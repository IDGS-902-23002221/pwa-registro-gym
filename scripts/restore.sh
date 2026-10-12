#!/usr/bin/env bash
#
# Simulacro de restauración (03 §3, punto 7 del ticket padre).
#
#   ./scripts/restore.sh <archivo.dump> [base_destino]
#
# Restaura el respaldo en una base LOCAL de prueba y corre una verificación de
# cordura (migraciones registradas + planes). La base destino se crea de cero;
# si existe, se borra primero. NUNCA apuntes esto a Supabase.
#
# Salida: 0 si la restauración sirve, 1 si no.

set -Eeuo pipefail

if [ $# -lt 1 ]; then
  echo "Uso: $0 <archivo.dump> [base_destino]" >&2
  exit 1
fi

ARCHIVO="$1"
DESTINO="${2:-restauracion_prueba}"

if [[ "$DESTINO" == "postgres" ]]; then
  echo "ERROR: destino inválido." >&2
  exit 1
fi

if ! command -v pg_restore >/dev/null 2>&1; then
  echo "ERROR: no se encontro 'pg_restore' en el PATH." >&2
  exit 1
fi

if [ ! -f "$ARCHIVO" ]; then
  echo "ERROR: no existe $ARCHIVO." >&2
  exit 1
fi

echo "Restaurando $ARCHIVO en base local '$DESTINO' ..."
sudo -u postgres psql -c "DROP DATABASE IF EXISTS \"$DESTINO\";" >/dev/null
sudo -u postgres psql -c "CREATE DATABASE \"$DESTINO\";" >/dev/null
# El dump trae CREATE EXTENSION supabase_vault (interno de Supabase, no existe
# en local): se filtra de la lista de restauración. Todo lo demás entra igual.
LISTA="$(mktemp)"
pg_restore --list "$ARCHIVO" | grep -v -i 'supabase_vault' > "$LISTA"
# El password viaja por variable (igual que en DATABASE_URL), no interactivo.
PGPASSWORD=postgres pg_restore -h localhost -U postgres -d "$DESTINO" --no-owner --no-privileges -L "$LISTA" "$ARCHIVO" >/dev/null
rm -f "$LISTA"

LOCAL_URL="postgresql://postgres:postgres@localhost:5432/$DESTINO"
MIGRACIONES="$(psql "$LOCAL_URL" -tAc 'SELECT count(*) FROM public.schema_migrations')"
PLANES="$(psql "$LOCAL_URL" -tAc 'SELECT count(*) FROM public.plan WHERE activo')"

echo "Migraciones registradas: $MIGRACIONES | Planes activos: $PLANES"
if [ "$MIGRACIONES" -lt 1 ] || [ "$PLANES" -lt 1 ]; then
  echo "ERROR: la restauración quedó incompleta." >&2
  exit 1
fi

echo "Simulacro OK: el respaldo sí restaura."
