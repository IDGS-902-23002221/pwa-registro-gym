-- 10_planes_activo.sql
-- TICKET 000.4.1.1: activar y desactivar un plan sin borrarlo.
--
-- Usa el prelude (Mensual 500.00 id 3333 activo, Trimestral 1350.00 id 4444
-- activo, socio Jose id 5555, sesion de personal activo). Todo se revierte.

\ir _prelude.sql

-- Desactivar: no borra la fila, deja bitacora con la transicion.
DO $$
BEGIN
  PERFORM public.cambiar_activo_plan('33333333-3333-3333-3333-333333333333', false);

  IF (SELECT activo FROM public.plan WHERE id = '33333333-3333-3333-3333-333333333333') THEN
    RAISE EXCEPTION 'FALLO: el plan Mensual siguio activo';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.plan WHERE id = '33333333-3333-3333-3333-333333333333') THEN
    RAISE EXCEPTION 'FALLO: desactivar borro la fila del plan';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.auditoria
                 WHERE accion = 'cambio_estado' AND entidad = 'plan'
                   AND entidad_id = '33333333-3333-3333-3333-333333333333'
                   AND justificacion = 'activo true -> false') THEN
    RAISE EXCEPTION 'FALLO: desactivar no dejo bitacora con la transicion';
  END IF;
END
$$;
\echo 'OK  desactivar conserva la fila y deja bitacora'

-- Un plan inactivo ya no se vende: cobrarlo falla con GYM07.
DO $$
BEGIN
  BEGIN
    PERFORM public.registrar_pago(
      '55555555-5555-5555-5555-555555555555', 500.00, 'efectivo',
      DATE '2026-12-01', NULL,
      '33333333-3333-3333-3333-333333333333'
    );
    RAISE EXCEPTION 'FALLO: se cobro con un plan inactivo';
  EXCEPTION WHEN SQLSTATE 'GYM07' THEN
    NULL;
  END;
END
$$;
\echo 'OK  cobro con plan inactivo rechazado con GYM07'

-- Idempotente: repetir el mismo estado no cambia nada ni ensucia la bitacora.
DO $$
DECLARE
  v_antes  integer;
  v_despues integer;
BEGIN
  SELECT count(*) INTO v_antes FROM public.auditoria
   WHERE accion = 'cambio_estado' AND entidad = 'plan';

  PERFORM public.cambiar_activo_plan('33333333-3333-3333-3333-333333333333', false);

  SELECT count(*) INTO v_despues FROM public.auditoria
   WHERE accion = 'cambio_estado' AND entidad = 'plan';

  IF v_despues <> v_antes THEN
    RAISE EXCEPTION 'FALLO: repetir el mismo estado dejo bitacora (antes % despues %)',
      v_antes, v_despues;
  END IF;
END
$$;
\echo 'OK  repetir el mismo estado es idempotente'

-- Reactivar vuelve a permitir el cobro.
DO $$
DECLARE
  v_resultado jsonb;
BEGIN
  PERFORM public.cambiar_activo_plan('33333333-3333-3333-3333-333333333333', true);

  IF NOT (SELECT activo FROM public.plan WHERE id = '33333333-3333-3333-3333-333333333333') THEN
    RAISE EXCEPTION 'FALLO: el plan Mensual no quedo activo';
  END IF;

  v_resultado := public.registrar_pago(
    '55555555-5555-5555-5555-555555555555', 500.00, 'efectivo',
    DATE '2026-12-01', NULL,
    '33333333-3333-3333-3333-333333333333'
  );
  IF v_resultado ->> 'folio' IS NULL THEN
    RAISE EXCEPTION 'FALLO: tras reactivar el cobro no devolvio folio';
  END IF;
END
$$;
\echo 'OK  reactivar permite cobrar de nuevo'

-- Plan inexistente y estado nulo.
DO $$
BEGIN
  BEGIN
    PERFORM public.cambiar_activo_plan('99999999-9999-9999-9999-999999999999', false);
    RAISE EXCEPTION 'FALLO: se acepto un plan inexistente';
  EXCEPTION WHEN SQLSTATE 'GYM07' THEN
    NULL;
  END;

  BEGIN
    PERFORM public.cambiar_activo_plan('33333333-3333-3333-3333-333333333333', NULL);
    RAISE EXCEPTION 'FALLO: se acepto un estado nulo';
  EXCEPTION WHEN SQLSTATE 'GYM07' THEN
    NULL;
  END;
END
$$;
\echo 'OK  plan inexistente y estado nulo rechazados con GYM07'

-- Perfil desactivado: GYM10, sin cambios.
SELECT set_config('app.usuario_id', '22222222-2222-2222-2222-222222222222', true);
DO $$
BEGIN
  BEGIN
    PERFORM public.cambiar_activo_plan('33333333-3333-3333-3333-333333333333', false);
    RAISE EXCEPTION 'FALLO: un perfil desactivado pudo cambiar un plan';
  EXCEPTION WHEN SQLSTATE 'GYM10' THEN
    NULL;
  END;
END
$$;
\echo 'OK  perfil desactivado recibe GYM10'

ROLLBACK;
