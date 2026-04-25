#!/usr/bin/env bash
# Mint the dashi-serving/tipg-db Secret from the live serving-postgis root
# password and apply the TiPG manifests. Idempotent.
#
# Usage:  bash scripts/tipg-bootstrap.sh
set -euo pipefail

NS_DB="${NS_DB:-dashi-serving-db}"
NS_TIPG="${NS_TIPG:-dashi-serving}"
DB_NAME="${DB_NAME:-serving}"
DB_HOST="${DB_HOST:-serving-postgis.${NS_DB}.svc.cluster.local}"
DB_PORT="${DB_PORT:-5432}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "→ Fetching dashi_serving_ro password from $NS_DB/serving-postgis"
RO_PASS=$(kubectl -n "$NS_DB" get secret serving-postgis -o jsonpath='{.data.READONLY_PASSWORD}' 2>/dev/null | base64 -d || true)

if [[ -z "$RO_PASS" ]]; then
  echo "ERROR: secret $NS_DB/serving-postgis has no READONLY_PASSWORD key."
  echo "       Re-deploy serving-db with a populated secret first:"
  echo "         make ogc-deploy   # or scripts/apply-with-secret.sh manifests/serving-db ..."
  exit 1
fi

DB_URL="postgresql://dashi_serving_ro:${RO_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}"

echo "→ Ensuring namespace $NS_TIPG"
kubectl apply -f "$REPO_ROOT/manifests/tipg/namespace.yaml"

echo "→ Writing dashi-serving/tipg-db secret (stays only in cluster)"
kubectl -n "$NS_TIPG" create secret generic tipg-db \
  --from-literal=user=dashi_serving_ro \
  --from-literal=password="$RO_PASS" \
  --from-literal=url="$DB_URL" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "→ Applying TiPG Deployment + Service"
# Skip the placeholder secret.yaml (we just wrote the real one).
kubectl apply -f "$REPO_ROOT/manifests/tipg/deployment.yaml"
kubectl apply -f "$REPO_ROOT/manifests/tipg/service.yaml"

kubectl -n "$NS_TIPG" rollout status deployment/tipg --timeout=180s

echo ""
echo "✓ TiPG deployed. Port-forward with:"
echo "  kubectl -n $NS_TIPG port-forward svc/tipg 8081:8081"
echo ""
echo "Endpoints once forwarded:"
echo "  curl http://localhost:8081/healthz"
echo "  curl http://localhost:8081/collections"
echo "  curl 'http://localhost:8081/collections/<id>/items?f=geojson&limit=10'"
