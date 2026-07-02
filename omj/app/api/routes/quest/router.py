"""FastAPI router for the Quest Variant domain.

Endpoints:
- POST /quests/{quest_id}/variants  — generate a variant (student, async)
- GET  /quests/{quest_id}/variants  — list variants for a quest (student)
- POST /quests/flows                — create a custom quest flow (teacher/admin)
- GET  /quests/flows/{flow_id}      — get a quest flow (teacher/admin)
"""
from __future__ import annotations

from typing import Any, Dict, Generic, List, Optional, TypeVar

from fastapi import APIRouter, Depends, HTTPException, Request

from app.api.routes.auth.middleware import require_role
from app.schemas.common import ApiResponse
from domain.quest.models import QuestFlow, QuestVariant
from domain.quest import repository as repo
from domain.quest.variant_engine import generate_variant
from services.ai.providers.base import get_default_provider
from services.jobs.state_machine import JobStateMachine
from pydantic import BaseModel

router = APIRouter(prefix="/quests", tags=["quests"])

T = TypeVar("T")


class CommonResponse(BaseModel, Generic[T]):
    """Unified API response envelope."""

    success: bool = True
    data: Optional[T] = None
    message: Optional[str] = None


class VariantListResponse(CommonResponse[List[QuestVariant]]):
    """Concrete response for a list of quest variants."""


class VariantResponse(CommonResponse[QuestVariant]):
    """Concrete response for a single quest variant."""


class FlowResponse(CommonResponse[QuestFlow]):
    """Concrete response for a single quest flow."""


class JobResponse(CommonResponse[Dict[str, Any]]):
    """Concrete response for an async job status."""


# ---------------------------------------------------------------------------
# Request schemas
# ---------------------------------------------------------------------------


class GenerateVariantRequest(BaseModel):
    """Body for POST /quests/{quest_id}/variants."""

    variant_type: str
    original_problem: Dict[str, Any]


class CreateFlowRequest(BaseModel):
    """Body for POST /quests/flows."""

    course_id: int
    quest_sequence: List[int]
    flow_rules: Optional[Dict[str, Any]] = None


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------


@router.post("/{quest_id}/variants", response_model=JobResponse)
async def create_variant(
    request: Request,
    quest_id: int,
    body: GenerateVariantRequest,
    _user=Depends(require_role("student", "teacher", "admin")),
):
    """Generate a quest variant asynchronously.

    Enqueues the generation job via ``JobStateMachine`` and returns the job id
    immediately so the client can poll for completion.
    TODO: add per-student rate limiting.
    """
    user_id = request.state.user_id

    sm = JobStateMachine()
    job = sm.start_job(
        user_id=user_id,
        job_type="quest_variant",
        payload={
            "quest_id": quest_id,
            "variant_type": body.variant_type,
            "original_problem": body.original_problem,
        },
    )
    job_id = job["job_id"]

    # TODO: kick off background worker to actually call generate_variant()
    # and transition the job to done/failed. For now we return the job id
    # so the client can poll /jobs/{job_id}.

    return JobResponse(
        data={"job_id": job_id, "status": job.get("status", "queued")},
        message="Variant generation queued",
    )


@router.get("/{quest_id}/variants", response_model=VariantListResponse)
async def list_variants(
    request: Request,
    quest_id: int,
    _user=Depends(require_role("student", "teacher", "admin")),
):
    """List all generated variants for a given original quest id."""
    variants = repo.list_variants_by_original(quest_id)
    return VariantListResponse(data=variants, message="Variants listed")


@router.post("/flows", response_model=FlowResponse)
async def create_flow(
    request: Request,
    body: CreateFlowRequest,
    _user=Depends(require_role("teacher", "admin")),
):
    """Create a custom quest flow (teacher/admin only)."""
    import json

    flow = QuestFlow(
        course_id=body.course_id,
        quest_sequence=body.quest_sequence,
        flow_rules_json=json.dumps(body.flow_rules, ensure_ascii=False) if body.flow_rules else None,
    )
    flow_id = repo.create_flow(flow)
    flow.id = flow_id
    return FlowResponse(data=flow, message="Quest flow created")


@router.get("/flows/{flow_id}", response_model=FlowResponse)
async def get_flow(
    request: Request,
    flow_id: int,
    _user=Depends(require_role("teacher", "admin")),
):
    """Retrieve a single quest flow by id (teacher/admin only)."""
    flow = repo.get_flow(flow_id)
    if flow is None:
        raise HTTPException(status_code=404, detail="Flow not found")
    return FlowResponse(data=flow, message="Quest flow retrieved")
