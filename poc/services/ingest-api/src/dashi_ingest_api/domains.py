"""GET /domains — list domains (= STAC collections + classification metadata)."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from .auth import Principal, current_user
from .clients import stac_client

router = APIRouter()


class Domain(BaseModel):
    id: str
    title: str
    description: str | None = None
    max_classification: str = "int"
    retention: str = "indefinite"


class DomainsResponse(BaseModel):
    domains: list[Domain]


@router.get("/domains", response_model=DomainsResponse)
async def domains(user: Principal = Depends(current_user)) -> DomainsResponse:
    async with stac_client() as client:
        r = await client.get("/collections")
        if r.status_code != 200:
            raise HTTPException(
                status_code=502,
                detail=f"stac /collections returned {r.status_code}",
            )
        body = r.json()

    out: list[Domain] = []
    for c in body.get("collections", []):
        # pgstac stores per-collection extras either under top-level keys or
        # nested "extra_fields"; tolerate both.
        extra = c.get("extra_fields") or c
        out.append(
            Domain(
                id=c["id"],
                title=c.get("title") or c["id"],
                description=c.get("description"),
                max_classification=str(extra.get("dashi:max_classification", "int")),
                retention=str(extra.get("dashi:retention", "indefinite")),
            )
        )
    return DomainsResponse(domains=out)
