-- 0005_pagos_recibos.sql
-- Cobros, recibos y la secuencia de folios.
-- Ver 02 §4, §5 y ADR-004, ADR-006.

-- ---------------------------------------------------------------------------
-- pago
-- ---------------------------------------------------------------------------
-- Ninguna columna es actualizable desde el cliente: 0008_rls.sql quita INSERT,
-- UPDATE y DELETE al rol authenticated. Solo escribe registrar_pago (0007).
CREATE TABLE public.pago (
  id            uuid                PRIMARY KEY DEFAULT gen_random_uuid(),
  socio_id      uuid                NOT NULL REFERENCES public.socio (id) ON DELETE RESTRICT,
  -- Usuario que cobro. ON DELETE RESTRICT: el historico de quien cobro no se
  -- pierde. Si se desactiva a un empleado se usa perfil.activo = false (02 §4).
  registrado_por uuid               NOT NULL REFERENCES public.perfil (id) ON DELETE RESTRICT,
  monto_mxn     numeric(10,2)       NOT NULL CHECK (monto_mxn > 0),
  forma_pago    public.forma_pago   NOT NULL,
  -- Primer dia del mes pagado. Junto con socio_id es unico: es lo que impide
  -- cobrar dos veces el mismo periodo (02 §4).
  periodo       date                NOT NULL,
  referencia    text,
  creado_en     timestamptz        NOT NULL DEFAULT now(),

  CONSTRAINT pago_periodo_inicio_de_mes
    CHECK (periodo = date_trunc('month', periodo)::date)
);

COMMENT ON TABLE  public.pago IS
  'Cobros. Tabla de solo insercion: la escribe unicamente registrar_pago.';
COMMENT ON COLUMN public.pago.periodo IS
  'Primer dia del mes pagado. La unique (socio_id, periodo) bloquea el doble cobro.';

-- El bloqueo del doble cobro es una restriccion de la base, no una validacion del
-- formulario (02 §1, "la base es la ultima defensa"). El frontend recibe GYM01
-- desde la excepcion, no desde un if.
CREATE UNIQUE INDEX pago_socio_periodo_uk
  ON public.pago (socio_id, periodo);

-- Reporte de ingresos por periodo y forma de pago.
CREATE INDEX pago_creado_en_idx   ON public.pago (creado_en);
CREATE INDEX pago_forma_pago_idx  ON public.pago (forma_pago, periodo);
-- Historial de pagos del detalle del socio, del mas reciente al mas antiguo.
CREATE INDEX pago_socio_creado_idx ON public.pago (socio_id, creado_en DESC);

-- ---------------------------------------------------------------------------
-- Secuencia de folios
-- ---------------------------------------------------------------------------
-- El folio lo asigna la base con nextval y no un MAX(folio) + 1 calculado en la
-- aplicacion: asi dos cobros simultaneos no pueden sacar el mismo numero (02 §4).
-- nextval no se deshace con un rollback, asi que los huecos son posibles y correctos;
-- lo que no puede pasar es el duplicado.
--
-- Se crea antes que la tabla porque recibo la referencia en su DEFAULT. El OWNED BY
-- se agrega despues, cuando la columna ya existe.
CREATE SEQUENCE public.recibo_folio_seq AS integer START WITH 1;

-- ---------------------------------------------------------------------------
-- recibo
-- ---------------------------------------------------------------------------
-- Un recibo por pago (PAGO ||--|| RECIBO en 02 §4).
CREATE TABLE public.recibo (
  id          uuid                PRIMARY KEY DEFAULT gen_random_uuid(),
  pago_id     uuid                NOT NULL UNIQUE REFERENCES public.pago (id) ON DELETE RESTRICT,
  folio       integer             NOT NULL DEFAULT nextval('public.recibo_folio_seq')
                                  UNIQUE CHECK (folio > 0),
  estado      public.estado_recibo NOT NULL DEFAULT 'pagado',
  emitido_en  date                NOT NULL DEFAULT current_date
);

COMMENT ON TABLE  public.recibo IS
  'Recibos. Uno por pago. La escritura es exclusiva de registrar_pago.';
COMMENT ON COLUMN public.recibo.folio IS
  'Folio consecutivo asignado por la secuencia recibo_folio_seq.';

-- Si la tabla recibo se llegara a borrar, la secuencia se borra con ella.
ALTER SEQUENCE public.recibo_folio_seq OWNED BY public.recibo.folio;

-- Historial de recibos del detalle del socio.
CREATE INDEX recibo_pago_idx     ON public.recibo (pago_id);
CREATE INDEX recibo_emitido_en_idx ON public.recibo (emitido_en DESC);