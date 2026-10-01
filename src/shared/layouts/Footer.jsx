import Box from '@mui/material/Box';
import Typography from '@mui/material/Typography';

function Footer() {
  const anioActual = new Date().getFullYear();

  return (
    <Box
      component="footer"
      sx={{ mt: 4, py: 2, textAlign: 'center', borderTop: '1px solid #9c27b0' }}
    >
      <Typography variant="body2" color="text.secondary">
        {`Modulo de registros — © ${anioActual} — gym`}
      </Typography>
    </Box>
  );
}

export default Footer;
