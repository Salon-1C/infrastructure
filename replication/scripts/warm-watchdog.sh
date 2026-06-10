#!/usr/bin/env bash
# Sidecar: monitoriza y repara replicación warm automáticamente.
set -euo pipefail

DB_PASSWORD="${DB_PASSWORD:?DB_PASSWORD requerido}"
DB_NAME="${DB_NAME:-blume}"
MYSQL_HOST="${MYSQL_HOST:-mysql}"
MYSQL_WARM_HOST="${MYSQL_WARM_HOST:-mysql-warm}"
WARM_CHECK_INTERVAL="${WARM_CHECK_INTERVAL:-60}"

replica_healthy() {
  local status
  status="$(mysql -h "$MYSQL_WARM_HOST" -uroot -p"${DB_PASSWORD}" -N -e \
    "SHOW REPLICA STATUS\G" 2>/dev/null | tr -d '\r' || true)"
  local io sql
  io=$(echo "$status" | grep -E 'Replica_IO_Running:' | awk '{print $2}')
  sql=$(echo "$status" | grep -E 'Replica_SQL_Running:' | awk '{print $2}')
  [[ "$io" == "Yes" && "$sql" == "Yes" ]]
}

echo "[warm-watchdog] Iniciando monitor de replicación (${MYSQL_HOST} → ${MYSQL_WARM_HOST})..."

while true; do
  if replica_healthy; then
    echo "[warm-watchdog] Replicación OK. Próxima verificación en ${WARM_CHECK_INTERVAL}s."
  else
    echo "[warm-watchdog] Replicación degradada. Ejecutando warm-replicate-core..."
    export DB_PASSWORD DB_NAME MYSQL_HOST MYSQL_WARM_HOST
    if bash /warm-replicate-core.sh; then
      echo "[warm-watchdog] Replicación restaurada."
    else
      echo "[warm-watchdog] WARN: warm-replicate-core falló; reintentando en ${WARM_CHECK_INTERVAL}s."
    fi
  fi
  sleep "$WARM_CHECK_INTERVAL"
done
