"""Register the dashi-ingest flow + a process-pool work pool.

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
    work_pool = os.environ.get("DASHI_PREFECT_WORK_POOL", "dashi-default")
    deployment_id = ingest_flow.deploy(
        name="dashi-ingest-deployment",
        work_pool_name=work_pool,
        image="dashi/dashi-ingest:dev",
        push=False,  # image is imported into k3d directly, no registry push
        parameters={
            "source_path": "/work/sample-data",
            "domain": "gelaende-umwelt",
            "stac_url": "http://stac-fastapi.dashi-catalog.svc.cluster.local:8080",
        },
        description="Format-agnostic dashi ingest run over a mounted sample path.",
        tags=["dashi", "ingest"],
    )
    print(f"deployed: {deployment_id}")


if __name__ == "__main__":
    main()
