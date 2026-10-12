-- 0010_rls_lectura_anon.sql
--
-- La 0008 le revocó TODO a anon a nivel tabla, así que sin sesión la API
-- devuelve 42501 (permission denied) en vez de lista vacía. Con este GRANT la
-- puerta la decide RLS (es_usuario_activo() = false sin sesión → 0 filas),
-- que es el diseño de 02 §6: la llave pública se filtra por políticas, no por
-- falta de permisos.
--
-- No cambia nada con sesión: authenticated ya tenía estos permisos en la 0008.

GRANT SELECT ON TABLE
  public.socio, public.plan, public.membresia, public.pago, public.recibo, public.auditoria
  TO anon;

GRANT SELECT ON public.socios_con_estado TO anon;
