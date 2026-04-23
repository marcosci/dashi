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
│   ├── stac-fastapi/
│   ├── titiler/
│   ├── duckdb-endpoint/
│   └── prefect/
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
- **Strang C (ingestion):** ✅ `miso-ingest` CLI format-agnostic (vector + raster), end-to-end proven with Dresden OSM extract — 28 shapefiles → 366k features → 3709 H3-7 partitions → 28 STAC items
- **Strang E (serving):** ⏳ next — TiTiler + DuckDB endpoint
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
    │   ├── vector.py   # reproject → GeoParquet Hive-partitioned on h3_7
    │   └── raster.py   # reproject → Cloud Optimized GeoTIFF + overviews
    └── runner.py       # glue: detect → validate → transform → upload → catalog
```

Input-format agnostic: any OGR/GDAL-readable vector (Shapefile, GeoPackage, KML, GeoJSON, FlatGeobuf, ...) or raster (GeoTIFF, NetCDF, JP2, VRT, ...). No product-specific hard-coding.

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
