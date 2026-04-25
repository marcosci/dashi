# titiler-endpoint — custom arm64 tile server

Minimal FastAPI + `rio-tiler` shim that implements the subset of TiTiler endpoints dashi needs, built natively for arm64 (k3d on Apple Silicon) because upstream `ghcr.io/developmentseed/titiler` only ships amd64 manifests as of April 2026.

## Why not the upstream image

k3d runs the node containerd runtime with the host architecture. On Apple Silicon that's arm64. Running the upstream amd64 image would require QEMU emulation at container runtime, which is slow and had stability issues during the PoC. Rebuilding the subset we need takes one Dockerfile + ~90 lines of Python, so we ship our own.

## What it provides

| Endpoint | Matches upstream |
|----------|------------------|
| `GET /_mgmt/ping` | custom liveness shorthand |
| `GET /healthz` | upstream |
| `GET /cog/info?url=…` | `titiler.core.endpoints.cog.info` |
| `GET /cog/bounds?url=…` | `titiler.core.endpoints.cog.bounds` |
| `GET /cog/tilejson.json?url=…` | `titiler.core.endpoints.cog.tilejson` |
| `GET /cog/tiles/{z}/{x}/{y}.{fmt}?url=…` | `titiler.core.endpoints.cog.tile` |

PNG / JPEG / WEBP rendering. Out-of-bounds tiles return a transparent 256×256 PNG (upstream behaviour).

## Build + run

```bash
docker build -t dashi/titiler-endpoint:dev .
docker run --rm -p 8080:8080 \
  -e AWS_S3_ENDPOINT=http://host.docker.internal:9000 \
  -e AWS_ACCESS_KEY_ID=… \
  -e AWS_SECRET_ACCESS_KEY=… \
  -e AWS_VIRTUAL_HOSTING=FALSE \
  -e AWS_HTTPS=NO \
  dashi/titiler-endpoint:dev
```

Under k3d, `poc/scripts/serving-deploy.sh` builds and `k3d image import`s it into the `dashi` cluster, then applies `poc/manifests/titiler/`.

## Files

- `app.py` — FastAPI app
- `Dockerfile` — python:3.12-slim + `fastapi`, `uvicorn[standard]`, `rio-tiler`, `pillow`

## When to retire this

Flip `poc/manifests/titiler/deployment.yaml` `image:` back to `ghcr.io/developmentseed/titiler:<tag>` as soon as the upstream image publishes linux/arm64. Delete this directory.
