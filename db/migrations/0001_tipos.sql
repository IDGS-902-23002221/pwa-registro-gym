-- 0001_tipos.sql
-- Enums del dominio y funciones de normalizacion de texto.
-- Ver 02 Tecnico y arquitectura §4.

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
-- Un solo rol en este sprint (ADR-005): administrador y personal son las mismas
-- personas. Cuando haga falta separar permisos se agrega 'admin' y se ajustan
-- las politicas de 0008_rls.sql.
CREATE TYPE public.rol AS ENUM ('personal');

-- Estado *almacenado* del socio. El estado que ve el usuario (activo / pausado /
-- vencido) lo calcula la vista socios_con_estado de 0006.
CREATE TYPE public.estado_socio AS ENUM ('activo', 'pausado');

CREATE TYPE public.estado_membresia AS ENUM ('activa', 'vencida');

CREATE TYPE public.estado_recibo AS ENUM ('pagado', 'pendiente', 'vencido');

CREATE TYPE public.forma_pago AS ENUM ('efectivo', 'transferencia', 'tarjeta');

-- ---------------------------------------------------------------------------
-- Normalizacion (02 §4)
-- ---------------------------------------------------------------------------
-- El indice unico de identidad de 0003_socios.sql compara nombre, apellidos y
-- telefono normalizados, para que "Jose  Perez " y "josé pérez" cuentan como la
-- misma persona.
--
-- Se usa translate() y no unaccent() a proposito:
--   1. unaccent() no es IMMUTABLE (depende del search_path), y Postgres exige
--      IMMUTABLE para poder usarla en un indice de expresion.
--   2. unaccent vive en el esquema "extensions" en Supabase y en "public" en una
--      instalacion local, asi que no hay una ruta que funcione en los dos.
-- translate() es inmutable, no necesita extensiones y da el mismo resultado
-- para los nombres en espanol que maneja este negocio.

CREATE OR REPLACE FUNCTION public.normalizar_texto(texto text)
RETURNS text
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
AS $$
  SELECT nullif(
    regexp_replace(
      btrim(
        translate(
          lower(coalesce(texto, '')),
          'áàäâãéèëêíìïîóòöôõúùüûñçýÁÀÄÂÃÉÈËÊÍÌÏÎÓÒÖÔÕÚÙÜÛÑÇÝ',
          'aaaaaeeeeiiiiooooouuuuncyAAAAAEEEEIIIIOOOOOUUUUNCY'
        )
      ),
      '\s+', ' ', 'g'
    ),
    ''
  );
$$;

COMMENT ON FUNCTION public.normalizar_texto(text) IS
  'Minusculas, sin acentos y sin espacios extra. Devuelve NULL si el texto queda vacio.';

-- El telefono se compara solo por digitos: "55 1234 5678" y "(55)1234-5678" son
-- el mismo numero.
CREATE OR REPLACE FUNCTION public.normalizar_telefono(telefono text)
RETURNS text
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
AS $$
  SELECT nullif(regexp_replace(coalesce(telefono, ''), '[^0-9]+', '', 'g'), '');
$$;

COMMENT ON FUNCTION public.normalizar_telefono(text) IS
  'Solo digitos, sin signos ni espacios. Devuelve NULL si no queda ningun digito.';

-- ---------------------------------------------------------------------------
-- Codigos de error de negocio (02 §5 y §7)
-- ---------------------------------------------------------------------------
-- Cada regla de negocio falla con su propio SQLSTATE, para que el frontend
-- mapee el codigo sin leer texto de la excepcion. El MESSAGE es el codigo de
-- negocio (PAGO_PERIODO_YA_CUBIERTO, ...) y la DETAIL lleva el detalle para el
-- registro del servidor. Al usuario nunca se le muestra el detalle (02 §7).
--
-- La clase 'GYM' no la usa Postgres (sus clases son 0A, 22, 23, 25, 28, 40, P0, XX).
--
--   GYM01  PAGO_PERIODO_YA_CUBIERTO   ya se cobro el periodo de ese socio
--   GYM02  SOCIO_NO_ENCONTRADO        el socio no existe o fue eliminado
--   GYM03  SOCIO_YA_ELIMINADO         el socio esta anonimizado por ARCO
--   GYM04  MONTO_INVALIDO             monto <= 0 o no es un numero
--   GYM05  FORMA_PAGO_INVALIDA        valor fuera del enum forma_pago
--   GYM06  PERIODO_INVALIDO           el periodo no es el primer dia de un mes
--   GYM07  PLAN_INVALIDO              no se pudo resolver el plan del cobro
--   GYM08  ESTADO_SOCIO_INVALIDO      estado fuera del enum estado_socio
--   GYM09  JUSTIFICACION_REQUERIDA    pausa y reactivación exigen justificacion
--   GYM10  PERFIL_INACTIVO            el usuario de la sesion no esta activo