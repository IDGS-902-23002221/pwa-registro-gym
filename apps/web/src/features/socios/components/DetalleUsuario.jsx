import { useEffect, useState } from 'react'
import Dialog from '@mui/material/Dialog'
import DialogTitle from '@mui/material/DialogTitle'
import DialogContent from '@mui/material/DialogContent'
import DialogActions from '@mui/material/DialogActions'
import Button from '@mui/material/Button'
import Box from '@mui/material/Box'
import Typography from '@mui/material/Typography'
import Divider from '@mui/material/Divider'
import { listarHistorial } from '../../pagos/services/pagosService'

// 'YYYY-MM-DD' a 'octubre de 2026'. Se parte a mano para no mover el día por
// zona horaria (new Date('2026-10-01') es UTC y en México puede caer en el 30).
const MESES = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
]
const nombreDelMes = (fecha) => {
  if (!fecha) return '—'
  const [anio, mes] = fecha.split('-').map(Number)
  if (!anio || !mes) return fecha
  return `${MESES[mes - 1]} de ${anio}`
}

// El join pago→recibo puede venir como objeto o como arreglo según PostgREST.
const folioDe = (pago) =>
  Array.isArray(pago.recibo) ? pago.recibo[0]?.folio : pago.recibo?.folio

function DetalleUsuario({ registro, abierto, onCerrar }) {
  const [historial, setHistorial] = useState([])
  const [cargandoHistorial, setCargandoHistorial] = useState(false)

  useEffect(() => {
    if (!abierto || !registro) return
    setCargandoHistorial(true)
    listarHistorial(registro.id)
      .then(setHistorial)
      .catch(() => setHistorial([]))
      .finally(() => setCargandoHistorial(false))
  }, [abierto, registro])

  if (!registro) {
    return null
  }

  const datos = [
    { etiqueta: 'Nombre', valor: `${registro.nombre} ${registro.apellidos ?? ''}`.trim() },
    { etiqueta: 'Correo', valor: registro.correo ?? '—' },
    { etiqueta: 'Telefono', valor: registro.telefono ?? '—' },
    { etiqueta: 'Estado', valor: registro.estado_calculado ?? registro.estado },
    { etiqueta: 'Pagado hasta', valor: registro.pagado_hasta ?? 'Sin pagos' },
    { etiqueta: 'ID', valor: registro.id },
  ]

  const info = []

  datos.forEach((dato) => {
    info.push(
      <Box key={dato.etiqueta} sx={{ mb: 2 }}>
        <Typography variant="caption" color="text.secondary">
          {dato.etiqueta}
        </Typography>
        <Typography variant="body1">{dato.valor}</Typography>
      </Box>
    )
  })

  return (
    <Dialog open={abierto} onClose={onCerrar} fullWidth maxWidth="xs">
      <DialogTitle> Detalle del socio</DialogTitle>
      <DialogContent>
        {info}
        <Divider sx={{ my: 1 }} />
        <Typography variant="subtitle2" sx={{ mb: 1 }}>
          Últimos pagos
        </Typography>
        {cargandoHistorial ? (
          <Typography variant="body2" color="text.secondary">Cargando…</Typography>
        ) : historial.length === 0 ? (
          <Typography variant="body2" color="text.secondary">Sin pagos todavía</Typography>
        ) : (
          historial.map((p) => (
            <Box key={p.id} sx={{ mb: 1 }}>
              <Typography variant="body2">
                Folio {folioDe(p) ?? '—'} · {nombreDelMes(p.periodo)} · ${p.monto_mxn} ({p.forma_pago})
              </Typography>
            </Box>
          ))
        )}
      </DialogContent>
      <DialogActions>
        <Button variant="outlined" onClick={onCerrar}>
          Cerrar
        </Button>
      </DialogActions>
    </Dialog>
  )
}
export default DetalleUsuario
