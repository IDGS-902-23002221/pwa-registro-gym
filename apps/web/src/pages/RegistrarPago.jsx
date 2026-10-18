import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import Box from '@mui/material/Box'
import Button from '@mui/material/Button'
import IconButton from '@mui/material/IconButton'
import TextField from '@mui/material/TextField'
import MenuItem from '@mui/material/MenuItem'
import Typography from '@mui/material/Typography'
import Alert from '@mui/material/Alert'
import Paper from '@mui/material/Paper'
import Chip from '@mui/material/Chip'
import AddIcon from '@mui/icons-material/Add'
import RemoveIcon from '@mui/icons-material/Remove'
import CardWell from '../shared/CardWell'
import { listar as listarSocios } from '../features/socios/services/sociosService'
import { listarPlanes, registrarPago, mensajeDeError } from '../features/pagos/services/pagosService'
import { fechaLarga, nombreDelMes } from '../shared/formatFecha'

const FORMAS_PAGO = ['efectivo', 'transferencia', 'tarjeta']

// Hoy en YYYY-MM-DD. Desde la 0011 el periodo es la fecha de inicio de
// cobertura (cualquier día): por defecto, el socio empieza hoy.
const hoyISO = () => {
  const hoy = new Date()
  return `${hoy.getFullYear()}-${String(hoy.getMonth() + 1).padStart(2, '0')}-${String(hoy.getDate()).padStart(2, '0')}`
}

// Aritmética en UTC para no mover el día por zona horaria.
const aFecha = (iso) => {
  const [a, m, d] = iso.split('-').map(Number)
  return new Date(Date.UTC(a, m - 1, d))
}
const aISO = (f) =>
  `${f.getUTCFullYear()}-${String(f.getUTCMonth() + 1).padStart(2, '0')}-${String(f.getUTCDate()).padStart(2, '0')}`
const masDias = (iso, n) => {
  const f = aFecha(iso)
  f.setUTCDate(f.getUTCDate() + n)
  return aISO(f)
}

// Vista previa client-side (misma fórmula del servidor): base = max(pagado_hasta,
// periodo - 1) y se suman los días del plan por cada mensualidad.
const previsualizar = (periodo, dias, meses, pagadoHasta) => {
  if (!periodo || !dias || meses < 1) return null
  let base = masDias(periodo, -1)
  if (pagadoHasta && pagadoHasta > base) base = pagadoHasta
  let fin = base
  for (let i = 0; i < meses; i++) fin = masDias(fin, dias)
  return { inicio: periodo, fin, meses }
}

// Pantalla /pagar: cobra N mensualidades encadenadas con registrar_pago y muestra
// los recibos. Renovar es cobrar el siguiente periodo con esta misma pantalla.
export default function RegistrarPago() {
  const navegar = useNavigate()
  const [q, setQ] = useState('')
  const [socios, setSocios] = useState([])
  const [socioId, setSocioId] = useState('')
  const [planes, setPlanes] = useState([])
  const [planId, setPlanId] = useState('')
  const [monto, setMonto] = useState('')
  const [formaPago, setFormaPago] = useState('efectivo')
  const [periodo, setPeriodo] = useState(hoyISO)
  const [meses, setMeses] = useState(1)
  const [referencia, setReferencia] = useState('')
  const [error, setError] = useState('')
  const [recibos, setRecibos] = useState([])
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
  const planElegido = planes.find((p) => p.id === planId)
  // Sin socio no hay nada que cobrar: los campos nacen bloqueados.
  const bloqueado = !socioId
  const total = planElegido && monto ? (Number(monto) * meses).toFixed(2) : null

  // Al elegir socio, el inicio se auto-pone: día siguiente al vencimiento si
  // tiene cobertura vigente, hoy si no. Evita el GYM01 del caso común
  // (renovar) sin quitar la edición manual.
  useEffect(() => {
    if (!socioElegido) return
    const hoy = hoyISO()
    setPeriodo(
      socioElegido.pagado_hasta && socioElegido.pagado_hasta >= hoy
        ? masDias(socioElegido.pagado_hasta, 1)
        : hoy
    )
  }, [socioId])
  const vistaPrevia = previsualizar(
    periodo,
    planElegido?.dias_periodo,
    meses,
    socioElegido?.pagado_hasta
  )

  const cobrar = async (e) => {
    e.preventDefault()
    setError('')
    setRecibos([])
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
      const cobrados = []
      let inicio = periodo
      for (let i = 0; i < meses; i++) {
        // eslint-disable-next-line no-await-in-loop
        const r = await registrarPago({
          socioId,
          monto: Number(monto),
          formaPago,
          periodo: inicio,
          referencia: meses > 1 ? `${referencia.trim()} (${i + 1}/${meses})`.trim() : referencia,
          planId,
        })
        cobrados.push(r)
        inicio = masDias(r.pagado_hasta, 1)
      }
      setRecibos(cobrados)
      // Limpia el formulario para el siguiente cobro (los recibos quedan visibles).
      setSocioId('')
      setQ('')
      setPlanId('')
      setMonto('')
      setFormaPago('efectivo')
      setPeriodo(hoyISO())
      setMeses(1)
      setReferencia('')
    } catch (err) {
      setError(mensajeDeError(err))
    } finally {
      setEnviando(false)
    }
  }

  const ultimo = recibos[recibos.length - 1]

  return (
    <Box sx={{ maxWidth: 480, mx: 'auto', p: 3, display: 'flex', flexDirection: 'column', gap: 2 }}>
      <Button variant="text" sx={{ alignSelf: 'flex-start' }} onClick={() => navegar('/')}>
        ← Volver
      </Button>
      <Typography variant="h5" component="h1">Registrar pago</Typography>
      {error && <Alert severity="error">{error}</Alert>}
      {ultimo && (
        <Alert severity="success">
          Cobro registrado. Folio{recibos.length > 1 ? 's' : ''} {recibos.map((r) => r.folio).join(', ')} ·
          cubierto hasta el {fechaLarga(ultimo.pagado_hasta)}.
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
      {!socioElegido && socios.length > 0 && (
        <CardWell>
          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1 }}>
            {socios.map((s) => (
              <Paper
                key={s.id}
                elevation={0}
                role="button"
                tabIndex={0}
                onClick={() => setSocioId(s.id)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter' || e.key === ' ') setSocioId(s.id)
                }}
                sx={{
                  p: 1.5,
                  cursor: 'pointer',
                  display: 'flex',
                  flexDirection: 'column',
                  gap: 0.5,
                  '&:hover': { backgroundColor: 'action.hover' },
                }}
              >
                <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 1 }}>
                  <Typography variant="subtitle2" sx={{ fontWeight: 700 }} noWrap>
                    {s.nombre} {s.apellidos ?? ''}
                  </Typography>
                  <Chip
                    size="small"
                    label={s.estado_calculado}
                    color={
                      s.estado_calculado === 'activo'
                        ? 'success'
                        : s.estado_calculado === 'vencido'
                          ? 'warning'
                          : 'default'
                    }
                    variant={s.estado_calculado === 'activo' ? 'filled' : 'outlined'}
                    sx={{ height: 20, fontSize: 11 }}
                  />
                </Box>
                {s.pagado_hasta && (
                  <Typography variant="caption" color="text.secondary">
                    Pagado hasta el {fechaLarga(s.pagado_hasta)}
                  </Typography>
                )}
              </Paper>
            ))}
          </Box>
        </CardWell>
      )}
      {socioElegido?.pagado_hasta && socioElegido.pagado_hasta >= hoyISO() && (
        <Alert severity="info">
          Tiene membresía activa hasta el {fechaLarga(socioElegido.pagado_hasta)}. El cobro
          empezará el {fechaLarga(periodo)}.
        </Alert>
      )}

      <TextField
        select
        label="Plan"
        value={planId}
        onChange={(e) => elegirPlan(e.target.value)}
        size="small"
        fullWidth
        disabled={bloqueado}
        helperText={bloqueado ? 'Primero elige un socio de la lista' : ''}
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
          disabled={bloqueado}
        />
        <TextField
          select
          label="Forma de pago"
          value={formaPago}
          onChange={(e) => setFormaPago(e.target.value)}
          size="small"
          disabled={bloqueado}
        >
          {FORMAS_PAGO.map((f) => (
            <MenuItem key={f} value={f}>
              {f}
            </MenuItem>
          ))}
        </TextField>
        <TextField
          label="Inicio de cobertura (cualquier día)"
          type="date"
          value={periodo}
          onChange={(e) => setPeriodo(e.target.value)}
          size="small"
          required
          disabled={bloqueado}
        />
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
          <Typography variant="body2" sx={{ flexGrow: 1 }}>
            {planElegido ? `${planElegido.nombre} (${meses})` : 'Mensualidades'}
          </Typography>
          <IconButton
            size="small"
            aria-label="Quitar una mensualidad"
            disabled={bloqueado || meses <= 1}
            onClick={() => setMeses((m) => Math.max(1, m - 1))}
          >
            <RemoveIcon fontSize="small" />
          </IconButton>
          <Typography variant="body1" sx={{ minWidth: 24, textAlign: 'center' }}>
            {meses}
          </Typography>
          <IconButton
            size="small"
            aria-label="Agregar una mensualidad"
            disabled={bloqueado || meses >= 99}
            onClick={() => setMeses((m) => Math.min(99, m + 1))}
          >
            <AddIcon fontSize="small" />
          </IconButton>
        </Box>
        {total && (
          <Typography variant="body1">
            Total a cobrar: ${total} ({meses} × ${Number(monto).toFixed(2)})
          </Typography>
        )}
        {vistaPrevia && (
          <Alert severity="info">
            Se registra el {fechaLarga(vistaPrevia.inicio)} y queda cubierto hasta el{' '}
            {fechaLarga(vistaPrevia.fin)} ({meses} {meses === 1 ? 'mensualidad' : 'mensualidades'}).
          </Alert>
        )}
        <TextField
          label="Referencia (opcional)"
          value={referencia}
          onChange={(e) => setReferencia(e.target.value)}
          size="small"
          disabled={bloqueado}
        />
        <Button type="submit" variant="contained" disabled={enviando || bloqueado}>
          {enviando ? 'Cobrando…' : meses === 1 ? 'Cobrar' : `Cobrar ${meses} meses`}
        </Button>
      </Box>

      {ultimo && (
        <Paper sx={{ p: 2 }} elevation={2}>
          <Typography variant="subtitle2">
            Recibo{recibos.length > 1 ? 's' : ''} folio {recibos.map((r) => r.folio).join(', ')}
          </Typography>
          <Typography variant="body2">Periodo: {nombreDelMes(recibos[0].periodo)}</Typography>
          <Typography variant="body2">Pagado hasta: {fechaLarga(ultimo.pagado_hasta)}</Typography>
          <Typography variant="body2">Vigencia membresía: {fechaLarga(ultimo.termina_en)}</Typography>
        </Paper>
      )}
    </Box>
  )
}
