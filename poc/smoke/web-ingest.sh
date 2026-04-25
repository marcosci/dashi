#!/usr/bin/env bash
# Smoke — web ingest API + static UI.
# Verifies:
#   1. ingest-api /healthz 200
#   2. /me returns the mock principal
#   3. /domains lists ≥ 1 collection (= STAC has gelaende-umwelt)
#   4. /presign mints a usable URL
#   5. ingest-web nginx serves index.html

set -euo pipefail

NS="${NS:-dashi-web}"
API_PORT="${API_PORT:-19089}"
WEB_PORT="${WEB_PORT:-19174}"

cleanup() { for pid in ${PFPIDS:-}; do kill "$pid" 2>/dev/null || true; done; }
trap cleanup EXIT

ok()   { echo "✓ $1"; }
fail() { echo "✗ $1" >&2; exit 1; }

if ! kubectl -n "$NS" get deploy ingest-api >/dev/null 2>&1; then
  echo "  (web ingest stack not deployed; skipping. Run: make web-ingest-deploy)"
  exit 0
fi

echo "→ port-forward svc/ingest-api"
kubectl -n "$NS" port-forward svc/ingest-api "${API_PORT}:8088" >/dev/null 2>&1 &
PFPIDS="$!"
echo "→ port-forward svc/ingest-web"
kubectl -n "$NS" port-forward svc/ingest-web "${WEB_PORT}:8080" >/dev/null 2>&1 &
PFPIDS="$PFPIDS $!"
sleep 4

HC=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${API_PORT}/healthz")
[[ "$HC" == "200" ]] && ok "ingest-api /healthz 200" || fail "/healthz $HC"

ME_USER=$(curl -sf "http://localhost:${API_PORT}/me" | python3 -c 'import sys,json;print(json.load(sys.stdin)["user"])')
[[ -n "$ME_USER" ]] && ok "/me user=$ME_USER" || fail "/me empty"

DCOUNT=$(curl -sf "http://localhost:${API_PORT}/domains" \
  | python3 -c 'import sys,json;print(len(json.load(sys.stdin)["domains"]))')
[[ "$DCOUNT" -ge 1 ]] && ok "/domains lists $DCOUNT collection(s)" \
                     || fail "/domains empty (expected gelaende-umwelt)"

PRESIGN_HTTP=$(curl -s -o /tmp/dashi-web-presign.json -w '%{http_code}' \
  -X POST "http://localhost:${API_PORT}/presign" \
  -H 'Content-Type: application/json' \
  -d '{"domain":"gelaende-umwelt","filename":"smoke.gpkg","content_type":"application/x-geopackage","content_length":1024}')
[[ "$PRESIGN_HTTP" == "200" ]] && ok "/presign 200" || { cat /tmp/dashi-web-presign.json; fail "/presign $PRESIGN_HTTP"; }

URL=$(python3 -c 'import sys,json;print(json.load(open("/tmp/dashi-web-presign.json"))["url"])')
[[ "$URL" == *"X-Amz-Signature="* ]] && ok "presigned URL contains SigV4 signature" \
                                     || fail "presigned URL missing signature"

INDEX_HTTP=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${WEB_PORT}/")
[[ "$INDEX_HTTP" == "200" ]] && ok "ingest-web index 200" || fail "/ $INDEX_HTTP"

INDEX_HAS_DASHI=$(curl -s "http://localhost:${WEB_PORT}/" | grep -c 'dashi' || true)
[[ "$INDEX_HAS_DASHI" -ge 1 ]] && ok "index.html contains dashi marker" \
                              || fail "index.html missing dashi marker"

echo ""
echo "✓ web ingest smoke PASSED"
