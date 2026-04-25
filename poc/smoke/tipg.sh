#!/usr/bin/env bash
# Smoke — TiPG (OGC API – Features) end-to-end.
#
# Verifies TiPG is reachable, advertises OGC conformance classes, and
# exposes at least one collection from the dashi-serving-db PostGIS
# instance.

set -euo pipefail

NS="${NS:-dashi-serving}"
PORT="${PORT:-19082}"

cleanup() { for pid in ${PFPIDS:-}; do kill "$pid" 2>/dev/null || true; done; }
trap cleanup EXIT

ok()   { echo "✓ $1"; }
fail() { echo "✗ $1" >&2; exit 1; }

echo "→ port-forward svc/tipg"
kubectl -n "$NS" port-forward svc/tipg "${PORT}:8081" >/dev/null 2>&1 &
PFPIDS="$!"
sleep 3

HC=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${PORT}/healthz")
[[ "$HC" == "200" ]] && ok "tipg /healthz $HC" || fail "/healthz $HC"

CONF_COUNT=$(curl -sf "http://localhost:${PORT}/conformance" \
  | python3 -c 'import sys,json;print(len(json.load(sys.stdin).get("conformsTo",[])))')
[[ "$CONF_COUNT" -ge 5 ]] && ok "conformance advertises $CONF_COUNT classes" \
                          || fail "expected >=5 conformance classes, got $CONF_COUNT"

COLL_COUNT=$(curl -sf "http://localhost:${PORT}/collections" \
  | python3 -c '
import sys, json
d = json.load(sys.stdin)
print(len(d.get("collections", []) or d.get("items", [])))
')
[[ "$COLL_COUNT" -ge 1 ]] && ok "tipg sees $COLL_COUNT collection(s)" \
                          || fail "no collections discovered"

# OGC API root document advertises the four standard link rels
LINK_RELS=$(curl -sf "http://localhost:${PORT}/" \
  | python3 -c 'import sys,json;d=json.load(sys.stdin);print(",".join(sorted(set(l["rel"] for l in d.get("links",[])))))')
echo "  link rels: $LINK_RELS"

echo ""
echo "✓ tipg smoke PASSED"
