#!/usr/bin/env bash
# Escenario Hot — réplicas activas de blume_business_logic_ms (active/active).
#
# Uso:
#   cd infrastructure && docker compose up -d
#   bash tests/replication/hot/run-test.sh
#
# Requisitos: curl, docker compose, stack en ejecución con deploy.replicas: 3

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../common.sh"

require_stack

echo "══════════════════════════════════════════════════════"
echo " REPLICATION HOT — Active/Active (blume_business_logic_ms)"
echo "══════════════════════════════════════════════════════"
echo ""

REPLICA_COUNT="$(docker compose ps blume-business-logic-ms --format json 2>/dev/null \
  | grep -c '"State":"running"' || docker compose ps blume-business-logic-ms 2>/dev/null | grep -c "running" || echo 0)"

if [[ "${REPLICA_COUNT}" -lt 3 ]]; then
  echo "  Escalando a 3 réplicas (docker compose --scale)..."
  docker compose up -d --scale blume-business-logic-ms=3 --no-recreate >/dev/null
  sleep 5
  REPLICA_COUNT="$(docker compose ps blume-business-logic-ms 2>/dev/null | grep -c "running" || echo 0)"
fi

check_true "Al menos 3 réplicas activas de business-logic (got: ${REPLICA_COUNT})" \
  "[[ ${REPLICA_COUNT} -ge 3 ]]"

if wait_explorar_200 30; then
  log_pass "Endpoint público responde antes del fallo (HTTP 200)"
  PASS=$((PASS + 1))
else
  log_fail "Endpoint público responde antes del fallo (HTTP $(curl_explorar_code))"
fi

TARGET="$(docker compose ps -q blume-business-logic-ms | head -n 1)"
if [[ -z "$TARGET" ]]; then
  log_fail "No se encontró contenedor business-logic para simular fallo"
else
  echo ""
  echo "  Simulando fallo de réplica: docker stop ${TARGET:0:12}..."
  docker stop "$TARGET" >/dev/null

  FAILURES=0
  for _ in $(seq 1 15); do
    code="$(curl_explorar_code)"
    [[ "$code" != "200" ]] && FAILURES=$((FAILURES + 1))
    sleep 1
  done

  check_eq "Peticiones fallidas durante 15 s post-fallo (objetivo: 0)" "0" "$FAILURES"

  docker start "$TARGET" >/dev/null 2>&1 || true
fi

print_summary "HOT REPLICATION" || exit 1
