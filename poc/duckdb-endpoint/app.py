"""dashi DuckDB SQL endpoint — read-only analytical queries against s3 parquet.

Accepts JSON POST /query with `{"sql": "..."}`. Enforces a SELECT-only allowlist
at first-token check so the endpoint can never mutate state (F-23 — rollenbasiert
wird in Phase 2 geschärft; hier: harte Read-Only-Policy).

Env:
  RUSTFS_ENDPOINT   http://rustfs.dashi-platform.svc.cluster.local:9000
  RUSTFS_ACCESS_KEY access key
  RUSTFS_SECRET_KEY secret key
  RUSTFS_REGION     default us-east-1
  QUERY_TIMEOUT_SEC default 30
  MAX_ROWS          default 10000
"""

from __future__ import annotations

import logging
import os
import re
from typing import Any

import duckdb
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

logging.basicConfig(level=os.environ.get("LOG_LEVEL", "INFO"))
log = logging.getLogger("dashi-duckdb")

RUSTFS_ENDPOINT = os.environ.get(
    "RUSTFS_ENDPOINT", "http://rustfs.dashi-platform.svc.cluster.local:9000"
)
RUSTFS_ACCESS_KEY = os.environ["RUSTFS_ACCESS_KEY"]
RUSTFS_SECRET_KEY = os.environ["RUSTFS_SECRET_KEY"]
RUSTFS_REGION = os.environ.get("RUSTFS_REGION", "us-east-1")
QUERY_TIMEOUT_SEC = int(os.environ.get("QUERY_TIMEOUT_SEC", "30"))
MAX_ROWS = int(os.environ.get("MAX_ROWS", "10000"))

# Strip http(s):// for DuckDB's `s3_endpoint` setting, keep host:port
_host_match = re.match(r"^https?://(.+)$", RUSTFS_ENDPOINT)
RUSTFS_HOST = _host_match.group(1) if _host_match else RUSTFS_ENDPOINT
RUSTFS_USE_SSL = RUSTFS_ENDPOINT.startswith("https://")


def _build_connection() -> duckdb.DuckDBPyConnection:
    conn = duckdb.connect(database=":memory:")
    conn.execute("INSTALL spatial; LOAD spatial;")
    conn.execute("INSTALL httpfs; LOAD httpfs;")
    conn.execute(f"SET s3_region='{RUSTFS_REGION}';")
    conn.execute(f"SET s3_endpoint='{RUSTFS_HOST}';")
    conn.execute(f"SET s3_use_ssl={'true' if RUSTFS_USE_SSL else 'false'};")
    conn.execute("SET s3_url_style='path';")
    conn.execute(f"SET s3_access_key_id='{RUSTFS_ACCESS_KEY}';")
    conn.execute(f"SET s3_secret_access_key='{RUSTFS_SECRET_KEY}';")
    return conn


app = FastAPI(title="dashi DuckDB SQL Endpoint", version="0.1.0")


class QueryRequest(BaseModel):
    sql: str = Field(..., min_length=1)
    params: list[Any] | None = None


class QueryResponse(BaseModel):
    rows: list[dict]
    columns: list[str]
    row_count: int
    truncated: bool


_ALLOWED_PREFIX = re.compile(r"^\s*(with|select|describe|pragma show|pragma table_info)\b", re.IGNORECASE)
_FORBIDDEN = re.compile(
    r"\b(insert|update|delete|drop|create|alter|copy|attach|detach|"
    r"truncate|grant|revoke|export|import)\b",
    re.IGNORECASE,
)


def _validate_sql(sql: str) -> None:
    if not _ALLOWED_PREFIX.match(sql):
        raise HTTPException(status_code=400, detail="only SELECT/WITH/DESCRIBE/PRAGMA allowed")
    if _FORBIDDEN.search(sql):
        raise HTTPException(status_code=400, detail="write/DDL keywords forbidden")
    if ";" in sql.rstrip().rstrip(";"):
        raise HTTPException(status_code=400, detail="multiple statements not allowed")


@app.get("/_mgmt/ping")
def ping() -> dict:
    return {"message": "PONG"}


@app.get("/_mgmt/health")
def health() -> dict:
    try:
        conn = _build_connection()
        conn.execute("SELECT 1").fetchone()
        return {"status": "ok"}
    except Exception as e:  # noqa: BLE001
        raise HTTPException(status_code=503, detail=f"duckdb unavailable: {e}") from e


@app.post("/query", response_model=QueryResponse)
def run_query(req: QueryRequest) -> QueryResponse:
    _validate_sql(req.sql)
    conn = _build_connection()
    try:
        conn.execute(f"SET query_timeout={QUERY_TIMEOUT_SEC}s;")
    except duckdb.Error:
        # Some DuckDB versions use seconds, others different syntax — best-effort
        pass

    wrapped_sql = f"SELECT * FROM ({req.sql}) LIMIT {MAX_ROWS + 1}"
    try:
        cursor = conn.execute(wrapped_sql, req.params or [])
    except duckdb.Error as e:
        raise HTTPException(status_code=400, detail=f"query error: {e}") from e

    columns = [d[0] for d in cursor.description] if cursor.description else []
    raw_rows = cursor.fetchall()
    truncated = len(raw_rows) > MAX_ROWS
    if truncated:
        raw_rows = raw_rows[:MAX_ROWS]

    rows = [dict(zip(columns, r, strict=False)) for r in raw_rows]
    # DuckDB may return Decimal / datetime / memoryview — coerce for JSON
    rows = [{k: _coerce(v) for k, v in row.items()} for row in rows]
    return QueryResponse(rows=rows, columns=columns, row_count=len(rows), truncated=truncated)


def _coerce(v: Any) -> Any:
    if v is None:
        return None
    if isinstance(v, (str, int, float, bool)):
        return v
    if isinstance(v, bytes):
        return v.hex()
    return str(v)
