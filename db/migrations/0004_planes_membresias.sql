-- 0004_planes_membresias.sql
-- Catalogo de planes y membresias.
-- Ver 02 §4.

-- ---------------------------------------------------------------------------
-- plan
-- ---------------------------------------------------------------------------
CREATE TABLE public.plan (
  id            uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre        text          NOT NULL UNIQUE CHECK (btrim(nombre) <> ''),
  -- Importes en pesos mexicanos con dos decimales (02 §4).
  precio_mxn    numeric(10,2) NOT NULL CHECK (precio_mxn > 0),
  dias_periodo  integer       NOT NULL CHECK (dias_periodo BETWEEN 1 AND 366),
  activo        boolean       NOT NULL DEFAULT true,
  creado_en     timestamptz   NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.plan IS
  'Catalogo de planes. Los datos iniciales van en db/seed.sql. En el MVP el catalogo es de solo lectura: los cambios los hace el desarrollador por SQL.';

-- ---------------------------------------------------------------------------
-- membresia
-- ---------------------------------------------------------------------------
-- No tiene columna monto: el precio vive en plan. Si alguna vez un socio paga
-- un precio distinto al del plan, la diferencia queda registrada en pago.monto_mxn,
-- no duplicada aqui.
CREATE TABLE public.membresia (
  id          uuid                  PRIMARY KEY DEFAULT gen_random_uuid(),
  socio_id    uuid                  NOT NULL REFERENCES public.socio (id) ON DELETE CASCADE,
  plan_id     uuid                  NOT NULL REFERENCES public.plan (id) ON DELETE RESTRICT,
  estado      public.estado_membresia NOT NULL DEFAULT 'activa',
  inicia_en   date                  NOT NULL,
  termina_en  date                  NOT NULL CHECK (termina_en >= inicia_en)
);

COMMENT ON TABLE  public.membresia IS
  'Vigencia que cubre cada socio. La extiende registrar_pago (0007).';
COMMENT ON COLUMN public.membresia.estado IS
  'La actualiza registrar_pago al vencer la vigencia. No la cambia el cliente (0008_rls.sql).';

-- Un socio tiene una sola membresia activa a la vez. Esto evita que registrar_pago
-- tenga que elegir entre varias filas vigentes para extender la cobertura.
CREATE UNIQUE INDEX membresia_socio_activa_uk
  ON public.membresia (socio_id)
  WHERE estado = 'activa';

-- Consulta del detalle del socio y del reporte de cartera.
CREATE INDEX membresia_socio_idx  ON public.membresia (socio_id);
CREATE INDEX membresia_plan_idx   ON public.membresia (plan_id);
CREATE INDEX membresia_vigencia_idx ON public.membresia (termina_en);