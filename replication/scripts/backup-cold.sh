#!/usr/bin/env bash
# Respaldo lógico (cold standby) de blume_record_db vía mysqldump.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

# shellcheck disable=SC1091
source .env 2>/dev/null || true
RECORD_DB_PASSWORD="${RECORD_DB_PASSWORD:?RECORD_DB_PASSWORD no definido en .env}"
RECORD_DB_NAME="${RECORD_DB_NAME:-recordings}"

BACKUP_DIR="${ROOT}/replication/backups"
mkdir -p "$BACKUP_DIR"

STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${BACKUP_DIR}/${RECORD_DB_NAME}-${STAMP}.sql"

echo "[cold-backup] Generando respaldo de blume_record_db en ${OUT}..."
docker compose exec -T recordings-mysql mysqldump \
  -uroot -p"${RECORD_DB_PASSWORD}" \
  --single-transaction \
  --routines \
  --triggers \
  "${RECORD_DB_NAME}" > "${OUT}"

echo "${OUT}"
