import { useState } from 'react';
import Paper from '@mui/material/Paper';
import Box from '@mui/material/Box';
import TextField from '@mui/material/TextField';
import MenuItem from '@mui/material/MenuItem';
import Button from '@mui/material/Button';
import Typography from '@mui/material/Typography';
import Alert from '@mui/material/Alert';
import { validarCampos } from '../models/socioModel';

// membresias llega por props para llenar el select
function FormularioRegistro({ onAgregar, membresias }) {
  const [nombre, setNombre] = useState('');
  const [email, setEmail] = useState('');
  const [telefono, setTelefono] = useState('');
  const [membresiaId, setMembresiaId] = useState('');
  const [error, setError] = useState('');

  const limpiarFormulario = () => {
    setNombre('');
    setEmail('');
    setTelefono('');
    setMembresiaId('');
  };

  const manejarEnvio = (evento) => {
    evento.preventDefault();

    const mensajeError = validarCampos(nombre, email, telefono, membresiaId);
    if (mensajeError) {
      setError(mensajeError);
      return;
    }

    const nuevoRegistro = {
      id: `soc-${Date.now()}`,
      nombre,
      email,
      telefono,
      membresiaId,
    };

    onAgregar(nuevoRegistro);
    setError('');
    limpiarFormulario();
  };

  // opciones del select, una por cada membresia
  const opciones = [];
  membresias.forEach((membresia) => {
    opciones.push(
      <MenuItem key={membresia.id} value={membresia.id}>
        {membresia.nombre}
      </MenuItem>
    );
  });

  return (
    <Paper sx={{ p: 3, mb: 3 }} elevation={2}>
      <Typography variant="h6" sx={{ mb: 2 }}>
        Nuevo Socio
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
          label="Email"
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          size="small"
        />
        <TextField
          label="Telefono"
          value={telefono}
          onChange={(e) => setTelefono(e.target.value)}
          size="small"
        />
        <TextField
          select
          label="Membresia"
          value={membresiaId}
          onChange={(e) => setMembresiaId(e.target.value)}
          size="small"
          sx={{ minWidth: 160 }}
        >
          {opciones}
        </TextField>
        <Button type="submit" variant="contained">
          Agregar
        </Button>
      </Box>
    </Paper>
  );
}

export default FormularioRegistro;