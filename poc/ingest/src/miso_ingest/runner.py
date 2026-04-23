"""End-to-end ingestion runner. Glues detect → validate → transform → upload → catalog."""

from __future__ import annotations

import hashlib
import json
import logging
import tempfile
from dataclasses import asdict, dataclass
from datetime import UTC, datetime
from pathlib import Path

import pystac
import rasterio

from miso_ingest import detect, stac, storage, validators
from miso_ingest.transforms import pointcloud as pointcloud_transform
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
    layer: str | None
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
    det: detect.Detection,
    *,
    domain: str,
    processed_bucket: str,
    stac_url: str,
    collection_description: str,
    s3_cfg: storage.S3Config,
    h3_resolution: int = 7,
) -> IngestOutcome:
    """Ingest a single detection (file + optional layer). Uploads + catalogs."""
    src = det.path
    if det.kind == "unknown":
        return IngestOutcome(
            input_path=str(src),
            kind="unknown",
            dataset_id="",
            status="skipped",
            output_uri=None,
            stac_item_id=None,
            layer=det.layer,
            reason=det.reason,
            counts={},
        )

    # Validate
    if det.kind == "vector":
        vr = validators.validate_vector(src, layer=det.layer)
    elif det.kind == "raster":
        vr = validators.validate_raster(src)
    elif det.kind == "pointcloud":
        try:
            vr = validators.validate_pointcloud(src)
        except ImportError as e:
            return IngestOutcome(
                input_path=str(src),
                kind=det.kind,
                dataset_id="",
                status="skipped",
                output_uri=None,
                stac_item_id=None,
                layer=det.layer,
                reason=f"pointcloud deps missing: {e}",
                counts={},
            )
    else:
        return IngestOutcome(
            input_path=str(src),
            kind=det.kind,
            dataset_id="",
            status="skipped",
            output_uri=None,
            stac_item_id=None,
            layer=det.layer,
            reason=f"unsupported kind: {det.kind}",
            counts={},
        )

    if not vr.ok:
        return IngestOutcome(
            input_path=str(src),
            kind=det.kind,
            dataset_id="",
            status="rejected",
            output_uri=None,
            stac_item_id=None,
            layer=det.layer,
            reason="; ".join(vr.errors),
            counts={"warnings": len(vr.warnings)},
        )

    # Per-layer datasets get their layer name hashed into the id
    dataset_id = _dataset_id(src, extra=(det.layer or "").encode())
    with tempfile.TemporaryDirectory(prefix="miso-ingest-") as tmp:
        tmp_path = Path(tmp)

        if det.kind == "vector":
            vresult = vector_transform.transform(
                src, tmp_path, h3_resolution=h3_resolution, layer=det.layer
            )
            if vresult.bbox is None:
                return IngestOutcome(
                    input_path=str(src),
                    kind="vector",
                    dataset_id=dataset_id,
                    status="rejected",
                    output_uri=None,
                    stac_item_id=None,
                    layer=det.layer,
                    reason="no partitions written (all features lacked geometry?)",
                    counts={"features": vresult.feature_count},
                )
            bbox = vresult.bbox
            assets_meta = _vector_assets()
            counts = {
                "features": vresult.feature_count,
                "repaired": vresult.repaired_count,
                "partitions": vresult.partitions,
                "source_crs": vresult.source_crs,
                "layer": det.layer,
            }
        elif det.kind == "raster":
            rresult = raster_transform.transform(src, tmp_path)
            bbox = _raster_bbox(rresult.output_path)
            assets_meta = _raster_assets(rresult.output_path.name)
            counts = {
                "bands": rresult.bands,
                "width": rresult.width,
                "height": rresult.height,
                "source_crs": rresult.source_crs,
                "reprojected": rresult.reprojected,
                "overviews": rresult.overviews,
            }
        else:  # pointcloud
            try:
                pcresult = pointcloud_transform.transform(src, tmp_path)
            except pointcloud_transform.PdalNotAvailable as e:
                return IngestOutcome(
                    input_path=str(src),
                    kind="pointcloud",
                    dataset_id=dataset_id,
                    status="skipped",
                    output_uri=None,
                    stac_item_id=None,
                    layer=det.layer,
                    reason=str(e),
                    counts={},
                )
            if pcresult.bounds is None:
                return IngestOutcome(
                    input_path=str(src),
                    kind="pointcloud",
                    dataset_id=dataset_id,
                    status="rejected",
                    output_uri=None,
                    stac_item_id=None,
                    layer=det.layer,
                    reason="COPC produced but bounds missing",
                    counts={"points": pcresult.point_count},
                )
            bbox = pcresult.bounds
            assets_meta = _pointcloud_assets(pcresult.output_path.name)
            counts = {
                "points": pcresult.point_count,
                "source_crs": pcresult.source_crs,
                "reprojected": pcresult.reprojected,
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

        key_prefix = storage.processed_prefix(domain, dataset_id, det.kind)
        n_objects = storage.upload_tree(tmp_path, processed_bucket, key_prefix, s3_cfg)

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
                "miso:source_layer": det.layer,
                "miso:source_crs": counts.get("source_crs"),
                "miso:object_count": n_objects,
            },
            assets=assets,
        )
        stac.post_item(item, stac_url=stac_url)

        output_uri = f"s3://{processed_bucket}/{key_prefix}/"
        log.info(
            "ingested %s%s → %s (%d objects, STAC id=%s)",
            src,
            f"[layer={det.layer}]" if det.layer else "",
            output_uri,
            n_objects,
            dataset_id,
        )
        return IngestOutcome(
            input_path=str(src),
            kind=det.kind,
            dataset_id=dataset_id,
            status="ingested",
            output_uri=output_uri,
            stac_item_id=dataset_id,
            layer=det.layer,
            reason=None,
            counts=counts,
        )


def _vector_assets() -> dict:
    return {
        "data": {
            "rel": "",
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


def _raster_assets(filename: str) -> dict:
    return {
        "data": {
            "rel": filename,
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


def _pointcloud_assets(filename: str) -> dict:
    return {
        "data": {
            "rel": filename,
            "media_type": "application/vnd.laszip+copc",
            "roles": ["data"],
            "title": "Cloud Optimized Point Cloud",
        },
        "metadata": {
            "rel": "_metadata.json",
            "media_type": "application/json",
            "roles": ["metadata"],
            "title": "Ingestion metadata sidecar",
        },
    }


def _raster_bbox(path: Path) -> tuple[float, float, float, float]:
    with rasterio.open(path) as ds:
        b = ds.bounds
        return (b.left, b.bottom, b.right, b.top)
