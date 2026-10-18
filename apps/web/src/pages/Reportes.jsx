import { useEffect, useState } from 'react'
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
import { vencimientos, detalleCobros, pdfCobros } from '../features/reportes/services/reportesService'
import { fechaLarga, fechaHora, nombreDelMes, diaYMes, anioDe } from '../shared/formatFecha'

const aISO = (f) =>
  `${f.getFullYear()}-${String(f.getMonth() + 1).padStart(2, '0')}-${String(f.getDate()).padStart(2, '0')}`
const hoyISO = () => aISO(new Date())
const inicioDeMes = () => aISO(new Date(new Date().getFullYear(), new Date().getMonth(), 1))
// Semana del gimnasio: lunes a sábado (domingo cerrado).
const semanaActual = () => {
  const hoy = new Date()
  const lunes = new Date(hoy)
  lunes.setDate(hoy.getDate() - ((hoy.getDay() + 6) % 7))
  const sabado = new Date(lunes)
  sabado.setDate(lunes.getDate() + 5)
  return [aISO(lunes), aISO(sabado)]
}

// Tarjeta de una fila para móvil (mismo dato que la tabla, en vertical).
function Tarjeta({ children }) {
  return (
    <Paper elevation={0} sx={{ p: 2, display: 'flex', flexDirection: 'column', gap: 0.5 }}>
      {children}
    </Paper>
  )
}

// Pantalla /reportes: presets día/semana/mes + rango manual. Cobros del rango
// (descargables en PDF) y vencimientos del rango (a quién le toca renovar).
// Mobile-first: en pantallas chicas cada sección es una lista de tarjetas dentro
// de un "pozo"; en escritorio, tabla. El corte es por breakpoint (sin doble DOM).
export default function Reportes() {
  const theme = useTheme()
  const esMovil = useMediaQuery(theme.breakpoints.down('sm'))

  const [desde, setDesde] = useState(hoyISO())
  const [hasta, setHasta] = useState(hoyISO())
  const [preset, setPreset] = useState('dia')
  const [detalle, setDetalle] = useState([])
  const [venc, setVenc] = useState([])
  const [error, setError] = useState('')
  const [cargando, setCargando] = useState(false)

  const cargar = async (d = desde, h = hasta) => {
    setError('')
    setCargando(true)
    try {
      const [det, ven] = await Promise.all([detalleCobros(d, h), vencimientos(d, h)])
      setDetalle(det)
      setVenc(ven)
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
      const [lun, sab] = semanaActual()
      setDesde(lun)
      setHasta(sab)
      cargar(lun, sab)
    } else {
      const ini = inicioDeMes()
      setDesde(ini)
      setHasta(hoy)
      cargar(ini, hoy)
    }
  }

  const total = detalle.reduce((acc, d) => acc + Number(d.monto), 0)

  const descargar = () => {
    pdfCobros({ filas: detalle, desde, hasta, total })
  }

  const tituloCobros = () => {
    if (preset === 'dia') {
      if (desde === hoyISO()) return `Cobros de hoy (${diaYMes(desde)}) de ${anioDe(desde)}`
      return `Cobros de ${diaYMes(desde)} de ${anioDe(desde)}`
    }
    if (preset === 'semana') return `Cobros de la semana (${fechaLarga(desde)} a ${fechaLarga(hasta)})`
    if (preset === 'mes') return `Cobros de ${nombreDelMes(desde)}`
    return `Cobros del ${fechaLarga(desde)} al ${fechaLarga(hasta)}`
  }

  const tituloVenc = () => {
    if (preset === 'dia') return 'Planes que vencen ese día'
    if (preset === 'semana') return 'Planes que vencen esta semana'
    if (preset === 'mes') return 'Planes que vencen este mes'
    return 'Planes que vencen en el rango'
  }

  return (
    <Box sx={{ maxWidth: 720, mx: 'auto', p: { xs: 2, sm: 3 }, display: 'flex', flexDirection: 'column', gap: 2 }}>
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

      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, flexWrap: 'wrap' }}>
        <Typography variant="h6" sx={{ flexGrow: 1, minWidth: 200 }}>
          {tituloCobros()} ({detalle.length})
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
                  <Typography variant="body2" color="text.secondary" noWrap>
                    {d.plan} · <Box component="span" sx={{ textTransform: 'capitalize' }}>{d.forma}</Box>
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
                <TableCell>Tipo de pago</TableCell>
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
                  <TableCell sx={{ textTransform: 'capitalize' }}>{d.forma}</TableCell>
                  <TableCell align="right">${d.monto}</TableCell>
                  <TableCell>{d.folio ?? '—'}</TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      )}

      <Typography variant="h6">{tituloVenc()} ({venc.length})</Typography>
      {venc.length === 0 ? (
        <Typography variant="body2" color="text.secondary">
          Sin vencimientos en ese rango
        </Typography>
      ) : esMovil ? (
        <CardWell>
          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1.5 }}>
            {venc.map((f) => (
              <Tarjeta key={f.socio_id}>
                <Box sx={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', gap: 1 }}>
                  <Typography variant="subtitle2" sx={{ fontWeight: 700 }} noWrap>
                    {f.nombre} {f.apellidos ?? ''}
                  </Typography>
                  {f.plan && <Chip size="small" label={f.plan} color="primary" variant="outlined" />}
                </Box>
                <Typography variant="body2" color="text.secondary">
                  Vence el {fechaLarga(f.vence_en)}
                </Typography>
                {f.telefono && (
                  <Typography variant="caption" color="text.secondary">
                    {f.telefono}
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
                <TableCell>Vence el</TableCell>
                <TableCell>Plan</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {venc.map((f) => (
                <TableRow key={f.socio_id}>
                  <TableCell>
                    {f.nombre} {f.apellidos ?? ''}
                    {f.telefono ? ` · ${f.telefono}` : ''}
                  </TableCell>
                  <TableCell>{fechaLarga(f.vence_en)}</TableCell>
                  <TableCell>{f.plan ?? '—'}</TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      )}
    </Box>
  )
}
