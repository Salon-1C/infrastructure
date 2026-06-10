#!/bin/bash
# Usage: ./add_node.sh <tailscale_ip>
# Example: ./add_node.sh 100.78.48.65

set -e

NODE_IP=$1

if [ -z "$NODE_IP" ]; then
  echo "Usage: $0 <tailscale_ip>"
  exit 1
fi

ENV_FILE=".env"
COMPOSE_FILE="docker-compose.yml"
DYNAMIC_FILE="traefik/dynamic.yml"

# ── 1. Add to CLUSTER_NODES in .env ──────────────────────────────────────
current_nodes=$(grep "^CLUSTER_NODES=" "$ENV_FILE" | cut -d= -f2)

if echo "$current_nodes" | grep -q "$NODE_IP"; then
  echo "Node $NODE_IP already in CLUSTER_NODES, skipping .env"
else
  new_nodes="${current_nodes},activities@${NODE_IP}"
  sed -i "s|^CLUSTER_NODES=.*|CLUSTER_NODES=${new_nodes}|" "$ENV_FILE"
  echo "✓ Updated CLUSTER_NODES in .env"
fi

# ── 2. Add Tailscale IP var to .env ──────────────────────────────────────
var_name="TAILSCALE_IP_$(echo "$NODE_IP" | tr '.' '_')"

if grep -q "^${var_name}=" "$ENV_FILE"; then
  echo "Var $var_name already in .env, skipping"
else
  echo "${var_name}=${NODE_IP}" >> "$ENV_FILE"
  echo "✓ Added ${var_name} to .env"
fi

# ── 3. Add backend to Traefik dynamic.yml ────────────────────────────────
backend_line="          - url: \"http://${NODE_IP}:4000\""

if grep -q "$NODE_IP" "$DYNAMIC_FILE"; then
  echo "Node $NODE_IP already in dynamic.yml, skipping"
else
  # Insert after the last existing activities server entry
  sed -i "/activities:/,/healthCheck:/{
    /- url:.*:4000/a\\
${backend_line}
  }" "$DYNAMIC_FILE"
  echo "✓ Added backend to dynamic.yml"
fi

echo ""
echo "Node $NODE_IP added. Next steps:"
echo "  1. Copy the repo to the new node and create its .env"
echo "  2. docker compose up --build -d blume_stream_activities_ms  (on new node)"
echo "  3. docker compose up --force-recreate blume_stream_activities_ms  (on laptop, to pick up new CLUSTER_NODES)"
echo "  Traefik will hot-reload dynamic.yml automatically."