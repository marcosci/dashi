#!/usr/bin/env bash
# Spawn one K8s Job per point cloud STAC item to convert COPC → 3D Tiles
# tileset, written to s3://curated/3dtiles/<item_id>/.
#
# Discovers items by querying the live STAC catalog for collection items
# with `properties.dashi:kind == 'pointcloud'`.
#
# Usage:
#   bash 3dtiles-generate.sh                      # process every pointcloud item
#   ITEMS=item1,item2 bash 3dtiles-generate.sh    # restrict to specific items
#
# Writes Job specs into namespace dashi-data using the same
# rustfs-pipeline secret as the PMTiles flow.

set -euo pipefail

NS="${NS:-dashi-data}"
IMAGE="${P3DT_IMAGE:-dashi/py3dtiles:dev}"
STAC_URL="${STAC_URL:-http://stac-fastapi.dashi-catalog.svc.cluster.local:8080}"
COLLECTION="${COLLECTION:-gelaende-umwelt}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "→ collecting pointcloud items from STAC ($STAC_URL/collections/$COLLECTION)"

PORT=19181
kubectl -n dashi-catalog port-forward svc/stac-fastapi "$PORT:8080" >/tmp/dashi-3dt-pf.log 2>&1 &
PF_PID=$!
trap 'kill "$PF_PID" 2>/dev/null || true' EXIT
sleep 2

ITEMS_JSON="$(curl -sf "http://localhost:${PORT}/collections/${COLLECTION}/items?limit=200" || true)"

if [[ -z "${ITEMS:-}" ]]; then
  ITEMS="$(echo "$ITEMS_JSON" | python3 -c '
import json, sys
d = json.load(sys.stdin)
ids = [f["id"] for f in d.get("features", []) if f["properties"].get("dashi:kind") == "pointcloud"]
print(",".join(ids))
')"
fi

if [[ -z "$ITEMS" ]]; then
  echo "no pointcloud items found in $COLLECTION; nothing to do."
  exit 0
fi

echo "  ▸ items: $ITEMS"

IFS=',' read -r -a ITEM_ARR <<<"$ITEMS"
for item_id in "${ITEM_ARR[@]}"; do
  [[ -z "$item_id" ]] && continue

  src_uri="$(echo "$ITEMS_JSON" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for f in d.get('features', []):
    if f['id'] == '$item_id':
        a = f.get('assets', {}).get('data', {})
        print(a.get('href', ''))
        break
")"

  if [[ -z "$src_uri" ]]; then
    echo "  ✗ $item_id  no data asset"
    continue
  fi

  # asset href is http://rustfs.dashi-platform.svc... — convert to s3://
  s3_uri="$(python3 -c "
import re
u = '$src_uri'
m = re.match(r'https?://[^/]+/([^/]+)/(.+)', u)
if m:
    print(f's3://{m.group(1)}/{m.group(2)}')
else:
    print(u)
")"

  job_name="p3dt-$(echo "$item_id" | tr '_' '-' | cut -c1-50)"
  echo "  ▸ $item_id   $s3_uri  → s3://curated/3dtiles/$item_id/"

  kubectl -n "$NS" delete job "$job_name" --ignore-not-found >/dev/null 2>&1 || true

  kubectl -n "$NS" apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: $job_name
  labels:
    app.kubernetes.io/part-of: dashi
    app.kubernetes.io/component: 3dtiles-generator
spec:
  ttlSecondsAfterFinished: 3600
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: gen
          image: $IMAGE
          imagePullPolicy: IfNotPresent
          env:
            - name: ITEM_ID
              value: $item_id
            - name: SOURCE_URI
              value: $s3_uri
            - name: DASHI_S3_ENDPOINT
              valueFrom:
                secretKeyRef:
                  name: rustfs-pipeline
                  key: endpoint
            - name: DASHI_S3_ACCESS_KEY
              valueFrom:
                secretKeyRef:
                  name: rustfs-pipeline
                  key: access-key
            - name: DASHI_S3_SECRET_KEY
              valueFrom:
                secretKeyRef:
                  name: rustfs-pipeline
                  key: secret-key
          resources:
            requests:
              cpu: 500m
              memory: 1Gi
            limits:
              cpu: "2"
              memory: 4Gi
EOF
done

echo ""
echo "→ waiting for all p3dt-* Jobs to complete (up to 20 min)"
for j in $(kubectl -n "$NS" get jobs -l app.kubernetes.io/component=3dtiles-generator -o name); do
  if ! kubectl -n "$NS" wait --for=condition=complete --timeout=1200s "$j" 2>/dev/null; then
    echo "  ✗ ${j#job.batch/}"
    kubectl -n "$NS" logs "${j/job./jobs/}" --tail=30 || true
  else
    echo "  ✓ ${j#job.batch/}"
  fi
done
