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
    """필요 변수: 호환용 생성 요청. 작동 원리: PostgreSQL에 배포된 활성 폼 목록을 반환한다."""
    del body
    template_ids = repo.postgres_level_test_store.list_template_ids()
    return TemplateGenerateResponse(
        data=TemplateGeneratePayload(
            generated=0,
            ready_templates=len(template_ids),
            template_ids=template_ids,
        ),
        message="PostgreSQL placement templates are ready",
    )


@router.post("/placement/start", response_model=PlacementStartResponse)
async def start_placement_test(
    request: Request,
    _user=Depends(require_role("student", "teacher", "admin")),
):
    """필요 변수: 인증 사용자 ID. 작동 원리: PostgreSQL 폼과 문제 payload를 한 번 읽어 placement 세션을 생성한다."""
    user_id = request.state.user_id
    template = repo.pick_ready_placement_template(user_id)
    if template is None:
        raise HTTPException(status_code=503, detail="No PostgreSQL placement template available")

    template_id = str(template["template_id"])
    items = repo.get_placement_template_items(template_id)
    if len(items) != engine.PLACEMENT_QUESTION_COUNT:
        raise HTTPException(status_code=503, detail="Placement template is incomplete")

    questions = [PlacementQuestion(**item) for item in items]
    if len(questions) != engine.PLACEMENT_QUESTION_COUNT:
        raise HTTPException(status_code=503, detail="PostgreSQL placement problems are incomplete")
    session_id = repo.create_placement_session(
        user_id=user_id,
        template_id=template_id,
    )
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
    assigned_item = repo.postgres_level_test_store.get_template_item(
        str(session["template_id"]),
        body.item_index,
    )
    if not assigned_item or str(assigned_item["quest_id"]) != body.quest_id:
        raise HTTPException(status_code=400, detail="Answer does not match the assigned placement problem")
    repo.upsert_placement_answer(
        session_id=session_id,
        item_index=body.item_index,
        quest_id=body.quest_id,
        is_correct=body.is_correct,
        answer_time=body.answer_time,
        step_correctness=body.step_correctness,
        # 클라이언트가 보낸 태그 대신 검수된 정적 문제 태그만 레이팅에 사용한다.
        tags=list(assigned_item["hash_tags"]),
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
