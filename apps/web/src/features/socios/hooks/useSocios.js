import { useCallback, useEffect, useState } from 'react'
import * as servicio from '../services/sociosService'

// Estado de socios contra Supabase. Mantiene la frontera anterior
// (agregarRegistro, actualizarRegistro, eliminarRegistro) para no tocar componentes,
// pero todo es async con loading y error. Ante un fallo se recarga del servidor.
function useSocios() {
  const [registros, setRegistros] = useState([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState(null)
  const [busqueda, setBusqueda] = useState('')

  const [editandoId, setEditandoId] = useState(null)
  const [detalleId, setDetalleId] = useState(null)

  const cargar = useCallback(async (termino = '') => {
    setCargando(true)
    setError(null)
    try {
      setRegistros(await servicio.listar({ busqueda: termino }))
    } catch (e) {
      setError(e.message ?? 'No se pudo cargar la lista de socios')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    cargar()
  }, [cargar])

  const buscar = useCallback(
    (termino) => {
      setBusqueda(termino)
      cargar(termino)
    },
    [cargar]
  )

  const agregarRegistro = async (datos) => {
    setError(null)
    try {
      await servicio.crear(datos)
      await cargar(busqueda)
      return { ok: true }
    } catch (e) {
      if (servicio.esDuplicado(e)) {
        return {
          ok: false,
          mensaje:
            'Ese socio ya existe (mismo nombre y teléfono). Búscalo en la lista para registrar su pago o renovar.',
        }
      }
      setError(e.message ?? 'No se pudo agregar el socio')
      return { ok: false, mensaje: 'No se pudo agregar el socio' }
    }
  }

  const actualizarRegistro = async (registroActualizado) => {
    setError(null)
    try {
      await servicio.actualizarContacto(registroActualizado.id, registroActualizado)
      setEditandoId(null)
      await cargar(busqueda)
    } catch (e) {
      if (servicio.esDuplicado(e)) {
        setError(
          'Ya existe otro socio con ese nombre y teléfono. Revisa los datos: no se guardó ningún cambio.'
        )
      } else {
        setError(e.message ?? 'No se pudo guardar los cambios')
      }
    }
  }

  const eliminarRegistro = async (idAEliminar) => {
    setError(null)
    try {
      await servicio.eliminar(idAEliminar)
      await cargar(busqueda)
    } catch (e) {
      setError(e.message ?? 'No se pudo eliminar el socio')
    }
  }

  const registroEnEdicion = registros.find((registro) => registro.id === editandoId)
  const registroDetalle = registros.find((registro) => registro.id === detalleId)

  return {
    registros,
    cargando,
    error,
    busqueda,
    buscar,
    recargar: () => cargar(busqueda),
    setEditandoId,
    setDetalleId,
    agregarRegistro,
    eliminarRegistro,
    actualizarRegistro,
    registroEnEdicion,
    registroDetalle,
  }
}

export default useSocios
