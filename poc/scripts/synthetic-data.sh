#!/usr/bin/env bash
# Generate small, deterministic synthetic samples for dashi demos and
# E2E tests. Produces:
#   - sample-points.geojson  (vector, ~1 KiB)
#   - sample-grid.tif        (raster, GeoTIFF, ~10 KiB)
#   - sample-features.parquet (tabular GeoParquet, ~5 KiB)
#
# Output dir defaults to `./.dashi-samples/`; override with $OUT_DIR.
# Optional: pass `--upload <domain>` to push them straight into the
# landing bucket via `dashictl ingest --dry-run` so the generator
# doubles as a smoke driver.
#
# Deterministic by design — the same inputs always produce the same
# bytes. Diffs in CI mean a real change, never RNG drift.

set -euo pipefail

OUT_DIR="${OUT_DIR:-$(pwd)/.dashi-samples}"
mkdir -p "$OUT_DIR"

UPLOAD_DOMAIN=""
if [[ "${1:-}" == "--upload" ]]; then
  UPLOAD_DOMAIN="${2:?--upload requires a domain id}"
fi

echo "→ generating synthetic samples in $OUT_DIR"

# 1. GeoJSON — six points around a fixed European bbox.
cat > "$OUT_DIR/sample-points.geojson" <<'EOF'
{
  "type": "FeatureCollection",
  "name": "dashi-synthetic-points",
  "crs": {"type":"name","properties":{"name":"urn:ogc:def:crs:OGC:1.3:CRS84"}},
  "features": [
    {"type":"Feature","properties":{"id":1,"name":"alpha"},  "geometry":{"type":"Point","coordinates":[12.5, 55.6]}},
    {"type":"Feature","properties":{"id":2,"name":"bravo"},  "geometry":{"type":"Point","coordinates":[13.4, 52.5]}},
    {"type":"Feature","properties":{"id":3,"name":"charlie"},"geometry":{"type":"Point","coordinates":[ 8.5, 47.4]}},
    {"type":"Feature","properties":{"id":4,"name":"delta"},  "geometry":{"type":"Point","coordinates":[ 2.3, 48.9]}},
    {"type":"Feature","properties":{"id":5,"name":"echo"},   "geometry":{"type":"Point","coordinates":[-0.1, 51.5]}},
    {"type":"Feature","properties":{"id":6,"name":"foxtrot"},"geometry":{"type":"Point","coordinates":[ 4.9, 52.4]}}
  ]
}
EOF
echo "  ✓ sample-points.geojson"

# 2. GeoTIFF + 3. GeoParquet — Python (we already require GDAL elsewhere,
#    but here we keep deps minimal: numpy + rasterio + geopandas).
python3 - "$OUT_DIR" <<'PYEOF'
import sys
from pathlib import Path

out = Path(sys.argv[1])

# GeoTIFF — a 32×32 deterministic gradient over a fixed bbox.
try:
    import numpy as np
    import rasterio
    from rasterio.transform import from_origin

    arr = np.fromfunction(
        lambda i, j: ((i * 8 + j * 4) % 256).astype("uint8"),
        (32, 32),
    )
    transform = from_origin(west=0.0, north=10.0, xsize=0.1, ysize=0.1)
    with rasterio.open(
        out / "sample-grid.tif",
        "w",
        driver="GTiff",
        height=32,
        width=32,
        count=1,
        dtype="uint8",
        crs="EPSG:4326",
        transform=transform,
        compress="deflate",
    ) as dst:
        dst.write(arr, 1)
    print("  ✓ sample-grid.tif")
except ImportError as e:
    print(f"  ⊘ sample-grid.tif (skipped: {e}; pip install rasterio numpy)")

# GeoParquet — same six points as the GeoJSON, minimal table.
try:
    import geopandas as gpd
    from shapely.geometry import Point

    rows = [
        {"id": 1, "name": "alpha",   "geometry": Point(12.5, 55.6)},
        {"id": 2, "name": "bravo",   "geometry": Point(13.4, 52.5)},
        {"id": 3, "name": "charlie", "geometry": Point(8.5, 47.4)},
        {"id": 4, "name": "delta",   "geometry": Point(2.3, 48.9)},
        {"id": 5, "name": "echo",    "geometry": Point(-0.1, 51.5)},
        {"id": 6, "name": "foxtrot", "geometry": Point(4.9, 52.4)},
    ]
    gdf = gpd.GeoDataFrame(rows, crs="EPSG:4326")
    gdf.to_parquet(out / "sample-features.parquet", compression="snappy")
    print("  ✓ sample-features.parquet")
except ImportError as e:
    print(f"  ⊘ sample-features.parquet (skipped: {e}; pip install geopandas pyarrow)")
PYEOF

if [[ -n "$UPLOAD_DOMAIN" ]]; then
  if ! command -v dashictl >/dev/null 2>&1; then
    echo "  ⊘ --upload requested but \`dashictl\` not on PATH"
    echo "    install via: cd poc/dashictl && cargo install --path . --locked"
    exit 1
  fi
  echo ""
  echo "→ uploading samples into domain '$UPLOAD_DOMAIN' (--dry-run)"
  for f in "$OUT_DIR"/sample-*; do
    [[ -f "$f" ]] || continue
    echo ""
    echo "  → $f"
    dashictl ingest "$f" --domain "$UPLOAD_DOMAIN" --dry-run || true
  done
fi

echo ""
echo "✓ synthetic samples ready in $OUT_DIR"
echo "  Use them to feed E2E tests, the catalog viewer, or new domain demos."
