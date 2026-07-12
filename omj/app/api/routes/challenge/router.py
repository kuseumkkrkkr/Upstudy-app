"""FastAPI router for the Challenge domain."""
from __future__ import annotations

from typing import Any, List, Optional

from fastapi import APIRouter, Depends, Request

from app.api.routes.auth.middleware import require_role
from app.api.routes.challenge import service
from app.schemas.common import ApiResponse, JobStatus

router = APIRouter(prefix="/challenges", tags=["challenges"])

# Preserve existing module-level test/legacy references after service extraction.
_ALLOWED_DAILY_TYPES = service._ALLOWED_DAILY_TYPES
_build_daily_items = service._build_daily_items
_load_or_create_daily_quests = service._load_or_create_daily_quests


# ---------------------------------------------------------------------------
# Request / response schemas
# ---------------------------------------------------------------------------


class AttemptRequest:
    """Body for POST /challenges/{id}/attempt."""

    answers: List[int]


class AttemptResponse(ApiResponse):
    """Response for a challenge attempt."""

    pass


class ChallengeListResponse(ApiResponse):
    """Response for listing challenges."""

    pass


class ProgressResponse(ApiResponse):
    """Response for a single progress record."""

    pass


class GenerateResponse(ApiResponse):
    """Response for challenge generation."""

    pass


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------


@router.get("/daily-quests", response_model=ApiResponse)
async def get_daily_quests(
    request: Request,
    course_id: str,
    _user=Depends(require_role("student", "teacher", "admin")),
):
    user_id: str = request.state.user_id
    data = service.get_daily_quests(user_id, course_id)
    return ApiResponse(status=JobStatus.done, data=data, message="Daily quests ready")


@router.post("/daily-quests/event", response_model=ApiResponse)
async def apply_daily_quest_event(
    request: Request,
    body: dict[str, Any],
    _user=Depends(require_role("student")),
):
    user_id: str = request.state.user_id
    data, _updated = service.apply_daily_quest_event(user_id, body)
    return ApiResponse(status=JobStatus.done, data=data, message="Daily quest event applied")


@router.post("/daily-quests/complete", response_model=ApiResponse)
async def complete_daily_quest(
    request: Request,
    body: dict[str, Any],
    _user=Depends(require_role("student")),
):
    user_id: str = request.state.user_id
    data = service.complete_daily_quest(user_id, body)
    return ApiResponse(status=JobStatus.done, data=data, message="Daily quest completed")


@router.get("/daily-quest-templates", response_model=ApiResponse)
async def list_daily_quest_templates(
    request: Request,
    enabled: Optional[bool] = None,
    difficulty: Optional[str] = None,
    _user=Depends(require_role("teacher", "admin")),
):
    data = service.list_daily_challenge_templates(enabled=enabled, difficulty=difficulty)
    return ApiResponse(status=JobStatus.done, data=data, message="Daily quest templates listed")


@router.put("/daily-quest-templates", response_model=ApiResponse)
async def upsert_daily_quest_template(
    request: Request,
    body: dict[str, Any],
    _user=Depends(require_role("teacher", "admin")),
):
    data = service.upsert_daily_challenge_template(body)
    return ApiResponse(status=JobStatus.done, data=data, message="Daily quest template saved")


@router.post("/daily-quest-templates/reset-defaults", response_model=ApiResponse)
async def reset_daily_quest_templates(
    request: Request,
    _user=Depends(require_role("admin")),
):
    data = service.reset_daily_challenge_templates()
    return ApiResponse(status=JobStatus.done, data=data, message="Daily quest templates reset")


@router.get("", response_model=ApiResponse)
async def list_challenges(
    request: Request,
    course_id: Optional[int] = None,
    _user=Depends(require_role("student", "teacher", "admin")),
):
    """List active challenges, optionally filtered by ``course_id``."""
    data = service.list_challenges(course_id)
    return ApiResponse(status=JobStatus.done, data=data, message="Active challenges listed")


@router.post("/{challenge_id}/attempt", response_model=ApiResponse)
async def submit_attempt(
    request: Request,
    challenge_id: int,
    body: dict[str, Any],
    _user=Depends(require_role("student")),
):
    """Submit answers for a challenge and return the score."""
    user_id: str = request.state.user_id
    data = service.submit_attempt(user_id, challenge_id, body)
    return ApiResponse(status=JobStatus.done, data=data, message="Attempt evaluated")


@router.get("/{challenge_id}/progress", response_model=ApiResponse)
async def get_progress(
    request: Request,
    challenge_id: int,
    user_id: Optional[str] = None,
    _user=Depends(require_role("student", "teacher", "admin")),
):
    """Get progress for a challenge."""
    caller_role: str = request.state.role
    caller_id: str = request.state.user_id
    data = service.get_progress(caller_role, caller_id, challenge_id, user_id)
    return ApiResponse(status=JobStatus.done, data=data, message="Progress retrieved")


@router.post("/generate/daily", response_model=ApiResponse)
async def create_daily_challenge(
    request: Request,
    body: dict[str, Any],
    _user=Depends(require_role("teacher", "admin")),
):
    """Generate a daily challenge (teacher/admin only)."""
    data = service.create_daily_challenge(body)
    return ApiResponse(status=JobStatus.done, data=data, message="Daily challenge generated")


@router.post("/generate/weekly", response_model=ApiResponse)
async def create_weekly_challenge(
    request: Request,
    body: dict[str, Any],
    _user=Depends(require_role("teacher", "admin")),
):
    """Generate a weekly challenge (teacher/admin only)."""
    data = service.create_weekly_challenge(body)
    return ApiResponse(status=JobStatus.done, data=data, message="Weekly challenge generated")
