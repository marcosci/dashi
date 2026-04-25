"""Prefect flow: post-ingest LLM enrichment of STAC items.

Walks every item in a collection (optionally filtered to those that
don't yet carry `dashi:enriched_title`), calls the configured LLM, and
PATCHes the STAC item with the new properties. Skips items whose
domain has classification ≥ rst — sensitive content does not get sent
to a third-party LLM unless explicitly opted in via
`--allow-classifications`.

The flow is fail-safe: per-item errors are logged + counted, never
abort the run.
"""

from __future__ import annotations

import os

import requests
from prefect import flow, get_run_logger, task

from dashi_ingest.enrich import LlmConfig, enrich_item

DEFAULT_ALLOWED = ("pub", "int")


@task(name="enrich-one-item")
def enrich_one(
    item: dict,
    *,
    stac_url: str,
    cfg_dump: dict,
    allowed_classifications: tuple[str, ...],
) -> dict:
    log = get_run_logger()
    item_id = item["id"]
    coll = item["collection"]
    props = item.get("properties", {}) or {}
    cls = str(props.get("dashi:classification", "int")).lower()

    if cls not in allowed_classifications:
        return {"id": item_id, "skipped": "classification", "value": cls}

    if props.get("dashi:enriched_title"):
        return {"id": item_id, "skipped": "already-enriched"}

    try:
        cfg = LlmConfig(**cfg_dump)
        enriched = enrich_item(item, cfg=cfg)
    except Exception as e:  # noqa: BLE001
        log.warning("enrich %s failed: %s", item_id, e)
        return {"id": item_id, "error": str(e)[:200]}

    # Merge into existing properties + PUT the whole item back.
    new_props = {**props, **enriched}
    new_item = {**item, "properties": new_props}
    try:
        r = requests.put(
            f"{stac_url.rstrip('/')}/collections/{coll}/items/{item_id}",
            json=new_item,
            timeout=20,
        )
        r.raise_for_status()
    except requests.RequestException as e:
        log.warning("PATCH STAC %s failed: %s", item_id, e)
        return {"id": item_id, "error": f"stac put: {e}"}

    return {
        "id": item_id,
        "enriched": True,
        "title": enriched.get("dashi:enriched_title"),
    }


@flow(name="dashi-enrich")
def enrich_flow(
    collection: str,
    stac_url: str | None = None,
    limit: int = 200,
    allow_classifications: str = "pub,int",
) -> list[dict]:
    """Enrich every item under a collection that lacks dashi:enriched_title."""
    log = get_run_logger()
    stac_url = stac_url or os.environ.get(
        "DASHI_STAC_URL",
        "http://stac-fastapi.dashi-catalog.svc.cluster.local:8080",
    )
    allowed = tuple(c.strip() for c in allow_classifications.split(",") if c.strip())
    if not allowed:
        allowed = DEFAULT_ALLOWED

    r = requests.get(
        f"{stac_url.rstrip('/')}/collections/{collection}/items",
        params={"limit": limit},
        timeout=30,
    )
    r.raise_for_status()
    features = r.json().get("features", [])
    log.info("collection=%s items=%d allowed=%s", collection, len(features), allowed)

    cfg_dump = LlmConfig.from_env().__dict__
    return [
        enrich_one(
            f,
            stac_url=stac_url,
            cfg_dump=cfg_dump,
            allowed_classifications=allowed,
        )
        for f in features
    ]
