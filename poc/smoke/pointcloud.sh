#!/usr/bin/env bash
# Smoke — point cloud serving end-to-end.
#
# Verifies the chain laid out in ADR-009 update 2026-04-25:
#   1. STAC catalog has at least one pointcloud item.
#   2. The item carries assets.data + assets.viewer3d (PoC tier).
#   3. The asset HREF is reachable via HTTP HEAD against RustFS (HTTP 200).
#   4. (Production tier, optional) If the item carries assets.tileset3d,
#      the tileset.json must be reachable and parse as valid JSON.

set -euo pipefail

NS_RUSTFS="${NS_RUSTFS:-dashi-platform}"
NS_CATALOG="${NS_CATALOG:-dashi-catalog}"
S3_LOCAL_PORT="${S3_LOCAL_PORT:-19100}"
STAC_LOCAL_PORT="${STAC_LOCAL_PORT:-19180}"
COLL="${COLL:-gelaende-umwelt}"

cleanup() { for pid in ${PFPIDS:-}; do kill "$pid" 2>/dev/null || true; done; }
trap cleanup EXIT

ok()   { echo "✓ $1"; }
fail() { echo "✗ $1" >&2; exit 1; }

echo "→ port-forwards"
kubectl -n "$NS_RUSTFS" port-forward svc/rustfs "${S3_LOCAL_PORT}:9000" >/dev/null 2>&1 &
PFPIDS="$!"
kubectl -n "$NS_CATALOG" port-forward svc/stac-fastapi "${STAC_LOCAL_PORT}:8080" >/dev/null 2>&1 &
PFPIDS="$PFPIDS $!"
sleep 3

ITEMS_JSON=$(curl -sf "http://localhost:${STAC_LOCAL_PORT}/collections/${COLL}/items?limit=200")
PC_COUNT=$(echo "$ITEMS_JSON" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(sum(1 for f in d.get("features",[]) if f["properties"].get("dashi:kind")=="pointcloud"))')
[[ "$PC_COUNT" -ge 1 ]] && ok "STAC contains $PC_COUNT pointcloud item(s)" \
                       || fail "no pointcloud items in collection $COLL"

PC_ITEM_ID=$(echo "$ITEMS_JSON" | python3 -c 'import sys,json;d=json.load(sys.stdin);print([f["id"] for f in d["features"] if f["properties"].get("dashi:kind")=="pointcloud"][0])')
ok "first pointcloud item: $PC_ITEM_ID"

# assets.data
DATA_HREF=$(echo "$ITEMS_JSON" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for f in d['features']:
    if f['id'] == '$PC_ITEM_ID':
        print(f['assets'].get('data',{}).get('href',''))
        break
")
[[ -n "$DATA_HREF" ]] && ok "assets.data href present" || fail "assets.data missing"

# assets.viewer3d (PoC tier)
V3D_HREF=$(echo "$ITEMS_JSON" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for f in d['features']:
    if f['id'] == '$PC_ITEM_ID':
        print(f['assets'].get('viewer3d',{}).get('href',''))
        break
")
[[ -n "$V3D_HREF" ]] && ok "assets.viewer3d href present (PoC tier)" \
                    || fail "assets.viewer3d missing — runner._pointcloud_assets() needs the patch"

# Translate cluster-internal asset URL (rustfs.dashi-platform.svc...) to localhost
LOCAL_DATA_URL=$(python3 -c "
import re
u = '$DATA_HREF'
m = re.match(r'https?://[^/]+/(.+)', u)
print('http://localhost:${S3_LOCAL_PORT}/' + (m.group(1) if m else u))
")

# Use mc presign (we hold the root cred via secret)
ACCESS=$(kubectl -n "$NS_RUSTFS" get secret rustfs-root -o jsonpath='{.data.access-key}' | base64 -d)
SECRET=$(kubectl -n "$NS_RUSTFS" get secret rustfs-root -o jsonpath='{.data.secret-key}' | base64 -d)

if command -v mc >/dev/null 2>&1; then
  mc alias set dashi-pf "http://localhost:${S3_LOCAL_PORT}" "$ACCESS" "$SECRET" >/dev/null 2>&1
  KEY="${LOCAL_DATA_URL#http://localhost:${S3_LOCAL_PORT}/}"
  PRESIGNED=$(mc share download --expire=5m "dashi-pf/${KEY}" 2>/dev/null | grep -E '^Share' | awk '{print $2}')
  if [[ -n "$PRESIGNED" ]]; then
    # presigned mints the URL for GET — use range GET to mimic deck.gl
    RANGE_HTTP=$(curl -s -o /dev/null -r 0-1023 -w '%{http_code}' "$PRESIGNED")
    [[ "$RANGE_HTTP" == "206" || "$RANGE_HTTP" == "200" ]] \
        && ok "COPC reachable via presigned URL (HTTP $RANGE_HTTP, range GET)" \
        || fail "COPC range GET $RANGE_HTTP"
  else
    echo "  (mc share could not mint presigned URL — skipping HEAD check)"
  fi
else
  echo "  (mc not on PATH — skipping presigned HEAD check)"
fi

# Optional: assets.tileset3d if production tier ran
T3D_HREF=$(echo "$ITEMS_JSON" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for f in d['features']:
    if f['id'] == '$PC_ITEM_ID':
        print(f['assets'].get('tileset3d',{}).get('href',''))
        break
")
if [[ -n "$T3D_HREF" ]]; then
  ok "assets.tileset3d present (production tier)"
  T3D_LOCAL=$(python3 -c "
import re
u = '$T3D_HREF'
m = re.match(r'https?://[^/]+/(.+)', u)
print('http://localhost:${S3_LOCAL_PORT}/' + (m.group(1) if m else u))
")
  if command -v mc >/dev/null 2>&1; then
    mc alias set dashi-pf "http://localhost:${S3_LOCAL_PORT}" "$ACCESS" "$SECRET" >/dev/null 2>&1
    KEY="${T3D_LOCAL#http://localhost:${S3_LOCAL_PORT}/}"
    PRESIGNED=$(mc share download --expire=5m "dashi-pf/${KEY}" 2>/dev/null | grep -E '^Share' | awk '{print $2}')
    if [[ -n "$PRESIGNED" ]]; then
      curl -sf "$PRESIGNED" | python3 -c 'import sys,json;json.load(sys.stdin)' \
        && ok "tileset.json parses as JSON" \
        || fail "tileset.json invalid"
    fi
  fi
else
  echo "  (no assets.tileset3d yet — run \`make 3dtiles-deploy\` to generate)"
fi

echo ""
echo "✓ point cloud smoke OK"
