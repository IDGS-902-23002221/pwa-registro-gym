// funciones puras del crud
// reciben el arreglo actual y regresan un arreglo nuevo
// no usan useState, eso lo hace el hook

// agregar un registro al final
export const crear = (registrosPrevios, nuevoRegistro) => {
  return [...registrosPrevios, nuevoRegistro];
};

// quitar el registro que coincida con el id
export const eliminar = (registrosPrevios, idAEliminar) => {
  return registrosPrevios.filter((registro) => registro.id !== idAEliminar);
};

// reemplazar el registro que coincida con el id por el actualizado
export const actualizar = (registrosPrevios, registroActualizado) => {
  return registrosPrevios.map((registro) =>
    registro.id === registroActualizado.id ? registroActualizado : registro
  );
};