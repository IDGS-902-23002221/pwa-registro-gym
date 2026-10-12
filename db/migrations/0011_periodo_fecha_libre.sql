-- 0011_periodo_fecha_libre.sql
--
-- Hallazgo 2026-10-11 (TICKET 000): un cliente nuevo llega cualquier día y su
-- cobertura corre desde ese día (paga el 2 de febrero, cubre hasta el 2 de marzo
-- con un plan de 30 días). El periodo deja de ser "el día 1 del mes" y pasa a ser
-- "la fecha de inicio de cobertura", cualquier día.
--
--   - Se elimina la validación GYM06 (PERIODO_INVALIDO).
--   - La unique (socio_id, periodo) sigue siendo el bloqueo del doble cobro,
--     ahora por día de inicio en vez de por mes.
--   - El encadenado sobre pagado_hasta no cambia: ya era genérico
--     (greatest(pagado_hasta, periodo - 1) + dias_periodo), así que una
--     renovación anticipada continúa donde terminó la anterior sin regalar días.
--   - Los cobros existentes con periodo en día 1 siguen válidos.
--
-- Se reescribe la función completa (CREATE OR REPLACE): la 0007 ya está aplicada
-- en producción y nunca se edita (ADR-008).

CREATE OR REPLACE FUNCTION public.registrar_pago(
  p_socio_id    uuid,
  p_monto       numeric,
  p_forma_pago  public.forma_pago,
  p_periodo     date,
  p_referencia  text        DEFAULT NULL,
  p_plan_id     uuid        DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_socio            public.socio%ROWTYPE;
  v_plan             public.plan%ROWTYPE;
  v_membresia        public.membresia%ROWTYPE;
  v_pago_id          uuid;
  v_recibo_id        uuid;
  v_folio            integer;
  v_pagado_hasta     date;
  v_termina_en       date;
  v_candidatos       integer;
  v_usuario          uuid;
BEGIN
  v_usuario := public.usuario_actual_id();

  IF NOT public.es_usuario_activo() THEN
    RAISE EXCEPTION USING
      ERRCODE = 'GYM10',
      MESSAGE = 'PERFIL_INACTIVO',
      DETAIL  = 'La sesion no corresponde a un perfil activo. Operacion cancelada.';
  END IF;

  IF p_monto IS NULL OR p_monto <= 0 THEN
    RAISE EXCEPTION USING
      ERRCODE = 'GYM04',
      MESSAGE = 'MONTO_INVALIDO',
      DETAIL  = format('monto recibido: %s', coalesce(p_monto::text, 'null'));
  END IF;

  IF p_periodo IS NULL THEN
    RAISE EXCEPTION USING
      ERRCODE = 'GYM06',
      MESSAGE = 'PERIODO_INVALIDO',
      DETAIL  = 'el periodo (fecha de inicio de cobertura) es obligatorio';
  END IF;

  -- FOR UPDATE serializa los cobros simultaneos del mismo socio: sin esto dos
  -- sesiones podrian pasar juntas la comprobacion de periodo y una leeria un
  -- pagado_hasta viejo.
  SELECT * INTO v_socio
  FROM public.socio
  WHERE id = p_socio_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING
      ERRCODE = 'GYM02',
      MESSAGE = 'SOCIO_NO_ENCONTRADO',
      DETAIL  = format('socio_id: %s', p_socio_id);
  END IF;

  IF v_socio.eliminado_en IS NOT NULL THEN
    RAISE EXCEPTION USING
      ERRCODE = 'GYM03',
      MESSAGE = 'SOCIO_YA_ELIMINADO',
      DETAIL  = format('socio_id: %s', p_socio_id);
  END IF;

  -- El bloqueo real del doble cobro es la unique (socio_id, periodo). La
  -- comprobacion explicita da un mensaje util en el caso normal, y la captura de
  -- unique_violation cubre la carrera: si otra transaccion se adelanta entre el
  -- SELECT y el INSERT, el error tambien llega como GYM01.
  IF EXISTS (SELECT 1 FROM public.pago WHERE socio_id = p_socio_id AND periodo = p_periodo) THEN
    RAISE EXCEPTION USING
      ERRCODE = 'GYM01',
      MESSAGE = 'PAGO_PERIODO_YA_CUBIERTO',
      DETAIL  = format('socio_id: %s ya tiene un cobro del periodo %s', p_socio_id, p_periodo);
  END IF;

  -- Plan: el dado, o deducido por monto.
  IF p_plan_id IS NOT NULL THEN
    SELECT * INTO v_plan FROM public.plan WHERE id = p_plan_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION USING
        ERRCODE = 'GYM07', MESSAGE = 'PLAN_INVALIDO',
        DETAIL  = format('plan_id inexistente: %s', p_plan_id);
    END IF;
    IF NOT v_plan.activo THEN
      RAISE EXCEPTION USING
        ERRCODE = 'GYM07', MESSAGE = 'PLAN_INVALIDO',
        DETAIL  = format('plan inactivo: %s', v_plan.nombre);
    END IF;
    IF v_plan.precio_mxn <> p_monto THEN
      RAISE EXCEPTION USING
        ERRCODE = 'GYM07', MESSAGE = 'PLAN_INVALIDO',
        DETAIL  = format('el plan %s cuesta %s y se recibio %s',
                         v_plan.nombre, v_plan.precio_mxn, p_monto);
    END IF;
  ELSE
    SELECT count(*) INTO v_candidatos
    FROM public.plan
    WHERE activo AND precio_mxn = p_monto;

    IF v_candidatos = 1 THEN
      SELECT * INTO v_plan FROM public.plan WHERE activo AND precio_mxn = p_monto;
    ELSIF v_candidatos = 0 THEN
      RAISE EXCEPTION USING
        ERRCODE = 'GYM07', MESSAGE = 'PLAN_INVALIDO',
        DETAIL  = format('ningun plan activo cuesta %s; indica el plan_id', p_monto);
    ELSE
      RAISE EXCEPTION USING
        ERRCODE = 'GYM07', MESSAGE = 'PLAN_INVALIDO',
        DETAIL  = format('%s planes activos cuestan %s; indica el plan_id',
                         v_candidatos, p_monto);
    END IF;
  END IF;

  -- Cobertura. Se construye sobre pagado_hasta para que una renovacion continue
  -- exactamente donde termino la anterior. La base es el ultimo dia ya cubierto,
  -- o el dia previo al periodo si el socio nunca ha pagado; y se suman
  -- dias_periodo dias completos a partir de ahi.
  --
  --   1er pago, periodo 2026-02-02, plan de 30 dias -> 2026-02-01 + 30 = 2026-03-03
  --   renovacion anticipada el 2026-03-02         -> 2026-03-03 + 30 = 2026-04-02
  --
  -- greatest() es lo que evita regalar la diferencia cuando hay huecos:
  -- si el socio dejo de pagar, la base nunca retrocede, asi que un salto no
  -- concede la cobertura perdida.
  v_pagado_hasta := greatest(coalesce(v_socio.pagado_hasta, p_periodo - 1), p_periodo - 1)
                    + v_plan.dias_periodo;

  -- Las membresias vencidas se cierran antes de buscar la vigente, para no tener
  -- que decidir en codigo si una membresia "activa" con terminio pasado cuenta.
  UPDATE public.membresia
     SET estado = 'vencida'
   WHERE socio_id = p_socio_id
     AND estado = 'activa'
     AND termina_en < current_date;

  INSERT INTO public.pago (socio_id, registrado_por, monto_mxn, forma_pago, periodo, referencia)
  VALUES (p_socio_id, v_usuario, p_monto, p_forma_pago, p_periodo, p_referencia)
  RETURNING id INTO v_pago_id;

  INSERT INTO public.recibo (pago_id, estado, emitido_en)
  VALUES (v_pago_id, 'pagado', current_date)
  RETURNING id, folio INTO v_recibo_id, v_folio;

  -- UPDATE y no INSERT: pagado_hasta es un dato desnormalizado que solo escribe
  -- esta funcion (ADR-004). 0008_rls.sql le quita la columna al cliente.
  UPDATE public.socio
     SET pagado_hasta = v_pagado_hasta
   WHERE id = p_socio_id;

  SELECT * INTO v_membresia
  FROM public.membresia
  WHERE socio_id = p_socio_id
    AND estado = 'activa'
  FOR UPDATE;

  IF FOUND THEN
    UPDATE public.membresia
       SET termina_en = greatest(v_membresia.termina_en, v_pagado_hasta)
     WHERE id = v_membresia.id;
    v_termina_en := greatest(v_membresia.termina_en, v_pagado_hasta);
  ELSE
    INSERT INTO public.membresia (socio_id, plan_id, estado, inicia_en, termina_en)
    VALUES (p_socio_id, v_plan.id, 'activa', p_periodo, v_pagado_hasta)
    RETURNING termina_en INTO v_termina_en;
  END IF;

  INSERT INTO public.auditoria (usuario_id, accion, entidad, entidad_id)
  VALUES (v_usuario, 'cobro', 'pago', v_pago_id);

  RETURN jsonb_build_object(
    'pago_id',       v_pago_id,
    'recibo_id',     v_recibo_id,
    'folio',         v_folio,
    'periodo',       p_periodo,
    'monto_mxn',     p_monto,
    'forma_pago',    p_forma_pago,
    'plan_id',       v_plan.id,
    'pagado_hasta',  v_pagado_hasta,
    'termina_en',    v_termina_en
  );
EXCEPTION
  WHEN unique_violation THEN
    -- Solo puede ser la unique (socio_id, periodo) de pago: el folio es
    -- nextval sobre una secuencia y no colisiona.
    RAISE EXCEPTION USING
      ERRCODE = 'GYM01',
      MESSAGE = 'PAGO_PERIODO_YA_CUBIERTO',
      DETAIL  = format('socio_id: %s ya tiene un cobro del periodo %s', p_socio_id, p_periodo);
END
$$;

COMMENT ON FUNCTION public.registrar_pago(uuid, numeric, public.forma_pago, date, text, uuid) IS
  'Registra un cobro o una renovacion en una sola transaccion. El periodo es la fecha de inicio de cobertura (cualquier dia, 0011). Errores: GYM01, GYM02, GYM03, GYM04, GYM06, GYM07, GYM10.';
