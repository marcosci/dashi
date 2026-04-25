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

KEY=$(echo "$ITEMS_JSON" | python3 -c "
import sys, json, re
d = json.load(sys.stdin)
for f in d['features']:
    if f['id'] == '$ITEM_ID':
        href = f['assets'].get('viewer3d', f['assets'].get('data', {})).get('href','')
        m = re.match(r'https?://[^/]+/(.+)', href)
        print(m.group(1) if m else '')
        break
")

if [[ -z "$KEY" ]]; then
  echo "ERROR: item $ITEM_ID has no viewer3d/data asset href" >&2
  exit 1
fi

SHARE=$(mc share download --expire="$EXPIRE" "dashi-pf/${KEY}" | grep -E '^Share' | awk '{print $2}')

VIEWER="http://localhost:8000/viewer/pointcloud.html?url=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1], safe=''))" "$SHARE")"

echo ""
echo "  Item:    $ITEM_ID"
echo "  Key:     $KEY"
echo "  Expires: $EXPIRE"
echo ""
echo "  Presigned URL (paste into viewer's input field):"
echo "  $SHARE"
echo ""
echo "  One-click viewer URL (with the share URL already filled in):"
echo "  $VIEWER"
echo ""
echo "  Tip: keep this terminal running — it is also holding the RustFS port-forward on :$PORT."
echo "       Ctrl-C to release."
sleep infinity
