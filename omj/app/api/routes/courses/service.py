"""Service layer for course V2 domain."""
from __future__ import annotations

from typing import Any, Optional

from fastapi import HTTPException

from domain.course import engine
from domain.course import v2_repository as repo
from domain.course.v2_models import CourseModule, CourseModuleType, CourseV2
from domain.academy import repository as academy_repo
from storage.textbook_storage import get_textbook, list_textbooks


def _can_manage(user: dict, course: CourseV2) -> bool:
    return (
        user.get("role") == "admin"
        or not str(course.owner_user_id or "").strip()
        or course.owner_user_id == user.get("user_id")
    )


def _enforce_visibility_limit(
    owner_user_id: str,
    is_public: bool,
    *,
    exclude_course_id: Optional[str] = None,
) -> None:
    max_count = 2 if is_public else 5
    current = repo.count_courses_by_visibility(
        owner_user_id,
        is_public,
        exclude_course_id=exclude_course_id,
    )
    if current >= max_count:
        kind = "public" if is_public else "private"
        raise HTTPException(status_code=400, detail=f"{kind}_course_limit_exceeded:{max_count}")


def _has_private_course_access(user: dict, course: CourseV2) -> bool:
    role = str(user.get("role") or "")
    user_id = str(user.get("user_id") or "")
    if course.is_public:
        return True
    if role == "admin":
        return True
    if role == "teacher" and _can_manage(user, course):
        return True
    group_id = str(course.access_group_id or "").strip()
    if not group_id:
        return False
    if not academy_repo.is_active_group_member(group_id=group_id, user_id=user_id):
        return False
    if course.access_academy_id:
        group = academy_repo.get_group(group_id)
        if not group or str(group.get("academy_id") or "") != str(course.access_academy_id):
            return False
    return True


def _collect_course_textbook_ids(course: CourseV2) -> list[str]:
    ids = []
    if course.textbook_id and course.textbook_id.strip():
        ids.append(course.textbook_id.strip())
    for module in course.modules:
        if (
            module.type == CourseModuleType.textbook_view
            and isinstance(module.textbook_id, str)
            and module.textbook_id.strip()
        ):
            textbook_id = module.textbook_id.strip()
            if textbook_id not in ids:
                ids.append(textbook_id)
    return ids


def _find_textbook_module(course: CourseV2, module_id: str, detail: dict[str, Any]) -> Optional[CourseModule]:
    if module_id:
        target = next((m for m in course.modules if m.id == module_id), None)
        if target and target.type == CourseModuleType.textbook_view:
            return target
    textbook_id = str(detail.get("textbook_id") or "").strip()
    page_from = detail.get("page_from")
    page_to = detail.get("page_to")
    candidates = [
        m
        for m in course.modules
        if m.type == CourseModuleType.textbook_view and (not textbook_id or m.textbook_id == textbook_id)
    ]
    if not candidates:
        return None
    if len(candidates) == 1:
        return candidates[0]
    if not textbook_id:
        return candidates[0]
    # Prefer exact page range match if possible.
    for module in candidates:
        if module.textbook_id != textbook_id:
            continue
        if page_from is None or page_to is None:
            return module
        if module.page_from == page_from and module.page_to == page_to:
            return module
    for module in candidates:
        if module.textbook_id == textbook_id:
            return module
    return candidates[0]


def _ensure_textbook_access(course: CourseV2, user: dict, textbook_id: str) -> bool:
    if not _has_private_course_access(user, course):
        return False
    allowed_ids = _collect_course_textbook_ids(course)
    if not allowed_ids:
        # Back-compat for old course definitions that only set top-level textbook_id.
        return bool(course.textbook_id == textbook_id)
    return textbook_id in allowed_ids or course.textbook_id == textbook_id


def list_course_documents(
    user: dict,
    course_id: str,
    doc_type: Optional[str] = None,
) -> list[dict[str, Any]]:
    course = repo.get_course_v2(course_id)
    if course is None:
        raise HTTPException(status_code=404, detail="Course not found")
    if not _has_private_course_access(user, course):
        raise HTTPException(status_code=403, detail="Course not found")

    doc_type = (doc_type or "").strip().lower()
    if doc_type and doc_type not in {"textbook", "textbooks"}:
        return []

    textbook_ids = _collect_course_textbook_ids(course)
    if not textbook_ids and course.textbook_id:
        textbook_ids = [course.textbook_id]

    items: list[dict[str, Any]] = []
    for textbook_id in textbook_ids:
        item = get_textbook(textbook_id)
        if item:
            items.append(item)
    return items


def get_course_textbook(
    user: dict,
    course_id: str,
    textbook_id: str,
) -> dict[str, Any]:
    course = repo.get_course_v2(course_id)
    if course is None:
        raise HTTPException(status_code=404, detail="Course not found")
    textbook_id = (textbook_id or "").strip()
    if not textbook_id:
        raise HTTPException(status_code=400, detail="textbook_id is required")
    if not _ensure_textbook_access(course, user, textbook_id):
        raise HTTPException(status_code=403, detail="Course textbook not found")

    item = get_textbook(textbook_id)
    if not item:
        raise HTTPException(status_code=404, detail="Textbook not found")
    return item


def create_course_v2(user: dict, course: CourseV2) -> CourseV2:
    owner_user_id = str(user.get("user_id") or "")
    if not owner_user_id:
        raise HTTPException(status_code=401, detail="Invalid token")
    course.owner_user_id = owner_user_id
    _enforce_visibility_limit(owner_user_id, bool(course.is_public))
    course = engine.insert_forced_wrong_answer_modules(course)
    repo.create_course_v2(course)
    return course


def get_course_v2(course_id: str, user: dict) -> CourseV2:
    course = repo.get_course_v2(course_id)
    if course is None:
        raise HTTPException(status_code=404, detail="Course not found")
    if not _has_private_course_access(user, course):
        raise HTTPException(status_code=403, detail="Forbidden")
    return course


def update_course_v2(user: dict, course_id: str, course: CourseV2) -> CourseV2:
    existing = repo.get_course_v2(course_id)
    if existing is None:
        raise HTTPException(status_code=404, detail="Course not found")
    if not _can_manage(user, existing):
        raise HTTPException(status_code=403, detail="You can only update your own course")

    course.id = course_id
    course.owner_user_id = existing.owner_user_id
    _enforce_visibility_limit(
        course.owner_user_id,
        bool(course.is_public),
        exclude_course_id=course_id,
    )
    course = engine.insert_forced_wrong_answer_modules(course)
    repo.update_course_v2(course)
    return course


def delete_course_v2(user: dict, course_id: str) -> tuple[bool, bool]:
    existing = repo.get_course_v2(course_id)
    if existing is None:
        return False, False
    if not _can_manage(user, existing):
        raise HTTPException(status_code=403, detail="You can only delete your own course")

    deleted = repo.delete_course_v2(course_id)
    return (bool(deleted), True)


def list_courses_v2(
    user: dict,
    query: Optional[str],
    tag: Optional[str],
    limit: int,
    recommend_for_ovr: Optional[int],
    mine_only: bool,
) -> list[CourseV2]:
    role = str(user.get("role") or "")
    owner_filter: Optional[str] = None
    public_filter: Optional[bool] = None

    if role == "student":
        public_filter = True
    elif mine_only:
        owner = str(user.get("user_id") or "")
        courses = repo.list_courses_v2(
            query=query,
            tag=tag,
            limit=limit,
            recommend_for_ovr=recommend_for_ovr,
        )
        return [c for c in courses if not str(c.owner_user_id or "").strip() or c.owner_user_id == owner][:limit]

    courses = repo.list_courses_v2(
        query=query,
        tag=tag,
        limit=limit,
        recommend_for_ovr=recommend_for_ovr,
        owner_user_id=owner_filter,
        is_public=public_filter,
    )
    return [c for c in courses if _has_private_course_access(user, c)]


def bind_course_academy_group(
    user: dict,
    course_id: str,
    academy_id: str,
    group_id: str,
) -> CourseV2:
    course = repo.get_course_v2(course_id)
    if course is None:
        raise HTTPException(status_code=404, detail="Course not found")
    if not _can_manage(user, course):
        raise HTTPException(status_code=403, detail="You can only update your own course")

    group = academy_repo.get_group(group_id)
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")
    if str(group.get("academy_id") or "") != academy_id:
        raise HTTPException(status_code=400, detail="Invalid academy/group mapping")

    course.access_academy_id = academy_id
    course.access_group_id = group_id
    course.is_public = False
    if not course.id.startswith("academy_"):
        course.id = f"academy_{academy_id}__group_{group_id}__{course.id}"
    repo.delete_course_v2(course_id)
    repo.create_course_v2(course)
    return course


def runtime_next(course_id: str, body: dict[str, Any]) -> dict[str, Any]:
    course = repo.get_course_v2(course_id)
    if course is None:
        raise HTTPException(status_code=404, detail="Course not found")

    current_module_id = body.get("current_module_id")
    student_state = body.get("student_state")

    return engine.next_module(course, current_module_id, student_state)


def validate_course_v2(course_id: str) -> dict[str, Any]:
    course = repo.get_course_v2(course_id)
    if course is None:
        raise HTTPException(status_code=404, detail="Course not found")

    validated = engine.insert_forced_wrong_answer_modules(course)
    original_ids = {m.id for m in course.modules}
    validated_ids = {m.id for m in validated.modules}
    added = list(validated_ids - original_ids)

    return {
        "course_id": course_id,
        "original_module_count": len(course.modules),
        "validated_module_count": len(validated.modules),
        "added_module_ids": added,
        "valid": True,
    }
