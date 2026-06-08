#!/usr/bin/env bash
# Respaldo lógico (cold standby) de blume_business_db vía mysqldump.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

# shellcheck disable=SC1091
source .env 2>/dev/null || true
DB_PASSWORD="${DB_PASSWORD:?DB_PASSWORD no definido en .env}"
DB_NAME="${DB_NAME:-blume}"

BACKUP_DIR="${ROOT}/replication/backups"
mkdir -p "$BACKUP_DIR"

STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${BACKUP_DIR}/${DB_NAME}-${STAMP}.sql"

echo "[cold-backup] Generando respaldo en ${OUT}..."
docker compose exec -T mysql mysqldump \
  -uroot -p"${DB_PASSWORD}" \
  --single-transaction \
  --routines \
  --triggers \
  "${DB_NAME}" > "${OUT}"

echo "${OUT}"
