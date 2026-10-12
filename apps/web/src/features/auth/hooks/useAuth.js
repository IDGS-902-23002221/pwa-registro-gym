import { useCallback, useEffect, useState } from 'react'
import { supabase } from '../../../shared/supabaseClient'

// Sesión de Supabase Auth: el único lugar que lee/escribe la sesión.
// Devuelve { sesion, cargando, error, entrar, salir }.
export default function useAuth() {
  const [sesion, setSesion] = useState(null)
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState(null)

  useEffect(() => {
    let viva = true
    supabase.auth.getSession().then(({ data, error: e }) => {
      if (!viva) return
      if (e) setError(e.message)
      setSesion(data.session ?? null)
      setCargando(false)
    })
    const { data: sub } = supabase.auth.onAuthStateChange((_evento, nueva) => {
      setSesion(nueva)
    })
    return () => {
      viva = false
      sub.subscription.unsubscribe()
    }
  }, [])

  const entrar = useCallback(async (correo, contrasena) => {
    setError(null)
    const { error: e } = await supabase.auth.signInWithPassword({
      email: correo,
      password: contrasena,
    })
    if (e) {
      setError('Correo o contraseña incorrectos')
      return false
    }
    return true
  }, [])

  const salir = useCallback(async () => {
    await supabase.auth.signOut()
  }, [])

  return { sesion, cargando, error, entrar, salir }
}
