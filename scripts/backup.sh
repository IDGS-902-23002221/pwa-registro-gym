#!/usr/bin/env bash
#
# Respaldo nocturno de la base de Supabase (03 §3).
#
#   DATABASE_URL=<pooler> ./scripts/backup.sh [directorio]
#
# Genera un pg_dump en formato custom con fecha y lo deja en el directorio dado
# (por defecto, ./respaldos/). La cadena de producción nunca se escribe en el
# repo: llega por variable de entorno (en GitHub Actions, secret).
#
# Salida: 0 si el respaldo quedó verificado, 1 si algo falló.

set -Eeuo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESTINO="${1:-$RAIZ/respaldos}"
FECHA="$(date +%F)"
ARCHIVO="$DESTINO/respaldo-$FECHA.dump"

if [ -z "${DATABASE_URL:-}" ]; then
  echo "ERROR: falta DATABASE_URL (la del pooler de Supabase)." >&2
  exit 1
fi

if ! command -v pg_dump >/dev/null 2>&1; then
  echo "ERROR: no se encontro 'pg_dump' en el PATH." >&2
  exit 1
fi

mkdir -p "$DESTINO"

echo "Respaldando en $ARCHIVO ..."
# Se excluye vault (esquema interno de Supabase que no existe en local y no
# aporta nada a la restauración): así el simulacro corre limpio.
pg_dump "$DATABASE_URL" -Fc -N vault -f "$ARCHIVO"

# Verificación mínima: el archivo existe, pesa algo y pg_restore lo lista.
if [ ! -s "$ARCHIVO" ]; then
  echo "ERROR: el respaldo quedo vacio." >&2
  exit 1
fi
TABLAS="$(pg_restore --list "$ARCHIVO" 2>/dev/null | grep -c 'TABLE DATA' || true)"
if [ "$TABLAS" -lt 5 ]; then
  echo "ERROR: el respaldo trae $TABLAS tablas con datos, se esperaban al menos 5." >&2
  exit 1
fi

echo "Listo: $ARCHIVO ($(du -h "$ARCHIVO" | cut -f1), $TABLAS tablas con datos)."
