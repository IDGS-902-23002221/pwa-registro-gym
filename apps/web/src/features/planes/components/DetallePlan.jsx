import { useEffect, useState } from 'react'
import Dialog from '@mui/material/Dialog'
import DialogTitle from '@mui/material/DialogTitle'
import DialogContent from '@mui/material/DialogContent'
import DialogActions from '@mui/material/DialogActions'
import Button from '@mui/material/Button'
import Box from '@mui/material/Box'
import TextField from '@mui/material/TextField'
import Typography from '@mui/material/Typography'
import Alert from '@mui/material/Alert'

// Detalle de un plan y edición de su precio (0016: es lo único editable; el
// cambio rige para cobros nuevos y no toca los cobros pasados).
// onGuardarPrecio es async y regresa { ok, mensaje }.
function DetallePlan({ registro, abierto, onCerrar, onGuardarPrecio }) {
  const [precio, setPrecio] = useState('')
  const [error, setError] = useState('')
  const [aviso, setAviso] = useState('')
  const [guardando, setGuardando] = useState(false)

  // Resincroniza al cambiar de plan (no en cada recarga, para no borrar el aviso).
  useEffect(() => {
    if (registro) {
      setPrecio(String(registro.precio_mxn))
      setError('')
      setAviso('')
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [registro?.id])

  if (!registro) {
    return null
  }

  const guardar = async (evento) => {
    evento.preventDefault()

    const p = Number(precio)
    if (String(precio).trim() === '' || Number.isNaN(p) || p <= 0) {
      setError('El precio debe ser mayor a cero')
      setAviso('')
      return
    }

    setGuardando(true)
    try {
      const res = await onGuardarPrecio(registro.id, p)
      if (res?.ok === false) {
        setError(res.mensaje)
        setAviso('')
        return
      }
      setError('')
      setAviso('Precio actualizado. Rige para cobros nuevos; los cobros pasados no cambian.')
    } finally {
      setGuardando(false)
    }
  }

  const datos = [
    { etiqueta: 'Nombre', valor: registro.nombre },
    { etiqueta: 'Días del periodo', valor: registro.dias_periodo },
    { etiqueta: 'Estado', valor: registro.activo ? 'Activo' : 'Inactivo' },
  ]

  return (
    <Dialog open={abierto} onClose={onCerrar} fullWidth maxWidth="xs">
      <DialogTitle>Detalle del plan</DialogTitle>
      <DialogContent>
        {datos.map((dato) => (
          <Box key={dato.etiqueta} sx={{ mb: 2 }}>
            <Typography variant="caption" color="text.secondary">
              {dato.etiqueta}
            </Typography>
            <Typography variant="body1">{dato.valor}</Typography>
          </Box>
        ))}

        <Box
          component="form"
          onSubmit={guardar}
          sx={{ display: 'flex', alignItems: 'flex-start', gap: 1, mt: 1 }}
        >
          <TextField
            label="Precio (MXN)"
            type="number"
            inputProps={{ step: '0.01', min: '0' }}
            value={precio}
            onChange={(e) => setPrecio(e.target.value)}
            size="small"
            fullWidth
          />
          <Button type="submit" variant="contained" disabled={guardando}>
            {guardando ? 'Guardando…' : 'Guardar'}
          </Button>
        </Box>

        {error && (
          <Alert severity="error" sx={{ mt: 2 }}>
            {error}
          </Alert>
        )}
        {aviso && (
          <Alert severity="success" sx={{ mt: 2 }}>
            {aviso}
          </Alert>
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

export default DetallePlan
