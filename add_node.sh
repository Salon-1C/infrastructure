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
DYNAMIC_FILE="traefik/dynamic.yml"

# ── 1. Update CLUSTER_NODES in .env ──────────────────────────────────────
current_nodes=$(grep "^CLUSTER_NODES=" "$ENV_FILE" | cut -d= -f2)

if echo "$current_nodes" | grep -q "$NODE_IP"; then
  echo "Node $NODE_IP already in CLUSTER_NODES, skipping"
else
  new_nodes="${current_nodes},activities@${NODE_IP}"
  sed -i "s|^CLUSTER_NODES=.*|CLUSTER_NODES=${new_nodes}|" "$ENV_FILE"
  echo "✓ Updated CLUSTER_NODES in .env"
fi

# ── 2. Add Tailscale IP var to .env on its own line ───────────────────────
var_name="TAILSCALE_IP_$(echo "$NODE_IP" | tr '.' '_')"

if grep -q "^${var_name}=" "$ENV_FILE"; then
  echo "Var $var_name already in .env, skipping"
else
  printf "\n%s=%s" "$var_name" "$NODE_IP" >> "$ENV_FILE"
  echo "✓ Added ${var_name} to .env"
fi

# ── 3. Add backend to Traefik dynamic.yml ────────────────────────────────
if grep -q "\"http://${NODE_IP}:4000\"" "$DYNAMIC_FILE"; then
  echo "Node $NODE_IP already in dynamic.yml, skipping"
else
  # Find the line number of the last activities server entry and insert after it
  last_line=$(grep -n "url.*:4000" "$DYNAMIC_FILE" | tail -1 | cut -d: -f1)

  if [ -z "$last_line" ]; then
    echo "✗ Could not find activities servers block in dynamic.yml"
    exit 1
  fi

  new_line="          - url: \"http://${NODE_IP}:4000\""
  sed -i "${last_line}a\\
${new_line}" "$DYNAMIC_FILE"
  echo "✓ Added backend to dynamic.yml"
fi

echo ""
echo "Node ${NODE_IP} added. Next steps:"
echo "  1. Copy the repo to the new node and create its .env"
echo "  2. Run on new node:  docker compose up --build -d blume_stream_activities_ms"
echo "  3. Run on laptop:    docker compose up --force-recreate blume_stream_activities_ms"
echo "  Traefik will hot-reload dynamic.yml automatically."