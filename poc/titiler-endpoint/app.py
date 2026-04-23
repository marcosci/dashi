"""MISO COG tile endpoint — minimal FastAPI + rio-tiler.

Compatible subset of TiTiler endpoints: info, tilejson, tiles.
Built as an arm64-native image because the upstream titiler image only
publishes amd64; rebuilding from rio-tiler directly is simpler and faster
than cross-arch emulation for a PoC.
"""

from __future__ import annotations

import logging
import os
from urllib.parse import quote

from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import Response
from rio_tiler.errors import TileOutsideBounds
from rio_tiler.io import Reader

logging.basicConfig(level=os.environ.get("LOG_LEVEL", "INFO"))
log = logging.getLogger("miso-titiler")

# GDAL env for S3 is read from process env (set by the K8s deployment)
# AWS_S3_ENDPOINT, AWS_VIRTUAL_HOSTING, AWS_HTTPS, AWS_ACCESS_KEY_ID,
# AWS_SECRET_ACCESS_KEY, AWS_REGION, GDAL_DISABLE_READDIR_ON_OPEN

app = FastAPI(title="MISO COG tile endpoint", version="0.1.0")


def _open(url: str) -> Reader:
    try:
        return Reader(url)
    except Exception as e:  # noqa: BLE001
        raise HTTPException(status_code=400, detail=f"cannot open {url}: {e}") from e


@app.get("/_mgmt/ping")
def ping() -> dict:
    return {"message": "PONG"}


@app.get("/healthz")
def healthz() -> dict:
    return {"status": "ok"}


@app.get("/cog/info")
def info(url: str = Query(..., description="S3 or HTTP URL to COG")) -> dict:
    with _open(url) as src:
        info = src.info()
    return info.model_dump(mode="json")


@app.get("/cog/bounds")
def bounds(url: str = Query(...)) -> dict:
    with _open(url) as src:
        return {"bounds": list(src.bounds)}


@app.get("/cog/tilejson.json")
def tilejson(
    url: str = Query(...),
    tile_format: str = Query("png"),
    tile_scale: int = Query(1),
) -> dict:
    with _open(url) as src:
        info = src.info()
        b = src.bounds
        minzoom = src.minzoom
        maxzoom = src.maxzoom
    base = os.environ.get("TILE_BASE_URL", "")
    tiles_template = (
        f"{base}/cog/tiles/{{z}}/{{x}}/{{y}}.{tile_format}"
        f"?url={quote(url)}&tile_scale={tile_scale}"
    )
    return {
        "tilejson": "3.0.0",
        "name": info.dataset_statistics[0] if getattr(info, "dataset_statistics", None) else url,
        "tiles": [tiles_template],
        "bounds": list(b),
        "minzoom": minzoom,
        "maxzoom": maxzoom,
    }


@app.get("/cog/tiles/{z}/{x}/{y}.{fmt}")
def tile(z: int, x: int, y: int, fmt: str, url: str = Query(...), tile_scale: int = Query(1)) -> Response:
    fmt_lower = fmt.lower()
    if fmt_lower not in {"png", "jpeg", "jpg", "webp"}:
        raise HTTPException(status_code=400, detail=f"unsupported format: {fmt}")
    try:
        with _open(url) as src:
            tile_data = src.tile(x, y, z, tilesize=256 * tile_scale)
    except TileOutsideBounds:
        # Return transparent empty tile
        import io

        from PIL import Image

        img = Image.new("RGBA", (256 * tile_scale, 256 * tile_scale), (0, 0, 0, 0))
        buf = io.BytesIO()
        img.save(buf, format="PNG")
        return Response(content=buf.getvalue(), media_type="image/png")
    except Exception as e:  # noqa: BLE001
        raise HTTPException(status_code=500, detail=f"tile error: {e}") from e

    media_type = {"png": "image/png", "jpeg": "image/jpeg", "jpg": "image/jpeg", "webp": "image/webp"}[
        fmt_lower
    ]
    pil_fmt = {"png": "PNG", "jpeg": "JPEG", "jpg": "JPEG", "webp": "WEBP"}[fmt_lower]
    content = tile_data.render(img_format=pil_fmt)
    return Response(content=content, media_type=media_type)
