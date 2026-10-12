-- 0008_rls.sql
-- Row Level Security y permisos por columna.
-- Ver 02 §6: "sin sesion valida no se lee ni se escribe nada" y "ocultar un boton
-- en la interfaz no es un permiso".

-- ---------------------------------------------------------------------------
-- Que protege que
-- ---------------------------------------------------------------------------
--   solo lectura      plan, membresia, pago, recibo, auditoria
--   lectura + alta    socio
--   lectura + contacto socio  (solamente datos de contacto, ver abajo)
--   lectura propia    perfil
--   todo lo demas     funciones SQL de 0007
--
-- RLS se HABILITA pero no se FUERZA. Forzarla (ALTER TABLE ... FORCE ROW LEVEL
-- SECURITY) sujetaria tambien al dueno de las tablas, y las funciones de 0007 son
-- SECURITY DEFINER: corrigen con los privilegios de ese dueno justamente para
-- poder escribir en pago, recibo y auditoria. Forzarla las dejaria sin poder
-- trabajar.

-- Los roles que PostgREST usa en Supabase. En el Postgres local de pruebas no
-- existen, y sin ellos cada REVOKE y cada GRANT de esta migracion fallaria. Se
-- crean aqui para que el modelo de permisos de produccion sea el mismo que se
-- prueba en local; en Supabase ya estan y este bloque no hace nada.
--
--   anon          la llave publica del frontend, sin sesion
--   authenticated la misma llave con un JWT de un usuario con sesion
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN NOINHERIT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN NOINHERIT;
  END IF;
END
$$;

-- Sin USAGE sobre el esquema, ningun rol puede resolver public.socio ni las
-- funciones, por mas que las politicas los dejen pasar.
GRANT USAGE ON SCHEMA public TO anon, authenticated;

ALTER TABLE public.perfil    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auditoria ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.socio     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.plan      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.membresia ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pago      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recibo    ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- Politicas
-- ---------------------------------------------------------------------------
-- es_usuario_activo() es SECURITY DEFINER (0002) para que al consultar perfil no
-- se dispare la politica de perfil. Si no, habria recursion infinita.

-- Cada quien puede leer su propia fila, activo o no: es lo que permite que la app
-- muestre "tu cuenta esta desactivada" en vez de un error generico.
CREATE POLICY perfil_leer_propio ON public.perfil
  FOR SELECT USING (id = public.usuario_actual_id());

CREATE POLICY auditoria_leer ON public.auditoria
  FOR SELECT USING (public.es_usuario_activo());

CREATE POLICY socio_leer ON public.socio
  FOR SELECT USING (public.es_usuario_activo());

CREATE POLICY socio_alta ON public.socio
  FOR INSERT WITH CHECK (public.es_usuario_activo());

CREATE POLICY socio_editar_contacto ON public.socio
  FOR UPDATE USING (public.es_usuario_activo());

CREATE POLICY plan_leer ON public.plan
  FOR SELECT USING (public.es_usuario_activo());

CREATE POLICY membresia_leer ON public.membresia
  FOR SELECT USING (public.es_usuario_activo());

CREATE POLICY pago_leer ON public.pago
  FOR SELECT USING (public.es_usuario_activo());

CREATE POLICY recibo_leer ON public.recibo
  FOR SELECT USING (public.es_usuario_activo());

-- Sin politica de INSERT / UPDATE / DELETE en pago, recibo, auditoria, plan,
-- membresia ni perfil: en ausencia de politica, el permiso se deniega (02 §6).
-- Sin politica de DELETE en socio: la eliminacion es ARCO, por eliminar_socio, que
-- ademas deja bitacora.

-- ---------------------------------------------------------------------------
-- Permisos de la llave publica
-- ---------------------------------------------------------------------------
-- La llave anon va en el frontend (es publica por diseno, 02 §6). Se le quita todo:
-- sin sesion es_usuario_activo() es false y RLS ya bloquea, pero depender solo de
-- RLS deja la puerta abierta a que una politica futura se equivoque.
REVOKE ALL ON TABLE public.perfil, public.auditoria, public.socio,
                    public.plan, public.membresia, public.pago, public.recibo
  FROM anon;

GRANT SELECT ON TABLE
  public.socio, public.plan, public.membresia, public.pago, public.recibo, public.auditoria
  TO authenticated;

-- El cliente ve su propio perfil por RLS, no por permiso de columna.
GRANT SELECT ON TABLE public.perfil TO authenticated;

-- Alta de socios y edicion de contacto.
GRANT INSERT ON TABLE public.socio TO authenticated;

-- El permiso de UPDATE se concede POR COLUMNA y no por tabla. De este modo el
-- cliente no puede escribir ni pagado_hasta (que solo escribe registrar_pago,
-- ADR-004) ni estado (que solo cambia cambiar_estado_socio, que deja la
-- justificacion en la bitacora) ni eliminado_en.
REVOKE UPDATE ON TABLE public.socio FROM authenticated;
GRANT UPDATE (nombre, apellidos, correo, telefono) ON TABLE public.socio TO authenticated;

-- La vista necesita permiso propio ademas del de sus tablas.
GRANT SELECT ON public.socios_con_estado TO authenticated;

-- ---------------------------------------------------------------------------
-- Funciones
-- ---------------------------------------------------------------------------
-- Por omision Postgres da EXECUTE a PUBLIC sobre toda funcion, y PUBLIC incluye
-- anon. Sin esto, anon podria llamar registrar_pago o eliminar_socio.
REVOKE ALL ON FUNCTION
  public.normalizar_texto(text),
  public.normalizar_telefono(text),
  public.usuario_actual_id(),
  public.es_usuario_activo(),
  public.trg_socio_auditoria_alta(),
  public.registrar_pago(uuid, numeric, public.forma_pago, date, text, uuid),
  public.cambiar_estado_socio(uuid, public.estado_socio, text),
  public.reporte_ingresos(date, date),
  public.reporte_cartera(),
  public.exportar_socio(uuid),
  public.eliminar_socio(uuid)
FROM PUBLIC;

-- Las cuatro funciones de apoyo (normalizar, usuario_actual, es_usuario_activo)
-- necesitan EXECUTE para authenticated porque aparecen dentro de las expresiones
-- de las politicas RLS, que se evaluan con los permisos de quien consulta.
GRANT EXECUTE ON FUNCTION
  public.normalizar_texto(text),
  public.normalizar_telefono(text),
  public.usuario_actual_id(),
  public.es_usuario_activo()
TO authenticated;

-- Las reglas de negocio, que es lo que el frontend llama con rpc().
GRANT EXECUTE ON FUNCTION
  public.registrar_pago(uuid, numeric, public.forma_pago, date, text, uuid),
  public.cambiar_estado_socio(uuid, public.estado_socio, text),
  public.reporte_ingresos(date, date),
  public.reporte_cartera(),
  public.exportar_socio(uuid),
  public.eliminar_socio(uuid)
TO authenticated;

-- ---------------------------------------------------------------------------
-- Secuencia de folios
-- ---------------------------------------------------------------------------
-- El folio se saca con nextval desde dentro de registrar_pago. Si el cliente
-- tuviera permiso sobre la secuencia podria encabezado a mano.
REVOKE ALL ON SEQUENCE public.recibo_folio_seq FROM anon, authenticated;