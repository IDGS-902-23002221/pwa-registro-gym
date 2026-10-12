-- 0009_trigger_perfil_auth.sql
-- Especifica de Supabase. En local esta migracion se omite (--objetivo supabase).
--
--   Local      ./scripts/migrate.sh                 -> no aplica 0009
--   Supabase   ./scripts/migrate.sh --objetivo supabase -> aplica 0009
--
-- Ver 02 §6: los usuarios los crea el desarrollador, no hay registros publicos.

-- migrate:require supabase

-- ---------------------------------------------------------------------------
-- Llave foranea a auth.users
-- ---------------------------------------------------------------------------
-- Se agrega aqui y no en 0002 porque el esquema "auth" es de Supabase: en el
-- Postgres local de pruebas no existe y la migracion fallaria.
ALTER TABLE public.perfil
  ADD CONSTRAINT perfil_id_fk_auth_users
  FOREIGN KEY (id) REFERENCES auth.users (id) ON DELETE CASCADE;

-- ---------------------------------------------------------------------------
-- Alta automatica de perfil
-- ---------------------------------------------------------------------------
-- Al crear un usuario en el panel de Supabase aparece una fila en perfil con
-- activo = false. El desarrollador la activa a mano desde el SQL Editor.
--
-- Que nazca desactivada es la parte importante: si un usuario se crea por error o
-- por un correo de prueba, no puede leer ni escribir nada hasta que alguien lo
-- active a proposito.
--
-- Si se decide la alta manual en lugar de este trigger, esta migracion es la
-- unica que hay que revertir (con una migracion nueva, nunca editando esta).

CREATE OR REPLACE FUNCTION public.trg_auth_crear_perfil()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_nombre text;
BEGIN
  -- El nombre va en user_metadata cuando el desarrollador lo captura. Si no esta,
  -- se usa la parte del correo antes de la arroba para que la fila no nazca vacia.
  v_nombre := coalesce(
    nullif(btrim(new.raw_user_meta_data ->> 'nombre'), ''),
    nullif(btrim(split_part(new.email, '@', 1)), ''),
    'sin nombre'
  );

  INSERT INTO public.perfil (id, nombre, rol, activo)
  VALUES (new.id, v_nombre, 'personal', false);

  RETURN NEW;
END
$$;

CREATE TRIGGER auth_crear_perfil
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.trg_auth_crear_perfil();

-- ---------------------------------------------------------------------------
-- Usuario de la sesion real
-- ---------------------------------------------------------------------------
-- En local, usuario_actual_id() lee el GUC "app.usuario_id" para que las consultas
-- de db/tests/ puedan simular una sesion. En Supabase la fuente de verdad es el
-- JWT de PostgREST, y se cambia el cuerpo de la funcion de 0002.
--
-- Con esto, si una consulta llega con la llave anon en vez de con sesion,
-- usuario_actual_id() devuelve NULL, es_usuario_activo() devuelve false y todas
-- las politicas niegan. El GUC app.usuario_id solo se usa desde psql.
CREATE OR REPLACE FUNCTION public.usuario_actual_id()
RETURNS uuid
LANGUAGE sql
STABLE
PARALLEL SAFE
AS $$
  SELECT auth.uid();
$$;

COMMENT ON FUNCTION public.usuario_actual_id() IS
  'id del usuario de la sesion, leido de auth.uid() (JWT de PostgREST).';