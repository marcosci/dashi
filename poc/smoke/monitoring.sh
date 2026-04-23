#!/usr/bin/env bash
# Phase-2 Strang I smoke — Prometheus + Grafana + kube-state-metrics.

set -euo pipefail

NS="${NS:-miso-monitoring}"
PROM_PORT="${PROM_PORT:-19090}"
GRAF_PORT="${GRAF_PORT:-13030}"

cleanup() { for pid in ${PFPIDS:-}; do kill "$pid" 2>/dev/null || true; done; }
trap cleanup EXIT

echo "→ port-forwards"
kubectl -n "$NS" port-forward svc/prometheus "${PROM_PORT}:9090" >/dev/null 2>&1 &
PFPIDS="$!"
kubectl -n "$NS" port-forward svc/grafana    "${GRAF_PORT}:3000" >/dev/null 2>&1 &
PFPIDS="$PFPIDS $!"
sleep 4

ok()   { echo "✓ $1"; }
fail() { echo "✗ $1" >&2; exit 1; }

# 1. Prometheus is ready
[[ "$(curl -sf http://localhost:${PROM_PORT}/-/ready)" == "Prometheus Server is Ready." ]] && ok "prometheus ready" || fail "prometheus not ready"

# 2. Prometheus has active targets
TARGETS=$(curl -sf "http://localhost:${PROM_PORT}/api/v1/targets?state=active" | python3 -c 'import sys,json;print(len(json.load(sys.stdin)["data"]["activeTargets"]))')
[[ "$TARGETS" -gt 0 ]] && ok "prometheus has $TARGETS active targets" || fail "no active targets"

# 3. kube-state-metrics is being scraped and healthy
KSM_UP=$(curl -sf "http://localhost:${PROM_PORT}/api/v1/query?query=up%7Bjob%3D%22kube-state-metrics%22%7D" | python3 -c 'import sys,json;d=json.load(sys.stdin).get("data",{}).get("result",[]);print(int(d[0]["value"][1]) if d else 0)')
[[ "$KSM_UP" == "1" ]] && ok "kube-state-metrics up" || fail "kube-state-metrics not up (got $KSM_UP)"

# 4. Alert rules loaded
RULES=$(curl -sf "http://localhost:${PROM_PORT}/api/v1/rules" | python3 -c 'import sys,json;g=json.load(sys.stdin)["data"]["groups"];print(sum(len(grp["rules"]) for grp in g))')
[[ "$RULES" -ge 4 ]] && ok "$RULES alert/recording rules loaded" || fail "expected >=4 rules, got $RULES"

# 5. kube-state-metrics produces a miso-* pod series
POD_COUNT=$(curl -sf "http://localhost:${PROM_PORT}/api/v1/query?query=count%28kube_pod_info%7Bnamespace%3D~%22miso-.%2A%22%7D%29" | python3 -c 'import sys,json;d=json.load(sys.stdin).get("data",{}).get("result",[]);print(int(float(d[0]["value"][1])) if d else 0)')
[[ "$POD_COUNT" -ge 3 ]] && ok "kube_pod_info sees $POD_COUNT pods in miso-* namespaces" || fail "expected >=3 miso-* pods, got $POD_COUNT"

# 6. Grafana health
GRAF_HEALTH=$(curl -sf "http://localhost:${GRAF_PORT}/api/health" | python3 -c 'import sys,json;print(json.load(sys.stdin)["database"])')
[[ "$GRAF_HEALTH" == "ok" ]] && ok "grafana database ok" || fail "grafana not ok ($GRAF_HEALTH)"

# 7. Grafana has the Prometheus datasource
DS_COUNT=$(curl -sf "http://localhost:${GRAF_PORT}/api/datasources" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(len([x for x in d if x.get("type")=="prometheus"]))')
[[ "$DS_COUNT" -ge 1 ]] && ok "grafana has Prometheus datasource" || fail "no Prometheus datasource"

# 8. Grafana has the dashi dashboard provisioned
DB_UID=$(curl -sf "http://localhost:${GRAF_PORT}/api/search?query=dashi" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d[0]["uid"] if d else "")')
[[ -n "$DB_UID" ]] && ok "grafana provisioned dashboard present ($DB_UID)" || fail "no dashboard matching 'dashi'"

echo ""
echo "✓ monitoring smoke PASSED"
