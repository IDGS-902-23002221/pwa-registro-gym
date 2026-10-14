-- 09_planes.sql
-- TICKET 000.4.1 (v1): alta de planes y edicion de precio por funciones
-- auditadas, con cobros pasados intactos.
--
-- Usa el prelude (planes Mensual 500.00 id 3333 y Trimestral 1350.00 id 4444,
-- socio Jose id 5555, sesion de personal activo). Todo se revierte al final.

\ir _prelude.sql

-- El alta crea el plan activo y deja bitacora.
DO $$
DECLARE
  v_id uuid;
BEGIN
  v_id := public.crear_plan('Semanal', 150.00, 7);

  IF NOT EXISTS (SELECT 1 FROM public.plan
                 WHERE id = v_id AND nombre = 'Semanal'
                   AND precio_mxn = 150.00 AND dias_periodo = 7 AND activo) THEN
    RAISE EXCEPTION 'FALLO: el plan Semanal no quedo como se pidio';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.auditoria
                 WHERE accion = 'alta' AND entidad = 'plan' AND entidad_id = v_id) THEN
    RAISE EXCEPTION 'FALLO: el alta no dejo bitacora';
  END IF;
END
$$;
\echo 'OK  alta de plan con bitacora'

-- Duplicado por nombre, nombre vacio, precio y dias invalidos.
DO $$
BEGIN
  BEGIN
    PERFORM public.crear_plan('Mensual', 400.00, 30);
    RAISE EXCEPTION 'FALLO: se acepto un plan duplicado';
  EXCEPTION WHEN SQLSTATE 'GYM07' THEN
    NULL;
  END;

  BEGIN
    PERFORM public.crear_plan('   ', 100.00, 30);
    RAISE EXCEPTION 'FALLO: se acepto un plan sin nombre';
  EXCEPTION WHEN SQLSTATE 'GYM07' THEN
    NULL;
  END;

  BEGIN
    PERFORM public.crear_plan('Gratis', 0, 30);
    RAISE EXCEPTION 'FALLO: se acepto un precio en cero';
  EXCEPTION WHEN SQLSTATE 'GYM04' THEN
    NULL;
  END;

  BEGIN
    PERFORM public.crear_plan('Raro', 100.00, 400);
    RAISE EXCEPTION 'FALLO: se aceptaron dias fuera de 1-366';
  EXCEPTION WHEN SQLSTATE 'GYM07' THEN
    NULL;
  END;
END
$$;
\echo 'OK  duplicado, nombre vacio, precio y dias invalidos rechazados'

-- Cobro al precio viejo, cambio de precio, y el cobro pasado queda intacto.
DO $$
DECLARE
  v_pago1 jsonb;
  v_pago2 jsonb;
BEGIN
  -- Cobro de Jose con el Mensual a 500.00 (precio vigente del prelude).
  v_pago1 := public.registrar_pago(
    '55555555-5555-5555-5555-555555555555', 500.00, 'efectivo',
    DATE '2026-12-01', NULL,
    '33333333-3333-3333-3333-333333333333'
  );

  -- El precio sube a 550.00.
  IF public.actualizar_precio_plan(
       '33333333-3333-3333-3333-333333333333', 550.00) <> 550.00 THEN
    RAISE EXCEPTION 'FALLO: actualizar_precio_plan no devolvio 550.00';
  END IF;

  -- El pago pasado conserva su monto (snapshot, no se reescribe).
  IF (SELECT monto_mxn FROM public.pago
      WHERE id = (v_pago1 ->> 'pago_id')::uuid) <> 500.00 THEN
    RAISE EXCEPTION 'FALLO: el cambio de precio reescribio un cobro pasado';
  END IF;

  -- Cobrar con el precio viejo y el plan explicito se rechaza (GYM07).
  BEGIN
    PERFORM public.registrar_pago(
      '55555555-5555-5555-5555-555555555555', 500.00, 'efectivo',
      DATE '2027-01-01', NULL,
      '33333333-3333-3333-3333-333333333333'
    );
    RAISE EXCEPTION 'FALLO: se acepto el precio viejo tras el cambio';
  EXCEPTION WHEN SQLSTATE 'GYM07' THEN
    NULL;
  END;

  -- Con el precio nuevo el cobro funciona.
  v_pago2 := public.registrar_pago(
    '55555555-5555-5555-5555-555555555555', 550.00, 'efectivo',
    DATE '2027-01-01', NULL,
    '33333333-3333-3333-3333-333333333333'
  );
  IF v_pago2 ->> 'folio' IS NULL THEN
    RAISE EXCEPTION 'FALLO: el cobro con precio nuevo no devolvio folio';
  END IF;

  -- La bitacora guarda el antes y el despues del precio.
  IF NOT EXISTS (SELECT 1 FROM public.auditoria
                 WHERE accion = 'cambio_precio' AND entidad = 'plan'
                   AND entidad_id = '33333333-3333-3333-3333-333333333333'
                   AND justificacion = 'precio 500.00 -> 550.00') THEN
    RAISE EXCEPTION 'FALLO: el cambio de precio no dejo bitacora con justificacion';
  END IF;
END
$$;
\echo 'OK  precio nuevo rige cobros nuevos, cobro pasado intacto, bitacora con justificacion'

-- Plan inexistente y perfil desactivado.
DO $$
BEGIN
  BEGIN
    PERFORM public.actualizar_precio_plan(
      '99999999-9999-9999-9999-999999999999', 600.00);
    RAISE EXCEPTION 'FALLO: se acepto un plan inexistente';
  EXCEPTION WHEN SQLSTATE 'GYM07' THEN
    NULL;
  END;
END
$$;
SELECT set_config('app.usuario_id', '22222222-2222-2222-2222-222222222222', true);
DO $$
BEGIN
  BEGIN
    PERFORM public.crear_plan('Nocturno', 200.00, 30);
    RAISE EXCEPTION 'FALLO: un perfil desactivado pudo dar de alta';
  EXCEPTION WHEN SQLSTATE 'GYM10' THEN
    NULL;
  END;

  BEGIN
    PERFORM public.actualizar_precio_plan(
      '33333333-3333-3333-3333-333333333333', 600.00);
    RAISE EXCEPTION 'FALLO: un perfil desactivado pudo cambiar precio';
  EXCEPTION WHEN SQLSTATE 'GYM10' THEN
    NULL;
  END;
END
$$;
\echo 'OK  plan inexistente GYM07, perfil desactivado GYM10 en ambas funciones'

ROLLBACK;
