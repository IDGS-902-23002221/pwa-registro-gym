-- db/seed.sql
-- Datos iniciales: el catalogo de planes.
--
-- Idempotente: se puede correr las veces que haga falta (03 §1 pide que en local
-- los datos sean ficticios y generados por este archivo).
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f db/seed.sql
--
-- No inserta socios ni pagos: esos los crean las funciones y los triggers, y meterlos
-- aqui saltandose las reglas de negocio no aportaria nada.

INSERT INTO public.plan (nombre, precio_mxn, dias_periodo, activo)
VALUES
  ('Mensual',    350.00, 30, true),
  ('Estudiante', 250.00, 30, true),
  ('Visita',      50.00,  1, true)
ON CONFLICT (nombre) DO UPDATE
   SET precio_mxn   = EXCLUDED.precio_mxn,
       dias_periodo = EXCLUDED.dias_periodo,
       activo       = EXCLUDED.activo;

-- Los planes viejos del arranque (Trimestral, Semestral, Anual) se desactivan:
-- ya no se venden, pero se conservan por historial.
UPDATE public.plan
   SET activo = false
 WHERE nombre NOT IN ('Mensual', 'Estudiante', 'Visita');

-- Verificacion: deben salir 3 planes activos.
SELECT nombre, precio_mxn, dias_periodo
FROM public.plan
WHERE activo
ORDER BY dias_periodo;