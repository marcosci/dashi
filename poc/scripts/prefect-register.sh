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

ACCESS=$(kubectl -n miso-platform get secret rustfs-root -o jsonpath='{.data.access-key}' | base64 -d)
SECRET=$(kubectl -n miso-platform get secret rustfs-root -o jsonpath='{.data.secret-key}' | base64 -d)

cd "$REPO_ROOT/ingest"   # so Prefect records a relative entrypoint that
                         # resolves inside the image (WORKDIR /app)

"$REPO_ROOT/ingest/.venv/bin/python" - <<PYEOF
import os
from miso_ingest.flows.ingest import ingest_flow

image = "$IMAGE"
pool = "$POOL"
sample_path = "$SAMPLE_PATH"

# NOTE (Phase-2 Strang H follow-up): Prefect's default kubernetes base job
# template accepts env as {KEY: VALUE} but not valueFrom.secretKeyRef. For
# PoC we inject RustFS credentials as plain values — they end up in the
# Prefect DB. Strang H will customise the base job template to support
# envFrom.secretRef so credentials stay on K8s-side only.
job_variables = {
    "image": image,
    "image_pull_policy": "IfNotPresent",
    "namespace": "miso-data",
    "service_account_name": "prefect-worker",
    "env": {
        "MISO_S3_ENDPOINT":   "http://rustfs.miso-platform.svc.cluster.local:9000",
        "MISO_STAC_URL":      "http://stac-fastapi.miso-catalog.svc.cluster.local:8080",
        "MISO_S3_ACCESS_KEY": "$ACCESS",
        "MISO_S3_SECRET_KEY": "$SECRET",
    },
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
