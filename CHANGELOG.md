# Changelog

All notable changes follow [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Iceberg REST catalog (tabulario/iceberg-rest) deployed in `dashi-iceberg` namespace, backed by SQLite metadata + RustFS warehouse at `s3://curated/iceberg/`. Promote curated GeoParquet → Iceberg tables via the new `dashi_ingest.flows.iceberg` Prefect flow. ADR-005 closes from "decided" to "deployed".
- LLM enrichment scaffolding: `dashi_ingest.enrich` (provider-agnostic OpenAI-compat client) + `dashi_ingest.flows.enrich` Prefect flow that writes `dashi:enriched_{title,description,keywords,model}` back to STAC. Optional Ollama Deployment in `dashi-llm` for fully-local inference. Enrichment is gated by classification (defaults to `pub,int` only).
- `make iceberg-deploy`, `make llm-deploy`, smoke checks `iceberg.sh` + `llm.sh`.
- **Resumable / large-file uploads.** New `/multipart/start | /complete | /abort` endpoints in `ingest-api`. The web UI auto-switches to chunked PUT for files ≥ 500 MiB (16 MiB parts, bounded concurrency = 4, per-part progress + ETag capture). Upload cap raised from 1 GiB → **50 GiB**. Below the threshold the existing single-PUT `/presign` path is unchanged.
- **Register existing object.** New `/register` endpoint + `Register` route in the web UI. Paste an `s3://landing/...` URI (already staged via rclone, the `dashi-ingest` CLI, or a partner push) and the same scan → classify → trigger pipeline runs without re-uploading. HEAD-validates the object exists before committing.
- `poc/scripts/port-forward-all.sh` — supervised `kubectl port-forward` table that holds 15 dashi services on stable localhost ports and respawns dead forwarders.
- **`dashictl` admin CLI** — Rust binary in `poc/dashictl/` with figlet-style splash banner (amber-on-stderr, suppressed in pipes / non-TTY). Subcommands wired so far: `domain list|show|create` (STAC), `audit tail [--follow]` (Loki LogQL), `runs --limit N` (Prefect), `config` (resolved settings). Partial / stub: `item delete` (dry-run preview), `gc` (read-only scan), `backup verify` (freshness check), `user grant` + `backfill` (placeholder + tracking link). Config via `~/.config/dashi/config.toml` with named contexts (`local` / `staging` / `prod`) plus `DASHI_*` env overrides. Three-layer ops model documented at the top of `--help` and in `poc/dashictl/README.md`: **dashictl** = operator CRUD, **Grafana** = read-only dashboards, **Web UI** = researcher front door — with the explicit rule "admin tasks NEVER grow into the web UI". CI job (`cargo fmt --check + cargo check + cargo clippy -D warnings`) added to `.github/workflows/ci.yml`.

## [0.1.0] — 2026-04-25

First public release. The platform is feature-complete for a Phase-2 PoC: every spatial-data-lake property delivered end-to-end on a local Kubernetes cluster, with ten smoke checks gating the build.

### Highlights
- **Spatial data lake on k3d / k3s.** RustFS object store, pgstac STAC catalog, Prefect 3 orchestration, multi-format ingest (vector / raster / pointcloud), serving via DuckDB + TiTiler + Martin + TiPG + maplibre-gl-lidar.
- **Open-source ready.** Apache-2.0, CONTRIBUTING.md, CODE_OF_CONDUCT.md, SECURITY.md, GitHub issue + PR templates, two CI workflows (docs + 7-job pipeline).
- **Web ingest UI.** React 18 + Vite + Tailwind v4 SPA with four routes — Ingest, Catalog, Runs, Viewer — backed by a thin FastAPI shim.

### Added (foundations)
- Apache Iceberg as the time-travel / ACID table format alongside GeoParquet (ADR-005).
- COPC point-cloud serving (PoC tier via maplibre-gl-lidar viewport streaming, production tier via py3dtiles 3D Tiles tilesets).
- TiPG (OGC API – Features) wired to the `dashi-serving-db` PostGIS instance.
- Martin vector-tile server backed by PMTiles produced by tippecanoe.
- Authelia OIDC issuer + oauth2-proxy scaffolding (forward-auth template per UI).
- pg_dump CronJobs with optional off-cluster S3 mirror for DR.
- Loki + promtail log shipping; Grafana datasource auto-provisioned.
- Per-zone IAM (RustFS) + scoped K8s NetworkPolicies (12 policies).
- Four-level classification scheme (`pub` / `int` / `rst` / `cnf`) enforced at the CLI, Prefect flow, ingest API, and UI; per-domain `dashi:max_classification` ceiling rejects requests at trigger time.
- Lineage: every STAC item now carries `dashi:prefect_flow_run_id` + `_url` linking back to the producing flow run.
- Incremental ingest: same content + same domain → same dataset id → skipped.
- Multidimensional raster detection: `.nc`, `.nc4`, `.h5`, `.hdf5`, `.he5`, `.hdf`, `.grib`, `.grb`, `.grb2` accepted.
- Pre-commit hooks (`detect-secrets`, ruff, shellcheck, common pre-commit-hooks).
- E2E CI job (kind cluster + RustFS smoke), gated by main-branch push or `e2e` PR label.

### Branding
- Full MISO → dashi rebrand across code, manifests, docs, ADRs.
- Demilitarised wording — generic spatial / Earth-observation framing.

### Deferred to future releases
- Authelia + oauth2-proxy live wiring (requires real DNS + TLS).
- Multi-file drop in the web UI (current flow already handles directories at the CLI level).
- Iceberg catalog HA + Postgres backend (single-replica SQLite for PoC).

[Unreleased]: https://github.com/marcosci/dashi/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/marcosci/dashi/releases/tag/v0.1.0
