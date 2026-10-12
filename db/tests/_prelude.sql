-- db/tests/_prelude.sql
-- Datos de prueba que usan todas las verificaciones. Se inserta con \ir desde cada
-- consulta de db/tests/.
--
-- IMPORTANTE: va dentro de una transaccion y cada test la revierte al terminar
-- (ROLLBACK). Las pruebas nunca dejan filas en la base: 03 §1 pide que en local no
-- se carguen datos reales, y esto evita que una prueba fallida contamine la
-- siguiente.
--
-- Los ids son fijos para que los tests los puedan citar sin variables.

\set ON_ERROR_STOP on

BEGIN;

-- Personal: uno activo (puede operar) y uno desactivado (02 §6).
INSERT INTO public.perfil (id, nombre, rol, activo) VALUES
  ('11111111-1111-1111-1111-111111111111', 'Personal activo',     'personal', true),
  ('22222222-2222-2222-2222-222222222222', 'Personal desactivado', 'personal', false);

-- La sesion. En local usuario_actual_id() lee este GUC; en Supabase lee el JWT.
-- El tercer argumento true lo limita a la transaccion actual.
SELECT set_config('app.usuario_id', '11111111-1111-1111-1111-111111111111', true);

-- Dos planes: sirve para probar la deduccion por monto y su caso ambiguo.
INSERT INTO public.plan (id, nombre, precio_mxn, dias_periodo, activo) VALUES
  ('33333333-3333-3333-3333-333333333333', 'Mensual',    500.00, 30, true),
  ('44444444-4444-4444-4444-444444444444', 'Trimestral', 1350.00, 90, true);

-- Un socio con telefono: es el sujeto de casi todas las pruebas de cobro.
INSERT INTO public.socio (id, nombre, apellidos, telefono, correo) VALUES
  ('55555555-5555-5555-5555-555555555555', 'Jose', 'Perez Ramirez', '5512345678', 'jose@ejemplo.mx');