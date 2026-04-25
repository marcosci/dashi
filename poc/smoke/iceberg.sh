#!/usr/bin/env bash
# Smoke — Iceberg REST catalog reachability + namespaces.
# Verifies:
#   1. iceberg-rest /v1/config 200
#   2. namespaces endpoint responds (may be empty on first run)
#   3. create + drop a throwaway namespace round-trips

set -euo pipefail

NS="${NS:-dashi-iceberg}"
PORT="${PORT:-19181}"

cleanup() { for pid in ${PFPIDS:-}; do kill "$pid" 2>/dev/null || true; done; }
trap cleanup EXIT

ok()   { echo "✓ $1"; }
fail() { echo "✗ $1" >&2; exit 1; }

if ! kubectl -n "$NS" get deploy iceberg-rest >/dev/null 2>&1; then
  echo "  (Iceberg REST not deployed; skipping. Run: make iceberg-deploy)"
  exit 0
fi

echo "→ port-forward svc/iceberg-rest"
kubectl -n "$NS" port-forward svc/iceberg-rest "${PORT}:8181" >/dev/null 2>&1 &
PFPIDS="$!"
sleep 4

CFG=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${PORT}/v1/config")
[[ "$CFG" == "200" ]] && ok "iceberg-rest /v1/config 200" || fail "/v1/config $CFG"

NSL=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${PORT}/v1/namespaces")
[[ "$NSL" == "200" ]] && ok "/v1/namespaces 200" || fail "/v1/namespaces $NSL"

# Round-trip a smoke namespace.
TEST_NS="dashi_smoke_$(date -u +%s)"
CREATE=$(curl -s -o /dev/null -w '%{http_code}' \
  -X POST "http://localhost:${PORT}/v1/namespaces" \
  -H 'Content-Type: application/json' \
  -d "{\"namespace\":[\"${TEST_NS}\"]}")
[[ "$CREATE" =~ ^(200|201)$ ]] && ok "namespace create ${TEST_NS}" \
                              || fail "namespace create $CREATE"

DROP=$(curl -s -o /dev/null -w '%{http_code}' \
  -X DELETE "http://localhost:${PORT}/v1/namespaces/${TEST_NS}")
[[ "$DROP" =~ ^(200|204)$ ]] && ok "namespace drop ${TEST_NS}" \
                            || fail "namespace drop $DROP"

echo ""
echo "✓ iceberg smoke PASSED"
