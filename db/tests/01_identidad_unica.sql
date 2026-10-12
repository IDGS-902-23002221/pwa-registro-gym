-- 01_identidad_unica.sql
-- 02 §4: el indice de identidad debe impedir el socio duplicado y normalizar
-- acentos, mayusculas y espacios. Y el mismo nombre con otro telefono solo avisa,
-- no bloquea.

\ir _prelude.sql

-- El alta ya debio dejar bitacora gracias al trigger de 0007.
DO $$
DECLARE
  v_conteo integer;
BEGIN
  SELECT count(*) INTO v_conteo
  FROM public.auditoria
  WHERE accion = 'alta' AND entidad = 'socio'
    AND entidad_id = '55555555-5555-5555-5555-555555555555';

  IF v_conteo <> 1 THEN
    RAISE EXCEPTION 'FALLO: el alta del socio debio dejar 1 fila de bitacora, hay %', v_conteo;
  END IF;
END
$$;
\echo 'OK  el alta del socio se registro en la bitacora'

-- La normalizacion: acentos, mayusculas y espacios repetidos.
DO $$
BEGIN
  IF public.normalizar_texto('  José   PÉREZ  ') IS DISTINCT FROM 'jose perez' THEN
    RAISE EXCEPTION 'FALLO: normalizar_texto devolvio %', public.normalizar_texto('  José   PÉREZ  ');
  END IF;
  IF public.normalizar_telefono('(55) 1234-5678') IS DISTINCT FROM '5512345678' THEN
    RAISE EXCEPTION 'FALLO: normalizar_telefono devolvio %', public.normalizar_telefono('(55) 1234-5678');
  END IF;
  IF public.normalizar_texto('   ') IS NOT NULL THEN
    RAISE EXCEPTION 'FALLO: un texto solo con espacios deberia normalizar a NULL';
  END IF;
END
$$;
\echo 'OK  la normalizacion de texto y telefono'

-- El duplicado real: mismo nombre, apellidos y telefono con otra ortografia.
DO $$
BEGIN
  BEGIN
    INSERT INTO public.socio (nombre, apellidos, telefono)
    VALUES ('JOSE', 'perez ramirez', '55 1234 5678');
    RAISE EXCEPTION 'FALLO: se acepto un socio duplicado';
  EXCEPTION WHEN unique_violation THEN
    NULL;  -- es lo que queremos
  END;
END
$$;
\echo 'OK  el socio duplicado fue rechazado por el indice unico'

-- Mismo nombre con OTRO telefono: 02 §4 dice que solo genera un aviso, no bloqueo.
DO $$
DECLARE
  v_id uuid;
BEGIN
  INSERT INTO public.socio (nombre, apellidos, telefono)
  VALUES ('Jose', 'Perez Ramirez', '5599999999')
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'FALLO: no se pudo crear un homonimo con otro telefono';
  END IF;
END
$$;
\echo 'OK  el mismo nombre con otro telefono si se puede registrar'

-- Sin telefono no hay forma de saber si es el mismo socio, asi que no bloquea.
DO $$
DECLARE
  v_id uuid;
BEGIN
  INSERT INTO public.socio (nombre, apellidos) VALUES ('Jose', 'Perez Ramirez')
  RETURNING id INTO v_id;

  INSERT INTO public.socio (nombre, apellidos) VALUES ('Jose', 'Perez Ramirez')
  RETURNING id INTO v_id;
END
$$;
\echo 'OK  sin telefono el duplicado no se bloquea (por diseno)'

ROLLBACK;