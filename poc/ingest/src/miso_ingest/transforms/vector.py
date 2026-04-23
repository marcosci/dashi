"""Vector → GeoParquet + H3 Hive partitioning. Format-agnostic on input."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import geopandas as gpd
from pyproj import CRS
from shapely.validation import make_valid

from miso_ingest.partition import assign_cell

TARGET_CRS = "EPSG:4326"


@dataclass
class VectorTransformResult:
    input_path: Path
    output_dir: Path
    feature_count: int
    repaired_count: int
    source_crs: str | None
    target_crs: str
    h3_resolution: int
    partitions: int


def transform(
    src: Path,
    out_dir: Path,
    *,
    h3_resolution: int = 7,
    repair_invalid: bool = True,
) -> VectorTransformResult:
    """Read any OGR-readable vector, reproject to EPSG:4326, write Hive-partitioned GeoParquet."""
    gdf = gpd.read_file(src)
    feature_count = len(gdf)
    source_crs = str(gdf.crs) if gdf.crs else None

    # Empty input → write an empty partition so downstream tools see a dataset marker
    if feature_count == 0:
        out_dir.mkdir(parents=True, exist_ok=True)
        (out_dir / "_EMPTY").write_text("no features in source")
        return VectorTransformResult(
            input_path=src,
            output_dir=out_dir,
            feature_count=0,
            repaired_count=0,
            source_crs=source_crs,
            target_crs=TARGET_CRS,
            h3_resolution=h3_resolution,
            partitions=0,
        )

    # Reproject only if needed (avoids numerical drift for already-4326 inputs)
    if gdf.crs is None:
        raise ValueError(
            f"{src}: no CRS declared — validator should have rejected this already"
        )
    if CRS.from_user_input(gdf.crs) != CRS.from_user_input(TARGET_CRS):
        gdf = gdf.to_crs(TARGET_CRS)

    # Repair invalid geometries
    repaired = 0
    if repair_invalid:
        invalid_mask = ~gdf.geometry.is_valid
        if invalid_mask.any():
            repaired = int(invalid_mask.sum())
            gdf.loc[invalid_mask, "geometry"] = gdf.loc[invalid_mask, "geometry"].apply(
                make_valid
            )

    # Assign H3 cells (centroid-based) + cross-cell flag
    gdf["h3_7"] = gdf.geometry.apply(lambda g: assign_cell(g, resolution=h3_resolution).h3_cell)

    out_dir.mkdir(parents=True, exist_ok=True)
    partitions = 0
    for cell, group in gdf.groupby("h3_7"):
        part_dir = out_dir / f"h3_{h3_resolution}={cell}"
        part_dir.mkdir(parents=True, exist_ok=True)
        part_path = part_dir / "part-0.parquet"
        group.drop(columns=["h3_7"]).to_parquet(part_path, index=False)
        partitions += 1

    return VectorTransformResult(
        input_path=src,
        output_dir=out_dir,
        feature_count=feature_count,
        repaired_count=repaired,
        source_crs=source_crs,
        target_crs=TARGET_CRS,
        h3_resolution=h3_resolution,
        partitions=partitions,
    )
