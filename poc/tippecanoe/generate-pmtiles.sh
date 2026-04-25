#!/usr/bin/env bash
# Generate PMTiles for one layer from RustFS GeoParquet.
#
# Pipeline:
#   1. boto3 lists *.parquet under the layer prefix and downloads each into
#      a flat local dir. We bypass /vsis3 directory mode because the
#      directory contains a sidecar (_metadata.json) that confuses GDAL's
#      Hive-partition autodetection.
#   2. ogr2ogr reads all .parquet files in the dir and writes a single
#      FlatGeobuf — uses GDAL 3.12 Parquet driver natively.
#   3. tippecanoe builds the PMTiles archive.
#   4. boto3 uploads PMTiles to s3://curated/tiles/<layer>.pmtiles.
#
# Required env:
#   MISO_S3_ENDPOINT, MISO_S3_ACCESS_KEY, MISO_S3_SECRET_KEY
#   LAYER_ID
#   LAYER_SOURCE_PREFIX (s3://processed/<...>/vector)
# Optional:
#   MIN_ZOOM (default 4), MAX_ZOOM (default 14)

set -euo pipefail

: "${MISO_S3_ENDPOINT:?}"
: "${MISO_S3_ACCESS_KEY:?}"
: "${MISO_S3_SECRET_KEY:?}"
: "${LAYER_ID:?}"
: "${LAYER_SOURCE_PREFIX:?}"

MIN_ZOOM="${MIN_ZOOM:-4}"
MAX_ZOOM="${MAX_ZOOM:-14}"

WORK_DIR="$(mktemp -d -p /tmp miso-pmtiles.XXXXXX)"
PARQ_DIR="${WORK_DIR}/parquet"
mkdir -p "$PARQ_DIR"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "→ layer=$LAYER_ID  source=$LAYER_SOURCE_PREFIX  zoom=${MIN_ZOOM}..${MAX_ZOOM}"

# Step 1: download .parquet files via boto3 (filter sidecars)
python3 - <<'PYEOF'
import os, sys, time
import boto3
from botocore.client import Config

src = os.environ["LAYER_SOURCE_PREFIX"]
endpoint = os.environ["MISO_S3_ENDPOINT"]
parq_dir = os.environ["PARQ_DIR"] if "PARQ_DIR" in os.environ else "/tmp/parq"
work_dir = os.environ.get("WORK_DIR", "/tmp/work")
PYEOF
# (the heredoc above is just to keep flake8 quiet — real work in next block)

WORK_DIR="$WORK_DIR" PARQ_DIR="$PARQ_DIR" python3 - <<'PYEOF'
import os, sys, time
import boto3
from botocore.client import Config

src = os.environ["LAYER_SOURCE_PREFIX"]
endpoint = os.environ["MISO_S3_ENDPOINT"]
parq_dir = os.environ["PARQ_DIR"]

assert src.startswith("s3://"), src
bucket, prefix = src[5:].split("/", 1)

client = boto3.client(
    "s3",
    endpoint_url=endpoint,
    region_name="us-east-1",
    aws_access_key_id=os.environ["MISO_S3_ACCESS_KEY"],
    aws_secret_access_key=os.environ["MISO_S3_SECRET_KEY"],
    config=Config(signature_version="s3v4", s3={"addressing_style": "path"}),
)

paginator = client.get_paginator("list_objects_v2")
keys = []
for page in paginator.paginate(Bucket=bucket, Prefix=prefix.rstrip("/") + "/"):
    for obj in page.get("Contents", []):
        if obj["Key"].endswith(".parquet"):
            keys.append(obj["Key"])
print(f"  ▸ {len(keys)} parquet partitions under s3://{bucket}/{prefix}")
if not keys:
    sys.exit(f"no parquet found under s3://{bucket}/{prefix}")

t0 = time.time()
for i, k in enumerate(keys):
    # Flatten to a unique local filename so they all sit in one dir
    rel = k[len(prefix.rstrip("/"))+1:]
    local_name = rel.replace("/", "__")
    client.download_file(bucket, k, os.path.join(parq_dir, local_name))
print(f"  ▸ downloaded {len(keys)} files in {time.time()-t0:.1f}s -> {parq_dir}")
PYEOF

# Step 2: ogr2ogr the directory of parquets -> FlatGeobuf
FGB_PATH="${WORK_DIR}/${LAYER_ID}.fgb"
echo "→ ogr2ogr $PARQ_DIR/*.parquet -> $FGB_PATH"

# Build a single FGB by concatenating each parquet into the same layer
FIRST=1
for f in "$PARQ_DIR"/*.parquet; do
  if [[ $FIRST -eq 1 ]]; then
    ogr2ogr -f FlatGeobuf -makevalid -t_srs EPSG:4326 -nln "$LAYER_ID" "$FGB_PATH" "$f" || true
    FIRST=0
  else
    ogr2ogr -f FlatGeobuf -update -append -makevalid -t_srs EPSG:4326 -nln "$LAYER_ID" "$FGB_PATH" "$f" || true
  fi
done
ogrinfo -so "$FGB_PATH" "$LAYER_ID" 2>/dev/null | grep -E "Feature Count|Geometry|Layer SRS" | sed 's/^/  /' || true

# Step 3: tippecanoe
PMT_PATH="${WORK_DIR}/${LAYER_ID}.pmtiles"
echo "→ tippecanoe -> $PMT_PATH"
tippecanoe \
  --output="$PMT_PATH" \
  --force \
  --name="dashi-${LAYER_ID}" \
  --layer="$LAYER_ID" \
  --minimum-zoom="$MIN_ZOOM" \
  --maximum-zoom="$MAX_ZOOM" \
  --drop-densest-as-needed \
  --extend-zooms-if-still-dropping \
  --no-tile-size-limit \
  --simplification=10 \
  "$FGB_PATH"

pmtiles show "$PMT_PATH" | head -20 || true

# Step 4: upload
echo "→ uploading to s3://curated/tiles/${LAYER_ID}.pmtiles"
PMT_PATH="$PMT_PATH" LAYER_ID="$LAYER_ID" python3 - <<'PYEOF'
import os, boto3
from botocore.client import Config
c = boto3.client(
    "s3",
    endpoint_url=os.environ["MISO_S3_ENDPOINT"],
    region_name="us-east-1",
    aws_access_key_id=os.environ["MISO_S3_ACCESS_KEY"],
    aws_secret_access_key=os.environ["MISO_S3_SECRET_KEY"],
    config=Config(signature_version="s3v4", s3={"addressing_style":"path"}),
)
c.upload_file(os.environ["PMT_PATH"], "curated", f"tiles/{os.environ['LAYER_ID']}.pmtiles")
print("uploaded")
PYEOF

echo "✓ ${LAYER_ID} -> s3://curated/tiles/${LAYER_ID}.pmtiles"
