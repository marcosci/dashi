# Prefect (Strang F — Pipeline Orchestrierung)

Minimal Prefect 3 server deployed in the `dashi-data` namespace. Backs [ADR-010](../../../adr/ADR-010-pipeline-orchestration.md).

## PoC scope

- Single-replica Prefect server (SQLite-backed via `emptyDir` volume — fine for demo, not durable across pod restarts)
- No separate worker pod: the ingest flow runs locally against the server's API via a port-forward. Production-grade deployments would register a Kubernetes work pool and let Prefect schedule flow runs as K8s Jobs.
- No scheduler CRDs, no API auth, no TLS. All deferred to Phase 2.

## Components

| File | Purpose |
|------|---------|
| `namespace.yaml` | `dashi-data` namespace |
| `deployment-server.yaml` | Prefect 3.1.15 server on Python 3.12, port 4200, `emptyDir` volume |
| `service.yaml` | ClusterIP `prefect-server:4200` |
| `kustomization.yaml` | Apply with `kubectl apply -k .` |

## Apply

```bash
cd poc
make prefect-up
kubectl -n dashi-data rollout status deployment/prefect-server --timeout=180s
```

## Use

```bash
# port-forward the API (also serves the UI on the same host:port)
kubectl -n dashi-data port-forward svc/prefect-server 4200:4200 &

# tell the Prefect client which API to talk to
export PREFECT_API_URL=http://localhost:4200/api

# run the dashi-ingest flow locally against the server
cd poc/ingest
.venv/bin/pip install "prefect>=3.1,<4"

cd ../..
# point dashi-ingest at its creds
export DASHI_S3_ACCESS_KEY=$(kubectl -n dashi-platform get secret rustfs-root -o jsonpath='{.data.access-key}' | base64 -d)
export DASHI_S3_SECRET_KEY=$(kubectl -n dashi-platform get secret rustfs-root -o jsonpath='{.data.secret-key}' | base64 -d)
export DASHI_S3_ENDPOINT=http://localhost:9000

# run a one-shot flow
cd poc
.venv-flows/bin/python -m flows.ingest poc/sample-data/
```

Open the UI:

```
http://localhost:4200/
```

You'll see the flow run, the per-layer task graph, timing, logs, retries.

## Production hardening deferred

- Durable Postgres backend (replace `emptyDir` + SQLite with Postgres from `dashi-catalog` or a dedicated instance)
- K8s work pool + worker Deployment so flows run as isolated Jobs
- AuthN/Z: Prefect server is currently open on the cluster network
- Persistent flow storage (`prefect.yaml` committed to git, pulled by a runtime image)
- Scheduling (cron triggers for periodic landing-zone sweeps)
- Alert integration (Slack / email / Teams)
