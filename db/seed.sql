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
  ('Mensual',    500.00, 30, true),
  ('Trimestral', 1350.00, 90, true),
  ('Semestral',  2400.00, 180, true),
  ('Anual',      4200.00, 365, true)
ON CONFLICT (nombre) DO UPDATE
   SET precio_mxn   = EXCLUDED.precio_mxn,
       dias_periodo = EXCLUDED.dias_periodo,
       activo       = EXCLUDED.activo;

-- Verificacion: deben salir 4 planes activos.
SELECT nombre, precio_mxn, dias_periodo
FROM public.plan
WHERE activo
ORDER BY dias_periodo;