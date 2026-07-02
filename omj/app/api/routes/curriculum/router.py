"""FastAPI router for Curriculum domain.

Endpoints:
- POST /curriculum/analyze   — weakness analysis for a user
- POST /curriculum/build     — build a new CurriculumPath
- POST /curriculum/adapt     — adapt an existing path with latest OVR
- GET  /curriculum/{user_id} — get the current path for a user
"""
from __future__ import annotations

from typing import Any, Optional

from fastapi import APIRouter, Depends, Request

from app.api.routes.auth.middleware import require_role
from app.schemas.common import ApiResponse
from domain.course.v2_models import CourseV2
from domain.course import v2_repository as course_repo
from domain.curriculum.models import CurriculumPath
from domain.curriculum import recommend_engine as engine
from domain.curriculum import repository as repo

router = APIRouter(prefix="/curriculum", tags=["curriculum"])


def _wrap(data: Optional[object], message: Optional[str] = None) -> ApiResponse:
    return ApiResponse(data=data, message=message)


# ---------------------------------------------------------------------------
# Analyze
# ---------------------------------------------------------------------------


@router.post("/analyze", response_model=ApiResponse)
async def analyze_curriculum(
    request: Request,
    body: dict[str, Any],
    _user=Depends(require_role("student", "teacher", "admin")),
):
    """Analyze weaknesses for a given user_id.

    Students may only analyze their own OVR.
    """
    user_id: str = body.get("user_id", "")
    if not user_id:
        return _wrap(None, "user_id is required")

    role = getattr(request.state, "role", None)
    caller_id = getattr(request.state, "user_id", None)
    if role == "student" and caller_id != user_id:
        return _wrap(None, "Students can only analyze their own data")

    ovr = repo.get_ovr(user_id)
    if ovr is None:
        return _wrap(None, "OVR not found for user")

    weaknesses = engine.analyze_weaknesses(ovr)
    return _wrap(
        {
            "user_id": user_id,
            "weaknesses": [w.model_dump(mode="json") for w in weaknesses],
            "count": len(weaknesses),
        },
        "Weakness analysis complete",
    )


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------


@router.post("/build", response_model=ApiResponse)
async def build_curriculum(
    request: Request,
    body: dict[str, Any],
    _user=Depends(require_role("teacher", "admin")),
):
    """Build a CurriculumPath for a user and course.

    Request body:
        {
            "course_id": str,
            "user_id": str,
            "total_weeks": int (default 12)
        }
    """
    course_id: str = str(body.get("course_id", ""))
    user_id: str = body.get("user_id", "")
    total_weeks: int = int(body.get("total_weeks", 12))

    if not course_id or not user_id:
        return _wrap(None, "course_id and user_id are required")

    course = course_repo.get_course_v2(course_id)
    if course is None:
        return _wrap(None, "Course not found")

    ovr = repo.get_ovr(user_id)
    if ovr is None:
        return _wrap(None, "OVR not found for user")

    weaknesses = engine.analyze_weaknesses(ovr)
    path = engine.build_curriculum(course, weaknesses, ovr, total_weeks=total_weeks)
    path_id = repo.save_path(path, user_id=user_id)

    return _wrap(
        {
            "path_id": path_id,
            "path": path.model_dump(mode="json"),
        },
        "Curriculum path built",
    )


# ---------------------------------------------------------------------------
# Adapt
# ---------------------------------------------------------------------------


@router.post("/adapt", response_model=ApiResponse)
async def adapt_curriculum(
    request: Request,
    body: dict[str, Any],
    _user=Depends(require_role("teacher", "admin")),
):
    """Adapt an existing path with the latest OVR data.

    Request body:
        {
            "path_id": int
        }
    """
    path_id = body.get("path_id")
    if path_id is None:
        return _wrap(None, "path_id is required")

    result = repo.get_path_by_id(path_id)
    if result is None:
        return _wrap(None, "Path not found")

    old_path, path_user_id = result
    new_ovr = repo.get_ovr(path_user_id)
    if new_ovr is None:
        return _wrap(None, "OVR not found for user")

    adapted = engine.adapt_path(old_path, new_ovr)
    new_path_id = repo.save_path(adapted, user_id=path_user_id)

    return _wrap(
        {
            "path_id": new_path_id,
            "path": adapted.model_dump(mode="json"),
        },
        "Curriculum path adapted",
    )


# ---------------------------------------------------------------------------
# Get current path
# ---------------------------------------------------------------------------


@router.get("/{user_id}", response_model=ApiResponse)
async def get_curriculum(
    request: Request,
    user_id: str,
    _user=Depends(require_role("student", "teacher", "admin")),
):
    """Get the most recent curriculum path for a user.

    Students may only view their own path.
    """
    role = getattr(request.state, "role", None)
    caller_id = getattr(request.state, "user_id", None)
    if role == "student" and caller_id != user_id:
        return _wrap(None, "Students can only view their own curriculum")

    path = repo.get_latest_path(user_id)
    if path is None:
        return _wrap(None, "No curriculum path found for user")

    return _wrap(path.model_dump(mode="json"))
