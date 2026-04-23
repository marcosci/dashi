# Operations Runbook

Step-by-step deploy, verify, and teardown for a new operator. Covers the full dashi PoC stack on a fresh machine.

## Prerequisites

| Tool | Version tested | macOS install | Linux install |
|------|---------------|---------------|---------------|
| Docker | 28+ | Docker Desktop / OrbStack | distro package |
| k3d | 5.8+ | `brew install k3d` | `curl -s https://raw.githubusercontent.com/rancher/k3d/main/install.sh \| bash` |
| kubectl | 1.34+ | `brew install kubectl` | distro package |
| helm | 3.19+ | `brew install helm` | distro package |
| mc (MinIO client) | 2025.08+ | `brew install minio/stable/mc` | install script |
| gdal / ogrinfo | 3.12+ | `brew install gdal` | distro `gdal-bin` |
| PDAL | 2.10+ | `brew install pdal` | `apt install pdal` |
| gh (GitHub CLI) | 2.87+ | `brew install gh` | distro package |
| Python | 3.11+ | `brew install python@3.12` | distro |

Clone + change into the repo:

```bash
git clone https://github.com/marcosci/dashi
cd dashi
```

## Bootstrap in one sitting

```bash
cd poc

# 0. Bring up the local cluster (k3d on Mac/Windows, native k3s on Linux)
make k3s-up                # ~30 s

# 1. Object storage
make storage-deploy        # RustFS StatefulSet + bucket init Job ~60 s

# 2. Catalog
make catalog-deploy        # pgstac Postgres + pypgstac migrate + stac-fastapi ~2 min

# 3. Serving layer (builds two custom arm64 images, imports into k3d, applies)
make serving-deploy        # TiTiler + DuckDB SQL endpoint ~3 min

# 4. Drop sample data into poc/sample-data/ (gitignored)
#    then run the pipeline:
make ingest-sample         # runs miso-ingest against whatever is in sample-data/

# 5. Smoke tests — catalog + ingest + serving
make smoke
```

After `make smoke` passes, the stack is fully operational.

## Port-forward cheat sheet

Nothing has an Ingress in PoC. Use port-forwards:

```bash
# RustFS S3 API + console
kubectl -n miso-platform  port-forward svc/rustfs          9000:9000 9001:9001

# stac-fastapi
kubectl -n miso-catalog   port-forward svc/stac-fastapi    18080:8080

# TiTiler + DuckDB endpoint
kubectl -n miso-serving   port-forward svc/titiler         18090:8080
kubectl -n miso-serving   port-forward svc/duckdb-endpoint 18091:8080
```

## Credential flow

```
rustfs-root           (miso-platform)      root credentials created at RustFS deploy
   │
   └──► rustfs-client (miso-serving)       mirrored by scripts/serving-deploy.sh
                                           so TiTiler + DuckDB endpoint can read
                                           s3://processed/… without a direct
                                           cross-namespace read
pgstac-credentials    (miso-catalog)       Postgres user/password used by pgstac
                                           + stac-fastapi + pypgstac migrate Job
```

All secrets live in K8s only. The YAML templates in `poc/manifests/*/secret.yaml` carry a placeholder string; `poc/scripts/apply-with-secret.sh` generates a random password, applies, then restores the template. Real credentials never land in git.

## Running miso-ingest against arbitrary data

```bash
# one-time: install the CLI in a venv
cd poc/ingest
python3 -m venv .venv
.venv/bin/pip install -e .

# every run: give it credentials + stac URL, point at any path
export MISO_S3_ACCESS_KEY=$(kubectl -n miso-platform get secret rustfs-root -o jsonpath='{.data.access-key}' | base64 -d)
export MISO_S3_SECRET_KEY=$(kubectl -n miso-platform get secret rustfs-root -o jsonpath='{.data.secret-key}' | base64 -d)
export MISO_S3_ENDPOINT=http://localhost:9000

.venv/bin/miso-ingest scan   /path/to/data                  # dry run — shows detected kind/driver/layer
.venv/bin/miso-ingest ingest /path/to/data --domain my-col  # real run
```

Supported input formats (auto-detected, no config): Shapefile · GeoPackage (multi-layer) · KML · GeoJSON · FlatGeobuf · MapInfo TAB/MIF · FileGDB · GeoTIFF (incl. already-COG) · NetCDF · JP2 · VRT · IMG · HGT · ASC · DEM · LAS · LAZ.

## Observing the stack

```bash
kubectl get pods -A | grep miso-
kubectl -n miso-platform get events --sort-by=.lastTimestamp | tail -20
kubectl -n miso-catalog  logs deploy/stac-fastapi --tail=50
kubectl -n miso-serving  logs deploy/duckdb-endpoint --tail=50
```

Catalog self-service:

```bash
curl http://localhost:18080/collections            | jq '.collections[].id'
curl http://localhost:18080/collections/<id>/items | jq '.features | length'
curl http://localhost:18080/search?bbox=13.5,50.8,14.0,51.2 | jq '.numReturned'
```

## Teardown

```bash
cd poc
make smoke       # optional — confirm clean state before shutting down
make k3s-down    # removes the k3d cluster entirely (data gone)
```

Leave everything where it is and just stop Docker Desktop / OrbStack if you want to resume later — the k3d cluster state survives.

## Fresh-start disaster recovery

```bash
# 1. Delete the cluster
make k3s-down

# 2. Clear any stale Docker-level state
docker system prune -a

# 3. Redo the full bootstrap
make k3s-up && make storage-deploy && make catalog-deploy && make serving-deploy
```

Persistent volumes follow the cluster; after `k3s-down` they're gone too. Sample data in `poc/sample-data/` stays on host.
