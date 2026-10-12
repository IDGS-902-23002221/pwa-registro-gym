-- 0006_vista_socios_con_estado.sql
-- Vista que calcula el estado visible del socio, mas los indices que la sostienen.
-- Ver 02 §4, §5 y RNF-07.

-- La vista tiene que verse exacta como la tabla socio: si se creara con la
-- semantica por defecto de Postgres, el usuario que la consulta leeria los datos
-- saltandose las politicas RLS de 0008. security_invoker = true (PostgreSQL 15+)
-- hace que se apliquen igual que en una lectura directa.
DO $$
BEGIN
  IF current_setting('server_version_num')::integer < 150000 THEN
    RAISE EXCEPTION
      'socios_con_estado necesita PostgreSQL 15 o superior (security_invoker). Servidor: %',
      current_setting('server_version');
  END IF;
END
$$;

CREATE VIEW public.socios_con_estado
WITH (security_invoker = true)
AS
SELECT
  s.id,
  s.nombre,
  s.apellidos,
  s.correo,
  s.telefono,
  s.estado,
  -- Estado visible (02 §4). No hay tarea programada que lo mantenga: se calcula
  -- al leer, asi que hoy siempre es correcto.
  CASE
    WHEN s.estado = 'pausado'                          THEN 'pausado'
    WHEN s.pagado_hasta IS NOT NULL
         AND s.pagado_hasta < current_date             THEN 'vencido'
    ELSE 'activo'
  END                                        AS estado_calculado,
  s.pagado_hasta,
  -- Texto contra el que se busca por nombre. Ya viene normalizado (sin acentos,
  -- minusculas, un solo espacio entre palabras), para que la busqueda del cliente
  -- no tenga que repetir la normalizacion. Filtrar con LIKE, no con ILIKE: sobre
  -- una columna ya en minusculas ILIKE no aprovecha el indice.
  normalizar_texto(s.nombre) || ' ' || coalesce(normalizar_texto(s.apellidos), '')
                                                  AS nombre_buscable,
  s.creado_en
FROM public.socio s
-- Un socio eliminado por ARCO deja de existir para la aplicacion. La fila se
-- conserva (02 §4: los recibos pueden tener que sobrevivir), pero no se lista.
WHERE s.eliminado_en IS NULL;

COMMENT ON VIEW public.socios_con_estado IS
  'Socios vigentes con su estado calculado: pausado, vencido o activo. Es lo que lee el frontend (02 §5).';

-- Indice de la columna nombre_buscable de la vista. Tiene que vivir en la tabla,
-- porque Postgres no indexa columnas de una vista.
CREATE INDEX socio_busquable_idx
  ON public.socio ((normalizar_texto(nombre) || ' ' || coalesce(normalizar_texto(apellidos), '')));

-- Orden por defecto del listado, que es el que hace el indice anterior utilizable
-- como escaneo remoto en vez de como filtro.
CREATE INDEX socio_vigente_idx
  ON public.socio (creado_en DESC)
  WHERE eliminado_en IS NULL;