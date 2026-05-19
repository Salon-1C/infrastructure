#!/usr/bin/env bash
# Prueba de la táctica de segmentación de red (atributo de calidad: Seguridad).
# Requiere el stack levantado: docker compose up -d
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

EDGE_NET="blume_edge"
APP_NET="blume_app"
DATA_NET="blume_data"
PROBE_IMAGE="${SEGMENTATION_PROBE_IMAGE:-alpine:3.20}"

PASS=0
FAIL=0

log_pass() { echo "[PASS] $*"; PASS=$((PASS + 1)); }
log_fail() { echo "[FAIL] $*"; FAIL=$((FAIL + 1)); }

require_network() {
  local net=$1
  if ! docker network inspect "$net" >/dev/null 2>&1; then
    echo "Red Docker '$net' no existe. Levanta el stack: docker compose up -d"
    exit 1
  fi
}

# nc -z: éxito si hay conexión TCP
can_connect() {
  local net=$1 host=$2 port=$3
  docker run --rm --network "$net" "$PROBE_IMAGE" \
    sh -c "nc -z -w 4 '$host' '$port'" >/dev/null 2>&1
}

can_connect_multi() {
  local host=$1 port=$2
  shift 2
  docker run --rm "$@" "$PROBE_IMAGE" \
    sh -c "nc -z -w 4 '$host' '$port'" >/dev/null 2>&1
}

assert_blocked() {
  local net=$1 host=$2 port=$3 desc=$4
  if can_connect "$net" "$host" "$port"; then
    log_fail "$desc — se alcanzó ${host}:${port} desde ${net} (debería estar bloqueado)"
  else
    log_pass "$desc"
  fi
}

assert_allowed() {
  local net=$1 host=$2 port=$3 desc=$4
  if can_connect "$net" "$host" "$port"; then
    log_pass "$desc"
  else
    log_fail "$desc — no se alcanzó ${host}:${port} desde ${net}"
  fi
}

echo "=== Prueba de segmentación de red — Blume (Seguridad) ==="
echo "Directorio: $ROOT"
echo ""

require_network "$EDGE_NET"
require_network "$APP_NET"
require_network "$DATA_NET"

echo "--- Escenario 1: zona DMZ (blume_edge) no alcanza capa de datos ---"
assert_blocked "$EDGE_NET" mysql 3306 \
  "DMZ → MySQL (business) bloqueado"
assert_blocked "$EDGE_NET" recordings-mysql 3306 \
  "DMZ → MySQL (recordings) bloqueado"
assert_blocked "$EDGE_NET" rabbitmq 5672 \
  "DMZ → RabbitMQ bloqueado"
assert_blocked "$EDGE_NET" postgres_activities 5432 \
  "DMZ → PostgreSQL bloqueado"
assert_blocked "$EDGE_NET" minio 9000 \
  "DMZ → MinIO bloqueado"

echo ""
echo "--- Escenario 2: capa de aplicación sin datos no alcanza BD/cola ---"
assert_blocked "$APP_NET" mysql 3306 \
  "App (sin data) → MySQL bloqueado"
assert_blocked "$APP_NET" rabbitmq 5672 \
  "App (sin data) → RabbitMQ bloqueado"

echo ""
echo "--- Escenario 3: servicios con rol app+data sí alcanzan datos ---"
if can_connect_multi mysql 3306 --network "$APP_NET" --network "$DATA_NET"; then
  log_pass "App+Data → MySQL permitido (simula microservicio con acceso legítimo)"
else
  log_fail "App+Data → MySQL — el microservicio no puede alcanzar la BD"
fi

if can_connect_multi rabbitmq 5672 --network "$APP_NET" --network "$DATA_NET"; then
  log_pass "App+Data → RabbitMQ permitido"
else
  log_fail "App+Data → RabbitMQ — el productor/consumidor no puede alcanzar la cola"
fi

echo ""
echo "--- Escenario 4: punto de entrada HTTP solo en DMZ ---"
assert_allowed "$EDGE_NET" traefik 80 \
  "DMZ → Traefik:80 permitido (único HTTP público del stack)"
assert_blocked "$EDGE_NET" blume-business-logic-ms 8082 \
  "DMZ → business-logic directo bloqueado (solo vía Traefik)"

echo ""
echo "--- Escenario 5: gateway enruta a aplicación (control funcional) ---"
if curl -sf --max-time 10 "http://localhost/health" >/dev/null 2>&1; then
  log_pass "Traefik enruta /health hacia record-service"
elif curl -sf --max-time 10 "http://localhost/api/v1/health" >/dev/null 2>&1; then
  log_pass "Traefik enruta API de recomendaciones"
else
  log_fail "Traefik no responde en localhost (¿stack levantado y healthy?)"
fi

echo ""
echo "=== Resumen: ${PASS} pass, ${FAIL} fail ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0
