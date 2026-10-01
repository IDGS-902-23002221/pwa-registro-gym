import { useState } from 'react';
import { crear, eliminar, actualizar } from '../services/membresiasService';

function useMembresias() {

  const [registros, setRegistros] = useState([]);
  // editar
  const [editandoId, setEditandoId] = useState(null);
  // detalle
  const [detalleId, setDetalleId] = useState(null);

  const agregarRegistro = (nuevoRegistro) => {
    setRegistros((registrosPrevios) => crear(registrosPrevios, nuevoRegistro));
  };

  const eliminarRegistro = (idAEliminar) => {
    setRegistros((registrosPrevios) => eliminar(registrosPrevios, idAEliminar));
  };

  const actualizarRegistro = (registroActualizado) => {
    setRegistros((registrosPrevios) => actualizar(registrosPrevios, registroActualizado));
    setEditandoId(null);
  };

  const registroEnEdicion = registros.find((registro) => registro.id === editandoId);

  const registroDetalle = registros.find((registro) => registro.id === detalleId);

  // todo lo que necesita la vista
  return {
    registros,
    setEditandoId,
    setDetalleId,
    agregarRegistro,
    eliminarRegistro,
    actualizarRegistro,
    registroEnEdicion,
    registroDetalle,
  };
}

export default useMembresias;