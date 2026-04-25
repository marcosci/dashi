"""Point cloud → Cloud Optimized Point Cloud (COPC). Format-agnostic on input.

Uses the PDAL CLI (`pdal`) as subprocess. PDAL's `writers.copc` produces
spatially-indexed COPC LAZ files that can be range-queried from object storage
without downloading the whole dataset (ADR-004).

Input: LAS / LAZ (any CRS).
Output: `<stem>.copc.laz` in the **source CRS** (no reprojection).

Why no reprojection: COPC stores a single voxel-cube bounding box that has to
be in the same units across X, Y, Z. Reprojecting only X/Y to WGS84 leaves Z
in metres, producing a mixed-unit cube that overflows ±180° longitude and
breaks every COPC reader. Browser-side viewers (e.g. maplibre-gl-lidar) do
the reprojection on read, so we keep the source projected CRS intact.

For STAC we still need a WGS84 bbox — computed via pyproj from the source
bbox at write time.

PDAL must be on PATH. On macOS: `brew install pdal`. On Linux (Debian/Ubuntu):
`apt install pdal`. Falls back to a clear error if PDAL is missing.
"""

from __future__ import annotations

import json
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path

import laspy
from pyproj import CRS, Transformer

TARGET_CRS_EPSG = 4326  # used only for the STAC bbox; COPC stays in source CRS


class PdalNotAvailable(RuntimeError):
    pass


@dataclass
class PointcloudTransformResult:
    input_path: Path
    output_path: Path
    point_count: int
    source_crs: str | None
    target_crs: str
    bounds: tuple[float, float, float, float] | None  # minx, miny, maxx, maxy in EPSG:4326
    reprojected: bool


def transform(src: Path, out_dir: Path) -> PointcloudTransformResult:
    pdal_bin = shutil.which("pdal")
    if not pdal_bin:
        raise PdalNotAvailable(
            "pdal CLI not found on PATH. Install: `brew install pdal` (macOS) "
            "or `apt install pdal` (Debian/Ubuntu)."
        )
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{src.stem}.copc.laz"

    # Inspect source CRS + bounds via laspy (no reprojection)
    with laspy.open(src) as reader:
        header = reader.header
        source_crs = header.parse_crs()
        point_count = int(header.point_count)
        src_mins = header.mins
        src_maxs = header.maxs

    # Build PDAL pipeline (reader → writers.copc) — keep source CRS intact.
    pipeline = {
        "pipeline": [
            str(src),
            {
                "type": "writers.copc",
                "filename": str(out_path),
            },
        ]
    }

    # Run `pdal pipeline`
    proc = subprocess.run(
        [pdal_bin, "pipeline", "--stdin"],
        input=json.dumps(pipeline),
        text=True,
        capture_output=True,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(
            f"pdal pipeline failed (rc={proc.returncode}):\nstdout: {proc.stdout}\nstderr: {proc.stderr}"
        )

    # Compute STAC bbox in WGS84 from the source-CRS corners.
    bounds: tuple[float, float, float, float] | None = None
    if source_crs is not None and src_mins is not None and src_maxs is not None:
        try:
            src_crs = CRS.from_user_input(source_crs)
            tgt_crs = CRS.from_epsg(TARGET_CRS_EPSG)
            if src_crs.equals(tgt_crs):
                bounds = (
                    float(src_mins[0]),
                    float(src_mins[1]),
                    float(src_maxs[0]),
                    float(src_maxs[1]),
                )
            else:
                t = Transformer.from_crs(src_crs, tgt_crs, always_xy=True)
                xs = [src_mins[0], src_maxs[0], src_mins[0], src_maxs[0]]
                ys = [src_mins[1], src_mins[1], src_maxs[1], src_maxs[1]]
                lons, lats = t.transform(xs, ys)
                bounds = (
                    float(min(lons)),
                    float(min(lats)),
                    float(max(lons)),
                    float(max(lats)),
                )
        except Exception:
            bounds = None
    elif src_mins is not None and src_maxs is not None:
        # No source CRS: report raw bounds so the caller can still write STAC,
        # but without a guarantee they are WGS84.
        bounds = (
            float(src_mins[0]),
            float(src_mins[1]),
            float(src_maxs[0]),
            float(src_maxs[1]),
        )

    return PointcloudTransformResult(
        input_path=src,
        output_path=out_path,
        point_count=point_count,
        source_crs=str(source_crs) if source_crs else None,
        target_crs=str(source_crs) if source_crs else "unknown",
        bounds=bounds,
        reprojected=False,
    )
