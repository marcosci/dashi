"""Register the miso-ingest flow + a process-pool work pool.

Run from inside a shell that has `prefect` installed and
`PREFECT_API_URL` pointing at the cluster-internal Prefect API (or a
port-forward to it).
"""

from __future__ import annotations

import os

from prefect.client.orchestration import get_client
from prefect.deployments import run_deployment

from flows.ingest import ingest_flow


def main() -> None:
    work_pool = os.environ.get("MISO_PREFECT_WORK_POOL", "miso-default")
    deployment_id = ingest_flow.deploy(
        name="miso-ingest-deployment",
        work_pool_name=work_pool,
        image="miso/miso-ingest:dev",
        push=False,  # image is imported into k3d directly, no registry push
        parameters={
            "source_path": "/work/sample-data",
            "domain": "gelaende-umwelt",
            "stac_url": "http://stac-fastapi.miso-catalog.svc.cluster.local:8080",
        },
        description="Format-agnostic MISO ingest run over a mounted sample path.",
        tags=["miso", "ingest"],
    )
    print(f"deployed: {deployment_id}")


if __name__ == "__main__":
    main()
