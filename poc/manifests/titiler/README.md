# TiTiler Deployment

Serves COG tiles, tilejson, and asset info from RustFS. Backs [ADR-003](../../../adr/ADR-003-raster-format-cog.md) and [ADR-009](../../../adr/ADR-009-serving-layer.md) (raster serving slice).

## Image choice

Upstream `ghcr.io/developmentseed/titiler` publishes amd64-only manifests. k3d nodes on Apple Silicon are arm64, so the upstream image fails to pull with `no match for platform in manifest`. Emulation via rosetta inside containerd was too flaky for reliable PoC runs.

We instead build a minimal arm64-native equivalent at [`poc/titiler-endpoint/`](../../titiler-endpoint/) using FastAPI + `rio-tiler`. It exposes the subset of TiTiler endpoints the PoC needs:

| Endpoint | Purpose |
|----------|---------|
| `GET /_mgmt/ping` | liveness probe |
| `GET /healthz` | readiness probe |
| `GET /cog/info?url=…` | metadata + band descriptions |
| `GET /cog/bounds?url=…` | bbox |
| `GET /cog/tilejson.json?url=…` | TileJSON 3.0 template |
| `GET /cog/tiles/{z}/{x}/{y}.png?url=…` | XYZ tile |

Migration back to the upstream image is trivial when it publishes multi-arch: change `deployment.yaml` `image:` field, rebuild/remove the custom directory, done.

## Components

| File | Purpose |
|------|---------|
| `namespace.yaml` | `dashi-serving` namespace |
| `secret.yaml` | `rustfs-client` template — real values injected by `scripts/serving-deploy.sh` from cluster state |
| `deployment.yaml` | TiTiler Deployment, references `dashi/titiler-endpoint:dev` |
| `service.yaml` | ClusterIP `titiler:8080` |
| `kustomization.yaml` | Apply with `kubectl apply -k .` |

## Apply

```bash
cd poc
make serving-deploy        # builds titiler-endpoint image + applies all serving manifests
```

Port-forward for local access:

```bash
kubectl -n dashi-serving port-forward svc/titiler 18090:8080
curl "http://localhost:18090/cog/info?url=s3://processed/gelaende-umwelt/<id>/raster/<file>.tif"
```

## Production hardening deferred

- HTTP caching (Varnish / Fastly / Cloudflare) in front of `/cog/tiles/*`
- Cog pre-generation for hot datasets (background job)
- Metrics: `rio-tiler` hit/miss, tile latency histogram
- AuthN/Z: currently open; role-based tile access tied to STAC item classification arrives with F-23
