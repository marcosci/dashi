# Feature Ideas — dashi backlog

Lightweight backlog. No promise to ship. Capture, sort later. Promotion path: idea → ADR (if architecture-relevant) or → roadmap entry (if scoped).

## How to add an idea

1. Append entry below under appropriate category (or create new category).
2. Fill template:

```markdown
### [Title]

- **Why:** one sentence on the pain or opportunity
- **Sketch:** 2–4 bullets on shape of the solution
- **Status:** `idea` | `triaged` | `spike-needed` | `adopted` | `rejected`
- **Owner:** unassigned | <name>
- **Refs:** related F-NN / ADR / external link
```

3. PR with the new entry. No discussion needed for `idea` state.

---

## Tooling & DX

### Possible CI tooling for dashi

- **Why:** PoC currently has manual smoke scripts. Production needs gated CI for manifests, ingest pipeline, PMTiles regeneration, and docs.
- **Sketch:**
  - GitHub Actions matrix: `kubeval` / `kubeconform` on every manifest, `pytest` on `dashi_ingest`, `mkdocs build --strict`, container builds for tippecanoe/titiler-endpoint/duckdb-endpoint
  - Renovate or Dependabot for pinned image tags (RustFS, Martin, TiTiler, Prefect, PostGIS)
  - On main: rebuild PMTiles in dry-run mode against a tiny fixture set
  - `make smoke` against an ephemeral k3d cluster spun up per PR (kind/k3d-action)
- **Status:** idea
- **Owner:** unassigned
- **Refs:** ADR-011 (infra substrate), `.github/workflows/docs.yml` (only existing CI)

### Pre-commit hooks (manifest lint, secret scan, markdown lint)

- **Why:** Catch leaks and broken kustomize before push.
- **Sketch:** `pre-commit-hooks` with `detect-secrets`, `kubeconform`, `markdownlint`, `shellcheck`, `ruff`.
- **Status:** idea
- **Owner:** unassigned

---

## Catalog & Metadata

### Metadata extraction with LLMs

- **Why:** STAC item title/description fields stay empty in the PoC because the human-readable summary doesn't fit any deterministic field on a GeoTIFF. LLM can produce a useful one-paragraph summary from filename + EXIF + first-band stats + (optionally) low-res thumbnail.
- **Sketch:**
  - Add post-ingest Prefect task `enrich_metadata(item_id)` that calls a configurable LLM endpoint (local Ollama, Claude API, OpenAI-compat)
  - Inputs: filename, MIME, GDAL `gdalinfo -json`, vector layer schema, sample geometry centroid + bbox reverse-geocoded
  - Output: title, description, suggested keywords (controlled vocab), suggested STAC extensions
  - Writes back to pgstac as a `properties.dashi:enriched_*` namespace so it never overwrites human-curated values
  - Privacy gate: opt-in flag per zone, since landing zone may carry sensitive content
- **Status:** idea
- **Owner:** unassigned
- **Refs:** ADR-006 (data catalog), F-04 (Metadaten), F-13 (Suche)

### Auto-derived keywords / controlled vocab mapping

- **Why:** Free-text keywords degrade search.
- **Sketch:** Embedding-based mapping from extracted terms to a small controlled vocabulary (Earth observation / C2 / Logistik / Gelände). Run as part of the same enrichment flow.
- **Status:** idea

---

## Serving & Consumption

### TiPG (OGC API – Features) deployment

- **Why:** ADR-009 selected TiPG for OGC API – Features. Currently ⏳.
- **Sketch:** Promote curated GeoParquet → PostGIS via Prefect, point TiPG at `serving-postgis`. Feature collection per `serving.layer_registry` row.
- **Status:** triaged
- **Owner:** unassigned
- **Refs:** ADR-009, `poc/manifests/serving-db/`, `docs/PHASE-2-ROADMAP.md` Strang J

### MapLibre demo viewer

- **Why:** Show what Martin actually serves to a non-technical stakeholder.
- **Sketch:** Single static HTML page using MapLibre + a hand-written style JSON pointing at `/tiles/{source}` Martin endpoints. Hosted as a sub-path on the docs site.
- **Status:** idea

### PMTiles cache invalidation per source

- **Why:** Currently the whole Martin pod restarts when any one PMTiles archive changes (initContainer mirror).
- **Sketch:** Switch to a sidecar that watches `s3://curated/tiles/` and `kubectl exec` into Martin to refresh just one file, OR upgrade Martin once it supports custom S3 endpoint config (see `maplibre/martin#1567`).
- **Status:** spike-needed

---

## Ingest & Pipeline

### Format coverage: NetCDF / Zarr / HDF5 climate stacks

- **Why:** Phase 2+ envisions weather/climate domain onboarding.
- **Sketch:** Ingest detector returns `kind=multidim`, transform extracts coordinate metadata + variable list, emits one COG per variable per timestep OR registers the original Zarr group via STAC `xarray-assets` extension.
- **Status:** idea

### Incremental ingest (skip already-processed)

- **Why:** Re-running ingest on a directory currently re-processes everything.
- **Sketch:** Hash file content + mtime, store in pgstac `properties.dashi:source_hash`, skip if matched.
- **Status:** idea

### Format-aware quality gates

- **Why:** Bad input (corrupt GeoTIFF, broken topology in Shapefile) currently fails late.
- **Sketch:** Pre-flight validators per kind (`gdalinfo --validate-cog`, `ogr_geometry validity`, PDAL pipeline preview). Fail to landing-zone quarantine instead of processed/.
- **Status:** idea

---

## Operations & Security

### OIDC / SSO across all UIs

- **Why:** Prefect, Grafana, MinIO Console, future TiPG/Martin all have separate auth.
- **Sketch:** Deploy Authelia or Dex + a single OIDC issuer. Reverse-proxy each UI through `oauth2-proxy` with per-namespace ingress.
- **Status:** triaged
- **Refs:** Phase 2 Strang H follow-up

### Backup / DR for pgstac + Prefect DB

- **Why:** Postgres data only on PVC. No off-cluster backup.
- **Sketch:** `pg_dump` CronJob → s3://backups/, retention 30d. Restore drill quarterly.
- **Status:** idea

### Cluster-wide audit log shipping

- **Why:** Currently no central log retention.
- **Sketch:** Loki + promtail in `dashi-monitoring`, Grafana datasource, label-based filtering per namespace.
- **Status:** idea

---

## Documentation & Onboarding

### Architecture diagram generator

- **Why:** Mermaid diagrams in docs go stale.
- **Sketch:** Generate from kustomize output (one diagram per namespace) on every docs build.
- **Status:** idea

### Decision log / ADR linter

- **Why:** Make sure every "Decision" line in an ADR has a Status, Context, Consequences trio.
- **Sketch:** Small Python script in CI that parses the ADR template and flags missing sections.
- **Status:** idea

---

## Research / Speculative

### H3 spatial join benchmarks vs. PostGIS

- **Why:** ADR-008 chose H3 partitioning. Need real numbers vs. PostGIS to justify the storage layer for join-heavy workloads.
- **Sketch:** Bench `dashi_ingest` 100M-row vector dataset, measure time for spatial join on H3 keys vs. ST_Contains on PostGIS GIST.
- **Status:** spike-needed
- **Refs:** ADR-008

### GPU-accelerated raster pipelines

- **Why:** COG → reprojection → derivatives is CPU-bound today.
- **Sketch:** RAPIDS `cuspatial` + `rio-tiler` GPU backend evaluation.
- **Status:** idea

### Federated catalog (multi-cluster STAC mesh)

- **Why:** When dashi runs at multiple sites, want a single search over all of them.
- **Sketch:** STAC API federation extension; or static pgstac replicas with a thin GraphQL aggregator.
- **Status:** idea
