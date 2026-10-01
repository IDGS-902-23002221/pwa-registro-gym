// validacion de campos del formulario
// recibe los valores y regresa el mensaje de error o texto vacio si todo esta bien
export const validarCampos = (nombre, precio, duracion) => {

  const campos = [
    { valor: nombre, etiqueta: 'Nombre' },
    { valor: precio, etiqueta: 'Precio' },
    { valor: duracion, etiqueta: 'Duracion' },
  ];

  let mensaje = '';
  campos.forEach((campo) => {
    if (!campo.valor.trim()) {
      mensaje = `El campo "${campo.etiqueta}" es obligatorio`;
    }
  });

  return mensaje;
};