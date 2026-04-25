# Troubleshooting

Every PoC-blocker we hit, with root cause and fix. Newest first.

## RustFS pod liveness probe 403

**Symptom.** `rustfs-0` pod stays `Running 0/1`, liveness probe logs `HTTP probe failed with statuscode: 403`, pod gets killed + restarted in a loop.

**Root cause.** `deployment.yaml` had `livenessProbe: httpGet /minio/health/ready`. RustFS does not expose the MinIO-compat health path unauthenticated. Every probe returns 403, k8s treats 403 as unhealthy, pod gets killed before the bucket-init Job can alias into it.

**Fix.** Switch both `readinessProbe` and `livenessProbe` to `tcpSocket: port: s3` — port-level reachability is what we actually need, not an HTTP body.

**Commit:** `0f38b06`

## rustfs-create-buckets Job: `connection refused`

**Symptom.** Pod is Ready, Service has no endpoints:

```
Endpoints: <none>
```

Job retries `mc alias set dashi http://rustfs:9000 …` forever.

**Root cause.** `kustomization.yaml` used the deprecated `commonLabels`, which adds `app.kubernetes.io/part-of: dashi` to **both** the Service selector and the Pod template. If the Service was applied via `kubectl apply -f` separately later (without the kustomize pass), selector and pod labels desynchronise; selector still has `part-of=dashi` but the pod labels do not.

**Fix.** Replace `commonLabels:` with:

```yaml
labels:
  - pairs:
      app.kubernetes.io/part-of: dashi
    includeSelectors: false
```

Always re-apply via `kubectl apply -k` to keep them in lockstep.

**Commit:** `0f38b06`

## pgstac-migrate Job: `pypgstac: not found`

**Symptom.** First attempt at the migrate Job used image `ghcr.io/stac-utils/pgstac:v0.9.5`. Logs:

```
/bin/sh: 7: pypgstac: not found
```

**Root cause.** The `pgstac` image ships Postgres + PostGIS + the pgstac SQL schemas only. The `pypgstac` CLI lives in a separate Python package. Tried the `ghcr.io/stac-utils/stac-fastapi-pgstac` image next; it has the `pypgstac` binary but not the `psycopg` backend (`ModuleNotFoundError: No module named 'psycopg'`).

**Fix.** Use `python:3.12-slim` as the Job image and `pip install pypgstac[psycopg]==0.9.5` at runtime:

```yaml
args:
  - |
    set -eu
    pip install --quiet --no-cache-dir "pypgstac[psycopg]==0.9.5"
    # wait for pg, then:
    pypgstac migrate
    pypgstac pgready
```

Adds ~30 s to first apply. Acceptable trade against maintaining our own pypgstac image.

**Commit:** `4926e6b`

## COG raster ingest fails: `Updating it will generally result in losing part of the optimizations`

**Symptom.** Raster ingest on already-COG input crashes with:

```
CPLE_AppDefinedError: File /tmp/dashi-ingest-.../sample.tif has C(loud) O(ptimized) G(eoTIFF) layout.
Updating it will generally result in losing part of the optimizations …
```

**Root cause.** `rio_copy(WarpedVRT, out, driver='COG', …)` opened the source file in update mode when the source already had COG layout. GDAL's COG driver refuses to clobber its own layout in-place.

**Fix.** Two-step: always write a plain `GTiff` temp first (reprojected if needed, plain rewrite if not), then `rio_copy(temp_path, out_path, driver='COG', …)`. Source is never opened writable; temp can always be clobbered.

**Commit:** `f1c5319`

## Port-forward drops on large upload

**Symptom.** `boto3.upload_file` on a 97 MB COPC output hits:

```
ConnectionClosedError: Connection was closed before we received a valid response from endpoint URL
```

Port-forward works for small files; dies on multi-minute uploads.

**Root cause.** `kubectl port-forward` opens a streaming HTTP/2 connection that occasionally gets reset by the API server under sustained load. A single-shot `put_object` call cannot resume.

**Fix.** Explicit boto3 `TransferConfig` — multipart at 8 MB chunks, 2 parallel threads, `retries={"max_attempts": 10, "mode": "adaptive"}`, and 30 s connect / 120 s read timeouts. Multipart means each chunk is its own HTTP request; drops retry at chunk granularity, so a 97 MB upload survives.

**Commit:** `5826bef`

## TiTiler image `no match for platform in manifest`

**Symptom.** `ImagePullBackOff` on `ghcr.io/developmentseed/titiler:0.19.3`, even after `docker pull --platform linux/amd64 … && k3d image import`. kubelet on arm64 node rejects the amd64 manifest.

**Root cause.** Upstream TiTiler publishes amd64-only images. k3d nodes on Apple Silicon are arm64. Emulation via rosetta/qemu inside containerd is unreliable.

**Fix.** Write a minimal arm64-native FastAPI + `rio-tiler` shim at `poc/titiler-endpoint/`. ~90 lines of Python, covers `/cog/info`, `/cog/bounds`, `/cog/tilejson.json`, `/cog/tiles/{z}/{x}/{y}.{fmt}`. Build locally, `k3d image import`. Flip back to upstream when it ships multi-arch.

**Commit:** `5826bef`

## Multi-layer GPKG silently ingesting only the first layer

**Symptom.** QGIS Military Grids GPKG has 5 layers. Ingest run reported `Summary: {ingested: 1}`. pyogrio warned:

```
UserWarning: More than one layer found in 'QGIS_Military_grids_LzS3XF7.gpkg': 'MGRS_example' (default), 'Grids_example', …
```

**Root cause.** `geopandas.read_file` + `pyogrio.read_info` default to layer 0. `detect.py` returned one `Detection` per file, so only the first layer reached the transform.

**Fix.** `detect.classify()` now calls `pyogrio.list_layers()` and emits one `Detection` per non-ignorable layer (`layer_styles`, `qgis_projects` filtered). `runner.ingest_one` takes a `Detection`, passes `det.layer` to the vector transform and `pyogrio.read_info`, and hashes the layer name into the dataset_id so per-layer outputs don't collide.

**Commit:** `5826bef`

## LAS/LAZ detected as `unknown`

**Symptom.** Point clouds skipped silently during ingest; `dashi-ingest scan` reported `unknown`.

**Root cause.** Original `detect.py` knew only `vector` and `raster` kinds. LAZ extension fell through to `rasterio.open()` which refused it.

**Fix.** New `pointcloud` kind. `POINTCLOUD_EXTS = {.las, .laz, .copc}` short-circuits classification. `transforms/pointcloud.py` uses PDAL `writers.copc` via subprocess with `filters.reprojection` for non-EPSG:4326 sources. Raises `PdalNotAvailable` when PDAL is missing on PATH; runner turns that into a clean `skipped` outcome.

**Commit:** `5826bef`

---

## Operational gotchas (not bugs, just surprises)

### DuckDB `SELECT COUNT(*)` returns `count_star()` as column name

The DuckDB SQL endpoint returns literal DuckDB column identifiers. Add `AS n` to alias in production consumers:

```sql
SELECT COUNT(*) AS n FROM read_parquet(['s3://…']);
```

### STAC Collection POST requires `links: []`

Empty array explicitly. `links: null` or omitting the field returns HTTP 422:

```
{"type":"missing", "loc":["body","links"], "msg":"Field required"}
```

STAC Core 1.0 treats `links` as optional; `stac-fastapi-pgstac` does not.

### k3d `image import` needs the image to be a single-arch tag

`k3d image import multi-arch:tag -c dashi` occasionally fails with `content digest … not found` because the local Docker has only the OCI index manifest, not the per-platform image. Pull once explicitly:

```bash
docker pull --platform linux/arm64 repo/image:tag
k3d image import repo/image:tag -c dashi
```
