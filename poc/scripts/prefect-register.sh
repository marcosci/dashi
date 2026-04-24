#!/usr/bin/env bash
# Register the miso-ingest flow as a Prefect deployment pointing at the
# in-cluster Kubernetes work pool. Idempotent. Uses prefect CLI.
#
# Prereqs:
#   - PREFECT_API_URL exported, pointing at http://localhost:4200/api
#     (port-forward svc/prefect-server first)
#   - miso/miso-ingest:dev image imported into k3d
#   - Work pool 'miso-default' exists (created automatically when the worker
#     first connects)

set -euo pipefail

POOL="${MISO_PREFECT_WORK_POOL:-miso-default}"
IMAGE="${MISO_INGEST_IMAGE:-miso/miso-ingest:dev}"
SAMPLE_PATH="${MISO_SAMPLE_PATH:-/work/sample-data}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -z "${PREFECT_API_URL:-}" ]]; then
  echo "ERROR: set PREFECT_API_URL to the Prefect server (e.g. http://localhost:4200/api)"
  exit 1
fi

echo "→ registering flow miso-ingest/main against work pool '$POOL' with image '$IMAGE'"

cd "$REPO_ROOT/ingest"   # so Prefect records a relative entrypoint that
                         # resolves inside the image (WORKDIR /app)

"$REPO_ROOT/ingest/.venv/bin/python" - <<PYEOF
import os
from miso_ingest.flows.ingest import ingest_flow

image = "$IMAGE"
pool = "$POOL"
sample_path = "$SAMPLE_PATH"

# Strang H — RustFS credentials are baked into the work pool's base job
# template via valueFrom.secretKeyRef (see scripts/prefect-patch-pool.sh).
# The deployment no longer carries credentials. Run prefect-patch-pool.sh
# once after the pool is created; this register script is idempotent after.
job_variables = {
    "image": image,
    "image_pull_policy": "IfNotPresent",
    "namespace": "miso-data",
    "service_account_name": "prefect-worker",
}

from prefect.client.schemas.schedules import CronSchedule

deployment_id = ingest_flow.deploy(
    name="main",
    work_pool_name=pool,
    image=image,
    build=False,
    push=False,
    job_variables=job_variables,
    parameters={
        "source_path": sample_path,
        "domain": "gelaende-umwelt",
        "stac_url": "http://stac-fastapi.miso-catalog.svc.cluster.local:8080",
    },
    schedules=[
        # Hourly sweep of the landing zone — adjust for production cadence
        CronSchedule(cron="0 * * * *", timezone="UTC"),
    ],
    description="Format-agnostic MISO ingest run over a mounted sample path. Scheduled hourly.",
    tags=["miso", "ingest", "scheduled"],
)
print(f"deployment-id: {deployment_id}")
PYEOF

echo ""
echo "✓ Registered. Trigger a flow run with:"
echo "    prefect deployment run 'miso-ingest/main'"
