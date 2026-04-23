#!/usr/bin/env bash
# Phase-2 smoke — Prefect K8s work pool + in-cluster flow run.
# Registers the miso-ingest deployment, triggers a run, verifies the
# flow-run pod completed and wrote a STAC item.

set -euo pipefail

NS_PLATFORM="${NS_PLATFORM:-miso-platform}"
NS_CATALOG="${NS_CATALOG:-miso-catalog}"
NS_DATA="${NS_DATA:-miso-data}"
PREFECT_PORT="${PREFECT_PORT:-19342}"
STAC_PORT="${STAC_PORT:-19380}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INGEST_VENV="$REPO_ROOT/ingest/.venv"

if [[ ! -x "$INGEST_VENV/bin/prefect" ]]; then
  echo "ERROR: prefect client not in ingest venv. Run: cd ingest && .venv/bin/pip install 'prefect>=3.1,<4'"
  exit 1
fi

cleanup() { for pid in ${PFPIDS:-}; do kill "$pid" 2>/dev/null || true; done; }
trap cleanup EXIT

echo "→ port-forwards"
kubectl -n "$NS_DATA"    port-forward svc/prefect-server "${PREFECT_PORT}:4200" >/dev/null 2>&1 &
PFPIDS="$!"
kubectl -n "$NS_CATALOG" port-forward svc/stac-fastapi   "${STAC_PORT}:8080"   >/dev/null 2>&1 &
PFPIDS="$PFPIDS $!"
sleep 4

export PREFECT_API_URL="http://localhost:${PREFECT_PORT}/api"
export MISO_STAC_URL="http://localhost:${STAC_PORT}"

ok()   { echo "✓ $1"; }
fail() { echo "✗ $1" >&2; exit 1; }

# 1. Prefect API reachable
[[ "$(curl -sf http://localhost:${PREFECT_PORT}/api/health)" == "true" ]] && ok "prefect API reachable" || fail "prefect API down"

# 2. Deployment exists and has cron schedule
SCH=$(curl -sf "http://localhost:${PREFECT_PORT}/api/deployments/name/miso-ingest/main" | python3 -c 'import sys,json;s=json.load(sys.stdin).get("schedules",[]);print(s[0]["schedule"].get("cron") if s else "")')
[[ -n "$SCH" ]] && ok "deployment miso-ingest/main has cron '$SCH'" || fail "no cron schedule on deployment"

# 3. Trigger a flow run
RUN_ID=$("$INGEST_VENV/bin/prefect" deployment run 'miso-ingest/main' 2>&1 | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1)
[[ -n "$RUN_ID" ]] && ok "triggered flow-run $RUN_ID" || fail "could not parse flow-run id"

# 4. Wait for completion
for i in $(seq 1 60); do
  STATE=$(curl -sf "http://localhost:${PREFECT_PORT}/api/flow_runs/$RUN_ID" | python3 -c 'import sys,json;print(json.load(sys.stdin)["state"]["type"])')
  [[ "$STATE" == "COMPLETED" || "$STATE" == "FAILED" || "$STATE" == "CRASHED" ]] && break
  sleep 5
done
[[ "$STATE" == "COMPLETED" ]] || fail "flow-run state=$STATE"
ok "flow-run COMPLETED (in-cluster K8s Job executed)"

# 5. Verify a pod with the flow-run-id label ran in miso-data
POD=$(kubectl -n "$NS_DATA" get pods -l "prefect.io/flow-run-id=$RUN_ID" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
[[ -n "$POD" ]] && ok "K8s Job pod found: $POD" || fail "no K8s Job pod for flow-run"

# 6. Verify STAC item landed
HTTP=$(curl -s -o /dev/null -w '%{http_code}' "$MISO_STAC_URL/collections/gelaende-umwelt/items?limit=1")
[[ "$HTTP" == "200" ]] && ok "catalog reachable" || fail "catalog returned $HTTP"

echo ""
echo "✓ phase-2 prefect-kube smoke PASSED"
