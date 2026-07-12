"""Academy domain API router.

Provides CRUD + business-logic endpoints for:
- Academy
- AcademyGroup (with friend verification, group limits, group type separation)
- AcademyGroupMember (with event logging)
- AttendanceLog (with statistics)
- TuitionPayment (with summary)
- FinanceLedger (with summary)
- ParentConsultNote
- GroupAssignment / GroupSubmission / SubmissionReport (3-stage pipeline)
- TimetablePreference / TimetablePlan (heuristic v1)
- StudentOverviewSnapshot (auto-build)
"""
import json
import random
import re
import sqlite3
import uuid
from datetime import datetime, timedelta
from typing import Any, Optional, List

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field

from app.api.deps import get_current_user
from domain.academy import repository as repo
from domain.course import v2_repository as course_v2_repo
from storage.social_storage import append_message, are_friends, get_user_by_id
from storage.social_storage import search_users_by_username
from storage.study_group_storage import append_group_message
from storage.rating_storage import create_user, get_user, list_tag_stats
from storage.solve_history import list_solve_history
from storage.level_test_analysis_storage import (
    list_level_test_analysis_summaries,
    save_level_test_analysis_session,
)
from storage.storage import DB_PATH
from storage.weakness_storage import list_weakness_tags
from services.ai.sam_client import generate_json, is_sam_configured

router = APIRouter(prefix="/academy", tags=["academy"])

MAX_GROUPS_PER_USER = 3
MAX_GROUPS_CREATED_PER_USER = 3


def _is_teacher_admin(role: str) -> bool:
    role_norm = (role or "").strip().lower()
    return role_norm in {"teacher", "admin", "academy_admin", "academy_teacher"}


def _is_admin_user(user: dict) -> bool:
    role = str(user.get("role") or "").strip().lower()
    return role in {"admin", "academy_admin"}


def _ensure_friend_access_or_403(caller_user_id: str, target_user_id: str) -> None:
    if not target_user_id or caller_user_id == target_user_id:
        return
    if not are_friends(caller_user_id, target_user_id):
        raise HTTPException(status_code=403, detail="Only friend students are accessible")


def _can_submit_course_level_test(user: dict, course) -> bool:
    user_id = str(user.get("user_id") or "")
    role = str(user.get("role") or "").strip().lower()
    if bool(course.is_public):
        return True
    if role == "admin":
        return True
    if role in {"teacher", "academy_teacher", "academy_admin"} and course.owner_user_id == user_id:
        return True
    state = course_v2_repo.get_runtime_state(user_id, course.id)
    if state.get("assigned_by_teacher") is True:
        return True
    group_id = str(course.access_group_id or "").strip()
    if not group_id:
        return False
    if not repo.is_active_group_member(group_id=group_id, user_id=user_id):
        return False
    if course.access_academy_id:
        group = repo.get_group(group_id)
        return bool(group and str(group.get("academy_id") or "") == str(course.access_academy_id))
    return True


def _parse_duration_days(value: Optional[str]) -> Optional[int]:
    text = str(value or "").strip().lower()
    if not text:
        return None
    compact = re.sub(r"\s+", "", text)
    match = re.fullmatch(r"(\d+)", compact)
    if match:
        return max(0, int(match.group(1)))
    match = re.search(r"(\d+)(일|day|days)", compact)
    if match:
        return max(0, int(match.group(1)))
    match = re.search(r"(\d+)(주|week|weeks)", compact)
    if match:
        return max(0, int(match.group(1)) * 7)
    match = re.search(r"(\d+)(개월|달|month|months)", compact)
    if match:
        return max(0, int(match.group(1)) * 30)
    return None


def _validate_course_due_date(course_id: str, due_date: Optional[str]) -> None:
    if not due_date:
        return
    course = course_v2_repo.get_course_v2(course_id)
    if course is None:
        raise HTTPException(status_code=404, detail="Course not found")
    allowed_days = _parse_duration_days(course.duration)
    if allowed_days is None:
        raise HTTPException(status_code=400, detail="course_duration_unbounded")
    try:
        due = datetime.strptime(due_date, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(status_code=400, detail="due_date must be YYYY-MM-DD")
    max_due = (datetime.utcnow().date() + timedelta(days=allowed_days))
    if due > max_due:
        raise HTTPException(status_code=400, detail="course_due_date_exceeds_duration")


def _is_active_teacher_in_group(group_id: str, user_id: str) -> bool:
    members = repo.list_group_members(
        group_id=group_id,
        user_id=user_id,
        status="active",
    )
    return any(
        str(member.get("role") or "").strip().lower() in {"teacher", "admin"}
        for member in members
    )


def _can_manage_group(user: dict, group_id: str) -> bool:
    if _is_admin_user(user):
        return True
    user_id = str(user.get("user_id") or "")
    return bool(group_id and user_id and _is_active_teacher_in_group(group_id, user_id))


def _can_access_group(user: dict, group_id: str) -> bool:
    if _can_manage_group(user, group_id):
        return True
    user_id = str(user.get("user_id") or "")
    return bool(group_id and user_id and repo.is_active_group_member(group_id=group_id, user_id=user_id))


def _require_group_manager(user: dict, group_id: str) -> None:
    if not _can_manage_group(user, group_id):
        raise HTTPException(status_code=403, detail="Teacher is not an active member of this group")


def _require_group_member(user: dict, group_id: str) -> None:
    if not _can_access_group(user, group_id):
        raise HTTPException(status_code=403, detail="Only group members can access this group")


def _can_manage_academy(user: dict, academy_id: str) -> bool:
    if _is_admin_user(user):
        return True
    user_id = str(user.get("user_id") or "")
    academy = repo.get_academy(academy_id) if academy_id else None
    if academy and str(academy.get("admin_user_id") or "") == user_id:
        return True
    return bool(
        academy_id
        and user_id
        and repo.is_active_academy_teacher(academy_id=academy_id, user_id=user_id)
    )


def _require_academy_manager(user: dict, academy_id: str) -> None:
    if not _can_manage_academy(user, academy_id):
        raise HTTPException(status_code=403, detail="Teacher is not an active member of this academy")


def _require_academy_student(academy_id: str, user_id: str) -> None:
    if not repo.is_active_academy_member(academy_id=academy_id, user_id=user_id):
        raise HTTPException(status_code=403, detail="Student is not an active member of this academy")


def _require_tuition_manager(payment_id: str, user: dict) -> dict:
    payment = repo.get_tuition_payment(payment_id)
    if not payment:
        raise HTTPException(status_code=404, detail="Tuition payment not found")
    _require_academy_manager(user, str(payment.get("academy_id") or ""))
    return payment


def _require_ledger_manager(ledger_id: str, user: dict) -> dict:
    entry = repo.get_ledger_entry(ledger_id)
    if not entry:
        raise HTTPException(status_code=404, detail="Ledger entry not found")
    _require_academy_manager(user, str(entry.get("academy_id") or ""))
    return entry


def _require_consult_manager(note_id: str, user: dict) -> dict:
    note = repo.get_consult_note(note_id)
    if not note:
        raise HTTPException(status_code=404, detail="Consult note not found")
    _require_academy_manager(user, str(note.get("academy_id") or ""))
    return note


def _require_assignment_manager(assignment_id: str, user: dict) -> dict:
    assignment = repo.get_assignment(assignment_id)
    if not assignment:
        raise HTTPException(status_code=404, detail="Assignment not found")
    _require_group_manager(user, str(assignment.get("group_id") or ""))
    return assignment


def _require_attendance_manager(log_id: str, user: dict) -> dict:
    log = repo.get_attendance_log(log_id)
    if not log:
        raise HTTPException(status_code=404, detail="Attendance not found")
    _require_group_manager(user, str(log.get("group_id") or ""))
    return log


def _get_submission_and_assignment(submission_id: str) -> tuple[dict, dict]:
    submission = repo.get_submission(submission_id)
    if not submission:
        raise HTTPException(status_code=404, detail="Submission not found")
    assignment = repo.get_assignment(str(submission.get("assignment_id") or ""))
    if not assignment:
        raise HTTPException(status_code=404, detail="Assignment not found")
    return submission, assignment


def _ensure_submission_access(user: dict, submission: dict, assignment: dict) -> None:
    if _is_admin_user(user):
        return
    user_id = str(user.get("user_id") or "")
    if user_id and str(submission.get("user_id") or "") == user_id:
        return
    _require_group_manager(user, str(assignment.get("group_id") or ""))


def _validate_course_assignment_scope(
    *,
    course_id: str,
    group_id: str,
    user: dict,
) -> None:
    user_id = str(user.get("user_id") or "")
    role = str(user.get("role") or "").strip().lower()
    group = repo.get_group(group_id)
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")
    if role != "admin" and not _is_active_teacher_in_group(group_id, user_id):
        raise HTTPException(status_code=403, detail="Teacher is not an active member of this group")

    course = course_v2_repo.get_course_v2(course_id)
    if course is None:
        raise HTTPException(status_code=404, detail="Course not found")
    if role != "admin" and course.owner_user_id != user_id:
        raise HTTPException(status_code=403, detail="Only the course owner can assign this course")
    if bool(course.is_public):
        return

    course_group_id = str(course.access_group_id or "").strip()
    course_academy_id = str(course.access_academy_id or "").strip()
    group_academy_id = str(group.get("academy_id") or "").strip()
    if course_group_id != group_id or (
        course_academy_id and course_academy_id != group_academy_id
    ):
        raise HTTPException(
            status_code=403,
            detail="Private course must be deployed to the target group before assignment",
        )


def _enroll_course_v2_for_students(course_id: str, user_ids: List[str]) -> None:
    course = course_v2_repo.get_course_v2(course_id)
    if course is None:
        raise HTTPException(status_code=404, detail="Course not found")
    for user_id in user_ids:
        state = course_v2_repo.get_runtime_state(user_id, course_id)
        if not state:
            state = {
                "status": "in_progress",
                "assigned_by_teacher": True,
                "assigned_at": datetime.utcnow().isoformat(timespec="seconds") + "Z",
            }
        else:
            state["assigned_by_teacher"] = True
        course_v2_repo.upsert_runtime_state(user_id, course_id, state)


def _send_assignment_notice(
    *,
    sender_user_id: str,
    group_id: str,
    target_user_ids: List[str],
    chat_mode: str,
    text: str,
) -> List[str]:
    errors: List[str] = []
    mode = chat_mode
    if mode == "auto":
        active_count = len(
            [
                item
                for item in repo.list_group_members(group_id=group_id, status="active")
                if str(item.get("role") or "student").lower() == "student"
            ]
        )
        mode = "group" if len(target_user_ids) == active_count else "direct"
    if mode == "group":
        try:
            append_group_message(group_id=group_id, user_id=sender_user_id, text=text)
        except Exception as exc:
            errors.append(f"group:{exc}")
        return errors
    now = datetime.utcnow().isoformat(timespec="seconds") + "Z"
    sender = get_user_by_id(sender_user_id)
    sender_name = (sender or {}).get("username") or sender_user_id
    for target_user_id in target_user_ids:
        try:
            append_message(
                message_id=str(uuid.uuid4()),
                user_id=sender_user_id,
                peer_id=target_user_id,
                text=text,
                created_at=now,
                is_mine=True,
            )
            append_message(
                message_id=str(uuid.uuid4()),
                user_id=target_user_id,
                peer_id=sender_user_id,
                text=text,
                created_at=now,
                is_mine=False,
            )
        except Exception as exc:
            errors.append(f"direct:{target_user_id}:{sender_name}:{exc}")
    return errors


def _json_list(value: object) -> list:
    if not value:
        return []
    if isinstance(value, list):
        return value
    try:
        parsed = json.loads(str(value))
        return parsed if isinstance(parsed, list) else []
    except Exception:
        return []


def _assignment_progress_for_student(user_id: str) -> dict:
    rows = repo.list_my_assignments(user_id=user_id)
    homework = []
    courses = []
    for row in rows:
        kind = str(row.get("kind") or "")
        item = {
            "assignment_id": row.get("assignment_id"),
            "submission_id": row.get("submission_id"),
            "title": row.get("title") or row.get("ref_id"),
            "ref_id": row.get("ref_id"),
            "due_date": row.get("due_date"),
            "status": row.get("submission_status") or "pending",
        }
        if kind == "course":
            state = course_v2_repo.get_runtime_state(user_id, str(row.get("ref_id") or ""))
            item["runtime_state"] = state
            item["progress"] = state.get("progress") or state.get("percent") or 0
            courses.append(item)
        elif kind == "homework":
            homework.append(item)
    return {"homework": homework, "courses": courses}


def _build_student_analysis(user_id: str) -> dict:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        rating = get_user(conn, user_id)
        if not rating:
            rating = create_user(conn, user_id=user_id, rating=1000.0)
            conn.commit()
        recent_results = _json_list(rating.get("recent_results"))
        recent_count = int(rating.get("recent_count") or 0)
        recent_sum = int(rating.get("recent_sum") or 0)
        tag_stats = list_tag_stats(conn, user_id)
    finally:
        conn.close()

    assignments = _assignment_progress_for_student(user_id)
    return {
        "user_id": user_id,
        "rating": {
            "rating": float(rating.get("rating") or 0),
            "ovr": float(rating.get("ovr") or 0),
            "ovr_prev": float(rating.get("ovr_prev") or 0),
            "ovr_delta": float(rating.get("ovr") or 0) - float(rating.get("ovr_prev") or 0),
            "recent_accuracy": (recent_sum / recent_count) if recent_count > 0 else 0.0,
            "recent_results": recent_results,
            "recent_count": recent_count,
        },
        "solve_history": list_solve_history(user_id=user_id, days=30, limit=20),
        "level_test_analysis": list_level_test_analysis_summaries(user_id, limit=20),
        "weakness_tags": list_weakness_tags(user_id)[:12],
        "tag_ratings": [
            {
                "tag": item.get("tag"),
                "attempts": item.get("attempts"),
                "rating": item.get("rating"),
                "delta": float(item.get("rating") or 0) - float(item.get("rating_prev") or 0),
            }
            for item in tag_stats[:12]
        ],
        "homework": assignments["homework"],
        "courses": assignments["courses"],
        "student_schedule": repo.list_student_schedule_tasks(user_id=user_id, limit=100),
    }


def _build_level_test_ai_summary(body: "LevelTestAnalysisSubmit") -> Optional[dict[str, Any]]:
    if body.ai_summary:
        return body.ai_summary
    if not is_sam_configured():
        return None
    problems = [item.model_dump() for item in body.problem_results]
    incorrect = [item for item in problems if item.get("is_correct") is False]
    sample_pool = incorrect or problems
    sample_count = min(5, max(3, len(sample_pool))) if len(sample_pool) >= 3 else len(sample_pool)
    samples = random.sample(sample_pool, sample_count) if sample_count else []
    prompt = (
        "Analyze this math level-test result for a teacher. "
        "Use only the provided anonymized statistics and problem-level minimal flow data. "
        "Return JSON with keys: summary, mathematical_thinking, weak_points, recommended_first_actions. "
        "Keep it concise and Korean.\n\n"
        + json.dumps(
            {
                "exam_id": body.exam_id,
                "tags": body.tags,
                "correct_count": body.correct_count,
                "total_count": body.total_count,
                "accuracy": body.accuracy,
                "elapsed_seconds": body.elapsed_seconds,
                "problem_samples": samples,
            },
            ensure_ascii=False,
        )
    )
    try:
        return generate_json(
            model=body.analysis_model or "gemma-4",
            prompt=prompt,
            temperature=0.2,
            max_tokens=1200,
        )
    except Exception:
        return None


# ---------------------------------------------------------------------------
# Response wrapper
# ---------------------------------------------------------------------------

class ApiResponse(BaseModel):
    success: bool = True
    data: Optional[dict] = None
    message: Optional[str] = None


class LevelTestProblemResult(BaseModel):
    item_index: int = Field(ge=1)
    quest_id: str = ""
    is_correct: bool
    tags: list[str] = Field(default_factory=list)
    selected_index: Optional[int] = None
    elapsed_seconds: Optional[int] = Field(default=None, ge=0)
    wrong_points: list[dict[str, Any]] = Field(default_factory=list)
    flow_minimum: list[dict[str, Any]] = Field(default_factory=list)


class LevelTestAnalysisSubmit(BaseModel):
    session_id: str = Field(min_length=1, max_length=120)
    course_id: str = Field(min_length=1, max_length=120)
    module_id: str = Field(min_length=1, max_length=120)
    exam_id: str = ""
    exam_title: str = ""
    tags: list[str] = Field(default_factory=list)
    correct_count: int = Field(ge=0)
    total_count: int = Field(ge=0)
    accuracy: float = Field(ge=0, le=100)
    passed: bool = False
    elapsed_seconds: int = Field(default=0, ge=0)
    analysis_model: str = "gemma-4"
    analysis_retention_days: int = Field(default=7, ge=1, le=7)
    ai_summary: Optional[dict[str, Any]] = None
    problem_results: list[LevelTestProblemResult] = Field(default_factory=list)


@router.post("/analysis/level-test", response_model=ApiResponse)
def submit_level_test_analysis(
    body: LevelTestAnalysisSubmit,
    user: dict = Depends(get_current_user),
):
    user_id = str(user.get("user_id") or "")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid token")

    course = course_v2_repo.get_course_v2(body.course_id)
    if course is None:
        raise HTTPException(status_code=404, detail="Course not found")
    if not _can_submit_course_level_test(user, course):
        raise HTTPException(status_code=403, detail="Course not found")
    module = course.get_module(body.module_id)
    module_type = getattr(module.type, "value", str(module.type)) if module else ""
    if module is None or module_type != "level_test":
        raise HTTPException(status_code=404, detail="Level test module not found")

    payload = body.model_dump()
    payload["user_id"] = user_id
    ai_summary = _build_level_test_ai_summary(body)
    if ai_summary:
        payload["ai_summary"] = ai_summary
    result = save_level_test_analysis_session(
        user_id=user_id,
        session_id=body.session_id,
        payload=payload,
        retention_days=body.analysis_retention_days,
    )
    return ApiResponse(data=result, message="Level test analysis saved")


@router.get("/friends/search-nickname", response_model=ApiResponse)
def search_friends_by_nickname(
    q: str = Query(..., min_length=1, max_length=50),
    limit: int = Query(default=20, ge=1, le=50),
    user: dict = Depends(get_current_user),
):
    """Search users by nickname/username inside academy feature flow.

    Used before academy group features are fully enabled so teachers/students
    can still add friends from academy context.
    """
    items = search_users_by_username(
        q,
        exclude_user_id=user.get("user_id"),
        limit=limit,
    )
    return ApiResponse(data={"items": items})


# ---------------------------------------------------------------------------
# Academy
# ---------------------------------------------------------------------------

class AcademyCreate(BaseModel):
    name: str
    address: Optional[str] = None
    phone: Optional[str] = None


class AcademyUpdate(BaseModel):
    name: Optional[str] = None
    address: Optional[str] = None
    phone: Optional[str] = None
    admin_user_id: Optional[str] = None


@router.post("", response_model=ApiResponse)
def create_academy(body: AcademyCreate, user: dict = Depends(get_current_user)):
    if not _is_teacher_admin(str(user.get("role") or "")):
        raise HTTPException(status_code=403, detail="Only teachers/admins can create academies")
    data = repo.create_academy(
        name=body.name,
        address=body.address,
        phone=body.phone,
        admin_user_id=user.get("user_id"),
    )
    return ApiResponse(data=data)


@router.get("", response_model=ApiResponse)
def list_academies(user: dict = Depends(get_current_user)):
    data = repo.list_academies()
    return ApiResponse(data={"items": data})


# ---------------------------------------------------------------------------
# AcademyGroup
# ---------------------------------------------------------------------------

class GroupCreate(BaseModel):
    academy_id: str
    name: str
    grade: Optional[str] = None
    subject: Optional[str] = None
    group_type: str = Field(default="academy_tutoring_group", description="academy_tutoring_group | social_study_group")
    searchable: bool = False
    friend_verification_required: bool = True
    max_members: int = Field(default=20, ge=1, le=100)
    style_border_color: Optional[str] = None
    style_badge_text: Optional[str] = None
    schedule_json: Optional[str] = None


class GroupUpdate(BaseModel):
    name: Optional[str] = None
    grade: Optional[str] = None
    subject: Optional[str] = None
    teacher_user_id: Optional[str] = None
    group_type: Optional[str] = None
    searchable: Optional[bool] = None
    friend_verification_required: Optional[bool] = None
    max_members: Optional[int] = None
    style_border_color: Optional[str] = None
    style_badge_text: Optional[str] = None
    schedule_json: Optional[str] = None


@router.post("/groups", response_model=ApiResponse)
def create_group(body: GroupCreate, user: dict = Depends(get_current_user)):
    """Create a new academy group.

    Enforces:
    - Max 3 groups created per user per academy
    - Max 3 total academy groups per user
    """
    user_id = user.get("user_id")
    role = user.get("role")

    # Only teachers/admins can create academy_tutoring_group
    if body.group_type == "academy_tutoring_group" and not _is_teacher_admin(str(role or "")):
        raise HTTPException(status_code=403, detail="Only teachers/admins can create academy tutoring groups")

    # Enforce: max 1 group created per user per academy
    created_count = repo.count_groups_created_by_user(user_id, body.academy_id)
    if created_count >= MAX_GROUPS_CREATED_PER_USER:
        raise HTTPException(status_code=400, detail=f"User already created {MAX_GROUPS_CREATED_PER_USER} group(s) in this academy")

    # Enforce: max 3 total academy groups per user
    total_count = repo.count_groups_for_user(user_id)
    if total_count >= MAX_GROUPS_PER_USER:
        raise HTTPException(status_code=400, detail=f"User already joined {MAX_GROUPS_PER_USER} academy groups")

    data = repo.create_group(
        academy_id=body.academy_id,
        name=body.name,
        grade=body.grade,
        subject=body.subject,
        teacher_user_id=user_id,
        group_type=body.group_type,
        searchable=body.searchable,
        friend_verification_required=body.friend_verification_required,
        max_members=body.max_members,
        style_border_color=body.style_border_color,
        style_badge_text=body.style_badge_text,
        schedule_json=body.schedule_json,
    )

    # Auto-add creator as teacher member
    repo.add_group_member(
        group_id=data["group_id"],
        user_id=user_id,
        role="teacher",
        status="active",
    )

    return ApiResponse(data=data)


@router.get("/groups", response_model=ApiResponse)
def list_groups(
    academy_id: Optional[str] = None,
    group_type: Optional[str] = None,
    searchable: Optional[bool] = None,
    user: dict = Depends(get_current_user),
):
    """List academy groups.

    - academy_tutoring_group: only visible to academy members
    - social_study_group: visible if searchable=True
    """
    data = repo.list_groups(academy_id=academy_id, group_type=group_type, searchable=searchable)
    return ApiResponse(data={"items": data})


@router.get("/groups/{group_id}", response_model=ApiResponse)
def get_group(group_id: str, user: dict = Depends(get_current_user)):
    data = repo.get_group(group_id)
    if not data:
        raise HTTPException(status_code=404, detail="Group not found")
    if not bool(data.get("searchable")):
        _require_group_member(user, group_id)
    return ApiResponse(data=data)


@router.put("/groups/{group_id}", response_model=ApiResponse)
def update_group(group_id: str, body: GroupUpdate, user: dict = Depends(get_current_user)):
    if not _is_teacher_admin(str(user.get("role") or "")):
        raise HTTPException(status_code=403, detail="Only teachers/admins can update groups")
    _require_group_manager(user, group_id)
    data = repo.update_group(
        group_id,
        name=body.name,
        grade=body.grade,
        subject=body.subject,
        teacher_user_id=body.teacher_user_id,
        group_type=body.group_type,
        searchable=body.searchable,
        friend_verification_required=body.friend_verification_required,
        max_members=body.max_members,
        style_border_color=body.style_border_color,
        style_badge_text=body.style_badge_text,
        schedule_json=body.schedule_json,
    )
    return ApiResponse(data=data)


@router.delete("/groups/{group_id}", response_model=ApiResponse)
def delete_group(group_id: str, user: dict = Depends(get_current_user)):
    if not _is_teacher_admin(str(user.get("role") or "")):
        raise HTTPException(status_code=403, detail="Only teachers/admins can delete groups")
    _require_group_manager(user, group_id)
    deleted = repo.delete_group(group_id)
    return ApiResponse(success=deleted, message="Deleted" if deleted else "Not found")


# ---------------------------------------------------------------------------
# AcademyGroupMember
# ---------------------------------------------------------------------------

class MemberCreate(BaseModel):
    group_id: str
    user_id: str
    role: str = "student"


class MemberInvite(BaseModel):
    group_id: str
    invited_user_id: str


@router.post("/members", response_model=ApiResponse)
def add_group_member(body: MemberCreate, user: dict = Depends(get_current_user)):
    """Add a member to a group.

    Enforces:
    - Max 3 academy groups per user
    - Friend verification if group requires it
    - Group capacity limit
    """
    group = repo.get_group(body.group_id)
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")
    _require_group_manager(user, body.group_id)

    # Check group capacity
    member_count = repo.get_group_member_count(body.group_id)
    if member_count >= group.get("max_members", 20):
        raise HTTPException(status_code=400, detail="Group is full")

    # Check user's group limit
    current_count = repo.count_groups_for_user(body.user_id)
    if current_count >= MAX_GROUPS_PER_USER:
        raise HTTPException(status_code=400, detail=f"User already joined {MAX_GROUPS_PER_USER} academy groups")

    # Friend verification
    if group.get("friend_verification_required", True):
        inviter_id = user.get("user_id")
        if not are_friends(inviter_id, body.user_id):
            raise HTTPException(status_code=403, detail="Active friendship required to join this group")

    data = repo.add_group_member(
        group_id=body.group_id,
        user_id=body.user_id,
        role=body.role,
        status="active",
    )

    # Log event
    repo.log_member_event(
        group_id=body.group_id,
        user_id=body.user_id,
        event_type="joined",
        triggered_by_user_id=user.get("user_id"),
        reason="direct_add",
    )

    return ApiResponse(data=data)


@router.post("/members/invite", response_model=ApiResponse)
def invite_member(body: MemberInvite, user: dict = Depends(get_current_user)):
    """Invite a member via friend verification.

    Creates a pending member record; actual join requires acceptance.
    """
    group = repo.get_group(body.group_id)
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")
    _require_group_manager(user, body.group_id)

    # Check group capacity
    member_count = repo.get_group_member_count(body.group_id)
    if member_count >= group.get("max_members", 20):
        raise HTTPException(status_code=400, detail="Group is full")

    # Check invitee's group limit
    current_count = repo.count_groups_for_user(body.invited_user_id)
    if current_count >= MAX_GROUPS_PER_USER:
        raise HTTPException(status_code=400, detail=f"User already joined {MAX_GROUPS_PER_USER} academy groups")

    # Friend verification
    if group.get("friend_verification_required", True):
        inviter_id = user.get("user_id")
        if not are_friends(inviter_id, body.invited_user_id):
            raise HTTPException(status_code=403, detail="Active friendship required to invite this user")

    data = repo.add_group_member(
        group_id=body.group_id,
        user_id=body.invited_user_id,
        role="student",
        status="pending",
    )

    # Log event
    repo.log_member_event(
        group_id=body.group_id,
        user_id=body.invited_user_id,
        event_type="invited",
        triggered_by_user_id=user.get("user_id"),
    )

    return ApiResponse(data=data, message="Invitation sent")


@router.post("/members/{member_id}/accept", response_model=ApiResponse)
def accept_invitation(member_id: str, user: dict = Depends(get_current_user)):
    """Accept a pending group invitation."""
    member = repo.get_group_member(member_id)
    if not member:
        raise HTTPException(status_code=404, detail="Member not found")
    if member.get("status") != "pending":
        raise HTTPException(status_code=400, detail="Member is not in pending status")
    if member.get("user_id") != user.get("user_id"):
        raise HTTPException(status_code=403, detail="Can only accept your own invitations")

    data = repo.update_member_status(member_id, "active")

    # Log event
    repo.log_member_event(
        group_id=member.get("group_id"),
        user_id=member.get("user_id"),
        event_type="joined",
        triggered_by_user_id=user.get("user_id"),
        reason="accepted_invitation",
    )

    return ApiResponse(data=data)


@router.get("/groups/{group_id}/members", response_model=ApiResponse)
def list_group_members(group_id: str, user: dict = Depends(get_current_user)):
    _require_group_member(user, group_id)
    data = repo.list_group_members(group_id=group_id)
    return ApiResponse(data={"items": data})


@router.delete("/members/{member_id}", response_model=ApiResponse)
def remove_group_member(member_id: str, reason: Optional[str] = None, user: dict = Depends(get_current_user)):
    member = repo.get_group_member(member_id)
    if not member:
        raise HTTPException(status_code=404, detail="Member not found")
    if member.get("user_id") != user.get("user_id"):
        if not _is_teacher_admin(str(user.get("role") or "")):
            raise HTTPException(status_code=403, detail="Only teachers/admins can remove members")
        _require_group_manager(user, str(member.get("group_id") or ""))
    deleted = repo.remove_group_member(member_id, reason=reason)
    return ApiResponse(success=deleted, message="Removed" if deleted else "Not found")


@router.get("/groups/{group_id}/events", response_model=ApiResponse)
def list_member_events(
    group_id: str,
    event_type: Optional[str] = None,
    limit: int = Query(default=100, le=500),
    user: dict = Depends(get_current_user),
):
    _require_group_manager(user, group_id)
    data = repo.list_member_events(group_id=group_id, event_type=event_type, limit=limit)
    return ApiResponse(data={"items": data})


# ---------------------------------------------------------------------------
# AttendanceLog
# ---------------------------------------------------------------------------

class AttendanceCreate(BaseModel):
    group_id: str
    user_id: str
    date: str  # YYYY-MM-DD
    status: str = Field(..., pattern=r"^(present|late|absent)$")
    note: Optional[str] = None


class AttendanceUpdate(BaseModel):
    status: Optional[str] = None
    note: Optional[str] = None


@router.post("/attendance", response_model=ApiResponse)
def record_attendance(body: AttendanceCreate, user: dict = Depends(get_current_user)):
    if not _is_teacher_admin(str(user.get("role") or "")):
        raise HTTPException(status_code=403, detail="Only teachers/admins can record attendance")
    _require_group_manager(user, body.group_id)
    if not repo.is_active_group_member(group_id=body.group_id, user_id=body.user_id):
        raise HTTPException(status_code=403, detail="Student is not an active member of this group")
    data = repo.record_attendance(
        group_id=body.group_id,
        user_id=body.user_id,
        date=body.date,
        status=body.status,
        checked_by_user_id=user.get("user_id"),
        note=body.note,
    )
    return ApiResponse(data=data)


@router.get("/attendance", response_model=ApiResponse)
def list_attendance(
    group_id: Optional[str] = None,
    user_id: Optional[str] = None,
    date: Optional[str] = None,
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
    user: dict = Depends(get_current_user),
):
    caller_user_id = str(user.get("user_id") or "")
    if _is_admin_user(user):
        data = repo.list_attendance(
            group_id=group_id,
            user_id=user_id,
            date=date,
            date_from=date_from,
            date_to=date_to,
        )
    elif _is_teacher_admin(str(user.get("role") or "")):
        if group_id:
            _require_group_manager(user, group_id)
        data = repo.list_attendance_for_teacher(
            teacher_user_id=caller_user_id,
            group_id=group_id,
            user_id=user_id,
            date=date,
            date_from=date_from,
            date_to=date_to,
        )
    else:
        if user_id and user_id != caller_user_id:
            raise HTTPException(status_code=403, detail="Can only view your own attendance")
        if group_id:
            _require_group_member(user, group_id)
        data = repo.list_attendance(
            group_id=group_id,
            user_id=caller_user_id,
            date=date,
            date_from=date_from,
            date_to=date_to,
        )
    return ApiResponse(data={"items": data})


@router.put("/attendance/{log_id}", response_model=ApiResponse)
def update_attendance(log_id: str, body: AttendanceUpdate, user: dict = Depends(get_current_user)):
    if not _is_teacher_admin(str(user.get("role") or "")):
        raise HTTPException(status_code=403, detail="Only teachers/admins can update attendance")
    _require_attendance_manager(log_id, user)
    data = repo.update_attendance(log_id, status=body.status, note=body.note)
    return ApiResponse(data=data)


@router.delete("/attendance/{log_id}", response_model=ApiResponse)
def delete_attendance(log_id: str, user: dict = Depends(get_current_user)):
    if not _is_teacher_admin(str(user.get("role") or "")):
        raise HTTPException(status_code=403, detail="Only teachers/admins can delete attendance")
    _require_attendance_manager(log_id, user)
    deleted = repo.delete_attendance(log_id)
    return ApiResponse(success=deleted, message="Deleted" if deleted else "Not found")


@router.get("/attendance/stats/{group_id}/{user_id}", response_model=ApiResponse)
def get_attendance_stats(
    group_id: str,
    user_id: str,
    days: int = Query(default=30, ge=1, le=365),
    user: dict = Depends(get_current_user),
):
    if str(user.get("user_id") or "") != user_id:
        _require_group_manager(user, group_id)
    else:
        _require_group_member(user, group_id)
    data = repo.get_attendance_stats(user_id, group_id, days=days)
    return ApiResponse(data=data)


# ---------------------------------------------------------------------------
# TuitionPayment
# ---------------------------------------------------------------------------

class TuitionCreate(BaseModel):
    academy_id: str
    user_id: str
    amount: int = Field(..., ge=0)
    month_label: str  # YYYY-MM
    method: Optional[str] = None
    receipt_url: Optional[str] = None
    memo: Optional[str] = None


class TuitionUpdate(BaseModel):
    amount: Optional[int] = None
    method: Optional[str] = None
    receipt_url: Optional[str] = None
    memo: Optional[str] = None


@router.post("/tuition", response_model=ApiResponse)
def create_tuition_payment(body: TuitionCreate, user: dict = Depends(get_current_user)):
    if not _is_teacher_admin(str(user.get("role") or "")):
        raise HTTPException(status_code=403, detail="Only teachers/admins can record tuition")
    _require_academy_manager(user, body.academy_id)
    _require_academy_student(body.academy_id, body.user_id)
    data = repo.create_tuition_payment(
        academy_id=body.academy_id,
        user_id=body.user_id,
        amount=body.amount,
        month_label=body.month_label,
        method=body.method,
        receipt_url=body.receipt_url,
        memo=body.memo,
    )
    return ApiResponse(data=data)


@router.get("/tuition", response_model=ApiResponse)
def list_tuition_payments(
    academy_id: Optional[str] = None,
    user_id: Optional[str] = None,
    month_label: Optional[str] = None,
    user: dict = Depends(get_current_user),
):
    caller_user_id = str(user.get("user_id") or "")
    if _is_admin_user(user):
        data = repo.list_tuition_payments(academy_id=academy_id, user_id=user_id, month_label=month_label)
    elif _is_teacher_admin(str(user.get("role") or "")):
        data = repo.list_tuition_payments_for_teacher(
            teacher_user_id=caller_user_id,
            academy_id=academy_id,
            user_id=user_id,
            month_label=month_label,
        )
    else:
        if user_id and user_id != caller_user_id:
            raise HTTPException(status_code=403, detail="Can only view your own tuition")
        data = repo.list_tuition_payments(
            academy_id=academy_id,
            user_id=caller_user_id,
            month_label=month_label,
        )
    return ApiResponse(data={"items": data})


@router.get("/tuition/summary/{academy_id}", response_model=ApiResponse)
def get_tuition_summary(
    academy_id: str,
    month_label: str,
    user: dict = Depends(get_current_user),
):
    if not _is_teacher_admin(str(user.get("role") or "")):
        raise HTTPException(status_code=403, detail="Only teachers/admins can view tuition summary")
    _require_academy_manager(user, academy_id)
    data = repo.get_tuition_summary(academy_id, month_label)
    return ApiResponse(data=data)


@router.put("/tuition/{payment_id}", response_model=ApiResponse)
def update_tuition_payment(payment_id: str, body: TuitionUpdate, user: dict = Depends(get_current_user)):
    if not _is_teacher_admin(str(user.get("role") or "")):
        raise HTTPException(status_code=403, detail="Only teachers/admins can update tuition")
    _require_tuition_manager(payment_id, user)
    data = repo.update_tuition_payment(
        payment_id,
        amount=body.amount,
        method=body.method,
        receipt_url=body.receipt_url,
        memo=body.memo,
    )
    return ApiResponse(data=data)


@router.delete("/tuition/{payment_id}", response_model=ApiResponse)
def delete_tuition_payment(payment_id: str, user: dict = Depends(get_current_user)):
    if not _is_teacher_admin(str(user.get("role") or "")):
        raise HTTPException(status_code=403, detail="Only teachers/admins can delete tuition")
    _require_tuition_manager(payment_id, user)
    deleted = repo.delete_tuition_payment(payment_id)
    return ApiResponse(success=deleted, message="Deleted" if deleted else "Not found")


# ---------------------------------------------------------------------------
# FinanceLedger
# ---------------------------------------------------------------------------

class LedgerCreate(BaseModel):
    academy_id: str
    category: str = Field(..., pattern=r"^(income|expense)$")
    amount: int = Field(..., ge=0)
    description: Optional[str] = None
    transaction_date: str  # YYYY-MM-DD


class LedgerUpdate(BaseModel):
    category: Optional[str] = None
    amount: Optional[int] = None
    description: Optional[str] = None
    transaction_date: Optional[str] = None


@router.post("/ledger", response_model=ApiResponse)
def create_ledger_entry(body: LedgerCreate, user: dict = Depends(get_current_user)):
    if not _is_teacher_admin(str(user.get("role") or "")):
        raise HTTPException(status_code=403, detail="Only teachers/admins can record ledger entries")
    _require_academy_manager(user, body.academy_id)
    data = repo.create_ledger_entry(
        academy_id=body.academy_id,
        category=body.category,
        amount=body.amount,
        description=body.description,
        transaction_date=body.transaction_date,
        recorded_by_user_id=user.get("user_id"),
    )
    return ApiResponse(data=data)


@router.get("/ledger", response_model=ApiResponse)
def list_ledger_entries(
    academy_id: Optional[str] = None,
    category: Optional[str] = None,
    transaction_date_from: Optional[str] = None,
    transaction_date_to: Optional[str] = None,
    user: dict = Depends(get_current_user),
):
    if not _is_teacher_admin(str(user.get("role") or "")):
        raise HTTPException(status_code=403, detail="Only teachers/admins can view ledger entries")
    if _is_admin_user(user):
        data = repo.list_ledger_entries(
            academy_id=academy_id,
            category=category,
            transaction_date_from=transaction_date_from,
            transaction_date_to=transaction_date_to,
        )
    else:
        data = repo.list_ledger_entries_for_teacher(
            teacher_user_id=str(user.get("user_id") or ""),
            academy_id=academy_id,
            category=category,
            transaction_date_from=transaction_date_from,
            transaction_date_to=transaction_date_to,
        )
    return ApiResponse(data={"items": data})


@router.get("/ledger/summary/{academy_id}", response_model=ApiResponse)
def get_ledger_summary(
    academy_id: str,
    transaction_date_from: Optional[str] = None,
    transaction_date_to: Optional[str] = None,
    user: dict = Depends(get_current_user),
):
    if not _is_teacher_admin(str(user.get("role") or "")):
        raise HTTPException(status_code=403, detail="Only teachers/admins can view ledger summary")
    _require_academy_manager(user, academy_id)
    data = repo.get_ledger_summary(academy_id, transaction_date_from, transaction_date_to)
    return ApiResponse(data=data)


@router.put("/ledger/{ledger_id}", response_model=ApiResponse)
def update_ledger_entry(ledger_id: str, body: LedgerUpdate, user: dict = Depends(get_current_user)):
    if not _is_teacher_admin(str(user.get("role") or "")):
        raise HTTPException(status_code=403, detail="Only teachers/admins can update ledger")
    _require_ledger_manager(ledger_id, user)
    data = repo.update_ledger_entry(
        ledger_id,
        category=body.category,
        amount=body.amount,
        description=body.description,
        transaction_date=body.transaction_date,
    )
    return ApiResponse(data=data)


@router.delete("/ledger/{ledger_id}", response_model=ApiResponse)
def delete_ledger_entry(ledger_id: str, user: dict = Depends(get_current_user)):
    if not _is_teacher_admin(str(user.get("role") or "")):
        raise HTTPException(status_code=403, detail="Only teachers/admins can delete ledger entries")
    _require_ledger_manager(ledger_id, user)
    deleted = repo.delete_ledger_entry(ledger_id)
    return ApiResponse(success=deleted, message="Deleted" if deleted else "Not found")


# ---------------------------------------------------------------------------
# ParentConsultNote
# ---------------------------------------------------------------------------

class ConsultCreate(BaseModel):
    academy_id: str
    student_user_id: str
    parent_name: Optional[str] = None
    parent_contact: Optional[str] = None
    topic: Optional[str] = None
    content: Optional[str] = None
    follow_up_date: Optional[str] = None


class ConsultUpdate(BaseModel):
    parent_name: Optional[str] = None
    parent_contact: Optional[str] = None
    topic: Optional[str] = None
    content: Optional[str] = None
    follow_up_date: Optional[str] = None


@router.post("/consult", response_model=ApiResponse)
def create_consult_note(body: ConsultCreate, user: dict = Depends(get_current_user)):
    if not _is_teacher_admin(str(user.get("role") or "")):
        raise HTTPException(status_code=403, detail="Only teachers/admins can create consult notes")
    _require_academy_manager(user, body.academy_id)
    _require_academy_student(body.academy_id, body.student_user_id)
    data = repo.create_consult_note(
        academy_id=body.academy_id,
        student_user_id=body.student_user_id,
        parent_name=body.parent_name,
        parent_contact=body.parent_contact,
        topic=body.topic,
        content=body.content,
        consulted_by_user_id=user.get("user_id"),
        follow_up_date=body.follow_up_date,
    )
    return ApiResponse(data=data)


@router.get("/consult", response_model=ApiResponse)
def list_consult_notes(
    academy_id: Optional[str] = None,
    student_user_id: Optional[str] = None,
    user: dict = Depends(get_current_user),
):
    if not _is_teacher_admin(str(user.get("role") or "")):
        raise HTTPException(status_code=403, detail="Only teachers/admins can view consult notes")
    if _is_admin_user(user):
        data = repo.list_consult_notes(academy_id=academy_id, student_user_id=student_user_id)
    else:
        data = repo.list_consult_notes_for_teacher(
            teacher_user_id=str(user.get("user_id") or ""),
            academy_id=academy_id,
            student_user_id=student_user_id,
        )
    return ApiResponse(data={"items": data})


@router.put("/consult/{note_id}", response_model=ApiResponse)
def update_consult_note(note_id: str, body: ConsultUpdate, user: dict = Depends(get_current_user)):
    if not _is_teacher_admin(str(user.get("role") or "")):
        raise HTTPException(status_code=403, detail="Only teachers/admins can update consult notes")
    _require_consult_manager(note_id, user)
    data = repo.update_consult_note(
        note_id,
        parent_name=body.parent_name,
        parent_contact=body.parent_contact,
        topic=body.topic,
        content=body.content,
        follow_up_date=body.follow_up_date,
    )
    return ApiResponse(data=data)


@router.delete("/consult/{note_id}", response_model=ApiResponse)
def delete_consult_note(note_id: str, user: dict = Depends(get_current_user)):
    if not _is_teacher_admin(str(user.get("role") or "")):
        raise HTTPException(status_code=403, detail="Only teachers/admins can delete consult notes")
    _require_consult_manager(note_id, user)
    deleted = repo.delete_consult_note(note_id)
    return ApiResponse(success=deleted, message="Deleted" if deleted else "Not found")


# ---------------------------------------------------------------------------
# GroupAssignment
# ---------------------------------------------------------------------------

class AssignmentCreate(BaseModel):
    group_id: str
    kind: str = Field(..., pattern=r"^(exam|problem|course|homework)$")
    ref_id: str
    title: Optional[str] = None
    message: Optional[str] = None
    due_date: Optional[str] = None  # YYYY-MM-DD
    target_user_ids: Optional[List[str]] = None
    chat_mode: str = Field(default="auto", pattern=r"^(auto|group|direct)$")


class AssignmentUpdate(BaseModel):
    title: Optional[str] = None
    message: Optional[str] = None
    due_date: Optional[str] = None


class StudentScheduleSync(BaseModel):
    tasks_by_date: dict[str, List[str]] = Field(default_factory=dict)


@router.post("/assignments", response_model=ApiResponse)
def create_assignment(body: AssignmentCreate, user: dict = Depends(get_current_user)):
    if not _is_teacher_admin(str(user.get("role") or "")):
        raise HTTPException(status_code=403, detail="Only teachers/admins can create assignments")
    _require_group_manager(user, body.group_id)
    if body.kind == "course":
        _validate_course_assignment_scope(
            course_id=body.ref_id,
            group_id=body.group_id,
            user=user,
        )
        _validate_course_due_date(body.ref_id, body.due_date)
    data = repo.create_assignment(
        group_id=body.group_id,
        sender_user_id=user.get("user_id"),
        kind=body.kind,
        ref_id=body.ref_id,
        title=body.title,
        message=body.message,
        due_date=body.due_date,
        target_user_ids=body.target_user_ids,
    )
    target_user_ids = data.get("target_user_ids") or []
    if body.kind == "course":
        _enroll_course_v2_for_students(body.ref_id, target_user_ids)
    title = body.title or ("코스" if body.kind == "course" else "숙제")
    notice = body.message or f"{title} 배정이 도착했습니다."
    delivery_errors = _send_assignment_notice(
        sender_user_id=user.get("user_id"),
        group_id=body.group_id,
        target_user_ids=target_user_ids,
        chat_mode=body.chat_mode,
        text=notice,
    )
    if delivery_errors:
        data["delivery_errors"] = delivery_errors
    return ApiResponse(data=data)


@router.get("/assignments", response_model=ApiResponse)
def list_assignments(
    group_id: Optional[str] = None,
    kind: Optional[str] = None,
    user: dict = Depends(get_current_user),
):
    if not _is_teacher_admin(str(user.get("role") or "")):
        raise HTTPException(status_code=403, detail="Use the personal assignment list")
    if _is_admin_user(user):
        data = repo.list_assignments(group_id=group_id, kind=kind)
    else:
        data = repo.list_assignments_for_teacher(
            user_id=str(user.get("user_id") or ""),
            group_id=group_id,
            kind=kind,
        )
    return ApiResponse(data={"items": data})


@router.get("/assignments/my", response_model=ApiResponse)
def list_my_assignments(
    kind: Optional[str] = None,
    user: dict = Depends(get_current_user),
):
    data = repo.list_my_assignments(user_id=user.get("user_id"), kind=kind)
    return ApiResponse(data={"items": data})


@router.patch("/assignments/{assignment_id}", response_model=ApiResponse)
def update_assignment(
    assignment_id: str,
    body: AssignmentUpdate,
    user: dict = Depends(get_current_user),
):
    if not _is_teacher_admin(str(user.get("role") or "")):
        raise HTTPException(status_code=403, detail="Only teachers/admins can update assignments")
    current = _require_assignment_manager(assignment_id, user)
    if current.get("kind") == "course" and body.due_date is not None:
        _validate_course_due_date(current.get("ref_id"), body.due_date)
    data = repo.update_assignment(
        assignment_id,
        title=body.title,
        message=body.message,
        due_date=body.due_date,
    )
    if not data:
        raise HTTPException(status_code=404, detail="Assignment not found")
    return ApiResponse(data=data)


@router.delete("/assignments/{assignment_id}", response_model=ApiResponse)
def delete_assignment(assignment_id: str, user: dict = Depends(get_current_user)):
    if not _is_teacher_admin(str(user.get("role") or "")):
        raise HTTPException(status_code=403, detail="Only teachers/admins can delete assignments")
    _require_assignment_manager(assignment_id, user)
    deleted = repo.delete_assignment(assignment_id)
    return ApiResponse(success=deleted, message="Deleted" if deleted else "Not found")


@router.get("/analysis/students/{student_user_id}", response_model=ApiResponse)
def get_student_analysis(student_user_id: str, user: dict = Depends(get_current_user)):
    if user.get("role") not in ("teacher", "admin"):
        if user.get("user_id") != student_user_id:
            raise HTTPException(status_code=403, detail="Can only view your own analysis")
    data = _build_student_analysis(student_user_id)
    return ApiResponse(data=data)


@router.put("/students/me/schedule", response_model=ApiResponse)
def sync_my_student_schedule(
    body: StudentScheduleSync,
    user: dict = Depends(get_current_user),
):
    items = repo.replace_student_schedule_tasks(
        user_id=user.get("user_id"),
        tasks_by_date=body.tasks_by_date,
        source="student",
    )
    return ApiResponse(data={"items": items})


# ---------------------------------------------------------------------------
# GroupSubmission
# ---------------------------------------------------------------------------

class SubmissionUpdate(BaseModel):
    status: Optional[str] = None
    data_json: Optional[str] = None


@router.get("/submissions", response_model=ApiResponse)
def list_submissions(
    assignment_id: Optional[str] = None,
    user_id: Optional[str] = None,
    status: Optional[str] = None,
    user: dict = Depends(get_current_user),
):
    caller_user_id = str(user.get("user_id") or "")
    if _is_admin_user(user):
        data = repo.list_submissions(assignment_id=assignment_id, user_id=user_id, status=status)
    elif _is_teacher_admin(str(user.get("role") or "")):
        if assignment_id:
            _require_assignment_manager(assignment_id, user)
        data = repo.list_submissions_for_teacher(
            teacher_user_id=caller_user_id,
            assignment_id=assignment_id,
            user_id=user_id,
            status=status,
        )
    else:
        if user_id and user_id != caller_user_id:
            raise HTTPException(status_code=403, detail="Can only view your own submissions")
        data = repo.list_submissions(
            assignment_id=assignment_id,
            user_id=caller_user_id,
            status=status,
        )
    return ApiResponse(data={"items": data})


@router.post("/submissions/{submission_id}/submit", response_model=ApiResponse)
def submit_submission(submission_id: str, body: SubmissionUpdate, user: dict = Depends(get_current_user)):
    """Student submits their work."""
    submission = repo.get_submission(submission_id)
    if not submission:
        raise HTTPException(status_code=404, detail="Submission not found")
    if submission.get("user_id") != user.get("user_id"):
        raise HTTPException(status_code=403, detail="Can only submit your own work")

    data = repo.update_submission_status(
        submission_id,
        status=body.status or "submitted",
        data_json=body.data_json,
    )
    return ApiResponse(data=data)


# ---------------------------------------------------------------------------
# SubmissionReport
# ---------------------------------------------------------------------------

class ReportCreate(BaseModel):
    submission_id: str
    correct_rate: Optional[float] = None
    time_spent_seconds: Optional[int] = None
    weak_tags: Optional[List[str]] = None
    feedback: Optional[str] = None


@router.post("/reports", response_model=ApiResponse)
def create_submission_report(body: ReportCreate, user: dict = Depends(get_current_user)):
    if not _is_teacher_admin(str(user.get("role") or "")):
        raise HTTPException(status_code=403, detail="Only teachers/admins can create reports")
    _submission, assignment = _get_submission_and_assignment(body.submission_id)
    _require_group_manager(user, str(assignment.get("group_id") or ""))
    data = repo.create_submission_report(
        submission_id=body.submission_id,
        correct_rate=body.correct_rate,
        time_spent_seconds=body.time_spent_seconds,
        weak_tags=body.weak_tags,
        feedback=body.feedback,
    )
    return ApiResponse(data=data)


@router.get("/reports/{report_id}", response_model=ApiResponse)
def get_submission_report(report_id: str, user: dict = Depends(get_current_user)):
    data = repo.get_submission_report(report_id)
    if not data:
        raise HTTPException(status_code=404, detail="Report not found")
    submission, assignment = _get_submission_and_assignment(str(data.get("submission_id") or ""))
    _ensure_submission_access(user, submission, assignment)
    return ApiResponse(data=data)


@router.get("/submissions/{submission_id}/report", response_model=ApiResponse)
def get_report_by_submission(submission_id: str, user: dict = Depends(get_current_user)):
    submission, assignment = _get_submission_and_assignment(submission_id)
    _ensure_submission_access(user, submission, assignment)
    data = repo.get_report_by_submission(submission_id)
    if not data:
        raise HTTPException(status_code=404, detail="Report not found")
    return ApiResponse(data=data)


# ---------------------------------------------------------------------------
# TimetablePreference
# ---------------------------------------------------------------------------

class TimetablePreferenceCreate(BaseModel):
    group_id: str
    day_of_week: str = Field(..., pattern=r"^(mon|tue|wed|thu|fri|sat|sun)$")
    time_slot: str  # HH:MM-HH:MM
    priority: int = Field(default=1, ge=1, le=5)


@router.post("/timetable/preferences", response_model=ApiResponse)
def create_timetable_preference(body: TimetablePreferenceCreate, user: dict = Depends(get_current_user)):
    _require_group_member(user, body.group_id)
    data = repo.create_timetable_preference(
        group_id=body.group_id,
        user_id=user.get("user_id"),
        day_of_week=body.day_of_week,
        time_slot=body.time_slot,
        priority=body.priority,
    )
    return ApiResponse(data=data)


@router.get("/timetable/preferences", response_model=ApiResponse)
def list_timetable_preferences(
    group_id: Optional[str] = None,
    user_id: Optional[str] = None,
    user: dict = Depends(get_current_user),
):
    caller_user_id = str(user.get("user_id") or "")
    if group_id:
        _require_group_member(user, group_id)
        if user_id and user_id != caller_user_id and not _can_manage_group(user, group_id):
            raise HTTPException(status_code=403, detail="Can only view your own preferences")
        data = repo.list_timetable_preferences(group_id=group_id, user_id=user_id)
    elif _is_admin_user(user):
        data = repo.list_timetable_preferences(group_id=group_id, user_id=user_id)
    else:
        if user_id and user_id != caller_user_id:
            raise HTTPException(status_code=403, detail="Can only view your own preferences")
        data = repo.list_timetable_preferences(user_id=caller_user_id)
    return ApiResponse(data={"items": data})


@router.delete("/timetable/preferences/{preference_id}", response_model=ApiResponse)
def delete_timetable_preference(preference_id: str, user: dict = Depends(get_current_user)):
    preference = repo.get_timetable_preference(preference_id)
    if not preference:
        raise HTTPException(status_code=404, detail="Preference not found")
    if str(preference.get("user_id") or "") != str(user.get("user_id") or ""):
        _require_group_manager(user, str(preference.get("group_id") or ""))
    deleted = repo.delete_timetable_preference(preference_id)
    return ApiResponse(success=deleted, message="Deleted" if deleted else "Not found")


# ---------------------------------------------------------------------------
# TimetablePlan
# ---------------------------------------------------------------------------

@router.post("/timetable/generate/{group_id}", response_model=ApiResponse)
def generate_timetable(group_id: str, user: dict = Depends(get_current_user)):
    if not _is_teacher_admin(str(user.get("role") or "")):
        raise HTTPException(status_code=403, detail="Only teachers/admins can generate timetables")
    _require_group_manager(user, group_id)
    data = repo.generate_timetable_heuristic_v1(group_id)
    return ApiResponse(data=data)


@router.get("/timetable/plans/{group_id}", response_model=ApiResponse)
def list_timetable_plans(group_id: str, user: dict = Depends(get_current_user)):
    _require_group_member(user, group_id)
    data = repo.list_timetable_plans(group_id)
    return ApiResponse(data={"items": data})


@router.post("/timetable/plans/{plan_id}/apply", response_model=ApiResponse)
def apply_timetable_plan(plan_id: str, user: dict = Depends(get_current_user)):
    if not _is_teacher_admin(str(user.get("role") or "")):
        raise HTTPException(status_code=403, detail="Only teachers/admins can apply timetable plans")
    plan = repo.get_timetable_plan(plan_id)
    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found")
    _require_group_manager(user, str(plan.get("group_id") or ""))
    data = repo.apply_timetable_plan(plan_id)
    if not data:
        raise HTTPException(status_code=404, detail="Plan not found")
    return ApiResponse(data=data)


# ---------------------------------------------------------------------------
# StudentOverviewSnapshot
# ---------------------------------------------------------------------------

class SnapshotCreate(BaseModel):
    user_id: str
    academy_id: str
    group_id: Optional[str] = None
    overall_score: Optional[float] = None
    attendance_rate: Optional[float] = None
    tuition_status: Optional[str] = None
    last_consult_note_id: Optional[str] = None
    summary_json: Optional[str] = None


@router.post("/snapshots", response_model=ApiResponse)
def create_snapshot(body: SnapshotCreate, user: dict = Depends(get_current_user)):
    if user.get("role") not in ("teacher", "admin"):
        raise HTTPException(status_code=403, detail="Only teachers/admins can create snapshots")
    _ensure_friend_access_or_403(user.get("user_id"), body.user_id)
    data = repo.create_snapshot(
        user_id=body.user_id,
        academy_id=body.academy_id,
        group_id=body.group_id,
        overall_score=body.overall_score,
        attendance_rate=body.attendance_rate,
        tuition_status=body.tuition_status,
        last_consult_note_id=body.last_consult_note_id,
        summary_json=body.summary_json,
    )
    return ApiResponse(data=data)


@router.post("/snapshots/build/{user_id}", response_model=ApiResponse)
def build_student_overview(
    user_id: str,
    academy_id: str,
    group_id: Optional[str] = None,
    user: dict = Depends(get_current_user),
):
    """Auto-build a comprehensive student overview from multiple data sources."""
    if user.get("role") not in ("teacher", "admin"):
        raise HTTPException(status_code=403, detail="Only teachers/admins can build snapshots")
    _ensure_friend_access_or_403(user.get("user_id"), user_id)
    data = repo.build_student_overview(user_id=user_id, academy_id=academy_id, group_id=group_id)
    return ApiResponse(data=data)


@router.get("/snapshots", response_model=ApiResponse)
def list_snapshots(
    user_id: Optional[str] = None,
    academy_id: Optional[str] = None,
    group_id: Optional[str] = None,
    limit: int = Query(default=50, le=200),
    user: dict = Depends(get_current_user),
):
    caller_user_id = user.get("user_id")
    if user_id:
        _ensure_friend_access_or_403(caller_user_id, user_id)
    data = repo.list_snapshots(user_id=user_id, academy_id=academy_id, group_id=group_id, limit=limit)
    if not user_id:
        data = [
            row
            for row in data
            if row.get("user_id") == caller_user_id or are_friends(caller_user_id, row.get("user_id"))
        ]
    return ApiResponse(data={"items": data})


@router.get("/snapshots/{snapshot_id}", response_model=ApiResponse)
def get_snapshot(snapshot_id: str, user: dict = Depends(get_current_user)):
    data = repo.get_snapshot(snapshot_id)
    if not data:
        raise HTTPException(status_code=404, detail="Snapshot not found")
    _ensure_friend_access_or_403(user.get("user_id"), data.get("user_id"))
    return ApiResponse(data=data)


@router.delete("/snapshots/{snapshot_id}", response_model=ApiResponse)
def delete_snapshot(snapshot_id: str, user: dict = Depends(get_current_user)):
    if user.get("role") not in ("teacher", "admin"):
        raise HTTPException(status_code=403, detail="Only teachers/admins can delete snapshots")
    deleted = repo.delete_snapshot(snapshot_id)
    return ApiResponse(success=deleted, message="Deleted" if deleted else "Not found")


@router.get("/{academy_id}", response_model=ApiResponse)
def get_academy(academy_id: str, user: dict = Depends(get_current_user)):
    data = repo.get_academy(academy_id)
    if not data:
        raise HTTPException(status_code=404, detail="Academy not found")
    return ApiResponse(data=data)


@router.put("/{academy_id}", response_model=ApiResponse)
def update_academy(academy_id: str, body: AcademyUpdate, user: dict = Depends(get_current_user)):
    if not _is_teacher_admin(str(user.get("role") or "")):
        raise HTTPException(status_code=403, detail="Only teachers/admins can update academies")
    _require_academy_manager(user, academy_id)
    data = repo.update_academy(
        academy_id,
        name=body.name,
        address=body.address,
        phone=body.phone,
        admin_user_id=body.admin_user_id,
    )
    return ApiResponse(data=data)


@router.delete("/{academy_id}", response_model=ApiResponse)
def delete_academy(academy_id: str, user: dict = Depends(get_current_user)):
    if not _is_teacher_admin(str(user.get("role") or "")):
        raise HTTPException(status_code=403, detail="Only teachers/admins can delete academies")
    _require_academy_manager(user, academy_id)
    deleted = repo.delete_academy(academy_id)
    return ApiResponse(success=deleted, message="Deleted" if deleted else "Not found")
