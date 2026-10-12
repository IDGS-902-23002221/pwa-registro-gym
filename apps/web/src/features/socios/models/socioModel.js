// Validación del formulario de socios. Nombre y apellidos obligatorios
// (el índice único es nombre + apellidos + teléfono, 02 §4).
// Teléfono y correo opcionales: sin teléfono el duplicado no se bloquea.
export const validarContacto = (nombre, apellidos, telefono) => {
  if (!nombre.trim() || !apellidos.trim()) {
    return 'Nombre y apellidos son obligatorios'
  }
  if (telefono.trim() && telefono.replace(/\D/g, '').length < 7) {
    return 'El teléfono debe tener al menos 7 dígitos'
  }
  return ''
}
