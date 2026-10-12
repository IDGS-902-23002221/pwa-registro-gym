-- 0015_reporte_rango_exacto.sql
--
-- Hallazgo 2026-10-12 (pantalla /reportes): reporte_ingresos filtraba
-- periodo >= date_trunc('month', p_desde), o sea desde el día 1 del mes aunque
-- se pidiera una semana. El total no cuadraba con la tabla de cobros del
-- periodo (que filtra exacto). Desde la 0011 los periodos son fechas libres y
-- el rango debe respetarse tal cual.
--
-- Se reescribe solo el filtro (CREATE OR REPLACE): la 0007 ya está aplicada y
-- nunca se edita.

CREATE OR REPLACE FUNCTION public.reporte_ingresos(p_desde date, p_hasta date)
RETURNS TABLE (
  forma_pago    public.forma_pago,
  total_mxn     numeric(12,2),
  cantidad      bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.es_usuario_activo() THEN
    RAISE EXCEPTION USING
      ERRCODE = 'GYM10', MESSAGE = 'PERFIL_INACTIVO',
      DETAIL  = 'La sesion no corresponde a un perfil activo.';
  END IF;

  IF p_desde IS NULL OR p_hasta IS NULL OR p_desde > p_hasta THEN
    RAISE EXCEPTION USING
      ERRCODE = 'GYM06', MESSAGE = 'PERIODO_INVALIDO',
      DETAIL  = format('rango invalido: desde %s hasta %s',
                       coalesce(p_desde::text, 'null'), coalesce(p_hasta::text, 'null'));
  END IF;

  RETURN QUERY
  SELECT pg.forma_pago, sum(pg.monto_mxn)::numeric(12,2), count(*)
  FROM public.pago pg
  WHERE pg.periodo >= p_desde
    AND pg.periodo <= p_hasta
  GROUP BY pg.forma_pago
  ORDER BY pg.forma_pago;
END
$$;

COMMENT ON FUNCTION public.reporte_ingresos(date, date) IS
  'Ingresos agrupados por forma de pago para un rango exacto de periodos. Errores: GYM06, GYM10.';
