# dashi — a cloud-native spatial data lake, in the open

> Apache-2.0 · Kubernetes-native · STAC + GeoParquet + COG + COPC + PMTiles · runs on a laptop · [marcosci/dashi](https://github.com/marcosci/dashi)

## What is dashi

**dashi** is the Japanese broth that sits under every layered dish — kombu, bonito, water. Unseen but essential. We built a spatial data lake to be exactly that: the foundation everything else rides on.

The goals were boring on purpose:

1. Ingest any geodata GDAL/OGR can read — vector, raster, point cloud — without bespoke plumbing per format.
2. Standardise it onto a small, well-understood set of cloud-native formats: **GeoParquet** for vector, **COG** for raster, **COPC** for point clouds, **PMTiles** for tile bundles.
3. Catalog it as **STAC** so any client can discover what's there.
4. Serve it through whichever protocol the consumer needs — analytical SQL via **DuckDB**, raster tiles via **TiTiler**, vector tiles via **Martin**, OGC API – Features via **TiPG**, point clouds via direct COPC streaming.
5. Run all of that locally on a laptop in `k3d`, with the same manifests deployable to any production Kubernetes cluster.

Every choice is documented as an ADR. Every decision rejects bigger, older, more enterprise-y options when they don't earn their weight: **GeoServer** is out, **Martin** is in. **MinIO** is out (license drift), **RustFS** is in. No JVM anywhere.

## What's in the repo

```
docs/         architecture spec (German source-of-truth + English contributor docs)
adr/          11 architecture decisions
poc/          a working Phase-0 PoC on local k3d
  manifests/  Kubernetes manifests per component
  ingest/     dashi-ingest — Python pipeline (detect → validate → transform → STAC)
  py3dtiles/  COPC → 3D Tiles tileset converter
  scripts/    bring up the cluster, deploy each strang, mint presigned URLs
  smoke/      end-to-end acceptance checks per strang
docs/viewer/  browser-side LiDAR viewer (maplibre-gl + opengeos/maplibre-gl-lidar)
```

A fresh laptop can clone the repo and `cd poc && make k3s-up && make smoke` to land at a working data lake with the bundled NZ LiDAR + Dresden OSM sample.

## Architecture in one diagram

```
   GeoTIFF, Shapefile,    ┌──────────────────────────────────────────────┐
   GPKG, KML, LAZ, …      │  Landing → Processed → Curated → Enrichment  │
            │             │           (zone model, RustFS S3)            │
            ▼             └──────────────┬───────────────────────────────┘
       Prefect flow                      │
      (dashi-ingest)            pgstac (STAC catalog, Postgres)
            │                            │
            └─────────┬──────────────────┘
                      ▼
        Serving:  TiTiler · DuckDB · Martin · TiPG · MapLibre+deck.gl
```

Spatial partitioning via **H3**. Single processing engine: **DuckDB + GDAL/PDAL**. Orchestration: **Prefect 3** in-cluster. Observability: **Prometheus + Grafana**.

## Why open-source it

Two reasons.

1. The architecture is opinionated and we want to be told if the opinions are wrong. The point cloud serving story — keep COPC in source CRS, let `loaders.gl` reproject browser-side — was wrong twice before we landed on it. We expect that to keep happening for a while.
2. Spatial data infrastructure that can run on a small cluster, self-host, and not bill per request is undersupplied. The reference stack we've assembled (RustFS + pgstac + Martin + TiTiler + TiPG + DuckDB + Prefect) is just _correct_ — every component is best-in-class for its zone — and shipping the wiring saves anyone else weeks.

## What works today

- [x] Phase-0 PoC: ingest → catalog → serve, all green
- [x] Vector tiles via Martin (PMTiles backend)
- [x] Raster tiles via TiTiler (custom arm64 build)
- [x] OGC API – Features via TiPG
- [x] Analytical SQL via DuckDB endpoint
- [x] Point clouds: direct COPC streaming + 3D Tiles tileset (py3dtiles)
- [x] Per-zone IAM (ingest / pipeline / serving-reader) on RustFS
- [x] NetworkPolicies (default-deny + scoped allows)
- [x] Prometheus + Grafana dashboards
- [x] CI — lint + manifests + docs + viewer build
- [x] Fully Apache-2.0

## What's next

- **TiPG promotion flow:** Prefect task that auto-promotes curated GeoParquet → PostGIS, so TiPG collections track ingest in real time.
- **OIDC / SSO:** unify Prefect, Grafana, MinIO Console under a single sign-in (Authelia + oauth2-proxy).
- **Backups / DR:** `pg_dump` CronJobs → off-cluster, restore drill quarterly.
- **Loki + promtail:** centralised logs as a Grafana datasource.
- **CesiumJS / iTowns adapters:** consume the existing `assets.tileset3d` from STAC.

Backlog: [`docs/FEATURE-IDEAS.md`](FEATURE-IDEAS.md). Issues + Discussions are open. PRs welcome — see [CONTRIBUTING.md](https://github.com/marcosci/dashi/blob/main/CONTRIBUTING.md).

## Try it

```bash
git clone https://github.com/marcosci/dashi
cd dashi/poc
make k3s-up
make storage-deploy catalog-deploy serving-deploy ogc-deploy tipg-deploy
make rbac-bootstrap network-policies-up monitoring-up prefect-up
make ingest-sample
make smoke
```

That's the whole thing. ~15 minutes on a recent laptop, no API keys, no managed services.

— Marco Sciaini + Johannes Schlund
