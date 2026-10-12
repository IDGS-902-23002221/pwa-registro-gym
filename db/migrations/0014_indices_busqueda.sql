-- 0014_indices_busqueda.sql
--
-- RNF-07 + hallazgo 2026-10-12 (db/tests/07): el índice btree de la 0006 sobre
-- la expresión normalizada no sirve para LIKE con locale de base distinto de C
-- (mucho menos para '%término%' con comodín inicial): el plan cae a Seq Scan
-- aunque la columna esté indexada.
--
--   - GIN con pg_trgm sobre la misma expresión: cubre prefijo ('jose%') y
--     contenido ('%apellido%'). Los planes salen como Bitmap Index Scan.
--   - btree sobre pagado_hasta (solo vigentes): el conteo de vencidos filtra
--     por esa columna y no tenía índice propio.
--   - El listado ORDER BY creado_en DESC LIMIT 50 ya lo cubre socio_vigente_idx.
--
-- pg_trgm es extensión confiable: se puede crear en Supabase y en local.

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX socio_busquable_trgm_idx
  ON public.socio
  USING gin ((normalizar_texto(nombre) || ' ' || coalesce(normalizar_texto(apellidos), '')) gin_trgm_ops);

CREATE INDEX socio_vencidos_idx
  ON public.socio (pagado_hasta)
  WHERE eliminado_en IS NULL;
