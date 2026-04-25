#!/usr/bin/env bash
# Smoke test — Prefect orchestration.
# Boots local port-forwards, runs the dashi-ingest flow against a tiny
# synthetic input, and verifies the flow+tasks completed in the Prefect API.

set -euo pipefail

NS_PLATFORM="${NS_PLATFORM:-dashi-platform}"
NS_CATALOG="${NS_CATALOG:-dashi-catalog}"
NS_DATA="${NS_DATA:-dashi-data}"
S3_PORT="${S3_PORT:-19200}"
STAC_PORT="${STAC_PORT:-19280}"
PREFECT_PORT="${PREFECT_PORT:-19242}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INGEST_VENV="$REPO_ROOT/ingest/.venv"

if [[ ! -x "$INGEST_VENV/bin/python" ]]; then
  echo "ERROR: ingest venv not found at $INGEST_VENV — run (cd ingest && python3 -m venv .venv && .venv/bin/pip install -e . 'prefect>=3.1,<4')"
  exit 1
fi

cleanup() { for pid in ${PFPIDS:-}; do kill "$pid" 2>/dev/null || true; done; rm -rf "${TMP_DIR:-}" || true; }
trap cleanup EXIT

echo "→ port-forwards"
kubectl -n "$NS_PLATFORM" port-forward svc/rustfs         "${S3_PORT}:9000"      >/dev/null 2>&1 &
PFPIDS="$!"
kubectl -n "$NS_CATALOG"  port-forward svc/stac-fastapi   "${STAC_PORT}:8080"    >/dev/null 2>&1 &
PFPIDS="$PFPIDS $!"
kubectl -n "$NS_DATA"     port-forward svc/prefect-server "${PREFECT_PORT}:4200" >/dev/null 2>&1 &
PFPIDS="$PFPIDS $!"
sleep 4

export DASHI_S3_ACCESS_KEY=$(kubectl -n "$NS_PLATFORM" get secret rustfs-root -o jsonpath='{.data.access-key}' | base64 -d)
export DASHI_S3_SECRET_KEY=$(kubectl -n "$NS_PLATFORM" get secret rustfs-root -o jsonpath='{.data.secret-key}' | base64 -d)
export DASHI_S3_ENDPOINT="http://localhost:${S3_PORT}"
export DASHI_STAC_URL="http://localhost:${STAC_PORT}"
export PREFECT_API_URL="http://localhost:${PREFECT_PORT}/api"

ok()   { echo "✓ $1"; }
fail() { echo "✗ $1" >&2; exit 1; }

# 1. Prefect API reachable
[[ "$(curl -sf http://localhost:${PREFECT_PORT}/api/health)" == "true" ]] && ok "prefect API reachable" || fail "prefect API not reachable"

# 2. Create synthetic input
TMP_DIR=$(mktemp -d)
cat > "$TMP_DIR/smoke.geojson" <<EOF
{"type":"FeatureCollection","crs":{"type":"name","properties":{"name":"urn:ogc:def:crs:OGC:1.3:CRS84"}},
 "features":[{"type":"Feature","properties":{"n":"a"},"geometry":{"type":"Point","coordinates":[13.737,51.052]}}]}
EOF

# 3. Run the flow locally against the cluster's Prefect server
BEFORE=$(curl -sf -X POST "http://localhost:${PREFECT_PORT}/api/flow_runs/filter" -H 'Content-Type: application/json' -d '{}' | python3 -c 'import sys,json;print(len(json.load(sys.stdin)))')
cd "$REPO_ROOT"
PYTHONPATH=. "$INGEST_VENV/bin/python" - <<PYEOF
from flows.ingest import ingest_flow
results = ingest_flow("$TMP_DIR", domain="smoke-prefect")
ok = sum(1 for r in results if r["status"] == "ingested")
assert ok >= 1, f"expected >=1 ingested, got {results!r}"
print(f"[smoke.py] ingested {ok} item(s)")
PYEOF

# 4. Verify one more flow run appeared and completed
AFTER=$(curl -sf -X POST "http://localhost:${PREFECT_PORT}/api/flow_runs/filter" -H 'Content-Type: application/json' -d '{}' | python3 -c 'import sys,json;print(len(json.load(sys.stdin)))')
[[ "$AFTER" -gt "$BEFORE" ]] || fail "no new flow run registered (before=$BEFORE after=$AFTER)"
ok "prefect flow run registered ($((AFTER - BEFORE)) new)"

LAST_STATE=$(curl -sf -X POST "http://localhost:${PREFECT_PORT}/api/flow_runs/filter" -H 'Content-Type: application/json' \
  -d '{"sort":"START_TIME_DESC","limit":1}' | python3 -c 'import sys,json;print(json.load(sys.stdin)[0]["state"]["type"])')
[[ "$LAST_STATE" == "COMPLETED" ]] || fail "latest flow run state=$LAST_STATE (expected COMPLETED)"
ok "latest flow run COMPLETED"

# 5. Cleanup: delete the smoke-prefect collection
curl -sf -X DELETE "${DASHI_STAC_URL}/collections/smoke-prefect" >/dev/null 2>&1 || true
ok "cleanup"

echo ""
echo "✓ prefect smoke test PASSED"
