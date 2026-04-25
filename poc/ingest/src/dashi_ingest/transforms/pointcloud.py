"""Point cloud → Cloud Optimized Point Cloud (COPC). Format-agnostic on input.

Uses the PDAL CLI (`pdal`) as subprocess. PDAL's `writers.copc` produces
spatially-indexed COPC LAZ files that can be range-queried from object storage
without downloading the whole dataset (ADR-004).

Input: LAS / LAZ (any CRS).
Output: `<stem>.copc.laz` reprojected to EPSG:4326 with COPC layout.

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

TARGET_CRS_EPSG = 4326


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

    # Inspect source to determine whether reprojection is required
    with laspy.open(src) as reader:
        header = reader.header
        source_crs = header.parse_crs()
        point_count = int(header.point_count)

    needs_reproject = source_crs is not None and int(source_crs.to_epsg() or 0) != TARGET_CRS_EPSG

    # Build PDAL pipeline (reader → [reprojection] → writers.copc)
    stages: list[dict | str] = [str(src)]
    if needs_reproject:
        stages.append(
            {
                "type": "filters.reprojection",
                "out_srs": f"EPSG:{TARGET_CRS_EPSG}",
            }
        )
    stages.append(
        {
            "type": "writers.copc",
            "filename": str(out_path),
        }
    )
    pipeline = {"pipeline": stages}

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

    # Probe output bounds via laspy (bounds in target CRS)
    with laspy.open(out_path) as reader:
        header = reader.header
        if header.mins is not None and header.maxs is not None:
            bounds = (
                float(header.mins[0]),
                float(header.mins[1]),
                float(header.maxs[0]),
                float(header.maxs[1]),
            )
        else:
            bounds = None

    return PointcloudTransformResult(
        input_path=src,
        output_path=out_path,
        point_count=point_count,
        source_crs=str(source_crs) if source_crs else None,
        target_crs=f"EPSG:{TARGET_CRS_EPSG}",
        bounds=bounds,
        reprojected=needs_reproject,
    )
