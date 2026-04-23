"""Register the miso-ingest flow as a Prefect deployment bound to the
miso-default Kubernetes work pool. Flow runs execute as K8s Jobs in the
miso-data namespace, using the miso/miso-ingest:dev image.

Run:

    export PREFECT_API_URL=http://localhost:4200/api
    python -m flows.deploy                 # register (idempotent)
    prefect deployment run 'miso-ingest/main'   # trigger a run
"""

from __future__ import annotations

import os
from pathlib import Path

from flows.ingest import ingest_flow


def main() -> None:
    image = os.environ.get("MISO_INGEST_IMAGE", "miso/miso-ingest:dev")
    work_pool = os.environ.get("MISO_PREFECT_WORK_POOL", "miso-default")
    sample_path = os.environ.get("MISO_SAMPLE_PATH", "/work/sample-data")

    # Credentials + endpoints are wired via job_variables.env so that every
    # flow run pod gets the same environment the local runner uses.
    job_env = {
        "MISO_S3_ENDPOINT": os.environ.get("MISO_S3_ENDPOINT", "http://rustfs.miso-platform.svc.cluster.local:9000"),
        "MISO_STAC_URL": os.environ.get("MISO_STAC_URL", "http://stac-fastapi.miso-catalog.svc.cluster.local:8080"),
    }

    # The worker injects a `valueFrom` secret reference via job_variables.
    job_variables = {
        "image": image,
        "image_pull_policy": "IfNotPresent",
        "namespace": "miso-data",
        "env": [{"name": k, "value": v} for k, v in job_env.items()]
        + [
            {
                "name": "MISO_S3_ACCESS_KEY",
                "valueFrom": {"secretKeyRef": {"name": "rustfs-client", "key": "access-key"}},
            },
            {
                "name": "MISO_S3_SECRET_KEY",
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
            "stac_url": job_env["MISO_STAC_URL"],
        },
        description="Format-agnostic MISO ingest run over a mounted sample path.",
        tags=["miso", "ingest"],
    )
    print(f"deployed: {deployment_id}")


if __name__ == "__main__":
    main()
