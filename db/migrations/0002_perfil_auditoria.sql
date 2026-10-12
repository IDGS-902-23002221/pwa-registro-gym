-- 0002_perfil_auditoria.sql
-- Tablas de personal y bitacora, mas el resolvedor del usuario de la sesion.
-- Ver 02 §4, §6 y 03 §1.

-- ---------------------------------------------------------------------------
-- perfil
-- ---------------------------------------------------------------------------
-- El id es el mismo de Supabase Auth (02 §4). La llave foranea a auth.users NO se
-- crea aqui: el esquema "auth" no existe en el Postgres local de pruebas y la
-- migracion fallaria. Se agrega en 0009_trigger_perfil_auth.sql, que es
-- especifica de Supabase.
CREATE TABLE public.perfil (
  id         uuid        PRIMARY KEY,
  nombre     text        NOT NULL CHECK (btrim(nombre) <> ''),
  rol        public.rol  NOT NULL DEFAULT 'personal',
  -- False por defecto: un usuario recien creado no puede operar hasta que el
  -- desarrollador lo activa a mano. Asi un alta accidental en Auth no concede
  -- acceso al sistema.
  activo     boolean     NOT NULL DEFAULT false,
  creado_en  timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE  public.perfil IS
  'Personal autorizado. Creado por el trigger de auth.users (0009) o a mano.';
COMMENT ON COLUMN public.perfil.activo IS
  'Si es false, el usuario no lee ni escribe nada (02 §6). Desactivar en vez de borrar conserva el historico.';

-- ---------------------------------------------------------------------------
-- auditoria
-- ---------------------------------------------------------------------------
-- Bitacora append-only: 0008_rls.sql no da permiso de update ni de delete al
-- cliente, y no existe ninguna funcion que modifique una fila ya escrita.
--
-- 02 §4 lista accion = alta|cambio_estado|cobro. Se agregan 'exportar' y
-- 'eliminacion' porque 02 §5 exige bitacora tambien en el alta del socio, en la
-- pausa/reactivacion, en el cobro y en las dos operaciones de ARCO.
CREATE TABLE public.auditoria (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id    uuid        REFERENCES public.perfil (id) ON DELETE SET NULL,
  accion        text        NOT NULL
                            CHECK (accion IN ('alta', 'cambio_estado', 'cobro', 'exportar', 'eliminacion')),
  entidad       text        NOT NULL
                            CHECK (entidad IN ('socio', 'membresia', 'pago')),
  entidad_id    uuid        NOT NULL,
  justificacion text,
  ocurrido_en   timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.auditoria IS
  'Bitacora append-only. Solo escriben los triggers y las funciones SQL; el cliente no puede modificarla.';

CREATE INDEX auditoria_ocurrido_en_idx ON public.auditoria (ocurrido_en DESC);
CREATE INDEX auditoria_entidad_idx      ON public.auditoria (entidad, entidad_id);
CREATE INDEX auditoria_usuario_idx      ON public.auditoria (usuario_id);

-- ---------------------------------------------------------------------------
-- Usuario de la sesion
-- ---------------------------------------------------------------------------
-- Las funciones SQL y las politicas RLS necesitan saber quien esta operando.
--
-- En local este stub lee el GUC "app.usuario_id", que las consultas de
-- db/tests/ fijan con SET app.usuario_id = '...' para simular una sesion sin
-- depender de Supabase Auth.
--
-- En Supabase, 0009 reemplaza el cuerpo por auth.uid(). Por eso el stub devuelve
-- NULL y no falla: simplemente no hay sesion.
CREATE OR REPLACE FUNCTION public.usuario_actual_id()
RETURNS uuid
LANGUAGE sql
STABLE
PARALLEL SAFE
AS $$
  SELECT nullif(current_setting('app.usuario_id', true), '')::uuid;
$$;

COMMENT ON FUNCTION public.usuario_actual_id() IS
  'id del usuario de la sesion. Local: GUC app.usuario_id. Supabase: auth.uid() (0009).';

-- ---------------------------------------------------------------------------
-- Usuario activo
-- ---------------------------------------------------------------------------
-- "¿Este usuario puede operar?" es la condicion de todas las politicas RLS de 0008
-- y la primera comprobacion de todas las funciones SQL de 0007.
--
-- Va aqui y no en 0008 por dos razones:
--   1. Las funciones de 0007 la necesitan, y las migraciones se aplican en orden.
--   2. Es SECURITY DEFINER a proposito. Una politica RLS que consultara perfil
--      dispararia la politica RLS de perfil, que a su vez la consultaria otra vez:
--      recursion infinita. Al ser SECURITY DEFINER la consulta corre con los
--      privilegios del dueno (el rol que aplica las migraciones) y no vuelve a
--      pasar por RLS.
CREATE OR REPLACE FUNCTION public.es_usuario_activo()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.perfil p
    WHERE p.id = public.usuario_actual_id()
      AND p.activo
  );
$$;

COMMENT ON FUNCTION public.es_usuario_activo() IS
  'true si la sesion actual corresponde a un perfil activo. Sin sesion devuelve false, no NULL.';