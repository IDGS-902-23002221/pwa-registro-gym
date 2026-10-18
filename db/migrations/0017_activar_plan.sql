-- 0017_activar_plan.sql
--
-- TICKET 000.4.1.1 (v1, back): activar y desactivar un plan sin borrarlo.
--
-- Complementa la 0016: alli se dio de alta y se edito precio; aqui el
-- encendido/apagado del catalogo. Desactivar no elimina la fila (pago y
-- membresia la referencian con ON DELETE RESTRICT, 0004) y no toca cobros
-- pasados: registrar_pago ya rechaza un plan inactivo (GYM07), asi que
-- desactivar solo impide venderlo de aqui en adelante.
--
-- No se amplian los CHECK de 0002: se usa accion 'cambio_estado' (ya permitida)
-- y entidad 'plan' (que la 0016 habilito). No se edita ninguna migracion
-- aplicada (ADR-008).

CREATE OR REPLACE FUNCTION public.cambiar_activo_plan(
  p_plan_id uuid,
  p_activo  boolean
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_usuario  public.perfil.id%TYPE := public.usuario_actual_id();
  v_anterior boolean;
BEGIN
  IF NOT public.es_usuario_activo() THEN
    RAISE EXCEPTION USING
      ERRCODE = 'GYM10', MESSAGE = 'PERFIL_INACTIVO',
      DETAIL  = 'La sesion no corresponde a un perfil activo.';
  END IF;

  IF p_activo IS NULL THEN
    RAISE EXCEPTION USING
      ERRCODE = 'GYM07', MESSAGE = 'PLAN_INVALIDO',
      DETAIL  = 'El estado a fijar (activo) es nulo.';
  END IF;

  SELECT activo INTO v_anterior
  FROM public.plan
  WHERE id = p_plan_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING
      ERRCODE = 'GYM07', MESSAGE = 'PLAN_INVALIDO',
      DETAIL  = format('plan_id inexistente: %s', p_plan_id);
  END IF;

  -- Idempotente: si ya esta en el estado pedido, no cambia ni deja bitacora.
  IF v_anterior = p_activo THEN
    RETURN;
  END IF;

  UPDATE public.plan
     SET activo = p_activo
   WHERE id = p_plan_id;

  -- %s sobre un boolean da 't'/'f'; se pasa a 'true'/'false' para que la
  -- bitacora se lea sola.
  INSERT INTO public.auditoria (usuario_id, accion, entidad, entidad_id, justificacion)
  VALUES (v_usuario, 'cambio_estado', 'plan', p_plan_id,
          format('activo %s -> %s',
                 CASE WHEN v_anterior THEN 'true' ELSE 'false' END,
                 CASE WHEN p_activo  THEN 'true' ELSE 'false' END));
END
$$;

COMMENT ON FUNCTION public.cambiar_activo_plan(uuid, boolean) IS
  'Activa o desactiva un plan sin borrarlo, con bitacora (accion cambio_estado, entidad plan). Idempotente: repetir el mismo estado no cambia nada. Errores: GYM07, GYM10.';

-- ---------------------------------------------------------------------------
-- Permisos: igual que las demas reglas de negocio (0008, 0013)
-- ---------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.cambiar_activo_plan(uuid, boolean) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.cambiar_activo_plan(uuid, boolean) TO authenticated;
