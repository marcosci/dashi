"""Runtime configuration. All settings come from env vars (12-factor)."""

from __future__ import annotations

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="DASHI_API_", case_sensitive=False)

    # S3 / RustFS
    s3_endpoint: str = Field(default="http://rustfs.dashi-platform.svc.cluster.local:9000")
    s3_region: str = Field(default="us-east-1")
    s3_access_key: str = ""
    s3_secret_key: str = ""
    landing_bucket: str = "landing"
    presign_expiry_seconds: int = 900  # 15 minutes
    upload_max_bytes: int = 1_073_741_824  # 1 GiB Phase-1 cap

    # Catalog (read-only)
    stac_url: str = "http://stac-fastapi.dashi-catalog.svc.cluster.local:8080"

    # Prefect
    prefect_api_url: str = "http://prefect-server.dashi-data.svc.cluster.local:4200/api"
    prefect_ui_url: str = "http://prefect-server.dashi-data.svc.cluster.local:4200"
    prefect_deployment_name: str = "dashi-ingest/main"

    # Auth
    # When mock_user is set, the API uses it as Remote-User regardless of headers
    # — only safe in local k3d. In production the ingress controller injects the
    # real Remote-User / Remote-Groups headers via Authelia forward-auth.
    mock_user: str = ""
    mock_groups: str = ""  # comma-separated

    # CORS
    cors_origins: str = "http://localhost:5173,http://localhost:8765"

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


settings = Settings()
