import { useState } from 'react';
import Box from '@mui/material/Box';
import Button from '@mui/material/Button';
import ModuloSocios from '../features/socios/components/ModuloSocios';
import ModuloMembresias from '../features/membresias/components/ModuloMembresias';
import useSocios from '../features/socios/hooks/useSocios';
import useMembresias from '../features/membresias/hooks/useMembresias';

// app es el unico que conoce los dos features
// aqui viven los dos hooks para que el estado no se pierda al cambiar de pantalla
function App() {

  const [vista, setVista] = useState('socios');

  const socios = useSocios();
  const membresias = useMembresias();

  return (
    <>
      <Box sx={{ display: 'flex', justifyContent: 'center', gap: 2, p: 1 }}>
        <Button
          variant={vista === 'socios' ? 'contained' : 'outlined'}
          onClick={() => setVista('socios')}
        >
          Socios
        </Button>
        <Button
          variant={vista === 'membresias' ? 'contained' : 'outlined'}
          onClick={() => setVista('membresias')}
        >
          Membresias
        </Button>
      </Box>

      {vista === 'socios' ? (
        <ModuloSocios socios={socios} membresias={membresias.registros} />
      ) : (
        <ModuloMembresias membresias={membresias} />
      )}
    </>
  );
}

export default App;