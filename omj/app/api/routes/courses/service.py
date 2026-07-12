"""Service layer for course V2 domain."""
from __future__ import annotations

from typing import Any, Optional

from fastapi import HTTPException

from domain.course import engine
from domain.course import v2_repository as repo
from domain.course.v2_models import CourseModule, CourseModuleType, CourseV2
from domain.academy import repository as academy_repo
from storage.teacher_exam_document_store import has_teacher_exam_document
from storage.textbook_storage import get_textbook, is_teacher_manual_textbook, list_textbooks


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
    if role == "student":
        state = repo.get_runtime_state(user_id, course.id)
        if state.get("assigned_by_teacher") is True:
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


def _is_active_teacher_in_group(group_id: str, user_id: str) -> bool:
    members = academy_repo.list_group_members(
        group_id=group_id,
        user_id=user_id,
        status="active",
    )
    return any(
        str(member.get("role") or "").strip().lower() in {"teacher", "admin"}
        for member in members
    )


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


def _ensure_course_textbooks_selectable(course: CourseV2) -> None:
    for textbook_id in _collect_course_textbook_ids(course):
        if is_teacher_manual_textbook(textbook_id):
            raise HTTPException(
                status_code=400,
                detail="teacher_manual_textbook_not_course_selectable",
            )


def _collect_course_exam_ids(course: CourseV2) -> list[str]:
    ids = []
    for module in course.modules:
        if module.type not in {CourseModuleType.exam_solve, CourseModuleType.level_test}:
            continue
        exam_id = str(module.exam_id or "").strip()
        if exam_id and exam_id not in ids:
            ids.append(exam_id)
    return ids


def _ensure_course_exams_owned(course: CourseV2) -> None:
    owner_user_id = str(course.owner_user_id or "").strip()
    if not owner_user_id:
        raise HTTPException(status_code=401, detail="Invalid token")
    for exam_id in _collect_course_exam_ids(course):
        if not has_teacher_exam_document(owner_user_id, exam_id):
            raise HTTPException(
                status_code=400,
                detail="teacher_exam_document_not_owned",
            )


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
    if is_teacher_manual_textbook(textbook_id):
        return False
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
        if is_teacher_manual_textbook(textbook_id):
            continue
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
    _ensure_course_textbooks_selectable(course)
    _ensure_course_exams_owned(course)
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


def _runtime_summary(course: CourseV2, state: dict[str, Any]) -> dict[str, Any]:
    if not state:
        return {}
    completed = state.get("completed_modules") if isinstance(state, dict) else []
    completed_modules = [
        str(module_id)
        for module_id in (completed if isinstance(completed, list) else [])
        if str(module_id).strip()
    ]
    total_modules = len(course.modules)
    progress = len(completed_modules) / total_modules if total_modules else 0.0
    status = "paused" if state.get("paused") else ("completed" if progress >= 1.0 else "in_progress")
    current_module_id = (
        completed_modules[-1]
        if completed_modules
        else (course.modules[0].id if course.modules else None)
    )
    return {
        "percent": round(progress, 2),
        "progress": state,
        "status": status,
        "last_action": current_module_id,
        "completed_modules": completed_modules,
        "module_count": total_modules,
    }


def course_v2_payload(course: CourseV2, user: dict, state: Optional[dict[str, Any]] = None) -> dict[str, Any]:
    payload = course.model_dump(mode="json")
    user_id = str(user.get("user_id") or "")
    runtime_state = state if state is not None else repo.get_runtime_state(user_id, course.id)
    payload.update(_runtime_summary(course, runtime_state or {}))
    return payload


def course_v2_payloads(courses: list[CourseV2], user: dict) -> list[dict[str, Any]]:
    user_id = str(user.get("user_id") or "")
    states = repo.list_runtime_states(user_id, [course.id for course in courses])
    return [
        course_v2_payload(course, user, states.get(course.id, {}))
        for course in courses
    ]


def update_course_v2(user: dict, course_id: str, course: CourseV2) -> CourseV2:
    existing = repo.get_course_v2(course_id)
    if existing is None:
        raise HTTPException(status_code=404, detail="Course not found")
    if not _can_manage(user, existing):
        raise HTTPException(status_code=403, detail="You can only update your own course")

    course.id = course_id
    course.owner_user_id = existing.owner_user_id
    _ensure_course_textbooks_selectable(course)
    _ensure_course_exams_owned(course)
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
    offset: int,
    recommend_for_ovr: Optional[int],
    mine_only: bool,
    visibility: Optional[str] = None,
    sort: Optional[str] = None,
    order: Optional[str] = None,
) -> list[CourseV2]:
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
        owner = str(user.get("user_id") or "")
        owner_filter = owner

    courses = repo.list_courses_v2(
        query=query,
        tag=tag,
        limit=limit,
        offset=offset,
        recommend_for_ovr=recommend_for_ovr,
        owner_user_id=owner_filter,
        is_public=public_filter,
        sort=sort,
        order=order,
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
    if str(user.get("role") or "") != "admin" and not _is_active_teacher_in_group(
        group_id,
        str(user.get("user_id") or ""),
    ):
        raise HTTPException(status_code=403, detail="Teacher is not an active member of this group")

    course.access_academy_id = academy_id
    course.access_group_id = group_id
    course.is_public = False
    _ensure_course_textbooks_selectable(course)
    _ensure_course_exams_owned(course)
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
