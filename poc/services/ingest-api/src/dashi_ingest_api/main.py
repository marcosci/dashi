"""dashi-ingest-api FastAPI app — wires the four routers + CORS + healthz."""

from __future__ import annotations

from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware

from . import catalog, domains, multipart, presign, register, runs, scan, trigger
from .auth import Principal, current_user
from .settings import settings

app = FastAPI(
    title="dashi-ingest-api",
    version="0.1.0",
    description=(
        "Thin shim for the dashi web ingest UI. Wraps RustFS presigning, "
        "Prefect flow triggering, and STAC collection discovery — nothing "
        "else. Authenticated by trusted Authelia forward-auth headers; "
        "must be exposed only behind the Authelia-protected ingress."
    ),
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)

app.include_router(domains.router, tags=["domains"])
app.include_router(presign.router, tags=["upload"])
app.include_router(multipart.router, tags=["upload"])
app.include_router(register.router, tags=["upload"])
app.include_router(scan.router, tags=["upload"])
app.include_router(trigger.router, tags=["upload"])
app.include_router(catalog.router, tags=["catalog"])
app.include_router(runs.router, tags=["runs"])


@app.get("/healthz", tags=["health"])
def healthz() -> dict:
    return {"status": "ok", "service": "dashi-ingest-api", "version": "0.1.0"}


@app.get("/me", tags=["health"])
def me(user: Principal = Depends(current_user)) -> dict:
    return {"user": user.user, "groups": list(user.groups)}
