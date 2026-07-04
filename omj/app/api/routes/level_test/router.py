"""FastAPI router for the Level Test domain.

Endpoints:
- POST /level-tests/speed               — generate a speed test
- POST /level-tests/speed/{id}/submit   — submit answers, get score
- POST /level-tests/power               — generate a power test
- POST /level-tests/power/{id}/submit   — submit power test answers
- GET  /level-tests/results/{user_id}   — aggregated results
"""
from __future__ import annotations

import asyncio
from datetime import datetime, timezone
from typing import Any, Dict, Generic, List, Optional, TypeVar

from fastapi import APIRouter, Depends, HTTPException, Request

from app.api.routes.auth.middleware import require_role
from domain.level_test import engine, repository as repo
from domain.level_test.models import (
    LevelTestResult,
    PowerTest,
    SpeedTest,
)
from rating_service import apply_level_test_placement
from services.ai.providers.base import get_default_provider
from pydantic import BaseModel, Field

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


class PlacementQuestion(BaseModel):
    item_index: int
    phase: int
    subject_key: str
    hash_tags: List[str]
    difficulty_tier: int
    quest_id: str
    problem_rating: float
    quest: Dict[str, Any]


class PlacementStartPayload(BaseModel):
    session_id: str
    template_id: str
    question_count: int
    questions: List[PlacementQuestion]


class PlacementStartResponse(CommonResponse[PlacementStartPayload]):
    """Concrete response for placement session start."""


class PlacementAnswerRequest(BaseModel):
    item_index: int
    quest_id: str
    is_correct: bool
    answer_time: Optional[float] = None
    step_correctness: List[Dict[str, Any]] = Field(default_factory=list)
    tags: List[str] = Field(default_factory=list)


class PlacementSubmitPayload(BaseModel):
    session_id: str
    rating: float
    ovr: float
    ovr_delta: float
    recent_accuracy: float
    lose_streak: int
    confidence: float
    strong_tags: List[Dict[str, Any]]
    weak_tags: List[Dict[str, Any]]


class PlacementSubmitResponse(CommonResponse[PlacementSubmitPayload]):
    """Concrete response for placement final rating."""


class TemplateGenerateRequest(BaseModel):
    count: int = 1


class TemplateGeneratePayload(BaseModel):
    generated: int
    ready_templates: int
    template_ids: List[str]


class TemplateGenerateResponse(CommonResponse[TemplateGeneratePayload]):
    """Concrete response for placement template generation."""


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


def _create_ready_template() -> str:
    template_id = repo.create_placement_template(
        version=engine.PLACEMENT_VERSION,
        subject_mix=engine.placement_subject_mix(),
        difficulty_profile=engine.placement_difficulty_profile(),
        status="generating",
    )
    try:
        items = engine.build_placement_template_items()
        if len(items) != engine.PLACEMENT_QUESTION_COUNT:
            raise RuntimeError("placement template did not produce 50 items")
        repo.add_placement_template_items(template_id, items)
        repo.set_placement_template_status(template_id, "ready")
        return template_id
    except Exception:
        repo.set_placement_template_status(template_id, "failed")
        raise


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


@router.post("/templates/generate", response_model=TemplateGenerateResponse)
async def generate_placement_templates(
    body: TemplateGenerateRequest,
    _user=Depends(require_role("teacher", "admin")),
):
    """Generate ready-to-assign placement test templates."""
    count = max(1, min(5, int(body.count or 1)))
    template_ids = []
    for _ in range(count):
        template_ids.append(await asyncio.to_thread(_create_ready_template))
    return TemplateGenerateResponse(
        data=TemplateGeneratePayload(
            generated=len(template_ids),
            ready_templates=repo.count_ready_placement_templates(),
            template_ids=template_ids,
        ),
        message="Placement templates generated",
    )


@router.post("/placement/start", response_model=PlacementStartResponse)
async def start_placement_test(
    request: Request,
    _user=Depends(require_role("student", "teacher", "admin")),
):
    """Assign a ready placement template to the authenticated user."""
    user_id = request.state.user_id
    template = repo.pick_ready_placement_template(user_id)
    if template is None:
        await asyncio.to_thread(_create_ready_template)
        template = repo.pick_ready_placement_template(user_id)
    if template is None:
        raise HTTPException(status_code=503, detail="No placement template available")

    template_id = str(template["template_id"])
    items = repo.get_placement_template_items(template_id)
    if len(items) != engine.PLACEMENT_QUESTION_COUNT:
        raise HTTPException(status_code=503, detail="Placement template is incomplete")

    session_id = repo.create_placement_session(
        user_id=user_id,
        template_id=template_id,
    )
    questions = [
        PlacementQuestion(**item)
        for item in engine.quest_payloads_for_template_items(items)
    ]
    return PlacementStartResponse(
        data=PlacementStartPayload(
            session_id=session_id,
            template_id=template_id,
            question_count=len(questions),
            questions=questions,
        ),
        message="Placement test started",
    )


@router.post("/placement/{session_id}/answer", response_model=CommonResponse[Dict[str, Any]])
async def submit_placement_answer(
    request: Request,
    session_id: str,
    body: PlacementAnswerRequest,
    _user=Depends(require_role("student", "teacher", "admin")),
):
    user_id = request.state.user_id
    session = repo.get_placement_session(session_id)
    if not session or session["user_id"] != user_id:
        raise HTTPException(status_code=404, detail="Placement session not found")
    if session["status"] == "graded":
        raise HTTPException(status_code=409, detail="Placement session already submitted")
    repo.upsert_placement_answer(
        session_id=session_id,
        item_index=body.item_index,
        quest_id=body.quest_id,
        is_correct=body.is_correct,
        answer_time=body.answer_time,
        step_correctness=body.step_correctness,
        tags=body.tags,
    )
    return CommonResponse(data={"ok": True}, message="Placement answer saved")


@router.post("/placement/{session_id}/submit", response_model=PlacementSubmitResponse)
async def submit_placement_test(
    request: Request,
    session_id: str,
    _user=Depends(require_role("student", "teacher", "admin")),
):
    user_id = request.state.user_id
    session = repo.get_placement_session(session_id)
    if not session or session["user_id"] != user_id:
        raise HTTPException(status_code=404, detail="Placement session not found")
    answers = repo.list_placement_answers(session_id)
    if len(answers) < engine.PLACEMENT_QUESTION_COUNT:
        raise HTTPException(status_code=400, detail="Placement test is not complete")
    result = apply_level_test_placement(
        user_id=user_id,
        session_id=session_id,
        answers=answers,
    )
    repo.complete_placement_session(
        session_id=session_id,
        estimated_rating=result.rating,
        estimated_ovr=result.ovr,
        confidence=result.confidence,
        strong_tags=result.strong_tags,
        weak_tags=result.weak_tags,
    )
    return PlacementSubmitResponse(
        data=PlacementSubmitPayload(
            session_id=session_id,
            rating=result.rating,
            ovr=result.ovr,
            ovr_delta=result.ovr_delta,
            recent_accuracy=result.recent_accuracy,
            lose_streak=result.lose_streak,
            confidence=result.confidence,
            strong_tags=result.strong_tags,
            weak_tags=result.weak_tags,
        ),
        message="Placement rating applied",
    )


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
