#!/usr/bin/env bash
# Rebuild custom images that were not auto-built by serving-deploy.sh,
# import them into k3d, then finish the redeploy (OGC + smoke).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
POC_DIR="$REPO_ROOT/poc"
LOG_DIR="$REPO_ROOT/.redeploy-logs"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/redeploy-resume2-$(date -u +%Y%m%dT%H%M%SZ).log"
ln -sfn "$(basename "$LOG")" "$LOG_DIR/latest.log"

step() { printf '\n========= [%s] %s =========\n' "$(date -u +%H:%M:%SZ)" "$*"; }

cd "$POC_DIR"
{
  step "Build dashi/tippecanoe:dev"
  docker build -t dashi/tippecanoe:dev tippecanoe

  step "Build dashi/dashi-ingest:dev"
  docker build -t dashi/dashi-ingest:dev ingest

  step "Import images into k3d cluster dashi"
  k3d image import dashi/tippecanoe:dev dashi/dashi-ingest:dev -c dashi

  step "Re-run OGC (PMTiles regen + Martin rollout)"
  make ogc-deploy

  step "Smoke tests"
  make smoke || { echo "SMOKE FAILED"; exit 1; }

  step "DONE"
  kubectl get ns | grep -E '^(dashi|miso)-' || true
} >>"$LOG" 2>&1
