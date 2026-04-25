"""Format detection — agnostic to specific sample data.

Each primary file resolves to one or more Detections. Multi-layer containers
(GeoPackage, FileGDB, KML with folders, SpatiaLite, ...) fan out into one
Detection per layer so downstream transforms can ingest layers independently.

Classification outcomes:

- `vector` — an OGR-readable layer within the file
- `raster` — a GDAL-readable raster dataset
- `pointcloud` — LAS/LAZ (handled by pointcloud transform, not GDAL)
- `unknown` — sidecar file, layer-container metadata, or unrecognised format
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Literal

import pyogrio
import rasterio
from rasterio.errors import RasterioIOError

Kind = Literal["vector", "raster", "pointcloud", "unknown"]

VECTOR_EXTS: frozenset[str] = frozenset(
    {".shp", ".gpkg", ".geojson", ".json", ".kml", ".kmz", ".fgb", ".tab", ".mif", ".gdb"}
)
RASTER_EXTS: frozenset[str] = frozenset(
    {".tif", ".tiff", ".cog", ".vrt", ".nc", ".jp2", ".img", ".hgt", ".asc", ".dem"}
)
POINTCLOUD_EXTS: frozenset[str] = frozenset({".las", ".laz", ".copc"})
SIDECAR_EXTS: frozenset[str] = frozenset(
    {".shx", ".dbf", ".prj", ".cpg", ".qix", ".qpj", ".sbn", ".sbx", ".atx", ".aux", ".xml"}
)
# Layer names emitted by QGIS / other GIS tools but carrying no spatial data
IGNORABLE_LAYERS: frozenset[str] = frozenset({"layer_styles", "qgis_projects"})


@dataclass(frozen=True)
class Detection:
    path: Path
    kind: Kind
    driver: str | None
    reason: str
    layer: str | None = None  # for multi-layer containers; None = single/default


def _probe_vector_layers(path: Path) -> list[tuple[str, str | None]]:
    """Return [(layer_name, driver), ...] — empty list when pyogrio cannot read."""
    try:
        layers = pyogrio.list_layers(path)
        if layers is None or len(layers) == 0:
            # Single-layer format (Shapefile, FlatGeobuf, ...): use base info call
            info = pyogrio.read_info(path)
            driver = info.get("driver")
            return [("", driver)] if driver else []
        driver = pyogrio.read_info(path).get("driver")
        # pyogrio.list_layers returns a numpy array of (name, geom_type) pairs.
        # Filter out ignorable catalogue layers.
        out: list[tuple[str, str | None]] = []
        for row in layers:
            name = str(row[0]) if len(row) > 0 else ""
            if name in IGNORABLE_LAYERS:
                continue
            out.append((name, driver))
        return out
    except Exception:  # noqa: BLE001
        return []


def _probe_raster(path: Path) -> tuple[str | None, str]:
    try:
        with rasterio.open(path) as src:
            return src.driver, "ok"
    except (RasterioIOError, OSError) as e:
        return None, f"rasterio refused: {e}"


def classify(path: Path) -> list[Detection]:
    """Classify a single file path. Returns 1+ Detections (one per layer for multi-layer formats)."""
    ext = path.suffix.lower()

    if ext in SIDECAR_EXTS:
        return [Detection(path, "unknown", None, "sidecar — companion file of a primary", None)]

    if ext in POINTCLOUD_EXTS:
        # Accept at extension level; deeper validation happens in the transform
        return [Detection(path, "pointcloud", "LAS/LAZ", "ok (ext-based)", None)]

    if ext in VECTOR_EXTS:
        layers = _probe_vector_layers(path)
        if not layers:
            return [Detection(path, "unknown", None, "pyogrio refused", None)]
        return [Detection(path, "vector", drv, "ok", lyr or None) for lyr, drv in layers]

    if ext in RASTER_EXTS:
        driver, reason = _probe_raster(path)
        kind: Kind = "raster" if driver else "unknown"
        return [Detection(path, kind, driver, reason, None)]

    # Unknown extension — probe both
    layers = _probe_vector_layers(path)
    if layers:
        return [
            Detection(path, "vector", drv, f"extension unknown; {'ok'}", lyr or None) for lyr, drv in layers
        ]
    driver, reason = _probe_raster(path)
    if driver:
        return [Detection(path, "raster", driver, f"extension unknown; {reason}", None)]
    return [Detection(path, "unknown", None, "no driver accepted", None)]


def discover(root: Path) -> list[Detection]:
    """Walk a path and return Detection entries for every primary file/layer."""
    if root.is_file():
        return classify(root)
    results: list[Detection] = []
    for p in sorted(root.rglob("*")):
        if p.is_file():
            results.extend(classify(p))
    return results
