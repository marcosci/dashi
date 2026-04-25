"""GET /runs — Prefect flow runs filtered by `submitted-by:<user>` tag."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from .auth import Principal, current_user
from .clients import prefect_client
from .settings import settings

router = APIRouter()


class FlowRun(BaseModel):
    id: str
    name: str
    state: str
    domain: str | None
    created: str
    started: str | None
    ended: str | None
    ui_url: str


class RunsResponse(BaseModel):
    runs: list[FlowRun]


@router.get("/runs", response_model=RunsResponse)
async def list_my_runs(
    limit: int = 50,
    all_users: bool = False,
    user: Principal = Depends(current_user),
) -> RunsResponse:
    if limit < 1 or limit > 200:
        raise HTTPException(status_code=400, detail="limit must be 1..200")

    tag = None if all_users else f"submitted-by:{user.user}"
    flow_runs_filter: dict = {
        "limit": limit,
        "sort": "START_TIME_DESC",
    }
    if tag:
        flow_runs_filter["flow_runs"] = {"tags": {"all_": [tag]}}

    async with prefect_client() as client:
        r = await client.post("/flow_runs/filter", json=flow_runs_filter)
        if r.status_code != 200:
            raise HTTPException(
                status_code=502,
                detail=f"prefect /flow_runs/filter {r.status_code}: {r.text[:200]}",
            )
        body = r.json()

    runs: list[FlowRun] = []
    for fr in body:
        tags: list[str] = fr.get("tags") or []
        domain = next((t.split(":", 1)[1] for t in tags if t.startswith("domain:")), None)
        state = (fr.get("state") or {}).get("type", "UNKNOWN")
        runs.append(
            FlowRun(
                id=fr["id"],
                name=fr.get("name", "?"),
                state=state,
                domain=domain,
                created=fr.get("created"),
                started=fr.get("start_time"),
                ended=fr.get("end_time"),
                ui_url=f"{settings.prefect_ui_url}/runs/flow-run/{fr['id']}",
            )
        )
    return RunsResponse(runs=runs)
