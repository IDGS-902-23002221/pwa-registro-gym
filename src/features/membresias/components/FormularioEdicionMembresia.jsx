import { useState } from 'react';
import Paper from '@mui/material/Paper';
import Box from '@mui/material/Box';
import TextField from '@mui/material/TextField';
import Button from '@mui/material/Button';
import Typography from '@mui/material/Typography';
import Alert from '@mui/material/Alert';
import { validarCampos } from '../models/membresiaModel';

function FormularioEdicionMembresia({ registro, onActualizar, onCancelar }) {
    const [nombre, setNombre] = useState(registro.nombre);
    const [precio, setPrecio] = useState(registro.precio);
    const [duracion, setDuracion] = useState(registro.duracion);
    const [error, setError] = useState('');
    const [idEditado, setIdEditado] = useState(registro.id);

    if (registro.id !== idEditado){
        setIdEditado(registro.id);
        setNombre(registro.nombre);
        setPrecio(registro.precio);
        setDuracion(registro.duracion);
    }

    const manejarEnvio = (evento) => {
        evento.preventDefault();

        const mensajeError = validarCampos(nombre, precio, duracion);
        if (mensajeError) {
            setError(mensajeError);
            return;
        }

        const registroActualizado = {
            ...registro,
            nombre,
            precio,
            duracion,
        };

        onActualizar(registroActualizado);
        setError('');
    };

    return (
        <Paper sx={{ p: 3, mb: 3 }} elevation={2}>
            <Typography variant="h6" sx={{ mb: 2 }}>
                Editar Membresia
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
                    Guardar
                </Button>
                <Button variant="outlined" onClick={onCancelar}>
                    Cancelar
                </Button>
            </Box>
        </Paper>
    );
}

export default FormularioEdicionMembresia;