import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useTheme } from '@mui/material/styles'
import useMediaQuery from '@mui/material/useMediaQuery'
import Box from '@mui/material/Box'
import Button from '@mui/material/Button'
import TextField from '@mui/material/TextField'
import Typography from '@mui/material/Typography'
import Alert from '@mui/material/Alert'
import Paper from '@mui/material/Paper'
import Chip from '@mui/material/Chip'
import Table from '@mui/material/Table'
import TableBody from '@mui/material/TableBody'
import TableCell from '@mui/material/TableCell'
import TableContainer from '@mui/material/TableContainer'
import TableHead from '@mui/material/TableHead'
import TableRow from '@mui/material/TableRow'
import CardWell from '../shared/CardWell'
import { ingresos, cartera, detalleCobros, pdfCobros } from '../features/reportes/services/reportesService'
import { fechaLarga, fechaHora } from '../shared/formatFecha'

const aISO = (f) =>
  `${f.getFullYear()}-${String(f.getMonth() + 1).padStart(2, '0')}-${String(f.getDate()).padStart(2, '0')}`
const hoyISO = () => aISO(new Date())
const inicioDeMes = () => aISO(new Date(new Date().getFullYear(), new Date().getMonth(), 1))
// Lunes a domingo de la semana en curso.
const semanaActual = () => {
  const hoy = new Date()
  const lunes = new Date(hoy)
  lunes.setDate(hoy.getDate() - ((hoy.getDay() + 6) % 7))
  const domingo = new Date(lunes)
  domingo.setDate(lunes.getDate() + 6)
  return [aISO(lunes), aISO(domingo)]
}

// Tarjeta de una fila para móvil (mismo dato que la tabla, en vertical).
function Tarjeta({ children }) {
  return (
    <Paper elevation={0} sx={{ p: 2, display: 'flex', flexDirection: 'column', gap: 0.5 }}>
      {children}
    </Paper>
  )
}

// Pantalla /reportes: presets día/semana/mes + rango manual, ingresos por forma
// de pago, tabla de cobros del periodo y cartera de vencidos, descargable en PDF.
// Mobile-first: en pantallas chicas cada sección es una lista de tarjetas dentro
// de un "pozo"; en escritorio, tabla. El corte es render condicional por breakpoint.
export default function Reportes() {
  const navegar = useNavigate()
  const theme = useTheme()
  const esMovil = useMediaQuery(theme.breakpoints.down('sm'))

  const [desde, setDesde] = useState(hoyISO())
  const [hasta, setHasta] = useState(hoyISO())
  const [preset, setPreset] = useState('dia')
  const [filas, setFilas] = useState([])
  const [detalle, setDetalle] = useState([])
  const [mora, setMora] = useState([])
  const [error, setError] = useState('')
  const [cargando, setCargando] = useState(false)

  const cargar = async (d = desde, h = hasta) => {
    setError('')
    setCargando(true)
    try {
      const [ing, det, cart] = await Promise.all([ingresos(d, h), detalleCobros(d, h), cartera()])
      setFilas(ing)
      setDetalle(det)
      setMora(cart)
    } catch (e) {
      setError(e.message ?? 'No se pudieron cargar los reportes')
    } finally {
      setCargando(false)
    }
  }

  useEffect(() => {
    cargar()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const aplicarPreset = (cual) => {
    setPreset(cual)
    const hoy = hoyISO()
    if (cual === 'dia') {
      setDesde(hoy)
      setHasta(hoy)
      cargar(hoy, hoy)
    } else if (cual === 'semana') {
      const [lun, dom] = semanaActual()
      setDesde(lun)
      setHasta(dom)
      cargar(lun, dom)
    } else {
      const ini = inicioDeMes()
      setDesde(ini)
      setHasta(hoy)
      cargar(ini, hoy)
    }
  }

  const total = filas.reduce((acc, f) => acc + Number(f.total_mxn), 0)

  const descargar = () => {
    pdfCobros({ filas: detalle, desde, hasta, total })
  }

  return (
    <Box sx={{ maxWidth: 720, mx: 'auto', p: { xs: 2, sm: 3 }, display: 'flex', flexDirection: 'column', gap: 2 }}>
      <Button variant="text" sx={{ alignSelf: 'flex-start' }} onClick={() => navegar('/')}>
        ← Volver
      </Button>
      <Typography variant="h5" component="h1">Reportes</Typography>
      {error && <Alert severity="error">{error}</Alert>}

      <Box sx={{ display: 'flex', gap: 1 }}>
        {[
          ['dia', 'Día'],
          ['semana', 'Semana'],
          ['mes', 'Mes'],
        ].map(([valor, etiqueta]) => (
          <Button
            key={valor}
            variant={preset === valor ? 'contained' : 'outlined'}
            onClick={() => aplicarPreset(valor)}
            sx={{ flex: 1 }}
          >
            {etiqueta}
          </Button>
        ))}
      </Box>

      <Box sx={{ display: 'flex', gap: 2, flexWrap: 'wrap', alignItems: 'center' }}>
        <TextField
          label="Desde"
          type="date"
          value={desde}
          onChange={(e) => {
            setDesde(e.target.value)
            setPreset('rango')
          }}
          size="small"
          InputLabelProps={{ shrink: true }}
        />
        <TextField
          label="Hasta"
          type="date"
          value={hasta}
          onChange={(e) => {
            setHasta(e.target.value)
            setPreset('rango')
          }}
          size="small"
          InputLabelProps={{ shrink: true }}
        />
        <Button variant="contained" onClick={() => cargar()} disabled={cargando}>
          {cargando ? 'Cargando…' : 'Ver'}
        </Button>
      </Box>

      <Typography variant="h6">Ingresos por forma de pago</Typography>
      {filas.length === 0 ? (
        <Typography variant="body2" color="text.secondary">
          {cargando ? 'Cargando…' : 'Sin cobros en ese rango'}
        </Typography>
      ) : esMovil ? (
        <CardWell>
          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1.5 }}>
            {filas.map((f) => (
              <Tarjeta key={f.forma_pago}>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', gap: 1 }}>
                  <Typography variant="subtitle2" sx={{ textTransform: 'capitalize' }}>
                    {f.forma_pago}
                  </Typography>
                  <Typography variant="h6" sx={{ fontVariantNumeric: 'tabular-nums' }}>
                    ${f.total_mxn}
                  </Typography>
                </Box>
                <Typography variant="caption" color="text.secondary">
                  {f.cantidad} {Number(f.cantidad) === 1 ? 'cobro' : 'cobros'}
                </Typography>
              </Tarjeta>
            ))}
            <Tarjeta>
              <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
                <Typography variant="subtitle2" sx={{ fontWeight: 700 }}>Total</Typography>
                <Typography variant="h6" sx={{ fontVariantNumeric: 'tabular-nums' }}>
                  ${total.toFixed(2)}
                </Typography>
              </Box>
            </Tarjeta>
          </Box>
        </CardWell>
      ) : (
        <TableContainer component={Paper} elevation={0} variant="outlined">
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell>Forma de pago</TableCell>
                <TableCell align="right">Cobros</TableCell>
                <TableCell align="right">Total</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {filas.map((f) => (
                <TableRow key={f.forma_pago}>
                  <TableCell sx={{ textTransform: 'capitalize' }}>{f.forma_pago}</TableCell>
                  <TableCell align="right">{f.cantidad}</TableCell>
                  <TableCell align="right">${f.total_mxn}</TableCell>
                </TableRow>
              ))}
              <TableRow>
                <TableCell><strong>Total</strong></TableCell>
                <TableCell />
                <TableCell align="right"><strong>${total.toFixed(2)}</strong></TableCell>
              </TableRow>
            </TableBody>
          </Table>
        </TableContainer>
      )}

      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, flexWrap: 'wrap' }}>
        <Typography variant="h6" sx={{ flexGrow: 1, minWidth: 200 }}>
          Cobros del periodo ({detalle.length})
        </Typography>
        <Button
          variant="outlined"
          onClick={descargar}
          disabled={detalle.length === 0}
          sx={{ flexGrow: { xs: 1, sm: 0 } }}
        >
          Descargar PDF
        </Button>
      </Box>
      {detalle.length === 0 ? (
        <Typography variant="body2" color="text.secondary">
          Sin cobros en ese rango
        </Typography>
      ) : esMovil ? (
        <CardWell>
          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1.5 }}>
            {detalle.map((d, i) => (
              <Tarjeta key={`${d.folio ?? i}-${d.creado_en}`}>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', gap: 1 }}>
                  <Typography variant="subtitle2" sx={{ fontWeight: 700 }} noWrap>
                    {d.socio}
                  </Typography>
                  <Typography variant="subtitle1" sx={{ fontVariantNumeric: 'tabular-nums' }}>
                    ${d.monto}
                  </Typography>
                </Box>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', gap: 1 }}>
                  <Typography variant="body2" color="text.secondary" noWrap sx={{ textTransform: 'capitalize' }}>
                    {d.plan} · {d.forma}
                  </Typography>
                  <Typography variant="body2" color="text.secondary">
                    Folio {d.folio ?? '—'}
                  </Typography>
                </Box>
                <Typography variant="caption" color="text.secondary">
                  {fechaHora(d.creado_en)}
                </Typography>
              </Tarjeta>
            ))}
          </Box>
        </CardWell>
      ) : (
        <TableContainer component={Paper} elevation={0} variant="outlined">
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell>Fecha</TableCell>
                <TableCell>Socio</TableCell>
                <TableCell>Plan</TableCell>
                <TableCell align="right">Monto</TableCell>
                <TableCell>Folio</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {detalle.map((d, i) => (
                <TableRow key={`${d.folio ?? i}-${d.creado_en}`}>
                  <TableCell>{fechaHora(d.creado_en)}</TableCell>
                  <TableCell>{d.socio}</TableCell>
                  <TableCell>{d.plan}</TableCell>
                  <TableCell align="right">${d.monto} ({d.forma})</TableCell>
                  <TableCell>{d.folio ?? '—'}</TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      )}

      <Typography variant="h6">Cartera vencida ({mora.length})</Typography>
      {mora.length === 0 ? (
        <Typography variant="body2" color="text.secondary">
          Sin vencidos. 🎉
        </Typography>
      ) : esMovil ? (
        <CardWell>
          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1.5 }}>
            {mora.map((m) => (
              <Tarjeta key={m.socio_id}>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', gap: 1 }}>
                  <Typography variant="subtitle2" sx={{ fontWeight: 700 }}>
                    {m.nombre} {m.apellidos ?? ''}
                  </Typography>
                  <Chip size="small" color="warning" label={`${m.dias_mora} días`} />
                </Box>
                <Typography variant="body2" color="text.secondary">
                  Pagado hasta {fechaLarga(m.pagado_hasta)}
                </Typography>
                {m.telefono && (
                  <Typography variant="caption" color="text.secondary">
                    {m.telefono}
                  </Typography>
                )}
              </Tarjeta>
            ))}
          </Box>
        </CardWell>
      ) : (
        <TableContainer component={Paper} elevation={0} variant="outlined">
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell>Socio</TableCell>
                <TableCell>Pagado hasta</TableCell>
                <TableCell align="right">Días de mora</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {mora.map((m) => (
                <TableRow key={m.socio_id}>
                  <TableCell>
                    {m.nombre} {m.apellidos ?? ''}
                    {m.telefono ? ` · ${m.telefono}` : ''}
                  </TableCell>
                  <TableCell>{fechaLarga(m.pagado_hasta)}</TableCell>
                  <TableCell align="right">{m.dias_mora}</TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      )}
    </Box>
  )
}
