#!/usr/bin/env bash
set -euo pipefail

CERT_DIR="$(dirname "$0")/ca"
mkdir -p "$CERT_DIR"

if [ -f "$CERT_DIR/blume-gateway.crt" ] && [ -f "$CERT_DIR/blume-gateway.key" ] && [ -f "$CERT_DIR/blume-internal-ca.crt" ]; then
  echo "Certificates already exist in $CERT_DIR — skipping generation."
  echo "Delete the ca/ folder and re-run to regenerate."
  exit 0
fi

echo "Generating Blume internal CA..."
openssl genrsa -out "$CERT_DIR/blume-internal-ca.key" 4096 2>/dev/null
openssl req -new -x509 -days 3650 \
  -key "$CERT_DIR/blume-internal-ca.key" \
  -out "$CERT_DIR/blume-internal-ca.crt" \
  -subj "/CN=Blume-Internal-CA/O=Blume/C=CO"

echo "Generating gateway key and certificate..."
openssl genrsa -out "$CERT_DIR/blume-gateway.key" 2048 2>/dev/null
openssl req -new \
  -key "$CERT_DIR/blume-gateway.key" \
  -out "$CERT_DIR/blume-gateway.csr" \
  -subj "/CN=localhost/O=Blume/C=CO"

openssl x509 -req -days 365 \
  -in "$CERT_DIR/blume-gateway.csr" \
  -CA "$CERT_DIR/blume-internal-ca.crt" \
  -CAkey "$CERT_DIR/blume-internal-ca.key" \
  -CAcreateserial \
  -out "$CERT_DIR/blume-gateway.crt" \
  -extfile <(printf "subjectAltName=DNS:localhost,DNS:traefik,IP:127.0.0.1\nbasicConstraints=CA:FALSE") \
  2>/dev/null

chmod 600 "$CERT_DIR/blume-internal-ca.key" "$CERT_DIR/blume-gateway.key"

echo "Done. Files written to $CERT_DIR:"
ls -1 "$CERT_DIR"
