// Formato de fechas para la interfaz. Se parte 'YYYY-MM-DD' a mano: new Date()
// interpreta sin hora como UTC y en México puede mover el día (02 §7: nada de
// datos confusos al usuario).

const MESES = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
]

// '2026-10-30' -> '30 de octubre de 2026'
export const fechaLarga = (fecha) => {
  if (!fecha) return '—'
  const [anio, mes, dia] = String(fecha).split('-').map(Number)
  if (!anio || !mes || !dia) return String(fecha)
  return `${dia} de ${MESES[mes - 1]} de ${anio}`
}

// Mueve N días (positivo o negativo) un 'YYYY-MM-DD'. En UTC para no mover el
// día por zona horaria.
export const moverDias = (fecha, n) => {
  const [anio, mes, dia] = String(fecha).split('-').map(Number)
  const f = new Date(Date.UTC(anio, mes - 1, dia))
  f.setUTCDate(f.getUTCDate() + n)
  return `${f.getUTCFullYear()}-${String(f.getUTCMonth() + 1).padStart(2, '0')}-${String(f.getUTCDate()).padStart(2, '0')}`
}

// '2026-10-01' -> 'octubre de 2026'
export const nombreDelMes = (fecha) => {
  if (!fecha) return '—'
  const [anio, mes] = String(fecha).split('-').map(Number)
  if (!anio || !mes) return String(fecha)
  return `${MESES[mes - 1]} de ${anio}`
}
