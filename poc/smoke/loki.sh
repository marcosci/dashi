#!/usr/bin/env bash
# Smoke — Loki + promtail.
# Verifies Loki is /ready, promtail DaemonSet is up on every node, and
# logs from at least one dashi-* pod have been ingested.

set -euo pipefail

NS="${NS:-dashi-monitoring}"
PORT="${PORT:-19310}"

cleanup() { for pid in ${PFPIDS:-}; do kill "$pid" 2>/dev/null || true; done; }
trap cleanup EXIT

ok()   { echo "✓ $1"; }
fail() { echo "✗ $1" >&2; exit 1; }

echo "→ port-forward svc/loki"
kubectl -n "$NS" port-forward svc/loki "${PORT}:3100" >/dev/null 2>&1 &
PFPIDS="$!"
sleep 4

HC=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${PORT}/ready")
[[ "$HC" == "200" ]] && ok "loki /ready 200" || fail "/ready $HC"

PROMTAIL_READY=$(kubectl -n "$NS" get ds promtail -o jsonpath='{.status.numberReady}')
PROMTAIL_DESIRED=$(kubectl -n "$NS" get ds promtail -o jsonpath='{.status.desiredNumberScheduled}')
[[ "$PROMTAIL_READY" == "$PROMTAIL_DESIRED" && "$PROMTAIL_READY" -ge 1 ]] \
  && ok "promtail ${PROMTAIL_READY}/${PROMTAIL_DESIRED} pods Ready" \
  || fail "promtail not Ready (${PROMTAIL_READY}/${PROMTAIL_DESIRED})"

# Query Loki for any log line in the last hour from any dashi-* namespace.
NOW=$(date -u +%s)
START=$(( NOW - 3600 ))
COUNT=$(curl -sf -H 'X-Scope-OrgID: dashi' \
  --get "http://localhost:${PORT}/loki/api/v1/query_range" \
  --data-urlencode 'query={namespace=~"dashi-.*"}' \
  --data-urlencode "start=${START}000000000" \
  --data-urlencode "end=${NOW}000000000" \
  --data-urlencode 'limit=5' \
  | python3 -c 'import sys,json;d=json.load(sys.stdin);print(sum(len(s.get("values",[])) for s in d.get("data",{}).get("result",[])))')

[[ "$COUNT" -ge 1 ]] && ok "Loki ingested $COUNT log line(s) from dashi-* namespaces" \
                     || fail "no log lines ingested yet (try again in ~30s)"

echo ""
echo "✓ loki smoke PASSED"
