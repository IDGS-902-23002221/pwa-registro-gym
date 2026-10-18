import { useEffect, useState } from 'react'
import Container from '@mui/material/Container'
import Box from '@mui/material/Box'
import Paper from '@mui/material/Paper'
import Typography from '@mui/material/Typography'
import Alert from '@mui/material/Alert'
import Chip from '@mui/material/Chip'
import Footer from '../../../shared/layouts/Footer'
import CardWell from '../../../shared/CardWell'
import { vencimientos } from '../services/inicioService'
import { fechaLarga, fechaLargaDia } from '../../../shared/formatFecha'

const aISO = (f) =>
  `${f.getFullYear()}-${String(f.getMonth() + 1).padStart(2, '0')}-${String(f.getDate()).padStart(2, '0')}`

// Semana del gimnasio: lunes a sábado (domingo cerrado). Se calcula en local.
const rangoSemana = () => {
  const hoy = new Date()
  const lunes = new Date(hoy)
  lunes.setDate(hoy.getDate() - ((hoy.getDay() + 6) % 7))
  const sabado = new Date(lunes)
  sabado.setDate(lunes.getDate() + 5)
  return [aISO(lunes), aISO(sabado)]
}

// Inicio: lo primero que ve el personal al entrar. Muestra a quién le toca
// renovar esta semana (lunes a sábado), para actuar a tiempo.
function ModuloInicio() {
  const [filas, setFilas] = useState([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')
  const [rango] = useState(rangoSemana)

  useEffect(() => {
    vencimientos(rango[0], rango[1])
      .then(setFilas)
      .catch((e) => setError(e.message ?? 'No se pudieron cargar los vencimientos'))
      .finally(() => setCargando(false))
  }, [rango])

  return (
    <>
      <Container maxWidth="md" sx={{ mt: 2 }}>
        <Typography variant="h5" component="h1" sx={{ mb: 0.5 }}>
          Inicio
        </Typography>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
          Semana del {fechaLargaDia(rango[0])} al {fechaLargaDia(rango[1])}
        </Typography>

        {error && (
          <Alert severity="error" sx={{ mb: 2 }}>
            {error}
          </Alert>
        )}

        <Typography variant="subtitle1" sx={{ fontWeight: 700, mb: 1 }}>
          Socios con plan por vencer esta semana
        </Typography>

        {cargando ? (
          <Paper elevation={0} sx={{ p: 3 }}>
            <Typography variant="body2" color="text.secondary" align="center">
              Cargando…
            </Typography>
          </Paper>
        ) : filas.length === 0 ? (
          <Paper elevation={0} sx={{ p: 4, textAlign: 'center' }}>
            <Typography variant="subtitle1" sx={{ fontWeight: 700, mb: 0.5 }}>
              Nadie vence esta semana
            </Typography>
            <Typography variant="body2" color="text.secondary">
              Todos los socios tienen su plan vigente. Buen trabajo.
            </Typography>
          </Paper>
        ) : (
          <CardWell>
            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1.5 }}>
              {filas.map((f) => (
                <Paper
                  key={f.socio_id}
                  elevation={0}
                  sx={{ p: 2, display: 'flex', flexDirection: 'column', gap: 0.75 }}
                >
                  <Box sx={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', gap: 1 }}>
                    <Typography variant="subtitle1" sx={{ fontWeight: 700 }} noWrap>
                      {f.nombre} {f.apellidos ?? ''}
                    </Typography>
                    {f.plan && <Chip size="small" label={f.plan} color="primary" variant="outlined" />}
                  </Box>
                  <Typography variant="body2" color="text.secondary">
                    Vence el {fechaLarga(f.vence_en)}
                  </Typography>
                  {f.telefono && (
                    <Typography variant="caption" color="text.secondary">
                      {f.telefono}
                    </Typography>
                  )}
                </Paper>
              ))}
            </Box>
          </CardWell>
        )}
      </Container>
      <Footer />
    </>
  )
}

export default ModuloInicio
