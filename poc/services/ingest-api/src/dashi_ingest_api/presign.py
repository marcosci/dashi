"""POST /presign — mint a presigned PUT URL for a landing-zone upload."""

from __future__ import annotations

import re
import uuid

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from .auth import Principal, current_user
from .clients import s3_client
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

    url = s3_client().generate_presigned_url(
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
