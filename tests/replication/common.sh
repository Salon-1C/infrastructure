#!/usr/bin/env bash
# Utilidades compartidas para pruebas de replicación.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

# shellcheck disable=SC1091
source .env 2>/dev/null || true

DB_PASSWORD="${DB_PASSWORD:?DB_PASSWORD no definido en infrastructure/.env}"
DB_NAME="${DB_NAME:-blume}"
BASE_URL="${BASE_URL:-https://localhost}"

PASS=0
FAIL=0

log_pass() { echo "  PASS: $*"; PASS=$((PASS + 1)); }
log_fail() { echo "  FAIL: $*"; FAIL=$((FAIL + 1)); }

check_eq() {
  local desc=$1 expected=$2 actual=$3
  if [[ "$actual" == "$expected" ]]; then
    log_pass "$desc (got: $actual)"
  else
    log_fail "$desc (expected: $expected, got: $actual)"
  fi
}

check_true() {
  local desc=$1
  shift
  if eval "$*"; then
    log_pass "$desc"
  else
    log_fail "$desc"
  fi
}

wait_explorar_200() {
  local max=${1:-30}
  for _ in $(seq 1 "$max"); do
    [[ "$(curl_explorar_code)" == "200" ]] && return 0
    sleep 2
  done
  return 1
}

require_stack() {
  if ! docker compose ps mysql 2>/dev/null | grep -q "Up"; then
    echo "Stack no levantado. Ejecuta: cd infrastructure && docker compose up -d"
    exit 1
  fi
}

wait_warm_replication() {
  local max=${1:-90}
  for i in $(seq 1 "$max"); do
    local status io sql
    status="$(docker compose exec -T mysql-warm mysql -uroot -p"${DB_PASSWORD}" -e \
      "SHOW REPLICA STATUS\G" 2>/dev/null | tr -d '\r' || true)"
    io=$(echo "$status" | grep -E 'Replica_IO_Running:' | awk '{print $2}')
    sql=$(echo "$status" | grep -E 'Replica_SQL_Running:' | awk '{print $2}')
    if [[ "$io" == "Yes" && "$sql" == "Yes" ]]; then
      return 0
    fi
    [[ "$i" -eq 1 ]] && echo "  Esperando replicación warm (replication-warm-setup)..."
    sleep 2
  done
  return 1
}

mysql_primary() {
  docker compose exec -T mysql mysql -uroot -p"${DB_PASSWORD}" -N -e "$*"
}

mysql_warm() {
  docker compose exec -T mysql-warm mysql -uroot -p"${DB_PASSWORD}" -N -e "$*"
}

ensure_marker_table() {
  mysql_primary "
CREATE TABLE IF NOT EXISTS ${DB_NAME}.replication_test_marker (
  marker_id VARCHAR(64) PRIMARY KEY,
  scenario VARCHAR(16) NOT NULL,
  note VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);"
}

curl_explorar_code() {
  curl -k -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 15 \
    "${BASE_URL}/api/cursos/explorar" 2>/dev/null || echo "000"
}

print_summary() {
  local title=$1
  echo ""
  echo "══════════════════════════════════════════════════════"
  echo " ${title}"
  echo " Results: ${PASS}/$((PASS + FAIL)) PASS  |  ${FAIL} FAIL"
  echo "══════════════════════════════════════════════════════"
  [[ "$FAIL" -eq 0 ]]
}
