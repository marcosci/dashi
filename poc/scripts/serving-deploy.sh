#!/usr/bin/env bash
# Deploy TiTiler + DuckDB endpoint to the miso-serving namespace.
#
# Prereqs:
#   - k3d cluster 'miso' running
#   - RustFS already deployed (secret miso-platform/rustfs-root exists)
#
# Steps:
#   1. Build the duckdb-endpoint image locally and import it into k3d
#   2. Mirror the RustFS root credential into miso-serving as rustfs-client
#      (client-side credential the serving layer uses — separate from the
#      rustfs-root SA credential, so it can be rotated independently later)
#   3. Apply TiTiler + duckdb-endpoint manifests

set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-miso}"
DUCKDB_IMG="${DUCKDB_IMG:-miso/duckdb-endpoint:dev}"
TITILER_IMG="${TITILER_IMG:-miso/titiler-endpoint:dev}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "→ Building $DUCKDB_IMG"
docker build -t "$DUCKDB_IMG" "$REPO_ROOT/duckdb-endpoint"

echo "→ Building $TITILER_IMG"
docker build -t "$TITILER_IMG" "$REPO_ROOT/titiler-endpoint"

echo "→ Importing images into k3d cluster $CLUSTER_NAME"
k3d image import "$DUCKDB_IMG" "$TITILER_IMG" -c "$CLUSTER_NAME"

echo "→ Ensuring miso-serving namespace"
kubectl apply -f "$REPO_ROOT/manifests/titiler/namespace.yaml"

echo "→ Mirroring RustFS root credential into miso-serving as rustfs-client"
ACCESS=$(kubectl -n miso-platform get secret rustfs-root -o jsonpath='{.data.access-key}' | base64 -d)
SECRET=$(kubectl -n miso-platform get secret rustfs-root -o jsonpath='{.data.secret-key}' | base64 -d)
kubectl -n miso-serving create secret generic rustfs-client \
  --from-literal=access-key="$ACCESS" \
  --from-literal=secret-key="$SECRET" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "→ Applying TiTiler"
# Apply but skip re-creating the placeholder secret.yaml (we manage rustfs-client above)
kubectl apply -f "$REPO_ROOT/manifests/titiler/deployment.yaml"
kubectl apply -f "$REPO_ROOT/manifests/titiler/service.yaml"

echo "→ Applying duckdb-endpoint"
kubectl apply -k "$REPO_ROOT/manifests/duckdb-endpoint"

echo ""
echo "→ Waiting for TiTiler"
kubectl -n miso-serving rollout status deployment/titiler --timeout=180s
echo "→ Waiting for duckdb-endpoint"
kubectl -n miso-serving rollout status deployment/duckdb-endpoint --timeout=180s

echo ""
echo "✓ Serving layer ready in miso-serving"
echo "  TiTiler         : svc/titiler:8080"
echo "  DuckDB SQL API  : svc/duckdb-endpoint:8080"
