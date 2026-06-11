#!/usr/bin/env bash
# Lógica idempotente de replicación warm MySQL primary → standby.
# Invocable desde sidecar (hosts por env) o vía setup-warm-replication.sh.
set -euo pipefail

DB_PASSWORD="${DB_PASSWORD:?DB_PASSWORD requerido}"
DB_NAME="${DB_NAME:-blume}"
MYSQL_HOST="${MYSQL_HOST:-mysql}"
MYSQL_WARM_HOST="${MYSQL_WARM_HOST:-mysql-warm}"
REPL_PASSWORD="${REPL_PASSWORD:-repl_blume_local}"

mysql_on() {
  local host=$1
  shift
  mysql -h "$host" -uroot -p"${DB_PASSWORD}" -N -e "$*"
}

echo "[warm-replicate] Verificando binlog en ${MYSQL_HOST}..."
read -r log_file log_pos <<< "$(mysql_on "$MYSQL_HOST" "SHOW BINARY LOG STATUS" | awk 'NR==1 {print $1, $2}')"
if [[ -z "${log_file:-}" || -z "${log_pos:-}" ]]; then
  echo "[warm-replicate] ERROR: binlog no activo en ${MYSQL_HOST}"
  exit 1
fi

echo "[warm-replicate] Creando usuario de replicación en primary..."
mysql_on "$MYSQL_HOST" "
DROP USER IF EXISTS 'repl'@'%';
CREATE USER 'repl'@'%' IDENTIFIED BY '${REPL_PASSWORD}';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
FLUSH PRIVILEGES;
"

WARM_TABLES="$(mysql_on "$MYSQL_WARM_HOST" \
  "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${DB_NAME}';" 2>/dev/null | tr -d '\r' || echo 0)"

if [[ "${WARM_TABLES:-0}" -eq 0 ]]; then
  echo "[warm-replicate] Clonando snapshot inicial ${MYSQL_HOST} → ${MYSQL_WARM_HOST}..."
  mysql_on "$MYSQL_WARM_HOST" "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;"
  mysqldump -h "$MYSQL_HOST" -uroot -p"${DB_PASSWORD}" \
    --single-transaction --routines --triggers "${DB_NAME}" \
    | mysql -h "$MYSQL_WARM_HOST" -uroot -p"${DB_PASSWORD}" "${DB_NAME}"
  read -r log_file log_pos <<< "$(mysql_on "$MYSQL_HOST" "SHOW BINARY LOG STATUS" | awk 'NR==1 {print $1, $2}')"
  echo "[warm-replicate] Posición binlog post-clon: ${log_file} @ ${log_pos}"
fi

echo "[warm-replicate] Configurando réplica en ${MYSQL_WARM_HOST}..."
mysql_on "$MYSQL_WARM_HOST" "
STOP REPLICA;
RESET REPLICA ALL;
CHANGE REPLICATION SOURCE TO
  SOURCE_HOST='${MYSQL_HOST}',
  SOURCE_USER='repl',
  SOURCE_PASSWORD='${REPL_PASSWORD}',
  SOURCE_LOG_FILE='${log_file}',
  SOURCE_LOG_POS=${log_pos},
  GET_SOURCE_PUBLIC_KEY=1;
START REPLICA;
"

for _ in $(seq 1 30); do
  status="$(mysql -h "$MYSQL_WARM_HOST" -uroot -p"${DB_PASSWORD}" -e "SHOW REPLICA STATUS\G" | tr -d '\r' || true)"
  io=$(echo "$status" | grep -E 'Replica_IO_Running:' | awk '{print $2}')
  sql=$(echo "$status" | grep -E 'Replica_SQL_Running:' | awk '{print $2}')
  if [[ "$io" == "Yes" && "$sql" == "Yes" ]]; then
    echo "[warm-replicate] Replicación activa (IO=Yes, SQL=Yes)."
    exit 0
  fi
  sleep 2
done

echo "[warm-replicate] ERROR: la réplica no alcanzó estado Running."
mysql_on "$MYSQL_WARM_HOST" "SHOW REPLICA STATUS\G" || true
exit 1
