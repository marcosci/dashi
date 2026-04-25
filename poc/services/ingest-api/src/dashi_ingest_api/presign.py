"""POST /presign — mint a presigned PUT URL for a landing-zone upload."""

from __future__ import annotations

import re
import uuid

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field

from .auth import Principal, current_user
from .clients import s3_presign_client_for
from .settings import settings

router = APIRouter()

# Filename allowlist — letters, digits, dot, dash, underscore. No directory
# components. Filenames longer than 200 chars or with NUL/control bytes
# rejected. Real validation happens server-side after upload (MIME sniff).
_FILENAME_RE = re.compile(r"^[A-Za-z0-9._-]{1,200}$")


class PresignRequest(BaseModel):
    domain: str = Field(min_length=1, max_length=64, pattern=r"^[a-z0-9-]+$")
    filename: str = Field(min_length=1, max_length=200)
    content_type: str = Field(default="application/octet-stream", max_length=128)
    content_length: int = Field(ge=1)


class PresignResponse(BaseModel):
    url: str
    bucket: str
    key: str
    s3_uri: str
    expires_in: int


@router.post("/presign", response_model=PresignResponse)
def presign(
    req: PresignRequest,
    request: Request,
    user: Principal = Depends(current_user),
) -> PresignResponse:
    if req.content_length > settings.upload_max_bytes:
        raise HTTPException(
            status_code=413,
            detail=(
                f"file exceeds Phase-1 upload cap "
                f"({settings.upload_max_bytes // (1024 * 1024)} MiB). "
                "Use the dashi-ingest CLI for bulk uploads."
            ),
        )
    if not _FILENAME_RE.fullmatch(req.filename):
        raise HTTPException(
            status_code=400,
            detail="filename must match [A-Za-z0-9._-] and contain no path components",
        )

    upload_id = uuid.uuid4().hex
    key = f"{req.domain}/incoming/{upload_id}/{req.filename}"

    # Browser-reachable endpoint. The ingest-web nginx proxies /s3/* to
    # RustFS while preserving Host, so the presigned URL is same-origin
    # with the SPA → no CORS. Override via DASHI_API_S3_PUBLIC_ENDPOINT
    # for production ingress setups.
    fwd_proto = request.headers.get("x-forwarded-proto") or request.url.scheme
    fwd_host = (
        request.headers.get("x-forwarded-host")
        or request.headers.get("host")
        or "localhost"
    )
    # No /s3 prefix — SigV4 includes the path in the canonical request,
    # so any prefix-mount would break the signature at RustFS. nginx
    # routes /landing/, /processed/, /curated/, /backups/ to RustFS
    # directly with Host preserved.
    public_endpoint = settings.s3_public_endpoint or f"{fwd_proto}://{fwd_host}"

    url = s3_presign_client_for(public_endpoint).generate_presigned_url(
        "put_object",
        Params={
            "Bucket": settings.landing_bucket,
            "Key": key,
            "ContentType": req.content_type,
        },
        ExpiresIn=settings.presign_expiry_seconds,
        HttpMethod="PUT",
    )

    return PresignResponse(
        url=url,
        bucket=settings.landing_bucket,
        key=key,
        s3_uri=f"s3://{settings.landing_bucket}/{key}",
        expires_in=settings.presign_expiry_seconds,
    )
