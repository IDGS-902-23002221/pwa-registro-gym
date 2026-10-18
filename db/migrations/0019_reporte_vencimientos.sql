-- 0019_reporte_vencimientos.sql
--
-- TICKET 000.5 (ajuste): socios cuyo plan vence dentro de un rango. Sustituye en
-- la interfaz a reporte_cartera (que traia dias de mora): el gimnasio quiere ver
-- a quién le toca renovar en el día / la semana / el mes elegido.
--
-- "Vence" = la cobertura termina (socio.pagado_hasta) dentro de [p_desde, p_hasta].
-- Se excluyen los pausados (su plan no corre). El tipo de membresía es el nombre
-- del plan de su membresía más reciente.
--
-- reporte_cartera se conserva por si se necesita; ya no se usa en la interfaz.

CREATE OR REPLACE FUNCTION public.reporte_vencimientos(p_desde date, p_hasta date)
RETURNS TABLE (
  socio_id  uuid,
  nombre    text,
  apellidos text,
  telefono  text,
  vence_en  date,
  plan      text
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
  SELECT v.id, v.nombre, v.apellidos, v.telefono, v.pagado_hasta, pl.nombre
  FROM public.socios_con_estado v
  -- Plan de la membresía más reciente del socio (aunque ya esté vencida).
  LEFT JOIN LATERAL (
    SELECT m.plan_id
    FROM public.membresia m
    WHERE m.socio_id = v.id
    ORDER BY m.termina_en DESC
    LIMIT 1
  ) lm ON true
  LEFT JOIN public.plan pl ON pl.id = lm.plan_id
  WHERE v.pagado_hasta IS NOT NULL
    AND v.pagado_hasta BETWEEN p_desde AND p_hasta
    AND v.estado_calculado <> 'pausado'
  ORDER BY v.pagado_hasta, v.nombre, v.apellidos;
END
$$;

COMMENT ON FUNCTION public.reporte_vencimientos(date, date) IS
  'Socios cuyo plan vence en el rango (excluye pausados), con su plan. Errores: GYM06, GYM10.';

REVOKE ALL ON FUNCTION public.reporte_vencimientos(date, date) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.reporte_vencimientos(date, date) TO authenticated;
