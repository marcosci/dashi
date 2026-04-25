# Domain onboarding — template

This is the sequence to follow when onboarding a new **domain** (i.e. a new `STAC collection` + the IAM, retention, and serving config that goes with it). It is the Strang K work track from `PHASE-2-ROADMAP.md`.

A "domain" in dashi means: a coherent set of related datasets owned by one team, sharing a retention policy and access boundary. Examples that sit alongside the PoC's `gelaende-umwelt` collection:

- `weather-radar` — DWD radolan radar grids, 5-min cadence, retention 90d
- `coastal-bathymetry` — multibeam point clouds, retention indefinite
- `urban-planning` — vector + 3D building footprints, retention 5y

## Step 0 — define the domain

Open a PR that adds an entry to `docs/onboarding/domains.md` with:

| Field | Example |
|-------|---------|
| `id` | `weather-radar` (lowercase, kebab-case, used as STAC collection id + s3 prefix) |
| `title` | "DWD radolan weather radar" |
| `owner` | team / person responsible for content |
| `retention` | `90d` / `1y` / `indefinite` |
| `access` | `internal` / `public` / `restricted-<group>` |
| `formats` | which kinds you expect — vector / raster / pointcloud / multidim |
| `cadence` | one-shot / hourly / daily / event-driven |
| `volume` | rough TB/month estimate |

## Step 1 — IAM (RustFS per-zone users)

Re-run the RBAC bootstrap with the new domain's name folded in. The bootstrap script reads `docs/onboarding/domains.md` and, for every entry, ensures three RustFS users exist with prefix-scoped policies:

```text
dashi-<domain>-ingest          (write landing/<domain>/*)
dashi-<domain>-pipeline        (read processed/<domain>/*, write curated/<domain>/*)
dashi-<domain>-serving-reader  (read curated/<domain>/*)
```

```bash
cd poc
make rbac-bootstrap
```

The script is idempotent — existing users keep their keys; only new domains get new users. K8s Secrets land in:

```text
dashi-data/dashi-<domain>-rustfs-pipeline
dashi-serving/dashi-<domain>-rustfs-serving
```

## Step 2 — Catalog (STAC collection)

The first ingest run for the domain auto-creates a STAC collection via `dashi_ingest.stac.ensure_collection`. Override the description per domain by passing `--collection-description` to `dashi-ingest`:

```bash
.venv/bin/dashi-ingest ingest /path/to/data \
  --domain weather-radar \
  --collection-description "DWD radolan weather radar — 5-min cadence, retention 90d"
```

## Step 3 — Ingest pipeline

Two paths depending on cadence:

### One-shot / batch

Run the ingest CLI against a local path or a mounted PV:

```bash
.venv/bin/dashi-ingest ingest s3://landing/<domain>/2026/04/26/ --domain <domain>
```

### Continuous

Register a Prefect deployment that watches a path or S3 prefix and triggers `dashi-ingest` per new file. See `poc/flows/deploy.py` for the pattern.

```bash
poc/scripts/prefect-register.sh \
  --domain weather-radar \
  --schedule "*/15 * * * *" \
  --source s3://landing/weather-radar/
```

## Step 4 — Quality gates

Add domain-specific validators to `poc/ingest/src/dashi_ingest/validators.py` if the standard ones miss something. The framework already covers:

- non-empty geometry / non-zero raster bands
- CRS readable from the file
- (raster) all bands same dtype
- (pointcloud) PDAL probe succeeds

If your domain needs additional checks (e.g. `temperature_min > -100`), add a function and wire it from `runner.ingest_one`.

## Step 5 — Serving

Per access type:

| Access need | Component | What you do |
|-------------|-----------|-------------|
| Analytical SQL | DuckDB endpoint | Nothing — auto-discovers parquet under `s3://processed/<domain>/`. |
| Raster tiles | TiTiler | Nothing — TiTiler reads any COG from RustFS via path param. |
| Vector tiles | Martin | Add the layer hash to `poc/scripts/pmtiles-generate.sh`, run `make ogc-deploy`. |
| OGC API – Features | TiPG | Promote one or more curated parquet → PostGIS via the `serving-postgis` instance, then TiPG auto-discovers it. (TiPG promotion flow lives in the FEATURE-IDEAS backlog.) |
| Point clouds | maplibre-gl-lidar viewer | Nothing — viewer accepts any presigned COPC URL. |

## Step 6 — Smoke + lineage

Add a domain-specific smoke script `poc/smoke/<domain>.sh` that:

1. queries STAC for ≥1 item in the new collection
2. fetches one asset via presigned URL (HTTP 206 range GET)
3. (if vector) fetches one MVT tile from Martin
4. (if raster) fetches one TiTiler `cog/info` 200

Wire it into `make smoke`.

## Step 7 — Retention + clean-up

Schedule a Prefect flow that lists STAC items older than the domain's retention, deletes the underlying RustFS objects, and removes the STAC items. Stub:

```python
@flow(name=f"retention-{DOMAIN}")
def retention_flow(domain: str = "weather-radar", days: int = 90):
    cutoff = datetime.now(UTC) - timedelta(days=days)
    items = stac.search(collection=domain, datetime=f"../{cutoff.isoformat()}")
    for item in items:
        for asset in item.assets.values():
            storage.delete(asset.href)
        stac.delete_item(item.id, collection=domain)
```

## Acceptance — the domain is "onboarded" when

- [ ] `docs/onboarding/domains.md` entry merged
- [ ] RBAC bootstrap created the three users
- [ ] First STAC item visible at `/collections/<domain>/items`
- [ ] Domain-specific smoke green
- [ ] Retention flow registered (or `indefinite` documented)
- [ ] Owner has signed off

## Worked example — `gelaende-umwelt`

The bundled PoC is a fully-onboarded domain. See:

- `poc/sample-data/` — the source files
- `poc/scripts/ingest-sample.sh` — the ingest invocation
- `poc/smoke/{catalog,ingest,serving,martin,pointcloud}.sh` — the per-strang smokes
- `s3://landing/gelaende-umwelt/`, `s3://processed/gelaende-umwelt/`, `s3://curated/gelaende-umwelt/` — the zone layout
