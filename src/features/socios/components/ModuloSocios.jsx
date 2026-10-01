import Container from '@mui/material/Container';
import Header from '../../../shared/layouts/Header';
import Footer from '../../../shared/layouts/Footer';
import FormularioRegistro from './FormularioRegistro';
import TablaRegistros from './TablaRegistros';
import FormularioEdicion from './FormularioEdicion';
import DetalleUsuario from './DetalleUsuario';

// socios y membresias llegan por props desde app
// el hook ya no se llama aqui para que el estado no se pierda al cambiar de pantalla
function ModuloSocios({ socios, membresias }) {

  const {
    registros,
    setEditandoId,
    setDetalleId,
    agregarRegistro,
    eliminarRegistro,
    actualizarRegistro,
    registroEnEdicion,
    registroDetalle,
  } = socios;

  return (
    <>
      <Header titulo="Modulo de socios" totalRegistros={registros.length} />
      <Container maxWidth="md">
        { registroEnEdicion ? (
          <FormularioEdicion
            registro={registroEnEdicion}
            onActualizar={actualizarRegistro}
            onCancelar={() => setEditandoId(null)}
            membresias={membresias}
          />
        ) : (
          <FormularioRegistro onAgregar={agregarRegistro} membresias={membresias}/>
        )}
        <TablaRegistros
          registros={registros}
          onEliminar={eliminarRegistro}
          onEditar={setEditandoId}
          onVerDetalle={setDetalleId}
          membresias={membresias}
        />

        <DetalleUsuario
          registro={registroDetalle}
          abierto={Boolean(registroDetalle)}
          onCerrar={() => setDetalleId(null)}
          membresias={membresias}
        />
      </Container>
      <Footer />
    </>
  );
}

export default ModuloSocios;