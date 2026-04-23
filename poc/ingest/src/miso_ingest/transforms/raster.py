"""Raster → Cloud Optimized GeoTIFF. Format-agnostic on input."""

from __future__ import annotations

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
    resolution_m: tuple[float, float] | None
    overviews: list[int]


def transform(src: Path, out_dir: Path, *, overview_levels: tuple[int, ...] = (2, 4, 8, 16)) -> RasterTransformResult:
    """Reproject (if needed) to EPSG:4326, write COG with overviews."""
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{src.stem}.tif"

    with rasterio.open(src) as source:
        source_crs = str(source.crs) if source.crs else None
        if source.crs is None:
            raise ValueError(
                f"{src}: no CRS declared — validator should have rejected this already"
            )

        needs_reproject = str(source.crs) != TARGET_CRS

        if needs_reproject:
            # Write reprojected COG via in-memory WarpedVRT → rio_copy to COG
            from rasterio.vrt import WarpedVRT

            dst_transform, dst_width, dst_height = calculate_default_transform(
                source.crs, TARGET_CRS, source.width, source.height, *source.bounds
            )
            vrt_profile = {
                "crs": TARGET_CRS,
                "transform": dst_transform,
                "width": dst_width,
                "height": dst_height,
                "resampling": Resampling.nearest,
            }
            with WarpedVRT(source, **vrt_profile) as vrt:
                cog_profile = vrt.profile.copy()
                cog_profile.update(driver="COG", compress="DEFLATE", BIGTIFF="IF_SAFER")
                rio_copy(vrt, out_path, driver="COG", compress="DEFLATE", BIGTIFF="IF_SAFER")
        else:
            cog_profile = source.profile.copy()
            cog_profile.update(driver="COG", compress="DEFLATE", BIGTIFF="IF_SAFER")
            rio_copy(source, out_path, driver="COG", compress="DEFLATE", BIGTIFF="IF_SAFER")

    # Re-open to gather output attributes + add overviews (COG driver often builds them)
    with rasterio.open(out_path, "r+") as dst:
        if not dst.overviews(1):
            dst.build_overviews(list(overview_levels), Resampling.average)
            dst.update_tags(ns="rio_overview", resampling="average")
        overviews = dst.overviews(1)
        bands = dst.count
        width = dst.width
        height = dst.height
        res = dst.res if dst.res else None

    return RasterTransformResult(
        input_path=src,
        output_path=out_path,
        bands=bands,
        width=width,
        height=height,
        source_crs=source_crs,
        target_crs=TARGET_CRS,
        resolution_m=res,
        overviews=list(overviews),
    )
