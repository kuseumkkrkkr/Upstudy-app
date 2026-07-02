"""FastAPI router for the exam domain.

Endpoints:
- POST /exams/generate — generate or retrieve cached exam layout
- GET  /exams/{exam_id} — get exam paper
- GET  /exams — list exam papers
"""
from typing import Generic, List, Optional, TypeVar

from fastapi import APIRouter, Depends, Query, Request

from app.api.routes.auth.middleware import require_role
from domain.exam.cache import get_cached_layout, set_cached_layout
from domain.exam.layout_engine import build_layout
from domain.exam.models import ExamPaper, ExamPaperLayout
from domain.exam import repository as repo
from pydantic import BaseModel

router = APIRouter(prefix="/exams/v2", tags=["exams-v2"])


# ---------------------------------------------------------------------------
# Generic response wrapper
# ---------------------------------------------------------------------------

T = TypeVar("T")


class CommonResponse(BaseModel, Generic[T]):
    """Unified API response envelope."""

    success: bool = True
    data: Optional[T] = None
    message: Optional[str] = None


class ExamPaperLayoutResponse(CommonResponse[ExamPaperLayout]):
    """Concrete response for a single exam layout."""


class ExamPaperResponse(CommonResponse[ExamPaper]):
    """Concrete response for a single exam paper."""


class ExamPaperListResponse(CommonResponse[List[ExamPaper]]):
    """Concrete response for a list of exam papers."""


# ---------------------------------------------------------------------------
# Request schemas
# ---------------------------------------------------------------------------

class ExamGenerateRequest(BaseModel):
    """Body for POST /exams/generate."""

    course_id: int
    unit_ids: List[int]
    seed: int
    difficulty_map: Optional[dict[str, str]] = None


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@router.post("/generate", response_model=ExamPaperLayoutResponse)
async def generate_exam(
    request: Request,
    body: ExamGenerateRequest,
    _user=Depends(require_role("teacher", "admin")),
):
    """Generate a deterministic exam layout, pulling from cache when available."""
    cached = get_cached_layout(body.course_id, body.seed)
    if cached is not None:
        return ExamPaperLayoutResponse(data=cached, message="Cache hit")

    difficulty_map = body.difficulty_map or {}
    layout = build_layout(body.course_id, body.unit_ids, difficulty_map)
    set_cached_layout(body.course_id, body.seed, layout)
    return ExamPaperLayoutResponse(data=layout, message="Layout generated")


@router.get("/{exam_id}", response_model=ExamPaperResponse)
async def get_exam(
    request: Request,
    exam_id: int,
    _user=Depends(require_role("student", "teacher", "admin")),
):
    """Retrieve a single exam paper by id."""
    paper = repo.get_exam_paper(exam_id)
    if paper is None:
        return ExamPaperResponse(success=False, data=None, message="Exam not found")
    return ExamPaperResponse(data=paper)


@router.get("", response_model=ExamPaperListResponse)
async def list_exams(
    request: Request,
    course_id: Optional[int] = Query(None),
    _user=Depends(require_role("student", "teacher", "admin")),
):
    """List exam papers, optionally filtered by course_id."""
    papers = repo.list_exam_papers(course_id)
    return ExamPaperListResponse(data=papers)
