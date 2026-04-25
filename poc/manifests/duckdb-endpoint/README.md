# DuckDB SQL Endpoint

Analytical SQL over GeoParquet in the Curated Zone (and Processed Zone during PoC). Backs [ADR-007](../../../adr/ADR-007-processing-engine.md) analytical slice and [ADR-009](../../../adr/ADR-009-serving-layer.md) SQL slice. Maps to requirement **F-20** (analytical SQL on Vektordaten).

## What it is

FastAPI + DuckDB 1.1.3 with `spatial` + `httpfs` extensions. Query body goes through a SELECT-only allowlist before execution. S3 credentials and endpoint come from env injected by the K8s Deployment. Source: [`poc/duckdb-endpoint/`](../../duckdb-endpoint/).

## Security posture

| Guard | Where |
|-------|-------|
| First-token allowlist (`with`, `select`, `describe`, `pragma`) | `_validate_sql` |
| Forbidden-keyword regex (`insert`, `update`, `delete`, `drop`, `create`, `alter`, `copy`, `attach`, `detach`, `truncate`, `grant`, `revoke`, `export`, `import`) | `_validate_sql` |
| Single-statement: trailing `;` allowed once, no stacked statements | `_validate_sql` |
| Row cap | `MAX_ROWS`, default 10 000. Responses include `truncated: true` when clipped |
| Query timeout | `QUERY_TIMEOUT_SEC`, default 30 |
| Network | ClusterIP only; no ingress; port-forward or sidecar to reach |

## API

| Endpoint | Purpose |
|----------|---------|
| `GET /_mgmt/ping` | probes |
| `GET /_mgmt/health` | runs `SELECT 1`, 503 on DuckDB init failure |
| `POST /query` | body: `{"sql": "<SELECT ...>", "params": [optional]}` → `{"rows", "columns", "row_count", "truncated"}` |

## Example queries

```sql
-- count all features ingested
SELECT COUNT(*) FROM read_parquet(['s3://processed/gelaende-umwelt/**/vector/**/*.parquet']);

-- bbox filter around Frauenkirche Dresden
SELECT COUNT(*)
FROM read_parquet(['s3://processed/gelaende-umwelt/**/vector/**/*.parquet'])
WHERE ST_Intersects(geometry, ST_MakeEnvelope(13.73, 51.04, 13.76, 51.06));

-- per-layer feature counts for a specific dataset
SELECT COUNT(*) AS n
FROM read_parquet(['s3://processed/gelaende-umwelt/0e80204b11694337/vector/**/*.parquet']);
```

## Components

| File | Purpose |
|------|---------|
| `namespace.yaml` | `dashi-serving` namespace |
| `deployment.yaml` | runs `dashi/duckdb-endpoint:dev`, reads `rustfs-client` secret |
| `service.yaml` | ClusterIP `duckdb-endpoint:8080` |
| `kustomization.yaml` | apply via `kubectl apply -k .` |

## Apply

```bash
cd poc
make serving-deploy         # builds image + applies
kubectl -n dashi-serving port-forward svc/duckdb-endpoint 18091:8080 &
curl -X POST http://localhost:18091/query \
  -H 'Content-Type: application/json' \
  -d '{"sql":"SELECT 1 AS one"}'
```

## Production hardening deferred

- Query result caching (Redis or local LRU)
- Per-caller quota + rate limit (Phase 2 with role-based policies)
- Read-replicated DuckDB pool for throughput (horizontal scaling)
- Spill-to-disk tuning for large joins (`memory_limit`, `temp_directory` sized to a PVC)
- Prometheus metrics exporter (query counts, latency, row volume)
