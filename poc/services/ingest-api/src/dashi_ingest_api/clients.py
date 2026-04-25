"""Lazy singletons for external clients (S3 + Prefect + STAC)."""

from __future__ import annotations

from functools import lru_cache

import boto3
import httpx
from botocore.client import Config

from .settings import settings


def _make_client(endpoint: str):
    return boto3.client(
        "s3",
        endpoint_url=endpoint,
        region_name=settings.s3_region,
        aws_access_key_id=settings.s3_access_key,
        aws_secret_access_key=settings.s3_secret_key,
        config=Config(
            signature_version="s3v4",
            s3={"addressing_style": "path"},
            retries={"max_attempts": 5, "mode": "adaptive"},
            connect_timeout=10,
            read_timeout=60,
        ),
    )


@lru_cache(maxsize=1)
def s3_client():
    """Cluster-internal client. Used for /scan downloads."""
    return _make_client(settings.s3_endpoint)


@lru_cache(maxsize=8)
def s3_presign_client_for(endpoint: str):
    """Browser-facing client. Used to mint presigned URLs whose Host the
    browser can actually reach. The endpoint is computed per request from
    the inbound Host header (so a single deployment serves multiple
    port-forwards / domain names without redeploys)."""
    return _make_client(endpoint)


def stac_client() -> httpx.AsyncClient:
    return httpx.AsyncClient(base_url=settings.stac_url, timeout=15.0)


def prefect_client() -> httpx.AsyncClient:
    return httpx.AsyncClient(base_url=settings.prefect_api_url, timeout=15.0)
