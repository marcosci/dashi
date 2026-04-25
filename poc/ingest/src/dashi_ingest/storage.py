"""S3-compatible storage helpers wired to RustFS (or any S3 endpoint).

Env:
  DASHI_S3_ENDPOINT       http(s) URL of the S3 API (default: http://localhost:9000)
  DASHI_S3_REGION         region name (default: us-east-1 — RustFS default)
  DASHI_S3_ACCESS_KEY     access key
  DASHI_S3_SECRET_KEY     secret key
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

import boto3
from boto3.s3.transfer import TransferConfig
from botocore.client import Config


@dataclass(frozen=True)
class S3Config:
    endpoint: str
    region: str
    access_key: str
    secret_key: str

    @classmethod
    def from_env(cls) -> S3Config:
        return cls(
            endpoint=os.environ.get("DASHI_S3_ENDPOINT", "http://localhost:9000"),
            region=os.environ.get("DASHI_S3_REGION", "us-east-1"),
            access_key=os.environ["DASHI_S3_ACCESS_KEY"],
            secret_key=os.environ["DASHI_S3_SECRET_KEY"],
        )

    def to_dict(self) -> dict:
        return {
            "endpoint": self.endpoint,
            "region": self.region,
            "access_key": self.access_key,
            "secret_key": self.secret_key,
        }


def delete_prefix(bucket: str, key_or_prefix: str, cfg: S3Config | None = None) -> int:
    """Delete every object under the given key_or_prefix. Returns count.

    Used by the retention flow: STAC asset hrefs point at a single object,
    but the dashi-ingest tree under that object's parent prefix may contain
    multiple files (e.g. vector partitions + _metadata.json sidecar). Treat
    the parent prefix as the unit of deletion.
    """
    s3 = s3_client(cfg)
    prefix = key_or_prefix
    if "/" in key_or_prefix:
        prefix = key_or_prefix.rsplit("/", 1)[0] + "/"
    deleted = 0
    paginator = s3.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        keys = [{"Key": o["Key"]} for o in page.get("Contents", []) or []]
        if not keys:
            continue
        s3.delete_objects(Bucket=bucket, Delete={"Objects": keys, "Quiet": True})
        deleted += len(keys)
    return deleted


_TRANSFER_CFG = TransferConfig(
    multipart_threshold=8 * 1024 * 1024,
    multipart_chunksize=8 * 1024 * 1024,
    max_concurrency=2,
    use_threads=True,
)


def s3_client(cfg: S3Config | None = None):
    cfg = cfg or S3Config.from_env()
    return boto3.client(
        "s3",
        endpoint_url=cfg.endpoint,
        region_name=cfg.region,
        aws_access_key_id=cfg.access_key,
        aws_secret_access_key=cfg.secret_key,
        config=Config(
            signature_version="s3v4",
            s3={"addressing_style": "path"},
            retries={"max_attempts": 10, "mode": "adaptive"},
            connect_timeout=30,
            read_timeout=120,
        ),
    )


def upload_tree(local_root: Path, bucket: str, key_prefix: str, cfg: S3Config | None = None) -> int:
    """Upload all files under `local_root` to `s3://{bucket}/{key_prefix}/...`.

    Preserves relative paths. Returns number of objects uploaded.
    """
    client = s3_client(cfg)
    n = 0
    for p in local_root.rglob("*"):
        if not p.is_file():
            continue
        rel = p.relative_to(local_root).as_posix()
        key = f"{key_prefix.rstrip('/')}/{rel}"
        client.upload_file(str(p), bucket, key, Config=_TRANSFER_CFG)
        n += 1
    return n


def processed_prefix(domain: str, dataset_id: str, kind: str) -> str:
    return f"{domain}/{dataset_id}/{kind}"


def s3_url(bucket: str, key: str, endpoint: str) -> str:
    base = endpoint.rstrip("/")
    return f"{base}/{bucket}/{key.lstrip('/')}"
