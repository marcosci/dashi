# duckdb-endpoint — SQL over GeoParquet in RustFS

FastAPI wrapper around an in-process DuckDB database with `spatial` + `httpfs` extensions. Serves `POST /query` with a SELECT-only allowlist for analytical SQL against GeoParquet in the Processed Zone.

## Why in-process DuckDB and not a DB server

DuckDB reads Parquet (and GeoParquet) directly from S3 via `httpfs`, applies `predicate pushdown` and `projection pushdown` per column, and crunches spatial joins with the `spatial` extension. No separate warehouse to operate, no data copy into a second store, no long-lived DB process to secure.

For PoC volumes (~1 GB, 367k features across 4000 partitions) DuckDB runs queries in sub-second on a single pod with 1 GB RAM. Scaling path: **horizontal pool of replicas behind a Service** (reads are independent) or **dedicated worker with more memory**; no architectural change required.

## Request shape

```http
POST /query
Content-Type: application/json

{ "sql": "SELECT COUNT(*) FROM read_parquet(['s3://processed/gelaende-umwelt/**/vector/**/*.parquet'])" }
```

Response:

```json
{
  "rows": [{"count_star()": 367219}],
  "columns": ["count_star()"],
  "row_count": 1,
  "truncated": false
}
```

## Safety rails

See the [manifest README](../manifests/duckdb-endpoint/README.md) — same rules enforced. The code is in `app.py::_validate_sql`.

## Build + run

```bash
docker build -t dashi/duckdb-endpoint:dev .
docker run --rm -p 8080:8080 \
  -e RUSTFS_ENDPOINT=http://host.docker.internal:9000 \
  -e RUSTFS_ACCESS_KEY=… \
  -e RUSTFS_SECRET_KEY=… \
  dashi/duckdb-endpoint:dev
```

Under k3d, `poc/scripts/serving-deploy.sh` handles build + import + deploy.

## Files

- `app.py` — FastAPI app with DuckDB connection factory + SELECT-only guard
- `Dockerfile` — python:3.12-slim + `fastapi`, `uvicorn[standard]`, `duckdb`, `pydantic`

## Known edge cases

- `SET query_timeout=…` syntax varies across DuckDB versions. Current code sets it best-effort and ignores the error when the version doesn't support it. Query still wall-clock-bounded by gunicorn/uvicorn request timeout.
- GeoParquet with >2 GB per partition should work via httpfs ranges, but not benchmarked yet.
- Results with geometry columns are coerced to WKT strings in `_coerce` for JSON serialisation.
