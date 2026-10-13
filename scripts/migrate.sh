#!/usr/bin/env bash
#
# Aplica las migraciones pendientes de db/migrations/ en orden.
#
#   Local      DATABASE_URL=postgresql://... ./scripts/migrate.sh
#   Supabase   DATABASE_URL=postgresql://... ./scripts/migrate.sh --objetivo supabase
#
# Reglas (03 DevOps §2):
#   - Cada archivo se aplica dentro de su propia transaccion. Por eso los archivos
#     NO deben traer BEGIN/COMMIT ni usar CREATE INDEX CONCURRENTLY.
#   - Se detiene en la primera migracion que falle.
#   - Una migracion ya aplicada no se edita jamas (ADR-008): si su checksum cambio,
#     el script falla y hay que escribir una migracion nueva que la corrija.
#
# Salida: 0 si todo quedo aplicado, 1 si algo fallo.

set -Eeuo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR_MIGRACIONES="$RAIZ/db/migrations"
ESQUEMA="public"
TABLA="$ESQUEMA.schema_migrations"

# Migraciones que solo aplican en Supabase (el esquema "auth" no existe en local).
# Se marcan en el propio archivo con:  -- migrate:require supabase

OBJETIVO="local"
LISTAR_SOLO=0

while [ $# -gt 0 ]; do
  case "$1" in
    --objetivo)
      [ $# -ge 2 ] || { echo "ERROR: --objetivo requiere un valor (local|supabase)" >&2; exit 1; }
      OBJETIVO="$2"; shift 2 ;;
    --listar)
      LISTAR_SOLO=1; shift ;;
    -h|--help)
      sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)
      echo "ERROR: argumento desconocido: $1" >&2; exit 1 ;;
  esac
done

case "$OBJETIVO" in
  local|supabase) ;;
  *) echo "ERROR: --objetivo debe ser 'local' o 'supabase' (recibido: $OBJETIVO)" >&2; exit 1 ;;
esac

if [ -z "${DATABASE_URL:-}" ]; then
  cat >&2 <<'MSG'
ERROR: falta DATABASE_URL.

  Local:     DATABASE_URL=postgresql://postgres:***@localhost:5432/registro_gym ./scripts/migrate.sh
  Supabase:  DATABASE_URL="postgresql://postgres.***@db.***.supabase.co:5432/postgres" \
             ./scripts/migrate.sh --objetivo supabase

La cadena de produccion nunca se escribe en el repo ni en Netlify (02 §8).
MSG
  exit 1
fi

if ! command -v psql >/dev/null 2>&1; then
  cat >&2 <<'MSG'
ERROR: no se encontro 'psql' en el PATH.

  En WSL (Debian):  sudo apt update && sudo apt install -y postgresql postgresql-client
  En Windows:       usar Git Bash con el cliente instalado, o el SQL Editor del panel de Supabase.
MSG
  exit 1
fi

if [ ! -d "$DIR_MIGRACIONES" ]; then
  echo "ERROR: no existe $DIR_MIGRACIONES" >&2
  exit 1
fi

PSQL=(psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q)

ejecutar() { "${PSQL[@]}" "$@"; }

# --- Conexion -------------------------------------------------------------
if ! ejecutar -c 'SELECT 1' >/dev/null 2>&1; then
  echo "ERROR: no se pudo conectar a la base de datos con DATABASE_URL." >&2
  echo "       Revisa que el host, el puerto y las credenciales sean correctos." >&2
  exit 1
fi

DESTINO="$(ejecutar -At -c "SELECT current_database() || ' como ' || current_user")"
echo "Base de datos: $DESTINO   |   objetivo: $OBJETIVO"

# --- Tabla de control -----------------------------------------------------
ejecutar -c "
CREATE TABLE IF NOT EXISTS $TABLA (
  version     text        NOT NULL PRIMARY KEY,
  nombre      text        NOT NULL,
  checksum    text        NOT NULL,
  aplicado_en timestamptz NOT NULL DEFAULT now()
);" >/dev/null

# --- Inventario de archivos ----------------------------------------------
mapfile -t ARCHIVOS < <(cd "$DIR_MIGRACIONES" && ls -1 | grep -E '^[0-9]{4}_[a-z0-9_]+\.sql$' | LC_ALL=C sort)

if [ ${#ARCHIVOS[@]} -eq 0 ]; then
  echo "No hay migraciones en $DIR_MIGRACIONES"
  exit 0
fi

declare -A VERSION_DE_ARCHIVO=()
PENDIENTES=()
SALTADOS=()
YA_APLICADAS=()

for archivo in "${ARCHIVOS[@]}"; do
  ruta="$DIR_MIGRACIONES/$archivo"
  version="${archivo%%_*}"
  nombre="$archivo"

  # Numeracion consecutiva: dos archivos con el mismo numero es un error de dedo.
  if [ -n "${VERSION_DE_ARCHIVO[$version]:-}" ]; then
    echo "ERROR: dos migraciones con la version $version:" >&2
    echo "         ${VERSION_DE_ARCHIVO[$version]} y $nombre" >&2
    exit 1
  fi
  VERSION_DE_ARCHIVO[$version]="$nombre"

  if ! grep -qE '^[[:space:]]*--[[:space:]]*migrate:require[[:space:]]+supabase' "$ruta"; then
    PENDIENTES+=("$nombre")
    continue
  fi

  # Migracion solo-Supabase.
  if [ "$OBJETIVO" = "supabase" ]; then
    PENDIENTES+=("$nombre")
  else
    SALTADOS+=("$nombre")
  fi
done

# --- Revision de checksums de lo ya aplicado (ADR-008) --------------------
while IFS='|' read -r version nombre checksum; do
  [ -n "$version" ] || continue
  archivo_en_disco="${VERSION_DE_ARCHIVO[$version]:-}"
  if [ -z "$archivo_en_disco" ]; then
    echo "ERROR: la version $version esta aplicada pero su archivo no existe en db/migrations/." >&2
    echo "       Una migracion aplicada en produccion no se borra jamas." >&2
    exit 1
  fi
  checksum_actual="$(sha256sum "$DIR_MIGRACIONES/$archivo_en_disco" | cut -d' ' -f1)"
  if [ "$checksum_actual" != "$checksum" ]; then
    cat >&2 <<MSG
ERROR: la migracion $archivo_en_disco YA ESTA APLICADA y su contenido cambio.

  aplicada: $checksum
  en disco: $checksum_actual

  Regla de oro (03 DevOps §2, ADR-008): un archivo aplicado en produccion no se
  edita jamas. Para corregirlo, escribe una migracion nueva y deja este archivo
  exactamente como estaba.
MSG
    exit 1
  fi
  YA_APLICADAS+=("$archivo_en_disco")
done < <(ejecutar -At -F'|' -c "SELECT version, nombre, checksum FROM $TABLA ORDER BY version")

# --- Descontar lo ya aplicado de lo pendiente --------------------------------
# Sin esto el script re-aplica todo en cada corrida y solo funciona en bases
# recién creadas (bug encontrado 2026-10-11 al agregar la 0011 sobre local con
# la 0001-0008 ya aplicadas).
declare -A ES_APLICADA=()
for ya in ${YA_APLICADAS[@]+"${YA_APLICADAS[@]}"}; do ES_APLICADA["$ya"]=1; done
PENDIENTES_FILTRADAS=()
for nombre in "${PENDIENTES[@]}"; do
  [ -n "${ES_APLICADA[$nombre]:-}" ] || PENDIENTES_FILTRADAS+=("$nombre")
done
if [ ${#PENDIENTES_FILTRADAS[@]} -gt 0 ]; then
  PENDIENTES=("${PENDIENTES_FILTRADAS[@]}")
else
  PENDIENTES=()
fi

# --- Informe --------------------------------------------------------------
[ ${#YA_APLICADAS[@]} -gt 0 ] && echo "Ya aplicadas: ${#YA_APLICADAS[@]}"
[ ${#SALTADOS[@]} -gt 0 ]    && echo "Omitidas (solo Supabase) en este objetivo: ${SALTADOS[*]}"

if [ ${#PENDIENTES[@]} -eq 0 ]; then
  echo "No hay migraciones pendientes."
  exit 0
fi

echo "Pendientes (${#PENDIENTES[@]}):"
for nombre in "${PENDIENTES[@]}"; do
  printf '  %s  sha256:%s\n' "$nombre" "$(sha256sum "$DIR_MIGRACIONES/$nombre" | cut -c1-12)"
done

if [ "$LISTAR_SOLO" -eq 1 ]; then
  exit 0
fi

# --- Aplicacion -----------------------------------------------------------
for nombre in "${PENDIENTES[@]}"; do
  version="${nombre%%_*}"
  ruta="$DIR_MIGRACIONES/$nombre"
  checksum="$(sha256sum "$ruta" | cut -d' ' -f1)"

  echo "-> $nombre"

  # --single-transaction envuelve TODO el archivo en una transaccion y
  # ON_ERROR_STOP hace que psql salga con error al primer fallo, con lo que
  # la transaccion se revierte y la version no queda registrada.
  if ! "${PSQL[@]}" --single-transaction -f "$ruta"; then
    echo "ERROR: fallo la migracion $nombre. Se revirtio completa; no quedo registrada." >&2
    exit 1
  fi

  ejecutar -c "
    INSERT INTO $TABLA (version, nombre, checksum)
    VALUES ('$version', '$nombre', '$checksum');" >/dev/null
done

TOTAL="$(ejecutar -At -c "SELECT count(*) FROM $TABLA")"
echo "Listo. $TOTAL migracion(es) registradas en $TABLA."