"""End-to-end ingestion runner. Glues detect → validate → transform → upload → catalog."""

from __future__ import annotations

import hashlib
import json
import logging
import shutil
import tempfile
from dataclasses import asdict, dataclass
from datetime import UTC, datetime
from pathlib import Path

import geopandas as gpd
import pystac
import rasterio

from miso_ingest import detect, stac, storage, validators
from miso_ingest.transforms import raster as raster_transform
from miso_ingest.transforms import vector as vector_transform

log = logging.getLogger(__name__)


@dataclass
class IngestOutcome:
    input_path: str
    kind: str
    dataset_id: str
    status: str  # "ingested" | "rejected" | "skipped"
    output_uri: str | None
    stac_item_id: str | None
    reason: str | None
    counts: dict


def _dataset_id(src: Path, extra: bytes = b"") -> str:
    h = hashlib.sha256()
    h.update(src.name.encode())
    with src.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    h.update(extra)
    return h.hexdigest()[:16]


def ingest_one(
    src: Path,
    *,
    domain: str,
    processed_bucket: str,
    stac_url: str,
    collection_description: str,
    s3_cfg: storage.S3Config,
    h3_resolution: int = 7,
) -> IngestOutcome:
    """Ingest a single file. Emits a metadata sidecar alongside the upload."""
    det = detect.classify(src)
    if det.kind == "unknown":
        return IngestOutcome(
            input_path=str(src),
            kind="unknown",
            dataset_id="",
            status="skipped",
            output_uri=None,
            stac_item_id=None,
            reason=det.reason,
            counts={},
        )

    # Validate
    if det.kind == "vector":
        vr = validators.validate_vector(src)
    else:
        vr = validators.validate_raster(src)
    if not vr.ok:
        return IngestOutcome(
            input_path=str(src),
            kind=det.kind,
            dataset_id="",
            status="rejected",
            output_uri=None,
            stac_item_id=None,
            reason="; ".join(vr.errors),
            counts={"warnings": len(vr.warnings)},
        )

    dataset_id = _dataset_id(src)
    with tempfile.TemporaryDirectory(prefix="miso-ingest-") as tmp:
        tmp_path = Path(tmp)

        if det.kind == "vector":
            vresult = vector_transform.transform(
                src, tmp_path, h3_resolution=h3_resolution
            )
            bbox, assets_meta = _vector_bbox_and_assets(tmp_path, vresult)
            counts = {
                "features": vresult.feature_count,
                "repaired": vresult.repaired_count,
                "partitions": vresult.partitions,
                "source_crs": vresult.source_crs,
            }
        else:
            rresult = raster_transform.transform(src, tmp_path)
            bbox, assets_meta = _raster_bbox_and_assets(rresult)
            counts = {
                "bands": rresult.bands,
                "width": rresult.width,
                "height": rresult.height,
                "source_crs": rresult.source_crs,
                "reprojected": rresult.reprojected,
                "overviews": rresult.overviews,
            }

        # Metadata sidecar
        sidecar = {
            "source": str(src),
            "detected": asdict(det),
            "validation": vr.to_dict(),
            "transform_counts": counts,
            "ingested_at": datetime.now(UTC).isoformat(),
            "target_crs": "EPSG:4326",
            "h3_resolution": h3_resolution if det.kind == "vector" else None,
        }
        (tmp_path / "_metadata.json").write_text(json.dumps(sidecar, indent=2, default=str))

        # Upload
        key_prefix = storage.processed_prefix(domain, dataset_id, det.kind)
        n_objects = storage.upload_tree(tmp_path, processed_bucket, key_prefix, s3_cfg)

        # STAC item
        stac.ensure_collection(
            collection_id=domain,
            description=collection_description,
            bbox=bbox,
            stac_url=stac_url,
        )
        assets = {
            name: pystac.Asset(
                href=storage.s3_url(processed_bucket, f"{key_prefix}/{a['rel']}", s3_cfg.endpoint),
                media_type=a["media_type"],
                roles=a["roles"],
                title=a.get("title"),
            )
            for name, a in assets_meta.items()
        }
        item = stac.build_item(
            item_id=dataset_id,
            collection_id=domain,
            bbox=bbox,
            geometry=None,
            datetime_=datetime.now(UTC),
            properties={
                "miso:kind": det.kind,
                "miso:driver": det.driver,
                "miso:source_name": src.name,
                "miso:source_crs": counts.get("source_crs"),
                "miso:object_count": n_objects,
            },
            assets=assets,
        )
        stac.post_item(item, stac_url=stac_url)

        output_uri = f"s3://{processed_bucket}/{key_prefix}/"
        log.info("ingested %s → %s (%d objects, STAC id=%s)", src, output_uri, n_objects, dataset_id)
        return IngestOutcome(
            input_path=str(src),
            kind=det.kind,
            dataset_id=dataset_id,
            status="ingested",
            output_uri=output_uri,
            stac_item_id=dataset_id,
            reason=None,
            counts=counts,
        )


def _vector_bbox_and_assets(tmp_path: Path, vresult):
    # bbox: union over all partition parquet files
    minx = miny = float("inf")
    maxx = maxy = float("-inf")
    for parquet_path in tmp_path.rglob("*.parquet"):
        gdf = gpd.read_parquet(parquet_path)
        if gdf.empty:
            continue
        b = gdf.total_bounds
        minx, miny = min(minx, b[0]), min(miny, b[1])
        maxx, maxy = max(maxx, b[2]), max(maxy, b[3])
    if minx == float("inf"):
        bbox = (-180.0, -90.0, 180.0, 90.0)
    else:
        bbox = (float(minx), float(miny), float(maxx), float(maxy))

    assets = {
        "data": {
            "rel": "",  # directory-level asset
            "media_type": "application/x-parquet",
            "roles": ["data"],
            "title": "GeoParquet dataset (Hive-partitioned on h3_7)",
        },
        "metadata": {
            "rel": "_metadata.json",
            "media_type": "application/json",
            "roles": ["metadata"],
            "title": "Ingestion metadata sidecar",
        },
    }
    # "rel" empty for data means the asset href points at the key_prefix itself.
    # Keep it pointing at one representative partition if we want a concrete URL;
    # simplest: dropping trailing slash signals a directory.
    return bbox, assets


def _raster_bbox_and_assets(rresult):
    with rasterio.open(rresult.output_path) as ds:
        bounds = ds.bounds
        bbox = (bounds.left, bounds.bottom, bounds.right, bounds.top)

    assets = {
        "data": {
            "rel": rresult.output_path.name,
            "media_type": "image/tiff; application=geotiff; profile=cloud-optimized",
            "roles": ["data"],
            "title": "Cloud Optimized GeoTIFF",
        },
        "metadata": {
            "rel": "_metadata.json",
            "media_type": "application/json",
            "roles": ["metadata"],
            "title": "Ingestion metadata sidecar",
        },
    }
    return bbox, assets
