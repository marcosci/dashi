"""Raster → Cloud Optimized GeoTIFF. Format-agnostic on input.

Two-step pipeline — write a plain GTiff temp first (whether a reprojection
happens or not), then convert to COG. This avoids `rio_copy` refusing to
rewrite inputs that already have COG layout and keeps the transform
deterministic across input formats.
"""

from __future__ import annotations

import tempfile
from dataclasses import dataclass
from pathlib import Path

import rasterio
from rasterio.enums import Resampling
from rasterio.shutil import copy as rio_copy
from rasterio.warp import calculate_default_transform, reproject

TARGET_CRS = "EPSG:4326"


@dataclass
class RasterTransformResult:
    input_path: Path
    output_path: Path
    bands: int
    width: int
    height: int
    source_crs: str | None
    target_crs: str
    resolution: tuple[float, float] | None
    overviews: list[int]
    reprojected: bool


def transform(src: Path, out_dir: Path) -> RasterTransformResult:
    """Reproject (if needed) to EPSG:4326 and write Cloud Optimized GeoTIFF."""
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{src.stem}.tif"

    with rasterio.open(src) as source:
        source_crs = str(source.crs) if source.crs else None
        if source.crs is None:
            raise ValueError(f"{src}: no CRS declared — validator should have rejected this already")
        reprojected = str(source.crs) != TARGET_CRS

        with tempfile.NamedTemporaryFile(suffix=".tif", delete=False) as tmp:
            tmp_path = Path(tmp.name)

        try:
            if reprojected:
                dst_transform, dst_width, dst_height = calculate_default_transform(
                    source.crs,
                    TARGET_CRS,
                    source.width,
                    source.height,
                    *source.bounds,
                )
                profile = source.profile.copy()
                profile.update(
                    driver="GTiff",
                    crs=TARGET_CRS,
                    transform=dst_transform,
                    width=dst_width,
                    height=dst_height,
                    tiled=True,
                    blockxsize=512,
                    blockysize=512,
                )
                with rasterio.open(tmp_path, "w", **profile) as dst:
                    for band_idx in range(1, source.count + 1):
                        reproject(
                            source=rasterio.band(source, band_idx),
                            destination=rasterio.band(dst, band_idx),
                            src_transform=source.transform,
                            src_crs=source.crs,
                            dst_transform=dst_transform,
                            dst_crs=TARGET_CRS,
                            resampling=Resampling.nearest,
                        )
            else:
                # No reprojection needed — rewrite to GTiff temp for a uniform
                # conversion step into COG below.
                profile = source.profile.copy()
                profile.update(
                    driver="GTiff",
                    tiled=True,
                    blockxsize=512,
                    blockysize=512,
                )
                with rasterio.open(tmp_path, "w", **profile) as dst:
                    for band_idx in range(1, source.count + 1):
                        dst.write(source.read(band_idx), band_idx)

            # Step 2 — convert plain GTiff temp to COG
            rio_copy(
                tmp_path,
                out_path,
                driver="COG",
                compress="DEFLATE",
                BIGTIFF="IF_SAFER",
                OVERVIEWS="AUTO",
                OVERVIEW_RESAMPLING="average",
            )
        finally:
            tmp_path.unlink(missing_ok=True)

    # Read back for metadata
    with rasterio.open(out_path) as dst:
        overviews = dst.overviews(1)
        bands = dst.count
        width = dst.width
        height = dst.height
        res = tuple(dst.res) if dst.res else None

    return RasterTransformResult(
        input_path=src,
        output_path=out_path,
        bands=bands,
        width=width,
        height=height,
        source_crs=source_crs,
        target_crs=TARGET_CRS,
        resolution=res,
        overviews=list(overviews),
        reprojected=reprojected,
    )
