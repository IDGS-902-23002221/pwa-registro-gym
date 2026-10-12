-- 06_rls.sql
-- 02 §6: el frontend usa la llave publica (anon) o una sesion (authenticated), nunca
-- el dueno de las tablas. Estas pruebas cambian de rol con SET ROLE para que las
-- politicas se apliquen de verdad, en lugar de confiar en que estan escritas bien.
--
-- Por eso estas pruebas solo corren en local: el dueno de las tablas en Supabase es
-- un rol al que un operador no puede_switchear en sesion.

\ir _prelude.sql

-- La llave publica, sin sesion, no lee nada. Se limpia el GUC que dejó el
-- prelude: un anon real nunca trae app.usuario_id puesto, y sin limpiarlo RLS
-- vería al usuario activo anterior.
SELECT set_config('app.usuario_id', '', true);
SET ROLE anon;
DO $$
DECLARE
  v_conteo bigint;
BEGIN
  SELECT count(*) INTO v_conteo FROM public.socio;
  IF v_conteo <> 0 THEN
    RAISE EXCEPTION 'FALLO: anon leyo % socios sin sesion', v_conteo;
  END IF;

  SELECT count(*) INTO v_conteo FROM public.auditoria;
  IF v_conteo <> 0 THEN
    RAISE EXCEPTION 'FALLO: anon leyo % filas de bitacora sin sesion', v_conteo;
  END IF;
END
$$;
\echo 'OK  anon no lee socios ni bitacora'
RESET ROLE;

-- Una sesion de un perfil desactivado tampoco lee: desactivado es cero permisos,
-- no solo "no puede escribir" (02 §6).
SELECT set_config('app.usuario_id', '22222222-2222-2222-2222-222222222222', true);
SET ROLE authenticated;
DO $$
DECLARE
  v_conteo bigint;
BEGIN
  SELECT count(*) INTO v_conteo FROM public.socio;
  IF v_conteo <> 0 THEN
    RAISE EXCEPTION 'FALLO: un perfil desactivado leyo % socios', v_conteo;
  END IF;
END
$$;
\echo 'OK  un perfil desactivado no lee nada'
RESET ROLE;

-- El mismo rol con un perfil activo si lee.
SELECT set_config('app.usuario_id', '11111111-1111-1111-1111-111111111111', true);
SET ROLE authenticated;
DO $$
DECLARE
  v_conteo bigint;
BEGIN
  SELECT count(*) INTO v_conteo FROM public.socio;
  IF v_conteo < 1 THEN
    RAISE EXCEPTION 'FALLO: un perfil activo leyo % socios, se esperaba al menos 1', v_conteo;
  END IF;
END
$$;
\echo 'OK  un perfil activo lee los socios'

-- Puede corregir su telefono: es el dato que mas se toca y el unico que el MVP
-- deja escribir directamente.
DO $$
DECLARE
  v_telefono text;
BEGIN
  UPDATE public.socio SET telefono = '5519999999' WHERE id = '55555555-5555-5555-5555-555555555555';
  SELECT telefono INTO v_telefono FROM public.socio WHERE id = '55555555-5555-5555-5555-555555555555';
  IF v_telefono <> '5519999999' THEN
    RAISE EXCEPTION 'FALLO: no se pudo corregir el telefono, quedo %', v_telefono;
  END IF;
END
$$;
\echo 'OK  el perfil activo puede corregir el telefono'

-- Pero pagado_hasta no: lo escribe registrar_pago(). Sin esto, cualquiera podria
-- "pagar" a un socio desde el cliente con una llamada REST suelta.
DO $$
BEGIN
  BEGIN
    UPDATE public.socio SET pagado_hasta = DATE '2030-01-01'
    WHERE id = '55555555-5555-5555-5555-555555555555';
    RAISE EXCEPTION 'FALLO: el cliente pudo escribir pagado_hasta';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;  -- 42501: la columna no esta en el GRANT
  END;
END
$$;
\echo 'OK  pagado_hasta no se puede escribir desde el cliente'

-- Tampoco puede cambiar el estado a mano: pasa por cambiar_estado_socio(), que
-- exige motivo y deja registro.
DO $$
BEGIN
  BEGIN
    UPDATE public.socio SET estado = 'pausado'
    WHERE id = '55555555-5555-5555-5555-555555555555';
    RAISE EXCEPTION 'FALLO: el cliente pudo cambiar el estado del socio a mano';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
END
$$;
\echo 'OK  el estado del socio no se puede cambiar a mano'

-- El alta de socio SÍ entra por el cliente: es la vía auditada (el trigger de
-- 0007 escribe la bitácora). Lo que no puede es borrar.
DO $$
DECLARE
  v_id uuid;
  v_altas integer;
BEGIN
  INSERT INTO public.socio (nombre, apellidos, telefono)
  VALUES ('Intruso', 'Auditado', '5500000000')
  RETURNING id INTO v_id;

  SELECT count(*) INTO v_altas
  FROM public.auditoria
  WHERE accion = 'alta' AND entidad = 'socio' AND entidad_id = v_id;
  IF v_altas <> 1 THEN
    RAISE EXCEPTION 'FALLO: el alta del cliente no dejo bitacora';
  END IF;

  BEGIN
    DELETE FROM public.socio WHERE id = '55555555-5555-5555-5555-555555555555';
    RAISE EXCEPTION 'FALLO: el cliente pudo borrar un socio';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
END
$$;
\echo 'OK  el alta del cliente deja bitacora y no puede borrar socios'

-- El perfil no se autoedita: el rol no es un parametro de la sesion.
DO $$
BEGIN
  BEGIN
    UPDATE public.perfil SET activo = false WHERE id = '11111111-1111-1111-1111-111111111111';
    RAISE EXCEPTION 'FALLO: el cliente pudo desactivar su propio perfil';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
END
$$;
\echo 'OK  el perfil no se autoedita'

-- Los pagos se registran por la funcion, no por un INSERT del cliente.
DO $$
BEGIN
  BEGIN
    INSERT INTO public.pago (socio_id, monto_mxn, forma_pago, periodo)
    VALUES ('55555555-5555-5555-5555-555555555555', 500.00, 'efectivo', DATE '2026-10-01');
    RAISE EXCEPTION 'FALLO: el cliente pudo insertar un pago directo';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
END
$$;
\echo 'OK  los pagos solo entran por registrar_pago()'

-- La bitacora no se puede escribir ni borrar: es la prueba de que la decision se
-- tomo.
DO $$
BEGIN
  BEGIN
    DELETE FROM public.auditoria;
    RAISE EXCEPTION 'FALLO: el cliente pudo borrar la bitacora';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
END
$$;
\echo 'OK  la bitacora es de solo lectura para el cliente'

RESET ROLE;

-- Y con la sesion perdida, ni siquiera las funciones dejan operar.
SELECT set_config('app.usuario_id', '', true);
DO $$
BEGIN
  BEGIN
    PERFORM public.registrar_pago(
      '55555555-5555-5555-5555-555555555555', 500.00, 'efectivo', DATE '2026-10-01', NULL
    );
    RAISE EXCEPTION 'FALLO: se cobro sin sesion';
  EXCEPTION WHEN SQLSTATE 'GYM10' THEN
    NULL;  -- PERFIL_INACTIVO
  END;
END
$$;
\echo 'OK  sin sesion las funciones de negocio rechazan la operacion'

ROLLBACK;