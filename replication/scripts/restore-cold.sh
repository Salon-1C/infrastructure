#!/usr/bin/env bash
# Restaura blume_business_db desde un dump mysqldump (failover Cold).
# Uso: bash restore-cold.sh <ruta-al-backup.sql>
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BACKUP_FILE="${1:?Indica la ruta del archivo .sql de respaldo}"

# shellcheck disable=SC1091
source .env 2>/dev/null || true
DB_PASSWORD="${DB_PASSWORD:?DB_PASSWORD no definido en .env}"
DB_NAME="${DB_NAME:-blume}"

if [[ ! -f "$BACKUP_FILE" ]]; then
  echo "[cold-restore] ERROR: archivo no encontrado: $BACKUP_FILE"
  exit 1
fi

echo "[cold-restore] Restaurando ${DB_NAME} desde ${BACKUP_FILE}..."
docker compose exec -T mysql mysql -uroot -p"${DB_PASSWORD}" -e "DROP DATABASE IF EXISTS \`${DB_NAME}\`; CREATE DATABASE \`${DB_NAME}\`;"
docker compose exec -T mysql mysql -uroot -p"${DB_PASSWORD}" "${DB_NAME}" < "${BACKUP_FILE}"
echo "[cold-restore] Restauración completada."
