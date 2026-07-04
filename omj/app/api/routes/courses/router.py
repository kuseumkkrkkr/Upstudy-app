"""FastAPI router for Course V2 domain."""
from __future__ import annotations

from typing import Any, Optional

from fastapi import APIRouter, Depends, Query, Request
from pydantic import BaseModel

from app.api.routes.auth.middleware import require_role
from app.api.deps import get_current_user
from app.api.routes.courses import service
from app.schemas.common import ApiResponse
from domain.course.v2_models import CourseV2
from domain.course import v2_repository as repo

router = APIRouter(prefix="/courses/v2", tags=["courses-v2"])


def _wrap(data: Optional[object], message: Optional[str] = None) -> ApiResponse:
    return ApiResponse(data=data, message=message)


@router.post("", response_model=ApiResponse)
async def create_course_v2(
    request: Request,
    course: CourseV2,
    user=Depends(require_role("teacher", "admin")),
):
    created = service.create_course_v2(user=user, course=course)
    return _wrap(created, "Course v2 created")


@router.get("/{course_id}", response_model=ApiResponse)
async def get_course_v2(
    request: Request,
    course_id: str,
    user=Depends(get_current_user),
):
    course = service.get_course_v2(course_id, user)
    return _wrap(course)


@router.put("/{course_id}", response_model=ApiResponse)
async def update_course_v2(
    request: Request,
    course_id: str,
    course: CourseV2,
    user=Depends(require_role("teacher", "admin")),
):
    updated = service.update_course_v2(user=user, course_id=course_id, course=course)
    return _wrap(updated, "Course v2 updated")


@router.delete("/{course_id}", response_model=ApiResponse)
async def delete_course_v2(
    request: Request,
    course_id: str,
    user=Depends(require_role("teacher", "admin")),
):
    deleted, found = service.delete_course_v2(user=user, course_id=course_id)
    if not found:
        return _wrap(None, "Course not found")
    return _wrap(None, "Course v2 deleted" if deleted else "Course not found")


@router.get("", response_model=ApiResponse)
async def list_courses_v2(
    request: Request,
    query: Optional[str] = None,
    tag: Optional[str] = None,
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0, le=2000),
    recommend_for_ovr: Optional[int] = None,
    mine_only: bool = False,
    visibility: Optional[str] = Query(default=None, pattern="^(all|public|private)$"),
    sort: Optional[str] = Query(default="updated_at", pattern="^(updated_at|created_at|title|target_ovr|difficulty)$"),
    order: Optional[str] = Query(default="desc", pattern="^(asc|desc)$"),
    include_total: bool = False,
    user=Depends(get_current_user),
):
    visibility = (visibility or "all").strip().lower()
    courses = service.list_courses_v2(
        user=user,
        query=query,
        tag=tag,
        limit=limit,
        offset=offset,
        recommend_for_ovr=recommend_for_ovr,
        mine_only=mine_only,
        visibility=None if visibility == "all" else visibility,
        sort=sort,
        order=order,
    )
    if not include_total:
        return _wrap(courses)

    role = str(user.get("role") or "")
    owner_filter: Optional[str] = None
    public_filter: Optional[bool] = None
    if role == "student":
        public_filter = True
    elif visibility == "public":
        public_filter = True
    elif visibility == "private":
        public_filter = False
    elif mine_only:
        owner_filter = str(user.get("user_id") or "")

    total = repo.count_courses_v2(
        query=query,
        tag=tag,
        owner_user_id=owner_filter,
        is_public=public_filter,
    )
    return _wrap(
        {
            "items": courses,
            "total": total,
            "limit": limit,
            "offset": offset,
        }
    )


class GroupBindRequest(BaseModel):
    """Body for course-academy-group binding."""
    academy_id: str
    group_id: str


@router.post("/{course_id}/bind-academy-group", response_model=ApiResponse)
async def bind_course_academy_group(
    request: Request,
    course_id: str,
    body: GroupBindRequest,
    user=Depends(require_role("teacher", "admin")),
):
    updated = service.bind_course_academy_group(
        user=user,
        course_id=course_id,
        academy_id=body.academy_id,
        group_id=body.group_id,
    )
    return _wrap(updated, "Bound to academy group")


class NextModuleRequest:
    """Request body for runtime/next endpoint."""

    def __init__(
        self,
        current_module_id: Optional[str] = None,
        student_state: Optional[dict[str, Any]] = None,
    ):
        self.current_module_id = current_module_id
        self.student_state = student_state or {}


@router.post("/{course_id}/runtime/next", response_model=ApiResponse)
async def runtime_next(
    request: Request,
    course_id: str,
    body: dict[str, Any],
    _user=Depends(require_role("student", "teacher", "admin")),
):
    result = service.runtime_next(course_id=course_id, body=body)
    return _wrap(result)


@router.post("/{course_id}/validate", response_model=ApiResponse)
async def validate_course_v2(
    request: Request,
    course_id: str,
    _user=Depends(require_role("teacher", "admin")),
):
    result = service.validate_course_v2(course_id)
    return _wrap(result, "Validation complete")


@router.get("/{course_id}/documents", response_model=ApiResponse)
async def list_course_documents(
    request: Request,
    course_id: str,
    type: Optional[str] = None,
    _user=Depends(get_current_user),
):
    items = service.list_course_documents(
        user=_user,
        course_id=course_id,
        doc_type=type,
    )
    return _wrap({"items": items}, "Course documents retrieved")


@router.get("/{course_id}/textbooks/{textbook_id}", response_model=ApiResponse)
async def get_course_textbook(
    request: Request,
    course_id: str,
    textbook_id: str,
    _user=Depends(get_current_user),
):
    item = service.get_course_textbook(
        user=_user,
        course_id=course_id,
        textbook_id=textbook_id,
    )
    return _wrap(item, "Course textbook retrieved")
