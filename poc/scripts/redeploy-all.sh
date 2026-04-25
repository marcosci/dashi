#!/usr/bin/env bash
# One-shot full redeploy. Tears the dashi k3d cluster down, brings it back,
# and deploys every component. Designed to run unattended in the background.
# Streams progress to a log file alongside the script.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
POC_DIR="$REPO_ROOT/poc"
LOG_DIR="$REPO_ROOT/.redeploy-logs"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/redeploy-$(date -u +%Y%m%dT%H%M%SZ).log"
ln -sfn "$(basename "$LOG")" "$LOG_DIR/latest.log"

step() {
  printf '\n========= [%s] %s =========\n' "$(date -u +%H:%M:%SZ)" "$*"
}

cd "$POC_DIR"

{
  step "Tear cluster down"
  make k3s-down || true

  step "Bring cluster up"
  make k3s-up

  step "Storage (RustFS + buckets)"
  make storage-deploy

  step "Catalog (pgstac + stac-fastapi)"
  make catalog-deploy

  step "RBAC bootstrap"
  make rbac-bootstrap

  step "Serving (TiTiler + DuckDB)"
  make serving-deploy

  step "Prefect"
  make prefect-up

  step "Prefect work pool patch"
  make prefect-patch-pool || true

  step "Monitoring (Prometheus + Grafana + kube-state-metrics)"
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
