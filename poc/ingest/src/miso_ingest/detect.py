"""Format detection — agnostic to specific sample data.

Routes every file to one of three kinds: `vector`, `raster`, `unknown`.
Detection uses file extension for speed, then verifies with a GDAL/OGR probe.
Every driver OGR/GDAL supports is accepted; no per-product hard-coding.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Literal

import pyogrio
import rasterio
from rasterio.errors import RasterioIOError

Kind = Literal["vector", "raster", "unknown"]

VECTOR_EXTS: frozenset[str] = frozenset(
    {".shp", ".gpkg", ".geojson", ".json", ".kml", ".kmz", ".fgb", ".tab", ".mif"}
)
RASTER_EXTS: frozenset[str] = frozenset(
    {".tif", ".tiff", ".cog", ".vrt", ".nc", ".jp2", ".img", ".hgt", ".asc", ".dem"}
)
SIDECAR_EXTS: frozenset[str] = frozenset(
    {".shx", ".dbf", ".prj", ".cpg", ".qix", ".qpj", ".sbn", ".sbx", ".atx", ".aux", ".xml"}
)


@dataclass(frozen=True)
class Detection:
    path: Path
    kind: Kind
    driver: str | None
    reason: str


def _probe_vector(path: Path) -> tuple[str | None, str]:
    try:
        info = pyogrio.read_info(path)
        return info.get("driver"), "ok"
    except Exception as e:  # noqa: BLE001
        return None, f"pyogrio refused: {e}"


def _probe_raster(path: Path) -> tuple[str | None, str]:
    try:
        with rasterio.open(path) as src:
            return src.driver, "ok"
    except (RasterioIOError, OSError) as e:
        return None, f"rasterio refused: {e}"


def classify(path: Path) -> Detection:
    """Classify a single file path as vector, raster, or unknown."""
    ext = path.suffix.lower()
    if ext in SIDECAR_EXTS:
        return Detection(path, "unknown", None, "sidecar — ignore, companion file of primary")

    if ext in VECTOR_EXTS:
        driver, reason = _probe_vector(path)
        kind: Kind = "vector" if driver else "unknown"
        return Detection(path, kind, driver, reason)

    if ext in RASTER_EXTS:
        driver, reason = _probe_raster(path)
        kind = "raster" if driver else "unknown"
        return Detection(path, kind, driver, reason)

    # Fallback: probe both. Vector first (cheaper).
    driver, reason = _probe_vector(path)
    if driver:
        return Detection(path, "vector", driver, f"extension unknown; {reason}")
    driver, reason = _probe_raster(path)
    if driver:
        return Detection(path, "raster", driver, f"extension unknown; {reason}")
    return Detection(path, "unknown", None, "no driver accepted")


def discover(root: Path) -> list[Detection]:
    """Walk a directory and return Detection for every primary file.

    Sidecar-only files (.shx, .dbf, ...) are listed with kind=unknown; callers
    should ignore them. Directories are descended recursively.
    """
    if root.is_file():
        return [classify(root)]
    results: list[Detection] = []
    for p in sorted(root.rglob("*")):
        if p.is_file():
            results.append(classify(p))
    return results
