"""FastAPI router for the Level Test domain.

Endpoints:
- POST /level-tests/speed               — generate a speed test
- POST /level-tests/speed/{id}/submit   — submit answers, get score
- POST /level-tests/power               — generate a power test
- POST /level-tests/power/{id}/submit   — submit power test answers
- GET  /level-tests/results/{user_id}   — aggregated results
"""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Dict, Generic, List, Optional, TypeVar

from fastapi import APIRouter, Depends, Request

from app.api.routes.auth.middleware import require_role
from domain.level_test import engine, repository as repo
from domain.level_test.models import (
    LevelTestResult,
    PowerTest,
    SpeedTest,
)
from services.ai.providers.base import get_default_provider
from pydantic import BaseModel

router = APIRouter(prefix="/level-tests", tags=["level-tests"])


# ---------------------------------------------------------------------------
# Generic response wrapper
# ---------------------------------------------------------------------------

T = TypeVar("T")


class CommonResponse(BaseModel, Generic[T]):
    """Unified API response envelope."""

    success: bool = True
    data: Optional[T] = None
    message: Optional[str] = None


class SpeedTestResponse(CommonResponse[SpeedTest]):
    """Concrete response for a single speed test."""


class PowerTestResponse(CommonResponse[PowerTest]):
    """Concrete response for a single power test."""


class ScoreResponse(CommonResponse[float]):
    """Concrete response for a numeric score."""


class LevelTestResultResponse(CommonResponse[LevelTestResult]):
    """Concrete response for aggregated results."""


# ---------------------------------------------------------------------------
# Request schemas
# ---------------------------------------------------------------------------


class GenerateSpeedTestRequest(BaseModel):
    """Body for POST /level-tests/speed."""

    topics: List[str]
    difficulty: str = "medium"


class SubmitSpeedTestRequest(BaseModel):
    """Body for POST /level-tests/speed/{id}/submit."""

    answers: List[Optional[int]]


class GeneratePowerTestRequest(BaseModel):
    """Body for POST /level-tests/power."""

    weakness_report: str


class SubmitPowerTestRequest(BaseModel):
    """Body for POST /level-tests/power/{id}/submit."""

    answers: List[Dict[str, Any]]


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------


@router.post("/speed", response_model=SpeedTestResponse)
async def create_speed_test(
    request: Request,
    body: GenerateSpeedTestRequest,
    _user=Depends(require_role("student", "teacher", "admin")),
):
    """Generate a new speed test for the authenticated user."""
    user_id = request.state.user_id
    ai_provider = get_default_provider()

    test = engine.generate_speed_test(
        user_id=user_id,
        topics=body.topics,
        difficulty=body.difficulty,
        ai_provider=ai_provider,
    )
    test_id = repo.create_speed_test(test)
    test.id = test_id
    return SpeedTestResponse(data=test, message="Speed test generated")


@router.post("/speed/{test_id}/submit", response_model=ScoreResponse)
async def submit_speed_test(
    request: Request,
    test_id: int,
    body: SubmitSpeedTestRequest,
    _user=Depends(require_role("student", "teacher", "admin")),
):
    """Submit answers for a speed test and receive a score."""
    user_id = request.state.user_id
    test = repo.get_speed_test(test_id)
    if test is None:
        return ScoreResponse(success=False, data=None, message="Speed test not found")

    # Students may only submit their own tests
    if request.state.role == "student" and test.user_id != user_id:
        return ScoreResponse(success=False, data=None, message="Forbidden")

    test.submitted_answers_json = __import__("json").dumps(body.answers, ensure_ascii=False)
    test.submitted_at = datetime.now(timezone.utc)
    test.status = "submitted"

    score = engine.evaluate_speed_test(test)
    test.score = round(score, 2)
    test.status = "graded"
    repo.update_speed_test(test)

    return ScoreResponse(data=test.score, message="Speed test graded")


@router.post("/power", response_model=PowerTestResponse)
async def create_power_test(
    request: Request,
    body: GeneratePowerTestRequest,
    _user=Depends(require_role("student", "teacher", "admin")),
):
    """Generate a new power test for the authenticated user."""
    user_id = request.state.user_id
    ai_provider = get_default_provider()

    test = engine.generate_power_test(
        user_id=user_id,
        weakness_report=body.weakness_report,
        ai_provider=ai_provider,
    )
    test_id = repo.create_power_test(test)
    test.id = test_id
    return PowerTestResponse(data=test, message="Power test generated")


@router.post("/power/{test_id}/submit", response_model=ScoreResponse)
async def submit_power_test(
    request: Request,
    test_id: int,
    body: SubmitPowerTestRequest,
    _user=Depends(require_role("student", "teacher", "admin")),
):
    """Submit answers for a power test and receive a heuristic score."""
    user_id = request.state.user_id
    test = repo.get_power_test(test_id)
    if test is None:
        return ScoreResponse(success=False, data=None, message="Power test not found")

    if request.state.role == "student" and test.user_id != user_id:
        return ScoreResponse(success=False, data=None, message="Forbidden")

    test.submitted_answers_json = __import__("json").dumps(body.answers, ensure_ascii=False)
    test.submitted_at = datetime.now(timezone.utc)
    test.status = "submitted"

    score = engine.evaluate_power_test(test)
    test.score = round(score, 2)
    test.status = "graded"
    repo.update_power_test(test)

    return ScoreResponse(data=test.score, message="Power test graded")


@router.get("/results/{user_id}", response_model=LevelTestResultResponse)
async def get_results(
    request: Request,
    user_id: str,
    _user=Depends(require_role("student", "teacher", "admin")),
):
    """Fetch aggregated level-test results for a user.

    Students may only view their own results; teachers and admins may view any.
    """
    caller = request.state.user_id
    role = request.state.role

    if role == "student" and caller != user_id:
        return LevelTestResultResponse(success=False, data=None, message="Forbidden")

    # Re-aggregate from stored tests so the result is always fresh
    speed_tests = repo.list_speed_tests(user_id=user_id)
    power_tests = repo.list_power_tests(user_id=user_id)
    result = engine.aggregate_results(user_id, speed_tests, power_tests)
    repo.save_level_test_result(result)

    return LevelTestResultResponse(data=result, message="Results aggregated")
