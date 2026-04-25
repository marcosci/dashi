#!/usr/bin/env bash
# Smoke — Authelia OIDC issuer (forward-auth gateway mode).
# Verifies Authelia is up + responsive. Live OIDC RPs are out of scope
# for the PoC (need DNS + TLS + real RP config); auth-protect.sh layers
# them in once those are available.

set -euo pipefail

NS="${NS:-dashi-auth}"
PORT="${PORT:-19091}"

cleanup() { for pid in ${PFPIDS:-}; do kill "$pid" 2>/dev/null || true; done; }
trap cleanup EXIT

ok()   { echo "✓ $1"; }
fail() { echo "✗ $1" >&2; exit 1; }

if ! kubectl -n "$NS" get deploy authelia >/dev/null 2>&1; then
  echo "  (Authelia not deployed; skipping. Run: make auth-bootstrap)"
  exit 0
fi

READY=$(kubectl -n "$NS" get deploy authelia -o jsonpath='{.status.readyReplicas}')
[[ "$READY" -ge 1 ]] && ok "authelia deploy Ready ($READY replicas)" \
                     || fail "authelia deploy not Ready"

echo "→ port-forward svc/authelia"
kubectl -n "$NS" port-forward svc/authelia "${PORT}:9091" >/dev/null 2>&1 &
PFPIDS="$!"
sleep 3

HC=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${PORT}/api/health")
[[ "$HC" == "200" ]] && ok "authelia /api/health 200" || fail "/api/health $HC"

# OIDC discovery endpoint should 404 in PoC (issuer disabled until first
# RP is registered via auth-protect.sh).
DISC=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${PORT}/.well-known/openid-configuration")
echo "  OIDC discovery: HTTP $DISC (404 = issuer not yet registered, expected in PoC)"

echo ""
echo "✓ auth smoke PASSED"
