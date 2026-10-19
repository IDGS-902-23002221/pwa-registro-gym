import { useState } from 'react'
import Paper from '@mui/material/Paper'
import Box from '@mui/material/Box'
import TextField from '@mui/material/TextField'
import Button from '@mui/material/Button'
import Typography from '@mui/material/Typography'
import Alert from '@mui/material/Alert'
import { validarContacto } from '../models/socioModel'
import { buscarHomonimos } from '../services/sociosService'

// Alta de socio: nombre + apellidos + teléfono (+ correo opcional).
// Sin membresía: la cobertura nace con el primer pago (registrar_pago).
//
// Antes de guardar se buscan homónimos (mismo nombre y apellidos, sin importar
// el teléfono). Si hay alguno, se avisa y se pide confirmar. La búsqueda va a la
// base, no a la lista ya cargada, así el aviso no depende de lo que esté en
// pantalla.
function FormularioRegistro({ onAgregar }) {
  const [nombre, setNombre] = useState('')
  const [apellidos, setApellidos] = useState('')
  const [telefono, setTelefono] = useState('')
  const [correo, setCorreo] = useState('')
  const [error, setError] = useState('')
  const [enviando, setEnviando] = useState(false)
  const [homonimos, setHomonimos] = useState([])
  const [confirmado, setConfirmado] = useState(false)

  const limpiarFormulario = () => {
    setNombre('')
    setApellidos('')
    setTelefono('')
    setCorreo('')
    setHomonimos([])
    setConfirmado(false)
  }

  // Si el usuario corrige algo después del aviso, el aviso se reinicia.
  const cambiar = (setter) => (evento) => {
    setter(evento.target.value)
    if (confirmado) {
      setConfirmado(false)
      setHomonimos([])
    }
  }

  const manejarEnvio = async (evento) => {
    evento.preventDefault()

    const mensajeError = validarContacto(nombre, apellidos, telefono)
    if (mensajeError) {
      setError(mensajeError)
      return
    }

    // Primera pasada: avisar si ya existe el mismo nombre.
    if (!confirmado) {
      setError('')
      setEnviando(true)
      try {
        const encontrados = await buscarHomonimos(nombre, apellidos)
        if (encontrados.length > 0) {
          setHomonimos(encontrados)
          setConfirmado(true)
          return
        }
      } catch {
        // Si la consulta falla, no bloquees el alta: la base sigue siendo la
        // última defensa (índice único nombre + apellidos + teléfono).
      } finally {
        setEnviando(false)
      }
    }

    setEnviando(true)
    const resultado = await onAgregar({
      nombre,
      apellidos,
      telefono,
      correo,
      homonimos: homonimos.length,
    })
    setEnviando(false)

    if (!resultado.ok) {
      setError(resultado.mensaje)
      return
    }
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
      {confirmado && (
        <Alert severity="warning" sx={{ mb: 2 }}>
          <Typography variant="body2" sx={{ fontWeight: 700, mb: 0.5 }}>
            Ya existe {homonimos.length === 1 ? 'un socio' : `${homonimos.length} socios`} con ese
            nombre:
          </Typography>
          {homonimos.map((h) => (
            <Typography key={h.id} variant="body2">
              • {h.nombre} {h.apellidos ?? ''}
              {h.telefono ? ` — ${h.telefono}` : ''}
            </Typography>
          ))}
          <Typography variant="body2" sx={{ mt: 1 }}>
            Si es la misma persona, búscala en <strong>Cobrar</strong> y renueva su membresía. Si
            es otra persona, confirma abajo.
          </Typography>
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
          onChange={cambiar(setNombre)}
          size="small"
          sx={{ width: { xs: '100%', sm: 200 } }}
        />
        <TextField
          label="Apellidos"
          value={apellidos}
          onChange={cambiar(setApellidos)}
          size="small"
          sx={{ width: { xs: '100%', sm: 200 } }}
        />
        <TextField
          label="Telefono"
          value={telefono}
          onChange={cambiar(setTelefono)}
          size="small"
          sx={{ width: { xs: '100%', sm: 160 } }}
        />
        <TextField
          label="Correo (opcional)"
          type="email"
          value={correo}
          onChange={cambiar(setCorreo)}
          size="small"
          sx={{ width: { xs: '100%', sm: 220 } }}
        />
        <Button
          type="submit"
          variant="contained"
          disabled={enviando}
          sx={{ width: { xs: '100%', sm: 'auto' } }}
        >
          {enviando ? 'Guardando…' : confirmado ? 'Es otra persona, guardar' : 'Agregar'}
        </Button>
      </Box>
    </Paper>
  )
}

export default FormularioRegistro
