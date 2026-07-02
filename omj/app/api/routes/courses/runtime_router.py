"""FastAPI router for Course V2 runtime operations."""
from __future__ import annotations

import time
from datetime import date
from typing import Any, Optional

from fastapi import APIRouter, Depends, Request

from app.api.routes.auth.middleware import require_role
from app.api.deps import get_current_user
from app.schemas.common import ApiResponse
from domain.course import engine
from domain.course import v2_repository as repo
from domain.academy import repository as academy_repo
from domain.course.v2_models import CourseModule, CourseModuleType
from storage.textbook_storage import get_textbook

router = APIRouter(prefix="/courses/v2/runtime", tags=["courses-v2-runtime"])


def _wrap(data: Optional[object], message: Optional[str] = None) -> ApiResponse:
    return ApiResponse(data=data, message=message)


def _today_iso() -> str:
    return date.today().isoformat()


def _today_ordinal() -> int:
    return date.today().toordinal()


def _curriculum_enabled(course) -> bool:
    settings = course.curriculum_settings or {}
    return bool(settings.get("enabled") is True)


def _ensure_runtime_state(course, user_id: str, state: dict[str, Any]) -> dict[str, Any]:
    out = dict(state or {})
    out.setdefault("user_id", user_id)
    out.setdefault("course_id", course.id)
    out.setdefault("started_day", _today_ordinal())
    out.setdefault("completed_modules", [])
    out.setdefault("module_results", {})
    out.setdefault("module_completed_day", {})
    out.setdefault("daily_completed", {})
    out.setdefault("deviation_count", 0)
    out.setdefault("paused", False)
    out.setdefault("pause_reason", "")
    out.setdefault("module_deadline_days", _default_deadline_days(course))
    return out


def _default_deadline_days(course) -> list[int]:
    settings = course.curriculum_settings or {}
    deadlines = settings.get("module_deadline_days")
    if isinstance(deadlines, list) and deadlines:
        return [max(0, int(x or 0)) for x in deadlines]

    every_n = int(settings.get("every_n_days") or 0)
    if every_n <= 0:
        return [0 for _ in course.modules]
    return [i * every_n for i, _ in enumerate(course.modules)]


def _build_schedule(course, state: dict[str, Any]) -> list[dict[str, Any]]:
    if not _curriculum_enabled(course):
        return []
    started_day = int(state.get("started_day") or _today_ordinal())
    deadlines = state.get("module_deadline_days") or _default_deadline_days(course)
    schedule = []
    for i, module in enumerate(course.modules):
        due_offset = deadlines[i] if i < len(deadlines) else 0
        due_day = started_day + int(due_offset)
        schedule.append(
            {
                "module_id": module.id,
                "title": module.title,
                "position": i,
                "due_day_offset": int(due_offset),
                "due_date": date.fromordinal(due_day).isoformat(),
                "completed": module.id in set(state.get("completed_modules") or []),
            }
        )
    return schedule


def _safe_int(value: Any, *, default: int | None = None) -> int | None:
    try:
        if value is None:
            return default
        if isinstance(value, bool):
            return int(value)
        return int(str(value))
    except (TypeError, ValueError):
        return default


def _textbook_page_count(textbook: dict[str, Any]) -> int:
    chapters = textbook.get("chapters")
    if not isinstance(chapters, list):
        return 1
    total = 0
    for chapter in chapters:
        if not isinstance(chapter, dict):
            continue
        if chapter.get("intro"):
            total += 1
        sections = chapter.get("sections")
        if isinstance(sections, list):
            total += len([s for s in sections if isinstance(s, dict)])
    return max(1, total)


def _normalize_page_range(
    textbook: dict[str, Any],
    page_from: int | None,
    page_to: int | None,
) -> tuple[int, int]:
    total_pages = _textbook_page_count(textbook)
    start = page_from if page_from and page_from > 0 else 1
    end = page_to if page_to and page_to > 0 else start
    if end < start:
        end = start
    start = min(max(1, start), total_pages)
    end = min(max(start, end), total_pages)
    return start, end


def _find_module_for_runtime(
    course,
    module_id: str,
    detail_textbook_id: str,
    page_from: int | None,
    page_to: int | None,
) -> CourseModule | None:
    module = None
    if module_id:
        module = next(
            (m for m in course.modules if m.id == module_id and m.type == CourseModuleType.textbook_view),
            None,
        )
    if module is not None:
        return module

    if not detail_textbook_id:
        return next(
            (m for m in course.modules if m.type == CourseModuleType.textbook_view),
            None,
        )

    candidates = [
        m
        for m in course.modules
        if m.type == CourseModuleType.textbook_view and m.textbook_id == detail_textbook_id
    ]
    if not candidates:
        return None
    if page_from is not None and page_to is not None:
        for c in candidates:
            if (
                _safe_int(c.page_from, default=1) == page_from
                and _safe_int(c.page_to, default=page_from) == page_to
            ):
                return c
    return candidates[0]


def _read_runtime_textbook_state(
    state: dict[str, Any],
    module_key: str,
) -> dict[str, Any]:
    holder = state.setdefault("textbook_view", {})
    if not isinstance(holder, dict):
        holder = {}
        state["textbook_view"] = holder
    entry = holder.get(module_key)
    if isinstance(entry, dict):
        return entry
    entry = {}
    holder[module_key] = entry
    return entry


def _build_textbook_progress(
    module_state: dict[str, Any],
    *, 
    enforce_min_minutes: bool,
    min_minutes: int,
    page_from: int,
    page_to: int,
    current_page: int,
) -> dict[str, Any]:
    total_pages = max(1, (page_to - page_from) + 1)
    page = max(page_from, min(page_to, current_page))
    page_ratio = (page - page_from + 1) / total_pages
    min_minutes_int = max(0, min_minutes)
    time_ratio = 1.0
    if enforce_min_minutes and min_minutes_int > 0:
        elapsed_sec = float(module_state.get("total_open_seconds", 0))
        time_ratio = min(1.0, elapsed_sec / float(min_minutes_int * 60))
    completed = min(1.0, page_ratio)
    if enforce_min_minutes and min_minutes_int > 0:
        completed = min(completed, time_ratio)
    return {
        "page_ratio": round(page_ratio, 4),
        "time_ratio": round(time_ratio, 4),
        "completion_ratio": round(min(1.0, completed), 4),
        "completed": completed >= 1.0,
        "current_page": page,
        "required_minutes": min_minutes_int,
        "enforce_min_minutes": enforce_min_minutes,
    }


def _touch_textbook_state(
    state: dict[str, Any],
    module_key: str,
    course_id: str,
    module_id: str,
    textbook_id: str,
    page_from: int,
    page_to: int,
    min_minutes: int,
    enforce_min_minutes: bool,
    current_page: int,
) -> dict[str, Any]:
    entry = _read_runtime_textbook_state(state, module_key)
    now = int(time.time())
    entry.setdefault("course_id", course_id)
    entry.setdefault("created_at", now)
    entry["module_id"] = module_id or entry.get("module_id")
    entry["textbook_id"] = textbook_id
    entry["page_from"] = page_from
    entry["page_to"] = page_to
    entry["min_minutes"] = min_minutes
    entry["enforce_min_minutes"] = bool(enforce_min_minutes)
    entry.setdefault("total_open_seconds", 0)
    entry.setdefault("last_active_at", now)
    entry["last_active_at"] = now
    last_page = entry.get("current_page")
    if _safe_int(last_page) is None:
        entry["current_page"] = current_page
    else:
        entry["current_page"] = _safe_int(current_page, default=entry["current_page"] or page_from) or current_page
    entry["current_page"] = max(page_from, min(page_to, int(entry["current_page"])))
    return entry


def _tick_textbook_open_time(module_state: dict[str, Any]) -> None:
    now = int(time.time())
    last = _safe_int(module_state.get("last_active_at"), default=now) or now
    if last > now:
        last = now
    delta = max(0, now - last)
    module_state["total_open_seconds"] = _safe_int(
        module_state.get("total_open_seconds"),
        default=0,
    ) + delta
    module_state["last_active_at"] = now


def _maybe_resume_with_extension(course, state: dict[str, Any], resume: bool) -> tuple[dict[str, Any], bool]:
    if not bool(state.get("paused")):
        return state, False
    if not resume:
        return state, False
    deadlines = list(state.get("module_deadline_days") or _default_deadline_days(course))
    state["module_deadline_days"] = [int(x) + 3 for x in deadlines]
    state["paused"] = False
    state["pause_reason"] = ""
    return state, True


def _current_day_offset(state: dict[str, Any]) -> int:
    started_day = int(state.get("started_day") or _today_ordinal())
    return max(0, _today_ordinal() - started_day)


def _is_daily_limit_reached(course, state: dict[str, Any]) -> bool:
    if not _curriculum_enabled(course):
        return False
    daily_max = int((course.curriculum_settings or {}).get("daily_max_modules") or 0)
    if daily_max <= 0:
        return False
    count = int((state.get("daily_completed") or {}).get(_today_iso(), 0))
    return count >= daily_max


def _enforce_deadline_and_pause(course, module_id: str, state: dict[str, Any]) -> dict[str, Any]:
    if not _curriculum_enabled(course):
        return state
    settings = course.curriculum_settings or {}
    max_dev = int(settings.get("max_deadline_deviation") or 0)
    if max_dev <= 0:
        return state

    module_ids = [m.id for m in course.modules]
    try:
        idx = module_ids.index(module_id)
    except ValueError:
        return state

    deadlines = list(state.get("module_deadline_days") or _default_deadline_days(course))
    due_offset = deadlines[idx] if idx < len(deadlines) else 0
    actual_offset = _current_day_offset(state)
    if actual_offset > int(due_offset):
        state["deviation_count"] = int(state.get("deviation_count") or 0) + 1

    if int(state.get("deviation_count") or 0) >= max_dev:
        state["paused"] = True
        state["pause_reason"] = "기한 이탈 허용 횟수에 도달하여 자동 일시정지되었습니다. 재개 시 각 모듈 기한이 +3일 연장됩니다."
    return state


def _target_user(request: Request, user_id: Optional[str]) -> str:
    caller_role: str = getattr(request.state, "role", "student")
    caller_id: str = getattr(request.state, "user_id", "")
    if caller_role == "student":
        return caller_id
    return user_id or caller_id


def _can_access_course(request: Request, course) -> bool:
    role: str = getattr(request.state, "role", "student")
    user_id: str = getattr(request.state, "user_id", "")
    if bool(course.is_public):
        return True
    if role == "admin":
        return True
    if role == "teacher" and course.owner_user_id == user_id:
        return True
    group_id = str(course.access_group_id or "").strip()
    if group_id and academy_repo.is_active_group_member(group_id=group_id, user_id=user_id):
        if course.access_academy_id:
            group = academy_repo.get_group(group_id)
            return bool(group and str(group.get("academy_id") or "") == str(course.access_academy_id))
        return True
    return False


@router.post("/next", response_model=ApiResponse)
async def runtime_next(
    request: Request,
    body: dict[str, Any],
    _user=Depends(get_current_user),
):
    course_id: str = str(body.get("course_id", ""))
    if not course_id:
        return _wrap(None, "course_id is required")

    course = repo.get_course_v2(course_id)
    if course is None:
        return _wrap(None, "Course not found")
    if not _can_access_course(request, course):
        return _wrap(None, "Course not found")

    target_user_id = _target_user(request, body.get("user_id"))
    if not target_user_id:
        return _wrap(None, "user_id is required")

    current_module_id = body.get("current_module_id")
    resume = body.get("resume") is True

    persisted = repo.get_runtime_state(target_user_id, course_id)
    incoming = body.get("student_state") or {}
    state = _ensure_runtime_state(course, target_user_id, {**persisted, **incoming})

    state, resumed = _maybe_resume_with_extension(course, state, resume)

    if bool(state.get("paused")):
        repo.upsert_runtime_state(target_user_id, course_id, state)
        return _wrap(
            {
                "next_module_id": None,
                "next_module": None,
                "status": "paused",
                "reason": state.get("pause_reason") or "Course paused",
                "student_state": state,
                "curriculum": {
                    "enabled": _curriculum_enabled(course),
                    "schedule": _build_schedule(course, state),
                },
            }
        )

    if _is_daily_limit_reached(course, state):
        return _wrap(
            {
                "next_module_id": None,
                "next_module": None,
                "status": "locked",
                "reason": "일일 최대 이수 모듈 수에 도달했습니다.",
                "student_state": state,
                "curriculum": {
                    "enabled": _curriculum_enabled(course),
                    "schedule": _build_schedule(course, state),
                },
            }
        )

    if current_module_id is None and state.get("completed_modules"):
        # Resume by completed history when caller does not pass current module.
        completed_ids = list(state.get("completed_modules") or [])
        current_module_id = completed_ids[-1] if completed_ids else None

    result = engine.next_module(course, current_module_id, state.get("module_results") or {})
    response = {
        **result,
        "student_state": state,
        "resumed_with_plus3days": resumed,
        "curriculum": {
            "enabled": _curriculum_enabled(course),
            "schedule": _build_schedule(course, state),
        },
    }
    repo.upsert_runtime_state(target_user_id, course_id, state)
    return _wrap(response)


@router.get("/state/{course_id}", response_model=ApiResponse)
async def runtime_state(
    request: Request,
    course_id: str,
    user_id: Optional[str] = None,
    _user=Depends(get_current_user),
):
    course = repo.get_course_v2(course_id)
    if course is None:
        return _wrap(None, "Course not found")
    if not _can_access_course(request, course):
        return _wrap(None, "Course not found")

    target_user_id = _target_user(request, user_id)
    if not target_user_id:
        return _wrap(None, "user_id is required")

    persisted = repo.get_runtime_state(target_user_id, course_id)
    state = _ensure_runtime_state(course, target_user_id, persisted)
    repo.upsert_runtime_state(target_user_id, course_id, state)

    completed = list(state.get("completed_modules") or [])
    total_modules = len(course.modules)
    progress = len(completed) / total_modules if total_modules > 0 else 0.0

    status = "paused" if state.get("paused") else ("completed" if progress >= 1.0 else "in_progress")

    out = {
        "course_id": course_id,
        "user_id": target_user_id,
        "completed_modules": completed,
        "current_module_id": completed[-1] if completed else (course.modules[0].id if course.modules else None),
        "overall_progress": round(progress, 2),
        "status": status,
        "pause_reason": state.get("pause_reason") or "",
        "deviation_count": int(state.get("deviation_count") or 0),
        "module_count": total_modules,
        "curriculum": {
            "enabled": _curriculum_enabled(course),
            "schedule": _build_schedule(course, state),
        },
        "student_state": state,
    }
    return _wrap(out, "Runtime state retrieved")


@router.post("/submit", response_model=ApiResponse)
async def runtime_submit(
    request: Request,
    body: dict[str, Any],
    _user=Depends(get_current_user),
):
    course_id: str = str(body.get("course_id", ""))
    module_id: str = str(body.get("module_id", ""))
    correct_count: int = int(body.get("correct_count", 0))
    total_count: int = int(body.get("total_count", 0))
    elapsed_seconds: Optional[int] = body.get("elapsed_seconds")

    if not course_id or not module_id:
        return _wrap(None, "course_id and module_id are required")

    course = repo.get_course_v2(course_id)
    if course is None:
        return _wrap(None, "Course not found")
    if not _can_access_course(request, course):
        return _wrap(None, "Course not found")

    module = course.get_module(module_id)
    if module is None:
        return _wrap(None, "Module not found in course")

    target_user_id = _target_user(request, body.get("user_id"))
    if not target_user_id:
        return _wrap(None, "user_id is required")

    persisted = repo.get_runtime_state(target_user_id, course_id)
    incoming = body.get("student_state") or {}
    state = _ensure_runtime_state(course, target_user_id, {**persisted, **incoming})

    if bool(state.get("paused")):
        return _wrap(
            {
                "passed": False,
                "reason": state.get("pause_reason") or "Course paused",
                "accuracy": 0.0,
                "detail": {},
                "next_module": {"module_id": None, "status": "paused", "reason": state.get("pause_reason")},
                "student_state": state,
            },
            "Course paused",
        )

    pass_result = engine.evaluate_module_pass(
        module=module,
        course=course,
        correct_count=correct_count,
        total_count=total_count,
        elapsed_seconds=elapsed_seconds,
    )

    module_results = dict(state.get("module_results") or {})
    module_results[module_id] = {
        "passed": pass_result["passed"],
        "accuracy": pass_result["accuracy"],
    }
    state["module_results"] = module_results

    completed_modules = list(state.get("completed_modules") or [])
    if pass_result["passed"] and module_id not in completed_modules:
        completed_modules.append(module_id)
        state["completed_modules"] = completed_modules

        day_key = _today_iso()
        daily_completed = dict(state.get("daily_completed") or {})
        daily_completed[day_key] = int(daily_completed.get(day_key, 0)) + 1
        state["daily_completed"] = daily_completed

        completed_day = dict(state.get("module_completed_day") or {})
        completed_day[module_id] = _current_day_offset(state)
        state["module_completed_day"] = completed_day

        state = _enforce_deadline_and_pause(course, module_id, state)

    repo.upsert_runtime_state(target_user_id, course_id, state)

    next_result = engine.next_module(course, module_id, state.get("module_results") or {})
    if state.get("paused"):
        next_payload = {
            "module_id": None,
            "status": "paused",
            "reason": state.get("pause_reason") or "Course paused",
        }
    elif _is_daily_limit_reached(course, state):
        next_payload = {
            "module_id": None,
            "status": "locked",
            "reason": "일일 최대 이수 모듈 수에 도달했습니다.",
        }
    else:
        next_payload = {
            "module_id": next_result.get("next_module_id"),
            "status": next_result.get("status"),
            "reason": next_result.get("reason"),
        }

    response_data = {
        "passed": pass_result["passed"],
        "reason": pass_result["reason"],
        "accuracy": pass_result["accuracy"],
        "detail": pass_result["detail"],
        "next_module": next_payload,
        "student_state": state,
        "curriculum": {
            "enabled": _curriculum_enabled(course),
            "schedule": _build_schedule(course, state),
        },
    }

    return _wrap(response_data, "Module submission evaluated")


@router.post("/textbook-view/start", response_model=ApiResponse)
async def textbook_view_start(
    request: Request,
    body: dict[str, Any],
    _user=Depends(get_current_user),
):
    course_id: str = str(body.get("course_id", ""))
    textbook_id: str = str(body.get("textbook_id", ""))
    module_id: str = str(body.get("module_id", ""))

    if not course_id or not textbook_id:
        return _wrap(None, "course_id and textbook_id are required")

    course = repo.get_course_v2(course_id)
    if course is None:
        return _wrap(None, "Course not found")
    if not _can_access_course(request, course):
        return _wrap(None, "Course not found")

    target_user_id = _target_user(request, body.get("user_id"))
    if not target_user_id:
        return _wrap(None, "user_id is required")

    requested_from = _safe_int(body.get("page_from"), default=None)
    requested_to = _safe_int(body.get("page_to"), default=None)

    textbook = get_textbook(textbook_id)
    if textbook is None:
        return _wrap(None, "Textbook not found")

    module = _find_module_for_runtime(
        course=course,
        module_id=module_id,
        detail_textbook_id=textbook_id,
        page_from=requested_from,
        page_to=requested_to,
    )
    if module is None:
        return _wrap(None, "Course textbook module not found")

    min_minutes = _safe_int(body.get("min_minutes"), default=0) or 0
    enforce_min_minutes = bool(body.get("enforce_min_minutes"))

    module_from, module_to = _normalize_page_range(
        textbook,
        _safe_int(module.page_from, default=requested_from),
        _safe_int(module.page_to, default=requested_to),
    )

    initial_page = _safe_int(body.get("page"), default=module_from) or module_from
    initial_page = max(module_from, min(module_to, initial_page))

    state = _ensure_runtime_state(
        course,
        target_user_id,
        repo.get_runtime_state(target_user_id, course_id),
    )
    key = module.id or f"textbook_view:{textbook_id}:{module_from}:{module_to}"
    module_state = _touch_textbook_state(
        state=state,
        module_key=key,
        course_id=course_id,
        module_id=module.id,
        textbook_id=textbook_id,
        page_from=module_from,
        page_to=module_to,
        min_minutes=min_minutes,
        enforce_min_minutes=enforce_min_minutes,
        current_page=initial_page,
    )
    _tick_textbook_open_time(module_state)

    progress = _build_textbook_progress(
        module_state,
        enforce_min_minutes=bool(module_state.get("enforce_min_minutes")),
        min_minutes=_safe_int(module_state.get("min_minutes"), default=0) or 0,
        page_from=module_from,
        page_to=module_to,
        current_page=initial_page,
    )
    module_state["progress"] = progress

    repo.upsert_runtime_state(target_user_id, course_id, state)

    return _wrap(
        {
            "course_id": course_id,
            "module_id": module.id,
            "textbook_id": textbook_id,
            "module_key": key,
            "page_from": module_from,
            "page_to": module_to,
            "progress": progress,
            "student_state": state,
        },
        "Textbook view started",
    )


@router.post("/textbook-view/heartbeat", response_model=ApiResponse)
async def textbook_view_heartbeat(
    request: Request,
    body: dict[str, Any],
    _user=Depends(get_current_user),
):
    course_id: str = str(body.get("course_id", ""))
    textbook_id: str = str(body.get("textbook_id", ""))
    module_id: str = str(body.get("module_id", ""))
    current_page = _safe_int(body.get("page"), default=None)

    if not course_id or not textbook_id:
        return _wrap(None, "course_id and textbook_id are required")

    course = repo.get_course_v2(course_id)
    if course is None:
        return _wrap(None, "Course not found")
    if not _can_access_course(request, course):
        return _wrap(None, "Course not found")

    requested_from = _safe_int(body.get("page_from"), default=None)
    requested_to = _safe_int(body.get("page_to"), default=None)

    textbook = get_textbook(textbook_id)
    if textbook is None:
        return _wrap(None, "Textbook not found")

    module = _find_module_for_runtime(
        course=course,
        module_id=module_id,
        detail_textbook_id=textbook_id,
        page_from=requested_from,
        page_to=requested_to,
    )
    if module is None:
        return _wrap(None, "Course textbook module not found")

    target_user_id = _target_user(request, body.get("user_id"))
    if not target_user_id:
        return _wrap(None, "user_id is required")

    module_from, module_to = _normalize_page_range(
        textbook,
        _safe_int(module.page_from, default=requested_from),
        _safe_int(module.page_to, default=requested_to),
    )

    key = module.id or f"textbook_view:{textbook_id}:{module_from}:{module_to}"
    state = _ensure_runtime_state(
        course,
        target_user_id,
        repo.get_runtime_state(target_user_id, course_id),
    )
    module_state = _touch_textbook_state(
        state=state,
        module_key=key,
        course_id=course_id,
        module_id=module.id,
        textbook_id=textbook_id,
        page_from=module_from,
        page_to=module_to,
        min_minutes=_safe_int(module.min_minutes, default=0) or 0,
        enforce_min_minutes=bool(module.enforce_min_minutes),
        current_page=current_page or module_from,
    )

    current_page = _safe_int(module_state.get("current_page"), default=module_from) or module_from
    current_page = max(module_from, min(module_to, current_page))
    module_state["current_page"] = current_page

    _tick_textbook_open_time(module_state)
    progress = _build_textbook_progress(
        module_state,
        enforce_min_minutes=bool(module_state.get("enforce_min_minutes")),
        min_minutes=_safe_int(module_state.get("min_minutes"), default=0) or 0,
        page_from=module_from,
        page_to=module_to,
        current_page=current_page,
    )
    module_state["progress"] = progress

    repo.upsert_runtime_state(target_user_id, course_id, state)

    return _wrap(
        {
            "course_id": course_id,
            "module_id": module.id,
            "textbook_id": textbook_id,
            "module_key": key,
            "page_from": module_from,
            "page_to": module_to,
            "current_page": current_page,
            "progress": progress,
            "student_state": state,
        },
        "Textbook heartbeat updated",
    )


@router.post("/textbook-view/complete", response_model=ApiResponse)
async def textbook_view_complete(
    request: Request,
    body: dict[str, Any],
    _user=Depends(get_current_user),
):
    course_id: str = str(body.get("course_id", ""))
    textbook_id: str = str(body.get("textbook_id", ""))
    module_id: str = str(body.get("module_id", ""))
    current_page = _safe_int(body.get("page"), default=None)

    if not course_id or not textbook_id:
        return _wrap(None, "course_id and textbook_id are required")

    course = repo.get_course_v2(course_id)
    if course is None:
        return _wrap(None, "Course not found")
    if not _can_access_course(request, course):
        return _wrap(None, "Course not found")

    requested_from = _safe_int(body.get("page_from"), default=None)
    requested_to = _safe_int(body.get("page_to"), default=None)

    textbook = get_textbook(textbook_id)
    if textbook is None:
        return _wrap(None, "Textbook not found")

    module = _find_module_for_runtime(
        course=course,
        module_id=module_id,
        detail_textbook_id=textbook_id,
        page_from=requested_from,
        page_to=requested_to,
    )
    if module is None:
        return _wrap(None, "Course textbook module not found")

    target_user_id = _target_user(request, body.get("user_id"))
    if not target_user_id:
        return _wrap(None, "user_id is required")

    module_from, module_to = _normalize_page_range(
        textbook,
        _safe_int(module.page_from, default=requested_from),
        _safe_int(module.page_to, default=requested_to),
    )

    key = module.id or f"textbook_view:{textbook_id}:{module_from}:{module_to}"
    state = _ensure_runtime_state(
        course,
        target_user_id,
        repo.get_runtime_state(target_user_id, course_id),
    )
    module_state = _touch_textbook_state(
        state=state,
        module_key=key,
        course_id=course_id,
        module_id=module.id,
        textbook_id=textbook_id,
        page_from=module_from,
        page_to=module_to,
        min_minutes=_safe_int(module.min_minutes, default=0) or 0,
        enforce_min_minutes=bool(module.enforce_min_minutes),
        current_page=current_page or module_from,
    )

    current_page = _safe_int(module_state.get("current_page"), default=module_from) or module_from
    current_page = max(module_from, min(module_to, current_page))
    module_state["current_page"] = current_page

    _tick_textbook_open_time(module_state)
    progress = _build_textbook_progress(
        module_state,
        enforce_min_minutes=bool(module_state.get("enforce_min_minutes")),
        min_minutes=_safe_int(module_state.get("min_minutes"), default=0) or 0,
        page_from=module_from,
        page_to=module_to,
        current_page=current_page,
    )
    module_state["progress"] = progress

    completed = bool(progress.get("completed"))
    if completed:
        completed_modules = list(state.get("completed_modules") or [])
        if module.id and module.id not in completed_modules:
            completed_modules.append(module.id)
            state["completed_modules"] = completed_modules

            day_key = _today_iso()
            daily_completed = dict(state.get("daily_completed") or {})
            daily_completed[day_key] = int(daily_completed.get(day_key, 0)) + 1
            state["daily_completed"] = daily_completed

            completed_day = dict(state.get("module_completed_day") or {})
            completed_day[module.id] = _current_day_offset(state)
            state["module_completed_day"] = completed_day

            state = _enforce_deadline_and_pause(course, module.id, state)

    repo.upsert_runtime_state(target_user_id, course_id, state)

    return _wrap(
        {
            "course_id": course_id,
            "module_id": module.id,
            "textbook_id": textbook_id,
            "module_key": key,
            "page_from": module_from,
            "page_to": module_to,
            "current_page": current_page,
            "passed": completed,
            "progress": progress,
            "reason": "completed" if completed else "in_progress",
            "student_state": state,
            "curriculum": {
                "enabled": _curriculum_enabled(course),
                "schedule": _build_schedule(course, state),
            },
        },
        "Textbook view completed",
    )
