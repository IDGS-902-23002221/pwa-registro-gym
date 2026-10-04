// funciones del crud 

// recibe arreglo actual y retorna uno nuevo

// el state se delega al hook 

//AGREGAR REGISTRO 
export const crear = (registrosPrevios, nuevoRegistro) => {
    return [...registrosPrevios, nuevoRegistro];
};

export const eliminar = (registrosPrevios, idAEliminar) => {
    //filter se queda con todos los registros cuyo id sea diferente al idAEliminar, los trus se quedan, los false se van
    // 1 !== 2 se queda - true
    // 2 !== 2 se va - false 
    return registrosPrevios.filter((registro) => registro.id !== idAEliminar);
};

// actualizar 

export const actualizar = (registrosPrevios, registroActualizado) => {
    return registrosPrevios.map((registro) => 
        registro.id === registroActualizado.id ? registroActualizado : registro
    );
};

