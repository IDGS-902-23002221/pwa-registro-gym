-- 04_estado_socio.sql
-- 02 §4: el estado visible se calcula al leer (activo / pausado / vencido) y un
-- socio eliminado por ARCO desaparece del listado.

\ir _prelude.sql

-- Al: pagado_hasta en el futuro; el resto de casos controlan cada rama del CASE
-- de la vista por separado.
INSERT INTO public.socio (id, nombre, apellidos, telefono, estado, pagado_hasta) VALUES
  ('a1111111-1111-1111-1111-111111111111', 'Al',    'Pagado',   '5510000001', 'activo',  DATE '2026-12-31'),
  ('b2222222-2222-2222-2222-222222222222', 'Bea',   'Vencido',  '5510000002', 'activo',  DATE '2025-12-31'),
  ('c3333333-3333-3333-3333-333333333333', 'Caro',  'Pausado',  '5510000003', 'pausado', DATE '2026-12-31'),
  ('d4444444-4444-4444-4444-444444444444', 'Dan',   'Sin pago', '5510000004', 'activo',  NULL),
  ('e5555555-5555-5555-5555-555555555555', 'Eva',   'Borrado',  '5510000005', 'activo',  DATE '2026-12-31');

-- Dan es el caso raro: nunca ha pagado, no es vencido, es activo.
SELECT public.eliminar_socio('e5555555-5555-5555-5555-555555555555');

DO $$
DECLARE
  v_actual     text;
  v_vencido    text;
  v_pausado    text;
  v_sin_pago   text;
  v_borrado    integer;
BEGIN
  SELECT estado_calculado INTO v_actual   FROM public.socios_con_estado WHERE nombre = 'Al';
  SELECT estado_calculado INTO v_vencido  FROM public.socios_con_estado WHERE nombre = 'Bea';
  SELECT estado_calculado INTO v_pausado  FROM public.socios_con_estado WHERE nombre = 'Caro';
  SELECT estado_calculado INTO v_sin_pago FROM public.socios_con_estado WHERE nombre = 'Dan';
  SELECT count(*)       INTO v_borrado    FROM public.socios_con_estado WHERE nombre = 'Eva';

  IF v_actual   IS DISTINCT FROM 'activo'  THEN RAISE EXCEPTION 'FALLO: Al deberia ser activo, es %', v_actual; END IF;
  IF v_vencido  IS DISTINCT FROM 'vencido' THEN RAISE EXCEPTION 'FALLO: Bea deberia ser vencido, es %', v_vencido; END IF;
  IF v_pausado  IS DISTINCT FROM 'pausado' THEN RAISE EXCEPTION 'FALLO: Caro deberia ser pausado, es %', v_pausado; END IF;
  IF v_sin_pago IS DISTINCT FROM 'activo'  THEN RAISE EXCEPTION 'FALLO: Dan nunca ha pagado y deberia ser activo, es %', v_sin_pago; END IF;
  IF v_borrado <> 0 THEN RAISE EXCEPTION 'FALLO: el socio eliminado por ARCO sigue en el listado'; END IF;
END
$$;
\echo 'OK  activo, vencido, pausado, sin pago y eliminado se calculan bien'

-- El estado cambia solo cuando pasa la fecha, sin tareas programadas: la vista se
-- calcula en cada lectura (02 §4).
DO $$
DECLARE
  v_antes text;
  v_despues text;
BEGIN
  SELECT estado_calculado INTO v_antes FROM public.socios_con_estado WHERE nombre = 'Al';

  UPDATE public.socio SET pagado_hasta = DATE '2020-01-01' WHERE nombre = 'Al';
  SELECT estado_calculado INTO v_despues FROM public.socios_con_estado WHERE nombre = 'Al';

  IF v_antes <> 'activo' OR v_despues <> 'vencido' THEN
    RAISE EXCEPTION 'FALLO: la vista no reflejo el cambio de pagado_hasta (% -> %)', v_antes, v_despues;
  END IF;
END
$$;
\echo 'OK  la vista refleja el cambio de cobertura en la siguiente lectura'

-- Pausar no cambia la fecha de cobertura ni la borra.
DO $$
DECLARE
  v_hasta date;
BEGIN
  PERFORM public.cambiar_estado_socio('a1111111-1111-1111-1111-111111111111', 'pausado', 'viaje');

  SELECT pagado_hasta INTO v_hasta FROM public.socio WHERE nombre = 'Al';
  IF v_hasta <> DATE '2020-01-01' THEN
    RAISE EXCEPTION 'FALLO: pausar movio la cobertura a %', v_hasta;
  END IF;
END
$$;
\echo 'OK  pausar conserva la fecha de cobertura'

-- La justificacion es obligatoria: sin ella el frontend no puede explicar el
-- cambio y la bitacora queda vacia. Se prueba con Bea (activa), porque Al ya
-- quedo pausado arriba y daria GYM08 en vez de GYM09.
DO $$
BEGIN
  BEGIN
    PERFORM public.cambiar_estado_socio('b2222222-2222-2222-2222-222222222222', 'pausado', '   ');
    RAISE EXCEPTION 'FALLO: se acepto pausar sin justificacion';
  EXCEPTION WHEN SQLSTATE 'GYM09' THEN
    NULL;  -- JUSTIFICACION_REQUERIDA
  END;
END
$$;
\echo 'OK  cambiar estado sin justificacion rechazado con GYM09'

-- Pausar dos veces seguidas no es un cambio, asi que se rechaza en vez de escribir
-- una justificacion nueva sin efecto. Se usa Dan (activo) porque Al ya pausado.
DO $$
BEGIN
  PERFORM public.cambiar_estado_socio('d4444444-4444-4444-4444-444444444444', 'pausado', 'otro viaje');
  BEGIN
    PERFORM public.cambiar_estado_socio('d4444444-4444-4444-4444-444444444444', 'pausado', 'mas viajes');
    RAISE EXCEPTION 'FALLO: se acepto pausar a un socio que ya estaba pausado';
  EXCEPTION WHEN SQLSTATE 'GYM08' THEN
    NULL;  -- ESTADO_SOCIO_INVALIDO
  END;
END
$$;
\echo 'OK  pausar a un socio ya pausado se rechaza con GYM08'

-- Volver a activo no repara la cobertura: solo la cambia de nuevo.
DO $$
DECLARE
  v_estado text;
BEGIN
  PERFORM public.cambiar_estado_socio('a1111111-1111-1111-1111-111111111111', 'activo', 'regreso');

  SELECT estado_calculado INTO v_estado FROM public.socios_con_estado WHERE nombre = 'Al';
  IF v_estado <> 'vencido' THEN
    RAISE EXCEPTION 'FALLO: reactivar dejo al socio en % cuando la cobertura sigue vencida', v_estado;
  END IF;
END
$$;
\echo 'OK  reactivar no repara una cobertura vencida'

ROLLBACK;