import { useState } from 'react'
import { BrowserRouter, Navigate, Route, Routes, useNavigate } from 'react-router-dom'
import Box from '@mui/material/Box'
import Button from '@mui/material/Button'
import Typography from '@mui/material/Typography'
import ModuloSocios from '../features/socios/components/ModuloSocios'
import ModuloMembresias from '../features/membresias/components/ModuloMembresias'
import useSocios from '../features/socios/hooks/useSocios'
import useMembresias from '../features/membresias/hooks/useMembresias'
import useAuth from '../features/auth/hooks/useAuth'
import Login from '../pages/Login'
import RegistrarPago from '../pages/RegistrarPago'

// Guard: sin sesión va a /login; con sesión cargando muestra espera.
function RequiereSesion({ auth, children }) {
  if (auth.cargando) {
    return <Typography sx={{ p: 3 }}>Cargando sesión…</Typography>
  }
  if (!auth.sesion) {
    return <Navigate to="/login" replace />
  }
  return children
}

// app es el unico que conoce los dos features
// aqui viven los dos hooks para que el estado no se pierda al cambiar de pantalla
function Panel({ auth }) {
  const [vista, setVista] = useState('socios')
  const navegar = useNavigate()

  const socios = useSocios()
  const membresias = useMembresias()

  const salir = async () => {
    await auth.salir()
    navegar('/login', { replace: true })
  }

  return (
    <>
      <Box sx={{ display: 'flex', justifyContent: 'center', gap: 2, p: 1 }}>
        <Button
          variant={vista === 'socios' ? 'contained' : 'outlined'}
          onClick={() => setVista('socios')}
        >
          Socios
        </Button>
        <Button
          variant={vista === 'membresias' ? 'contained' : 'outlined'}
          onClick={() => setVista('membresias')}
        >
          Membresias
        </Button>
        <Button variant="text" color="inherit" onClick={() => navegar('/pagar')}>
          Cobrar
        </Button>
        <Button variant="text" color="inherit" onClick={salir}>
          Salir
        </Button>
      </Box>

      {vista === 'socios' ? (
        <ModuloSocios socios={socios} />
      ) : (
        <ModuloMembresias membresias={membresias} />
      )}
    </>
  )
}

function App() {
  const auth = useAuth()

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login auth={auth} />} />
        <Route
          path="/"
          element={
            <RequiereSesion auth={auth}>
              <Panel auth={auth} />
            </RequiereSesion>
          }
        />
        <Route
          path="/pagar"
          element={
            <RequiereSesion auth={auth}>
              <RegistrarPago />
            </RequiereSesion>
          }
        />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  )
}

export default App
