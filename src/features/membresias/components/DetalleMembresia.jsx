import Dialog from '@mui/material/Dialog';
import DialogTitle from '@mui/material/DialogTitle';
import DialogContent from '@mui/material/DialogContent';
import DialogActions from '@mui/material/DialogActions';
import Button from '@mui/material/Button';
import Box from '@mui/material/Box';
import Typography from '@mui/material/Typography';


function DetalleMembresia({ registro, abierto, onCerrar }){
    if(!registro){
        return null;
    }

    const datos = [
        {etiqueta:'Nombre', valor: registro.nombre},
        {etiqueta:'Precio', valor: `$${registro.precio}`},
        {etiqueta:'Duracion (meses)', valor: registro.duracion},
        {etiqueta:'ID', valor: registro.id},
    ];

    const info = [];

    datos.forEach((dato) => {
        info.push(
            <Box key={dato.etiqueta} sx={{mb: 2}}>
                <Typography variant='caption' color='text.secondary'>
                    {dato.etiqueta}
                </Typography>
                <Typography variant='body1'>{dato.valor}</Typography>
            </Box>
        );
    });

    return (
        <Dialog open={abierto} onClose={onCerrar} fullWidth maxWidth="xs">
            <DialogTitle> Detalle de la membresia</DialogTitle>
            <DialogContent>{info}</DialogContent>
            <DialogActions >
            <Button variant="outlined" onClick={onCerrar}>
                  Cerrar
            </Button>
            </DialogActions>
        </Dialog>
    );
}
export default DetalleMembresia;