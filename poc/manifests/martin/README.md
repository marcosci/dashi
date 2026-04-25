# Martin — vector tile server (Strang J)

[Martin](https://github.com/maplibre/martin) v1.6 from the MapLibre org. Serves MVT vector tiles + the OGC API – Tiles modern equivalent of WMS/WMTS. Backs requirements **F-22** (Vektorkacheln) and the OGC-API-Tiles part of **F-21**. Decision details in [ADR-009](../../../adr/ADR-009-serving-layer.md).

## What it serves

Six layers (PoC subset, more added by re-running `scripts/pmtiles-generate.sh`):

| Source name | Origin | Zoom range |
|-------------|--------|-----------|
| `osm_roads` | Geofabrik OSM Dresden roads | 5–14 |
| `osm_buildings` | OSM building footprints | 10–14 |
| `osm_landuse` | OSM landuse polygons | 6–13 |
| `osm_water` | OSM water polygons | 5–13 |
| `osm_railways` | OSM railways | 6–14 |
| `mgrs_grids` | QGIS Military Grids GPKG (MGRS layer) | 5–12 |

`tippecanoe --drop-densest-as-needed` will collapse some zoom levels for sparse layers; check each layer's TileJSON for actual `minzoom` / `maxzoom`.

## Endpoints

| Path | Returns |
|------|---------|
| `GET /` | Greeting + version |
| `GET /health` | `OK` (200) — used as Kubernetes probe |
| `GET /catalog` | JSON listing of every configured tile/sprite/font source |
| `GET /<source>` | TileJSON 3.0.0 (tiles URL template, vector_layers, bounds, zoom range) |
| `GET /<source>/{z}/{x}/{y}` | MVT tile (gzipped protobuf). 204 No Content for empty tiles. |
| `GET /catalog?format=mvt` | Discovery for OGC clients |

## Architecture (PoC)

```
RustFS curated/tiles/*.pmtiles
        │
        │ initContainer mirrors via mc
        ▼
emptyDir /tiles inside the Martin pod
        │
        ▼
Martin reads PMTiles as local files, serves MVT
```

Martin v1.6's PMTiles backend uses Apache `object_store` and does not currently expose a custom-S3-endpoint knob through the public config schema. That blocks direct s3:// reads against RustFS. Workaround: an `initContainer` (`minio/mc`) mirrors `s3://curated/tiles/` into a shared `emptyDir` on pod start. Cost: pod startup time scales with tile-archive size (~200 KB–15 MB per layer, fine for PoC). Re-mirror happens whenever the Deployment rolls (`make ogc-deploy` does this automatically).

## Apply

```bash
# Generate PMTiles + deploy Martin in one go
cd poc
make ogc-deploy
```

Or step-by-step:

```bash
bash scripts/pmtiles-generate.sh        # spawns one K8s Job per layer
kubectl apply -k manifests/martin
kubectl -n miso-serving rollout restart deployment/martin
```

## Smoke

`poc/smoke/martin.sh` covers:

- `/health` returns 200
- `/catalog` lists ≥6 sources
- `/osm_roads` returns valid TileJSON 3.0.0
- `/osm_roads/10/551/342` (Dresden bbox) returns ≥1 KB of MVT
- Out-of-bounds tile returns 204
- All 6 layers reachable

## Production hardening deferred

- **Push-update** instead of pod-rollout-on-change (currently restart triggers re-mirror)
- **Custom S3 endpoint in Martin config** — track [maplibre/martin#1567](https://github.com/maplibre/martin/issues/1567) or similar; remove the `initContainer` mirror once supported
- **Style / sprite / font registration** — Martin supports it, deferred
- **Authentication** — Martin has no built-in auth; add an OIDC reverse proxy when consumers arrive
- **Per-tile cache invalidation** when PMTiles regenerate — currently the whole pod reloads
- **Custom basemap style** in Maplibre/MapBox-style JSON pointing at Martin
