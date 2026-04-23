"""Prefect flow wrapping miso-ingest.

Design:

- One `@flow` per ingestion invocation.
- One `@task` per detected primary layer/file (so Prefect's retry + logging
  granularity matches the unit of transformation).
- Flow accepts either a local path (run from inside the cluster with the data
  baked into the image / mounted via configmap) or an `s3://` landing-zone
  prefix (produces a tempdir locally, downloads with `mc` or `boto3` — not
  implemented for PoC, left as a TODO).

Scheduling + triggers are handled by the Prefect deployment definition in
`register.py`, not here.
"""

from __future__ import annotations

import os
from pathlib import Path

from prefect import flow, get_run_logger, task
from prefect.tasks import task_input_hash

from miso_ingest import detect, storage
from miso_ingest.runner import IngestOutcome, ingest_one


@task(
    name="ingest-one",
    retries=2,
    retry_delay_seconds=30,
    cache_key_fn=task_input_hash,
    cache_expiration=None,  # permanent cache; re-runs of the same content are no-ops
)
def ingest_one_task(
    path: str,
    kind: str,
    driver: str | None,
    layer: str | None,
    reason: str,
    *,
    domain: str,
    processed_bucket: str,
    stac_url: str,
    collection_description: str,
    h3_resolution: int,
) -> dict:
    logger = get_run_logger()
    det = detect.Detection(
        path=Path(path),
        kind=kind,  # type: ignore[arg-type]
        driver=driver,
        reason=reason,
        layer=layer,
    )
    s3_cfg = storage.S3Config.from_env()

    # Uploads are already gated by boto3 TransferConfig (8MB chunks, 2 threads).
    # Add a Prefect concurrency slot in Phase 2 once the deployment creates it
    # via `prefect concurrency-limit create miso-ingest-uploads 4` during bootstrap.
    outcome: IngestOutcome = ingest_one(
        det,
        domain=domain,
        processed_bucket=processed_bucket,
        stac_url=stac_url,
        collection_description=collection_description,
        s3_cfg=s3_cfg,
        h3_resolution=h3_resolution,
    )

    logger.info(
        "%s  kind=%s  path=%s  layer=%s  dataset_id=%s  uri=%s  reason=%s",
        outcome.status,
        outcome.kind,
        outcome.input_path,
        outcome.layer,
        outcome.dataset_id,
        outcome.output_uri,
        outcome.reason,
    )
    return outcome.__dict__


@flow(name="miso-ingest")
def ingest_flow(
    source_path: str,
    domain: str = "gelaende-umwelt",
    processed_bucket: str = "processed",
    stac_url: str | None = None,
    collection_description: str = "Domain data processed via MISO ingestion pipeline",
    h3_resolution: int = 7,
) -> list[dict]:
    """Discover every primary file/layer under source_path and ingest.

    Parameters come in via Prefect deployment default values or the
    `prefect deployment run` CLI — no code edits needed for a new run.
    """
    logger = get_run_logger()

    stac_url = stac_url or os.environ.get("MISO_STAC_URL", "http://stac-fastapi.miso-catalog.svc.cluster.local:8080")
    src = Path(source_path)

    detections = detect.discover(src)
    real = [d for d in detections if d.kind != "unknown"]
    logger.info("discovered %d primary targets (%d skipped)", len(real), len(detections) - len(real))

    outcomes = [
        ingest_one_task.submit(
            path=str(d.path),
            kind=d.kind,
            driver=d.driver,
            layer=d.layer,
            reason=d.reason,
            domain=domain,
            processed_bucket=processed_bucket,
            stac_url=stac_url,
            collection_description=collection_description,
            h3_resolution=h3_resolution,
        )
        for d in real
    ]

    results = [f.result() for f in outcomes]
    by_status = {"ingested": 0, "rejected": 0, "skipped": 0}
    for r in results:
        by_status[r["status"]] = by_status.get(r["status"], 0) + 1
    logger.info("summary: %s", by_status)
    return results


if __name__ == "__main__":
    import sys

    if len(sys.argv) < 2:
        raise SystemExit("usage: python -m flows.ingest <path-or-dir>")
    ingest_flow(sys.argv[1])
