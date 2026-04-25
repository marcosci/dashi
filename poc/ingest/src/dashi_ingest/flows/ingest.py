"""Prefect flow wrapping dashi-ingest.

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
from prefect.context import get_run_context
from prefect.tasks import task_input_hash

from dashi_ingest import detect, storage
from dashi_ingest.runner import IngestOutcome, ingest_one


def _prefect_lineage() -> dict:
    """Return STAC properties that link an ingest output back to the Prefect
    flow + task run that produced it. Returns an empty dict when called
    outside a Prefect context (e.g. from the CLI).
    """
    try:
        ctx = get_run_context()
    except Exception:  # noqa: BLE001
        return {}

    flow_run = getattr(ctx, "flow_run", None)
    task_run = getattr(ctx, "task_run", None)

    api_url = os.environ.get("PREFECT_API_URL", "")
    ui_base = api_url.rsplit("/api", 1)[0] if api_url.endswith("/api") else api_url

    out: dict = {}
    if flow_run is not None:
        out["dashi:prefect_flow_run_id"] = str(flow_run.id)
        out["dashi:prefect_flow_name"] = flow_run.name
        if ui_base:
            out["dashi:prefect_flow_run_url"] = f"{ui_base}/runs/flow-run/{flow_run.id}"
    if task_run is not None:
        out["dashi:prefect_task_run_id"] = str(task_run.id)
    return out


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
    classification: str = "int",
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

    # Lineage: pull the live Prefect run context so the STAC item carries
    # a deterministic link back to the run that produced it. Also forward
    # the per-run classification so the runner stamps it on the STAC item.
    lineage = _prefect_lineage()
    lineage["dashi:classification"] = classification

    # Uploads are already gated by boto3 TransferConfig (8MB chunks, 2 threads).
    # Add a Prefect concurrency slot in Phase 2 once the deployment creates it
    # via `prefect concurrency-limit create dashi-ingest-uploads 4` during bootstrap.
    outcome: IngestOutcome = ingest_one(
        det,
        domain=domain,
        processed_bucket=processed_bucket,
        stac_url=stac_url,
        collection_description=collection_description,
        s3_cfg=s3_cfg,
        h3_resolution=h3_resolution,
        lineage=lineage,
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


def _fetch_s3_to_tmp(s3_uri: str, dest: Path) -> Path:
    """Download s3://bucket/key (or its prefix tree) into dest. Returns the
    local path that detect.discover() should be pointed at.
    """
    s3 = storage.s3_client(storage.S3Config.from_env())
    rest = s3_uri[len("s3://") :]
    bucket, _, key = rest.partition("/")
    dest.mkdir(parents=True, exist_ok=True)

    # If key looks like a single object (has a dot/extension after the last /),
    # download it as one file. Otherwise treat as a prefix and mirror the tree.
    last = key.rsplit("/", 1)[-1] if "/" in key else key
    if "." in last and last and not key.endswith("/"):
        local = dest / last
        s3.download_file(bucket, key, str(local))
        return local

    paginator = s3.get_paginator("list_objects_v2")
    prefix = key.rstrip("/") + "/" if key else ""
    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        for obj in page.get("Contents", []) or []:
            rel = obj["Key"][len(prefix) :] if prefix else obj["Key"]
            if not rel:
                continue
            target = dest / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            s3.download_file(bucket, obj["Key"], str(target))
    return dest


@flow(name="dashi-ingest")
def ingest_flow(
    source_path: str,
    domain: str = "gelaende-umwelt",
    processed_bucket: str = "processed",
    stac_url: str | None = None,
    collection_description: str = "Domain data processed via dashi ingestion pipeline",
    h3_resolution: int = 7,
    classification: str = "int",
) -> list[dict]:
    """Discover every primary file/layer under source_path and ingest.

    `source_path` may be either a local filesystem path or an `s3://` URI
    (single object or prefix). For S3 inputs the flow downloads the
    referenced bytes into a tempdir, then runs detect.discover() on that
    tempdir — keeps detect.py filesystem-only and lets the ingest-api shim
    hand off browser-uploaded files via presigned PUT to landing/.

    Parameters come in via Prefect deployment default values or the
    `prefect deployment run` CLI — no code edits needed for a new run.
    """
    logger = get_run_logger()

    stac_url = stac_url or os.environ.get(
        "DASHI_STAC_URL", "http://stac-fastapi.dashi-catalog.svc.cluster.local:8080"
    )

    if source_path.startswith("s3://"):
        import tempfile

        tmp = Path(tempfile.mkdtemp(prefix="dashi-flow-"))
        logger.info("fetching %s → %s", source_path, tmp)
        src = _fetch_s3_to_tmp(source_path, tmp)
    else:
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
            classification=classification,
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
