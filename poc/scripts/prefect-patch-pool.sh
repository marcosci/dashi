#!/usr/bin/env bash
# Strang H3 — customise the Prefect `dashi-default` Kubernetes work pool
# base job template so every flow-run pod injects RustFS credentials
# via valueFrom.secretKeyRef instead of plain env values. Secrets stay
# K8s-side; the Prefect DB never stores them.

set -euo pipefail

POOL="${DASHI_PREFECT_WORK_POOL:-dashi-default}"

if [[ -z "${PREFECT_API_URL:-}" ]]; then
  echo "ERROR: set PREFECT_API_URL first (port-forward svc/prefect-server)"
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_PY="$REPO_ROOT/ingest/.venv/bin/python"
[[ -x "$VENV_PY" ]] || { echo "ERROR: ingest venv missing"; exit 1; }

echo "→ patching work pool '$POOL' base job template"

"$VENV_PY" - <<PYEOF
import asyncio, json, os
from prefect.client.orchestration import get_client

POOL = "$POOL"

# valueFrom entries that get baked into the job manifest template so
# every flow-run pod inherits them, regardless of what the flow
# deployment's job_variables.env field contains.
INJECTED = [
    {"name": "DASHI_S3_ACCESS_KEY", "valueFrom": {"secretKeyRef": {"name": "dashi-rustfs-pipeline", "key": "access-key"}}},
    {"name": "DASHI_S3_SECRET_KEY", "valueFrom": {"secretKeyRef": {"name": "dashi-rustfs-pipeline", "key": "secret-key"}}},
    {"name": "DASHI_S3_ENDPOINT",   "valueFrom": {"secretKeyRef": {"name": "dashi-rustfs-pipeline", "key": "endpoint"}}},
    {"name": "DASHI_STAC_URL",      "value": "http://stac-fastapi.dashi-catalog.svc.cluster.local:8080"},
]

async def main():
    async with get_client() as c:
        pool = await c.read_work_pool(POOL)
        tpl = pool.base_job_template

        container = tpl["job_configuration"]["job_manifest"]["spec"]["template"]["spec"]["containers"][0]
        # Remove Prefect's Jinja env substitution and replace with our list.
        # Kubernetes will merge the list verbatim into the pod spec.
        container["env"] = INJECTED

        await c.update_work_pool(
            POOL,
            work_pool=__import__("prefect.client.schemas.actions", fromlist=["WorkPoolUpdate"]).WorkPoolUpdate(
                base_job_template=tpl,
            ),
        )
        print(f"✓ patched '{POOL}' — env now sourced from dashi-rustfs-pipeline Secret")
        print(f"  injected: {[e['name'] for e in INJECTED]}")

asyncio.run(main())
PYEOF
