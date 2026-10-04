import AppBar from '@mui/material/AppBar';
import Toolbar from '@mui/material/Toolbar';
import Typography from '@mui/material/Typography';
import FitnessCenterIcon from '@mui/icons-material/FitnessCenter';

function Header({ titulo, totalRegistros }) {
  return (
    <AppBar position="static" sx={{ mb: 3 }}>
      <Toolbar>
        <FitnessCenterIcon sx={{ mr: 1, color: 'secondary.main' }} />
        <Typography variant="h6" component="h1" sx={{ flexGrow: 1, fontWeight: 700 }}>
          {`${titulo} — ${totalRegistros} socio(s)`}
        </Typography>
      </Toolbar>
    </AppBar>
  );
}

export default Header;
