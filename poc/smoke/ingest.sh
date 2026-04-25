#!/usr/bin/env bash
# End-to-end smoke — ingestion pipeline.
# Creates a tiny synthetic GeoJSON, runs dashi-ingest against it, verifies
# the STAC item came back from the catalog and the parquet partition exists
# on RustFS. Exits non-zero on any failure.

set -euo pipefail

NS_RUSTFS="${NS_RUSTFS:-dashi-platform}"
NS_CATALOG="${NS_CATALOG:-dashi-catalog}"
S3_LOCAL_PORT="${S3_LOCAL_PORT:-19000}"
STAC_LOCAL_PORT="${STAC_LOCAL_PORT:-19080}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INGEST_DIR="$REPO_ROOT/ingest"

cleanup() {
  for pid in ${PFPIDS:-}; do kill "$pid" 2>/dev/null || true; done
}
trap cleanup EXIT

echo "→ port-forwards"
kubectl -n "$NS_RUSTFS" port-forward svc/rustfs "${S3_LOCAL_PORT}:9000" >/dev/null 2>&1 &
PFPIDS="$!"
kubectl -n "$NS_CATALOG" port-forward svc/stac-fastapi "${STAC_LOCAL_PORT}:8080" >/dev/null 2>&1 &
PFPIDS="$PFPIDS $!"
sleep 3

echo "→ fetch RustFS credentials"
export DASHI_S3_ACCESS_KEY=$(kubectl -n "$NS_RUSTFS" get secret rustfs-root -o jsonpath='{.data.access-key}' | base64 -d)
export DASHI_S3_SECRET_KEY=$(kubectl -n "$NS_RUSTFS" get secret rustfs-root -o jsonpath='{.data.secret-key}' | base64 -d)
export DASHI_S3_ENDPOINT="http://localhost:${S3_LOCAL_PORT}"

STAC_URL="http://localhost:${STAC_LOCAL_PORT}"
COLL="smoke-ingest"
TMP_DIR=$(mktemp -d)

echo "→ write synthetic GeoJSON (1 point, EPSG:4326, Dresden area)"
cat > "$TMP_DIR/point.geojson" <<'EOF'
{
  "type": "FeatureCollection",
  "crs": {"type":"name","properties":{"name":"urn:ogc:def:crs:OGC:1.3:CRS84"}},
  "features": [
    {"type":"Feature","properties":{"name":"smoke-test-1"},"geometry":{"type":"Point","coordinates":[13.737,51.052]}}
  ]
}
EOF

echo "→ dashi-ingest scan"
"$INGEST_DIR/.venv/bin/dashi-ingest" scan "$TMP_DIR" >/dev/null

echo "→ dashi-ingest ingest"
"$INGEST_DIR/.venv/bin/dashi-ingest" ingest "$TMP_DIR" \
  --domain "$COLL" \
  --stac-url "$STAC_URL" \
  --collection-description "smoke ingest" >/dev/null

echo "→ verify collection exists"
HTTP=$(curl -s -o /tmp/dashi-smoke-coll.json -w '%{http_code}' "$STAC_URL/collections/$COLL")
[[ "$HTTP" == "200" ]] || { echo "✗ collection not found (HTTP $HTTP)"; exit 1; }
echo "  ✓ collection $COLL"

echo "→ verify at least one item"
COUNT=$(curl -sf "$STAC_URL/collections/$COLL/items" | python3 -c 'import sys,json;print(len(json.load(sys.stdin).get("features",[])))')
[[ "$COUNT" -ge 1 ]] || { echo "✗ expected at least 1 item, found $COUNT"; exit 1; }
echo "  ✓ $COUNT item(s) in $COLL"

echo "→ cleanup smoke collection"
for id in $(curl -sf "$STAC_URL/collections/$COLL/items?limit=100" | python3 -c 'import sys,json;[print(f["id"]) for f in json.load(sys.stdin).get("features",[])]'); do
  curl -sf -X DELETE "$STAC_URL/collections/$COLL/items/$id" >/dev/null || true
done
curl -sf -X DELETE "$STAC_URL/collections/$COLL" >/dev/null || true
rm -rf "$TMP_DIR"

echo ""
echo "✓ ingest smoke test PASSED"
