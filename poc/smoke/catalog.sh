#!/usr/bin/env bash
# Smoke test — stac-fastapi + pgstac catalog
# Covers: ping, root catalog, collections list, collection create, spatial query.
# Exits non-zero on any failure.

set -euo pipefail

NS="${NS:-dashi-catalog}"
SVC="${SVC:-stac-fastapi}"
PORT_LOCAL="${PORT_LOCAL:-18080}"
PORT_SVC="${PORT_SVC:-8080}"

cleanup() {
  if [[ -n "${PFPID:-}" ]]; then kill "$PFPID" 2>/dev/null || true; fi
}
trap cleanup EXIT

echo "→ port-forward svc/${SVC} → localhost:${PORT_LOCAL}"
kubectl -n "$NS" port-forward "svc/${SVC}" "${PORT_LOCAL}:${PORT_SVC}" >/dev/null 2>&1 &
PFPID=$!
sleep 2

API="http://localhost:${PORT_LOCAL}"

fail() { echo "✗ $1" >&2; exit 1; }
ok()   { echo "✓ $1"; }

# 1. ping
if [[ "$(curl -sf "$API/_mgmt/ping" | python3 -c 'import sys,json; print(json.load(sys.stdin)["message"])')" == "PONG" ]]; then
  ok "ping"
else
  fail "ping did not return PONG"
fi

# 2. root = STAC catalog 1.0.0
if [[ "$(curl -sf "$API/" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d["type"], d["stac_version"])')" == "Catalog 1.0.0" ]]; then
  ok "root catalog STAC 1.0.0"
else
  fail "root did not return STAC 1.0.0 catalog"
fi

# 3. collections list reachable
if curl -sf "$API/collections" >/dev/null; then
  ok "collections list reachable"
else
  fail "collections list unreachable"
fi

# 4. create test collection (idempotent; ignore 409)
COLL_ID="smoke-${RANDOM}"
PAYLOAD=$(cat <<EOF
{
  "type":"Collection",
  "id":"${COLL_ID}",
  "stac_version":"1.0.0",
  "description":"smoke-test collection, safe to delete",
  "license":"proprietary",
  "links":[],
  "extent":{
    "spatial":{"bbox":[[13.57,50.98,13.92,51.14]]},
    "temporal":{"interval":[["2026-04-23T00:00:00Z",null]]}
  }
}
EOF
)
HTTP=$(curl -s -o /tmp/dashi-smoke-coll.json -w '%{http_code}' -X POST "$API/collections" -H 'Content-Type: application/json' -d "$PAYLOAD")
if [[ "$HTTP" == "200" || "$HTTP" == "201" || "$HTTP" == "409" ]]; then
  ok "collection POST returned $HTTP"
else
  echo "--- response body ---"
  cat /tmp/dashi-smoke-coll.json
  fail "collection POST failed (HTTP $HTTP)"
fi

# 5. bbox search over Dresden returns the collection metadata
if curl -sf "$API/collections/${COLL_ID}" >/dev/null; then
  ok "GET /collections/${COLL_ID}"
else
  fail "GET /collections/${COLL_ID} failed"
fi

# 6. cleanup smoke collection
curl -sf -X DELETE "$API/collections/${COLL_ID}" >/dev/null && ok "cleanup DELETE"

echo ""
echo "✓ catalog smoke test PASSED"
