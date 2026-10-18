#!/usr/bin/env bash
# scripts/test-db.sh
# Corre las verificaciones de db/tests/ contra la base de DATABASE_URL.
#
#   ./scripts/test-db.sh
#
# Cada prueba de db/tests/ va en su propia transaccion y la revierte al terminar,
# asi que esto no deja filas. Lo unico que sobrevive son los valores quemados de las
# secuencias, que es irrelevante.
#
# Sale con codigo 1 si algo falla, para poder engancharlo a lo que sea despues.

set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v psql >/dev/null 2>&1; then
  echo "psql no esta instalado. En WSL: sudo apt update && sudo apt install -y postgresql postgresql-client"
  exit 1
fi

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "Falta DATABASE_URL."
  echo
  echo "  export DATABASE_URL='postgresql://usuario@localhost:5432/registro_gym'"
  echo
  echo "La base debe tener las migraciones aplicadas: ./scripts/migrate.sh"
  exit 1
fi

# Las pruebas 06 cambian de rol con SET ROLE, asi que hace falta poder pasar a
# anon y authenticated, que solo puede hacer quien es superusuario.
ROL_ACTUAL="$(psql "$DATABASE_URL" -tAc 'SELECT current_user' 2>/dev/null)"
if [[ -z "$ROL_ACTUAL" ]]; then
  echo "No se pudo conectar a la base con DATABASE_URL."
  exit 1
fi
if [[ "$(psql "$DATABASE_URL" -tAc "SELECT count(*) FROM pg_roles WHERE rolname IN ('anon','authenticated')")" != "2" ]]; then
  echo "Los roles anon y authenticated no existen."
  echo "Se crean al aplicar 0008_rls.sql. Corre ./scripts/migrate.sh primero."
  exit 1
fi

# Sin esto una verificacion que falla a mitad puede dejar datos y la siguiente
# empieza sobre un estado que ya no es el de partida.
if [[ "$(psql "$DATABASE_URL" -tAc 'SELECT count(*) FROM public.schema_migrations')" == "0" ]]; then
  echo "No hay migraciones aplicadas. Corre ./scripts/migrate.sh primero."
  exit 1
fi

echo "Base:  ${DATABASE_URL%%\?*}"
echo "Rol:   ${ROL_ACTUAL}"
echo "Migraciones aplicadas: $(psql "$DATABASE_URL" -tAc 'SELECT count(*) FROM public.schema_migrations')"
echo

TOTAL=0
FALLIDAS=0
FALLOS=()

for archivo in "$RAIZ"/db/tests/[0-9]*.sql; do
  nombre="$(basename "$archivo")"
  TOTAL=$((TOTAL + 1))
  echo "----------------------------------------------------------------"
  echo ">> $nombre"

  salida="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -f "$archivo" 2>&1)"
  codigo=$?

  # El detalle del fallo se imprime completo: un FALLO sin su mensaje no sirve.
  echo "$salida" | sed 's/^/   /'

  if [[ $codigo -eq 0 ]]; then
    echo "   PASA $nombre"
  else
    echo "   FALLA $nombre (codigo $codigo)"
    FALLIDAS=$((FALLIDAS + 1))
    FALLOS+=("$nombre")
  fi
done

echo "----------------------------------------------------------------"
echo "Folios bajo concurrencia (dos sesiones a la vez)"

if "$RAIZ"/scripts/test-folios-concurrencia.sh; then
  echo "   PASA test-folios-concurrencia.sh"
else
  echo "   FALLA test-folios-concurrencia.sh"
  FALLIDAS=$((FALLIDAS + 1))
  FALLOS+=("test-folios-concurrencia.sh")
fi

echo "----------------------------------------------------------------"
echo "$((TOTAL + 1)) verificaciones, $FALLIDAS fallidas"

if [[ $FALLIDAS -gt 0 ]]; then
  echo "Fallaron:"
  for f in "${FALLOS[@]}"; do echo "  - $f"; done
  exit 1
fi

echo "Todo en verde."