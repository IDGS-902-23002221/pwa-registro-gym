import {useState} from 'react';
import {crear, eliminar, actualizar} from '../services/sociosService';

function useSocios(){

    const [registros, setRegistros] = useState([]);

    const [editandoId, setEditandoId] = useState(null);

    const [detalleId, setDetalleId] = useState(null);

    const agregarRegistro = (nuevoRegistro) => {
        setRegistros((registrosPrevios) => crear(registrosPrevios, nuevoRegistro))
    }

    const actualizarRegistro = (registroActualizado) => {
        setRegistros((registrosPrevios) => actualizar(registrosPrevios, registroActualizado));
        setEditandoId(null);
    }

    const eliminarRegistro = (registroEliminado) => {
        setRegistros((registrosPrevios) => eliminar(registrosPrevios, registroEliminado))
    }

    const registroEnEdicion = registros.find((registro) => registro.id == editandoId); 

    const registroDetalle = registros.find((registro) => registro.id === detalleId);

    return{
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
export default useSocios;