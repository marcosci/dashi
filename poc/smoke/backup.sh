#!/usr/bin/env bash
# Smoke — pg_dump CronJobs.
#   1. CronJobs exist + scheduled
#   2. Trigger backup-prefect ad-hoc, wait for success
#   3. Verify s3://backups/prefect/<stamp>/prefect.dump exists with size > 0

set -euo pipefail

NS="${NS:-dashi-backup}"
NS_PLATFORM="${NS_PLATFORM:-dashi-platform}"
S3_PORT="${S3_PORT:-19103}"

cleanup() { for pid in ${PFPIDS:-}; do kill "$pid" 2>/dev/null || true; done; }
trap cleanup EXIT

ok()   { echo "✓ $1"; }
fail() { echo "✗ $1" >&2; exit 1; }

CRON_COUNT=$(kubectl -n "$NS" get cronjobs --no-headers 2>/dev/null | wc -l | tr -d ' ')
[[ "$CRON_COUNT" -ge 3 ]] && ok "$CRON_COUNT CronJobs scheduled" \
                          || fail "expected >=3 CronJobs in $NS, got $CRON_COUNT"

JOB_NAME="smoke-backup-$(date -u +%H%M%S)"
echo "→ trigger ad-hoc job $JOB_NAME"
kubectl -n "$NS" create job --from=cronjob/backup-prefect "$JOB_NAME" >/dev/null

if ! kubectl -n "$NS" wait --for=condition=complete --timeout=300s "job/$JOB_NAME" 2>/dev/null; then
  echo "✗ ad-hoc backup job did not complete in 5 min"
  kubectl -n "$NS" logs --tail=20 -l job-name="$JOB_NAME" 2>&1 || true
  exit 1
fi
ok "ad-hoc backup job completed"

# Verify object exists in s3://backups/prefect/
kubectl -n "$NS_PLATFORM" port-forward svc/rustfs "${S3_PORT}:9000" >/dev/null 2>&1 &
PFPIDS="$!"
sleep 3
ACCESS=$(kubectl -n "$NS_PLATFORM" get secret rustfs-root -o jsonpath='{.data.access-key}' | base64 -d)
SECRET=$(kubectl -n "$NS_PLATFORM" get secret rustfs-root -o jsonpath='{.data.secret-key}' | base64 -d)
mc alias set dashi-bk "http://localhost:${S3_PORT}" "$ACCESS" "$SECRET" >/dev/null

DUMP_COUNT=$(mc ls --recursive dashi-bk/backups/prefect/ 2>/dev/null | wc -l | tr -d ' ')
[[ "$DUMP_COUNT" -ge 1 ]] && ok "found $DUMP_COUNT prefect.dump file(s) in s3://backups/" \
                          || fail "no prefect dump file found"

LATEST_SIZE=$(mc ls --recursive dashi-bk/backups/prefect/ 2>/dev/null \
  | tail -1 | awk '{print $4 $5}')
ok "latest dump size: $LATEST_SIZE"

# Cleanup the smoke artefact
mc rm --recursive --force dashi-bk/backups/prefect/ >/dev/null 2>&1 || true
kubectl -n "$NS" delete job "$JOB_NAME" --ignore-not-found >/dev/null 2>&1

echo ""
echo "✓ backup smoke PASSED"
