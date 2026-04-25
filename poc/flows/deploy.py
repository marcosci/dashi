"""Register the dashi-ingest flow as a Prefect deployment bound to the
dashi-default Kubernetes work pool. Flow runs execute as K8s Jobs in the
dashi-data namespace, using the dashi/dashi-ingest:dev image.

Run:

    export PREFECT_API_URL=http://localhost:4200/api
    python -m flows.deploy                 # register (idempotent)
    prefect deployment run 'dashi-ingest/main'   # trigger a run
"""

from __future__ import annotations

import os
from pathlib import Path

from flows.ingest import ingest_flow


def main() -> None:
    image = os.environ.get("DASHI_INGEST_IMAGE", "dashi/dashi-ingest:dev")
    work_pool = os.environ.get("DASHI_PREFECT_WORK_POOL", "dashi-default")
    sample_path = os.environ.get("DASHI_SAMPLE_PATH", "/work/sample-data")

    # Credentials + endpoints are wired via job_variables.env so that every
    # flow run pod gets the same environment the local runner uses.
    job_env = {
        "DASHI_S3_ENDPOINT": os.environ.get("DASHI_S3_ENDPOINT", "http://rustfs.dashi-platform.svc.cluster.local:9000"),
        "DASHI_STAC_URL": os.environ.get("DASHI_STAC_URL", "http://stac-fastapi.dashi-catalog.svc.cluster.local:8080"),
    }

    # The worker injects a `valueFrom` secret reference via job_variables.
    job_variables = {
        "image": image,
        "image_pull_policy": "IfNotPresent",
        "namespace": "dashi-data",
        "env": [{"name": k, "value": v} for k, v in job_env.items()]
        + [
            {
                "name": "DASHI_S3_ACCESS_KEY",
                "valueFrom": {"secretKeyRef": {"name": "rustfs-client", "key": "access-key"}},
            },
            {
                "name": "DASHI_S3_SECRET_KEY",
                "valueFrom": {"secretKeyRef": {"name": "rustfs-client", "key": "secret-key"}},
            },
        ],
    }

    deployment_id = ingest_flow.from_source(
        source=str(Path(__file__).resolve().parent.parent),
        entrypoint="flows/ingest.py:ingest_flow",
    ).deploy(
        name="main",
        work_pool_name=work_pool,
        image=image,
        build=False,
        push=False,
        job_variables=job_variables,
        parameters={
            "source_path": sample_path,
            "domain": "gelaende-umwelt",
            "stac_url": job_env["DASHI_STAC_URL"],
        },
        description="Format-agnostic dashi ingest run over a mounted sample path.",
        tags=["dashi", "ingest"],
    )
    print(f"deployed: {deployment_id}")


if __name__ == "__main__":
    main()
