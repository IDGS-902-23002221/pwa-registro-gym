import Box from '@mui/material/Box'
import { color, shape } from '../app/tokens'

// Contenedor "pozo": recuadro con borde y relleno desvanecido que agrupa una
// lista de tarjetas para que éstas contrasten contra él. Se usa en las vistas
// móviles (planes, reportes) para dar sensación de profundidad por capas.
export default function CardWell({ children, sx, ...props }) {
  return (
    <Box
      {...props}
      sx={{
        p: 1.5,
        borderRadius: `${shape.radius.lg}px`,
        border: `1px solid ${color.line}`,
        backgroundImage: 'linear-gradient(180deg, rgba(0,0,0,0.34), rgba(0,0,0,0.10))',
        boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.04)',
        ...sx,
      }}
    >
      {children}
    </Box>
  )
}
