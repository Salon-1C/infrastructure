#!/usr/bin/env bash
# Failover manual Warm: promueve mysql-warm a primario de escritura.
#
# Uso:
#   cd infrastructure && bash replication/scripts/promote-warm.sh
#
# Tras ejecutar, actualiza DB_HOST=mysql-warm en docker-compose.yml (o .env override)
# y reinicia blume-business-logic-ms:
#   docker compose up -d blume-business-logic-ms
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

# shellcheck disable=SC1091
source .env 2>/dev/null || true
DB_PASSWORD="${DB_PASSWORD:?DB_PASSWORD no definido en .env}"

echo "[promote-warm] Deteniendo replicación en mysql-warm..."
docker compose exec -T mysql-warm mysql -uroot -p"${DB_PASSWORD}" -e "
STOP REPLICA;
RESET REPLICA ALL;
SET GLOBAL read_only = 0;
"

echo "[promote-warm] mysql-warm promovido a primario de escritura."
echo ""
echo "  Pasos manuales restantes:"
echo "  1. Detener o aislar el mysql primario caído si aún corre."
echo "  2. Cambiar DB_HOST de blume-business-logic-ms a mysql-warm en docker-compose.yml."
echo "  3. Reiniciar microservicios:"
echo "       docker compose up -d blume-business-logic-ms"
echo ""
echo "  RTO estimado: minutos (según tiempo de reconfiguración manual)."
