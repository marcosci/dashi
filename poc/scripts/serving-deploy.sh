#!/usr/bin/env bash
# Deploy TiTiler + DuckDB endpoint to the dashi-serving namespace.
#
# Prereqs:
#   - k3d cluster 'dashi' running
#   - RustFS already deployed (secret dashi-platform/rustfs-root exists)
#
# Steps:
#   1. Build the duckdb-endpoint image locally and import it into k3d
#   2. Mirror the RustFS root credential into dashi-serving as rustfs-client
#      (client-side credential the serving layer uses — separate from the
#      rustfs-root SA credential, so it can be rotated independently later)
#   3. Apply TiTiler + duckdb-endpoint manifests

set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-dashi}"
DUCKDB_IMG="${DUCKDB_IMG:-dashi/duckdb-endpoint:dev}"
TITILER_IMG="${TITILER_IMG:-dashi/titiler-endpoint:dev}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "→ Building $DUCKDB_IMG"
docker build -t "$DUCKDB_IMG" "$REPO_ROOT/duckdb-endpoint"

echo "→ Building $TITILER_IMG"
docker build -t "$TITILER_IMG" "$REPO_ROOT/titiler-endpoint"

CTX="$(kubectl config current-context 2>/dev/null || echo "")"
if [[ "$CTX" == k3d-* ]]; then
  echo "→ Importing images into k3d cluster $CLUSTER_NAME"
  k3d image import "$DUCKDB_IMG" "$TITILER_IMG" -c "$CLUSTER_NAME"
else
  echo "→ Skipping k3d import (context=$CTX shares docker daemon, images visible directly)"
fi

echo "→ Ensuring dashi-serving namespace"
kubectl apply -f "$REPO_ROOT/manifests/titiler/namespace.yaml"

echo "→ Verifying per-zone RustFS credentials are present"
if ! kubectl -n dashi-serving get secret dashi-rustfs-serving >/dev/null 2>&1; then
  echo ""
  echo "ERROR: secret dashi-serving/dashi-rustfs-serving missing."
  echo "       Run: bash poc/scripts/rbac-bootstrap.sh"
  echo "       This creates the per-zone RustFS users + scoped K8s Secrets."
  exit 1
fi

echo "→ Applying TiTiler"
# Apply but skip re-creating the placeholder secret.yaml (we manage rustfs-client above)
kubectl apply -f "$REPO_ROOT/manifests/titiler/deployment.yaml"
kubectl apply -f "$REPO_ROOT/manifests/titiler/service.yaml"

echo "→ Applying duckdb-endpoint"
kubectl apply -k "$REPO_ROOT/manifests/duckdb-endpoint"

echo ""
echo "→ Waiting for TiTiler"
kubectl -n dashi-serving rollout status deployment/titiler --timeout=180s
echo "→ Waiting for duckdb-endpoint"
kubectl -n dashi-serving rollout status deployment/duckdb-endpoint --timeout=180s

echo ""
echo "✓ Serving layer ready in dashi-serving"
echo "  TiTiler         : svc/titiler:8080"
echo "  DuckDB SQL API  : svc/duckdb-endpoint:8080"
