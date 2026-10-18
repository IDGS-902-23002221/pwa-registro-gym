#!/usr/bin/env bash
# scripts/test-folios-concurrencia.sh
# 02 §5: "cobrar dos veces el mismo periodo" tiene que rechazarse siempre, incluso
# si dos cajeros cobran a la vez. Esta prueba abre dos sesiones de psql en paralelo
# y les hace cobrar a socios distintos al mismo tiempo.
#
# Por que socios distintos: el indice unico (socio_id, periodo) ya esta probado en
# db/tests/02_doble_cobro.sql. Lo que se prueba aqui es que la secuencia del folio
# reparte numeros sin repetir cuando dos sesiones cobran a la vez, que es el otro
# modo de fallo del mismo requisito.
#
# Sale con codigo 1 si los folios se repiten.

set -uo pipefail

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "Falta DATABASE_URL."
  exit 1
fi

TRABAJO="$(mktemp -d)"
trap 'rm -rf "$TRABAJO"' EXIT

SOCIOS_POR_SESION=25

# Cada sesion cobra a sus socios en una sola transaccion y la confirma. Se ejecutan
# las dos en paralelo: sin solapamiento la prueba no valeria nada.
generar_sesion() {
  local offset="$1"
  local salida="$2"

  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -f - >"$salida" 2>&1 <<SQL
BEGIN;

-- El perfil que opera. Necesario porque registrar_pago() exige sesion activa.
INSERT INTO public.perfil (id, nombre, activo) VALUES
  ('99999999-9999-9999-9999-999999999999', 'Personal concurrencia', true)
ON CONFLICT (id) DO NOTHING;
SELECT set_config('app.usuario_id', '99999999-9999-9999-9999-999999999999', true);

-- El plan al que apunta el monto, para que la deduccion no se_pruebe.
INSERT INTO public.plan (id, nombre, precio_mxn, dias_periodo, activo) VALUES
  ('88888888-8888-8888-8888-888888888888', 'Plan concurrencia', 500.00, 30, true)
ON CONFLICT (nombre) DO NOTHING;

-- ${SOCIOS_POR_SESION} socios propios de esta sesion.
INSERT INTO public.socio (nombre, apellidos, telefono, pagado_hasta)
SELECT
  'Concurrencia',
  'Sesion ${offset} socio ' || lpad(i::text, 3, '0'),
  '55' || lpad(('${offset}' || lpad(i::text, 3, '0'))::text, 9, '0'),
  DATE '2025-12-31'
FROM generate_series(1, ${SOCIOS_POR_SESION}) AS i;

-- Un cobro por socio.
SELECT public.registrar_pago(
  id, 500.00, 'efectivo', DATE '2026-10-01', 'concurrencia ${offset}'
)
FROM public.socio
WHERE apellidos LIKE 'Sesion ${offset} %';

COMMIT;
SQL
}

generar_sesion 1 "$TRABAJO/sesion_1.log" &
PID_1=$!
generar_sesion 2 "$TRABAJO/sesion_2.log" &
PID_2=$!

wait $PID_1; CODIGO_1=$?
wait $PID_2; CODIGO_2=$?

if [[ $CODIGO_1 -ne 0 ]]; then
  echo "La sesion 1 fallo:"
  sed 's/^/  /' "$TRABAJO/sesion_1.log"
  exit 1
fi
if [[ $CODIGO_2 -ne 0 ]]; then
  echo "La sesion 2 fallo:"
  sed 's/^/  /' "$TRABAJO/sesion_2.log"
  exit 1
fi

# Los dos cobros al mismo socio no pueden haberse colado: el indice unico lo impedia,
# pero que la prueba lo confirme es lo que la hace util si alguien cambia el indice.
REPETIDOS="$(psql "$DATABASE_URL" -tAc "
  SELECT coalesce(sum(repeticiones) - count(*), 0)
  FROM (
    SELECT socio_id, periodo, count(*) AS repeticiones
    FROM public.pago
    WHERE referencia LIKE 'concurrencia %'
    GROUP BY socio_id, periodo
  ) d
")"

if [[ "$REPETIDOS" != "0" ]]; then
  echo "FALLO: hay $REPETIDOS periodos cobrados mas de una vez"
  exit 1
fi

# Y ningun folio repetido en toda la base.
FOLIOS="$(psql "$DATABASE_URL" -tAc '
  SELECT count(*) - count(DISTINCT folio) FROM public.recibo
')"

if [[ "$FOLIOS" != "0" ]]; then
  echo "FALLO: hay $FOLIOS folios repetidos"
  exit 1
fi

TOTAL="$(psql "$DATABASE_URL" -tAc "
  SELECT count(*) FROM public.pago WHERE referencia LIKE 'concurrencia %'
")"

echo "  $TOTAL cobros de dos sesiones en paralelo, sin periodos ni folios repetidos"

# Limpieza: estas filas son de la prueba, no del seed. El orden importa porque
# recibo.pago_id, membresia.plan_id y pago.registrado_por son ON DELETE RESTRICT: hay
# que borrar de abajo hacia arriba o Postgres rechaza el borrado. La bitácora se
# borra PRIMERO (referencia a los pagos por entidad_id) para no dejar basura que
# contamine el conteo de db/tests/02_doble_cobro.sql.
psql "$DATABASE_URL" -q <<SQL >/dev/null 2>&1
BEGIN;
DELETE FROM public.auditoria
 WHERE (accion = 'cobro' AND entidad = 'pago'
        AND entidad_id IN (SELECT id FROM public.pago WHERE referencia LIKE 'concurrencia %'))
    OR (accion = 'alta' AND entidad = 'socio'
        AND entidad_id IN (SELECT id FROM public.socio WHERE apellidos LIKE 'Sesion % %'));
DELETE FROM public.recibo r
  USING public.pago p
 WHERE r.pago_id = p.id AND p.referencia LIKE 'concurrencia %';
DELETE FROM public.pago WHERE referencia LIKE 'concurrencia %';
DELETE FROM public.socio WHERE apellidos LIKE 'Sesion % %';
DELETE FROM public.plan  WHERE nombre = 'Plan concurrencia';
DELETE FROM public.perfil WHERE id = '99999999-9999-9999-9999-999999999999';
COMMIT;
SQL

exit 0