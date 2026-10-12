-- 08_reportes_y_export.sql
-- Los reportes y la exportacion (02 §5). Ademas de los numeros, estas pruebas
-- fijan una cosa importante: un reporte con la sesion perdida no devuelve cero
-- filas, falla con GYM10. Si devolviera cero, el frontend no podria distinguir
-- "no hay nada" de "no tienes permiso".

\ir _prelude.sql

INSERT INTO public.socio (id, nombre, apellidos, telefono, correo, pagado_hasta) VALUES
  ('66666666-6666-6666-6666-666666666666', 'Ana',   'Lopez Diaz',  '5588888888', 'ana@ejemplo.mx',   DATE '2026-10-30'),
  ('77777777-7777-7777-7777-777777777777', 'Bruno', 'Mora Paz',   '5577777777', 'bruno@ejemplo.mx', DATE '2025-12-31'),
  ('88888888-8888-8888-8888-888888888888', 'Carla', 'Rios Nunez', '5566666666', 'carla@ejemplo.mx',  NULL);

-- Octubre y noviembre de 2026: dos formas de pago, dos socios.
SELECT public.registrar_pago(
  '55555555-5555-5555-5555-555555555555', 500.00, 'efectivo', DATE '2026-10-01', 'octubre jose'
);
SELECT public.registrar_pago(
  '66666666-6666-6666-6666-666666666666', 500.00, 'efectivo', DATE '2026-10-01', 'octubre ana'
);
SELECT public.registrar_pago(
  '55555555-5555-5555-5555-555555555555', 500.00, 'tarjeta',  DATE '2026-11-01', 'noviembre jose'
);

-- El reporte agrupa por forma de pago y solo mira el rango pedido.
DO $$
DECLARE
  v_efectivo   numeric;
  v_efectivo_n bigint;
  v_tarjeta    numeric;
  v_tarjeta_n  bigint;
BEGIN
  SELECT total_mxn, cantidad INTO v_efectivo, v_efectivo_n
  FROM public.reporte_ingresos(DATE '2026-10-01', DATE '2026-10-31')
  WHERE forma_pago = 'efectivo';

  SELECT total_mxn, cantidad INTO v_tarjeta, v_tarjeta_n
  FROM public.reporte_ingresos(DATE '2026-10-01', DATE '2026-10-31')
  WHERE forma_pago = 'tarjeta';

  IF v_efectivo IS DISTINCT FROM 1000.00 OR v_efectivo_n IS DISTINCT FROM 2 THEN
    RAISE EXCEPTION 'FALLO: efectivo dio % en % cobros, se esperaban 1000.00 en 2',
      v_efectivo, v_efectivo_n;
  END IF;

  -- En el rango de octubre el cobro de noviembre no entra.
  IF v_tarjeta IS NOT NULL THEN
    RAISE EXCEPTION 'FALLO: el cobro de tarjeta de noviembre aparece en el reporte de octubre (%', v_tarjeta;
  END IF;

  SELECT total_mxn, cantidad INTO v_tarjeta, v_tarjeta_n
  FROM public.reporte_ingresos(DATE '2026-11-01', DATE '2026-11-30')
  WHERE forma_pago = 'tarjeta';

  IF v_tarjeta IS DISTINCT FROM 500.00 OR v_tarjeta_n IS DISTINCT FROM 1 THEN
    RAISE EXCEPTION 'FALLO: tarjeta dio % en % cobros, se esperaban 500.00 en 1',
      v_tarjeta, v_tarjeta_n;
  END IF;
END
$$;
\echo 'OK  reporte_ingresos agrupa por forma de pago y respeta el rango'

-- Un rango invertido es un error del cliente, no un reporte vacio.
DO $$
BEGIN
  BEGIN
    PERFORM public.reporte_ingresos(DATE '2026-11-01', DATE '2026-10-01');
    RAISE EXCEPTION 'FALLO: se acepto un rango invertido';
  EXCEPTION WHEN SQLSTATE 'GYM06' THEN
    NULL;
  END;
END
$$;
\echo 'OK  rango de fechas invertido rechazado con GYM06'

-- La cartera: solo los vencidos, con los dias de mora.
DO $$
DECLARE
  v_nombre text;
  v_dias   integer;
  v_total  bigint;
BEGIN
  SELECT count(*) INTO v_total FROM public.reporte_cartera();
  IF v_total <> 1 THEN
    RAISE EXCEPTION 'FALLO: la cartera tiene % filas y se esperaba 1 (solo Bruno)', v_total;
  END IF;

  SELECT nombre, dias_mora INTO v_nombre, v_dias FROM public.reporte_cartera();

  IF v_nombre <> 'Bruno' THEN
    RAISE EXCEPTION 'FALLO: la cartera trajo a % y se esperaba a Bruno', v_nombre;
  END IF;
  IF v_dias <> (current_date - DATE '2025-12-31')::integer THEN
    RAISE EXCEPTION 'FALLO: dias_mora dio % y se esperaba %', v_dias, current_date - DATE '2025-12-31';
  END IF;
END
$$;
\echo 'OK  reporte_cartera solo trae vencidos y cuenta los dias de mora'

-- Un socio que nunca ha pagado no aparece en la cartera: no debe nada todavia.
DO $$
DECLARE
  v_en_cartera integer;
BEGIN
  SELECT count(*) INTO v_en_cartera FROM public.reporte_cartera() WHERE nombre = 'Carla';
  IF v_en_cartera <> 0 THEN
    RAISE EXCEPTION 'FALLO: una socio que nunca ha pagado aparece en la cartera';
  END IF;
END
$$;
\echo 'OK  quien nunca ha pagado no esta en la cartera'

-- La exportacion trae socio, membresias y pagos, y deja rastro de que se hizo.
DO $$
DECLARE
  v_export       jsonb;
  v_membresias   jsonb;
  v_pagos        jsonb;
  v_folios       jsonb;
  v_exportaciones integer;
BEGIN
  v_export := public.exportar_socio('55555555-5555-5555-5555-555555555555');

  IF v_export -> 'socio' ->> 'nombre' <> 'Jose' THEN
    RAISE EXCEPTION 'FALLO: la exportacion trae el nombre %', v_export -> 'socio' ->> 'nombre';
  END IF;

  v_membresias := v_export -> 'membresias';
  -- Una sola membresía activa extendida (02 §5: "extiende la vigencia", no historial).
  IF jsonb_array_length(v_membresias) <> 1 THEN
    RAISE EXCEPTION 'FALLO: la exportacion trae % membresias y se esperaba 1',
      jsonb_array_length(v_membresias);
  END IF;

  v_pagos := v_export -> 'pagos';
  IF jsonb_array_length(v_pagos) <> 2 THEN
    RAISE EXCEPTION 'FALLO: la exportacion trae % pagos y se esperaban 2',
      jsonb_array_length(v_pagos);
  END IF;

  -- Cada pago viaja con su folio: un recibo sin folio no sirve para el gym.
  SELECT jsonb_agg(p ->> 'folio' ORDER BY p ->> 'folio') INTO v_folios
  FROM jsonb_array_elements(v_pagos) AS p;

  IF EXISTS (SELECT 1 FROM jsonb_array_elements_text(v_folios) f WHERE f IS NULL) THEN
    RAISE EXCEPTION 'FALLO: hay un pago en la exportacion sin folio';
  END IF;

  SELECT count(*) INTO v_exportaciones FROM public.auditoria
  WHERE accion = 'exportar' AND entidad_id = '55555555-5555-5555-5555-555555555555';
  IF v_exportaciones <> 1 THEN
    RAISE EXCEPTION 'FALLO: la exportacion dejo % rastros en bitacora y se esperaba 1', v_exportaciones;
  END IF;
END
$$;
\echo 'OK  exportar_socio entrega socio, membresias y pagos, y deja bitacora'

-- Exportar un socio inexistente.
DO $$
BEGIN
  BEGIN
    PERFORM public.exportar_socio('99999999-9999-9999-9999-999999999999');
    RAISE EXCEPTION 'FALLO: se exporto un socio que no existe';
  EXCEPTION WHEN SQLSTATE 'GYM02' THEN
    NULL;
  END;
END
$$;
\echo 'OK  exportar un socio inexistente falla con GYM02'

-- Sin sesion activa los tres fallan: es la diferencia entre "no hay datos" y "no
-- tienes permiso".
SELECT set_config('app.usuario_id', '22222222-2222-2222-2222-222222222222', true);
DO $$
BEGIN
  BEGIN
    PERFORM * FROM public.reporte_ingresos(DATE '2026-10-01', DATE '2026-10-31');
    RAISE EXCEPTION 'FALLO: reporte_ingresos respondio sin sesion activa';
  EXCEPTION WHEN SQLSTATE 'GYM10' THEN NULL;
  END;

  BEGIN
    PERFORM * FROM public.reporte_cartera();
    RAISE EXCEPTION 'FALLO: reporte_cartera respondio sin sesion activa';
  EXCEPTION WHEN SQLSTATE 'GYM10' THEN NULL;
  END;

  BEGIN
    PERFORM public.exportar_socio('55555555-5555-5555-5555-555555555555');
    RAISE EXCEPTION 'FALLO: exportar_socio respondio sin sesion activa';
  EXCEPTION WHEN SQLSTATE 'GYM10' THEN NULL;
  END;
END
$$;
\echo 'OK  sin perfil activo los reportes fallan con GYM10 en vez de salir vacios'

ROLLBACK;