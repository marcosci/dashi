#!/usr/bin/env bash
# Phase-2 Strang J smoke — Martin vector tile server backed by PMTiles.

set -euo pipefail

NS="${NS:-miso-serving}"
PORT="${PORT:-19130}"

cleanup() { for pid in ${PFPIDS:-}; do kill "$pid" 2>/dev/null || true; done; }
trap cleanup EXIT

echo "→ port-forward svc/martin"
kubectl -n "$NS" port-forward svc/martin "${PORT}:3000" >/dev/null 2>&1 &
PFPIDS="$!"
sleep 4

ok()   { echo "✓ $1"; }
fail() { echo "✗ $1" >&2; exit 1; }

# 1. Health
HC=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${PORT}/health")
[[ "$HC" == "200" ]] && ok "martin /health 200" || fail "/health $HC"

# 2. Catalog lists 6 sources
SRC_COUNT=$(curl -sf "http://localhost:${PORT}/catalog" | python3 -c 'import sys,json;print(len(json.load(sys.stdin)["tiles"]))')
[[ "$SRC_COUNT" -ge 6 ]] && ok "$SRC_COUNT tile sources in catalog" || fail "expected >=6 sources, got $SRC_COUNT"

# 3. TileJSON for a known source
TJ=$(curl -sf "http://localhost:${PORT}/osm_roads")
echo "$TJ" | python3 -c 'import sys,json;d=json.load(sys.stdin);assert d["tilejson"]=="3.0.0";assert "vector_layers" in d;print("ok")' >/dev/null \
  && ok "osm_roads tilejson 3.0.0 with vector_layers" || fail "tilejson invalid"

# 4. Real tile in Dresden bbox at z=10 (z=12 dropped by tippecanoe density filter)
TILE_HTTP=$(curl -s -o /tmp/martin-tile.mvt -w '%{http_code}' "http://localhost:${PORT}/osm_roads/10/551/342")
TILE_SIZE=$(stat -f%z /tmp/martin-tile.mvt 2>/dev/null || stat -c%s /tmp/martin-tile.mvt)
[[ "$TILE_HTTP" == "200" && "$TILE_SIZE" -gt 1000 ]] \
  && ok "z=10 Dresden tile served ($TILE_SIZE bytes)" \
  || fail "z=10 tile bad (http=$TILE_HTTP size=$TILE_SIZE)"

# 5. Empty-tile semantics: tile outside Dresden bbox returns 204
EMPTY=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${PORT}/osm_roads/10/100/100")
[[ "$EMPTY" == "204" ]] && ok "out-of-bounds tile returns 204" || fail "expected 204 for out-of-bounds, got $EMPTY"

# 6. All 6 layers reachable at /<source>
for layer in osm_roads osm_buildings osm_landuse osm_water osm_railways mgrs_grids; do
  CODE=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${PORT}/${layer}")
  [[ "$CODE" == "200" ]] || fail "tilejson for $layer returned $CODE"
done
ok "tilejson available for all 6 layers"

echo ""
echo "✓ martin smoke PASSED"
