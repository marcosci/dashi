#!/usr/bin/env bash
# Stand up the dashi-iceberg namespace + REST catalog. Mirrors the
# pipeline RustFS Secret so the catalog can stage table data into
# s3://curated/iceberg/. Idempotent — re-run after Secret rotation.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NS="dashi-iceberg"

echo "→ Apply $NS namespace"
kubectl apply -f "$REPO_ROOT/manifests/iceberg/namespace.yaml"

echo "→ Mirror dashi-rustfs-pipeline → $NS"
kubectl -n dashi-data get secret dashi-rustfs-pipeline -o yaml \
  | sed "s/namespace: dashi-data/namespace: $NS/" \
  | grep -v -E "^(  resourceVersion|  uid|  creationTimestamp|  ownerReferences):" \
  | kubectl apply -f -

echo "→ Apply Iceberg REST catalog"
kubectl apply -k "$REPO_ROOT/manifests/iceberg"

kubectl -n "$NS" rollout status deployment/iceberg-rest --timeout=180s

echo ""
echo "✓ Iceberg REST catalog live at svc/iceberg-rest.${NS}:8181"
echo ""
echo "  Port-forward:"
echo "    kubectl -n $NS port-forward svc/iceberg-rest 8181:8181"
echo "  Discovery:"
echo "    curl http://localhost:8181/v1/config"
echo "  Promote a curated parquet to Iceberg via Prefect:"
echo "    PREFECT_API_URL=... python -m dashi_ingest.flows.iceberg \\"
echo "      --table gelaende_umwelt.osm_roads --source s3://processed/.../vector/"
