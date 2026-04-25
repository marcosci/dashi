#!/usr/bin/env bash
# Mint a presigned URL for the first pointcloud STAC item and print it
# in a copy-paste-friendly form for docs/viewer/pointcloud.html.
#
# Usage:
#   make pointcloud-presign
#   ITEM_ID=<id> make pointcloud-presign      # specific item
#   EXPIRE=4h    make pointcloud-presign      # custom expiry (default 1h)
#   PORT=19100   make pointcloud-presign      # local port-forward port

set -euo pipefail

NS_RUSTFS="${NS_RUSTFS:-dashi-platform}"
NS_CATALOG="${NS_CATALOG:-dashi-catalog}"
PORT="${PORT:-19100}"
STAC_PORT="${STAC_PORT:-19181}"
COLL="${COLL:-gelaende-umwelt}"
EXPIRE="${EXPIRE:-1h}"

cleanup() { for pid in ${PFPIDS:-}; do kill "$pid" 2>/dev/null || true; done; }
trap cleanup EXIT

if ! command -v mc >/dev/null 2>&1; then
  echo "ERROR: mc not on PATH (brew install minio/stable/mc)" >&2
  exit 1
fi

kubectl -n "$NS_RUSTFS" port-forward svc/rustfs "${PORT}:9000" >/dev/null 2>&1 &
PFPIDS="$!"
kubectl -n "$NS_CATALOG" port-forward svc/stac-fastapi "${STAC_PORT}:8080" >/dev/null 2>&1 &
PFPIDS="$PFPIDS $!"
sleep 3

ACCESS=$(kubectl -n "$NS_RUSTFS" get secret rustfs-root -o jsonpath='{.data.access-key}' | base64 -d)
SECRET=$(kubectl -n "$NS_RUSTFS" get secret rustfs-root -o jsonpath='{.data.secret-key}' | base64 -d)
mc alias set dashi-pf "http://localhost:${PORT}" "$ACCESS" "$SECRET" >/dev/null

ITEMS_JSON=$(curl -sf "http://localhost:${STAC_PORT}/collections/${COLL}/items?limit=200")

ITEM_ID="${ITEM_ID:-$(echo "$ITEMS_JSON" | python3 -c '
import sys, json
d = json.load(sys.stdin)
ids = [f["id"] for f in d.get("features", []) if f["properties"].get("dashi:kind") == "pointcloud"]
print(ids[0] if ids else "")
')}"

if [[ -z "$ITEM_ID" ]]; then
  echo "ERROR: no pointcloud item in collection $COLL" >&2
  exit 1
fi

ASSETS=$(echo "$ITEMS_JSON" | python3 -c "
import sys, json, re
d = json.load(sys.stdin)
for f in d['features']:
    if f['id'] == '$ITEM_ID':
        a = f['assets']
        out = {}
        for k in ('viewer3d', 'data', 'tileset3d'):
            href = a.get(k, {}).get('href', '')
            m = re.match(r'https?://[^/]+/(.+)', href)
            if m:
                out[k] = m.group(1)
        print(json.dumps(out))
        break
")

if [[ -z "$ASSETS" ]]; then
  echo "ERROR: STAC item $ITEM_ID has no recognised assets" >&2
  exit 1
fi

share_for() {
  local key="$1"
  mc share download --expire="$EXPIRE" "dashi-pf/${key}" 2>/dev/null \
    | grep -E '^Share' | awk '{print $2}'
}

urlenc() {
  python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1], safe=''))" "$1"
}

VIEWER_BASE="${VIEWER_BASE:-http://localhost:8000/viewer/pointcloud.html}"

# Production tier — 3D Tiles tileset (preferred when present).
TILESET3D_KEY=$(echo "$ASSETS" | python3 -c "import sys,json;print(json.load(sys.stdin).get('tileset3d',''))")
TILESET3D_URL=""
if [[ -n "$TILESET3D_KEY" ]]; then
  TILESET3D_URL=$(share_for "$TILESET3D_KEY")
fi

# PoC tier — direct COPC.
COPC_KEY=$(echo "$ASSETS" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('viewer3d') or d.get('data') or '')")
COPC_URL=$(share_for "$COPC_KEY")

echo ""
echo "  Item:    $ITEM_ID"
echo "  Expires: $EXPIRE"
echo ""

if [[ -n "$COPC_URL" ]]; then
  echo "  ┌─────────────────────────────────────────────────────────────────┐"
  echo "  │ COPC (recommended for the bundled dashi viewer)                 │"
  echo "  │   maplibre-gl-lidar streams viewport-by-viewport via HTTP range │"
  echo "  └─────────────────────────────────────────────────────────────────┘"
  echo ""
  echo "  Presigned URL:"
  echo "  $COPC_URL"
  echo ""
  echo "  One-click viewer URL:"
  echo "  ${VIEWER_BASE}?url=$(urlenc "$COPC_URL")"
  echo ""
fi

if [[ -n "$TILESET3D_URL" ]]; then
  echo "  ┌─────────────────────────────────────────────────────────────────┐"
  echo "  │ 3D Tiles tileset — for CesiumJS / iTowns / deck.gl Tile3DLayer  │"
  echo "  │   (not consumed by the bundled maplibre-gl-lidar viewer)        │"
  echo "  └─────────────────────────────────────────────────────────────────┘"
  echo ""
  echo "  Presigned tileset.json:"
  echo "  $TILESET3D_URL"
  echo ""
fi

echo "  Tip: keep this terminal running — it is also holding the RustFS port-forward on :$PORT."
echo "       Ctrl-C to release."
sleep infinity
