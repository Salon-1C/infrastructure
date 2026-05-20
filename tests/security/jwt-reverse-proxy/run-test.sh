#!/usr/bin/env bash
# Security tests — Scenario 2 (Reverse Proxy) & Scenario 4 (JWT)
#
# Usage:
#   bash run-test.sh
#
# Requirements:
#   - nc (netcat), curl
#   - Blume stack running: cd infrastructure && docker compose up -d
#   - System accessible at https://localhost

set -euo pipefail

BASE="https://localhost"
PASS=0
FAIL=0

check() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$actual" = "$expected" ]; then
        echo "  PASS: $desc (got: $actual)"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (expected: $expected, got: $actual)"
        FAIL=$((FAIL + 1))
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
echo "══════════════════════════════════════════════════════"
echo " SCENARIO 2: Reverse Proxy Pattern"
echo "══════════════════════════════════════════════════════"
echo ""
echo "  [2.1] Internal microservice ports must NOT be reachable from host"
for port in 8082 8080 8081 8000 4000 8888; do
    result=$(nc -z -w1 localhost "$port" 2>/dev/null && echo "open" || echo "closed")
    check "Port $port (internal service) not exposed on host" "closed" "$result"
done

echo ""
echo "  [2.2] Traefik admin dashboard must be disabled"
admin_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 \
    http://localhost:8080/api/rawdata 2>/dev/null || echo "000")
check "Traefik admin API inaccessible (:8080)" "000" "$admin_code"

echo ""
echo "  [2.3] Traffic must route successfully through Traefik (:443)"
# A POST to /api/auth/login with invalid credentials returns 401, not connection refused
http_code=$(curl -k -s -o /dev/null -w "%{http_code}" \
    -X POST "$BASE/api/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"email":"probe@test.com","password":"wrongpassword"}')
check "Requests route through Traefik (not connection refused)" "401" "$http_code"

echo ""
echo "  [2.4] No internal address or port appears in response headers"
headers=$(curl -k -s -D - -o /dev/null "$BASE/" 2>/dev/null)
if echo "$headers" | grep -qE ":(8082|8080|8081|8000|4000|8888)"; then
    check "Internal ports not leaked in response headers" "clean" "LEAKED"
else
    check "Internal ports not leaked in response headers" "clean" "clean"
fi

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════"
echo " SCENARIO 4: JWT Token-based Authentication Pattern"
echo "══════════════════════════════════════════════════════"
echo ""
echo "  [4.1] REST layer — request without token must be rejected"
code=$(curl -k -s -o /dev/null -w "%{http_code}" "$BASE/api/channels")
check "No token → 403 Forbidden" "403" "$code"

echo ""
echo "  [4.2] REST layer — forged token (invalid signature) must be rejected"
FAKE_TOKEN="eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJoYWNrZXJAZXZpbC5jb20iLCJ1c2VySWQiOiI5OTkiLCJyb2xlQ29kZSI6IlBST0ZFU1NPUiIsInVzZXJuYW1lIjoiaGFja2VyIn0.INVALIDSIGNATURE"
code=$(curl -k -s -o /dev/null -w "%{http_code}" \
    -H "Cookie: blume_session=$FAKE_TOKEN" \
    "$BASE/api/channels")
check "Forged token (wrong signature) → 403 Forbidden" "403" "$code"

echo ""
echo "  [4.3] Streaming layer (Go) — publish without token must be rejected"
code=$(curl -k -s -o /dev/null -w "%{http_code}" \
    -X POST "$BASE/auth/mediamtx" \
    -H "Content-Type: application/json" \
    -d '{"action":"publish","path":"/live/stream-key","query":"","ip":"1.2.3.4"}')
check "Publish without token → 401 Unauthorized" "401" "$code"

echo ""
echo "  [4.4] Streaming layer (Go) — student token publishing must be forbidden"
# JWT with roleCode=STUDENT signed with wrong secret (simulates a student trying publish)
STUDENT_FAKE="eyJhbGciOiJIUzI1NiJ9.eyJyb2xlQ29kZSI6IlNUVURFTlQiLCJ1c2VySWQiOiIxMjMifQ.BADSIG"
code=$(curl -k -s -o /dev/null -w "%{http_code}" \
    -X POST "$BASE/auth/mediamtx" \
    -H "Content-Type: application/json" \
    -d "{\"action\":\"publish\",\"path\":\"/live/key\",\"query\":\"token=$STUDENT_FAKE\",\"ip\":\"1.2.3.4\"}")
check "Student publish attempt (invalid token) → 401 Unauthorized" "401" "$code"

echo ""
echo "  [4.5] REST layer — tampered payload must be rejected (integrity check)"
# Header + modified payload (roleCode=PROFESSOR) + original signature from a different payload
# Any change to the payload invalidates the HMAC signature
TAMPERED="eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJzdHVkZW50QHRlc3QuY29tIiwicm9sZUNvZGUiOiJQUk9GRVNTT1IifQ.ORIGINALSIGNATUREFROMOTHERTOKEN"
code=$(curl -k -s -o /dev/null -w "%{http_code}" \
    -H "Cookie: blume_session=$TAMPERED" \
    "$BASE/api/channels")
check "Tampered JWT payload → 403 Forbidden" "403" "$code"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════"
TOTAL=$((PASS + FAIL))
echo " Results: $PASS/$TOTAL PASS  |  $FAIL FAIL"
echo "══════════════════════════════════════════════════════"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
