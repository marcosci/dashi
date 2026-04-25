#!/usr/bin/env bash
# Apply the dashi-backup namespace + 3 daily pg_dump CronJobs. The CronJobs
# need to read DB credentials from the source-DB namespaces and S3
# credentials from dashi-data — so we mirror those Secrets into
# dashi-backup at apply time. Re-run after Secret rotation.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NS="dashi-backup"

mirror_secret() {
  local src_ns="$1" name="$2"
  echo "  ▸ mirror $src_ns/$name → $NS/$name"
  kubectl -n "$src_ns" get secret "$name" -o yaml \
    | sed "s/namespace: ${src_ns}/namespace: ${NS}/" \
    | grep -v -E "^(  resourceVersion|  uid|  creationTimestamp|  ownerReferences):" \
    | kubectl apply -f -
}

echo "→ Applying $NS namespace"
kubectl apply -f "$REPO_ROOT/manifests/backup/namespace.yaml"

echo "→ Mirroring per-DB credentials into $NS"
mirror_secret dashi-catalog    pgstac-credentials
mirror_secret dashi-data       prefect-db
mirror_secret dashi-serving-db serving-postgis

echo "→ Mirroring S3 pipeline credentials into $NS"
mirror_secret dashi-data       dashi-rustfs-pipeline

echo "→ Applying CronJobs"
kubectl apply -f "$REPO_ROOT/manifests/backup/cronjobs.yaml"

echo ""
echo "✓ pg_dump CronJobs scheduled in $NS:"
kubectl -n "$NS" get cronjobs
echo ""
echo "  Trigger an ad-hoc run with:"
echo "    kubectl -n $NS create job --from=cronjob/backup-pgstac          backup-pgstac-now"
echo "    kubectl -n $NS create job --from=cronjob/backup-prefect         backup-prefect-now"
echo "    kubectl -n $NS create job --from=cronjob/backup-serving-postgis backup-serving-postgis-now"
echo ""
echo "  Then watch: kubectl -n $NS logs -f job/<name>"
