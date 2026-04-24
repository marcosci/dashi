.PHONY: help k3s-up k3s-down storage-deploy catalog-deploy serving-deploy prefect-up \
        monitoring-up rbac-bootstrap network-policies-up prefect-patch-pool \
        ingest-sample smoke teardown docs-serve docs-build

help:
	@echo "dashi PoC targets"
	@echo ""
	@echo "  Cluster"
	@echo "    k3s-up          Start local k3d cluster (macOS/Windows) or native k3s (Linux)"
	@echo "    k3s-down        Tear cluster down"
	@echo ""
	@echo "  Platform"
	@echo "    storage-deploy    Deploy RustFS + create zone buckets (landing/processed/curated)"
	@echo "    catalog-deploy  Deploy stac-fastapi + PostgreSQL"
	@echo "    serving-deploy  Deploy TiTiler + DuckDB query endpoint"
	@echo "    prefect-up      Start Prefect server + worker (K8s work pool)"
	@echo "    monitoring-up   Deploy Prometheus + Grafana + kube-state-metrics"
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
	@bash scripts/apply-with-secret.sh manifests/rustfs secret.yaml CHANGE_ME_ROOT_PASSWORD
	@echo ""
	@echo "→ Waiting for RustFS to be Ready"
	kubectl -n miso-platform rollout status statefulset/rustfs --timeout=180s
	@echo ""
	@echo "→ Waiting for bucket-init Job"
	kubectl -n miso-platform wait --for=condition=complete job/rustfs-create-buckets --timeout=120s
	@echo ""
	@echo "✓ RustFS ready. Buckets: landing / processed / curated"
	@echo "  Port-forward with: kubectl -n miso-platform port-forward svc/rustfs 9000:9000 9001:9001"

catalog-deploy:
	@bash scripts/apply-with-secret.sh manifests/pgstac secret.yaml CHANGE_ME_PG_PASSWORD
	@echo ""
	@echo "→ Waiting for Postgres (pgstac) StatefulSet"
	kubectl -n miso-catalog rollout status statefulset/pgstac --timeout=180s
	@echo ""
	@echo "→ Waiting for pgstac migration Job"
	kubectl -n miso-catalog wait --for=condition=complete job/pgstac-migrate --timeout=180s
	@echo ""
	@echo "→ Waiting for stac-fastapi Deployment"
	kubectl -n miso-catalog rollout status deployment/stac-fastapi --timeout=180s
	@echo ""
	@echo "✓ Catalog ready. stac-fastapi on svc/stac-fastapi:8080 in miso-catalog"
	@echo "  Port-forward: kubectl -n miso-catalog port-forward svc/stac-fastapi 8080:8080"

serving-deploy:
	@bash scripts/serving-deploy.sh

rbac-bootstrap:
	@bash scripts/rbac-bootstrap.sh

network-policies-up:
	kubectl apply -k manifests/network-policies
	@echo ""
	@echo "✓ NetworkPolicies applied (12 total: default-deny per namespace + scoped allows)"

prefect-patch-pool:
	@bash scripts/prefect-patch-pool.sh

monitoring-up:
	@bash scripts/apply-with-secret.sh manifests/monitoring grafana.yaml CHANGE_ME_GRAFANA_ADMIN
	@echo ""
	@echo "→ Waiting for Prometheus"
	kubectl -n miso-monitoring rollout status deployment/prometheus --timeout=180s
	@echo "→ Waiting for kube-state-metrics"
	kubectl -n miso-monitoring rollout status deployment/kube-state-metrics --timeout=120s
	@echo "→ Waiting for Grafana"
	kubectl -n miso-monitoring rollout status deployment/grafana --timeout=180s
	@echo ""
	@echo "✓ Monitoring up. Port-forwards:"
	@echo "  kubectl -n miso-monitoring port-forward svc/prometheus 9090:9090"
	@echo "  kubectl -n miso-monitoring port-forward svc/grafana    3000:3000"

prefect-up:
	@bash scripts/apply-with-secret.sh manifests/prefect statefulset-postgres.yaml CHANGE_ME_PREFECT_DB
	@echo ""
	@echo "→ Waiting for Prefect DB"
	kubectl -n miso-data rollout status statefulset/prefect-db --timeout=180s
	@echo "→ Waiting for Prefect server"
	kubectl -n miso-data rollout status deployment/prefect-server --timeout=240s
	@echo "→ Waiting for Prefect worker"
	kubectl -n miso-data rollout status deployment/prefect-worker --timeout=180s
	@echo ""
	@echo "✓ Prefect up. Port-forward with:"
	@echo "  kubectl -n miso-data port-forward svc/prefect-server 4200:4200"
	@echo "  then visit http://localhost:4200/  (UI) and set PREFECT_API_URL=http://localhost:4200/api"

ingest-sample:
	@bash scripts/ingest-sample.sh

smoke:
	@bash smoke/catalog.sh
	@bash smoke/ingest.sh
	@bash smoke/serving.sh
	@bash smoke/prefect.sh
	@bash smoke/rbac.sh
	@bash smoke/monitoring.sh

teardown:
	@echo "TODO: kubectl delete -k manifests/"

docs-serve:
	@cd .. && mkdocs serve

docs-build:
	@cd .. && mkdocs build
