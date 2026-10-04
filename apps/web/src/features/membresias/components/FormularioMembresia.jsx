import { useState } from 'react';
import Paper from '@mui/material/Paper';
import Box from '@mui/material/Box';
import TextField from '@mui/material/TextField';
import Button from '@mui/material/Button';
import Typography from '@mui/material/Typography';
import Alert from '@mui/material/Alert';
import { validarCampos } from '../models/membresiaModel';


function FormularioMembresia({ onAgregar }) {
  const [nombre, setNombre] = useState('');
  const [precio, setPrecio] = useState('');
  const [duracion, setDuracion] = useState('');
  const [error, setError] = useState('');

  const limpiarFormulario = () => {
    setNombre('');
    setPrecio('');
    setDuracion('');
  };

  const manejarEnvio = (evento) => {
    evento.preventDefault();

    const mensajeError = validarCampos(nombre, precio, duracion);
    if (mensajeError) {
      setError(mensajeError);
      return;
    }

    const nuevoRegistro = {
      id: `mem-${Date.now()}`,
      nombre,
      precio,
      duracion,
    };

    onAgregar(nuevoRegistro);
    setError('');
    limpiarFormulario();
  };

  return (
    <Paper sx={{ p: 3, mb: 3 }} elevation={2}>
      <Typography variant="h6" sx={{ mb: 2 }}>
        Nueva Membresia
      </Typography>

      {error && (
        <Alert severity="error" sx={{ mb: 2 }}>
          {error}
        </Alert>
      )}

      <Box
        component="form"
        onSubmit={manejarEnvio}
        sx={{ display: 'flex', flexWrap: 'wrap', gap: 2, alignItems: 'center' }}
      >
        <TextField
          label="Nombre"
          value={nombre}
          onChange={(e) => setNombre(e.target.value)}
          size="small"
        />
        <TextField
          label="Precio"
          type="number"
          value={precio}
          onChange={(e) => setPrecio(e.target.value)}
          size="small"
          sx={{ width: 120 }}
        />
        <TextField
          label="Duracion (meses)"
          type="number"
          value={duracion}
          onChange={(e) => setDuracion(e.target.value)}
          size="small"
          sx={{ width: 160 }}
        />
        <Button type="submit" variant="contained">
          Agregar
        </Button>
      </Box>
    </Paper>
  );
}

export default FormularioMembresia;