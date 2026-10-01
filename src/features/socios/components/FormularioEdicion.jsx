import { useState } from 'react';
import Paper from '@mui/material/Paper';
import Box from '@mui/material/Box';
import TextField from '@mui/material/TextField';
import MenuItem from '@mui/material/MenuItem';
import Button from '@mui/material/Button';
import Typography from '@mui/material/Typography';
import Alert from '@mui/material/Alert';
import { validarCampos } from '../models/socioModel';

function FormularioEdicion({ registro, onActualizar, onCancelar, membresias }) {
    const [nombre, setNombre] = useState(registro.nombre);
    const [email, setEmail] = useState(registro.email);
    const [telefono, setTelefono] = useState(registro.telefono);
    const [membresiaId, setMembresiaId] = useState(registro.membresiaId);
    const [error, setError] = useState('');
    const [idEditado, setIdEditado] = useState(registro.id);

    if (registro.id !== idEditado){
        setIdEditado(registro.id);
        setNombre(registro.nombre);
        setEmail(registro.email);
        setTelefono(registro.telefono);
        setMembresiaId(registro.membresiaId);
    }

    const manejarEnvio = (evento) => {
        evento.preventDefault();

        const mensajeError = validarCampos(nombre, email, telefono, membresiaId);
        if (mensajeError) {
            setError(mensajeError);
            return;
        }

        const registroActualizado = {
            ...registro,
            nombre,
            email,
            telefono,
            membresiaId,
        };

        onActualizar(registroActualizado);
        setError('');
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
                Editar Socio
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
                    Guardar
                </Button>
                <Button variant="outlined" onClick={onCancelar}>
                    Cancelar
                </Button>
            </Box>
        </Paper>
    );
}

export default FormularioEdicion;