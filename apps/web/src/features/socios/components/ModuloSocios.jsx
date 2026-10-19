import { useState } from 'react'
import Container from '@mui/material/Container'
import Box from '@mui/material/Box'
import Paper from '@mui/material/Paper'
import TextField from '@mui/material/TextField'
import Button from '@mui/material/Button'
import Alert from '@mui/material/Alert'
import Snackbar from '@mui/material/Snackbar'
import Typography from '@mui/material/Typography'
import AddIcon from '@mui/icons-material/Add'
import Footer from '../../../shared/layouts/Footer'
import FormularioRegistro from './FormularioRegistro'
import TablaRegistros from './TablaRegistros'
import FormularioEdicion from './FormularioEdicion'
import DetalleUsuario from './DetalleUsuario'

// Socios en modo "buscar primero": al abrir no se lista a nadie. Los resultados
// aparecen justo debajo del buscador (lo primero bajo el dedo, arriba del teclado);
// el alta está plegada para no empujarlos. socios es el hook con Supabase.
function ModuloSocios({ socios }) {
  const {
    registros,
    cargando,
    error,
    busqueda,
    modo,
    buscar,
    verTodos,
    limpiar,
    setEditandoId,
    setDetalleId,
    agregarRegistro,
    eliminarRegistro,
    actualizarRegistro,
    registroEnEdicion,
    registroDetalle,
  } = socios

  const [mostrarAlta, setMostrarAlta] = useState(false)
  const [aviso, setAviso] = useState(null)

  const agregar = async (datos) => {
    const resultado = await agregarRegistro(datos)
    if (resultado.ok) {
      setMostrarAlta(false)
      setAviso(
        datos.homonimos > 0
          ? { tipo: 'warning', texto: 'Socio agregado. Ojo: ya existía otro con el mismo nombre.' }
          : { tipo: 'success', texto: 'Socio agregado correctamente.' }
      )
    }
    return resultado
  }

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
          <>
            {/* Resultados: lo primero debajo del buscador para verlos al escribir. */}
            {modo === 'inicial' ? (
              <Paper
                elevation={0}
                sx={{ p: 4, textAlign: 'center', display: 'flex', flexDirection: 'column', gap: 1.5, alignItems: 'center' }}
              >
                <Typography variant="subtitle1" sx={{ fontWeight: 700 }}>
                  Busca un socio
                </Typography>
                <Typography variant="body2" color="text.secondary" sx={{ maxWidth: 440 }}>
                  Escribe el nombre o el teléfono del socio para encontrarlo. Para registrar un
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
              <>
                {modo === 'todos' && (
                  <Box sx={{ display: 'flex', justifyContent: 'flex-end', mb: 1 }}>
                    <Button size="small" onClick={limpiar}>
                      Ocultar
                    </Button>
                  </Box>
                )}
                <TablaRegistros registros={registros} cargando={cargando} onVerDetalle={setDetalleId} />
              </>
            )}

            {/* Alta de socio, plegada para no empujar los resultados. */}
            <Box sx={{ mt: 3 }}>
              {mostrarAlta ? (
                <FormularioRegistro onAgregar={agregar} />
              ) : (
                <Button
                  variant="outlined"
                  startIcon={<AddIcon />}
                  onClick={() => setMostrarAlta(true)}
                  fullWidth
                >
                  Nuevo socio
                </Button>
              )}
            </Box>
          </>
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
      <Snackbar
        open={Boolean(aviso)}
        autoHideDuration={4000}
        onClose={() => setAviso(null)}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'center' }}
      >
        <Alert
          severity={aviso?.tipo ?? 'success'}
          variant="filled"
          onClose={() => setAviso(null)}
          sx={{ width: '100%' }}
        >
          {aviso?.texto}
        </Alert>
      </Snackbar>
      <Footer />
    </>
  )
}

export default ModuloSocios
