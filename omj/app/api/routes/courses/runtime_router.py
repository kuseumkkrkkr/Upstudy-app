"""FastAPI router for Course V2 runtime operations."""
from __future__ import annotations

import time
import random
from datetime import date
from typing import Any, Optional

from fastapi import APIRouter, Depends, Request

from app.api.routes.auth.middleware import require_role
from app.api.routes.challenge import service as daily_quest_service
from app.api.deps import get_current_user
from app.schemas.common import ApiResponse
from domain.course import engine
from domain.course import v2_repository as repo
from domain.academy import repository as academy_repo
from domain.course.v2_models import CourseModule, CourseModuleType
from storage.textbook_storage import get_textbook, is_teacher_manual_textbook
from storage.postgres_problem_store import postgres_problem_store
from storage.storage import get_quests_by_ids as get_local_quests_by_ids

router = APIRouter(prefix="/courses/v2/runtime", tags=["courses-v2-runtime"])

# 필요 변수: PostgreSQL 주 저장소와 카나리 이미지의 읽기 전용 원본 문제 DB다.
# 작동 원리: 운영 데이터는 PostgreSQL을 우선하고, 이관되지 않은 고정 코스 문제만
# 이미지의 원본 SQLite에서 보완해 공개 코스가 빈 화면으로 열리지 않게 한다.
get_quest = postgres_problem_store.get_problem
search_quests = postgres_problem_store.search_problems
update_quest_mcq = postgres_problem_store.update_problem_mcq


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


def _auto_complete_empty_wrong_answer_reviews(
    course,
    module_id: str,
    state: dict[str, Any],
    completed_modules: list[str],
    *,
    correct_count: int,
    total_count: int,
) -> list[str]:
    if total_count <= 0 or correct_count < total_count:
        return completed_modules

    review_prefix = f"{module_id}_wa_"
    review_ids = [
        module.id
        for module in course.modules
        if module.type == CourseModuleType.wrong_answer_review
        and str(module.id or "").startswith(review_prefix)
    ]
    if not review_ids:
        return completed_modules

    module_results = dict(state.get("module_results") or {})
    completed_day = dict(state.get("module_completed_day") or {})
    current_day = _current_day_offset(state)
    changed = False
    for review_id in review_ids:
        if review_id in completed_modules:
            continue
        completed_modules.append(review_id)
        module_results[review_id] = {
            "passed": True,
            "accuracy": 100,
            "correct_count": 0,
            "total_count": 0,
            "auto_completed": True,
            "reason": "no_wrong_answers",
        }
        completed_day[review_id] = current_day
        changed = True

    if changed:
        state["completed_modules"] = completed_modules
        state["module_results"] = module_results
        state["module_completed_day"] = completed_day
    return completed_modules


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


def _daily_quest_signals_for_runtime_submit(
    module: CourseModule,
    *,
    correct_count: int,
    total_count: int,
    elapsed_seconds: Optional[int],
    module_completed_now: bool,
) -> dict[str, int]:
    """필요 변수: 완료한 모듈 종류·정답/전체 수·소요 시간·최초 완료 여부.
    작동 원리: 런타임 서버가 판정한 결과만 일일 퀘스트 감지 신호로 변환한다.
    같은 모듈의 최초 완료 신호는 한 번만 보내고, 실제 제출 문제 수는 풀이 유형에만 반영한다.
    """
    signals: dict[str, int] = {}
    if module_completed_now:
        signals["course_module_completed"] = 1

    module_type = module.type
    if module_type == CourseModuleType.problem_solve:
        signals["problem_solved"] = max(0, total_count)
        signals["activity_score"] = max(0, correct_count)
    elif module_type == CourseModuleType.wrong_answer_review:
        signals["wrong_answer_solved"] = max(0, total_count)
        signals["wrong_answer_correct"] = max(0, correct_count)
        signals["activity_score"] = max(0, correct_count)
    elif module_type == CourseModuleType.exam_solve:
        signals["exam_attempt"] = 1
        signals["exam_accuracy"] = round((max(0, correct_count) / total_count) * 100) if total_count > 0 else 0
        signals["activity_score"] = max(0, correct_count)
        if total_count > 0 and correct_count >= total_count:
            signals["exam_perfect"] = 1

    if elapsed_seconds is not None and elapsed_seconds >= 60:
        signals["focus_minutes"] = max(1, elapsed_seconds // 60)
    return signals


def _record_runtime_daily_quest_activity(
    user_id: str,
    course_id: str,
    signals: dict[str, int],
) -> None:
    """필요 변수: 인증된 학생·코스 ID·런타임 검증 신호.
    작동 원리: 일일 퀘스트 반영 실패가 코스 학습 결과를 되돌리지 않도록 독립적으로
    기록하며, 빈 신호는 DB 요청 없이 건너뛴다.
    """
    if not signals:
        return
    daily_quest_service.record_daily_quest_activity(
        user_id,
        course_id,
        signals,
        source="course_runtime",
    )


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
    if role == "student":
        state = repo.get_runtime_state(user_id, course.id)
        if state.get("assigned_by_teacher") is True:
            return True
    group_id = str(course.access_group_id or "").strip()
    if group_id and academy_repo.is_active_group_member(group_id=group_id, user_id=user_id):
        if course.access_academy_id:
            group = academy_repo.get_group(group_id)
            return bool(group and str(group.get("academy_id") or "") == str(course.access_academy_id))
        return True
    return False


def _can_access_runtime_target(request: Request, course, target_user_id: str) -> bool:
    role: str = getattr(request.state, "role", "student")
    caller_id: str = getattr(request.state, "user_id", "")
    if not target_user_id:
        return False
    if target_user_id == caller_id:
        return True
    if role == "admin":
        return True
    if role != "teacher" or course.owner_user_id != caller_id:
        return False

    target_state = repo.get_runtime_state(target_user_id, course.id)
    if target_state.get("assigned_by_teacher") is True:
        return True
    if target_state and bool(course.is_public):
        return True

    group_id = str(course.access_group_id or "").strip()
    if not group_id:
        return False
    if not academy_repo.is_active_group_member(group_id=group_id, user_id=target_user_id):
        return False
    if course.access_academy_id:
        group = academy_repo.get_group(group_id)
        return bool(group and str(group.get("academy_id") or "") == str(course.access_academy_id))
    return True


def _blocks_to_text(value: Any) -> str:
    if isinstance(value, dict):
        blocks = value.get("blocks")
        if isinstance(blocks, list):
            return " ".join(
                str(block.get("content", "")).strip()
                for block in blocks
                if isinstance(block, dict) and str(block.get("content", "")).strip()
            ).strip()
    return str(value or "").strip()


def _number_or_none(value: Any) -> Optional[float]:
    text = _blocks_to_text(value)
    if not text:
        return None
    try:
        return float(text)
    except Exception:
        return None


def _build_choices(answer_value: Any, *, pattern: str = "pm2", shuffle: bool = True) -> tuple[list[dict[str, Any]], int]:
    answer_num = _number_or_none(answer_value)
    if answer_num is None:
        answer_text = _blocks_to_text(answer_value) or "0"
        values = [answer_text]
        while len(values) < 5:
            values.append(f"{answer_text}_{len(values)}")
        if shuffle:
            random.shuffle(values)
        answer_index = values.index(answer_text)
        return [{"blocks": [{"type": "text", "content": str(item)}]} for item in values], answer_index

    answer_int = int(round(answer_num))
    offsets = {
        "pm1": [-2, -1, 0, 1, 2],
        "mixed": [-2, -1, 0, 2, 4],
    }.get(pattern, [-4, -2, 0, 2, 4])
    values = [answer_int + offset for offset in offsets]
    while len(set(values)) < 5:
        values.append(answer_int + random.randint(-10, 10))
    values = list(dict.fromkeys(values))[:5]
    if shuffle:
        random.shuffle(values)
    answer_index = values.index(answer_int)
    return [{"blocks": [{"type": "text", "content": str(item)}]} for item in values], answer_index


def _ensure_mcq_quest(quest: dict[str, Any], module: CourseModule) -> dict[str, Any]:
    data = quest.get("data") if isinstance(quest.get("data"), dict) else {}
    qtype = str(data.get("question_type") or "").lower()
    objectify = str(getattr(module, "objectify_mode", "") or "").lower()
    if qtype in {"multiple_choice", "mcq"} or objectify not in {"multiple_choice", "mcq", "objectify"}:
        return quest

    policy = getattr(module, "mcq_policy", None)
    policy = policy if isinstance(policy, dict) else {}
    options, answer_index = _build_choices(
        data.get("quest_answer"),
        pattern=str(policy.get("offset_pattern") or "pm2"),
        shuffle=policy.get("random_choices") is not False,
    )
    quest_id = str((quest.get("header") or {}).get("quest_id") or "")
    if quest_id:
        update_quest_mcq(
            quest_id,
            quest_options=options,
            choice_answer_index=answer_index,
            meta={
                "mcq_conversion": {
                    "source_quest_id": quest_id,
                    "mcq_policy": policy or {"offset_pattern": "pm2", "random_choices": True},
                    "answer_index": answer_index,
                    "hints_forbidden": True,
                },
                "variant_meta": {"variant_input_mode": "course_runtime_mcq", "is_mcq_branch": True},
            },
        )
    data["question_type"] = "multiple_choice"
    data["quest_options"] = options
    data["choice_answer_index"] = answer_index
    quest["data"] = data
    return quest


def _problem_ids_from_module(module: CourseModule) -> list[str]:
    raw = module.problem_ids or getattr(module, "selected_problem_ids", None) or []
    if not isinstance(raw, list):
        return []
    return [str(item).strip() for item in raw if str(item).strip()]


def _load_module_quests(module: CourseModule) -> list[dict[str, Any]]:
    """필요 변수는 코스 모듈의 고정 문제 ID와 선택적 검색 조건이다.
    작동 원리는 고정 ID를 PostgreSQL에서 한 번에 읽고 누락 ID만 원본 SQLite로
    보완한 뒤, 순서·중복 제거·MCQ 변환을 유지해 카나리와 운영 응답 계약을 맞춘다.
    """
    quests: list[dict[str, Any]] = []
    seen: set[str] = set()
    problem_ids = _problem_ids_from_module(module)
    postgres_quests = postgres_problem_store.get_problems_by_ids(problem_ids)
    missing_ids = [quest_id for quest_id in problem_ids if quest_id not in postgres_quests]
    local_quests = {
        str((quest.get("header") or {}).get("quest_id") or ""): quest
        for quest in get_local_quests_by_ids(missing_ids)
        if isinstance(quest, dict)
    }
    for quest_id in problem_ids:
        quest = postgres_quests.get(quest_id) or local_quests.get(quest_id)
        if not quest:
            continue
        qid = str((quest.get("header") or {}).get("quest_id") or quest_id)
        if qid in seen:
            continue
        seen.add(qid)
        quests.append(_ensure_mcq_quest(quest, module))

    if quests:
        return quests

    query = getattr(module, "problem_query", None)
    query = query if isinstance(query, dict) else {}
    hash_tags = module.hash_tags or query.get("hash_tags") or []
    hash_tag = ",".join(str(tag).strip() for tag in hash_tags if str(tag).strip())
    text = str(query.get("text") or query.get("text_query") or "").strip()
    limit = int(module.question_count or module.max_problems or 10)
    if not hash_tag and not text:
        return []
    result = search_quests(
        hash_tag=hash_tag or None,
        text_query=text or None,
        page=1,
        page_size=max(1, min(limit, 50)),
    )
    for quest in result.get("quests", []):
        if isinstance(quest, dict):
            quests.append(_ensure_mcq_quest(quest, module))
    return quests[:limit]


@router.post("/problem-solve/load", response_model=ApiResponse)
async def problem_solve_load(
    request: Request,
    body: dict[str, Any],
    _user=Depends(get_current_user),
):
    course_id = str(body.get("course_id") or "").strip()
    module_id = str(body.get("module_id") or "").strip()
    if not course_id or not module_id:
        return _wrap(None, "course_id and module_id are required")
    course = repo.get_course_v2(course_id)
    if course is None or not _can_access_course(request, course):
        return _wrap(None, "Course not found")
    module = course.get_module(module_id)
    if module is None or module.type != CourseModuleType.problem_solve:
        return _wrap(None, "Problem solve module not found")
    quests = _load_module_quests(module)
    pass_rate = int(module.pass_rate if module.pass_rate is not None else 90)
    return _wrap(
        {
            "course_id": course_id,
            "module_id": module_id,
            "quests": quests,
            "pass_rate": pass_rate,
            "runtime_attempt": {
                "started_at": int(time.time()),
                "first_submit_locked": False,
            },
        },
        "Problem solve module loaded",
    )


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
    if not _can_access_runtime_target(request, course, target_user_id):
        return _wrap(None, "Course not found")

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
    if not _can_access_runtime_target(request, course, target_user_id):
        return _wrap(None, "Course not found")

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
    per_problem_elapsed_seconds = body.get("per_problem_elapsed_seconds")

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
    if not _can_access_runtime_target(request, course, target_user_id):
        return _wrap(None, "Course not found")

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
    previous_result = module_results.get(module_id) if isinstance(module_results.get(module_id), dict) else {}
    first_elapsed_seconds = previous_result.get("first_elapsed_seconds")
    if first_elapsed_seconds is None and elapsed_seconds is not None:
        first_elapsed_seconds = elapsed_seconds
    first_problem_elapsed = previous_result.get("first_problem_elapsed_seconds")
    if first_problem_elapsed is None and isinstance(per_problem_elapsed_seconds, list):
        first_problem_elapsed = per_problem_elapsed_seconds
    module_results[module_id] = {
        "passed": pass_result["passed"],
        "accuracy": pass_result["accuracy"],
        "correct_count": correct_count,
        "total_count": total_count,
        "first_elapsed_seconds": first_elapsed_seconds,
        "first_problem_elapsed_seconds": first_problem_elapsed,
        "latest_elapsed_seconds": elapsed_seconds,
    }
    state["module_results"] = module_results

    completed_modules = list(state.get("completed_modules") or [])
    module_completed_now = False
    if pass_result["passed"] and module_id not in completed_modules:
        module_completed_now = True
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

    if pass_result["passed"]:
        completed_modules = _auto_complete_empty_wrong_answer_reviews(
            course,
            module_id,
            state,
            completed_modules,
            correct_count=correct_count,
            total_count=total_count,
        )

    repo.upsert_runtime_state(target_user_id, course_id, state)
    _record_runtime_daily_quest_activity(
        target_user_id,
        course_id,
        _daily_quest_signals_for_runtime_submit(
            module,
            correct_count=correct_count,
            total_count=total_count,
            elapsed_seconds=elapsed_seconds,
            module_completed_now=module_completed_now,
        ),
    )

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
    if is_teacher_manual_textbook(textbook_id):
        return _wrap(None, "Course textbook module not found")

    course = repo.get_course_v2(course_id)
    if course is None:
        return _wrap(None, "Course not found")
    if not _can_access_course(request, course):
        return _wrap(None, "Course not found")

    target_user_id = _target_user(request, body.get("user_id"))
    if not target_user_id:
        return _wrap(None, "user_id is required")
    if not _can_access_runtime_target(request, course, target_user_id):
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
    if is_teacher_manual_textbook(textbook_id):
        return _wrap(None, "Course textbook module not found")

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
    if not _can_access_runtime_target(request, course, target_user_id):
        return _wrap(None, "Course not found")

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
    if is_teacher_manual_textbook(textbook_id):
        return _wrap(None, "Course textbook module not found")

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
    if not _can_access_runtime_target(request, course, target_user_id):
        return _wrap(None, "Course not found")

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
    module_completed_now = False
    if completed:
        completed_modules = list(state.get("completed_modules") or [])
        if module.id and module.id not in completed_modules:
            module_completed_now = True
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
    if module_completed_now:
        _record_runtime_daily_quest_activity(
            target_user_id,
            course_id,
            {
                "textbook_completed": 1,
                "course_module_completed": 1,
                "activity_score": 1,
            },
        )

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
