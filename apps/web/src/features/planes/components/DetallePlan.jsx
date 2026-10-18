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
import Switch from '@mui/material/Switch'
import FormControlLabel from '@mui/material/FormControlLabel'
import { validarCampos } from '../models/planModel'

// Edición completa de un plan en un solo lugar: nombre y días (0018), precio
// (0016) y estado (0017). Un solo "Guardar" aplica sólo lo que cambió, cada
// cambio por su rpc auditada. El precio rige cobros nuevos y no toca los pasados.
function DetallePlan({ registro, abierto, onCerrar, onGuardarDatos, onGuardarPrecio, onCambiarEstado }) {
  const [nombre, setNombre] = useState('')
  const [dias, setDias] = useState('')
  const [precio, setPrecio] = useState('')
  const [activo, setActivo] = useState(true)
  const [error, setError] = useState('')
  const [aviso, setAviso] = useState('')
  const [guardando, setGuardando] = useState(false)

  // Resincroniza al cambiar de plan (no en cada recarga, para no borrar el aviso).
  useEffect(() => {
    if (registro) {
      setNombre(registro.nombre)
      setDias(String(registro.dias_periodo))
      setPrecio(String(registro.precio_mxn))
      setActivo(registro.activo)
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
    setError('')
    setAviso('')

    const mensajeError = validarCampos(nombre, precio, dias)
    if (mensajeError) {
      setError(mensajeError)
      return
    }

    setGuardando(true)
    try {
      if (nombre.trim() !== registro.nombre || Number(dias) !== registro.dias_periodo) {
        const r = await onGuardarDatos(registro.id, { nombre, dias: Number(dias) })
        if (r?.ok === false) {
          setError(r.mensaje)
          return
        }
      }
      if (Number(precio) !== Number(registro.precio_mxn)) {
        const r = await onGuardarPrecio(registro.id, Number(precio))
        if (r?.ok === false) {
          setError(r.mensaje)
          return
        }
      }
      if (activo !== registro.activo) {
        const r = await onCambiarEstado(registro.id, activo)
        if (r?.ok === false) {
          setError(r.mensaje)
          return
        }
      }
      setAviso('Cambios guardados.')
    } finally {
      setGuardando(false)
    }
  }

  return (
    <Dialog open={abierto} onClose={onCerrar} fullWidth maxWidth="xs">
      <DialogTitle>Editar plan</DialogTitle>
      <DialogContent>
        <Box
          id="form-plan"
          component="form"
          onSubmit={guardar}
          sx={{ display: 'flex', flexDirection: 'column', gap: 2, mt: 1 }}
        >
          <TextField
            label="Nombre"
            value={nombre}
            onChange={(e) => setNombre(e.target.value)}
            size="small"
            fullWidth
          />
          <Box sx={{ display: 'flex', gap: 2 }}>
            <TextField
              label="Precio (MXN)"
              type="number"
              inputProps={{ step: '0.01', min: '0' }}
              value={precio}
              onChange={(e) => setPrecio(e.target.value)}
              size="small"
              fullWidth
            />
            <TextField
              label="Días"
              type="number"
              inputProps={{ min: '1', max: '366' }}
              helperText="30 = mensual"
              value={dias}
              onChange={(e) => setDias(e.target.value)}
              size="small"
              fullWidth
            />
          </Box>
          <FormControlLabel
            control={<Switch checked={activo} onChange={(e) => setActivo(e.target.checked)} />}
            label={
              <Typography variant="body2" color="text.secondary">
                {activo ? 'Activo (se puede vender)' : 'Inactivo (no se vende)'}
              </Typography>
            }
          />
          {error && <Alert severity="error">{error}</Alert>}
          {aviso && <Alert severity="success">{aviso}</Alert>}
        </Box>
      </DialogContent>
      <DialogActions>
        <Button variant="outlined" onClick={onCerrar}>
          Cerrar
        </Button>
        <Button type="submit" form="form-plan" variant="contained" disabled={guardando}>
          {guardando ? 'Guardando…' : 'Guardar'}
        </Button>
      </DialogActions>
    </Dialog>
  )
}

export default DetallePlan
