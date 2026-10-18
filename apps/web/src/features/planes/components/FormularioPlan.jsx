import { useState } from 'react'
import Paper from '@mui/material/Paper'
import Box from '@mui/material/Box'
import TextField from '@mui/material/TextField'
import Button from '@mui/material/Button'
import Typography from '@mui/material/Typography'
import Alert from '@mui/material/Alert'
import { validarCampos } from '../models/planModel'

// Alta de plan. onAgregar es async y regresa { ok, mensaje }.
function FormularioPlan({ onAgregar }) {
  const [nombre, setNombre] = useState('')
  const [precio, setPrecio] = useState('')
  const [dias, setDias] = useState('')
  const [error, setError] = useState('')
  const [enviando, setEnviando] = useState(false)

  const limpiar = () => {
    setNombre('')
    setPrecio('')
    setDias('')
  }

  const manejarEnvio = async (evento) => {
    evento.preventDefault()

    const mensajeError = validarCampos(nombre, precio, dias)
    if (mensajeError) {
      setError(mensajeError)
      return
    }

    setEnviando(true)
    try {
      const res = await onAgregar({ nombre, precio, dias })
      if (res?.ok === false) {
        setError(res.mensaje)
        return
      }
      setError('')
      limpiar()
    } finally {
      setEnviando(false)
    }
  }

  return (
    <Paper sx={{ p: 3, mb: 3 }} elevation={2}>
      <Typography variant="h6" sx={{ mb: 2 }}>
        Nuevo plan
      </Typography>

      {error && (
        <Alert severity="error" sx={{ mb: 2 }}>
          {error}
        </Alert>
      )}

      <Box
        component="form"
        onSubmit={manejarEnvio}
        sx={{ display: 'flex', flexWrap: 'wrap', gap: 2, alignItems: 'center' }}
      >
        <TextField
          label="Nombre"
          value={nombre}
          onChange={(e) => setNombre(e.target.value)}
          size="small"
        />
        <TextField
          label="Precio (MXN)"
          type="number"
          inputProps={{ step: '0.01', min: '0' }}
          value={precio}
          onChange={(e) => setPrecio(e.target.value)}
          size="small"
          sx={{ width: 150 }}
        />
        <TextField
          label="Días"
          type="number"
          inputProps={{ min: '1', max: '366' }}
          helperText="30 = mensual"
          value={dias}
          onChange={(e) => setDias(e.target.value)}
          size="small"
          sx={{ width: 130 }}
        />
        <Button type="submit" variant="contained" disabled={enviando}>
          {enviando ? 'Agregando…' : 'Agregar'}
        </Button>
      </Box>
    </Paper>
  )
}

export default FormularioPlan
