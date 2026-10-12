-- 07_rendimiento.sql
-- RNF-07: el listado y la busqueda por nombre tienen que seguir siendo rapidos con
-- 500 socios, que es el orden de magnitud del MVP.
--
-- Lo que se comprueba aqui es que Postgres usa los indices de 0006 y no un
-- escaneo completo de la tabla. El tiempo se imprime, pero no se falla por el:
-- depende del hardware, y una prueba que falla por ir un poco lento en una
-- maquina virtual no sirve para nada.

\ir _prelude.sql

-- 500 socios de prueba. generate_series evita 500 INSERTs a mano.
INSERT INTO public.socio (nombre, apellidos, telefono, correo, estado, pagado_hasta)
SELECT
  'Socio' || lpad(i::text, 4, '0'),
  'Apellido' || lpad(i::text, 4, '0'),
  '55' || lpad(i::text, 9, '0'),
  'socio' || lpad(i::text, 4, '0') || '@ejemplo.mx',
  'activo',
  CASE WHEN i % 3 = 0 THEN DATE '2026-12-31' ELSE DATE '2025-01-31' END
FROM generate_series(1, 500) AS i;

ANALYZE public.socio;

DO $$
DECLARE
  v_total bigint;
BEGIN
  SELECT count(*) INTO v_total FROM public.socio;
  IF v_total < 505 THEN
    RAISE EXCEPTION 'FALLO: se esperaban al menos 505 socios, hay %', v_total;
  END IF;
END
$$;
\echo 'OK  500 socios de prueba cargados'

-- La busqueda por nombre: el indice sobre la expresion normalizada tiene que
-- aparecer en el plan.
CREATE TEMP TABLE plan_busqueda AS
EXPLAIN (ANALYZE, FORMAT TEXT)
SELECT id, nombre, estado_calculado
FROM public.socios_con_estado
WHERE nombre_buscable LIKE 'jose perez%';

DO $$
DECLARE
  v_plan text;
BEGIN
  SELECT string_agg(query_plan, E'\n') INTO v_plan FROM plan_busqueda;

  IF v_plan NOT LIKE '%Index%' THEN
    RAISE EXCEPTION 'FALLO: la busqueda por nombre no uso un indice:%', E'\n', v_plan;
  END IF;

  IF v_plan LIKE '%Seq Scan%' THEN
    RAISE EXCEPTION 'FALLO: la busqueda por nombre hizo un escaneo secuencial:%', E'\n', v_plan;
  END IF;

  RAISE NOTICE 'plan de busqueda:%', E'\n', v_plan;
END
$$;
\echo 'OK  la busqueda por nombre usa el indice de la expresion normalizada'

-- El termino comun no puede degradar a escaneo completo.
CREATE TEMP TABLE plan_generico AS
EXPLAIN (ANALYZE, FORMAT TEXT)
SELECT id, nombre
FROM public.socios_con_estado
WHERE nombre_buscable LIKE '%apellido%';

DO $$
DECLARE
  v_plan text;
BEGIN
  SELECT string_agg(query_plan, E'\n') INTO v_plan FROM plan_generico;

  IF v_plan LIKE '%Seq Scan%' THEN
    RAISE EXCEPTION 'FALLO: una busqueda generica hizo un escaneo secuencial:%', E'\n', v_plan;
  END IF;

  RAISE NOTICE 'plan generico:%', E'\n', v_plan;
END
$$;
\echo 'OK  una busqueda generica tampoco cae a escaneo secuencial'

-- El listado paginado: ordenado por creado_en sobre los socios vigentes.
CREATE TEMP TABLE plan_listado AS
EXPLAIN (ANALYZE, FORMAT TEXT)
SELECT id, nombre, estado_calculado
FROM public.socios_con_estado
ORDER BY creado_en DESC
LIMIT 50;

DO $$
DECLARE
  v_plan text;
BEGIN
  SELECT string_agg(query_plan, E'\n') INTO v_plan FROM plan_listado;
  IF v_plan NOT LIKE '%Index%' THEN
    RAISE EXCEPTION 'FALLO: el listado no uso el indice de socios vigentes:%', E'\n', v_plan;
  END IF;
  RAISE NOTICE 'plan de listado:%', E'\n', v_plan;
END
$$;
\echo 'OK  el listado paginado usa el indice de socios vigentes'

-- Listar los vencidos tiene que filtrar por las columnas base (pagado_hasta y
-- eliminado_en), no por estado_calculado: ese CASE se calcula en cada fila de la
-- vista y no es indexable. Por eso la app lista y luego ordena en el cliente.
CREATE TEMP TABLE plan_vencidos AS
EXPLAIN (ANALYZE, FORMAT TEXT)
SELECT count(*) FROM public.socio
WHERE eliminado_en IS NULL AND pagado_hasta < current_date;

DO $$
DECLARE
  v_plan text;
BEGIN
  SELECT string_agg(query_plan, E'\n') INTO v_plan FROM plan_vencidos;
  RAISE NOTICE 'plan de vencidos:%', E'\n', v_plan;

  IF v_plan LIKE '%Seq Scan%' THEN
    RAISE EXCEPTION 'FALLO: contar vencidos hizo un escaneo secuencial:%', E'\n', v_plan;
  END IF;
END
$$;
\echo 'OK  contar vencidos no escanea la tabla completa'

ROLLBACK;