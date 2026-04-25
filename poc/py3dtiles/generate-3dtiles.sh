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

# Stage 1 — PDAL: decompress COPC LAZ → plain LAS. py3dtiles' bundled
# lazrs decoder fails on COPC point-data with `failed to fill whole buffer`,
# so we hand off decompression to PDAL (rock-solid laszip backend).
SRC_LAS="${WORK_DIR}/source.las"
echo "→ pdal translate (COPC LAZ → plain LAS for py3dtiles)"
pdal translate "$SRC_LOCAL" "$SRC_LAS" --writers.las.compression=false

# Stage 2 — py3dtiles: LAS → 3D Tiles tileset
echo "→ py3dtiles convert"
py3dtiles convert \
  --out "$OUT_DIR" \
  --overwrite \
  "$SRC_LAS"

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

# PATCH the STAC item so the viewer can discover the tileset deterministically.
# stac-fastapi exposes JSON-Patch via PUT /collections/<c>/items/<id> (full
# item replace). We fetch, mutate, and put back.
if [[ -n "${STAC_URL:-}" && -n "${STAC_COLLECTION:-}" ]]; then
  echo "→ PATCH STAC item ${STAC_COLLECTION}/${ITEM_ID} with assets.tileset3d"
  STAC_URL="$STAC_URL" STAC_COLLECTION="$STAC_COLLECTION" \
  CURATED_BUCKET="$CURATED_BUCKET" TILESET_PREFIX="$TILESET_PREFIX" \
  ITEM_ID="$ITEM_ID" python3 - <<'PYEOF'
import json
import os
import urllib.request
import urllib.error

stac = os.environ["STAC_URL"].rstrip("/")
coll = os.environ["STAC_COLLECTION"]
item_id = os.environ["ITEM_ID"]
bucket = os.environ["CURATED_BUCKET"]
prefix = os.environ["TILESET_PREFIX"].rstrip("/")

# stac-fastapi internally exposes RustFS via http://rustfs.<ns>.svc:9000.
# Mirror what dashi_ingest.storage.s3_url does — same scheme is reachable
# from any pod in the cluster.
endpoint = os.environ.get("DASHI_S3_ENDPOINT", "http://rustfs.dashi-platform.svc.cluster.local:9000")
tileset_href = f"{endpoint.rstrip('/')}/{bucket}/{prefix}/tileset.json"

url = f"{stac}/collections/{coll}/items/{item_id}"
try:
    with urllib.request.urlopen(url, timeout=20) as r:
        item = json.load(r)
except urllib.error.HTTPError as e:
    print(f"  ✗ STAC GET failed ({e.code}); skipping asset patch")
    raise SystemExit(0)

item.setdefault("assets", {})["tileset3d"] = {
    "href":       tileset_href,
    "type":       "application/json",
    "title":      "3D Tiles tileset (py3dtiles)",
    "roles":      ["visualization", "3d-tiles"],
    "dashi:source_kind": "pointcloud",
}

req = urllib.request.Request(
    url,
    data=json.dumps(item).encode(),
    method="PUT",
    headers={"Content-Type": "application/json"},
)
try:
    with urllib.request.urlopen(req, timeout=20) as r:
        print(f"  ✓ STAC item updated (HTTP {r.status})")
except urllib.error.HTTPError as e:
    print(f"  ✗ STAC PUT failed (HTTP {e.code}): {e.read().decode()[:200]}")
    # Non-fatal — tileset is on disk regardless.
PYEOF
else
  echo "  (STAC_URL or STAC_COLLECTION unset — skipping asset patch)"
fi
