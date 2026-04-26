"""POST /register — register an existing s3://landing/... object for ingest.

The browser-side upload path (`/presign` or `/multipart/*`) covers files
the user has on disk. But operators routinely pre-stage data into RustFS
out-of-band: rclone sync, `dashi-ingest` CLI, cron-pulled feeds. This
endpoint lets the UI pick up such an object, validate it exists, and feed
it into the same scan → trigger pipeline.

Validation rules:
  - URI must be inside the configured landing bucket (no cross-bucket
    register, no s3:// outside RustFS).
  - HEAD object must succeed (proves the object exists + we can read it).
  - Object size must be > 0 (catch incomplete writes).

This endpoint mints no credentials — it only checks the object exists and
returns the same metadata shape as /presign so the UI can reuse the rest
of its state machine.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from .auth import Principal, current_user
from .clients import s3_client
from .settings import settings

router = APIRouter()


class RegisterRequest(BaseModel):
    s3_uri: str = Field(min_length=8)


class RegisterResponse(BaseModel):
    s3_uri: str
    bucket: str
    key: str
    content_length: int
    content_type: str | None = None
    last_modified: str | None = None


def _parse_s3(uri: str) -> tuple[str, str]:
    if not uri.startswith("s3://"):
        raise HTTPException(status_code=400, detail="s3_uri must start with s3://")
    rest = uri[len("s3://") :]
    bucket, _, key = rest.partition("/")
    if not bucket or not key:
        raise HTTPException(status_code=400, detail="malformed s3_uri")
    if bucket != settings.landing_bucket:
        raise HTTPException(
            status_code=400,
            detail=(
                f"register only allowed on bucket={settings.landing_bucket}; "
                "stage objects there first (rclone, dashi-ingest CLI)."
            ),
        )
    if ".." in key.split("/"):
        raise HTTPException(status_code=400, detail="key must not contain '..'")
    return bucket, key


@router.post("/register", response_model=RegisterResponse)
def register(
    req: RegisterRequest,
    user: Principal = Depends(current_user),
) -> RegisterResponse:
    bucket, key = _parse_s3(req.s3_uri)
    s3 = s3_client()

    try:
        head = s3.head_object(Bucket=bucket, Key=key)
    except Exception as e:  # noqa: BLE001
        raise HTTPException(
            status_code=404,
            detail=f"s3 object not found: {e}",
        ) from e

    size = int(head.get("ContentLength", 0) or 0)
    if size <= 0:
        raise HTTPException(
            status_code=400,
            detail="object exists but is empty — re-upload or remove the stub",
        )

    last_modified = head.get("LastModified")
    last_modified_str = last_modified.isoformat() if hasattr(last_modified, "isoformat") else None

    return RegisterResponse(
        s3_uri=f"s3://{bucket}/{key}",
        bucket=bucket,
        key=key,
        content_length=size,
        content_type=head.get("ContentType"),
        last_modified=last_modified_str,
    )
