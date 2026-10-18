import { useLocation, useNavigate } from 'react-router-dom'
import AppBar from '@mui/material/AppBar'
import Toolbar from '@mui/material/Toolbar'
import Tabs from '@mui/material/Tabs'
import Tab from '@mui/material/Tab'
import Box from '@mui/material/Box'
import Typography from '@mui/material/Typography'
import IconButton from '@mui/material/IconButton'
import Tooltip from '@mui/material/Tooltip'
import LogoutIcon from '@mui/icons-material/Logout'

// Barra superior (topbar) única para toda la app con sesión: marca + secciones +
// salir. La sección activa se deriva de la ruta, así el botón "Atrás" del celular
// y los enlaces directos funcionan solos. En móvil las pestañas van a lo ancho.
const SECCIONES = [
  { valor: 'socios', etiqueta: 'Socios', ruta: '/socios' },
  { valor: 'planes', etiqueta: 'Planes', ruta: '/planes' },
  { valor: 'cobrar', etiqueta: 'Cobrar', ruta: '/pagar' },
  { valor: 'reportes', etiqueta: 'Reportes', ruta: '/reportes' },
]

const seccionDe = (pathname) =>
  SECCIONES.find((s) => pathname.startsWith(s.ruta))?.valor ?? 'socios'

function TopBar({ onSalir }) {
  const navegar = useNavigate()
  const { pathname } = useLocation()

  return (
    <AppBar position="sticky">
      <Toolbar sx={{ gap: 1.5 }}>
        <Typography variant="h6" component="div" sx={{ fontWeight: 800, letterSpacing: '-0.02em' }}>
          Gym
        </Typography>
        <Box sx={{ flexGrow: 1 }} />
        <Tooltip title="Salir">
          <IconButton onClick={onSalir} aria-label="Salir" size="small">
            <LogoutIcon fontSize="small" />
          </IconButton>
        </Tooltip>
      </Toolbar>
      <Tabs
        value={seccionDe(pathname)}
        onChange={(e, valor) => navegar(SECCIONES.find((s) => s.valor === valor).ruta)}
        variant="fullWidth"
        textColor="inherit"
        sx={{
          minHeight: 46,
          borderTop: '1px solid',
          borderColor: 'divider',
          '& .MuiTab-root': { minHeight: 46, fontWeight: 700 },
        }}
      >
        {SECCIONES.map((s) => (
          <Tab key={s.valor} value={s.valor} label={s.etiqueta} />
        ))}
      </Tabs>
    </AppBar>
  )
}

export default TopBar
