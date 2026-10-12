-- 07_rendimiento.sql
-- RNF-07: el listado y la busqueda por nombre tienen que seguir siendo rapidos con
-- 500 socios, que es el orden de magnitud del MVP.
--
-- Lo que se comprueba aqui es que Postgres usa los indices de 0006/0014 y no un
-- escaneo completo de la tabla. El tiempo se imprime, pero no se falla por el:
-- depende del hardware, y una prueba que falla por ir un poco lento en una
-- maquina virtual no sirve para nada.
--
-- Por que 20000 y no 500: con 500 filas el planificador elige Seq Scan aunque el
-- indice sirva (verificado: es la opción más barata y correcta a esa escala).
-- Para probar USO de índices hay que darle una escala donde el índice gane.

\ir _prelude.sql

-- 20000 socios con NOMBRES DIVERSOS (no 'Socio0001'): si todos comparten las
-- mismas palabras, todos comparten trigramas y ningún índice de texto puede
-- ganarle al Seq Scan. Con datos como los reales, el GIN sí gana.
INSERT INTO public.socio (nombre, apellidos, telefono, correo, estado, pagado_hasta)
SELECT
  (ARRAY['Ana','Luis','María','José','Carmen','Pedro','Lucía','Miguel','Elena','Jorge','Sofía','Diego','Valeria','Hugo','Renata'])[1 + (i % 15)] || ' ' || i,
  (ARRAY['García','López','Pérez','Ruiz','Torres','Vega','Mora','Soto','Ríos','Nava'])[1 + (i % 10)] || ' ' || (i % 97),
  '55' || lpad(i::text, 9, '0'),
  'socio' || lpad(i::text, 5, '0') || '@ejemplo.mx',
  'activo',
  CASE WHEN i % 100 = 0 THEN DATE '2025-01-31' ELSE DATE '2026-12-31' END
FROM generate_series(1, 20000) AS i;

ANALYZE public.socio;

-- REINDEX del GIN dentro de esta misma transacción (al final se hace ROLLBACK
-- y todo queda como estaba). Por qué: los ciclos de prueba (insertar 20000 y
-- revertir) inflan el índice a cientos de páginas vacías y ANALYZE no actualiza
-- esa estadística del índice; el planificador lo ve gigante y prefiere Seq Scan
-- aunque sirva. Recién construido, el plan sí lo elige. En producción el índice
-- está compacto y no hace falta nada.
REINDEX INDEX public.socio_busquable_trgm_idx;

DO $$
DECLARE
  v_total bigint;
BEGIN
  SELECT count(*) INTO v_total FROM public.socio;
  IF v_total < 20001 THEN
    RAISE EXCEPTION 'FALLO: se esperaban al menos 20001 socios (1 del prelude + 20000), hay %', v_total;
  END IF;
END
$$;
\echo 'OK  20000 socios de prueba cargados'

-- La busqueda por nombre: el indice sobre la expresion normalizada tiene que
-- aparecer en el plan. (EXPLAIN no puede ir en un CREATE TABLE AS, así que el
-- plan se recorre con FOR ... IN EXECUTE.)
DO $$
DECLARE
  v_plan text := '';
  r record;
BEGIN
  FOR r IN EXECUTE
    $q$EXPLAIN SELECT id, nombre, estado_calculado
       FROM public.socios_con_estado
       WHERE nombre_buscable LIKE 'jose perez%'$q$
  LOOP
    v_plan := v_plan || E'\n' || r."QUERY PLAN";
  END LOOP;

  IF v_plan NOT LIKE '%Index%' THEN
    RAISE EXCEPTION 'FALLO: la busqueda por nombre no uso un indice:%', v_plan;
  END IF;

  IF v_plan LIKE '%Seq Scan%' THEN
    RAISE EXCEPTION 'FALLO: la busqueda por nombre hizo un escaneo secuencial:%', v_plan;
  END IF;

  RAISE NOTICE 'plan de busqueda:%', v_plan;
END
$$;
\echo 'OK  la busqueda por nombre usa el indice de la expresion normalizada'

-- El termino con comodín inicial también debe usar el índice de trigramas (0014),
-- no degradar a escaneo. 'Pérez 42' existe en un puñado de filas (apellido % 10
-- y sufijo % 97 se combinan cada 970), así que el GIN lo aísla.
DO $$
DECLARE
  v_plan text := '';
  r record;
BEGIN
  FOR r IN EXECUTE
    $q$EXPLAIN SELECT id, nombre
       FROM public.socios_con_estado
       WHERE nombre_buscable LIKE '%erez 42%'$q$
  LOOP
    v_plan := v_plan || E'\n' || r."QUERY PLAN";
  END LOOP;

  IF v_plan LIKE '%Seq Scan%' THEN
    RAISE EXCEPTION 'FALLO: una busqueda generica hizo un escaneo secuencial:%', v_plan;
  END IF;

  RAISE NOTICE 'plan generico:%', v_plan;
END
$$;
\echo 'OK  una busqueda generica tampoco cae a escaneo secuencial'

-- El listado paginado: ordenado por creado_en sobre los socios vigentes.
DO $$
DECLARE
  v_plan text := '';
  r record;
BEGIN
  FOR r IN EXECUTE
    $q$EXPLAIN SELECT id, nombre, estado_calculado
       FROM public.socios_con_estado
       ORDER BY creado_en DESC
       LIMIT 50$q$
  LOOP
    v_plan := v_plan || E'\n' || r."QUERY PLAN";
  END LOOP;

  IF v_plan NOT LIKE '%Index%' THEN
    RAISE EXCEPTION 'FALLO: el listado no uso el indice de socios vigentes:%', v_plan;
  END IF;
  RAISE NOTICE 'plan de listado:%', v_plan;
END
$$;
\echo 'OK  el listado paginado usa el indice de socios vigentes'

-- Listar los vencidos tiene que filtrar por las columnas base (pagado_hasta y
-- eliminado_en), no por estado_calculado: ese CASE se calcula en cada fila de la
-- vista y no es indexable. Por eso la app lista y luego ordena en el cliente.
DO $$
DECLARE
  v_plan text := '';
  r record;
BEGIN
  FOR r IN EXECUTE
    $q$EXPLAIN SELECT count(*) FROM public.socio
       WHERE eliminado_en IS NULL AND pagado_hasta < current_date$q$
  LOOP
    v_plan := v_plan || E'\n' || r."QUERY PLAN";
  END LOOP;

  RAISE NOTICE 'plan de vencidos:%', v_plan;

  IF v_plan LIKE '%Seq Scan%' THEN
    RAISE EXCEPTION 'FALLO: contar vencidos hizo un escaneo secuencial:%', v_plan;
  END IF;
END
$$;
\echo 'OK  contar vencidos no escanea la tabla completa'

ROLLBACK;