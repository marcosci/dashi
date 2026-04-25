#!/usr/bin/env bash
# Kick off PMTiles generation for a hand-picked set of STAC items.
# One K8s Job per layer. Jobs write to s3://curated/tiles/<layer>.pmtiles
# using the dashi-pipeline IAM role (has curated/ write + processed/ read).
#
# Usage:
#   bash pmtiles-generate.sh               # uses built-in demo list
#   LAYERS=layer1.tsv bash pmtiles-generate.sh   # override with explicit TSV

set -euo pipefail

NS="${NS:-miso-data}"
IMAGE="${TIPPECANOE_IMAGE:-miso/tippecanoe:dev}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Built-in demo set — derived from live STAC catalog, 2026-04-25.
# Format: layer_id <TAB> source_prefix <TAB> min_zoom <TAB> max_zoom
read -r -d '' LAYERS_DATA <<'EOF' || true
osm_roads	s3://processed/gelaende-umwelt/0e80204b11694337/vector	5	14
osm_buildings	s3://processed/gelaende-umwelt/e697e674cbdbb8a0/vector	10	14
osm_landuse	s3://processed/gelaende-umwelt/3e101071b6b86e32/vector	6	13
osm_water	s3://processed/gelaende-umwelt/560d1c1d82d3d2bf/vector	5	13
osm_railways	s3://processed/gelaende-umwelt/2cd235c1855841ba/vector	6	14
mgrs_grids	s3://processed/gelaende-umwelt/28838a19ceacfdf3/vector	5	12
EOF

echo "→ spawning one K8s Job per layer in namespace $NS"
echo ""

while IFS=$'\t' read -r layer src minz maxz; do
  [[ -z "$layer" || "$layer" =~ ^# ]] && continue

  JOB_NAME="pmtiles-${layer//_/-}"
  echo "  ▸ $layer   $src  (z ${minz}..${maxz})"

  # delete prior Job (so we can re-run idempotently)
  kubectl -n "$NS" delete job "$JOB_NAME" --ignore-not-found >/dev/null 2>&1 || true

  kubectl -n "$NS" apply -f - <<EOF2
apiVersion: batch/v1
kind: Job
metadata:
  name: ${JOB_NAME}
  labels:
    app.kubernetes.io/name: pmtiles-generator
    app.kubernetes.io/part-of: miso
spec:
  backoffLimit: 2
  ttlSecondsAfterFinished: 7200
  template:
    metadata:
      labels:
        app.kubernetes.io/name: pmtiles-generator
    spec:
      restartPolicy: OnFailure
      containers:
        - name: gen
          image: ${IMAGE}
          imagePullPolicy: IfNotPresent
          command: ["/usr/local/bin/generate-pmtiles.sh"]
          env:
            - name: LAYER_ID
              value: "${layer}"
            - name: LAYER_SOURCE_PREFIX
              value: "${src}"
            - name: MIN_ZOOM
              value: "${minz}"
            - name: MAX_ZOOM
              value: "${maxz}"
            - name: MISO_S3_ENDPOINT
              valueFrom:
                secretKeyRef:
                  name: dashi-rustfs-pipeline
                  key: endpoint
            - name: MISO_S3_ACCESS_KEY
              valueFrom:
                secretKeyRef:
                  name: dashi-rustfs-pipeline
                  key: access-key
            - name: MISO_S3_SECRET_KEY
              valueFrom:
                secretKeyRef:
                  name: dashi-rustfs-pipeline
                  key: secret-key
          resources:
            requests:
              cpu: "200m"
              memory: "1Gi"
            limits:
              cpu: "2"
              memory: "4Gi"
EOF2
done <<<"$LAYERS_DATA"

echo ""
echo "→ waiting for all pmtiles-* Jobs to complete (up to 15 min)"
# Collect job names and wait sequentially — gives us cleaner logs
for job in $(kubectl -n "$NS" get jobs -l app.kubernetes.io/name=pmtiles-generator -o jsonpath='{.items[*].metadata.name}'); do
  kubectl -n "$NS" wait --for=condition=complete "job/$job" --timeout=900s >/dev/null 2>&1 \
    && echo "  ✓ $job" \
    || { echo "  ✗ $job"; kubectl -n "$NS" logs --tail=40 "job/$job" 2>&1 | sed 's/^/    /' ; }
done

echo ""
echo "✓ PMTiles generation pass complete"
