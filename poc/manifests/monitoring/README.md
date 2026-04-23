# Observability — Prometheus + Grafana (Strang I)

Minimal in-cluster observability stack for the dashi PoC. Intentionally operator-free (no CRDs, no Prometheus Operator) so it slots into a small k3d cluster without 500 MB of overhead. Backs Phase-2 criteria _"Monitoring Dashboard aktiv"_ and _"Alert-Regeln definiert"_.

## Components

| File | Purpose |
|------|---------|
| `namespace.yaml` | `miso-monitoring` namespace |
| `rbac.yaml` | Prometheus ServiceAccount + ClusterRole (node, pod, service, endpoint scrape) |
| `kube-state-metrics.yaml` | kube-state-metrics Deployment — emits K8s object metrics as Prometheus timeseries |
| `prometheus.yaml` | Prometheus Deployment + Service + ConfigMap (scrape config + alert rules) — retains 7 days in `emptyDir` |
| `grafana.yaml` | Grafana Deployment + Service + Secret + provisioned datasource + provisioned `dashi · Platform Overview` dashboard |
| `kustomization.yaml` | `kubectl apply -k .` |

## Scrape jobs

1. **prometheus** self-scrape
2. **kubernetes-apiservers** — API-server metrics
3. **kubernetes-nodes** — kubelet metrics via API proxy
4. **kubernetes-cadvisor** — per-pod CPU/mem/network metrics
5. **kubernetes-pods** — any pod annotated `prometheus.io/scrape: "true"` with `prometheus.io/port: "<port>"` auto-discovered
6. **kube-state-metrics** — K8s object state

To add a custom service into Prometheus, annotate the pod:

```yaml
metadata:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port:   "9090"
    prometheus.io/path:   "/metrics"   # optional; default /metrics
```

## Alert rules (defined, delivery via Alertmanager deferred to Phase 3)

| Alert | Condition | Severity |
|-------|-----------|----------|
| `PodCrashLoop` | > 3 restarts in 5 min on any pod, 10 min persisting | warning |
| `DashiPodDown` | Pod in `Failed` / `Unknown` phase in a `miso-*` namespace for 5 min | critical |
| `PVCFull` | PVC < 20 % free for 10 min | warning |
| `DashiIngestFlowFailure` | Prefect flow-run entered `FAILED` in the last hour | warning |

Rules render on Prometheus → Alerts tab but do not dispatch anywhere. Alertmanager integration (email/Slack/Teams) is Phase 3.

## Apply

```bash
cd poc
make monitoring-up
```

Port-forward Grafana:

```bash
kubectl -n miso-monitoring port-forward svc/grafana 13000:3000 &
# Anonymous Viewer on; admin login: see Secret `grafana-admin` for rotated password
```

Grafana comes pre-configured with a `Prometheus` data source and the `dashi · Platform Overview` dashboard (4 stat panels + 3 timeseries — pods Running/CrashLooping, PVC fullness, namespace count, restarts, CPU, memory). Extend by dropping more JSON into `grafana-dashboards` ConfigMap or by creating dashboards via the UI (won't persist without a Grafana DB PVC, which is a Phase-2-hardening follow-up).

## Production hardening deferred

- Durable PVC for Prometheus + Grafana (currently both `emptyDir`)
- Alertmanager Deployment + receiver config (Slack/Email/PagerDuty)
- Remote write to long-term storage (Thanos / Mimir) — only needed when cluster retention exceeds 30 days
- Prometheus Operator CRDs (`ServiceMonitor`, `PrometheusRule`) if we scale past ~20 services
- Log aggregation with Loki (part of Strang I.5 — audit logs)
- Exporters per data service:
  - `postgres_exporter` sidecars for `pgstac-db` + `prefect-db`
  - `rustfs_exporter` or Prometheus-formatted `/metrics` on the RustFS pod
  - Custom `/metrics` endpoint on `miso-ingest`, `duckdb-endpoint`, `titiler-endpoint`
