import Container from '@mui/material/Container'
import Alert from '@mui/material/Alert'
import Header from '../../../shared/layouts/Header'
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
    cambiarEstadoRegistro,
    registroDetalle,
  } = planes

  // El detalle edita solo el precio (0016); se reusa el actualizarRegistro del hook.
  const guardarPrecio = (id, precio) => actualizarRegistro({ id, precio_mxn: precio })

  return (
    <>
      <Header titulo="Catálogo de planes" totalRegistros={registros.length} unidad="plan(es)" />
      <Container maxWidth="md">
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
          onGuardarPrecio={guardarPrecio}
        />
      </Container>
      <Footer />
    </>
  )
}

export default ModuloPlanes
