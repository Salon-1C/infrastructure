#!/usr/bin/env bash
# Wrapper manual: ejecuta warm-replicate-core dentro del sidecar o vía exec.
# Con docker compose up -d esto ya corre automáticamente vía replication-warm-setup.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

# shellcheck disable=SC1091
source .env 2>/dev/null || true
DB_PASSWORD="${DB_PASSWORD:?DB_PASSWORD no definido en .env}"
DB_NAME="${DB_NAME:-blume}"

echo "[warm-setup] Esperando mysql y mysql-warm..."
docker compose up -d mysql mysql-warm replication-warm-setup
for _ in $(seq 1 30); do
  if docker compose ps mysql-warm 2>/dev/null | grep -q "(healthy)"; then
    break
  fi
  sleep 2
done

echo "[warm-setup] Ejecutando warm-replicate-core en sidecar..."
docker compose exec -T replication-warm-setup bash /warm-replicate-core.sh
