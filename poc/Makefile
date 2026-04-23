.PHONY: help k3s-up k3s-down storage-deploy catalog-deploy serving-deploy prefect-up \
        ingest-sample smoke teardown docs-serve docs-build

help:
	@echo "MISO PoC targets"
	@echo ""
	@echo "  Cluster"
	@echo "    k3s-up          Start local k3d cluster (macOS/Windows) or native k3s (Linux)"
	@echo "    k3s-down        Tear cluster down"
	@echo ""
	@echo "  Platform"
	@echo "    storage-deploy    Deploy RustFS + create zone buckets (landing/processed/curated)"
	@echo "    catalog-deploy  Deploy stac-fastapi + PostgreSQL"
	@echo "    serving-deploy  Deploy TiTiler + DuckDB query endpoint"
	@echo "    prefect-up      Start Prefect server"
	@echo ""
	@echo "  Data"
	@echo "    ingest-sample   Run ingestion pipeline against poc/sample-data/"
	@echo "    smoke           Run Gate-1-equivalent acceptance checks"
	@echo ""
	@echo "  Docs"
	@echo "    docs-serve      Launch MkDocs Material locally (http://localhost:8000)"
	@echo "    docs-build      Build static site to site/"
	@echo ""
	@echo "  Housekeeping"
	@echo "    teardown        Remove all deployments (keeps cluster)"

CLUSTER_NAME ?= miso

k3s-up:
	@bash scripts/k3s-up.sh $(CLUSTER_NAME)

k3s-down:
	@bash scripts/k3s-down.sh $(CLUSTER_NAME)

storage-deploy:
	@echo "TODO: apply manifests/rustfs/"
	@exit 1

catalog-deploy:
	@echo "TODO: apply manifests/stac-fastapi/"
	@exit 1

serving-deploy:
	@echo "TODO: apply manifests/titiler/ + manifests/duckdb-endpoint/"
	@exit 1

prefect-up:
	@echo "TODO: apply manifests/prefect/"
	@exit 1

ingest-sample:
	@echo "TODO: python -m miso_ingest.cli ingest poc/sample-data/"
	@exit 1

smoke:
	@echo "TODO: bash smoke/run-all.sh"
	@exit 1

teardown:
	@echo "TODO: kubectl delete -k manifests/"

docs-serve:
	@cd .. && mkdocs serve

docs-build:
	@cd .. && mkdocs build
