import { supabase } from '../../../shared/supabaseClient'

// Servicio del catálogo de planes: la única capa que habla con Supabase.
// Lee la tabla plan (activos e inactivos, para administrarla) y escribe por rpc:
// crear_plan, actualizar_precio_plan y cambiar_activo_plan (0016 y 0017). No hay
// INSERT/UPDATE directo: plan es de solo lectura para el cliente (RLS 0008) y las
// funciones dejan bitácora. El cobro usa su propio listarPlanes en pagosService.

// Códigos de negocio (GYMxx) a mensajes para la interfaz (02 §7: nunca el texto
// crudo de la excepción).
const MENSAJES = {
  GYM04: 'El precio debe ser mayor a cero.',
  GYM07: 'No se pudo guardar el plan. Revisa el nombre (no puede repetirse) y los días (1 a 366).',
  GYM10: 'Tu sesión no tiene perfil activo. Vuelve a entrar.',
}

export function mensajeDeError(error) {
  return MENSAJES[error?.code] ?? 'No se pudo completar la operación. Intenta de nuevo.'
}

// Todos los planes para administrar: activos primero, luego por duración y nombre.
export async function listar() {
  const { data, error } = await supabase
    .from('plan')
    .select('id, nombre, precio_mxn, dias_periodo, activo')
    .order('activo', { ascending: false })
    .order('dias_periodo')
    .order('nombre')
  if (error) throw error
  return data ?? []
}

export async function crearPlan({ nombre, precio, dias }) {
  const { data, error } = await supabase.rpc('crear_plan', {
    p_nombre: nombre.trim(),
    p_precio: Number(precio),
    p_dias: Number(dias),
  })
  if (error) throw error
  return data
}

export async function actualizarPrecioPlan(planId, precio) {
  const { data, error } = await supabase.rpc('actualizar_precio_plan', {
    p_plan_id: planId,
    p_precio: Number(precio),
  })
  if (error) throw error
  return data
}

export async function actualizarDatosPlan(planId, { nombre, dias }) {
  const { error } = await supabase.rpc('actualizar_datos_plan', {
    p_plan_id: planId,
    p_nombre: nombre.trim(),
    p_dias: Number(dias),
  })
  if (error) throw error
}

export async function cambiarActivoPlan(planId, activo) {
  const { error } = await supabase.rpc('cambiar_activo_plan', {
    p_plan_id: planId,
    p_activo: activo,
  })
  if (error) throw error
}
