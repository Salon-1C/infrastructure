#!/usr/bin/env bash
# Escenario Cold — recuperación desde respaldo lógico (mysqldump).
#
# Uso:
#   cd infrastructure && docker compose up -d
#   bash tests/replication/cold/run-test.sh
#
# El test crea datos, respalda, simula desastre y mide RTO de restauración.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../common.sh"

require_stack

echo "══════════════════════════════════════════════════════"
echo " REPLICATION COLD — Recuperación desde backup (mysqldump)"
echo "══════════════════════════════════════════════════════"
echo ""

ensure_marker_table

MARKER_BEFORE="cold-before-$(date +%s)"
MARKER_AFTER="cold-after-$(date +%s)"

mysql_primary "
INSERT INTO ${DB_NAME}.replication_test_marker (marker_id, scenario, note)
VALUES ('${MARKER_BEFORE}', 'cold', 'before backup');
"

BACKUP_FILE="$(bash replication/scripts/backup-cold.sh | tail -n 1)"
check_true "Respaldo cold generado (${BACKUP_FILE})" "[[ -f '${BACKUP_FILE}' && -s '${BACKUP_FILE}' ]]"

mysql_primary "
INSERT INTO ${DB_NAME}.replication_test_marker (marker_id, scenario, note)
VALUES ('${MARKER_AFTER}', 'cold', 'after backup — must be lost on restore');
"

COUNT_AFTER="$(mysql_primary "SELECT COUNT(*) FROM ${DB_NAME}.replication_test_marker WHERE marker_id='${MARKER_AFTER}';")"
check_eq "Dato post-backup presente antes del desastre" "1" "$COUNT_AFTER"

echo ""
echo "  Simulando desastre: DROP DATABASE ${DB_NAME}..."
START_RESTORE=$(date +%s%3N)
docker compose exec -T mysql mysql -uroot -p"${DB_PASSWORD}" -e "DROP DATABASE \`${DB_NAME}\`;"

DISASTER_CODE="$(curl_explorar_code)"
if [[ "$DISASTER_CODE" != "200" ]]; then
  log_pass "Servicio degradado/no disponible tras desastre (got HTTP ${DISASTER_CODE})"
  PASS=$((PASS + 1))
else
  log_fail "Servicio degradado/no disponible tras desastre (got HTTP ${DISASTER_CODE})"
fi

bash replication/scripts/restore-cold.sh "$BACKUP_FILE" >/dev/null
END_RESTORE=$(date +%s%3N)
RTO_MS=$((END_RESTORE - START_RESTORE))

COUNT_BEFORE="$(mysql_primary "SELECT COUNT(*) FROM ${DB_NAME}.replication_test_marker WHERE marker_id='${MARKER_BEFORE}';")"
COUNT_AFTER_RESTORE="$(mysql_primary "SELECT COUNT(*) FROM ${DB_NAME}.replication_test_marker WHERE marker_id='${MARKER_AFTER}';")"

check_eq "Marcador pre-backup recuperado (RPO = punto del dump)" "1" "$COUNT_BEFORE"
check_eq "Marcador post-backup NO recuperado (pérdida acorde a RPO cold)" "0" "$COUNT_AFTER_RESTORE"

HTTP_AFTER="$(curl_explorar_code)"
check_eq "Servicio restaurado tras recovery" "200" "$HTTP_AFTER"

if [[ "$RTO_MS" -le 120000 ]]; then
  log_pass "RTO de restauración ≤ 120 s (got: ${RTO_MS} ms)"
else
  log_fail "RTO de restauración ≤ 120 s (got: ${RTO_MS} ms)"
fi

print_summary "COLD REPLICATION" || exit 1
