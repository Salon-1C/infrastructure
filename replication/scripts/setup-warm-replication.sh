#!/usr/bin/env bash
# Configura replicación asíncrona MySQL primary → mysql-warm (escenario Warm).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

# shellcheck disable=SC1091
source .env 2>/dev/null || true
DB_PASSWORD="${DB_PASSWORD:?DB_PASSWORD no definido en .env}"
DB_NAME="${DB_NAME:-blume}"

COMPOSE=(docker compose -f docker-compose.yml -f docker-compose.replication.yml --profile replication)

mysql_exec() {
  local service=$1
  shift
  "${COMPOSE[@]}" exec -T "$service" mysql -uroot -p"${DB_PASSWORD}" -N -e "$*"
}

echo "[warm-setup] Esperando mysql y mysql-warm..."
"${COMPOSE[@]}" up -d mysql mysql-warm
for _ in $(seq 1 30); do
  if "${COMPOSE[@]}" ps mysql-warm 2>/dev/null | grep -q "(healthy)"; then
    break
  fi
  sleep 2
done

echo "[warm-setup] Creando usuario de replicación en primary (idempotente)..."
mysql_exec mysql "
DROP USER IF EXISTS 'repl'@'%';
CREATE USER 'repl'@'%' IDENTIFIED BY 'repl_blume_local';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
FLUSH PRIVILEGES;
"

read -r log_file log_pos <<< "$(mysql_exec mysql "SHOW BINARY LOG STATUS" | awk 'NR==1 {print $1, $2}')"
if [[ -z "${log_file:-}" || -z "${log_pos:-}" ]]; then
  echo "[warm-setup] ERROR: binlog no activo en mysql. Reinicia mysql con docker-compose.replication.yml."
  exit 1
fi

echo "[warm-setup] Primary binlog: ${log_file} @ ${log_pos}"

WARM_TABLES="$("${COMPOSE[@]}" exec -T mysql-warm mysql -uroot -p"${DB_PASSWORD}" -N -e \
  "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${DB_NAME}';" 2>/dev/null | tr -d '\r' || echo 0)"

if [[ "${WARM_TABLES:-0}" -eq 0 ]]; then
  echo "[warm-setup] Clonando snapshot inicial primary → mysql-warm..."
  "${COMPOSE[@]}" exec -T mysql-warm mysql -uroot -p"${DB_PASSWORD}" \
    -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;"
  docker compose exec -T mysql mysqldump -uroot -p"${DB_PASSWORD}" \
    --single-transaction --routines --triggers "${DB_NAME}" \
    | "${COMPOSE[@]}" exec -T mysql-warm mysql -uroot -p"${DB_PASSWORD}" "${DB_NAME}"
  read -r log_file log_pos <<< "$(mysql_exec mysql "SHOW BINARY LOG STATUS" | awk 'NR==1 {print $1, $2}')"
  echo "[warm-setup] Posición binlog post-clon: ${log_file} @ ${log_pos}"
fi

echo "[warm-setup] Configurando réplica warm..."
mysql_exec mysql-warm "
STOP REPLICA;
RESET REPLICA ALL;
CHANGE REPLICATION SOURCE TO
  SOURCE_HOST='mysql',
  SOURCE_USER='repl',
  SOURCE_PASSWORD='repl_blume_local',
  SOURCE_LOG_FILE='${log_file}',
  SOURCE_LOG_POS=${log_pos},
  GET_SOURCE_PUBLIC_KEY=1;
START REPLICA;
"

for _ in $(seq 1 30); do
  status="$(mysql_exec mysql-warm "SHOW REPLICA STATUS\G" | tr -d '\r' || true)"
  io=$(echo "$status" | grep -E 'Replica_IO_Running:' | awk '{print $2}')
  sql=$(echo "$status" | grep -E 'Replica_SQL_Running:' | awk '{print $2}')
  if [[ "$io" == "Yes" && "$sql" == "Yes" ]]; then
    echo "[warm-setup] Replicación activa (IO=Yes, SQL=Yes)."
    exit 0
  fi
  sleep 2
done

echo "[warm-setup] ERROR: la réplica no alcanzó estado Running."
mysql_exec mysql-warm "SHOW REPLICA STATUS\G" || true
exit 1
