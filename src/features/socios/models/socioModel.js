// validacion de campos del formulario
// recibe los valores y regresa el mensaje de error o texto vacio si todo esta bien
export const validarCampos = (nombre, email, telefono, membresiaId) => {

  const campos = [
    { valor: nombre, etiqueta: 'Nombre' },
    { valor: email, etiqueta: 'Email' },
    { valor: telefono, etiqueta: 'Telefono' },
    { valor: membresiaId, etiqueta: 'Membresia' },
  ];

  let mensaje = '';
  campos.forEach((campo) => {
    if (!campo.valor.trim()) {
      mensaje = `El campo "${campo.etiqueta}" es obligatorio`;
    }
  });

  return mensaje;
};