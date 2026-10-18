import { useState } from 'react'
import Paper from '@mui/material/Paper'
import Box from '@mui/material/Box'
import TextField from '@mui/material/TextField'
import Button from '@mui/material/Button'
import Typography from '@mui/material/Typography'
import Alert from '@mui/material/Alert'
import { validarContacto } from '../models/socioModel'

// Normalización igual que la base (minúsculas, sin acentos, un solo espacio).
const normalizar = (texto) =>
  (texto ?? '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/\s+/g, ' ')
    .trim()

// Alta de socio: nombre + apellidos + teléfono (+ correo opcional).
// Sin membresía: la cobertura nace con el primer pago (registrar_pago).
function FormularioRegistro({ onAgregar, registros = [] }) {
  const [nombre, setNombre] = useState('')
  const [apellidos, setApellidos] = useState('')
  const [telefono, setTelefono] = useState('')
  const [correo, setCorreo] = useState('')
  const [error, setError] = useState('')
  const [aviso, setAviso] = useState('')
  const [enviando, setEnviando] = useState(false)

  const limpiarFormulario = () => {
    setNombre('')
    setApellidos('')
    setTelefono('')
    setCorreo('')
  }

  const manejarEnvio = async (evento) => {
    evento.preventDefault()

    const mensajeError = validarContacto(nombre, apellidos, telefono)
    if (mensajeError) {
      setError(mensajeError)
      return
    }

    setEnviando(true)
    const resultado = await onAgregar({ nombre, apellidos, telefono, correo })
    setEnviando(false)

    if (!resultado.ok) {
      setError(resultado.mensaje)
      return
    }
    // Aviso sin bloqueo (02 §4): mismo nombre con otro teléfono.
    const homonimo = registros.some(
      (r) =>
        normalizar(r.nombre) === normalizar(nombre) &&
        normalizar(r.apellidos) === normalizar(apellidos)
    )
    setAviso(
      homonimo
        ? 'Aviso: ya existe otro socio con ese mismo nombre (otro teléfono). Revisa que no sea la misma persona.'
        : ''
    )
    setError('')
    limpiarFormulario()
  }

  return (
    <Paper sx={{ p: 3, mb: 3 }} elevation={2}>
      <Typography variant="h6" sx={{ mb: 2 }}>
        Nuevo Socio
      </Typography>

      {error && (
        <Alert severity="error" sx={{ mb: 2 }}>
          {error}
        </Alert>
      )}
      {aviso && (
        <Alert severity="warning" sx={{ mb: 2 }}>
          {aviso}
        </Alert>
      )}

      <Box
        component="form"
        onSubmit={manejarEnvio}
        sx={{
          display: 'flex',
          flexDirection: { xs: 'column', sm: 'row' },
          flexWrap: { sm: 'wrap' },
          gap: 2,
          alignItems: { xs: 'stretch', sm: 'center' },
        }}
      >
        <TextField
          label="Nombre"
          value={nombre}
          onChange={(e) => setNombre(e.target.value)}
          size="small"
          sx={{ width: { xs: '100%', sm: 200 } }}
        />
        <TextField
          label="Apellidos"
          value={apellidos}
          onChange={(e) => setApellidos(e.target.value)}
          size="small"
          sx={{ width: { xs: '100%', sm: 200 } }}
        />
        <TextField
          label="Telefono"
          value={telefono}
          onChange={(e) => setTelefono(e.target.value)}
          size="small"
          sx={{ width: { xs: '100%', sm: 160 } }}
        />
        <TextField
          label="Correo (opcional)"
          type="email"
          value={correo}
          onChange={(e) => setCorreo(e.target.value)}
          size="small"
          sx={{ width: { xs: '100%', sm: 220 } }}
        />
        <Button
          type="submit"
          variant="contained"
          disabled={enviando}
          sx={{ width: { xs: '100%', sm: 'auto' } }}
        >
          {enviando ? 'Guardando…' : 'Agregar'}
        </Button>
      </Box>
    </Paper>
  )
}

export default FormularioRegistro
