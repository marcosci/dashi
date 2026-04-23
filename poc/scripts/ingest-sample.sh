#!/usr/bin/env bash
# Run miso-ingest against poc/sample-data/ into the live cluster.
# Sets up temporary port-forwards, injects RustFS credentials from the
# cluster Secret, and invokes the CLI. Credentials never leave the shell.

set -euo pipefail

NS_RUSTFS="${NS_RUSTFS:-miso-platform}"
NS_CATALOG="${NS_CATALOG:-miso-catalog}"
S3_LOCAL_PORT="${S3_LOCAL_PORT:-19100}"
STAC_LOCAL_PORT="${STAC_LOCAL_PORT:-19180}"
DOMAIN="${DOMAIN:-gelaende-umwelt}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SAMPLE_DIR="${SAMPLE_DIR:-$REPO_ROOT/sample-data}"
INGEST_VENV="$REPO_ROOT/ingest/.venv"

if [[ ! -x "$INGEST_VENV/bin/miso-ingest" ]]; then
  echo "ERROR: miso-ingest venv not found. Run: (cd $REPO_ROOT/ingest && python3 -m venv .venv && .venv/bin/pip install -e .)"
  exit 1
fi
if [[ ! -d "$SAMPLE_DIR" ]]; then
  echo "ERROR: sample dir $SAMPLE_DIR not found"
  exit 1
fi

cleanup() { for pid in ${PFPIDS:-}; do kill "$pid" 2>/dev/null || true; done; }
trap cleanup EXIT

echo "→ port-forwards"
kubectl -n "$NS_RUSTFS" port-forward svc/rustfs "${S3_LOCAL_PORT}:9000" >/dev/null 2>&1 &
PFPIDS="$!"
kubectl -n "$NS_CATALOG" port-forward svc/stac-fastapi "${STAC_LOCAL_PORT}:8080" >/dev/null 2>&1 &
PFPIDS="$PFPIDS $!"
sleep 3

export MISO_S3_ACCESS_KEY=$(kubectl -n "$NS_RUSTFS" get secret rustfs-root -o jsonpath='{.data.access-key}' | base64 -d)
export MISO_S3_SECRET_KEY=$(kubectl -n "$NS_RUSTFS" get secret rustfs-root -o jsonpath='{.data.secret-key}' | base64 -d)
export MISO_S3_ENDPOINT="http://localhost:${S3_LOCAL_PORT}"

"$INGEST_VENV/bin/miso-ingest" ingest "$SAMPLE_DIR" \
  --domain "$DOMAIN" \
  --stac-url "http://localhost:${STAC_LOCAL_PORT}"
