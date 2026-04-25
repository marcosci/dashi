# Viewers

Lightweight static demo pages that consume what the dashi serving layer publishes. No build step; everything is browser-side via CDN.

| Page | Backs requirement | What it shows |
|------|-------------------|---------------|
| [pointcloud.html](pointcloud.html) | F-22 sibling — point cloud serving | Direct LAS/LAZ rendering with deck.gl + `@loaders.gl/las`. Paste a presigned RustFS URL (or any HTTPS LAZ URL) and orbit-view. |

## Try it locally

```bash
# 1. port-forward RustFS
kubectl -n dashi-platform port-forward svc/rustfs 19100:9000 &

# 2. mint a presigned URL for the bundled sample COPC
ACCESS=$(kubectl -n dashi-platform get secret rustfs-root -o jsonpath='{.data.access-key}' | base64 -d)
SECRET=$(kubectl -n dashi-platform get secret rustfs-root -o jsonpath='{.data.secret-key}' | base64 -d)
mc alias set dashi-pf http://localhost:19100 "$ACCESS" "$SECRET"
mc share download --expire=1h dashi-pf/processed/gelaende-umwelt/9e5f66f607bd3f5f/pointcloud/points.copc.laz

# 3. open the viewer (e.g. via the docs dev server)
mkdocs serve
# then visit http://localhost:8000/viewer/pointcloud.html and paste the URL
```

You can also pass the URL via query string:

```
http://localhost:8000/viewer/pointcloud.html?url=<presigned-url>
```

## Why direct LAZ instead of a tile server

For point clouds the serving story is fundamentally different from raster (TiTiler) and vector (Martin):

- **`maplibre-gl-lidar` (this page)** streams COPC LAZ viewport-by-viewport via HTTP-range requests. Full file never enters memory; only nodes intersecting the camera frustum are decoded.
- A separate **3D Tiles tileset** (`tileset.json` + `.pnts` chunks) is also published to `s3://curated/3dtiles/<item_id>/` for non-COPC-aware consumers — CesiumJS, iTowns, deck.gl `Tile3DLayer`. The dashi viewer does not consume it directly because the COPC streaming path is already memory-bounded.
