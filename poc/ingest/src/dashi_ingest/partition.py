"""H3 partitioning — geometry → H3 cell at configurable resolution.

ADR-008 chose H3 as the platform-wide spatial partitioning scheme. We use
centroids for assignment: simple, deterministic, correct for the majority of
features. Very large features (bigger than an H3 cell at the target resolution)
receive the cell of their bounding-box centroid; the cell is tagged with a
`cross_cell` marker so query planners know to scan neighbours as well.
"""

from __future__ import annotations

from dataclasses import dataclass

import h3
from shapely.geometry.base import BaseGeometry


@dataclass(frozen=True)
class PartitionAssignment:
    h3_cell: str
    cross_cell: bool


def assign_cell(geom: BaseGeometry, resolution: int = 7) -> PartitionAssignment:
    """Assign one H3 cell per geometry. Returns 15-char H3 string.

    Resolution 7 ~ 5 km² edge. See ADR-008 for per-resolution budget.
    """
    if geom is None or geom.is_empty:
        raise ValueError("cannot assign H3 cell to empty geometry")

    # Centroid-based assignment is cheap and deterministic
    centroid = geom.centroid
    cell = h3.latlng_to_cell(centroid.y, centroid.x, resolution)

    # Detect cross-cell features: cell diameter at this resolution vs geom diagonal
    edge_km = h3.average_hexagon_edge_length(resolution, unit="km")
    diag_km = _approx_diagonal_km(geom)
    cross_cell = diag_km > edge_km

    return PartitionAssignment(h3_cell=cell, cross_cell=cross_cell)


def _approx_diagonal_km(geom: BaseGeometry) -> float:
    minx, miny, maxx, maxy = geom.bounds
    # Rough WGS84 great-circle approximation — sufficient for cross-cell flag
    lat_km = (maxy - miny) * 111.0
    lon_km = (maxx - minx) * 111.0 * max(0.1, abs(1.0))  # equator-biased upper bound
    return (lat_km**2 + lon_km**2) ** 0.5
