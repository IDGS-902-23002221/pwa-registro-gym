import { useTheme } from '@mui/material/styles'
import useMediaQuery from '@mui/material/useMediaQuery'
import Paper from '@mui/material/Paper'
import Box from '@mui/material/Box'
import Table from '@mui/material/Table'
import TableBody from '@mui/material/TableBody'
import TableCell from '@mui/material/TableCell'
import TableContainer from '@mui/material/TableContainer'
import TableHead from '@mui/material/TableHead'
import TableRow from '@mui/material/TableRow'
import IconButton from '@mui/material/IconButton'
import Switch from '@mui/material/Switch'
import Chip from '@mui/material/Chip'
import Typography from '@mui/material/Typography'
import VisibilityIcon from '@mui/icons-material/Visibility'
import CardWell from '../../../shared/CardWell'

const precio = (n) => `$${Number(n).toFixed(2)}`

// Catálogo de planes. Mobile-first: en pantallas chicas, lista de tarjetas dentro
// de un "pozo" (contenedor con borde y relleno desvanecido) para que contrasten;
// en escritorio, tabla. El switch activa/desactiva (no borra); "Detalle" abre el
// diálogo donde además se edita el precio.
//
// El cambio tabla/tarjetas es sólo render condicional por breakpoint: no hay
// cálculo pesado ni doble DOM, así que no afecta el rendimiento.
function TablaPlanes({ registros = [], cargando = false, onVerDetalle, onCambiarEstado }) {
  const theme = useTheme()
  const esMovil = useMediaQuery(theme.breakpoints.down('sm'))

  if (registros.length === 0) {
    return (
      <Paper elevation={0} sx={{ p: 3 }}>
        <Typography variant="body2" color="text.secondary" align="center">
          {cargando ? 'Cargando…' : 'Aún no hay planes'}
        </Typography>
      </Paper>
    )
  }

  if (esMovil) {
    return (
      <CardWell>
        <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1 }}>
          {registros.map((registro) => (
            <Paper
              key={registro.id}
              elevation={0}
              sx={{
                px: 1.5,
                py: 1,
                display: 'flex',
                flexDirection: 'column',
                gap: 0.5,
                opacity: registro.activo ? 1 : 0.6,
              }}
            >
              <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 1 }}>
                <Typography variant="subtitle2" sx={{ fontWeight: 700 }} noWrap>
                  {registro.nombre}
                </Typography>
                <Chip
                  size="small"
                  label={registro.activo ? 'Activo' : 'Inactivo'}
                  color={registro.activo ? 'success' : 'default'}
                  variant={registro.activo ? 'filled' : 'outlined'}
                  sx={{ height: 20, fontSize: 11 }}
                />
              </Box>

              <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 1 }}>
                <Box sx={{ display: 'flex', alignItems: 'baseline', gap: 1, minWidth: 0 }}>
                  <Typography variant="subtitle1" sx={{ fontVariantNumeric: 'tabular-nums', fontWeight: 700 }}>
                    {precio(registro.precio_mxn)}
                  </Typography>
                  <Typography variant="caption" color="text.secondary">
                    {registro.dias_periodo} {registro.dias_periodo === 1 ? 'día' : 'días'}
                  </Typography>
                </Box>
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.25 }}>
                  <IconButton
                    size="small"
                    color="info"
                    onClick={() => onVerDetalle(registro.id)}
                    aria-label={`Ver detalle de ${registro.nombre}`}
                  >
                    <VisibilityIcon fontSize="small" />
                  </IconButton>
                  <Switch
                    size="small"
                    checked={registro.activo}
                    onChange={(e) => onCambiarEstado(registro.id, e.target.checked)}
                    inputProps={{ 'aria-label': `Activar o desactivar ${registro.nombre}` }}
                  />
                </Box>
              </Box>
            </Paper>
          ))}
        </Box>
      </CardWell>
    )
  }

  return (
    <TableContainer component={Paper} elevation={0}>
      <Table size="small">
        <TableHead>
          <TableRow>
            <TableCell>#</TableCell>
            <TableCell>Nombre</TableCell>
            <TableCell>Precio</TableCell>
            <TableCell>Días</TableCell>
            <TableCell>Activo</TableCell>
            <TableCell align="right">Acciones</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {registros.map((registro, indice) => (
            <TableRow key={registro.id} sx={{ opacity: registro.activo ? 1 : 0.6 }}>
              <TableCell>{indice + 1}</TableCell>
              <TableCell>{registro.nombre}</TableCell>
              <TableCell>{precio(registro.precio_mxn)}</TableCell>
              <TableCell>{registro.dias_periodo}</TableCell>
              <TableCell>
                <Switch
                  size="small"
                  checked={registro.activo}
                  onChange={(e) => onCambiarEstado(registro.id, e.target.checked)}
                  inputProps={{ 'aria-label': `Activar o desactivar ${registro.nombre}` }}
                />
              </TableCell>
              <TableCell align="right">
                <IconButton
                  size="small"
                  color="info"
                  onClick={() => onVerDetalle(registro.id)}
                  aria-label={`Ver detalle de ${registro.nombre}`}
                >
                  <VisibilityIcon fontSize="small" />
                </IconButton>
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </TableContainer>
  )
}

export default TablaPlanes
