# PoC — Phase 0 Implementation

Local k3s-based Proof of Concept validating the zone architecture end-to-end with real sample data.

**Owner:** Marco Sciaini · **Substrate:** k3s (lokal) + GitHub Actions + Pages · **Scope:** Gelände & Umwelt, ~500MB–1GB sample data

## Planned Layout

```
poc/
├── README.md                # This file
├── Makefile                 # Top-level targets (bootstrap / deploy / smoke / teardown)
├── sample-data/             # Local sample data — .gitignored, NOT committed
│   └── .gitkeep
├── manifests/               # k8s manifests / Helm values
│   ├── rustfs/              # S3-compatible object storage (see ADR-001)
│   ├── pgstac/              # pgstac Postgres + stac-fastapi API
│   ├── titiler/             # COG tile endpoint (arm64 rebuild via titiler-endpoint/)
│   ├── duckdb-endpoint/     # SQL endpoint over GeoParquet in RustFS
│   └── prefect/
├── titiler-endpoint/        # Dockerfile + FastAPI app (rio-tiler based, arm64-native)
├── duckdb-endpoint/         # Dockerfile + FastAPI app (DuckDB SELECT-only)
├── ingest/                  # Python ingestion + standardization
│   ├── pyproject.toml
│   ├── src/
│   │   ├── adapters/        # Format detection (GeoTIFF, Shapefile, KML, GPKG)
│   │   ├── validators/      # GDAL-based validation
│   │   ├── transforms/      # KRS → EPSG:4326, COG/GeoParquet conversion
│   │   ├── partitioning/    # H3 resolution 7
│   │   └── catalog/         # STAC item generation
│   └── tests/
├── flows/                   # Prefect flows orchestrating ingest pipeline
└── smoke/                   # End-to-end smoke tests for Gate-1 equivalent
```

## Bootstrap (once Phase 0 begins)

```bash
make k3s-up          # Install k3s/k3d, configure kubectl
make storage-deploy  # Deploy RustFS + create zone buckets (landing/processed/curated)
make catalog-deploy  # Deploy stac-fastapi + PostgreSQL
make serving-deploy  # Deploy TiTiler + DuckDB endpoint
make prefect-up      # Start Prefect server
make ingest-sample   # Load sample-data/ through full pipeline
make smoke           # Run Gate-1 acceptance checks
```

## Current State

- **Strang B (cluster + storage):** ✅ RustFS live in `miso-platform`, buckets `landing/processed/curated`
- **Strang D (catalog):** ✅ pgstac + stac-fastapi live in `miso-catalog`
- **Strang C (ingestion):** ✅ `miso-ingest` CLI format-agnostic (vector, raster, point cloud). End-to-end proven:
    - 29 Dresden OSM shapefiles → 366k features → 3709 H3-7 partitions → 28 STAC items (1 legitimate rejection, empty coastline)
    - 1 GeoTIFF (EPSG:32631) → reprojected COG with overviews
    - 1 GeoPackage with 4 usable layers → 4 separate STAC items
    - 1 LAZ (NZGD2000 NZTM2000, 28.8M points, 118 MB) → 97 MB COPC reprojected to EPSG:4326 via PDAL
- **Strang E (serving):** ✅ TiTiler + DuckDB SQL endpoint live in `miso-serving`
    - `GET /cog/info` + `/cog/tiles/{z}/{x}/{y}.png` on COGs in RustFS (custom arm64 image — upstream TiTiler is amd64-only)
    - `POST /query` on DuckDB with SELECT-only allowlist, spatial extension, httpfs pointed at RustFS. `ST_Intersects` over the 367k-feature Dresden dataset returns in <2 s (BBox around Frauenkirche matched 10490 features)
- **Strang F (Prefect + Gate-1):** ⏳

## Ingestion package

```
poc/ingest/
└── src/miso_ingest/
    ├── cli.py          # `miso-ingest scan | ingest`
    ├── detect.py       # format classification (vector / raster / unknown)
    ├── validators.py   # CRS present, geometries valid, non-empty
    ├── partition.py    # H3 cell assignment (centroid-based)
    ├── storage.py      # S3 client + upload
    ├── stac.py         # Collection + Item build + POST/PUT
    ├── transforms/
    │   ├── vector.py      # reproject → GeoParquet Hive-partitioned on h3_7
    │   ├── raster.py      # reproject → Cloud Optimized GeoTIFF + overviews
    │   └── pointcloud.py  # reproject → Cloud Optimized Point Cloud (COPC via PDAL)
    └── runner.py          # glue: detect → validate → transform → upload → catalog
```

Input-format agnostic:

- **Vector** — any OGR-readable format: Shapefile, GeoPackage (including **multi-layer containers — one STAC item per layer**), KML, KMZ, GeoJSON, FlatGeobuf, MapInfo TAB/MIF, FileGDB, ...
- **Raster** — any GDAL-readable format including already-COG GeoTIFF: COG, GeoTIFF, NetCDF, JP2, VRT, HGT, ASC, IMG, ...
- **Point cloud** — LAS / LAZ → converted to **COPC** (Cloud Optimized Point Cloud) via PDAL, reprojected to EPSG:4326.

No product-specific hard-coding. Drop any supported file and it classifies, validates, reprojects, and catalogs.

### System prerequisites

- Python 3.13+ (3.14 also supported after fixing the macOS `libexpat` pyexpat linkage — see Troubleshooting)
- GDAL 3.8+ for rasterio / pyogrio
- PDAL 2.10+ for LAS/LAZ → COPC conversion (`brew install pdal` on macOS; `apt install pdal` on Debian/Ubuntu). If missing, pointcloud ingestion is skipped with a clear error; other formats unaffected.

### Known limitations (tracked)

- **Vector empty-layer ingestion:** layers with zero features after validation are rejected at the transform boundary with a clear reason (previously returned a world-extent bbox silently).
- **GPKG catalogue layers** (`layer_styles`, `qgis_projects`): filtered during detection. Primary layers only appear as STAC items.
- **KMZ (zipped KML):** detection recognises the extension, but fan-out to inner KML requires an unzip step not yet wired in.

Run against your own data:

```bash
# inside ingest/ once:
python3 -m venv .venv && .venv/bin/pip install -e .

# every run:
cd poc
make ingest-sample              # uses poc/sample-data/ and live cluster
# or:
export MISO_S3_ENDPOINT=http://localhost:9000
export MISO_S3_ACCESS_KEY=...
export MISO_S3_SECRET_KEY=...
.venv/bin/miso-ingest ingest /path/to/data --domain my-collection
```

## Related Spec

- Architecture: [docs/07-logical-architecture.md](../07-logical-architecture.md)
- Requirements in scope: F-01, F-03, F-05, F-07, F-09, F-10, F-11, F-12, F-14, F-16, F-20 — see [docs/id-reference.md](../id-reference.md)
- Substrate decision: [adr/ADR-011-infra-substrate.md](../adr/ADR-011-infra-substrate.md)
- Gate-1 acceptance: [docs/09-phases.md](../09-phases.md#abnahmekriterien--gate-1)
