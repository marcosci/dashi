#!/usr/bin/env bash
# Drop an oauth2-proxy in front of an existing Service. Use after
# scripts/auth-bootstrap.sh.
#
# Usage:
#   bash scripts/auth-protect.sh <namespace> <upstream-svc-name> <upstream-port>
#
# Example:
#   bash scripts/auth-protect.sh dashi-monitoring grafana 3000
set -euo pipefail

NS="${1:?usage: auth-protect.sh <ns> <svc> <port>}"
SVC="${2:?usage: auth-protect.sh <ns> <svc> <port>}"
PORT="${3:?usage: auth-protect.sh <ns> <svc> <port>}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "→ Generating per-RP secrets"
COOKIE_SECRET="$(python3 -c 'import secrets,base64;print(base64.urlsafe_b64encode(secrets.token_bytes(32)).decode().rstrip("="))')"
CLIENT_SECRET="$(python3 -c 'import secrets;print(secrets.token_urlsafe(48))')"

echo "→ Applying oauth2-proxy Secret in $NS"
kubectl -n "$NS" create secret generic oauth2-proxy \
  --from-literal=cookie-secret="$COOKIE_SECRET" \
  --from-literal=client-secret="$CLIENT_SECRET" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "→ Rendering oauth2-proxy Deployment for $NS / $SVC:$PORT"
sed \
  -e "s|namespace: dashi-monitoring|namespace: $NS|g" \
  -e "s|http://grafana.dashi-monitoring.svc.cluster.local:3000|http://${SVC}.${NS}.svc.cluster.local:${PORT}|g" \
  "$REPO_ROOT/manifests/auth/oauth2-proxy.yaml" \
  | kubectl apply -f -

kubectl -n "$NS" rollout status deployment/oauth2-proxy --timeout=120s

echo ""
echo "✓ oauth2-proxy live in $NS:4180 — front-door to $SVC:$PORT"
echo ""
echo "  Tell the upstream Authelia about the new client — append to"
echo "  manifests/auth/authelia-config.yaml under identity_providers.oidc.clients,"
echo "  rotate the BOOTSTRAP_ME client_secret with the value just generated:"
echo "    $CLIENT_SECRET"
echo "  then \`kubectl -n dashi-auth rollout restart deploy/authelia\`."
