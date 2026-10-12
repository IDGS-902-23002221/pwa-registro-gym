-- 03_folio_unico.sql
-- 02 §4: el folio lo asigna la secuencia de la base, no un MAX(folio)+1 de la
-- aplicacion, para que dos cobros simultaneos no saquen el mismo numero.

\ir _prelude.sql

INSERT INTO public.socio (id, nombre, apellidos, telefono)
VALUES ('66666666-6666-6666-6666-666666666666', 'Ana', 'Lopez Diaz', '5588888888');

DO $$
DECLARE
  v_folio_1 integer;
  v_folio_2 integer;
BEGIN
  SELECT (public.registrar_pago(
           '55555555-5555-5555-5555-555555555555', 500.00, 'efectivo', DATE '2026-10-01', NULL
         )) ->> 'folio' INTO v_folio_1;

  SELECT (public.registrar_pago(
           '66666666-6666-6666-6666-666666666666', 500.00, 'efectivo', DATE '2026-10-01', NULL
         )) ->> 'folio' INTO v_folio_2;

  IF v_folio_2 <> v_folio_1 + 1 THEN
    RAISE EXCEPTION 'FALLO: los folios deberian ser consecutivos (% y %)', v_folio_1, v_folio_2;
  END IF;
END
$$;
\echo 'OK  los folios son consecutivos (nextval no se reutiliza)'

DO $$
DECLARE
  v_total     bigint;
  v_distintos bigint;
BEGIN
  SELECT count(*), count(DISTINCT folio) INTO v_total, v_distintos FROM public.recibo;
  IF v_total <> v_distintos THEN
    RAISE EXCEPTION 'FALLO: hay % recibos pero solo % folios distintos', v_total, v_distintos;
  END IF;
END
$$;
\echo 'OK  no hay folios repetidos'

-- Un recibo por pago.
DO $$
DECLARE
  v_duplicados integer;
BEGIN
  SELECT count(*) INTO v_duplicados
  FROM (SELECT pago_id FROM public.recibo GROUP BY pago_id HAVING count(*) > 1) d;
  IF v_duplicados > 0 THEN
    RAISE EXCEPTION 'FALLO: % pagos tienen mas de un recibo', v_duplicados;
  END IF;
END
$$;
\echo 'OK  cada pago tiene exactamente un recibo'

-- nextval no se deshace con un rollback: el folio se consume aunque la transaccion
-- se revierta. Eso deja huecos, que son correctos; lo que no puede pasar es que un
-- folio se reutilice. Esta verificacion existe para que el hueco no se lea como bug.
DO $$
DECLARE
  v_folio_gastado integer;
  v_siguiente     integer;
BEGIN
  BEGIN
    SELECT (public.registrar_pago(
             '55555555-5555-5555-5555-555555555555', 500.00, 'efectivo', DATE '2026-12-01', NULL
           )) ->> 'folio' INTO v_folio_gastado;
    RAISE EXCEPTION 'revierto a proposito';
  EXCEPTION WHEN OTHERS THEN
    NULL;  -- la subtransaccion se revierte: no queda ni el pago ni el recibo
  END;

  SELECT nextval('public.recibo_folio_seq') INTO v_siguiente;

  IF v_folio_gastado IS NULL THEN
    RAISE EXCEPTION 'FALLO: el cobro revertido no devolvio folio';
  END IF;
  IF v_siguiente <= v_folio_gastado THEN
    RAISE EXCEPTION 'FALLO: se gasto el folio % y el siguiente es %; un folio nunca se reutiliza',
      v_folio_gastado, v_siguiente;
  END IF;
END
$$;
\echo 'OK  un cobro revertido consume su folio (huecos permitidos, reutilizacion no)'

ROLLBACK;