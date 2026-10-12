import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import Box from '@mui/material/Box'
import Button from '@mui/material/Button'
import TextField from '@mui/material/TextField'
import MenuItem from '@mui/material/MenuItem'
import Typography from '@mui/material/Typography'
import Alert from '@mui/material/Alert'
import Paper from '@mui/material/Paper'
import { listar as listarSocios } from '../features/socios/services/sociosService'
import { listarPlanes, registrarPago, mensajeDeError } from '../features/pagos/services/pagosService'

const FORMAS_PAGO = ['efectivo', 'transferencia', 'tarjeta']

// Primer día del mes actual en YYYY-MM-DD (el periodo siempre es inicio de mes).
const inicioDeMesActual = () => {
  const hoy = new Date()
  return `${hoy.getFullYear()}-${String(hoy.getMonth() + 1).padStart(2, '0')}-01`
}

// Pantalla /pagar: cobra un periodo con registrar_pago y muestra el recibo.
// Renovar es cobrar el siguiente periodo con esta misma pantalla.
export default function RegistrarPago() {
  const navegar = useNavigate()
  const [q, setQ] = useState('')
  const [socios, setSocios] = useState([])
  const [socioId, setSocioId] = useState('')
  const [planes, setPlanes] = useState([])
  const [planId, setPlanId] = useState('')
  const [monto, setMonto] = useState('')
  const [formaPago, setFormaPago] = useState('efectivo')
  const [periodo, setPeriodo] = useState(inicioDeMesActual())
  const [referencia, setReferencia] = useState('')
  const [error, setError] = useState('')
  const [recibo, setRecibo] = useState(null)
  const [enviando, setEnviando] = useState(false)

  useEffect(() => {
    listarPlanes().then(setPlanes).catch((e) => setError(e.message))
  }, [])

  useEffect(() => {
    if (!q.trim()) {
      setSocios([])
      return
    }
    const t = setTimeout(() => {
      listarSocios({ busqueda: q }).then(setSocios).catch(() => {})
    }, 300)
    return () => clearTimeout(t)
  }, [q])

  const elegirPlan = (id) => {
    setPlanId(id)
    const plan = planes.find((p) => p.id === id)
    if (plan) setMonto(String(plan.precio_mxn))
  }

  const socioElegido = socios.find((s) => s.id === socioId)

  const cobrar = async (e) => {
    e.preventDefault()
    setError('')
    setRecibo(null)
    if (!socioId) {
      setError('Elige un socio de la lista')
      return
    }
    if (!planId) {
      setError('Elige un plan del catálogo')
      return
    }
    setEnviando(true)
    try {
      const r = await registrarPago({
        socioId,
        monto: Number(monto),
        formaPago,
        periodo,
        referencia,
        planId,
      })
      setRecibo(r)
    } catch (err) {
      setError(mensajeDeError(err))
    } finally {
      setEnviando(false)
    }
  }

  return (
    <Box sx={{ maxWidth: 480, mx: 'auto', p: 3, display: 'flex', flexDirection: 'column', gap: 2 }}>
      <Button variant="text" sx={{ alignSelf: 'flex-start' }} onClick={() => navegar('/')}>
        ← Volver
      </Button>
      <Typography variant="h5" component="h1">Registrar pago</Typography>
      {error && <Alert severity="error">{error}</Alert>}
      {recibo && (
        <Alert severity="success">
          Cobro registrado. Folio {recibo.folio} · cubierto hasta {recibo.pagado_hasta}.
        </Alert>
      )}

      <TextField
        label="Buscar socio por nombre"
        value={socioElegido ? `${socioElegido.nombre} ${socioElegido.apellidos ?? ''}`.trim() : q}
        onChange={(e) => {
          setSocioId('')
          setQ(e.target.value)
        }}
        size="small"
        fullWidth
      />
      {!socioElegido &&
        socios.map((s) => (
          <Button
            key={s.id}
            variant="text"
            sx={{ justifyContent: 'flex-start' }}
            onClick={() => setSocioId(s.id)}
          >
            {s.nombre} {s.apellidos ?? ''} ({s.estado_calculado})
          </Button>
        ))}

      <TextField
        select
        label="Plan"
        value={planId}
        onChange={(e) => elegirPlan(e.target.value)}
        size="small"
        fullWidth
      >
        {planes.map((p) => (
          <MenuItem key={p.id} value={p.id}>
            {p.nombre} — ${p.precio_mxn}
          </MenuItem>
        ))}
      </TextField>

      <Box component="form" onSubmit={cobrar} sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
        <TextField
          label="Monto (MXN)"
          type="number"
          inputProps={{ step: '0.01', min: '0' }}
          value={monto}
          onChange={(e) => setMonto(e.target.value)}
          size="small"
          required
        />
        <TextField
          select
          label="Forma de pago"
          value={formaPago}
          onChange={(e) => setFormaPago(e.target.value)}
          size="small"
        >
          {FORMAS_PAGO.map((f) => (
            <MenuItem key={f} value={f}>
              {f}
            </MenuItem>
          ))}
        </TextField>
        <TextField
          label="Periodo (primer día del mes)"
          type="date"
          value={periodo}
          onChange={(e) => setPeriodo(e.target.value)}
          size="small"
          required
        />
        <TextField
          label="Referencia (opcional)"
          value={referencia}
          onChange={(e) => setReferencia(e.target.value)}
          size="small"
        />
        <Button type="submit" variant="contained" disabled={enviando}>
          {enviando ? 'Cobrando…' : 'Cobrar'}
        </Button>
      </Box>

      {recibo && (
        <Paper sx={{ p: 2 }} elevation={2}>
          <Typography variant="subtitle2">Recibo folio {recibo.folio}</Typography>
          <Typography variant="body2">Periodo: {recibo.periodo}</Typography>
          <Typography variant="body2">Pagado hasta: {recibo.pagado_hasta}</Typography>
          <Typography variant="body2">Vigencia membresía: {recibo.termina_en}</Typography>
        </Paper>
      )}
    </Box>
  )
}
