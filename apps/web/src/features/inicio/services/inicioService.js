import { supabase } from '../../../shared/supabaseClient'

// Inicio: socios cuyo plan vence en un rango (0019). Una sola consulta barata
// (usa el índice de pagado_hasta). El rango de la semana (lunes a sábado) lo
// calcula el componente.
export async function vencimientos(desde, hasta) {
  const { data, error } = await supabase.rpc('reporte_vencimientos', {
    p_desde: desde,
    p_hasta: hasta,
  })
  if (error) throw error
  return data ?? []
}
