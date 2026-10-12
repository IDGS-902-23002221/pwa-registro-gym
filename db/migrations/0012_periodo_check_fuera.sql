-- 0012_periodo_check_fuera.sql
--
-- Complemento de la 0011: la 0005 dejó un CHECK (pago_periodo_inicio_de_mes) que
-- exige día 1 en la columna periodo. Sin quitarlo, registrar_pago acepta
-- cualquier día pero el INSERT lo rechaza. Se elimina; la regla vive en la
-- función (periodo obligatorio, GYM06 solo si es nulo).
--
-- La unique (socio_id, periodo) se conserva: es el bloqueo del doble cobro.

ALTER TABLE public.pago
  DROP CONSTRAINT pago_periodo_inicio_de_mes;
