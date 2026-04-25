"""Format-specific standardization transforms. Every transform enforces:

- Target CRS = EPSG:4326 (ADR — single platform-wide KRS)
- Vectors → GeoParquet partitioned by H3 (ADR-002 + ADR-008)
- Rasters → Cloud Optimized GeoTIFF with overviews (ADR-003)
- Metadata sidecar JSON captured alongside every output
"""
