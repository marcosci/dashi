"""Generic validation at the Landing → Processed boundary.

Validators are format-agnostic. They answer:

    - is the file readable at all?
    - does it declare a CRS?
    - are the geometries valid (vector) / does it have a valid bbox (raster)?
    - is it non-empty?

No product-specific schema checks. Those belong in the domain-specific
enrichment pipeline (Strang D / E), not at the zone boundary.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

import pyogrio
import rasterio
import shapely.geometry  # noqa: F401 (used via geopandas)
import shapely.validation
from pyproj import CRS


@dataclass
class ValidationResult:
    ok: bool
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)

    def fail(self, msg: str) -> None:
        self.ok = False
        self.errors.append(msg)

    def warn(self, msg: str) -> None:
        self.warnings.append(msg)

    def to_dict(self) -> dict:
        return {"ok": self.ok, "errors": self.errors, "warnings": self.warnings}


def validate_vector(path: Path, *, sample_geometries: int = 1000) -> ValidationResult:
    """Validate a vector file using pyogrio (no full read into memory).

    Sampling of geometries limits cost on very large datasets while still
    catching common issues. `sample_geometries=0` disables sampling.
    """
    result = ValidationResult(ok=True)
    try:
        info = pyogrio.read_info(path)
    except Exception as e:  # noqa: BLE001
        result.fail(f"unreadable: {e}")
        return result

    if info.get("features", 0) == 0:
        result.fail("zero features")

    crs_wkt = info.get("crs")
    if not crs_wkt:
        result.fail("missing CRS — producer must declare coordinate reference system")
    else:
        try:
            CRS.from_user_input(crs_wkt)
        except Exception as e:  # noqa: BLE001
            result.fail(f"unparsable CRS: {e}")

    if info.get("geometry_type") is None:
        result.warn("geometry type is None (attribute-only dataset?)")

    # Geometry-validity spot check
    try:
        n = info.get("features", 0)
        to_read = min(n, sample_geometries) if sample_geometries else n
        if to_read > 0:
            geoms, _ = pyogrio.read_dataframe(
                path, max_features=to_read, read_geometry=True
            ), None
            invalid = 0
            for g in geoms.geometry:
                if g is None:
                    continue
                if not g.is_valid:
                    invalid += 1
            if invalid:
                result.warn(
                    f"{invalid}/{to_read} sampled geometries invalid — will be repaired in transform"
                )
    except Exception as e:  # noqa: BLE001
        result.warn(f"geometry sample skipped: {e}")

    return result


def validate_raster(path: Path) -> ValidationResult:
    result = ValidationResult(ok=True)
    try:
        with rasterio.open(path) as src:
            if src.count == 0:
                result.fail("zero bands")
            if src.width == 0 or src.height == 0:
                result.fail("zero-dimension raster")
            if src.crs is None:
                result.fail("missing CRS — producer must declare coordinate reference system")
            if src.bounds is None or any(v is None for v in src.bounds):
                result.fail("missing bounds")
    except Exception as e:  # noqa: BLE001
        result.fail(f"unreadable: {e}")
    return result
