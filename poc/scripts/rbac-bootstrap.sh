#!/usr/bin/env bash
# Strang H1 — per-zone RustFS identity + K8s Secret fan-out.
#
# Creates three RustFS IAM users with bucket-scoped policies and mirrors
# their access/secret keys into the appropriate K8s namespaces so the
# workloads consume a least-privilege credential instead of the shared
# rustfs-root key.
#
# | RustFS user          | Policy                                | K8s namespace(s) |
# |----------------------|---------------------------------------|------------------|
# | dashi-ingest         | landing/* read+write                  | miso-data (external producers — PoC: nobody yet) |
# | dashi-pipeline       | landing/* RO + processed/* + curated/* RW | miso-data (Prefect flow jobs)            |
# | dashi-serving-reader | processed/* + curated/* read-only     | miso-serving (TiTiler, DuckDB endpoint) |
#
# Idempotent. Safe to rerun — re-creating a user rotates its keys and
# refreshes the downstream Secret.

set -euo pipefail

NS_PLATFORM="${NS_PLATFORM:-miso-platform}"
S3_PORT="${S3_PORT:-19300}"
POLICY_DIR="${POLICY_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../manifests/rustfs/policies" && pwd)}"

cleanup() { for pid in ${PFPIDS:-}; do kill "$pid" 2>/dev/null || true; done; }
trap cleanup EXIT

if ! command -v mc >/dev/null 2>&1; then
  echo "ERROR: mc (MinIO client) not on PATH. brew install minio/stable/mc"
  exit 1
fi

echo "→ port-forward RustFS admin"
kubectl -n "$NS_PLATFORM" port-forward svc/rustfs "${S3_PORT}:9000" >/dev/null 2>&1 &
PFPIDS="$!"
sleep 3

ROOT_ACCESS=$(kubectl -n "$NS_PLATFORM" get secret rustfs-root -o jsonpath='{.data.access-key}' | base64 -d)
ROOT_SECRET=$(kubectl -n "$NS_PLATFORM" get secret rustfs-root -o jsonpath='{.data.secret-key}' | base64 -d)
mc alias set dashi-root "http://localhost:${S3_PORT}" "$ROOT_ACCESS" "$ROOT_SECRET" >/dev/null

# Ensure the three policies exist (idempotent)
for policy in dashi-ingest dashi-pipeline dashi-serving-reader; do
  echo "→ policy: $policy"
  mc admin policy create dashi-root "$policy" "$POLICY_DIR/${policy}.json" >/dev/null 2>&1 || \
    mc admin policy create dashi-root "$policy" "$POLICY_DIR/${policy}.json"
done

create_user_and_secret() {
  local user="$1"
  local policy="$2"
  local namespace="$3"
  local secret_name="$4"

  # Rotate: drop existing user if present, then re-create with fresh key
  mc admin user remove dashi-root "$user" >/dev/null 2>&1 || true

  local secret_key
  secret_key=$(openssl rand -base64 32 | tr -d '=+/' | cut -c1-40)
  mc admin user add dashi-root "$user" "$secret_key" >/dev/null
  mc admin policy attach dashi-root "$policy" --user "$user" >/dev/null

  echo "→ user $user (policy: $policy) mirrored into ${namespace}/${secret_name}"
  kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  kubectl -n "$namespace" create secret generic "$secret_name" \
    --from-literal=access-key="$user" \
    --from-literal=secret-key="$secret_key" \
    --from-literal=endpoint="http://rustfs.${NS_PLATFORM}.svc.cluster.local:9000" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null
}

create_user_and_secret dashi-pipeline       dashi-pipeline       miso-data    dashi-rustfs-pipeline
create_user_and_secret dashi-serving-reader dashi-serving-reader miso-serving dashi-rustfs-serving
create_user_and_secret dashi-ingest         dashi-ingest         miso-data    dashi-rustfs-ingest

echo ""
echo "✓ per-zone RustFS identity bootstrap complete"
echo ""
mc admin user list dashi-root
