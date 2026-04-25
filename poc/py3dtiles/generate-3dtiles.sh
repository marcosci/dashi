#!/usr/bin/env bash
# Generate a 3D Tiles tileset from a single COPC/LAZ source on RustFS,
# upload the tileset.json + .pnts chunks back to s3://curated/3dtiles/<id>/.
#
# Pipeline:
#   1. boto3 downloads the COPC LAZ (HTTP range, single file).
#   2. py3dtiles convert produces a local tileset directory.
#   3. boto3 uploads the entire tree under the curated prefix.
#
# Required env:
#   DASHI_S3_ENDPOINT, DASHI_S3_ACCESS_KEY, DASHI_S3_SECRET_KEY
#   ITEM_ID                # STAC item id (also used as tileset key)
#   SOURCE_URI             # s3://processed/.../<file>.copc.laz
# Optional:
#   CURATED_BUCKET         # default 'curated'
#   TILESET_PREFIX         # default '3dtiles/<ITEM_ID>'

set -euo pipefail

: "${DASHI_S3_ENDPOINT:?}"
: "${DASHI_S3_ACCESS_KEY:?}"
: "${DASHI_S3_SECRET_KEY:?}"
: "${ITEM_ID:?}"
: "${SOURCE_URI:?}"

CURATED_BUCKET="${CURATED_BUCKET:-curated}"
TILESET_PREFIX="${TILESET_PREFIX:-3dtiles/${ITEM_ID}}"

WORK_DIR="$(mktemp -d -p /tmp dashi-3dtiles.XXXXXX)"
SRC_LOCAL="${WORK_DIR}/source.copc.laz"
OUT_DIR="${WORK_DIR}/out"
mkdir -p "$OUT_DIR"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "→ item=$ITEM_ID  source=$SOURCE_URI  out=s3://${CURATED_BUCKET}/${TILESET_PREFIX}/"

WORK_DIR="$WORK_DIR" SRC_LOCAL="$SRC_LOCAL" OUT_DIR="$OUT_DIR" \
CURATED_BUCKET="$CURATED_BUCKET" TILESET_PREFIX="$TILESET_PREFIX" \
python3 - <<'PYEOF'
import os
import boto3
from botocore.client import Config

s3 = boto3.client(
    "s3",
    endpoint_url=os.environ["DASHI_S3_ENDPOINT"],
    aws_access_key_id=os.environ["DASHI_S3_ACCESS_KEY"],
    aws_secret_access_key=os.environ["DASHI_S3_SECRET_KEY"],
    config=Config(signature_version="s3v4", retries={"max_attempts": 10, "mode": "adaptive"}),
)

src = os.environ["SOURCE_URI"]
assert src.startswith("s3://"), f"SOURCE_URI must be s3://, got {src}"
_, _, rest = src.partition("s3://")
bucket, _, key = rest.partition("/")
print(f"  ↓ download s3://{bucket}/{key}")
s3.download_file(bucket, key, os.environ["SRC_LOCAL"])
PYEOF

echo "→ py3dtiles convert"
py3dtiles convert \
  --out "$OUT_DIR" \
  --overwrite \
  "$SRC_LOCAL"

echo "→ uploading tileset to s3://${CURATED_BUCKET}/${TILESET_PREFIX}/"
WORK_DIR="$WORK_DIR" OUT_DIR="$OUT_DIR" \
CURATED_BUCKET="$CURATED_BUCKET" TILESET_PREFIX="$TILESET_PREFIX" \
python3 - <<'PYEOF'
import os
from pathlib import Path
import boto3
from boto3.s3.transfer import TransferConfig
from botocore.client import Config

s3 = boto3.client(
    "s3",
    endpoint_url=os.environ["DASHI_S3_ENDPOINT"],
    aws_access_key_id=os.environ["DASHI_S3_ACCESS_KEY"],
    aws_secret_access_key=os.environ["DASHI_S3_SECRET_KEY"],
    config=Config(signature_version="s3v4", retries={"max_attempts": 10, "mode": "adaptive"}),
)
xfer = TransferConfig(multipart_threshold=8*1024*1024, multipart_chunksize=8*1024*1024)

bucket = os.environ["CURATED_BUCKET"]
prefix = os.environ["TILESET_PREFIX"].rstrip("/")
out = Path(os.environ["OUT_DIR"])

count = 0
for p in out.rglob("*"):
    if not p.is_file():
        continue
    key = f"{prefix}/{p.relative_to(out).as_posix()}"
    extra = {}
    if p.name.endswith(".json"):
        extra["ContentType"] = "application/json"
    elif p.name.endswith(".pnts"):
        extra["ContentType"] = "application/octet-stream"
    s3.upload_file(str(p), bucket, key, Config=xfer, ExtraArgs=extra)
    count += 1
print(f"  ✓ uploaded {count} files")
PYEOF

echo "✓ tileset published: s3://${CURATED_BUCKET}/${TILESET_PREFIX}/tileset.json"
