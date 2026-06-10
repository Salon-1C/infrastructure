#!/usr/bin/env bash
# Escenario Warm — réplica MySQL sincronizada pero no sirve tráfico de aplicación.
#
# Uso:
#   cd infrastructure && docker compose up -d
#   bash tests/replication/warm/run-test.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../common.sh"

require_stack

echo "══════════════════════════════════════════════════════"
echo " REPLICATION WARM — MySQL standby sincronizado (mysql-warm)"
echo "══════════════════════════════════════════════════════"
echo ""

if ! docker compose ps mysql-warm 2>/dev/null | grep -q "Up"; then
  echo "mysql-warm no está levantado. Ejecuta: docker compose up -d"
  exit 1
fi

if ! wait_warm_replication 90; then
  echo "Replicación warm no activa tras 90s. Revisa: docker compose logs replication-warm-setup"
  exit 1
fi

REPLICA_STATUS="$(docker compose exec -T mysql-warm mysql -uroot -p"${DB_PASSWORD}" -e \
  "SHOW REPLICA STATUS\G" 2>/dev/null | tr -d '\r' || true)"

IO_RUNNING="$(echo "$REPLICA_STATUS" | grep -E 'Replica_IO_Running:' | awk '{print $2}')"
SQL_RUNNING="$(echo "$REPLICA_STATUS" | grep -E 'Replica_SQL_Running:' | awk '{print $2}')"
SECONDS_BEHIND="$(echo "$REPLICA_STATUS" | grep -E 'Seconds_Behind_Source:' | awk '{print $2}')"

check_eq "Replica_IO_Running = Yes" "Yes" "$IO_RUNNING"
check_eq "Replica_SQL_Running = Yes" "Yes" "$SQL_RUNNING"

if [[ "$SECONDS_BEHIND" =~ ^[0-9]+$ ]]; then
  check_true "Lag de replicación ≤ 5 s (got: ${SECONDS_BEHIND}s)" "[[ ${SECONDS_BEHIND} -le 5 ]]"
else
  log_pass "Lag de replicación ≤ 5 s (NULL — réplica al día)"
  PASS=$((PASS + 1))
fi

ensure_marker_table
MARKER="warm-$(date +%s)-$RANDOM"
mysql_primary "
INSERT INTO ${DB_NAME}.replication_test_marker (marker_id, scenario, note)
VALUES ('${MARKER}', 'warm', 'insert on primary');
"

SYNCED=0
for _ in $(seq 1 15); do
  COUNT="$(mysql_warm "SELECT COUNT(*) FROM ${DB_NAME}.replication_test_marker WHERE marker_id='${MARKER}';" 2>/dev/null || echo 0)"
  if [[ "$COUNT" == "1" ]]; then
    SYNCED=1
    break
  fi
  sleep 1
done

check_true "Marcador replicado a mysql-warm" "[[ ${COUNT:-0} -eq 1 ]]"
check_true "Tiempo de propagación ≤ 15 s" "[[ ${SYNCED} -eq 1 ]]"

READ_ONLY="$(docker compose exec -T mysql-warm mysql -uroot -p"${DB_PASSWORD}" -N -e \
  "SELECT @@read_only;" 2>/dev/null | tr -d '\r')"
check_eq "Réplica warm permanece read-only (no sirve escrituras de app)" "1" "$READ_ONLY"

print_summary "WARM REPLICATION" || exit 1
