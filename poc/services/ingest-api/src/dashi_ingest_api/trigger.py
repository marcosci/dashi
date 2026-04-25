"""POST /trigger — create a Prefect flow run pointed at the landing s3_uri."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from .auth import Principal, current_user
from .clients import prefect_client
from .settings import settings

router = APIRouter()


class TriggerRequest(BaseModel):
    s3_uri: str
    domain: str
    classification: str = "int"
    collection_description: str | None = None


CLASSIFICATION_RANK = {"pub": 0, "int": 1, "rst": 2, "cnf": 3}


class TriggerResponse(BaseModel):
    flow_run_id: str
    flow_run_name: str
    state: str
    ui_url: str


@router.post("/trigger", response_model=TriggerResponse)
async def trigger(
    req: TriggerRequest,
    user: Principal = Depends(current_user),
) -> TriggerResponse:
    if not req.s3_uri.startswith(f"s3://{settings.landing_bucket}/"):
        raise HTTPException(
            status_code=400,
            detail=f"s3_uri must point at the {settings.landing_bucket} bucket",
        )

    cls = req.classification.lower()
    if cls not in CLASSIFICATION_RANK:
        raise HTTPException(
            status_code=400,
            detail=f"classification must be one of {sorted(CLASSIFICATION_RANK)}",
        )

    # Enforce the domain's max_classification ceiling. Read from STAC
    # collection extra_fields (populated at onboarding time, see
    # docs/onboarding/domain-template.md).
    from .clients import stac_client

    async with stac_client() as client:
        cr = await client.get(f"/collections/{req.domain}")
        if cr.status_code == 200:
            coll = cr.json()
            extra = coll.get("extra_fields") or coll
            ceiling = str(extra.get("dashi:max_classification", "cnf")).lower()
            if ceiling in CLASSIFICATION_RANK and CLASSIFICATION_RANK[cls] > CLASSIFICATION_RANK[ceiling]:
                raise HTTPException(
                    status_code=403,
                    detail=(
                        f"classification '{cls}' exceeds the {req.domain} domain "
                        f"ceiling '{ceiling}' — see docs/classification.md"
                    ),
                )

    parameters = {
        "source_path": req.s3_uri,
        "domain": req.domain,
        "classification": cls,
    }
    if req.collection_description:
        parameters["collection_description"] = req.collection_description

    async with prefect_client() as client:
        # 1. Resolve the deployment id from "<flow>/<deployment>"
        dep_resp = await client.get(f"/deployments/name/{settings.prefect_deployment_name}")
        if dep_resp.status_code != 200:
            raise HTTPException(
                status_code=502,
                detail=(
                    f"prefect deployment '{settings.prefect_deployment_name}' "
                    f"not found ({dep_resp.status_code})"
                ),
            )
        deployment_id = dep_resp.json()["id"]

        # 2. Create the flow run, tagged with the OIDC user for filtering.
        run_resp = await client.post(
            f"/deployments/{deployment_id}/create_flow_run",
            json={
                "parameters": parameters,
                "tags": [f"submitted-by:{user.user}", f"domain:{req.domain}"],
            },
        )
        if run_resp.status_code not in (200, 201):
            raise HTTPException(
                status_code=502,
                detail=f"prefect refused flow run ({run_resp.status_code}): {run_resp.text[:200]}",
            )
        run = run_resp.json()

    return TriggerResponse(
        flow_run_id=run["id"],
        flow_run_name=run["name"],
        state=(run.get("state") or {}).get("type", "PENDING"),
        ui_url=f"{settings.prefect_ui_url}/runs/flow-run/{run['id']}",
    )
