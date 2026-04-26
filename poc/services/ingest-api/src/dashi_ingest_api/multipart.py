"""Multipart upload endpoints — for files larger than the single-PUT cap.

Workflow:
  1. POST /multipart/start  → server initiates an S3 multipart upload, mints
     one presigned URL per part. Browser receives `urls[]` aligned with the
     part numbers (1..N), uploads parts in parallel/sequence, captures each
     ETag from the response header.
  2. POST /multipart/complete → server calls CompleteMultipartUpload with the
     ETag list. RustFS assembles the parts into a single object.
  3. POST /multipart/abort   → server aborts an upload that the browser
     decides to give up on (free server-side storage of accumulated parts).

Part size and count are computed server-side from `content_length`, with a
floor of 5 MiB (S3 minimum, except last part) and a ceiling of 10000 parts
(S3 hard limit). Default part size = 16 MiB.
"""

from __future__ import annotations

import re
import uuid

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field

from .auth import Principal, current_user
from .clients import s3_client, s3_presign_client_for
from .settings import settings

router = APIRouter()

_FILENAME_RE = re.compile(r"^[A-Za-z0-9._-]{1,200}$")
_S3_MIN_PART = 5 * 1024 * 1024  # S3 hard floor (except last part)
_S3_MAX_PARTS = 10_000  # S3 hard ceiling


class MultipartStartRequest(BaseModel):
    domain: str = Field(min_length=1, max_length=64, pattern=r"^[a-z0-9-]+$")
    filename: str = Field(min_length=1, max_length=200)
    content_type: str = Field(default="application/octet-stream", max_length=128)
    content_length: int = Field(ge=1)


class MultipartStartResponse(BaseModel):
    upload_id: str
    bucket: str
    key: str
    s3_uri: str
    part_size: int
    part_count: int
    urls: list[str]
    expires_in: int


class MultipartPart(BaseModel):
    part_number: int = Field(ge=1, le=_S3_MAX_PARTS)
    etag: str = Field(min_length=1)


class MultipartCompleteRequest(BaseModel):
    bucket: str
    key: str
    upload_id: str
    parts: list[MultipartPart] = Field(min_length=1)


class MultipartCompleteResponse(BaseModel):
    s3_uri: str
    etag: str | None = None


class MultipartAbortRequest(BaseModel):
    bucket: str
    key: str
    upload_id: str


def _compute_part_size(content_length: int) -> tuple[int, int]:
    """Return (part_size, part_count) for the given total length.

    Tries the configured default first (16 MiB). If that overflows the
    10000-part S3 limit, scales the part size up just enough to fit.
    """
    base = max(settings.multipart_part_size_bytes, _S3_MIN_PART)
    n = (content_length + base - 1) // base
    if n <= _S3_MAX_PARTS:
        return base, n
    # Need bigger parts. Round up to the next 1 MiB so the math stays clean.
    needed = (content_length + _S3_MAX_PARTS - 1) // _S3_MAX_PARTS
    needed = ((needed + 1024 * 1024 - 1) // (1024 * 1024)) * 1024 * 1024
    n = (content_length + needed - 1) // needed
    return needed, n


@router.post("/multipart/start", response_model=MultipartStartResponse)
def multipart_start(
    req: MultipartStartRequest,
    request: Request,
    user: Principal = Depends(current_user),
) -> MultipartStartResponse:
    if req.content_length > settings.upload_max_bytes:
        raise HTTPException(
            status_code=413,
            detail=(
                f"file exceeds upload cap "
                f"({settings.upload_max_bytes // (1024 * 1024 * 1024)} GiB). "
                "Use the dashi-ingest CLI for bulk uploads."
            ),
        )
    if req.content_length < settings.multipart_threshold_bytes:
        raise HTTPException(
            status_code=400,
            detail=(
                f"content_length below multipart threshold "
                f"({settings.multipart_threshold_bytes // (1024 * 1024)} MiB) "
                "— use POST /presign for small files."
            ),
        )
    if not _FILENAME_RE.fullmatch(req.filename):
        raise HTTPException(
            status_code=400,
            detail="filename must match [A-Za-z0-9._-] and contain no path components",
        )

    upload_uuid = uuid.uuid4().hex
    key = f"{req.domain}/incoming/{upload_uuid}/{req.filename}"
    bucket = settings.landing_bucket

    # 1. Create the multipart upload server-side (cluster-internal client).
    s3 = s3_client()
    init = s3.create_multipart_upload(
        Bucket=bucket,
        Key=key,
        ContentType=req.content_type,
    )
    upload_id = init["UploadId"]

    # 2. Mint per-part presigned URLs against the browser-facing endpoint.
    fwd_proto = request.headers.get("x-forwarded-proto") or request.url.scheme
    fwd_host = request.headers.get("x-forwarded-host") or request.headers.get("host") or "localhost"
    public_endpoint = settings.s3_public_endpoint or f"{fwd_proto}://{fwd_host}"
    presigner = s3_presign_client_for(public_endpoint)

    part_size, part_count = _compute_part_size(req.content_length)
    urls: list[str] = []
    for part_number in range(1, part_count + 1):
        url = presigner.generate_presigned_url(
            "upload_part",
            Params={
                "Bucket": bucket,
                "Key": key,
                "UploadId": upload_id,
                "PartNumber": part_number,
            },
            ExpiresIn=settings.presign_expiry_seconds,
            HttpMethod="PUT",
        )
        urls.append(url)

    return MultipartStartResponse(
        upload_id=upload_id,
        bucket=bucket,
        key=key,
        s3_uri=f"s3://{bucket}/{key}",
        part_size=part_size,
        part_count=part_count,
        urls=urls,
        expires_in=settings.presign_expiry_seconds,
    )


@router.post("/multipart/complete", response_model=MultipartCompleteResponse)
def multipart_complete(
    req: MultipartCompleteRequest,
    user: Principal = Depends(current_user),
) -> MultipartCompleteResponse:
    if req.bucket != settings.landing_bucket:
        raise HTTPException(status_code=400, detail="bucket mismatch")
    if not req.key.startswith(tuple(f"{c}/incoming/" for c in [""])):
        # Sanity-check the key shape (domain/incoming/<uuid>/<filename>).
        parts = req.key.split("/")
        if len(parts) < 4 or parts[1] != "incoming":
            raise HTTPException(status_code=400, detail="malformed key")

    # Sort by part_number defensively — the S3 API requires ascending order.
    sorted_parts = sorted(req.parts, key=lambda p: p.part_number)
    s3 = s3_client()
    try:
        resp = s3.complete_multipart_upload(
            Bucket=req.bucket,
            Key=req.key,
            UploadId=req.upload_id,
            MultipartUpload={"Parts": [{"PartNumber": p.part_number, "ETag": p.etag} for p in sorted_parts]},
        )
    except Exception as e:  # noqa: BLE001
        raise HTTPException(
            status_code=502,
            detail=f"complete_multipart_upload failed: {e}",
        ) from e

    return MultipartCompleteResponse(
        s3_uri=f"s3://{req.bucket}/{req.key}",
        etag=resp.get("ETag"),
    )


@router.post("/multipart/abort")
def multipart_abort(
    req: MultipartAbortRequest,
    user: Principal = Depends(current_user),
) -> dict:
    if req.bucket != settings.landing_bucket:
        raise HTTPException(status_code=400, detail="bucket mismatch")
    s3 = s3_client()
    try:
        s3.abort_multipart_upload(
            Bucket=req.bucket,
            Key=req.key,
            UploadId=req.upload_id,
        )
    except Exception as e:  # noqa: BLE001
        # Abort is best-effort — RustFS GC sweeps stale uploads anyway.
        return {"ok": False, "detail": str(e)}
    return {"ok": True}
