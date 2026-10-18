import { useCallback, useState } from 'react'
import * as servicio from '../services/sociosService'

// Estado de socios contra Supabase, en modo "buscar primero": no carga la lista
// al abrir. Se consulta al escribir (>= 2 caracteres) o al pedir "Ver todos".
// Mantiene la frontera (agregarRegistro, actualizarRegistro, eliminarRegistro)
// con carga y error; ante un fallo recarga del servidor.
function useSocios() {
  const [registros, setRegistros] = useState([])
  const [cargando, setCargando] = useState(false)
  const [error, setError] = useState(null)
  const [busqueda, setBusqueda] = useState('')
  // 'inicial' (nada), 'busqueda' (resultados de un término) o 'todos' (todos).
  const [modo, setModo] = useState('inicial')

  const [editandoId, setEditandoId] = useState(null)
  const [detalleId, setDetalleId] = useState(null)

  const cargar = useCallback(async (termino, m) => {
    setCargando(true)
    setError(null)
    try {
      setRegistros(await servicio.listar({ busqueda: m === 'todos' ? '' : termino }))
    } catch (e) {
      setError(e.message ?? 'No se pudo cargar la lista de socios')
    } finally {
      setCargando(false)
    }
  }, [])

  const buscar = useCallback(
    (termino) => {
      setBusqueda(termino)
      if (termino.trim().length >= 2) {
        setModo('busqueda')
        cargar(termino, 'busqueda')
      } else {
        setModo('inicial')
        setRegistros([])
      }
    },
    [cargar]
  )

  const verTodos = useCallback(() => {
    setBusqueda('')
    setModo('todos')
    cargar('', 'todos')
  }, [cargar])

  // Vuelve al estado inicial (nada listado), como recién abierta la pestaña.
  const limpiar = useCallback(() => {
    setBusqueda('')
    setModo('inicial')
    setRegistros([])
  }, [])

  // Refresca según el modo actual (no hace nada en 'inicial').
  const recargar = useCallback(() => {
    if (modo === 'busqueda') cargar(busqueda, 'busqueda')
    else if (modo === 'todos') cargar('', 'todos')
  }, [modo, busqueda, cargar])

  const agregarRegistro = async (datos) => {
    setError(null)
    try {
      await servicio.crear(datos)
      recargar()
      return { ok: true }
    } catch (e) {
      if (servicio.esDuplicado(e)) {
        return {
          ok: false,
          mensaje:
            'Ese socio ya existe (mismo nombre y teléfono). Búscalo para registrar su pago o renovar.',
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
      recargar()
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
      recargar()
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
    modo,
    buscar,
    verTodos,
    limpiar,
    recargar,
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
