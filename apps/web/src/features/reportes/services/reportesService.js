import { jsPDF } from 'jspdf'
import autoTable from 'jspdf-autotable'
import { supabase } from '../../../shared/supabaseClient'
import { fechaHora, fechaLarga, moverDias } from '../../../shared/formatFecha'

// Reportes: solo lectura por funciones SECURITY DEFINER (02 §5). Si la sesión
// se pierde, fallan con GYM10 en vez de devolver cero filas, para no confundir
// "no hay nada" con "no tienes permiso".

// Vencimientos del rango: socios cuyo plan termina entre desde y hasta, con su
// plan (0019). Sustituye al antiguo reporte de cartera con días de mora.
export async function vencimientos(desde, hasta) {
  const { data, error } = await supabase.rpc('reporte_vencimientos', {
    p_desde: desde,
    p_hasta: hasta,
  })
  if (error) {
    if (error.code === 'GYM06') throw new Error('El rango de fechas es inválido.')
    throw error
  }
  return data ?? []
}

// Un 'YYYY-MM-DD' como límite ISO con la hora del gimnasio (León = UTC-6 fijo).
// Es lo que se compara contra creado_en (timestamptz): sin el offset, Postgres
// lo leería como UTC y un cobro de las 22:00 se saldría del día.
const inicioDelDia = (dia) => `${dia}T00:00:00-06:00`

// Cobros HECHOS en el rango (por creado_en, la fecha del cobro), con socio y
// folio, del más nuevo al más viejo. Antes se filtraba por periodo (inicio de
// cobertura), que es otro día: un cobro de renovación podía no aparecer hasta su
// semana de cobertura, o mostrarse una fila con fecha fuera del rango pedido.
// El plan se deduce por monto contra el catálogo activo (hoy sin ambigüedad:
// 350/250/50). Si dos planes costaran igual, habría que cruzar con membresía.
export async function detalleCobros(desde, hasta) {
  const [{ data: pagos, error }, { data: planes, error: errorP }] = await Promise.all([
    supabase
      .from('pago')
      .select('monto_mxn, forma_pago, periodo, creado_en, socio(nombre, apellidos), recibo(folio)')
      .gte('creado_en', inicioDelDia(desde))
      .lt('creado_en', inicioDelDia(moverDias(hasta, 1)))
      .order('creado_en', { ascending: false }),
    supabase.from('plan').select('nombre, precio_mxn').eq('activo', true),
  ])
  if (error) throw error
  if (errorP) throw errorP
  return (pagos ?? []).map((p) => {
    const socio = Array.isArray(p.socio) ? p.socio[0] : p.socio
    const recibo = Array.isArray(p.recibo) ? p.recibo[0] : p.recibo
    const plan = (planes ?? []).find((x) => Number(x.precio_mxn) === Number(p.monto_mxn))
    return {
      creado_en: p.creado_en,
      periodo: p.periodo,
      socio: `${socio?.nombre ?? ''} ${socio?.apellidos ?? ''}`.trim() || '—',
      plan: plan?.nombre ?? '—',
      monto: p.monto_mxn,
      forma: p.forma_pago,
      folio: recibo?.folio ?? null,
    }
  })
}

// PDF del detalle generado en el navegador (punto 5 del ticket padre).
export function pdfCobros({ filas, desde, hasta, total }) {
  const doc = new jsPDF()
  doc.setFontSize(14)
  doc.text(`Reporte de cobros del ${fechaLarga(desde)} al ${fechaLarga(hasta)}`, 14, 16)
  autoTable(doc, {
    startY: 24,
    head: [['Fecha', 'Socio', 'Plan', 'Tipo de pago', 'Monto', 'Folio']],
    body: filas.map((f) => [
      fechaHora(f.creado_en),
      f.socio,
      f.plan,
      f.forma,
      `$${f.monto}`,
      f.folio ?? '—',
    ]),
    foot: [['', '', '', 'Total', `$${Number(total).toFixed(2)}`, '']],
  })
  doc.save(`reporte-${desde}_${hasta}.pdf`)
}
