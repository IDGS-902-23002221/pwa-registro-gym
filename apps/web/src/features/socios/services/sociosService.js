import { supabase } from '../../../shared/supabaseClient'

// Servicio de socios: la única capa que habla con Supabase.
// Lee de la vista socios_con_estado (02 §5) y escribe solo columnas de contacto
// (0008_rls: pagado_hasta y estado no se pueden escribir desde el cliente).

// 23505 = duplicado (mismo nombre, apellidos y teléfono, 02 §4).
export function esDuplicado(error) {
  return error?.code === '23505'
}

// Listado paginado + búsqueda por nombre. La vista ya trae nombre_buscable en
// minúsculas y sin acentos: se filtra con LIKE, no ILIKE (así usa el índice).
export async function listar({ busqueda = '', limite = 50 } = {}) {
  let q = supabase
    .from('socios_con_estado')
    .select('id, nombre, apellidos, correo, telefono, estado_calculado, pagado_hasta, creado_en')
    .order('creado_en', { ascending: false })
    .limit(limite)

  const termino = busqueda.trim().toLowerCase()
  if (termino) {
    q = q.like('nombre_buscable', `${termino}%`)
  }

  const { data, error } = await q
  if (error) throw error
  return data ?? []
}

export async function crear({ nombre, apellidos, telefono, correo }) {
  const { data, error } = await supabase
    .from('socio')
    .insert({
      nombre: nombre.trim(),
      apellidos: apellidos.trim() || null,
      telefono: telefono.trim() || null,
      correo: correo.trim() || null,
    })
    .select('id')
    .single()
  if (error) throw error
  return data
}

// Solo datos de contacto (nombre, apellidos, correo, teléfono).
export async function actualizarContacto(id, { nombre, apellidos, telefono, correo }) {
  const { error } = await supabase
    .from('socio')
    .update({
      nombre: nombre.trim(),
      apellidos: apellidos.trim() || null,
      telefono: telefono.trim() || null,
      correo: correo.trim() || null,
    })
    .eq('id', id)
  if (error) throw error
}

// ARCO: anonimiza (no borra la fila, los pagos sobreviven). Deja bitácora.
export async function eliminar(id) {
  const { error } = await supabase.rpc('eliminar_socio', { p_socio_id: id })
  if (error) throw error
}
