import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import Box from '@mui/material/Box'
import Button from '@mui/material/Button'
import TextField from '@mui/material/TextField'
import Typography from '@mui/material/Typography'
import Alert from '@mui/material/Alert'

// Pantalla /login: wrapper delgado, la sesión vive en useAuth (app/).
export default function Login({ auth }) {
  const [correo, setCorreo] = useState('')
  const [contrasena, setContrasena] = useState('')
  const [enviando, setEnviando] = useState(false)
  const navegar = useNavigate()

  const enviar = async (e) => {
    e.preventDefault()
    setEnviando(true)
    const ok = await auth.entrar(correo.trim(), contrasena)
    setEnviando(false)
    if (ok) navegar('/', { replace: true })
  }

  return (
    <Box
      component="form"
      onSubmit={enviar}
      sx={{ display: 'flex', flexDirection: 'column', gap: 2, maxWidth: 360, mx: 'auto', p: 3 }}
    >
      <Typography variant="h5" component="h1">Iniciar sesión</Typography>
      {auth.error && <Alert severity="error">{auth.error}</Alert>}
      <TextField
        label="Correo"
        type="email"
        required
        value={correo}
        onChange={(e) => setCorreo(e.target.value)}
        autoComplete="email"
      />
      <TextField
        label="Contraseña"
        type="password"
        required
        value={contrasena}
        onChange={(e) => setContrasena(e.target.value)}
        autoComplete="current-password"
      />
      <Button type="submit" variant="contained" disabled={enviando}>
        {enviando ? 'Entrando…' : 'Entrar'}
      </Button>
    </Box>
  )
}
