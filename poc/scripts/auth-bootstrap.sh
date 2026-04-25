#!/usr/bin/env bash
# Stand up the dashi-auth namespace: Authelia (OIDC issuer) + a Secret of
# generated session/storage/oidc keys. After this, run
# auth-protect.sh <ns> <upstream-svc> for each UI you want behind SSO.
#
# Status: scaffolded. The Authelia config in authelia-config.yaml is a
# template; replace user passwords + OIDC client secrets via this script's
# generated authelia-secrets Secret.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NS_AUTH="dashi-auth"

echo "→ Applying $NS_AUTH manifests"
kubectl apply -k "$REPO_ROOT/manifests/auth"

# --- Generate the per-deployment secrets if they don't exist yet ---
if ! kubectl -n "$NS_AUTH" get secret authelia-secrets >/dev/null 2>&1; then
  echo "→ Generating authelia-secrets (jwt + session + storage + oidc-hmac)"
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  openssl rand -hex 64 > "$TMP/jwt"
  openssl rand -hex 64 > "$TMP/session"
  openssl rand -hex 32 > "$TMP/storage"
  openssl rand -hex 64 > "$TMP/oidc-hmac"

  kubectl -n "$NS_AUTH" create secret generic authelia-secrets \
    --from-file=jwt="$TMP/jwt" \
    --from-file=session="$TMP/session" \
    --from-file=storage="$TMP/storage" \
    --from-file=oidc-hmac="$TMP/oidc-hmac" \
    --dry-run=client -o yaml | kubectl apply -f -
fi

echo "→ Waiting for authelia rollout"
kubectl -n "$NS_AUTH" rollout status deployment/authelia --timeout=180s

echo ""
echo "✓ Authelia live at svc/authelia.${NS_AUTH}:9091"
echo ""
echo "  ⚠  Production hardening before any non-PoC use:"
echo "     - replace the bootstrap admin password in authelia-config.yaml/users.yml"
echo "       (gen with:  authelia hash-password)"
echo "     - replace the BOOTSTRAP_ME OIDC client_secret per RP"
echo "     - point the cookies.domain at a real DNS name + serve over TLS"
echo ""
echo "Next: protect a UI (Grafana shown):"
echo "  bash scripts/auth-protect.sh dashi-monitoring grafana 3000"
