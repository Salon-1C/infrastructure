#!/usr/bin/env bash
# Restaura blume_record_db desde un dump mysqldump (failover Cold).
# Uso: bash restore-cold.sh <ruta-al-backup.sql>
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BACKUP_FILE="${1:?Indica la ruta del archivo .sql de respaldo}"

# shellcheck disable=SC1091
source .env 2>/dev/null || true
RECORD_DB_PASSWORD="${RECORD_DB_PASSWORD:?RECORD_DB_PASSWORD no definido en .env}"
RECORD_DB_NAME="${RECORD_DB_NAME:-recordings}"

if [[ ! -f "$BACKUP_FILE" ]]; then
  echo "[cold-restore] ERROR: archivo no encontrado: $BACKUP_FILE"
  exit 1
fi

echo "[cold-restore] Restaurando blume_record_db (${RECORD_DB_NAME}) desde ${BACKUP_FILE}..."
docker compose exec -T recordings-mysql mysql -uroot -p"${RECORD_DB_PASSWORD}" \
  -e "DROP DATABASE IF EXISTS \`${RECORD_DB_NAME}\`; CREATE DATABASE \`${RECORD_DB_NAME}\`;"
docker compose exec -T recordings-mysql mysql -uroot -p"${RECORD_DB_PASSWORD}" \
  "${RECORD_DB_NAME}" < "${BACKUP_FILE}"
echo "[cold-restore] Restauración completada."
