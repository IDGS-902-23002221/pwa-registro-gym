-- 0013_rls_execute_anon.sql
--
-- Complemento de la 0010: las políticas RLS llaman a es_usuario_activo() y
-- usuario_actual_id(), que se evalúan con los permisos de quien consulta. La
-- 0008 solo les dio EXECUTE a authenticated, así que anon seguía con
-- permission denied. Sin esto, la 0010 no sirve.
--
-- Las funciones de negocio (registrar_pago, etc.) siguen solo para
-- authenticated: anon no puede llamarlas.

GRANT EXECUTE ON FUNCTION
  public.normalizar_texto(text),
  public.normalizar_telefono(text),
  public.usuario_actual_id(),
  public.es_usuario_activo()
TO anon;
