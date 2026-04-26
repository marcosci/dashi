#!/usr/bin/env bash
# Build dashi/ingest-api + dashi/ingest-web, import into k3d, mirror the
# pipeline RustFS Secret into dashi-web, apply manifests.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER_NAME="${CLUSTER_NAME:-dashi}"

echo "→ build dashi/ingest-api:dev"
docker build -t dashi/ingest-api:dev -f "$REPO_ROOT/services/ingest-api/Dockerfile" "$REPO_ROOT"

echo "→ build dashi/ingest-web:dev"
docker build -t dashi/ingest-web:dev "$REPO_ROOT/web/ingest"

CTX="$(kubectl config current-context 2>/dev/null || echo "")"
if [[ "$CTX" == k3d-* ]]; then
  echo "→ k3d image import"
  k3d image import dashi/ingest-api:dev dashi/ingest-web:dev -c "$CLUSTER_NAME"
else
  echo "→ Skipping k3d import (context=$CTX shares docker daemon)"
fi

echo "→ apply ingest-api namespace + Deployment"
kubectl apply -k "$REPO_ROOT/manifests/ingest-api"

# Mirror the pipeline RustFS Secret so the api can mint presigned URLs.
echo "→ mirror dashi-rustfs-pipeline → dashi-web"
kubectl -n dashi-data get secret dashi-rustfs-pipeline -o yaml \
  | sed 's/namespace: dashi-data/namespace: dashi-web/' \
  | grep -v -E "^(  resourceVersion|  uid|  creationTimestamp|  ownerReferences):" \
  | kubectl apply -f -

echo "→ apply ingest-web Deployment"
kubectl apply -k "$REPO_ROOT/manifests/ingest-web"

echo "→ rollout"
kubectl -n dashi-web rollout restart deployment/ingest-api deployment/ingest-web
kubectl -n dashi-web rollout status deployment/ingest-api --timeout=180s
kubectl -n dashi-web rollout status deployment/ingest-web --timeout=120s

echo ""
echo "✓ web ingest stack live in dashi-web"
echo ""
echo "  Port-forward (PoC, mock-auth dev mode):"
echo "    kubectl -n dashi-web port-forward svc/ingest-web 5174:8080 &"
echo "    kubectl -n dashi-web port-forward svc/ingest-api 8088:8088 &"
echo ""
echo "  Then visit http://localhost:5174 — but the static UI calls /api/*"
echo "  on its own origin; for PoC use the dev server (npm run dev) which"
echo "  proxies /api/* to localhost:8088."
