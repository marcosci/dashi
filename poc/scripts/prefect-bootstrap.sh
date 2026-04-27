#!/usr/bin/env bash
# Auto-register the dashi-ingest Prefect deployment + patch the
# Kubernetes work pool's base job template with RustFS credentials.
#
# Combines `prefect-patch-pool.sh` and `prefect-register.sh` behind a
# single idempotent target — runs end-to-end from a cold cluster
# without requiring the operator to manage a port-forward by hand.
#
# Re-runnable; safe to wire into `make prefect-up` and into
# `redeploy-all.sh`. If the work pool / deployment already exist with
# the desired shape, this is a no-op.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_PY="$REPO_ROOT/ingest/.venv/bin/python"

# 1. Ensure the local venv exists. The patch + register Python scripts
#    speak the Prefect API via the in-process client, so `prefect`
#    needs to be importable. Bootstrap on demand.
if [[ ! -x "$VENV_PY" ]]; then
  echo "→ bootstrap dashi-ingest venv (first run only)"
  python3 -m venv "$REPO_ROOT/ingest/.venv"
  "$REPO_ROOT/ingest/.venv/bin/pip" install --quiet --upgrade pip
  # Editable install picks up local edits + pulls Prefect transitively.
  "$REPO_ROOT/ingest/.venv/bin/pip" install --quiet -e "$REPO_ROOT/ingest"
fi

# 2. Stand up a temporary port-forward to the in-cluster Prefect server.
#    The two underlying scripts insist on PREFECT_API_URL pointing at a
#    reachable HTTP endpoint, so we expose svc/prefect-server on a
#    locally-free port for the duration of this script.
PORT="${DASHI_PREFECT_BOOTSTRAP_PORT:-14200}"
LOG_DIR="/tmp/dashi-prefect-bootstrap"
mkdir -p "$LOG_DIR"

# Free the port if a stale forwarder is sitting on it.
if lsof -ti tcp:"$PORT" >/dev/null 2>&1; then
  lsof -ti tcp:"$PORT" | xargs -r kill -9 2>/dev/null || true
  sleep 1
fi

echo "→ port-forwarding svc/prefect-server :$PORT (transient)"
kubectl -n dashi-data port-forward --address=127.0.0.1 \
  svc/prefect-server "${PORT}:4200" \
  >"$LOG_DIR/pf.log" 2>&1 &
PF_PID=$!
trap 'kill "$PF_PID" 2>/dev/null || true' EXIT

# Wait for the forward to accept connections (Prefect health endpoint).
for _ in $(seq 1 30); do
  if curl -fsS -o /dev/null -m 1 "http://127.0.0.1:${PORT}/api/health"; then
    break
  fi
  sleep 1
done
if ! curl -fsS -o /dev/null -m 2 "http://127.0.0.1:${PORT}/api/health"; then
  echo "ERROR: prefect-server didn't accept on :$PORT within 30s"
  echo "       check $LOG_DIR/pf.log"
  exit 1
fi

export PREFECT_API_URL="http://127.0.0.1:${PORT}/api"

# 3. Patch the work pool first — the deployment register step assumes
#    the pool already exists with the right env injection.
#    The pool is auto-created when the prefect-worker Deployment first
#    connects to the API; if we get here before that, retry briefly.
for _ in $(seq 1 15); do
  if "$VENV_PY" - <<'PYEOF' 2>/dev/null
import asyncio
from prefect.client.orchestration import get_client
async def main():
    async with get_client() as c:
        await c.read_work_pool("dashi-default")
asyncio.run(main())
PYEOF
  then
    break
  fi
  sleep 2
done

bash "$REPO_ROOT/scripts/prefect-patch-pool.sh"
bash "$REPO_ROOT/scripts/prefect-register.sh"

echo ""
echo "✓ prefect work pool patched + dashi-ingest/main deployment registered"
