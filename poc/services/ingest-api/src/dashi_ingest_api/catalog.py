"""GET /catalog/items — paginated STAC items with classification + lineage."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from .auth import Principal, current_user
from .clients import stac_client

router = APIRouter()


class CatalogItem(BaseModel):
    id: str
    collection: str
    datetime: str | None
    kind: str | None
    classification: str
    source_name: str | None
    object_count: int | None
    bbox: list[float] | None
    prefect_flow_run_id: str | None = None
    prefect_flow_run_url: str | None = None
    prefect_flow_name: str | None = None
    asset_keys: list[str]


class CatalogResponse(BaseModel):
    items: list[CatalogItem]
    next: str | None = None


@router.get("/catalog/items/{collection}/{item_id}")
async def catalog_item_detail(
    collection: str,
    item_id: str,
    user: Principal = Depends(current_user),
) -> dict:
    """Return the raw STAC item — drives the Catalog drill-down side panel."""
    async with stac_client() as client:
        r = await client.get(f"/collections/{collection}/items/{item_id}")
        if r.status_code == 404:
            raise HTTPException(status_code=404, detail="item not found")
        if r.status_code != 200:
            raise HTTPException(status_code=502, detail=f"stac {r.status_code}")
    return r.json()


@router.get("/catalog/items", response_model=CatalogResponse)
async def catalog_items(
    collection: str | None = None,
    classification: str | None = None,
    kind: str | None = None,
    limit: int = 50,
    user: Principal = Depends(current_user),
) -> CatalogResponse:
    if limit < 1 or limit > 200:
        raise HTTPException(status_code=400, detail="limit must be 1..200")

    if collection:
        path = f"/collections/{collection}/items"
    else:
        path = "/search"

    params: dict = {"limit": limit}
    # pgstac STAC search supports `query` for property filters; in PoC we
    # filter client-side after fetching to keep the shim trivial.
    async with stac_client() as client:
        if collection:
            r = await client.get(path, params=params)
        else:
            r = await client.post(path, json=params)
        if r.status_code != 200:
            raise HTTPException(status_code=502, detail=f"stac {path} {r.status_code}")
        body = r.json()

    out: list[CatalogItem] = []
    for f in body.get("features", []):
        props = f.get("properties", {}) or {}
        if kind and props.get("dashi:kind") != kind:
            continue
        cls = str(props.get("dashi:classification", "int"))
        if classification and cls != classification:
            continue
        out.append(
            CatalogItem(
                id=f["id"],
                collection=f.get("collection") or collection or "",
                datetime=props.get("datetime"),
                kind=props.get("dashi:kind"),
                classification=cls,
                source_name=props.get("dashi:source_name"),
                object_count=props.get("dashi:object_count"),
                bbox=f.get("bbox"),
                prefect_flow_run_id=props.get("dashi:prefect_flow_run_id"),
                prefect_flow_run_url=props.get("dashi:prefect_flow_run_url"),
                prefect_flow_name=props.get("dashi:prefect_flow_name"),
                asset_keys=list((f.get("assets") or {}).keys()),
            )
        )

    return CatalogResponse(items=out)
