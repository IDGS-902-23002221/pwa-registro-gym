import { useEffect, useState } from 'react'
import Dialog from '@mui/material/Dialog'
import DialogTitle from '@mui/material/DialogTitle'
import DialogContent from '@mui/material/DialogContent'
import DialogActions from '@mui/material/DialogActions'
import Button from '@mui/material/Button'
import Box from '@mui/material/Box'
import Typography from '@mui/material/Typography'
import Divider from '@mui/material/Divider'
import Table from '@mui/material/Table'
import TableBody from '@mui/material/TableBody'
import TableCell from '@mui/material/TableCell'
import TableContainer from '@mui/material/TableContainer'
import TableHead from '@mui/material/TableHead'
import TableRow from '@mui/material/TableRow'
import Paper from '@mui/material/Paper'
import { listarHistorial } from '../../pagos/services/pagosService'
import { fechaLarga, moverDias } from '../../../shared/formatFecha'

// El join pago→recibo puede venir como objeto o como arreglo según PostgREST.
const folioDe = (pago) =>
  Array.isArray(pago.recibo) ? pago.recibo[0]?.folio : pago.recibo?.folio

// Cobertura de cada folio: del periodo al día previo del siguiente cobro (así se
// ve el encadenado); el último llega hasta el vencimiento vigente.
const conCobertura = (pagos, venceVigente) => {
  const ordenados = [...pagos].sort((a, b) => (a.periodo < b.periodo ? -1 : 1))
  return ordenados.map((p, i) => ({
    ...p,
    fin: ordenados[i + 1] ? moverDias(ordenados[i + 1].periodo, -1) : (p.vence ?? venceVigente),
  }))
}

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
    { etiqueta: 'Pagado hasta', valor: registro.pagado_hasta ? fechaLarga(registro.pagado_hasta) : 'Sin pagos' },
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

  // Historial con cobertura por folio (ordenado del más viejo al más nuevo para
  // que el encadenado se lea de arriba hacia abajo).
  const cobros = conCobertura(historial, registro.pagado_hasta).reverse()

  return (
    <Dialog open={abierto} onClose={onCerrar} fullWidth maxWidth="sm">
      <DialogTitle> Detalle del socio</DialogTitle>
      <DialogContent>
        {info}
        <Divider sx={{ my: 2 }} />
        <Typography variant="subtitle2" sx={{ mb: 1.5 }}>
          Últimos pagos
        </Typography>
        {cargandoHistorial ? (
          <Typography variant="body2" color="text.secondary">Cargando…</Typography>
        ) : cobros.length === 0 ? (
          <Typography variant="body2" color="text.secondary">Sin pagos todavía</Typography>
        ) : (
          <TableContainer component={Paper} elevation={0} variant="outlined">
            <Table size="small">
              <TableHead>
                <TableRow>
                  <TableCell>Folio</TableCell>
                  <TableCell>Pagó el</TableCell>
                  <TableCell>Cubre del</TableCell>
                  <TableCell>Cubre hasta</TableCell>
                  <TableCell>Plazo</TableCell>
                  <TableCell align="right">Precio</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {cobros.map((p) => (
                  <TableRow key={p.id}>
                    <TableCell>{folioDe(p) ?? '—'}</TableCell>
                    <TableCell>{fechaLarga(String(p.creado_en).slice(0, 10))}</TableCell>
                    <TableCell>{fechaLarga(p.periodo)}</TableCell>
                    <TableCell>{p.fin ? fechaLarga(p.fin) : '—'}</TableCell>
                    <TableCell>
                      {p.planNombre ?? '—'}
                      {p.planDias ? ` (${p.planDias} d)` : ''}
                    </TableCell>
                    <TableCell align="right">
                      ${p.monto_mxn} ({p.forma_pago})
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </TableContainer>
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
