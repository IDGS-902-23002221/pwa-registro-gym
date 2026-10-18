import { useCallback, useEffect, useState } from 'react'
import * as servicio from '../services/planesService'

// Estado del catálogo de planes contra Supabase (patrón de useSocios). Mantiene
// la frontera que espera la pestaña (agregarRegistro, actualizarRegistro,
// cambiarEstadoRegistro) con carga y error; ante un fallo recarga del servidor.
function usePlanes() {
  const [registros, setRegistros] = useState([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState(null)

  const [editandoId, setEditandoId] = useState(null)
  const [detalleId, setDetalleId] = useState(null)

  const cargar = useCallback(async () => {
    setCargando(true)
    setError(null)
    try {
      setRegistros(await servicio.listar())
    } catch (e) {
      setError(e.message ?? 'No se pudo cargar el catálogo de planes')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    cargar()
  }, [cargar])

  const agregarRegistro = async (datos) => {
    setError(null)
    try {
      await servicio.crearPlan(datos)
      await cargar()
      return { ok: true }
    } catch (e) {
      return { ok: false, mensaje: servicio.mensajeDeError(e) }
    }
  }

  // En este catálogo editar es cambiar el precio (0016); nombre y días no se tocan.
  const actualizarRegistro = async (registroActualizado) => {
    setError(null)
    try {
      await servicio.actualizarPrecioPlan(registroActualizado.id, registroActualizado.precio_mxn)
      setEditandoId(null)
      await cargar()
      return { ok: true }
    } catch (e) {
      return { ok: false, mensaje: servicio.mensajeDeError(e) }
    }
  }

  const cambiarEstadoRegistro = async (id, activo) => {
    setError(null)
    try {
      await servicio.cambiarActivoPlan(id, activo)
      await cargar()
    } catch (e) {
      setError(servicio.mensajeDeError(e))
    }
  }

  const registroEnEdicion = registros.find((registro) => registro.id === editandoId)
  const registroDetalle = registros.find((registro) => registro.id === detalleId)

  return {
    registros,
    cargando,
    error,
    recargar: cargar,
    setEditandoId,
    setDetalleId,
    agregarRegistro,
    actualizarRegistro,
    cambiarEstadoRegistro,
    registroEnEdicion,
    registroDetalle,
  }
}

export default usePlanes
