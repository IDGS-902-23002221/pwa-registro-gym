import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import Typography from '@mui/material/Typography'
import ModuloInicio from '../features/inicio/components/ModuloInicio'
import ModuloSocios from '../features/socios/components/ModuloSocios'
import ModuloPlanes from '../features/planes/components/ModuloPlanes'
import useSocios from '../features/socios/hooks/useSocios'
import usePlanes from '../features/planes/hooks/usePlanes'
import useAuth from '../features/auth/hooks/useAuth'
import TopBar from '../shared/layouts/TopBar'
import Login from '../pages/Login'
import RegistrarPago from '../pages/RegistrarPago'
import Reportes from '../pages/Reportes'

// Guard + topbar: sin sesión va a /login; con sesión, muestra la barra superior
// y la página. Ahora cada sección es una ruta, así el botón "Atrás" del celular
// y los enlaces directos se comportan solos.
function Autenticado({ auth, children }) {
  if (auth.cargando) {
    return <Typography sx={{ p: 3 }}>Cargando sesión…</Typography>
  }
  if (!auth.sesion) {
    return <Navigate to="/login" replace />
  }
  return (
    <>
      <TopBar onSalir={() => auth.salir()} />
      {children}
    </>
  )
}

function PaginaSocios() {
  const socios = useSocios()
  return <ModuloSocios socios={socios} />
}

function PaginaPlanes() {
  const planes = usePlanes()
  return <ModuloPlanes planes={planes} />
}

function App() {
  const auth = useAuth()

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login auth={auth} />} />
        <Route
          path="/inicio"
          element={
            <Autenticado auth={auth}>
              <ModuloInicio />
            </Autenticado>
          }
        />
        <Route
          path="/socios"
          element={
            <Autenticado auth={auth}>
              <PaginaSocios />
            </Autenticado>
          }
        />
        <Route
          path="/planes"
          element={
            <Autenticado auth={auth}>
              <PaginaPlanes />
            </Autenticado>
          }
        />
        <Route
          path="/pagar"
          element={
            <Autenticado auth={auth}>
              <RegistrarPago />
            </Autenticado>
          }
        />
        <Route
          path="/reportes"
          element={
            <Autenticado auth={auth}>
              <Reportes />
            </Autenticado>
          }
        />
        <Route path="/" element={<Navigate to="/inicio" replace />} />
        <Route path="*" element={<Navigate to="/inicio" replace />} />
      </Routes>
    </BrowserRouter>
  )
}

export default App
