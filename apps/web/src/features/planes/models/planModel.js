// Validación del formulario de plan (patrón de membresiaModel).
// Recibe los valores del formulario y regresa el mensaje de error, o '' si todo
// está bien. La base valida otra vez (0016): esto solo mejora el mensaje.

export const validarCampos = (nombre, precio, dias) => {
  if (!String(nombre ?? '').trim()) {
    return 'El nombre es obligatorio'
  }

  const p = Number(precio)
  if (String(precio ?? '').trim() === '' || Number.isNaN(p) || p <= 0) {
    return 'El precio debe ser mayor a cero'
  }

  const d = Number(dias)
  if (String(dias ?? '').trim() === '' || !Number.isInteger(d) || d < 1 || d > 366) {
    return 'Los días deben ser un número entero entre 1 y 366'
  }

  return ''
}
