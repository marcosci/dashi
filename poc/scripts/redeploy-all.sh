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

  step "Prefect bootstrap (patch pool + register dashi-ingest deployment)"
  make prefect-bootstrap || true

  step "Monitoring (Prometheus + Grafana + kube-state-metrics)"
  make monitoring-up

  step "NetworkPolicies"
  make network-policies-up

  step "OGC (PostGIS + Martin + PMTiles regen)"
  make ogc-deploy || true

  step "Web ingest (ingest-api + ingest-web)"
  make web-ingest-deploy || true

  step "Iceberg REST catalog"
  make iceberg-deploy || true

  step "Backup CronJobs"
  make backup-deploy || true

  step "TiPG (OGC API – Features)"
  make tipg-deploy || true

  # LLM enrichment is optional — pulls a 2 GiB model. Off unless
  # explicitly opted in via DASHI_ENABLE_LLM=1.
  if [[ "${DASHI_ENABLE_LLM:-0}" == "1" ]]; then
    step "LLM enrichment (Ollama, optional)"
    make llm-deploy || true
  else
    step "LLM enrichment skipped (DASHI_ENABLE_LLM=1 to opt in)"
  fi

  step "Smoke tests"
  make smoke || { echo "SMOKE FAILED"; exit 1; }

  step "DONE"
  kubectl get ns | grep -E '^(dashi|miso)-' || true
} >>"$LOG" 2>&1
