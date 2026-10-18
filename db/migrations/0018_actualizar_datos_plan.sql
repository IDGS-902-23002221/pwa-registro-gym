-- 0018_actualizar_datos_plan.sql
--
-- TICKET 000.4.1.1 (ampliación): editar el nombre y los días de un plan desde
-- una función auditada. El precio sigue en actualizar_precio_plan (0016) y el
-- encendido/apagado en cambiar_activo_plan (0017): cada cambio con su bitácora.
--
-- Editar el nombre o los días no toca cobros pasados: pago.monto_mxn es el precio
-- cobrado (snapshot) y membresia referencia el plan por id, no por nombre.
--
-- 0018 añade la acción 'cambio_datos' a la bitácora (la 0002/0016 no la tenían).
-- No se edita ninguna migración aplicada (ADR-008).

ALTER TABLE public.auditoria DROP CONSTRAINT IF EXISTS auditoria_accion_check;
ALTER TABLE public.auditoria ADD CONSTRAINT auditoria_accion_check
  CHECK (accion IN ('alta', 'cambio_estado', 'cobro', 'exportar', 'eliminacion', 'cambio_precio', 'cambio_datos'));

CREATE OR REPLACE FUNCTION public.actualizar_datos_plan(
  p_plan_id uuid,
  p_nombre  text,
  p_dias    integer
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_usuario public.perfil.id%TYPE := public.usuario_actual_id();
  v_plan    public.plan%ROWTYPE;
  v_nombre  text := btrim(coalesce(p_nombre, ''));
BEGIN
  IF NOT public.es_usuario_activo() THEN
    RAISE EXCEPTION USING
      ERRCODE = 'GYM10', MESSAGE = 'PERFIL_INACTIVO',
      DETAIL  = 'La sesion no corresponde a un perfil activo.';
  END IF;

  IF v_nombre = '' THEN
    RAISE EXCEPTION USING
      ERRCODE = 'GYM07', MESSAGE = 'PLAN_INVALIDO',
      DETAIL  = 'El nombre del plan esta vacio.';
  END IF;

  IF p_dias IS NULL OR p_dias < 1 OR p_dias > 366 THEN
    RAISE EXCEPTION USING
      ERRCODE = 'GYM07', MESSAGE = 'PLAN_INVALIDO',
      DETAIL  = format('dias_periodo fuera de 1-366: %s', coalesce(p_dias::text, 'null'));
  END IF;

  SELECT * INTO v_plan FROM public.plan WHERE id = p_plan_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING
      ERRCODE = 'GYM07', MESSAGE = 'PLAN_INVALIDO',
      DETAIL  = format('plan_id inexistente: %s', p_plan_id);
  END IF;

  IF EXISTS (SELECT 1 FROM public.plan WHERE nombre = v_nombre AND id <> p_plan_id) THEN
    RAISE EXCEPTION USING
      ERRCODE = 'GYM07', MESSAGE = 'PLAN_INVALIDO',
      DETAIL  = format('ya existe un plan con el nombre %s', v_nombre);
  END IF;

  -- Sin cambios: no actualiza ni deja bitácora (idempotente).
  IF v_plan.nombre = v_nombre AND v_plan.dias_periodo = p_dias THEN
    RETURN;
  END IF;

  UPDATE public.plan
     SET nombre = v_nombre,
         dias_periodo = p_dias
   WHERE id = p_plan_id;

  INSERT INTO public.auditoria (usuario_id, accion, entidad, entidad_id, justificacion)
  VALUES (v_usuario, 'cambio_datos', 'plan', p_plan_id,
          format('nombre "%s" -> "%s"; dias %s -> %s',
                 v_plan.nombre, v_nombre, v_plan.dias_periodo, p_dias));
END
$$;

COMMENT ON FUNCTION public.actualizar_datos_plan(uuid, text, integer) IS
  'Cambia nombre y dias de un plan con bitacora (accion cambio_datos, entidad plan). Idempotente. Errores: GYM07, GYM10.';

REVOKE ALL ON FUNCTION public.actualizar_datos_plan(uuid, text, integer) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.actualizar_datos_plan(uuid, text, integer) TO authenticated;
