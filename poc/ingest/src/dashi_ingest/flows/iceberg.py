"""Promote curated GeoParquet → an Iceberg table.

Reads parquet files under s3://<bucket>/<prefix>/, registers them as a
new (or appended-to) Iceberg table via the REST catalog, returns the
fully-qualified table identifier so DuckDB / Trino / Spark can read it.

The Iceberg catalog itself runs in dashi-iceberg (manifests/iceberg/);
data files live under s3://curated/iceberg/<warehouse>/.

Usage:

    from dashi_ingest.flows.iceberg import promote_to_iceberg
    promote_to_iceberg.fn(
        table="gelaende_umwelt.osm_roads",
        source_prefix="s3://processed/gelaende-umwelt/<dataset>/vector/",
    )

DuckDB read path:

    INSTALL iceberg;
    LOAD iceberg;
    ATTACH 'http://iceberg-rest.dashi-iceberg.svc:8181' AS iceberg
        (TYPE iceberg);
    SELECT * FROM iceberg.gelaende_umwelt.osm_roads LIMIT 10;
"""

from __future__ import annotations

import os
import tempfile
from pathlib import Path

import pyarrow as pa
import pyarrow.parquet as pq
from prefect import flow, get_run_logger, task

from dashi_ingest import storage


def _read_curated_parquet(prefix_uri: str) -> pa.Table:
    """Download every *.parquet under the prefix into a tempdir + read once."""
    if not prefix_uri.startswith("s3://"):
        raise ValueError("source_prefix must start with s3://")
    rest = prefix_uri[len("s3://") :]
    bucket, _, key = rest.partition("/")
    prefix = key.rstrip("/") + "/"

    s3 = storage.s3_client()
    with tempfile.TemporaryDirectory(prefix="dashi-iceberg-") as tmp:
        local_dir = Path(tmp)
        paginator = s3.get_paginator("list_objects_v2")
        files: list[Path] = []
        for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
            for obj in page.get("Contents", []) or []:
                if not obj["Key"].endswith(".parquet"):
                    continue
                rel = obj["Key"][len(prefix) :]
                target = local_dir / rel
                target.parent.mkdir(parents=True, exist_ok=True)
                s3.download_file(bucket, obj["Key"], str(target))
                files.append(target)
        if not files:
            raise RuntimeError(f"no .parquet files under {prefix_uri}")
        return pq.ParquetDataset(local_dir).read()


@task(name="promote-iceberg")
def promote(
    table: str,
    source_prefix: str,
    *,
    catalog_uri: str | None = None,
    warehouse: str | None = None,
) -> dict:
    """Append a curated GeoParquet partition into an Iceberg table.

    Creates the namespace + table on the first call; subsequent calls
    append a new snapshot.
    """
    log = get_run_logger()
    catalog_uri = catalog_uri or os.environ.get(
        "DASHI_ICEBERG_REST_URI",
        "http://iceberg-rest.dashi-iceberg.svc.cluster.local:8181",
    )
    warehouse = warehouse or os.environ.get("DASHI_ICEBERG_WAREHOUSE", "s3://curated/iceberg/")

    if "." not in table:
        raise ValueError("table must be '<namespace>.<name>'")
    namespace, name = table.split(".", 1)

    # Heavy import — keep at runtime so the module imports cheaply elsewhere.
    from pyiceberg.catalog import load_catalog  # type: ignore[import-not-found]

    s3_cfg = storage.S3Config.from_env()
    catalog = load_catalog(
        "dashi",
        **{
            "type": "rest",
            "uri": catalog_uri,
            "warehouse": warehouse,
            "s3.endpoint": s3_cfg.endpoint,
            "s3.access-key-id": s3_cfg.access_key,
            "s3.secret-access-key": s3_cfg.secret_key,
            "s3.region": s3_cfg.region,
            "s3.path-style-access": "true",
        },
    )

    if (namespace,) not in catalog.list_namespaces():
        log.info("creating Iceberg namespace %s", namespace)
        catalog.create_namespace(namespace)

    log.info("reading parquet from %s", source_prefix)
    pa_table = _read_curated_parquet(source_prefix)
    log.info("loaded %s rows × %s cols", pa_table.num_rows, pa_table.num_columns)

    if (namespace, name) in catalog.list_tables(namespace):
        log.info("appending into existing table %s", table)
        tbl = catalog.load_table(table)
        tbl.append(pa_table)
    else:
        log.info("creating new Iceberg table %s", table)
        tbl = catalog.create_table(table, schema=pa_table.schema)
        tbl.append(pa_table)

    return {
        "table": table,
        "rows_appended": pa_table.num_rows,
        "snapshot_id": tbl.current_snapshot().snapshot_id if tbl.current_snapshot() else None,
        "metadata_location": tbl.metadata_location,
    }


@flow(name="dashi-iceberg-promote")
def promote_flow(
    table: str,
    source_prefix: str,
) -> dict:
    return promote(table, source_prefix)


if __name__ == "__main__":
    import argparse

    p = argparse.ArgumentParser()
    p.add_argument("--table", required=True, help="<namespace>.<name>")
    p.add_argument("--source", required=True, help="s3://bucket/prefix/")
    args = p.parse_args()
    print(promote_flow(args.table, args.source))
