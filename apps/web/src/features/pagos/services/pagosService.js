import { supabase } from '../../../shared/supabaseClient'

// Pagos contra la función registrar_pago (02 §5, ADR-006): pago + recibo con
// folio + pagado_hasta + membresía + bitácora en una sola transacción.
// Renovar = registrar el pago del siguiente periodo con esta misma función.

// Códigos de negocio (GYMxx) a mensajes para la interfaz. Nunca se muestra el
// detalle crudo de la excepción (02 §7).
const MENSAJES = {
  GYM01: 'Ese periodo ya está cubierto para este socio. Para renovar, cobra el siguiente mes.',
  GYM02: 'Socio no encontrado. Recarga la lista.',
  GYM03: 'Ese socio fue eliminado (ARCO) y ya no admite cobros.',
  GYM04: 'El monto debe ser mayor a cero.',
  GYM06: 'El periodo debe ser el primer día del mes (ej. 2026-10-01).',
  GYM07: 'Ese monto no coincide con el plan elegido. Revisa el plan.',
  GYM10: 'Tu sesión no tiene perfil activo. Vuelve a entrar.',
}

export function mensajeDeError(error) {
  return MENSAJES[error?.code] ?? 'No se pudo registrar el pago. Intenta de nuevo.'
}

export async function listarPlanes() {
  const { data, error } = await supabase
    .from('plan')
    .select('id, nombre, precio_mxn, dias_periodo')
    .eq('activo', true)
    .order('dias_periodo')
  if (error) throw error
  return data ?? []
}

export async function registrarPago({ socioId, monto, formaPago, periodo, referencia, planId }) {
  const { data, error } = await supabase.rpc('registrar_pago', {
    p_socio_id: socioId,
    p_monto: monto,
    p_forma_pago: formaPago,
    p_periodo: periodo,
    p_referencia: referencia?.trim() || null,
    p_plan_id: planId,
  })
  if (error) throw error
  return data
}
