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
import Button from '@mui/material/Button'
import Chip from '@mui/material/Chip'
import Typography from '@mui/material/Typography'
import VisibilityIcon from '@mui/icons-material/Visibility'
import CardWell from '../../../shared/CardWell'

const colorEstado = (estado) =>
  estado === 'activo' ? 'success' : estado === 'vencido' ? 'warning' : 'default'

// Lista desde socios_con_estado. Mobile-first: tarjetas dentro de un "pozo" en
// pantallas chicas, tabla en escritorio. Acción única por fila ("Detalle"): todo
// lo demás (editar, eliminar ARCO) vive dentro del diálogo, como en Planes.
function TablaRegistros({ registros = [], cargando = false, onVerDetalle }) {
  const theme = useTheme()
  const esMovil = useMediaQuery(theme.breakpoints.down('sm'))

  if (registros.length === 0) {
    return (
      <Paper elevation={0} sx={{ p: 3 }}>
        <Typography variant="body2" color="text.secondary" align="center">
          {cargando ? 'Cargando…' : 'Aún no hay socios'}
        </Typography>
      </Paper>
    )
  }

  if (esMovil) {
    return (
      <CardWell>
        <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1.5 }}>
          {registros.map((registro) => (
            <Paper key={registro.id} elevation={0} sx={{ p: 2, display: 'flex', flexDirection: 'column', gap: 1 }}>
              <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 1 }}>
                <Box sx={{ minWidth: 0 }}>
                  <Typography variant="subtitle1" sx={{ fontWeight: 700 }} noWrap>
                    {registro.nombre} {registro.apellidos ?? ''}
                  </Typography>
                  <Typography variant="body2" color="text.secondary" noWrap>
                    {registro.telefono ?? 'Sin teléfono'}
                  </Typography>
                </Box>
                <Chip
                  size="small"
                  label={registro.estado_calculado ?? registro.estado}
                  color={colorEstado(registro.estado_calculado ?? registro.estado)}
                  variant={(registro.estado_calculado ?? registro.estado) === 'activo' ? 'filled' : 'outlined'}
                />
              </Box>
              <Button
                size="small"
                variant="outlined"
                startIcon={<VisibilityIcon fontSize="small" />}
                onClick={() => onVerDetalle(registro.id)}
                sx={{ alignSelf: 'flex-start' }}
              >
                Detalle
              </Button>
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
            <TableCell>Socio</TableCell>
            <TableCell>Teléfono</TableCell>
            <TableCell>Estado</TableCell>
            <TableCell align="right">Acciones</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {registros.map((registro, indice) => (
            <TableRow key={registro.id}>
              <TableCell>{indice + 1}</TableCell>
              <TableCell>
                {registro.nombre} {registro.apellidos}
              </TableCell>
              <TableCell>{registro.telefono ?? '—'}</TableCell>
              <TableCell>{registro.estado_calculado ?? registro.estado}</TableCell>
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

export default TablaRegistros
