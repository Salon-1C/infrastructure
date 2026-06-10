#!/usr/bin/env bash
# Sidecar: respaldos cold automáticos de blume_record_db.
set -euo pipefail

DB_PASSWORD="${DB_PASSWORD:?DB_PASSWORD requerido}"
DB_NAME="${DB_NAME:?DB_NAME requerido}"
MYSQL_HOST="${MYSQL_HOST:-recordings-mysql}"
BACKUP_INTERVAL_SECONDS="${BACKUP_INTERVAL_SECONDS:-3600}"
BACKUP_RETENTION_COUNT="${BACKUP_RETENTION_COUNT:-24}"
BACKUP_DIR="/backups"

mkdir -p "$BACKUP_DIR"

run_backup() {
  local stamp out
  stamp="$(date +%Y%m%d-%H%M%S)"
  out="${BACKUP_DIR}/${DB_NAME}-${stamp}.sql"

  echo "[cold-backup] Generando respaldo de blume_record_db en ${out}..."
  mysqldump -h "$MYSQL_HOST" -uroot -p"${DB_PASSWORD}" \
    --single-transaction --routines --triggers "${DB_NAME}" > "${out}"
  echo "[cold-backup] Respaldo completado: ${out}"

  local count
  count="$(ls -1 "${BACKUP_DIR}/${DB_NAME}-"*.sql 2>/dev/null | wc -l | tr -d ' ')"
  if [[ "$count" -gt "$BACKUP_RETENTION_COUNT" ]]; then
    local to_delete=$((count - BACKUP_RETENTION_COUNT))
    echo "[cold-backup] Purgando ${to_delete} respaldo(s) antiguo(s) (retención=${BACKUP_RETENTION_COUNT})..."
    ls -1t "${BACKUP_DIR}/${DB_NAME}-"*.sql | tail -n "$to_delete" | xargs -r rm -f
  fi
}

echo "[cold-backup] Iniciando loop blume_record_db (intervalo=${BACKUP_INTERVAL_SECONDS}s, retención=${BACKUP_RETENTION_COUNT})..."

while true; do
  if run_backup; then
    echo "[cold-backup] Próximo respaldo en ${BACKUP_INTERVAL_SECONDS}s."
  else
    echo "[cold-backup] WARN: backup falló; reintentando en ${BACKUP_INTERVAL_SECONDS}s."
  fi
  sleep "$BACKUP_INTERVAL_SECONDS"
done
