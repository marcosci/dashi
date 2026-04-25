#!/usr/bin/env bash
# Resume redeploy from catalog-rollout onwards (pgstac image already cached).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
POC_DIR="$REPO_ROOT/poc"
LOG_DIR="$REPO_ROOT/.redeploy-logs"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/redeploy-resume-$(date -u +%Y%m%dT%H%M%SZ).log"
ln -sfn "$(basename "$LOG")" "$LOG_DIR/latest.log"

step() { printf '\n========= [%s] %s =========\n' "$(date -u +%H:%M:%SZ)" "$*"; }

cd "$POC_DIR"

{
  step "Wait for stac-fastapi to recover"
  kubectl -n dashi-catalog rollout status deployment/stac-fastapi --timeout=300s

  step "RBAC bootstrap"
  make rbac-bootstrap

  step "Serving (TiTiler + DuckDB)"
  make serving-deploy

  step "Prefect"
  make prefect-up

  step "Prefect work pool patch"
  make prefect-patch-pool || true

  step "Monitoring"
  make monitoring-up

  step "NetworkPolicies"
  make network-policies-up

  step "OGC (PostGIS + Martin + PMTiles regen)"
  make ogc-deploy

  step "Smoke tests"
  make smoke || { echo "SMOKE FAILED"; exit 1; }

  step "DONE"
  kubectl get ns | grep -E '^(dashi|miso)-' || true
} >>"$LOG" 2>&1
