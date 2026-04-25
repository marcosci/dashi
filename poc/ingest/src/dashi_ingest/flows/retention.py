"""Domain retention flow.

Reads `docs/onboarding/domains.md` retention column, finds STAC items in
each collection older than the cutoff, deletes the underlying RustFS
objects, then deletes the STAC items themselves.

Per-domain retention values understood:
    indefinite        — never delete (skip).
    Nd                — N days  (e.g. 30d, 90d, 365d)
    Nm                — N months (30 day month)
    Ny                — N years  (365 day year)

Run the flow with the per-domain override (`--domain weather-radar`)
or the catch-all `--all` to walk every onboarded domain.

The flow is idempotent: deleting an item that is already gone is a no-op.
"""

from __future__ import annotations

import os
import re
from datetime import UTC, datetime, timedelta
from pathlib import Path

import requests
from prefect import flow, get_run_logger, task

from dashi_ingest import storage

DEFAULT_DOMAINS_DOC = (
    Path(__file__).resolve().parents[3]
    / "docs"
    / "onboarding"
    / "domains.md"
)
RETENTION_RE = re.compile(r"^(\d+)\s*([dmyDMY])$")


def _parse_retention(spec: str) -> timedelta | None:
    """`30d` → 30 days. `1y` → 365 days. `indefinite` → None."""
    spec = spec.strip().lower()
    if spec in {"indefinite", "forever", "infinite", "-"}:
        return None
    m = RETENTION_RE.match(spec)
    if not m:
        return None
    n = int(m.group(1))
    unit = m.group(2)
    if unit == "d":
        return timedelta(days=n)
    if unit == "m":
        return timedelta(days=30 * n)
    if unit == "y":
        return timedelta(days=365 * n)
    return None


def _parse_domains_table(doc: Path) -> dict[str, str]:
    """Parse the markdown table in `domains.md` → {id: retention}."""
    out: dict[str, str] = {}
    if not doc.is_file():
        return out
    seen_header = False
    for line in doc.read_text().splitlines():
        line = line.strip()
        if not line.startswith("|"):
            continue
        cells = [c.strip(" `") for c in line.strip("|").split("|")]
        if not seen_header:
            if "id" in [c.lower() for c in cells]:
                seen_header = True
            continue
        if cells and cells[0].startswith("-"):
            continue
        if len(cells) >= 4:
            domain_id = cells[0]
            retention = cells[3]
            if domain_id and not domain_id.startswith("-"):
                out[domain_id] = retention
    return out


@task(name="prune-domain")
def prune_domain(
    domain: str,
    retention_spec: str,
    *,
    stac_url: str,
    s3_cfg_dump: dict,
) -> dict:
    """Delete STAC items + their assets older than retention_spec."""
    log = get_run_logger()
    delta = _parse_retention(retention_spec)
    if delta is None:
        log.info("domain=%s retention=%s — nothing to do", domain, retention_spec)
        return {"domain": domain, "deleted": 0, "skipped": True}

    cutoff = datetime.now(UTC) - delta
    log.info("domain=%s cutoff=%s", domain, cutoff.isoformat())

    items_url = f"{stac_url.rstrip('/')}/collections/{domain}/items"
    deleted = 0
    page = 0
    while True:
        page += 1
        r = requests.get(
            items_url,
            params={"limit": 200, "datetime": f"../{cutoff.isoformat()}"},
            timeout=30,
        )
        if r.status_code != 200:
            log.warning("STAC GET %s -> %d; stopping pagination", items_url, r.status_code)
            break
        features = r.json().get("features", [])
        if not features:
            break

        s3_cfg = storage.S3Config(**s3_cfg_dump)
        for feat in features:
            for asset in feat.get("assets", {}).values():
                href = asset.get("href")
                if not href:
                    continue
                bucket, key = _parse_s3_href(href)
                if not bucket:
                    continue
                try:
                    storage.delete_prefix(bucket, key, s3_cfg)
                except Exception as e:  # noqa: BLE001
                    log.warning("asset %s delete failed: %s", href, e)
            del_url = f"{items_url}/{feat['id']}"
            dr = requests.delete(del_url, timeout=30)
            if dr.status_code in (200, 204):
                deleted += 1
            else:
                log.warning("STAC DELETE %s -> %d", del_url, dr.status_code)

        if len(features) < 200 or page >= 50:
            break

    log.info("domain=%s deleted=%d", domain, deleted)
    return {"domain": domain, "deleted": deleted, "cutoff": cutoff.isoformat()}


def _parse_s3_href(href: str) -> tuple[str | None, str]:
    """`http://rustfs.../<bucket>/<key>` or `s3://<bucket>/<key>` → (bucket, key)."""
    if href.startswith("s3://"):
        rest = href[5:]
        if "/" in rest:
            b, k = rest.split("/", 1)
            return b, k
        return rest, ""
    m = re.match(r"https?://[^/]+/([^/]+)/(.+)", href)
    if m:
        return m.group(1), m.group(2)
    return None, ""


@flow(name="dashi-retention")
def retention_flow(
    domain: str | None = None,
    domains_doc: str | None = None,
    stac_url: str | None = None,
) -> list[dict]:
    """Walk every onboarded domain (or one specific domain) + prune."""
    log = get_run_logger()
    stac_url = stac_url or os.environ.get(
        "DASHI_STAC_URL",
        "http://stac-fastapi.dashi-catalog.svc.cluster.local:8080",
    )
    doc = Path(domains_doc) if domains_doc else DEFAULT_DOMAINS_DOC
    table = _parse_domains_table(doc)
    if not table:
        log.warning("no domains found in %s — nothing to do", doc)
        return []

    s3_cfg_dump = storage.S3Config.from_env().to_dict()

    targets = (
        [(domain, table.get(domain, "indefinite"))] if domain else list(table.items())
    )
    return [
        prune_domain(d, r, stac_url=stac_url, s3_cfg_dump=s3_cfg_dump)
        for d, r in targets
    ]
