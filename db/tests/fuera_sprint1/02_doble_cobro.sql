-- 02_doble_cobro.sql
-- 02 §5: cobrar dos veces el mismo periodo debe fallar con PAGO_PERIODO_YA_CUBIERTO,
-- nunca duplicar el cobro. Es la verificacion central del MVP.

\ir _prelude.sql

-- El primer cobro funciona y devuelve el folio.
DO $$
DECLARE
  v_resultado jsonb;
BEGIN
  v_resultado := public.registrar_pago(
    '55555555-5555-5555-5555-555555555555', 500.00, 'efectivo', DATE '2026-10-01', NULL
  );

  IF v_resultado ->> 'folio' IS NULL THEN
    RAISE EXCEPTION 'FALLO: el primer cobro no devolvio folio';
  END IF;
  IF (v_resultado ->> 'pagado_hasta')::date <> DATE '2026-10-30' THEN
    RAISE EXCEPTION 'FALLO: pagado_hasta quedo en % y se esperaba 2026-10-30',
      v_resultado ->> 'pagado_hasta';
  END IF;
END
$$;
\echo 'OK  primer cobro registrado, pagado_hasta = 2026-10-30'

-- El segundo cobro del mismo periodo y socio se rechaza.
DO $$
BEGIN
  BEGIN
    PERFORM public.registrar_pago(
      '55555555-5555-5555-5555-555555555555', 500.00, 'efectivo', DATE '2026-10-01', NULL
    );
    RAISE EXCEPTION 'FALLO: se acepto el cobro dos veces del periodo 2026-10';
  EXCEPTION WHEN SQLSTATE 'GYM01' THEN
    NULL;  -- PAGO_PERIODO_YA_CUBIERTO: es lo que queremos
  END;
END
$$;
\echo 'OK  doble cobro del mismo periodo rechazado con GYM01'

-- Y solo quedo un pago, un recibo y una fila de bitacora de cobro.
DO $$
DECLARE
  v_pagos    integer;
  v_recibos  integer;
  v_cobros   integer;
BEGIN
  SELECT count(*) INTO v_pagos    FROM public.pago     WHERE socio_id = '55555555-5555-5555-5555-555555555555';
  SELECT count(*) INTO v_recibos  FROM public.recibo   WHERE pago_id IN (SELECT id FROM public.pago);
  SELECT count(*) INTO v_cobros   FROM public.auditoria WHERE accion = 'cobro';

  IF v_pagos <> 1 THEN RAISE EXCEPTION 'FALLO: quedaron % pagos, se esperaba 1', v_pagos; END IF;
  IF v_recibos <> 1 THEN RAISE EXCEPTION 'FALLO: quedaron % recibos, se esperaba 1', v_recibos; END IF;
  IF v_cobros <> 1 THEN RAISE EXCEPTION 'FALLO: quedaron % cobros en bitacora, se esperaba 1', v_cobros; END IF;
END
$$;
\echo 'OK  el cobro rechazado no dejo pagos, recibos ni bitacora a medias'

-- El socio no estaba pausado ni eliminado, asi que el cobro es legitimo: pausa no
-- bloquea el cobro, solo el estado visible.
SELECT public.cambiar_estado_socio(
  '55555555-5555-5555-5555-555555555555', 'pausado', 'viaje'
);

DO $$
DECLARE
  v_resultado jsonb;
BEGIN
  v_resultado := public.registrar_pago(
    '55555555-5555-5555-5555-555555555555', 500.00, 'efectivo', DATE '2026-11-01', NULL
  );
  -- Renovar sobre pagado_hasta 2026-10-30 y periodo 2026-11-01 continua el
  -- calendario: la base es 2026-10-31 y 30 dias dan 2026-11-30.
  IF (v_resultado ->> 'pagado_hasta')::date <> DATE '2026-11-30' THEN
    RAISE EXCEPTION 'FALLO: la renovacion dio pagado_hasta % y se esperaba 2026-11-30',
      v_resultado ->> 'pagado_hasta';
  END IF;
END
$$;
\echo 'OK  la renovacion continua la cobertura sin regalar ni saltarse meses'

-- Un salto de dos meses no retrocede la cobertura.
DO $$
DECLARE
  v_resultado jsonb;
BEGIN
  v_resultado := public.registrar_pago(
    '55555555-5555-5555-5555-555555555555', 500.00, 'efectivo', DATE '2027-01-01', NULL
  );
  IF (v_resultado ->> 'pagado_hasta')::date <> DATE '2027-01-30' THEN
    RAISE EXCEPTION 'FALLO: tras el salto pagado_hasta quedo en % y se esperaba 2027-01-30',
      v_resultado ->> 'pagado_hasta';
  END IF;
END
$$;
\echo 'OK  un salto de meses no concede la cobertura perdida'

-- La membresia quedo una sola y le sigue a la cobertura.
DO $$
DECLARE
  v_activas  integer;
  v_termino  date;
BEGIN
  SELECT count(*), max(termina_en) INTO v_activas, v_termino
  FROM public.membresia
  WHERE socio_id = '55555555-5555-5555-5555-555555555555' AND estado = 'activa';

  IF v_activas <> 1 THEN
    RAISE EXCEPTION 'FALLO: hay % membresias activas, se esperaba 1 (indice parcial)', v_activas;
  END IF;
  IF v_termino <> DATE '2027-01-30' THEN
    RAISE EXCEPTION 'FALLO: la membresia termina en % y se esperaba 2027-01-30', v_termino;
  END IF;
END
$$;
\echo 'OK  una sola membresia activa, terminada en la ultima cobertura'

-- Periodo que no es primer dia de mes.
DO $$
BEGIN
  BEGIN
    PERFORM public.registrar_pago(
      '55555555-5555-5555-5555-555555555555', 500.00, 'efectivo', DATE '2027-02-15', NULL
    );
    RAISE EXCEPTION 'FALLO: se acepto un periodo que no es inicio de mes';
  EXCEPTION WHEN SQLSTATE 'GYM06' THEN
    NULL;  -- PERIODO_INVALIDO
  END;
END
$$;
\echo 'OK  periodo que no es inicio de mes rechazado con GYM06'

-- Monto invalido.
DO $$
BEGIN
  BEGIN
    PERFORM public.registrar_pago(
      '55555555-5555-5555-5555-555555555555', 0, 'efectivo', DATE '2027-02-01', NULL
    );
    RAISE EXCEPTION 'FALLO: se acepto un monto de 0';
  EXCEPTION WHEN SQLSTATE 'GYM04' THEN
    NULL;  -- MONTO_INVALIDO
  END;
END
$$;
\echo 'OK  monto de 0 rechazado'

-- Si dos planes activos cuestan lo mismo, la deduccion por monto es ambigua y hay
-- que fallar en vez de elegir uno al azar (GYM07). Se resuelve indicando plan_id.
INSERT INTO public.plan (nombre, precio_mxn, dias_periodo, activo)
VALUES ('Mensual alternativo', 500.00, 30, true);

INSERT INTO public.socio (id, nombre, apellidos, telefono)
VALUES ('66666666-6666-6666-6666-666666666666', 'Ana', 'Lopez Diaz', '5588888888');

SELECT set_config('app.usuario_id', '11111111-1111-1111-1111-111111111111', true);

DO $$
BEGIN
  BEGIN
    PERFORM public.registrar_pago(
      '66666666-6666-6666-6666-666666666666', 500.00, 'efectivo', DATE '2026-10-01', NULL
    );
    RAISE EXCEPTION 'FALLO: se acepto un cobro con dos planes del mismo precio sin plan_id';
  EXCEPTION WHEN SQLSTATE 'GYM07' THEN
    NULL;  -- PLAN_INVALIDO por ambiguedad
  END;
END
$$;
\echo 'OK  deduccion de plan ambigua rechazada con GYM07'

-- Indicando el plan_id si se cobra.
DO $$
DECLARE
  v_resultado jsonb;
BEGIN
  v_resultado := public.registrar_pago(
    '66666666-6666-6666-6666-666666666666', 500.00, 'efectivo', DATE '2026-10-01', NULL,
    '33333333-3333-3333-3333-333333333333'
  );
  IF v_resultado ->> 'folio' IS NULL THEN
    RAISE EXCEPTION 'FALLO: con plan_id explicito el cobro debio funcionar';
  END IF;
END
$$;
\echo 'OK  con plan_id explicito el cobro se resuelve'

-- El monto no puede contradecir al plan.
DO $$
BEGIN
  BEGIN
    PERFORM public.registrar_pago(
      '66666666-6666-6666-6666-666666666666', 999.00, 'efectivo', DATE '2026-11-01', NULL,
      '44444444-4444-4444-4444-444444444444'
    );
    RAISE EXCEPTION 'FALLO: se acepto un monto que no coincide con el plan';
  EXCEPTION WHEN SQLSTATE 'GYM07' THEN
    NULL;
  END;
END
$$;
\echo 'OK  monto que contradice al plan rechazado con GYM07'

-- Sin sesion activa no se cobra. Un usuario desactivado es GYM10, no un cobro
-- silencioso (02 §6).
SELECT set_config('app.usuario_id', '22222222-2222-2222-2222-222222222222', true);
DO $$
BEGIN
  BEGIN
    PERFORM public.registrar_pago(
      '55555555-5555-5555-5555-555555555555', 500.00, 'efectivo', DATE '2027-02-01', NULL
    );
    RAISE EXCEPTION 'FALLO: un perfil desactivado pudo cobrar';
  EXCEPTION WHEN SQLSTATE 'GYM10' THEN
    NULL;  -- PERFIL_INACTIVO
  END;
END
$$;
\echo 'OK  un perfil desactivado recibe GYM10 y no cobra'

ROLLBACK;