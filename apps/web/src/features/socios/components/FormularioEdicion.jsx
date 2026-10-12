import { useState } from 'react'
import Paper from '@mui/material/Paper'
import Box from '@mui/material/Box'
import TextField from '@mui/material/TextField'
import Button from '@mui/material/Button'
import Typography from '@mui/material/Typography'
import Alert from '@mui/material/Alert'
import { validarContacto } from '../models/socioModel'

// Edición de datos de contacto (lo único que el cliente puede escribir, 0008_rls).
function FormularioEdicion({ registro, onActualizar, onCancelar }) {
  const [nombre, setNombre] = useState(registro.nombre ?? '')
  const [apellidos, setApellidos] = useState(registro.apellidos ?? '')
  const [telefono, setTelefono] = useState(registro.telefono ?? '')
  const [correo, setCorreo] = useState(registro.correo ?? '')
  const [error, setError] = useState('')
  const [idEditado, setIdEditado] = useState(registro.id)

  if (registro.id !== idEditado) {
    setIdEditado(registro.id)
    setNombre(registro.nombre ?? '')
    setApellidos(registro.apellidos ?? '')
    setTelefono(registro.telefono ?? '')
    setCorreo(registro.correo ?? '')
  }

  const manejarEnvio = (evento) => {
    evento.preventDefault()

    const mensajeError = validarContacto(nombre, apellidos, telefono)
    if (mensajeError) {
      setError(mensajeError)
      return
    }

    onActualizar({ ...registro, nombre, apellidos, telefono, correo })
    setError('')
  }

  return (
    <Paper sx={{ p: 3, mb: 3 }} elevation={2}>
      <Typography variant="h6" sx={{ mb: 2 }}>
        Editar Socio
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
          label="Apellidos"
          value={apellidos}
          onChange={(e) => setApellidos(e.target.value)}
          size="small"
        />
        <TextField
          label="Telefono"
          value={telefono}
          onChange={(e) => setTelefono(e.target.value)}
          size="small"
        />
        <TextField
          label="Correo (opcional)"
          type="email"
          value={correo}
          onChange={(e) => setCorreo(e.target.value)}
          size="small"
        />
        <Button type="submit" variant="contained">
          Guardar
        </Button>
        <Button variant="outlined" onClick={onCancelar}>
          Cancelar
        </Button>
      </Box>
    </Paper>
  )
}

export default FormularioEdicion
