# Changelog

All notable changes follow [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] — 2026-04-27

Operator-complete + second-domain release. The `dashictl` mutation
paths (`item delete --apply`, `gc --apply`, `backup restore-test`) are
no longer dry-runs, the cluster is exercised end-to-end in CI, every
pushed image carries an SBOM + vuln scan, and a second sample domain
proves the multi-tenant story.

### Added
- **`dashictl item delete --apply`** — STAC item cascade delete.
  Reads the item, prompts the operator to retype the item id,
  cascades S3 assets → STAC record → (manual) Iceberg partition.
  `DASHICTL_YES=1` skips the prompt for CI use. Audit line emitted to
  stderr before the cascade so log shippers (Loki) capture the
  intent even if the process is killed mid-cascade.
- **`dashictl gc --apply`** — orphan-object garbage collection. Walks
  every STAC collection's items, joins against an S3 ListObjectsV2
  pagination of the target bucket, deletes objects that are not
  referenced and older than `--min-age-hours` (default 1, override
  `DASHICTL_GC_MIN_AGE_HOURS`). Always reports orphan count + total
  MiB before applying; confirmation prompt requires retyping the
  bucket name.
- **`dashictl backup restore-test`** — proves the newest pgstac dump
  is restorable end-to-end. Creates a Job in `dashi-backup` namespace
  that spins an ephemeral PostgreSQL, `aws s3 cp`'s the latest dump,
  runs `pg_restore`, runs sanity SELECTs (collection/item counts),
  then tears down. `--key <key>` pins to a specific dump,
  `--leave-on-fail` keeps the Job + Postgres in-cluster for
  post-mortem.
- **`.github/workflows/ci.yml` E2E job** now goes beyond RustFS
  smoke: deploys pgstac + stac-fastapi against a kind cluster,
  builds `dashictl` from source, runs `dashictl domain create/list`
  and `dashictl doctor` against the live cluster.
- **`.github/workflows/images.yml` SBOM + scan** — every `v*` tag
  push now generates a Syft SPDX SBOM per image, runs Grype with
  `severity-cutoff: high`, and uploads both as 90-day GH Actions
  artefacts under `<image>-supplychain`.
- **`poc/scripts/seed-sample-domains.sh`** — provisions the
  `gelaende-umwelt` (ceiling=int) and `klima-historisch`
  (ceiling=pub) demo domains via `dashictl domain create`. Proves
  the multi-tenant boundary semantics with two real domains.
- **`docs/CLI-OPERATIONS.md`** — day-2 runbook for every dashictl
  subcommand. Wired into mkdocs nav.
- **`adr/ADR-012-local-substrate-orbstack.md`** — captures the colima
  → OrbStack vanilla k8s switch + the reasoning ahead of any future
  reverse migration.

### Changed
- `dashictl` subcommands `item delete`, `gc`, `backup` no longer
  carry the "stub" / "partial" markers in their help text — they
  are real mutations with real audit trails.

## [0.1.1] — 2026-04-27

Reproducible-bootstrap patch release. Same surface area as v0.1.0, but
the four known fresh-cluster gaps + CI image baseline are closed.

### Added
- **`dashictl doctor`** — preflight check matrix (STAC, Prefect,
  Loki, S3 buckets, ingest-api, deployment-registered). Exits
  non-zero on any hard failure so it's CI-friendly. Use as the
  success oracle for `make redeploy-all` or fresh-cluster bringup.
- **`make prefect-bootstrap`** — combines `prefect-patch-pool` and
  `prefect-register` behind one idempotent target. Auto-bootstraps
  the local `dashi-ingest` venv, manages its own port-forward to
  `svc/prefect-server`, and is now wired into `make prefect-up` so a
  fresh cluster lands with `dashi-ingest/main` already registered.
- **Synthetic sample data generator** at `poc/scripts/synthetic-data.sh`
  — produces deterministic GeoJSON + GeoTIFF + GeoParquet fixtures
  for E2E tests, demos, or new domain seeding. `--upload <domain>`
  flag drives `dashictl ingest --dry-run` end-to-end.
- **GitHub Actions image pipeline** (`.github/workflows/images.yml`):
  builds all 7 dashi images (tippecanoe, dashi-ingest, ingest-api,
  ingest-web, duckdb-endpoint, titiler-endpoint, py3dtiles) on every
  PR (amd64). On `v*` tag push, also builds linux/arm64 and pushes
  to GHCR as `ghcr.io/marcosci/dashi/<svc>:<tag>` + `:latest`.

### Changed
- `ingest-api` deployment now defaults `DASHI_API_S3_PUBLIC_ENDPOINT`
  to `http://localhost:9000` so presigned PUT URLs work out-of-the-box
  against the standard `port-forward-all.sh` setup. Production
  deployments behind nginx should override to `""` so the per-request
  Host header is used instead.
- `pmtiles-generate.sh` now exits cleanly (status 0) when the source
  prefix in `processed/` is empty — fresh clusters no longer fail with
  `BackoffLimitExceeded` for layers whose source data hasn't landed
  yet. Re-run `make ogc-deploy` once ingest produces partitions.
- `redeploy-all.sh` extends the deploy chain to cover web-ingest,
  iceberg, backup, tipg. LLM deploy is gated behind
  `DASHI_ENABLE_LLM=1` (default off — Ollama pulls a 2 GiB model).
- `serving-deploy.sh` and `web-ingest-deploy.sh` skip `k3d image
  import` when the active kubectl context is not `k3d-*`. Vanilla
  Kubernetes distros (OrbStack k8s, kind, real clusters) share the
  host docker daemon, so locally-built images are visible without an
  explicit import step.

### Fixed
- Splash logo in `dashictl` now renders as a procedural ANSI
  half-block bowl + amber drop instead of an embedded raster, which
  composited against a checker pattern in iTerm2-style transparent-
  image rendering. Identical output across iTerm2, Ghostty,
  Terminal.app, ssh, tmux. Saves ~5 MB of release-binary size.
- Splash + `--help` output dropped the verbose long-about text
  (three-layer ops model, "admin tasks NEVER" rule). That guidance
  lives in README + CHANGELOG only; help stays terse.

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

[Unreleased]: https://github.com/marcosci/dashi/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/marcosci/dashi/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/marcosci/dashi/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/marcosci/dashi/releases/tag/v0.1.0
