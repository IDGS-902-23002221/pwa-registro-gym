-- 0016_gestion_planes.sql
--
-- TICKET 000.4.1 (v1, solo back): alta de planes y edicion de precio desde
-- funciones SQL auditadas. Sin activar/desactivar (va en otro ticket), sin UI.
--
-- Cobros pasados intactos por diseno (02 §4): pago.monto_mxn es el precio
-- cobrado (snapshot) y membresia.plan_id tiene ON DELETE RESTRICT (0004).
-- actualizar_precio_plan no toca ninguna fila de pago ni de membresia; y
-- registrar_pago ya exige monto == precio vigente (GYM07), asi que el precio
-- nuevo rige solo para cobros nuevos.
--
-- La bitacora de 0002 solo admitia entidad socio|membresia|pago: aqui se
-- amplia a 'plan' y la accion 'cambio_precio'. Las migraciones aplicadas no
-- se editan jamas (ADR-008): por eso el ALTER va aqui y no en la 0002.

-- ---------------------------------------------------------------------------
-- 1. Ampliar la bitacora para planes
-- ---------------------------------------------------------------------------
-- Los CHECK sin nombre de 0002 usan los nombres por defecto de Postgres.
ALTER TABLE public.auditoria DROP CONSTRAINT IF EXISTS auditoria_accion_check;
ALTER TABLE public.auditoria DROP CONSTRAINT IF EXISTS auditoria_entidad_check;

ALTER TABLE public.auditoria ADD CONSTRAINT auditoria_accion_check
  CHECK (accion IN ('alta', 'cambio_estado', 'cobro', 'exportar', 'eliminacion', 'cambio_precio'));

ALTER TABLE public.auditoria ADD CONSTRAINT auditoria_entidad_check
  CHECK (entidad IN ('socio', 'membresia', 'pago', 'plan'));

-- ---------------------------------------------------------------------------
-- 2. Alta de planes
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.crear_plan(
  p_nombre text,
  p_precio numeric,
  p_dias   integer
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_usuario public.perfil.id%TYPE := public.usuario_actual_id();
  v_plan_id uuid;
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

  IF p_precio IS NULL OR p_precio <= 0 THEN
    RAISE EXCEPTION USING
      ERRCODE = 'GYM04', MESSAGE = 'MONTO_INVALIDO',
      DETAIL  = format('precio recibido: %s', coalesce(p_precio::text, 'null'));
  END IF;

  IF p_dias IS NULL OR p_dias < 1 OR p_dias > 366 THEN
    RAISE EXCEPTION USING
      ERRCODE = 'GYM07', MESSAGE = 'PLAN_INVALIDO',
      DETAIL  = format('dias_periodo fuera de 1-366: %s', coalesce(p_dias::text, 'null'));
  END IF;

  IF EXISTS (SELECT 1 FROM public.plan WHERE nombre = v_nombre) THEN
    RAISE EXCEPTION USING
      ERRCODE = 'GYM07', MESSAGE = 'PLAN_INVALIDO',
      DETAIL  = format('plan duplicado: %s', v_nombre);
  END IF;

  INSERT INTO public.plan (nombre, precio_mxn, dias_periodo)
  VALUES (v_nombre, p_precio, p_dias)
  RETURNING id INTO v_plan_id;

  INSERT INTO public.auditoria (usuario_id, accion, entidad, entidad_id)
  VALUES (v_usuario, 'alta', 'plan', v_plan_id);

  RETURN v_plan_id;
EXCEPTION
  WHEN unique_violation THEN
    -- Carrera por nombre entre dos altas simultaneas: el UNIQUE manda.
    RAISE EXCEPTION USING
      ERRCODE = 'GYM07', MESSAGE = 'PLAN_INVALIDO',
      DETAIL  = format('plan duplicado: %s', v_nombre);
END
$$;

COMMENT ON FUNCTION public.crear_plan(text, numeric, integer) IS
  'Alta de plan con bitacora (accion alta, entidad plan). El plan nace activo. Errores: GYM04, GYM07, GYM10.';

-- ---------------------------------------------------------------------------
-- 3. Edicion de precio (cobros pasados intactos)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.actualizar_precio_plan(
  p_plan_id uuid,
  p_precio  numeric
)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_usuario  public.perfil.id%TYPE := public.usuario_actual_id();
  v_anterior numeric;
BEGIN
  IF NOT public.es_usuario_activo() THEN
    RAISE EXCEPTION USING
      ERRCODE = 'GYM10', MESSAGE = 'PERFIL_INACTIVO',
      DETAIL  = 'La sesion no corresponde a un perfil activo.';
  END IF;

  IF p_precio IS NULL OR p_precio <= 0 THEN
    RAISE EXCEPTION USING
      ERRCODE = 'GYM04', MESSAGE = 'MONTO_INVALIDO',
      DETAIL  = format('precio recibido: %s', coalesce(p_precio::text, 'null'));
  END IF;

  SELECT precio_mxn INTO v_anterior
  FROM public.plan
  WHERE id = p_plan_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING
      ERRCODE = 'GYM07', MESSAGE = 'PLAN_INVALIDO',
      DETAIL  = format('plan_id inexistente: %s', p_plan_id);
  END IF;

  UPDATE public.plan
     SET precio_mxn = p_precio
   WHERE id = p_plan_id;

  INSERT INTO public.auditoria (usuario_id, accion, entidad, entidad_id, justificacion)
  VALUES (v_usuario, 'cambio_precio', 'plan', p_plan_id,
          format('precio %s -> %s', v_anterior, p_precio));

  RETURN p_precio;
END
$$;

COMMENT ON FUNCTION public.actualizar_precio_plan(uuid, numeric) IS
  'Cambia solo plan.precio_mxn; pago.monto_mxn y membresia quedan intactos. Rige para cobros nuevos (registrar_pago exige GYM07). Errores: GYM04, GYM07, GYM10.';

-- ---------------------------------------------------------------------------
-- 4. Permisos: como las reglas de negocio (0008_rls.sql)
-- ---------------------------------------------------------------------------
-- SECURITY DEFINER escribe en plan y auditoria con privilegios del dueno,
-- igual que registrar_pago escribe en pago/recibo. El cliente solo las llama
-- por rpc; sin EXECUTE no puede usarlas (0013).
REVOKE ALL ON FUNCTION
  public.crear_plan(text, numeric, integer),
  public.actualizar_precio_plan(uuid, numeric)
FROM PUBLIC;

GRANT EXECUTE ON FUNCTION
  public.crear_plan(text, numeric, integer),
  public.actualizar_precio_plan(uuid, numeric)
TO authenticated;
