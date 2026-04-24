#!/usr/bin/env bash
# Strang H smoke — per-zone IAM + NetworkPolicy manifests + flow uses
# envFrom Secret (no creds in Prefect DB).

set -euo pipefail

NS_PLATFORM="${NS_PLATFORM:-miso-platform}"
NS_DATA="${NS_DATA:-miso-data}"
NS_SERVING="${NS_SERVING:-miso-serving}"
S3_PORT="${S3_PORT:-19400}"
PREFECT_PORT="${PREFECT_PORT:-19442}"

cleanup() { for pid in ${PFPIDS:-}; do kill "$pid" 2>/dev/null || true; done; }
trap cleanup EXIT

echo "→ port-forwards"
kubectl -n "$NS_PLATFORM" port-forward svc/rustfs         "${S3_PORT}:9000"      >/dev/null 2>&1 &
PFPIDS="$!"
kubectl -n "$NS_DATA"     port-forward svc/prefect-server "${PREFECT_PORT}:4200" >/dev/null 2>&1 &
PFPIDS="$PFPIDS $!"
sleep 4

ok()   { echo "✓ $1"; }
fail() { echo "✗ $1" >&2; exit 1; }

# 1. Three per-zone secrets exist
for ref in "${NS_DATA}/dashi-rustfs-pipeline" "${NS_DATA}/dashi-rustfs-ingest" "${NS_SERVING}/dashi-rustfs-serving"; do
  ns="${ref%%/*}"
  name="${ref##*/}"
  kubectl -n "$ns" get secret "$name" >/dev/null 2>&1 || fail "missing secret $ref"
done
ok "3 per-zone Secrets present (dashi-rustfs-pipeline, -ingest, -serving)"

# 2. Old shared secret removed
if kubectl -n "$NS_SERVING" get secret rustfs-client >/dev/null 2>&1; then
  fail "legacy shared secret miso-serving/rustfs-client still exists"
fi
ok "legacy rustfs-client secret removed from miso-serving"

# 3. Per-zone IAM users exist and have their policies attached
ROOT_ACCESS=$(kubectl -n "$NS_PLATFORM" get secret rustfs-root -o jsonpath='{.data.access-key}' | base64 -d)
ROOT_SECRET=$(kubectl -n "$NS_PLATFORM" get secret rustfs-root -o jsonpath='{.data.secret-key}' | base64 -d)
mc alias set dashi-smoke "http://localhost:${S3_PORT}" "$ROOT_ACCESS" "$ROOT_SECRET" >/dev/null

USERS=$(mc admin user list dashi-smoke 2>&1 | awk '{print $3}' | tr '\n' ',' )
for expected in dashi-pipeline dashi-serving-reader dashi-ingest; do
  echo "$USERS" | grep -q "$expected" || fail "RustFS user $expected missing"
done
ok "3 RustFS users present (dashi-pipeline, dashi-serving-reader, dashi-ingest)"

# 4. serving-reader CANNOT write (policy scope check)
READER_SECRET=$(kubectl -n "$NS_SERVING" get secret dashi-rustfs-serving -o jsonpath='{.data.secret-key}' | base64 -d)
mc alias set dashi-reader "http://localhost:${S3_PORT}" dashi-serving-reader "$READER_SECRET" >/dev/null

if echo "denied-test" | mc pipe dashi-reader/processed/_smoke_write_test 2>/dev/null; then
  fail "dashi-serving-reader was able to write to processed/ — policy too permissive"
fi
ok "dashi-serving-reader write denied to processed/ (least-privilege enforced)"

# 5. serving-reader CAN read processed/ (sanity: a STAC-ingested dataset exists)
if ! mc ls dashi-reader/processed/ >/dev/null 2>&1; then
  fail "dashi-serving-reader cannot list processed/ — misconfigured"
fi
ok "dashi-serving-reader can list processed/"

# 6. Prefect base job template was patched (valueFrom.secretKeyRef present)
HAS_VALUEFROM=$(curl -sf "http://localhost:${PREFECT_PORT}/api/work_pools/miso-default" \
  | python3 -c 'import sys,json; tpl=json.load(sys.stdin)["base_job_template"]; c=tpl["job_configuration"]["job_manifest"]["spec"]["template"]["spec"]["containers"][0]; env=c.get("env",[]); print("dashi-rustfs-pipeline" if any(e.get("valueFrom",{}).get("secretKeyRef",{}).get("name")=="dashi-rustfs-pipeline" for e in (env if isinstance(env,list) else [])) else "MISSING")')
[[ "$HAS_VALUEFROM" == "dashi-rustfs-pipeline" ]] || fail "work pool base job template does not envFrom dashi-rustfs-pipeline (got: $HAS_VALUEFROM)"
ok "Prefect work pool injects dashi-rustfs-pipeline via valueFrom"

# 7. NetworkPolicy objects exist (enforcement depends on CNI; applied === documented intent)
POLICY_COUNT=$(kubectl get networkpolicies -A --no-headers 2>/dev/null | grep -c miso- || true)
[[ "$POLICY_COUNT" -ge 10 ]] || fail "expected >=10 NetworkPolicies in miso-* namespaces, got $POLICY_COUNT"
ok "$POLICY_COUNT NetworkPolicies applied across miso-* namespaces"

# 8. Existing smoke tests still pass (catalog + serving regressions check)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bash "$REPO_ROOT/smoke/catalog.sh" >/dev/null 2>&1 || fail "catalog smoke regressed after H rewiring"
ok "catalog smoke still green"

bash "$REPO_ROOT/smoke/serving.sh" >/dev/null 2>&1 || fail "serving smoke regressed after H rewiring"
ok "serving smoke still green"

echo ""
echo "✓ Strang H RBAC smoke PASSED"
