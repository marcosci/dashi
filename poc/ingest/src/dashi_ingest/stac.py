"""STAC Item builder + Collection POSTer. Format-agnostic on output."""

from __future__ import annotations

from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import pystac
import requests

DEFAULT_STAC_URL = "http://localhost:18080"


def build_item(
    *,
    item_id: str,
    collection_id: str,
    bbox: tuple[float, float, float, float],
    geometry: dict | None,
    datetime_: datetime | None,
    properties: dict[str, Any],
    assets: dict[str, pystac.Asset],
) -> pystac.Item:
    """Build a STAC 1.0 Item covering one processed dataset."""
    item = pystac.Item(
        id=item_id,
        geometry=geometry or _bbox_to_polygon(bbox),
        bbox=list(bbox),
        datetime=(datetime_ or datetime.now(UTC)),
        properties=properties or {},
        collection=collection_id,
    )
    for key, asset in assets.items():
        item.add_asset(key, asset)
    return item


def ensure_collection(
    *,
    collection_id: str,
    description: str,
    bbox: tuple[float, float, float, float],
    stac_url: str = DEFAULT_STAC_URL,
) -> None:
    """Create a STAC Collection if it does not yet exist."""
    probe = requests.get(f"{stac_url.rstrip('/')}/collections/{collection_id}", timeout=10)
    if probe.status_code == 200:
        return
    if probe.status_code != 404:
        probe.raise_for_status()
    payload = {
        "type": "Collection",
        "id": collection_id,
        "stac_version": "1.0.0",
        "description": description,
        "license": "proprietary",
        "links": [],
        "extent": {
            "spatial": {"bbox": [list(bbox)]},
            "temporal": {"interval": [[datetime.now(UTC).isoformat(), None]]},
        },
    }
    r = requests.post(f"{stac_url.rstrip('/')}/collections", json=payload, timeout=15)
    r.raise_for_status()


def post_item(item: pystac.Item, *, stac_url: str = DEFAULT_STAC_URL) -> None:
    """POST or upsert a STAC Item via stac-fastapi transaction extension."""
    url = f"{stac_url.rstrip('/')}/collections/{item.collection_id}/items"
    r = requests.post(url, json=item.to_dict(), timeout=30)
    if r.status_code == 409:
        # Already exists — PUT to upsert
        put_url = f"{url}/{item.id}"
        pr = requests.put(put_url, json=item.to_dict(), timeout=30)
        pr.raise_for_status()
        return
    r.raise_for_status()


def _bbox_to_polygon(bbox: tuple[float, float, float, float]) -> dict:
    minx, miny, maxx, maxy = bbox
    return {
        "type": "Polygon",
        "coordinates": [
            [
                [minx, miny],
                [maxx, miny],
                [maxx, maxy],
                [minx, maxy],
                [minx, miny],
            ]
        ],
    }
