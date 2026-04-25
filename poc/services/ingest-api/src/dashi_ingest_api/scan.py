"""POST /scan — fetch a landing object + run dashi-ingest's detect.discover()."""

from __future__ import annotations

import tempfile
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from .auth import Principal, current_user
from .clients import s3_client
from .settings import settings

router = APIRouter()


class ScanRequest(BaseModel):
    s3_uri: str


class ScanRow(BaseModel):
    path: str
    kind: str
    driver: str | None
    layer: str | None
    reason: str | None
    ok: bool = True
    warnings: list[str] = []
    errors: list[str] = []


class ScanResponse(BaseModel):
    rows: list[ScanRow]
    primary_count: int
    blocking_errors: int = 0


def _parse_s3(uri: str) -> tuple[str, str]:
    if not uri.startswith("s3://"):
        raise HTTPException(status_code=400, detail="s3_uri must start with s3://")
    rest = uri[len("s3://") :]
    bucket, _, key = rest.partition("/")
    if not bucket or not key:
        raise HTTPException(status_code=400, detail="malformed s3_uri")
    if bucket != settings.landing_bucket:
        raise HTTPException(status_code=400, detail=f"scan only allowed on bucket={settings.landing_bucket}")
    return bucket, key


@router.post("/scan", response_model=ScanResponse)
def scan(
    req: ScanRequest,
    user: Principal = Depends(current_user),
) -> ScanResponse:
    # Defer the import: dashi_ingest pulls heavy GIS deps; we only need it
    # at request time. The same package the Prefect flow uses.
    from dashi_ingest import detect, validators

    bucket, key = _parse_s3(req.s3_uri)
    s3 = s3_client()

    with tempfile.TemporaryDirectory(prefix="dashi-scan-") as tmp:
        local = Path(tmp) / Path(key).name
        try:
            s3.download_file(bucket, key, str(local))
        except Exception as e:  # noqa: BLE001
            raise HTTPException(status_code=404, detail=f"s3 object not found: {e}") from e

        detections = detect.discover(local)
        rows: list[ScanRow] = []
        for d in detections:
            warnings: list[str] = []
            errors: list[str] = []
            ok = True

            if d.kind == "vector":
                vr = validators.validate_vector(d.path, layer=d.layer)
                ok, warnings, errors = vr.ok, list(vr.warnings), list(vr.errors)
            elif d.kind == "raster":
                vr = validators.validate_raster(d.path)
                ok, warnings, errors = vr.ok, list(vr.warnings), list(vr.errors)
            elif d.kind == "pointcloud":
                try:
                    vr = validators.validate_pointcloud(d.path)
                    ok, warnings, errors = vr.ok, list(vr.warnings), list(vr.errors)
                except ImportError as e:
                    ok = False
                    errors.append(f"pointcloud deps missing: {e}")

            rows.append(
                ScanRow(
                    path=str(d.path.name),
                    kind=d.kind,
                    driver=d.driver,
                    layer=d.layer,
                    reason=d.reason,
                    ok=ok,
                    warnings=warnings,
                    errors=errors,
                )
            )

        return ScanResponse(
            rows=rows,
            primary_count=sum(1 for d in detections if d.kind != "unknown"),
            blocking_errors=sum(1 for r in rows if not r.ok),
        )
