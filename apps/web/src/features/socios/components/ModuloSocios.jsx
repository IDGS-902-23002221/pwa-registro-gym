import Container from '@mui/material/Container'
import Box from '@mui/material/Box'
import TextField from '@mui/material/TextField'
import Alert from '@mui/material/Alert'
import Typography from '@mui/material/Typography'
import Footer from '../../../shared/layouts/Footer'
import FormularioRegistro from './FormularioRegistro'
import TablaRegistros from './TablaRegistros'
import FormularioEdicion from './FormularioEdicion'
import DetalleUsuario from './DetalleUsuario'

// socios llega por props desde app (hook con Supabase).
function ModuloSocios({ socios }) {
  const {
    registros,
    cargando,
    error,
    busqueda,
    buscar,
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
          <Box component="span" sx={{ color: 'text.secondary', fontSize: '1rem' }}>
            ({registros.length})
          </Box>
        </Typography>
        {error && (
          <Alert severity="error" sx={{ mb: 2 }}>
            {error}
          </Alert>
        )}
        <TextField
          label="Buscar por nombre"
          value={busqueda}
          onChange={(e) => buscar(e.target.value)}
          size="small"
          fullWidth
          sx={{ mb: 2 }}
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
        <TablaRegistros registros={registros} cargando={cargando} onVerDetalle={setDetalleId} />

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
