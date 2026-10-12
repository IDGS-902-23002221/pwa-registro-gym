-- 0003_socios.sql
-- Tabla socio e indices de identidad y busqueda.
-- Ver 02 §4.

CREATE TABLE public.socio (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  -- No hay cedula ni fecha de nacimiento (02 §4): el socio se identifica con este
  -- id interno y se busca por nombre. El indice unico de abajo es el que
  -- realmente impide dar de alta dos veces al mismo.
  nombre       text        NOT NULL CHECK (btrim(nombre) <> ''),
  apellidos    text,
  correo       text,
  telefono     text        CHECK (telefono IS NULL OR length(normalizar_telefono(telefono)) >= 7),
  -- Estado almacenado. El estado visible (activo/pausado/vencido) lo calcula la
  -- vista socios_con_estado de 0006.
  estado       public.estado_socio NOT NULL DEFAULT 'activo',
  -- Dato desnormalizado a proposito (ADR-004): guarda la ultima fecha pagada y lo
  -- actualiza solo registrar_pago (0007). Evita un SUM por fila en la lista de
  -- socios. 0008_rls.sql le quita al cliente el permiso de actualizar esta
  -- columna, y db/tests/05_cadena_de_cobertura.sql la contrasta contra el
  -- ultimo pago real.
  pagado_hasta date,
  -- Marca de anonimizacion por ARCO. No esta en 02 §4; se agrega porque sin el la
  -- vista no tiene forma de dejar de listar a un socio eliminado: eliminar_socio no
  -- borra la fila, la anonimiza. 02 §4 deja abierto si los recibos se conservan, y
  -- por ahora se conservan (ADR-008); ver el comentario de eliminar_socio en 0007.
  eliminado_en timestamptz,
  creado_en    timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE  public.socio IS
  'Socios del gimnasio. Sin cedula ni fecha de nacimiento.';
COMMENT ON COLUMN public.socio.pagado_hasta IS
  'Ultimo dia pagado. Solo la escribe registrar_pago (ADR-004).';
COMMENT ON COLUMN public.socio.eliminado_en IS
  'Fecha de anonimizacion por ARCO. No NULL = socio vigente.';

-- ---------------------------------------------------------------------------
-- Identidad unica
-- ---------------------------------------------------------------------------
-- Mismo nombre + apellidos + telefono = mismo socio, y la interfaz ofrece renovar
-- en vez de duplicar (02 §4). El indice es parcial a proposito: sin telefono no
-- hay forma de saber si dos registros con el mismo nombre son la misma persona,
-- asi que solo se evita el duplicado cuando hay telefono.
--
-- Comparar sobre las funciones normalizadas hace que "Jose  Pérez " y
-- "josé pérez" colisionen.
CREATE UNIQUE INDEX socio_identidad_uk
  ON public.socio (
    normalizar_texto(nombre),
    normalizar_texto(apellidos),
    normalizar_telefono(telefono)
  )
  WHERE telefono IS NOT NULL
    AND btrim(telefono) <> '';

-- Aviso (no bloqueo) cuando el nombre existe con otro telefono: este indice de
-- solo lectura es el que permite la busqueda que dispara ese aviso.
CREATE INDEX socio_busqueda_nombre_idx
  ON public.socio (normalizar_texto(apellidos), normalizar_texto(nombre));

-- Reporte de cartera y filtro de vencidos.
CREATE INDEX socio_pagado_hasta_idx
  ON public.socio (pagado_hasta)
  WHERE eliminado_en IS NULL;

-- Listado por antiguedad, que es el orden por defecto de la tabla.
CREATE INDEX socio_creado_en_idx ON public.socio (creado_en DESC);

-- Nota sobre el correo: 000.0 asumia que el email
-- necesitaba unique en la base, pero 02 §4 no lo declara y no debe llevarlo: dos
-- familiares pueden compartir un correo y el correo es opcional. Si en algun
-- momento hace falta, se agrega como indice unico parcial con correo NOT NULL,
-- en una migracion nueva.