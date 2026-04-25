#!/usr/bin/env bash
# Smoke test — serving layer (TiTiler + DuckDB SQL endpoint).
# Requires: cluster running, rustfs + stac-fastapi live, ingested items present.

set -euo pipefail

NS_SERVING="${NS_SERVING:-dashi-serving}"
NS_CATALOG="${NS_CATALOG:-dashi-catalog}"
TITILER_PORT="${TITILER_PORT:-18090}"
DUCKDB_PORT="${DUCKDB_PORT:-18091}"
STAC_PORT="${STAC_PORT:-18080}"

cleanup() { for pid in ${PFPIDS:-}; do kill "$pid" 2>/dev/null || true; done; }
trap cleanup EXIT

echo "→ port-forwards"
kubectl -n "$NS_SERVING" port-forward svc/titiler "${TITILER_PORT}:8080" >/dev/null 2>&1 &
PFPIDS="$!"
kubectl -n "$NS_SERVING" port-forward svc/duckdb-endpoint "${DUCKDB_PORT}:8080" >/dev/null 2>&1 &
PFPIDS="$PFPIDS $!"
kubectl -n "$NS_CATALOG" port-forward svc/stac-fastapi "${STAC_PORT}:8080" >/dev/null 2>&1 &
PFPIDS="$PFPIDS $!"
sleep 3

ok()   { echo "✓ $1"; }
fail() { echo "✗ $1" >&2; exit 1; }

# 1. pings
[[ "$(curl -sf http://localhost:${TITILER_PORT}/_mgmt/ping | python3 -c 'import sys,json;print(json.load(sys.stdin)["message"])')" == "PONG" ]] && ok "titiler ping" || fail "titiler ping"
[[ "$(curl -sf http://localhost:${DUCKDB_PORT}/_mgmt/ping | python3 -c 'import sys,json;print(json.load(sys.stdin)["message"])')" == "PONG" ]] && ok "duckdb ping"  || fail "duckdb ping"

# 2. fetch a raster STAC item, use its s3:// URL for TiTiler
RASTER_URL=$(curl -sf "http://localhost:${STAC_PORT}/search?limit=50" | python3 -c "
import sys,json
for f in json.load(sys.stdin).get('features',[]):
    if f['properties'].get('dashi:kind') == 'raster':
        a = f['assets'].get('data')
        if a and a.get('href','').endswith('.tif'):
            print(a['href']); break
")
[[ -n "${RASTER_URL}" ]] || fail "no raster item in catalog for TiTiler test"
# Replace the user-facing http://localhost:9000 with the cluster-internal s3://
INTERNAL_URL=$(echo "$RASTER_URL" | sed -E 's|https?://[^/]+/||; s|^|s3://|')
ok "raster asset: $INTERNAL_URL"

INFO_HTTP=$(curl -s -o /tmp/dashi-smoke-info.json -w '%{http_code}' "http://localhost:${TITILER_PORT}/cog/info?url=${INTERNAL_URL}")
[[ "$INFO_HTTP" == "200" ]] || { cat /tmp/dashi-smoke-info.json; fail "titiler /cog/info returned $INFO_HTTP"; }
ok "titiler /cog/info returned 200"

# 3. DuckDB SELECT
HTTP=$(curl -s -o /tmp/dashi-smoke-q.json -w '%{http_code}' -X POST "http://localhost:${DUCKDB_PORT}/query" -H 'Content-Type: application/json' -d '{"sql":"SELECT 1 AS one"}')
[[ "$HTTP" == "200" ]] || fail "duckdb /query returned $HTTP"
ok "duckdb SELECT 1"

# 4. DuckDB spatial — count vector features
SQL='SELECT COUNT(*) AS n FROM read_parquet(['\''s3://processed/gelaende-umwelt/**/vector/**/*.parquet'\''])'
COUNT=$(curl -sf -X POST "http://localhost:${DUCKDB_PORT}/query" -H 'Content-Type: application/json' -d "{\"sql\":\"${SQL}\"}" | python3 -c 'import sys,json;print(json.load(sys.stdin)["rows"][0]["n"])')
[[ "$COUNT" -gt 0 ]] || fail "expected vector features, got $COUNT"
ok "duckdb counted $COUNT vector features across processed/"

# 5. DuckDB spatial-filter
SQL2='SELECT COUNT(*) AS near FROM read_parquet(['\''s3://processed/gelaende-umwelt/**/vector/**/*.parquet'\'']) WHERE ST_Intersects(geometry, ST_MakeEnvelope(13.73, 51.04, 13.76, 51.06))'
NEAR=$(curl -sf -X POST "http://localhost:${DUCKDB_PORT}/query" -H 'Content-Type: application/json' -d "{\"sql\":\"${SQL2}\"}" | python3 -c 'import sys,json;print(json.load(sys.stdin)["rows"][0]["near"])')
[[ "$NEAR" -gt 0 ]] || fail "expected features near Frauenkirche bbox, got $NEAR"
ok "duckdb ST_Intersects bbox returned $NEAR features"

# 6. DuckDB write-denial (security guard)
HTTP=$(curl -s -o /dev/null -w '%{http_code}' -X POST "http://localhost:${DUCKDB_PORT}/query" -H 'Content-Type: application/json' -d '{"sql":"CREATE TABLE t(x int)"}')
[[ "$HTTP" == "400" ]] || fail "write should be blocked; got $HTTP"
ok "duckdb DDL blocked ($HTTP)"

echo ""
echo "✓ serving smoke test PASSED"
