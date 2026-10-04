import Container from '@mui/material/Container';
import Header from '../../../shared/layouts/Header';
import Footer from '../../../shared/layouts/Footer';
import FormularioMembresia from './FormularioMembresia';
import TablaMembresias from './TablaMembresias';
import FormularioEdicionMembresia from './FormularioEdicionMembresia';
import DetalleMembresia from './DetalleMembresia';

// membresias llega por props desde app
// el hook ya no se llama aqui para que el estado no se pierda al cambiar de pantalla
function ModuloMembresias({ membresias }) {

  const {
    registros,
    setEditandoId,
    setDetalleId,
    agregarRegistro,
    eliminarRegistro,
    actualizarRegistro,
    registroEnEdicion,
    registroDetalle,
  } = membresias;

  return (
    <>
      <Header titulo="Modulo de membresias" totalRegistros={registros.length} />
      <Container maxWidth="md">
        { registroEnEdicion ? (
          <FormularioEdicionMembresia
            registro={registroEnEdicion}
            onActualizar={actualizarRegistro}
            onCancelar={() => setEditandoId(null)}
          />
        ) : (
          <FormularioMembresia onAgregar={agregarRegistro}/>
        )}
        <TablaMembresias
          registros={registros}
          onEliminar={eliminarRegistro}
          onEditar={setEditandoId}
          onVerDetalle={setDetalleId}
        />

        <DetalleMembresia
          registro={registroDetalle}
          abierto={Boolean(registroDetalle)}
          onCerrar={() => setDetalleId(null)}
        />
      </Container>
      <Footer />
    </>
  );
}

export default ModuloMembresias;