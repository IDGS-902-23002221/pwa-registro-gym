import Paper from '@mui/material/Paper';
import Table from '@mui/material/Table';
import TableBody from '@mui/material/TableBody';
import TableCell from '@mui/material/TableCell';
import TableContainer from '@mui/material/TableContainer';
import TableHead from '@mui/material/TableHead';
import TableRow from '@mui/material/TableRow';
import IconButton from '@mui/material/IconButton';
import Typography from '@mui/material/Typography';
import DeleteIcon from '@mui/icons-material/Delete';
import EditIcon from '@mui/icons-material/Edit';
import VisibilityIcon from '@mui/icons-material/Visibility';

function TablaMembresias({ registros, onEliminar, onEditar, onVerDetalle }) {

  const filas = [];
  registros.forEach((registro, indice) => {
    filas.push(
      <TableRow key={registro.id}>
        <TableCell>{indice + 1}</TableCell>
        <TableCell>{registro.nombre}</TableCell>
        <TableCell>{`$${registro.precio}`}</TableCell>
        <TableCell>{registro.duracion}</TableCell>
        <TableCell align="right">

          <IconButton
            size="small"
            color="info"
            onClick={() => onVerDetalle(registro.id)}
            aria-label={`Ver detalle de ${registro.nombre}`}
          >
            <VisibilityIcon fontSize="small" />
          </IconButton>

          <IconButton
            size="small"
            color="primary"
            onClick={() => onEditar(registro.id)}
            aria-label={`Editar registro de ${registro.nombre}`}
          >
            <EditIcon fontSize="small" />
          </IconButton>

          <IconButton
            size="small"
            color="error"
            onClick={() => onEliminar(registro.id)}
            aria-label={`Eliminar registro de ${registro.nombre}`}
          >
            <DeleteIcon fontSize="small" />
          </IconButton>

        </TableCell>
      </TableRow>
    );
  });

  return (
    <TableContainer component={Paper} elevation={2}>
      <Table size="small">
        <TableHead>
          <TableRow>
            <TableCell>#</TableCell>
            <TableCell>Nombre</TableCell>
            <TableCell>Precio</TableCell>
            <TableCell>Duracion (meses)</TableCell>
            <TableCell align="right">Acciones</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {filas.length > 0 ? (
            filas
          ) : (
            <TableRow>
              <TableCell colSpan={5}>
                <Typography variant="body2" color="text.secondary" align="center">
                  Aun no hay registros
                </Typography>
              </TableCell>
            </TableRow>
          )}
        </TableBody>
      </Table>
    </TableContainer>
  );
}

export default TablaMembresias;