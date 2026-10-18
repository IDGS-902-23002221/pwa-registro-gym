-- 12_vencimientos.sql
-- TICKET 000.5: reporte_vencimientos (0019) - socios cuyo plan vence en un rango.
--
-- Usa el prelude (Mensual 500.00/30 id 3333, socio Jose id 5555, personal activo).
-- Se cobra para fijar pagado_hasta y luego se consulta el rango. Todo se revierte.

\ir _prelude.sql

-- Cobro de un mes: deja a Jose cubierto hasta 2026-10-30.
DO $$
BEGIN
  PERFORM public.registrar_pago(
    '55555555-5555-5555-5555-555555555555', 500.00, 'efectivo',
    DATE '2026-10-01', NULL, '33333333-3333-3333-3333-333333333333');
END
$$;

-- Dentro del rango: aparece con su vencimiento y plan.
DO $$
DECLARE v_fila record;
BEGIN
  SELECT * INTO v_fila FROM public.reporte_vencimientos(DATE '2026-10-01', DATE '2026-10-31');
  IF v_fila IS NULL THEN
    RAISE EXCEPTION 'FALLO: Jose no aparecio en su rango de vencimiento';
  END IF;
  IF v_fila.vence_en <> DATE '2026-10-30' THEN
    RAISE EXCEPTION 'FALLO: vence_en = %, se esperaba 2026-10-30', v_fila.vence_en;
  END IF;
  IF v_fila.plan <> 'Mensual' THEN
    RAISE EXCEPTION 'FALLO: plan = %, se esperaba Mensual', v_fila.plan;
  END IF;
END
$$;
\echo 'OK  vencimiento dentro del rango con fecha y plan'

-- Fuera del rango: no aparece.
DO $$
DECLARE v_count integer;
BEGIN
  SELECT count(*) INTO v_count FROM public.reporte_vencimientos(DATE '2026-11-01', DATE '2026-11-30');
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'FALLO: aparecio un vencimiento fuera de rango';
  END IF;
END
$$;
\echo 'OK  sin vencimientos fuera del rango'

-- Un socio pausado no cuenta como vencimiento.
DO $$
DECLARE v_count integer;
BEGIN
  PERFORM public.cambiar_estado_socio(
    '55555555-5555-5555-5555-555555555555', 'pausado', 'prueba de vencimientos');
  SELECT count(*) INTO v_count FROM public.reporte_vencimientos(DATE '2026-10-01', DATE '2026-10-31');
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'FALLO: un socio pausado aparecio como vencimiento';
  END IF;
END
$$;
\echo 'OK  los pausados se excluyen'

-- Rango invalido y perfil desactivado.
DO $$
BEGIN
  BEGIN
    PERFORM public.reporte_vencimientos(DATE '2026-11-01', DATE '2026-10-01');
    RAISE EXCEPTION 'FALLO: se acepto un rango invertido';
  EXCEPTION WHEN SQLSTATE 'GYM06' THEN NULL;
  END;
END
$$;
SELECT set_config('app.usuario_id', '22222222-2222-2222-2222-222222222222', true);
DO $$
BEGIN
  BEGIN
    PERFORM public.reporte_vencimientos(DATE '2026-10-01', DATE '2026-10-31');
    RAISE EXCEPTION 'FALLO: un perfil desactivado pudo consultar';
  EXCEPTION WHEN SQLSTATE 'GYM10' THEN NULL;
  END;
END
$$;
\echo 'OK  rango invertido GYM06 y perfil desactivado GYM10'

ROLLBACK;
