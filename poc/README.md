# PoC — Phase 0 Implementation

Local k3s-based Proof of Concept validating the zone architecture end-to-end with real sample data.

**Owner:** Marco Sciaini · **Substrate:** k3s (lokal) + GitLab CI/CD · **Scope:** Gelände & Umwelt, ~500MB–1GB sample data

## Planned Layout

```
poc/
├── README.md                # This file
├── Makefile                 # Top-level targets (bootstrap / deploy / smoke / teardown)
├── sample-data/             # Local sample data — .gitignored, NOT committed
│   └── .gitkeep
├── manifests/               # k8s manifests / Helm values
│   ├── minio/
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
make k3s-up          # Install k3s, configure kubectl
make minio-deploy    # Deploy MinIO + create zone buckets
make catalog-deploy  # Deploy stac-fastapi + PostgreSQL
make serving-deploy  # Deploy TiTiler + DuckDB endpoint
make prefect-up      # Start Prefect server
make ingest-sample   # Load sample-data/ through full pipeline
make smoke           # Run Gate-1 acceptance checks
```

## Current State

**Not yet bootstrapped.** This directory is a scaffold plan. See [PHASE-0-ROADMAP.md](../PHASE-0-ROADMAP.md) for sequence.

## Related Spec

- Architecture: [docs/07-logical-architecture.md](../07-logical-architecture.md)
- Requirements in scope: F-01, F-03, F-05, F-07, F-09, F-10, F-11, F-12, F-14, F-16, F-20 — see [docs/id-reference.md](../id-reference.md)
- Substrate decision: [adr/ADR-011-infra-substrate.md](../adr/ADR-011-infra-substrate.md)
- Gate-1 acceptance: [docs/09-phases.md](../09-phases.md#abnahmekriterien--gate-1)
