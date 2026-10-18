import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import Box from '@mui/material/Box'
import Paper from '@mui/material/Paper'
import Button from '@mui/material/Button'
import TextField from '@mui/material/TextField'
import Typography from '@mui/material/Typography'
import Alert from '@mui/material/Alert'
import { gradient, elevation } from '../app/tokens'

// Pantalla /login: wrapper delgado, la sesión vive en useAuth (app/).
// Centrada y con identidad (ícono genérico de gimnasia, no una pesa).
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
    <Box sx={{ minHeight: '100dvh', display: 'grid', placeItems: 'center', p: 2 }}>
      <Paper
        component="form"
        onSubmit={enviar}
        elevation={0}
        sx={{
          width: '100%',
          maxWidth: 380,
          p: { xs: 3, sm: 4 },
          display: 'flex',
          flexDirection: 'column',
          gap: 2,
        }}
      >
        <Box sx={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 1.5, mb: 1 }}>
          <Box
            sx={{
              width: 68,
              height: 68,
              borderRadius: '50%',
              backgroundImage: gradient.brand,
              boxShadow: elevation.glow,
              display: 'grid',
              placeItems: 'center',
            }}
          >
            <Typography sx={{ fontWeight: 900, fontSize: 20, letterSpacing: '0.04em', color: '#0b0716' }}>
              GYM
            </Typography>
          </Box>
          <Typography variant="h5" component="h1">
            Bienvenido
          </Typography>
          <Typography variant="body2" color="text.secondary" align="center">
            Registro de socios y membresías
          </Typography>
        </Box>

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
        <Button type="submit" variant="contained" size="large" disabled={enviando}>
          {enviando ? 'Entrando…' : 'Entrar'}
        </Button>
      </Paper>
    </Box>
  )
}
