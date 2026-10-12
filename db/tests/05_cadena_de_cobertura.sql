-- 05_cadena_de_cobertura.sql
-- ADR-004: la cobertura se encadena con la anterior y no se re-deriva del ultimo
-- pago ni del ultimo mes pagado. Estas pruebas fijan esa regla.

\ir _prelude.sql

-- Tres renovaciones seguidas, mes a mes.
DO $$
DECLARE
  v_resultado jsonb;
BEGIN
  SELECT public.registrar_pago(
           '55555555-5555-5555-5555-555555555555', 500.00, 'efectivo', DATE '2026-10-01', NULL
         ) INTO v_resultado;
  IF (v_resultado ->> 'pagado_hasta')::date <> DATE '2026-10-30' THEN
    RAISE EXCEPTION 'FALLO: primer pago dejo pagado_hasta %', v_resultado ->> 'pagado_hasta';
  END IF;

  SELECT public.registrar_pago(
           '55555555-5555-5555-5555-555555555555', 500.00, 'efectivo', DATE '2026-11-01', NULL
         ) INTO v_resultado;
  IF (v_resultado ->> 'pagado_hasta')::date <> DATE '2026-11-30' THEN
    RAISE EXCEPTION 'FALLO: segundo pago dejo pagado_hasta % y se esperaba 2026-11-30',
      v_resultado ->> 'pagado_hasta';
  END IF;

  SELECT public.registrar_pago(
           '55555555-5555-5555-5555-555555555555', 500.00, 'efectivo', DATE '2026-12-01', NULL
         ) INTO v_resultado;
  IF (v_resultado ->> 'pagado_hasta')::date <> DATE '2026-12-30' THEN
    RAISE EXCEPTION 'FALLO: tercer pago dejo pagado_hasta % y se esperaba 2026-12-30',
      v_resultado ->> 'pagado_hasta';
  END IF;
END
$$;
\echo 'OK  la cobertura se encadena dia a dia, sin meses regalados ni perdidos'

-- La membresia se extiende, no se duplica: una sola activa que sigue a la
-- cobertura (02 §5: "extiende la vigencia (termina_en) de la membresía").
-- Recorte sprint1: historial de membresias vencidas fuera de alcance.
DO $$
DECLARE
  v_total   integer;
  v_activas integer;
  v_vencidas integer;
  v_ultima  date;
BEGIN
  SELECT count(*) FILTER (WHERE estado = 'activa'),
         count(*) FILTER (WHERE estado = 'vencida'),
         max(termina_en) FILTER (WHERE estado = 'activa'),
         count(*)
    INTO v_activas, v_vencidas, v_ultima, v_total
  FROM public.membresia
  WHERE socio_id = '55555555-5555-5555-5555-555555555555';

  IF v_total <> 1 THEN
    RAISE EXCEPTION 'FALLO: hay % membresias y se esperaba 1 (la activa extendida)', v_total;
  END IF;
  IF v_activas <> 1 THEN
    RAISE EXCEPTION 'FALLO: hay % membresias activas y solo puede haber una', v_activas;
  END IF;
  IF v_vencidas <> 0 THEN
    RAISE EXCEPTION 'FALLO: hay % membresias vencidas y se esperaban 0 (recorte sprint1)', v_vencidas;
  END IF;
  IF v_ultima <> DATE '2026-12-30' THEN
    RAISE EXCEPTION 'FALLO: la membresia activa termina en % y coincide con pagado_hasta', v_ultima;
  END IF;
END
$$;
\echo 'OK  cada renovacion extiende la membresia activa (recorte sprint1)'

-- La vista se apoya en socio.pagado_hasta y no en membresia.termina_en (ADR-004),
-- asi que desalinear la membresia a mano no cambia lo que ve el usuario.
DO $$
DECLARE
  v_estado text;
BEGIN
  UPDATE public.membresia SET termina_en = DATE '2027-06-30'
  WHERE socio_id = '55555555-5555-5555-5555-555555555555' AND estado = 'activa';

  SELECT estado_calculado INTO v_estado FROM public.socios_con_estado WHERE nombre = 'Jose';
  IF v_estado <> 'activo' THEN
    RAISE EXCEPTION 'FALLO: desalinear la membresia cambio el estado visible a %', v_estado;
  END IF;
END
$$;
\echo 'OK  la cobertura visible se sostiene en socio.pagado_hasta (ADR-004)'

-- Historias 0011: cliente nuevo cualquier día + renovación anticipada.
-- Nadia llega el 11 de febrero y su mes corre desde ese día.
DO $$
DECLARE
  v_resultado jsonb;
BEGIN
  INSERT INTO public.socio (id, nombre, apellidos, telefono)
  VALUES ('77777777-1111-1111-1111-111111111111', 'Nadia', 'Nueva Diaz', '5571111111');

  SELECT public.registrar_pago(
           '77777777-1111-1111-1111-111111111111', 500.00, 'efectivo', DATE '2026-02-11', NULL
         ) INTO v_resultado;
  -- Base 2026-02-10 + 30 = 2026-03-12.
  IF (v_resultado ->> 'pagado_hasta')::date <> DATE '2026-03-12' THEN
    RAISE EXCEPTION 'FALLO: primer pago de Nadia dejo pagado_hasta % y se esperaba 2026-03-12',
      v_resultado ->> 'pagado_hasta';
  END IF;

  -- Renueva el 10 de marzo, antes de vencer: se encadena desde el 12, sin perder días.
  SELECT public.registrar_pago(
           '77777777-1111-1111-1111-111111111111', 500.00, 'efectivo', DATE '2026-03-10', NULL
         ) INTO v_resultado;
  IF (v_resultado ->> 'pagado_hasta')::date <> DATE '2026-04-11' THEN
    RAISE EXCEPTION 'FALLO: renovacion anticipada dejo pagado_hasta % y se esperaba 2026-04-11',
      v_resultado ->> 'pagado_hasta';
  END IF;
END
$$;
\echo 'OK  alta cualquier día y renovación anticipada encadenan (0011)'

-- Visita un domingo: plan de 1 día, cubre solo ese día.
-- (El plan se inserta aquí porque el seed, dueño del catálogo, no está cargado
-- durante las pruebas.)
DO $$
DECLARE
  v_resultado jsonb;
BEGIN
  INSERT INTO public.plan (nombre, precio_mxn, dias_periodo, activo)
  VALUES ('Visita', 50.00, 1, true);

  INSERT INTO public.socio (id, nombre, apellidos, telefono)
  VALUES ('88888888-2222-2222-2222-222222222222', 'Victor', 'Visita Sol', '5572222222');

  SELECT public.registrar_pago(
           '88888888-2222-2222-2222-222222222222', 50.00, 'efectivo', DATE '2026-02-15', NULL
         ) INTO v_resultado;
  IF (v_resultado ->> 'pagado_hasta')::date <> DATE '2026-02-15' THEN
    RAISE EXCEPTION 'FALLO: la visita dejo pagado_hasta % y se esperaba 2026-02-15',
      v_resultado ->> 'pagado_hasta';
  END IF;
END
$$;
\echo 'OK  la visita cubre solo el día del pago (0011)'

-- Un socio que ya no esta activo no desaparece de los reportes: se archiva, no se
-- borra. Un pago de un socio archivado si se rechaza (GYM03).
DO $$
BEGIN
  BEGIN
    PERFORM public.eliminar_socio('55555555-5555-5555-5555-555555555555');
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'FALLO: eliminar_socio fallo de forma inesperada: %', SQLERRM;
  END;

  BEGIN
    PERFORM public.registrar_pago(
      '55555555-5555-5555-5555-555555555555', 500.00, 'efectivo', DATE '2027-01-01', NULL
    );
    RAISE EXCEPTION 'FALLO: se acepto un cobro a un socio eliminado';
  EXCEPTION WHEN SQLSTATE 'GYM03' THEN
    NULL;  -- SOCIO_NO_ENCONTRADO
  END;
END
$$;
\echo 'OK  tras ARCO el socio se archiva, desaparece del listado y ya no admite cobros'

-- ARCO no borra la fila: la sustituye por un registro no identificable y sella la
-- fecha. No se destruye la tabla, y con ella los pagos que la apuntan.
DO $$
DECLARE
  v_nombre    text;
  v_apellidos text;
  v_correo    text;
  v_telefono  text;
  v_eliminado timestamptz;
BEGIN
  SELECT nombre, apellidos, correo, telefono, eliminado_en
    INTO v_nombre, v_apellidos, v_correo, v_telefono, v_eliminado
  FROM public.socio WHERE id = '55555555-5555-5555-5555-555555555555';

  IF v_nombre <> 'ELIMINADO' THEN
    RAISE EXCEPTION 'FALLO: ARCO dejo el nombre en %', v_nombre;
  END IF;
  IF v_apellidos IS NOT NULL OR v_correo IS NOT NULL OR v_telefono IS NOT NULL THEN
    RAISE EXCEPTION 'FALLO: ARCO dejo datos identificables (apellidos %, correo %, telefono %)',
      v_apellidos, v_correo, v_telefono;
  END IF;
  IF v_eliminado IS NULL THEN
    RAISE EXCEPTION 'FALLO: ARCO no sello eliminado_en';
  END IF;
END
$$;
\echo 'OK  ARCO anonimiza los datos identificables'

-- Anonimizar dos veces es un error, no un borrado silencioso.
DO $$
BEGIN
  BEGIN
    PERFORM public.eliminar_socio('55555555-5555-5555-5555-555555555555');
    RAISE EXCEPTION 'FALLO: ARCO se aplico dos veces sobre el mismo socio';
  EXCEPTION WHEN SQLSTATE 'GYM03' THEN
    NULL;  -- SOCIO_YA_ELIMINADO
  END;
END
$$;
\echo 'OK  ARCO repetido rechazado con GYM03'

-- Los pagos y recibos sobreviven a ARCO.
DO $$
DECLARE
  v_pagos   integer;
  v_recibos integer;
BEGIN
  SELECT count(*) INTO v_pagos   FROM public.pago   WHERE socio_id = '55555555-5555-5555-5555-555555555555';
  SELECT count(*) INTO v_recibos FROM public.recibo r
   JOIN public.pago p ON p.id = r.pago_id
   WHERE p.socio_id = '55555555-5555-5555-5555-555555555555';

  IF v_pagos <> 3 OR v_recibos <> 3 THEN
    RAISE EXCEPTION 'FALLO: ARCO destruyo historial (% pagos, % recibos)', v_pagos, v_recibos;
  END IF;
END
$$;
\echo 'OK  los pagos y recibos sobreviven a ARCO'

ROLLBACK;