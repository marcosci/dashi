"""Lazy singletons for external clients (S3 + Prefect + STAC)."""

from __future__ import annotations

from functools import lru_cache

import boto3
import httpx
from botocore.client import Config

from .settings import settings


@lru_cache(maxsize=1)
def s3_client():
    return boto3.client(
        "s3",
        endpoint_url=settings.s3_endpoint,
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


def stac_client() -> httpx.AsyncClient:
    return httpx.AsyncClient(base_url=settings.stac_url, timeout=15.0)


def prefect_client() -> httpx.AsyncClient:
    return httpx.AsyncClient(base_url=settings.prefect_api_url, timeout=15.0)
