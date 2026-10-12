import Container from '@mui/material/Container'
import TextField from '@mui/material/TextField'
import Alert from '@mui/material/Alert'
import Header from '../../../shared/layouts/Header'
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
      <Header titulo="Modulo de socios" totalRegistros={registros.length} />
      <Container maxWidth="md">
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
        <TablaRegistros
          registros={registros}
          cargando={cargando}
          onEliminar={eliminarRegistro}
          onEditar={setEditandoId}
          onVerDetalle={setDetalleId}
        />

        <DetalleUsuario
          registro={registroDetalle}
          abierto={Boolean(registroDetalle)}
          onCerrar={() => setDetalleId(null)}
        />
      </Container>
      <Footer />
    </>
  )
}

export default ModuloSocios
