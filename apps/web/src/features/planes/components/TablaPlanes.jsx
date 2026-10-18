import Paper from '@mui/material/Paper'
import Table from '@mui/material/Table'
import TableBody from '@mui/material/TableBody'
import TableCell from '@mui/material/TableCell'
import TableContainer from '@mui/material/TableContainer'
import TableHead from '@mui/material/TableHead'
import TableRow from '@mui/material/TableRow'
import IconButton from '@mui/material/IconButton'
import Switch from '@mui/material/Switch'
import Typography from '@mui/material/Typography'
import VisibilityIcon from '@mui/icons-material/Visibility'

// Catálogo de planes. El switch activa/desactiva (no borra); "ver detalle" abre
// el diálogo donde además se edita el precio.
function TablaPlanes({ registros = [], cargando = false, onVerDetalle, onCambiarEstado }) {
  const filas = registros.map((registro, indice) => (
    <TableRow key={registro.id} sx={{ opacity: registro.activo ? 1 : 0.55 }}>
      <TableCell>{indice + 1}</TableCell>
      <TableCell>{registro.nombre}</TableCell>
      <TableCell>{`$${Number(registro.precio_mxn).toFixed(2)}`}</TableCell>
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
  ))

  return (
    <TableContainer component={Paper} elevation={2}>
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
          {filas.length > 0 ? (
            filas
          ) : (
            <TableRow>
              <TableCell colSpan={6}>
                <Typography variant="body2" color="text.secondary" align="center">
                  {cargando ? 'Cargando…' : 'Aún no hay planes'}
                </Typography>
              </TableCell>
            </TableRow>
          )}
        </TableBody>
      </Table>
    </TableContainer>
  )
}

export default TablaPlanes
