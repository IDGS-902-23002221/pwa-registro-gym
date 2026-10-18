import Container from '@mui/material/Container'
import Box from '@mui/material/Box'
import Alert from '@mui/material/Alert'
import Typography from '@mui/material/Typography'
import Footer from '../../../shared/layouts/Footer'
import FormularioPlan from './FormularioPlan'
import TablaPlanes from './TablaPlanes'
import DetallePlan from './DetallePlan'

// Catálogo de planes. Recibe el hook ya creado (planes) desde app, para que el
// estado no se pierda al cambiar de pestaña.
function ModuloPlanes({ planes }) {
  const {
    registros,
    cargando,
    error,
    setDetalleId,
    agregarRegistro,
    actualizarRegistro,
    actualizarDatos,
    cambiarEstadoRegistro,
    registroDetalle,
  } = planes

  // El detalle edita todo: nombre/días (actualizarDatos), precio (actualizarRegistro) y estado.
  const guardarPrecio = (id, precio) => actualizarRegistro({ id, precio_mxn: precio })

  return (
    <>
      <Container maxWidth="md" sx={{ mt: 2 }}>
        <Typography variant="h5" component="h1" sx={{ mb: 2 }}>
          Catálogo de planes{' '}
          <Box component="span" sx={{ color: 'text.secondary', fontSize: '1rem' }}>
            ({registros.length})
          </Box>
        </Typography>
        {error && (
          <Alert severity="error" sx={{ mb: 2 }}>
            {error}
          </Alert>
        )}
        <FormularioPlan onAgregar={agregarRegistro} />
        <TablaPlanes
          registros={registros}
          cargando={cargando}
          onVerDetalle={setDetalleId}
          onCambiarEstado={cambiarEstadoRegistro}
        />
        <DetallePlan
          registro={registroDetalle}
          abierto={Boolean(registroDetalle)}
          onCerrar={() => setDetalleId(null)}
          onGuardarDatos={actualizarDatos}
          onGuardarPrecio={guardarPrecio}
          onCambiarEstado={cambiarEstadoRegistro}
        />
      </Container>
      <Footer />
    </>
  )
}

export default ModuloPlanes
