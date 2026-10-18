-- 11_planes_datos.sql
-- TICKET 000.4.1.1: editar nombre y días de un plan (0018).
--
-- Usa el prelude (Mensual 500.00/30 id 3333, Trimestral 1350.00/90 id 4444,
-- socio Jose id 5555, sesión de personal activo). Todo se revierte.

\ir _prelude.sql

-- Editar nombre y días: cambia, deja bitácora y no toca el precio.
DO $$
BEGIN
  PERFORM public.actualizar_datos_plan(
    '33333333-3333-3333-3333-333333333333', 'Mensual Plus', 35);

  IF (SELECT nombre FROM public.plan WHERE id = '33333333-3333-3333-3333-333333333333') <> 'Mensual Plus' THEN
    RAISE EXCEPTION 'FALLO: no cambio el nombre';
  END IF;
  IF (SELECT dias_periodo FROM public.plan WHERE id = '33333333-3333-3333-3333-333333333333') <> 35 THEN
    RAISE EXCEPTION 'FALLO: no cambiaron los dias';
  END IF;
  IF (SELECT precio_mxn FROM public.plan WHERE id = '33333333-3333-3333-3333-333333333333') <> 500.00 THEN
    RAISE EXCEPTION 'FALLO: editar datos toco el precio';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.auditoria
                 WHERE accion = 'cambio_datos' AND entidad = 'plan'
                   AND entidad_id = '33333333-3333-3333-3333-333333333333') THEN
    RAISE EXCEPTION 'FALLO: no dejo bitacora de cambio_datos';
  END IF;
END
$$;
\echo 'OK  editar nombre y dias deja bitacora y no toca el precio'

-- Idempotente: repetir los mismos valores no deja nueva bitácora.
DO $$
DECLARE v_antes integer; v_despues integer;
BEGIN
  SELECT count(*) INTO v_antes FROM public.auditoria WHERE accion = 'cambio_datos';
  PERFORM public.actualizar_datos_plan(
    '33333333-3333-3333-3333-333333333333', 'Mensual Plus', 35);
  SELECT count(*) INTO v_despues FROM public.auditoria WHERE accion = 'cambio_datos';
  IF v_despues <> v_antes THEN
    RAISE EXCEPTION 'FALLO: repetir los mismos datos dejo bitacora';
  END IF;
END
$$;
\echo 'OK  repetir los mismos datos es idempotente'

-- Duplicado de nombre (excluyendo el propio), nombre vacio, dias invalidos, inexistente.
DO $$
BEGIN
  BEGIN
    PERFORM public.actualizar_datos_plan(
      '33333333-3333-3333-3333-333333333333', 'Trimestral', 35);
    RAISE EXCEPTION 'FALLO: se acepto un nombre duplicado';
  EXCEPTION WHEN SQLSTATE 'GYM07' THEN NULL;
  END;

  BEGIN
    PERFORM public.actualizar_datos_plan(
      '33333333-3333-3333-3333-333333333333', '   ', 35);
    RAISE EXCEPTION 'FALLO: se acepto un nombre vacio';
  EXCEPTION WHEN SQLSTATE 'GYM07' THEN NULL;
  END;

  BEGIN
    PERFORM public.actualizar_datos_plan(
      '33333333-3333-3333-3333-333333333333', 'Mensual Plus', 400);
    RAISE EXCEPTION 'FALLO: se aceptaron dias fuera de 1-366';
  EXCEPTION WHEN SQLSTATE 'GYM07' THEN NULL;
  END;

  BEGIN
    PERFORM public.actualizar_datos_plan(
      '99999999-9999-9999-9999-999999999999', 'Fantasma', 30);
    RAISE EXCEPTION 'FALLO: se acepto un plan inexistente';
  EXCEPTION WHEN SQLSTATE 'GYM07' THEN NULL;
  END;
END
$$;
\echo 'OK  duplicado, nombre vacio, dias invalidos e inexistente rechazados con GYM07'

-- Perfil desactivado: GYM10.
SELECT set_config('app.usuario_id', '22222222-2222-2222-2222-222222222222', true);
DO $$
BEGIN
  BEGIN
    PERFORM public.actualizar_datos_plan(
      '33333333-3333-3333-3333-333333333333', 'No Deberia', 30);
    RAISE EXCEPTION 'FALLO: un perfil desactivado pudo editar el plan';
  EXCEPTION WHEN SQLSTATE 'GYM10' THEN NULL;
  END;
END
$$;
\echo 'OK  perfil desactivado recibe GYM10'

ROLLBACK;
