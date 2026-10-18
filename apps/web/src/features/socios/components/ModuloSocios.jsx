import Container from '@mui/material/Container'
import Box from '@mui/material/Box'
import Paper from '@mui/material/Paper'
import TextField from '@mui/material/TextField'
import Button from '@mui/material/Button'
import Alert from '@mui/material/Alert'
import Typography from '@mui/material/Typography'
import Footer from '../../../shared/layouts/Footer'
import FormularioRegistro from './FormularioRegistro'
import TablaRegistros from './TablaRegistros'
import FormularioEdicion from './FormularioEdicion'
import DetalleUsuario from './DetalleUsuario'

// Socios en modo "buscar primero": al abrir no se lista a nadie, solo se pide
// buscar por nombre o teléfono (o "Ver todos"). Así la pantalla abre al instante
// y se enfoca en la tarea. socios es el hook con Supabase, creado en la página.
function ModuloSocios({ socios }) {
  const {
    registros,
    cargando,
    error,
    busqueda,
    modo,
    buscar,
    verTodos,
    setEditandoId,
    setDetalleId,
    agregarRegistro,
    eliminarRegistro,
    actualizarRegistro,
    registroEnEdicion,
    registroDetalle,
  } = socios

  return (
    <>
      <Container maxWidth="md" sx={{ mt: 2 }}>
        <Typography variant="h5" component="h1" sx={{ mb: 2 }}>
          Socios{' '}
          {modo !== 'inicial' && (
            <Box component="span" sx={{ color: 'text.secondary', fontSize: '1rem' }}>
              ({registros.length})
            </Box>
          )}
        </Typography>

        {error && (
          <Alert severity="error" sx={{ mb: 2 }}>
            {error}
          </Alert>
        )}

        <TextField
          label="Buscar por nombre o teléfono"
          value={busqueda}
          onChange={(e) => buscar(e.target.value)}
          size="small"
          fullWidth
          sx={{ mb: 2 }}
          helperText={modo === 'inicial' ? 'Escribe al menos 2 letras' : ''}
        />

        {registroEnEdicion ? (
          <FormularioEdicion
            registro={registroEnEdicion}
            onActualizar={actualizarRegistro}
            onCancelar={() => setEditandoId(null)}
          />
        ) : (
          <FormularioRegistro onAgregar={agregarRegistro} registros={registros} />
        )}

        {modo === 'inicial' ? (
          <Paper
            elevation={0}
            sx={{ p: 4, textAlign: 'center', display: 'flex', flexDirection: 'column', gap: 1.5, alignItems: 'center' }}
          >
            <Typography variant="subtitle1" sx={{ fontWeight: 700 }}>
              Busca un socio
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ maxWidth: 440 }}>
              Escribe el nombre o el teléfono del socio arriba para encontrarlo. Para registrar un
              pago, usa la pestaña Cobrar.
            </Typography>
            <Button variant="outlined" onClick={verTodos}>
              Ver todos
            </Button>
          </Paper>
        ) : modo === 'busqueda' && !cargando && registros.length === 0 ? (
          <Paper elevation={0} sx={{ p: 3 }}>
            <Typography variant="body2" color="text.secondary" align="center">
              Sin resultados para «{busqueda}». Revisa la escritura o prueba por teléfono.
            </Typography>
          </Paper>
        ) : (
          <TablaRegistros registros={registros} cargando={cargando} onVerDetalle={setDetalleId} />
        )}

        <DetalleUsuario
          registro={registroDetalle}
          abierto={Boolean(registroDetalle)}
          onCerrar={() => setDetalleId(null)}
          onEditar={(id) => {
            setDetalleId(null)
            setEditandoId(id)
          }}
          onEliminar={(id) => {
            eliminarRegistro(id)
            setDetalleId(null)
          }}
        />
      </Container>
      <Footer />
    </>
  )
}

export default ModuloSocios
