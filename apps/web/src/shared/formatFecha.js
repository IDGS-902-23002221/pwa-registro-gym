// Formato de fechas para la interfaz. Las fechas de SOLO DÍA ('YYYY-MM-DD') se
// parten a mano: new Date() las interpreta como UTC y en México puede mover el
// día (02 §7: nada de datos confusos al usuario). Los TIMESTAMPS (con hora) sí
// se convierten a la zona del gimnasio antes de mostrarse.

const MESES = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
]

// Zona del gimnasio, fija (no la del dispositivo) para que la hora se vea igual
// en cualquier celular. León, Gto. es zona centro; México no aplica horario de
// verano desde 2022, así que es UTC-6 todo el año.
const ZONA = 'America/Mexico_City'

// Partes (año, mes, día, hora, minuto) de un timestamp en la zona del gimnasio.
// Devuelve null si viene vacío o no es una fecha válida.
const partesEnZona = (momento) => {
  if (!momento) return null
  const fecha = momento instanceof Date ? momento : new Date(momento)
  if (Number.isNaN(fecha.getTime())) return null
  const partes = new Intl.DateTimeFormat('en-CA', {
    timeZone: ZONA,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(fecha)
  const v = {}
  for (const { type, value } of partes) v[type] = value
  return { anio: +v.year, mes: +v.month, dia: +v.day, hora: v.hour, minuto: v.minute }
}

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

// Timestamp -> '18 de octubre de 2026, 22:16' (hora del gimnasio, no UTC).
// Antes se cortaba el ISO y se mostraba la hora UTC tal cual: un cobro de las
// 22:16 se veía como "04:16" del día siguiente.
export const fechaHora = (momento) => {
  const p = partesEnZona(momento)
  if (!p) return '—'
  return `${p.dia} de ${MESES[p.mes - 1]} de ${p.anio}, ${p.hora}:${p.minuto}`
}

// Timestamp -> '18 de octubre de 2026' (solo el día del gimnasio). Para listados
// donde no hace falta la hora, sin caer en el día UTC.
export const fechaLargaDeMomento = (momento) => {
  const p = partesEnZona(momento)
  if (!p) return '—'
  return `${p.dia} de ${MESES[p.mes - 1]} de ${p.anio}`
}

// '2026-10-01' -> 'octubre de 2026'
export const nombreDelMes = (fecha) => {
  if (!fecha) return '—'
  const [anio, mes] = String(fecha).split('-').map(Number)
  if (!anio || !mes) return String(fecha)
  return `${MESES[mes - 1]} de ${anio}`
}

const DIAS = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado']

// '2026-10-12' -> 'lunes 12 de octubre' (día de la semana en UTC, sin mover el día).
export const fechaLargaDia = (fecha) => {
  if (!fecha) return '—'
  const [anio, mes, dia] = String(fecha).split('-').map(Number)
  if (!anio || !mes || !dia) return String(fecha)
  const dow = new Date(Date.UTC(anio, mes - 1, dia)).getUTCDay()
  return `${DIAS[dow]} ${dia} de ${MESES[mes - 1]}`
}

// '2026-10-17' -> '17 de octubre'
export const diaYMes = (fecha) => {
  if (!fecha) return '—'
  const [, mes, dia] = String(fecha).split('-').map(Number)
  if (!mes || !dia) return String(fecha)
  return `${dia} de ${MESES[mes - 1]}`
}

// '2026-10-17' -> '2026'
export const anioDe = (fecha) => (fecha ? String(fecha).split('-')[0] : '')
