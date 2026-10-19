import { useEffect, useState } from 'react'
import { useTheme } from '@mui/material/styles'
import useMediaQuery from '@mui/material/useMediaQuery'
import Dialog from '@mui/material/Dialog'
import DialogTitle from '@mui/material/DialogTitle'
import DialogContent from '@mui/material/DialogContent'
import DialogActions from '@mui/material/DialogActions'
import Button from '@mui/material/Button'
import Box from '@mui/material/Box'
import Typography from '@mui/material/Typography'
import Divider from '@mui/material/Divider'
import Paper from '@mui/material/Paper'
import Table from '@mui/material/Table'
import TableBody from '@mui/material/TableBody'
import TableCell from '@mui/material/TableCell'
import TableContainer from '@mui/material/TableContainer'
import TableHead from '@mui/material/TableHead'
import TableRow from '@mui/material/TableRow'
import { listarHistorial } from '../../pagos/services/pagosService'
import { fechaLarga, fechaLargaDeMomento, moverDias } from '../../../shared/formatFecha'

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

// Detalle del socio: datos, historial de pagos y las acciones (editar contacto,
// eliminar ARCO). Así la fila de la lista queda con una sola acción ("Detalle"),
// como en Planes. En móvil el historial se muestra como lista, no como tabla.
function DetalleUsuario({ registro, abierto, onCerrar, onEditar, onEliminar }) {
  const theme = useTheme()
  const esMovil = useMediaQuery(theme.breakpoints.down('sm'))
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
    { etiqueta: 'Teléfono', valor: registro.telefono ?? '—' },
    { etiqueta: 'Estado', valor: registro.estado_calculado ?? registro.estado },
    { etiqueta: 'Pagado hasta', valor: registro.pagado_hasta ? fechaLarga(registro.pagado_hasta) : 'Sin pagos' },
  ]

  const cobros = conCobertura(historial, registro.pagado_hasta).reverse()

  return (
    <Dialog open={abierto} onClose={onCerrar} fullWidth maxWidth="sm">
      <DialogTitle>Detalle del socio</DialogTitle>
      <DialogContent>
        {datos.map((dato) => (
          <Box key={dato.etiqueta} sx={{ mb: 2 }}>
            <Typography variant="caption" color="text.secondary">
              {dato.etiqueta}
            </Typography>
            <Typography variant="body1">{dato.valor}</Typography>
          </Box>
        ))}
        <Divider sx={{ my: 2 }} />
        <Typography variant="subtitle2" sx={{ mb: 1.5 }}>
          Últimos pagos
        </Typography>
        {cargandoHistorial ? (
          <Typography variant="body2" color="text.secondary">Cargando…</Typography>
        ) : cobros.length === 0 ? (
          <Typography variant="body2" color="text.secondary">Sin pagos todavía</Typography>
        ) : esMovil ? (
          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1 }}>
            {cobros.map((p) => (
              <Paper key={p.id} variant="outlined" sx={{ p: 1.5, display: 'flex', flexDirection: 'column', gap: 0.25 }}>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', gap: 1 }}>
                  <Typography variant="subtitle2">Folio {folioDe(p) ?? '—'}</Typography>
                  <Typography variant="subtitle2" sx={{ fontVariantNumeric: 'tabular-nums' }}>
                    ${p.monto_mxn} ({p.forma_pago})
                  </Typography>
                </Box>
                <Typography variant="body2">
                  Cubre del {fechaLarga(p.periodo)} al {p.fin ? fechaLarga(p.fin) : '—'}
                </Typography>
                <Typography variant="caption" color="text.secondary">
                  Pagó el {fechaLargaDeMomento(p.creado_en)}
                  {p.planNombre ? ` · ${p.planNombre}${p.planDias ? ` (${p.planDias} d)` : ''}` : ''}
                </Typography>
              </Paper>
            ))}
          </Box>
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
                    <TableCell>{fechaLargaDeMomento(p.creado_en)}</TableCell>
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
      <DialogActions sx={{ flexWrap: 'wrap', gap: 1, justifyContent: 'space-between' }}>
        <Box sx={{ display: 'flex', gap: 1 }}>
          <Button variant="outlined" onClick={() => onEditar(registro.id)}>
            Editar
          </Button>
          <Button
            color="error"
            onClick={() => {
              if (
                window.confirm(
                  `Eliminar a ${registro.nombre} ${registro.apellidos ?? ''}? Se anonimizan sus datos (ARCO) y se conservan sus pagos.`
                )
              ) {
                onEliminar(registro.id)
              }
            }}
          >
            Eliminar
          </Button>
        </Box>
        <Button variant="contained" onClick={onCerrar}>
          Cerrar
        </Button>
      </DialogActions>
    </Dialog>
  )
}

export default DetalleUsuario
