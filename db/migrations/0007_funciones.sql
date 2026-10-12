-- 0007_funciones.sql
-- Reglas de negocio en Postgres (ADR-006).
-- Ver 02 §4 y §5.
--
-- Todas son SECURITY DEFINER: el cliente las llama con rpc() y por eso corren
-- con los privilegios de quien las creo, saltandose RLS a proposito. Esa es la
-- unica forma de escribir en pago, recibo y auditoria, que no admiten escritura
-- desde el cliente (02 §6).
--
-- Por eso ninguna se salta la primera comprobacion: si no hay un perfil activo
-- detras de la sesion, fallan con GYM10 antes de tocar nada.
--
-- Convencion de errores (02 §5): SQLSTATE propio por codigo de negocio, el
-- codigo en el MESSAGE y el detalle en la DETAIL. Ver la tabla en 0001.

-- ---------------------------------------------------------------------------
-- Alta de socio: bitacora
-- ---------------------------------------------------------------------------
-- 02 §5 dice que el alta es una insercion directa en socio y que ademas deja
-- bitacora. Las dos cosas a la vez se conseguiu con un trigger en vez de una
-- funcion de alta: el cliente sigue insertando (02 §5) y la bitacora no se
-- puede saltar por el camino.
CREATE OR REPLACE FUNCTION public.trg_socio_auditoria_alta()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  INSERT INTO public.auditoria (usuario_id, accion, entidad, entidad_id)
  VALUES (public.usuario_actual_id(), 'alta', 'socio', NEW.id);
  RETURN NEW;
END
$$;

CREATE TRIGGER socio_auditoria_alta
AFTER INSERT ON public.socio
FOR EACH ROW EXECUTE FUNCTION public.trg_socio_auditoria_alta();

-- ---------------------------------------------------------------------------
-- registrar_pago
-- ---------------------------------------------------------------------------
-- Cobro o renovacion. Hace pago + recibo + folio + pagado_hasta + vigencia de la
-- membresia + bitacora en una sola transaccion (02 §5, ADR-006). Si algo falla,
-- no queda nada a medias.
--
-- Renovar es registrar el pago del siguiente periodo, con esta misma funcion.
--
-- p_plan_id es opcional y es una adicion a la firma de 02 §5. Se necesita porque
-- el pago guarda el monto, no el plan, y la membresia guarda el plan: sin el
-- parametro habia que deducir el plan por precio, lo que falla en cuanto haya dos
-- planes con el mismo monto. Si se omite, se deduce por precio y si la deduccion
-- es ambigua o no encuentra nada se falla con GYM07 en vez de adivinar.
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

  IF p_periodo IS NULL OR p_periodo <> date_trunc('month', p_periodo)::date THEN
    RAISE EXCEPTION USING
      ERRCODE = 'GYM06',
      MESSAGE = 'PERIODO_INVALIDO',
      DETAIL  = format('el periodo debe ser el primer dia del mes; recibido: %s',
                       coalesce(p_periodo::text, 'null'));
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
  --   1er pago, periodo 2026-10-01, plan de 30 dias -> 2026-09-30 + 30 = 2026-10-30
  --   renovacion, periodo 2026-11-01              -> 2026-10-31 + 30 = 2026-11-30
  --
  -- greatest() es lo que evita regalar la diferencia cuando hay meses de por medio:
  -- si el socio dejo de pagar, la base nunca retrocede, asi que un salto de dos
  -- meses no concede la cobertura perdida.
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
  'Registra un cobro o una renovacion en una sola transaccion. Errores: GYM01, GYM02, GYM03, GYM04, GYM06, GYM07, GYM10.';

-- ---------------------------------------------------------------------------
-- cambiar_estado_socio
-- ---------------------------------------------------------------------------
-- Pausar y reactivar (02 §5). Pasar por la funcion y no por un UPDATE directo es
-- lo que garantiza que quede la justificacion en la bitacora.
CREATE OR REPLACE FUNCTION public.cambiar_estado_socio(
  p_socio_id      uuid,
  p_estado        public.estado_socio,
  p_justificacion text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_socio public.socio%ROWTYPE;
BEGIN
  IF NOT public.es_usuario_activo() THEN
    RAISE EXCEPTION USING
      ERRCODE = 'GYM10', MESSAGE = 'PERFIL_INACTIVO',
      DETAIL  = 'La sesion no corresponde a un perfil activo. Operacion cancelada.';
  END IF;

  IF p_justificacion IS NULL OR btrim(p_justificacion) = '' THEN
    RAISE EXCEPTION USING
      ERRCODE = 'GYM09', MESSAGE = 'JUSTIFICACION_REQUERIDA',
      DETAIL  = 'Pausar y reactivar exigen justificacion: queda en la bitacora.';
  END IF;

  SELECT * INTO v_socio FROM public.socio WHERE id = p_socio_id FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING
      ERRCODE = 'GYM02', MESSAGE = 'SOCIO_NO_ENCONTRADO',
      DETAIL  = format('socio_id: %s', p_socio_id);
  END IF;

  IF v_socio.eliminado_en IS NOT NULL THEN
    RAISE EXCEPTION USING
      ERRCODE = 'GYM03', MESSAGE = 'SOCIO_YA_ELIMINADO',
      DETAIL  = format('socio_id: %s', p_socio_id);
  END IF;

  IF v_socio.estado = p_estado THEN
    RAISE EXCEPTION USING
      ERRCODE = 'GYM08', MESSAGE = 'ESTADO_SOCIO_INVALIDO',
      DETAIL  = format('el socio ya esta en estado %s', p_estado);
  END IF;

  UPDATE public.socio SET estado = p_estado WHERE id = p_socio_id;

  INSERT INTO public.auditoria (usuario_id, accion, entidad, entidad_id, justificacion)
  VALUES (public.usuario_actual_id(), 'cambio_estado', 'socio', p_socio_id, btrim(p_justificacion));
END
$$;

COMMENT ON FUNCTION public.cambiar_estado_socio(uuid, public.estado_socio, text) IS
  'Pausa o reactiva un socio con justificacion, dejando bitacora. Errores: GYM02, GYM03, GYM08, GYM09, GYM10.';

-- ---------------------------------------------------------------------------
-- reporte_ingresos
-- ---------------------------------------------------------------------------
-- SECURITY DEFINER por una sola razon: poder fallar con GYM10 cuando el usuario no
-- esta activo. Si se dejara en modo invoker, RLS devolveria cero filas y el
-- frontend no podria distinguir "no hay ingresos" de "no tienes permiso".
CREATE OR REPLACE FUNCTION public.reporte_ingresos(p_desde date, p_hasta date)
RETURNS TABLE (
  forma_pago    public.forma_pago,
  total_mxn     numeric(12,2),
  cantidad      bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.es_usuario_activo() THEN
    RAISE EXCEPTION USING
      ERRCODE = 'GYM10', MESSAGE = 'PERFIL_INACTIVO',
      DETAIL  = 'La sesion no corresponde a un perfil activo.';
  END IF;

  IF p_desde IS NULL OR p_hasta IS NULL OR p_desde > p_hasta THEN
    RAISE EXCEPTION USING
      ERRCODE = 'GYM06', MESSAGE = 'PERIODO_INVALIDO',
      DETAIL  = format('rango invalido: desde %s hasta %s',
                       coalesce(p_desde::text, 'null'), coalesce(p_hasta::text, 'null'));
  END IF;

  RETURN QUERY
  SELECT pg.forma_pago, sum(pg.monto_mxn)::numeric(12,2), count(*)
  FROM public.pago pg
  WHERE pg.periodo >= date_trunc('month', p_desde)::date
    AND pg.periodo <= p_hasta
  GROUP BY pg.forma_pago
  ORDER BY pg.forma_pago;
END
$$;

COMMENT ON FUNCTION public.reporte_ingresos(date, date) IS
  'Ingresos agrupados por forma de pago para un rango de periodos. Errores: GYM06, GYM10.';

-- ---------------------------------------------------------------------------
-- reporte_cartera
-- ---------------------------------------------------------------------------
-- Vencidos y dias de mora (02 §5). Solo lectura sobre la vista, asi que no puede
-- devolver a un socio eliminado.
CREATE OR REPLACE FUNCTION public.reporte_cartera()
RETURNS TABLE (
  socio_id     uuid,
  nombre       text,
  apellidos    text,
  telefono     text,
  pagado_hasta date,
  dias_mora    integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.es_usuario_activo() THEN
    RAISE EXCEPTION USING
      ERRCODE = 'GYM10', MESSAGE = 'PERFIL_INACTIVO',
      DETAIL  = 'La sesion no corresponde a un perfil activo.';
  END IF;

  RETURN QUERY
  SELECT v.id, v.nombre, v.apellidos, v.telefono, v.pagado_hasta,
         (current_date - v.pagado_hasta)::integer
  FROM public.socios_con_estado v
  WHERE v.estado_calculado = 'vencido'
  ORDER BY v.pagado_hasta, v.nombre;
END
$$;

COMMENT ON FUNCTION public.reporte_cartera() IS
  'Socios vencidos con sus dias de mora. Errores: GYM10.';

-- ---------------------------------------------------------------------------
-- exportar_socio (ARCO)
-- ---------------------------------------------------------------------------
-- Derecho de acceso: entrega todo lo del socio en un solo objeto y deja bitacora
-- de que se exporto, porque una exportación de datos personales es un evento que
-- conviene poder rastrear (02 §5).
CREATE OR REPLACE FUNCTION public.exportar_socio(p_socio_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_socio public.socio%ROWTYPE;
BEGIN
  IF NOT public.es_usuario_activo() THEN
    RAISE EXCEPTION USING
      ERRCODE = 'GYM10', MESSAGE = 'PERFIL_INACTIVO',
      DETAIL  = 'La sesion no corresponde a un perfil activo.';
  END IF;

  SELECT * INTO v_socio FROM public.socio WHERE id = p_socio_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING
      ERRCODE = 'GYM02', MESSAGE = 'SOCIO_NO_ENCONTRADO',
      DETAIL  = format('socio_id: %s', p_socio_id);
  END IF;

  INSERT INTO public.auditoria (usuario_id, accion, entidad, entidad_id)
  VALUES (public.usuario_actual_id(), 'exportar', 'socio', p_socio_id);

  RETURN jsonb_build_object(
    'socio', jsonb_build_object(
      'id',           v_socio.id,
      'nombre',       v_socio.nombre,
      'apellidos',    v_socio.apellidos,
      'correo',       v_socio.correo,
      'telefono',     v_socio.telefono,
      'estado',       v_socio.estado,
      'pagado_hasta', v_socio.pagado_hasta,
      'creado_en',    v_socio.creado_en,
      'eliminado_en', v_socio.eliminado_en
    ),
    'membresias', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
               'plan',      pl.nombre,
               'estado',    m.estado,
               'inicia_en', m.inicia_en,
               'termina_en', m.termina_en
             ) ORDER BY m.inicia_en)
      FROM public.membresia m
      JOIN public.plan pl ON pl.id = m.plan_id
      WHERE m.socio_id = p_socio_id
    ), '[]'::jsonb),
    'pagos', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
               'periodo',    pg.periodo,
               'monto_mxn',  pg.monto_mxn,
               'forma_pago', pg.forma_pago,
               'referencia', pg.referencia,
               'folio',      r.folio,
               'creado_en',  pg.creado_en
             ) ORDER BY pg.periodo DESC)
      FROM public.pago pg
      LEFT JOIN public.recibo r ON r.pago_id = pg.id
      WHERE pg.socio_id = p_socio_id
    ), '[]'::jsonb)
  );
END
$$;

COMMENT ON FUNCTION public.exportar_socio(uuid) IS
  'Exporta los datos de un socio (derecho de acceso) y deja bitacora. Errores: GYM02, GYM10.';

-- ---------------------------------------------------------------------------
-- eliminar_socio (ARCO)
-- ---------------------------------------------------------------------------
-- 02 §4 deja abierta la duda de si los recibos deben conservarse por obligacion
-- fiscal ("por verificar con contador y abogado") y por eso no se borra nada: se
-- anonimiza al socio y se conservan pagos, recibos y bitacora.
--
-- El criterio es que hacia los dos lados se puede corregir despues con una
-- migracion nueva (ADR-008); borrar datos personales de forma definitiva y luego
-- arrepentirse no tiene vuelta atras. Si el contador confirma que no hay
-- obligacion de conservar los recibos, se cambia el cuerpo de esta funcion por un
-- DELETE en cascada en una migracion nueva: el resto del esquema no depende de la
-- eleccion.
--
-- La anonimizacion es real: nombre y apellidos quedan sin el dato, el telefono se
-- pone NULL para salir del indice de identidad unico, y eliminado_en saca la fila
-- de la vista. Lo que sobrevive es el id, y con el nada se puede reconstruir al socio.
CREATE OR REPLACE FUNCTION public.eliminar_socio(p_socio_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_socio public.socio%ROWTYPE;
BEGIN
  IF NOT public.es_usuario_activo() THEN
    RAISE EXCEPTION USING
      ERRCODE = 'GYM10', MESSAGE = 'PERFIL_INACTIVO',
      DETAIL  = 'La sesion no corresponde a un perfil activo.';
  END IF;

  SELECT * INTO v_socio FROM public.socio WHERE id = p_socio_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING
      ERRCODE = 'GYM02', MESSAGE = 'SOCIO_NO_ENCONTRADO',
      DETAIL  = format('socio_id: %s', p_socio_id);
  END IF;

  IF v_socio.eliminado_en IS NOT NULL THEN
    RAISE EXCEPTION USING
      ERRCODE = 'GYM03', MESSAGE = 'SOCIO_YA_ELIMINADO',
      DETAIL  = format('socio_id: %s ya fue anonimizado el %s', p_socio_id, v_socio.eliminado_en);
  END IF;

  UPDATE public.socio
     SET nombre       = 'ELIMINADO',
         apellidos    = NULL,
         correo       = NULL,
         telefono     = NULL,
         pagado_hasta = NULL,
         eliminado_en = now()
   WHERE id = p_socio_id;

  INSERT INTO public.auditoria (usuario_id, accion, entidad, entidad_id, justificacion)
  VALUES (
    public.usuario_actual_id(),
    'eliminacion',
    'socio',
    p_socio_id,
    'Anonimizacion por derechos ARCO (datos personales). Pagos y recibos conservados.'
  );
END
$$;

COMMENT ON FUNCTION public.eliminar_socio(uuid) IS
  'Anonimiza al socio por ARCO; conserva pagos, recibos y bitacora. Errores: GYM02, GYM03, GYM10.';