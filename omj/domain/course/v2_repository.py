"""PostgreSQL-backed repository for Course V2.

Provides:
- _ensure_course_v2_tables: idempotent schema init for course_v2 table
- create_course_v2, get_course_v2, update_course_v2, delete_course_v2
- list_courses_v2
"""
from __future__ import annotations

import json
from infra.db import postgres_compat as db
import uuid
from typing import Any, Optional

from domain.course.v2_models import (
    ChallengePolicy,
    CourseModule,
    CourseV2,
    FlowPolicy,
    PassPolicy,
    RuntimeFlags,
    SchedulePolicy,
)


def _ensure_course_v2_tables() -> None:
    """Create the course_v2 table if it does not exist."""
    with db.connect() as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS course_v2 (
                id TEXT PRIMARY KEY,
                owner_user_id TEXT NOT NULL DEFAULT '',
                access_academy_id TEXT,
                access_group_id TEXT,
                title TEXT NOT NULL,
                description TEXT NOT NULL DEFAULT '',
                difficulty TEXT NOT NULL DEFAULT '',
                duration TEXT NOT NULL DEFAULT '',
                tags TEXT NOT NULL DEFAULT '[]',
                focus_tags TEXT NOT NULL DEFAULT '[]',
                target_ovr INTEGER DEFAULT 0,
                textbook_id TEXT,
                textbook_pages INTEGER DEFAULT 0,
                is_demo INTEGER NOT NULL DEFAULT 0,
                is_public INTEGER NOT NULL DEFAULT 0,
                modules_json TEXT NOT NULL DEFAULT '[]',
                pass_policy_json TEXT,
                flow_policy_json TEXT,
                challenge_policy_json TEXT,
                schedule_policy_json TEXT,
                runtime_flags_json TEXT,
                curriculum_settings_json TEXT,
                challenge_settings_json TEXT,
                created_at INTEGER DEFAULT (strftime('%s','now')),
                updated_at INTEGER DEFAULT (strftime('%s','now'))
            )
            """
        )
        try:
            conn.execute("ALTER TABLE course_v2 ADD COLUMN IF NOT EXISTS curriculum_settings_json TEXT")
        except db.OperationalError:
            pass
        try:
            conn.execute("ALTER TABLE course_v2 ADD COLUMN IF NOT EXISTS challenge_settings_json TEXT")
        except db.OperationalError:
            pass
        try:
            conn.execute("ALTER TABLE course_v2 ADD COLUMN IF NOT EXISTS owner_user_id TEXT NOT NULL DEFAULT ''")
        except db.OperationalError:
            pass
        try:
            conn.execute("ALTER TABLE course_v2 ADD COLUMN IF NOT EXISTS is_public INTEGER NOT NULL DEFAULT 0")
        except db.OperationalError:
            pass
        try:
            conn.execute("ALTER TABLE course_v2 ADD COLUMN IF NOT EXISTS access_academy_id TEXT")
        except db.OperationalError:
            pass
        try:
            conn.execute("ALTER TABLE course_v2 ADD COLUMN IF NOT EXISTS access_group_id TEXT")
        except db.OperationalError:
            pass
        conn.commit()

        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS course_v2_runtime (
                user_id TEXT NOT NULL,
                course_id TEXT NOT NULL,
                state_json TEXT NOT NULL DEFAULT '{}',
                created_at INTEGER DEFAULT (strftime('%s','now')),
                updated_at INTEGER DEFAULT (strftime('%s','now')),
                PRIMARY KEY (user_id, course_id)
            )
            """
        )
        conn.commit()


def _serialize_course(course: CourseV2) -> dict[str, Any]:
    """필요 변수: CourseV2 모델. 작동 원리: PostgreSQL 저장용 평면 딕셔너리로 직렬화한다."""
    return {
        "id": course.id,
        "owner_user_id": course.owner_user_id or "",
        "access_academy_id": course.access_academy_id,
        "access_group_id": course.access_group_id,
        "title": course.title,
        "description": course.description,
        "difficulty": course.difficulty,
        "duration": course.duration,
        "tags": json.dumps(course.tags, ensure_ascii=False),
        "focus_tags": json.dumps(course.focus_tags, ensure_ascii=False),
        "target_ovr": course.target_ovr,
        "textbook_id": course.textbook_id,
        "textbook_pages": course.textbook_pages,
        "is_demo": 1 if course.is_demo else 0,
        "is_public": 1 if course.is_public else 0,
        "modules_json": json.dumps(
            [m.model_dump(mode="json") for m in course.modules],
            ensure_ascii=False,
        ),
        "pass_policy_json": (
            json.dumps(course.pass_policy.model_dump(mode="json"), ensure_ascii=False)
            if course.pass_policy
            else None
        ),
        "flow_policy_json": (
            json.dumps(course.flow_policy.model_dump(mode="json"), ensure_ascii=False)
            if course.flow_policy
            else None
        ),
        "challenge_policy_json": (
            json.dumps(course.challenge_policy.model_dump(mode="json"), ensure_ascii=False)
            if course.challenge_policy
            else None
        ),
        "schedule_policy_json": (
            json.dumps(course.schedule_policy.model_dump(mode="json"), ensure_ascii=False)
            if course.schedule_policy
            else None
        ),
        "runtime_flags_json": (
            json.dumps(course.runtime_flags.model_dump(mode="json"), ensure_ascii=False)
            if course.runtime_flags
            else None
        ),
        "curriculum_settings_json": json.dumps(
            course.curriculum_settings or {},
            ensure_ascii=False,
        ),
        "challenge_settings_json": json.dumps(
            course.challenge_settings or {},
            ensure_ascii=False,
        ),
        "created_at": course.created_at,
        "updated_at": course.updated_at,
    }


def _row_to_course(row: db.Row) -> CourseV2:
    """Convert a db.Row into a CourseV2 instance."""
    data: dict[str, Any] = dict(row)

    # Parse list fields
    data["tags"] = json.loads(data.get("tags", "[]") or "[]")
    data["focus_tags"] = json.loads(data.get("focus_tags", "[]") or "[]")

    # Parse modules
    modules_raw = json.loads(data.get("modules_json", "[]") or "[]")
    data["modules"] = [CourseModule.model_validate(m) for m in modules_raw]

    # Parse policy JSON blobs
    for key, cls in (
        ("pass_policy_json", PassPolicy),
        ("flow_policy_json", FlowPolicy),
        ("challenge_policy_json", ChallengePolicy),
        ("schedule_policy_json", SchedulePolicy),
        ("runtime_flags_json", RuntimeFlags),
    ):
        json_str = data.pop(key, None)
        field_name = key.replace("_json", "")
        if json_str:
            data[field_name] = cls.model_validate(json.loads(json_str))
        else:
            data[field_name] = cls()

    curriculum_raw = data.pop("curriculum_settings_json", None)
    challenge_raw = data.pop("challenge_settings_json", None)
    data["curriculum_settings"] = json.loads(curriculum_raw) if curriculum_raw else {}
    data["challenge_settings"] = json.loads(challenge_raw) if challenge_raw else {}

    data["is_demo"] = bool(data.get("is_demo", 0))
    data["is_public"] = bool(data.get("is_public", 0))

    return CourseV2.model_validate(data)


def _normalize_sort(sort: Optional[str], order: Optional[str]) -> tuple[str, str]:
    sort_key = (sort or "updated_at").strip().lower()
    order_key = (order or "desc").strip().lower()
    if sort_key not in {"updated_at", "created_at", "title", "target_ovr", "difficulty"}:
        sort_key = "updated_at"
    if order_key not in {"asc", "desc"}:
        order_key = "desc"
    return sort_key, order_key


def _build_filters(
    *,
    query: Optional[str] = None,
    tag: Optional[str] = None,
    owner_user_id: Optional[str] = None,
    is_public: Optional[bool] = None,
) -> tuple[list[str], list[Any]]:
    clauses: list[str] = []
    params: list[Any] = []

    q_norm = (query or "").strip().lower()
    if q_norm:
        clauses.append("(LOWER(title) LIKE ? OR LOWER(description) LIKE ?)")
        like = f"%{q_norm}%"
        params.extend([like, like])

    tag_norm = (tag or "").strip().lower()
    if tag_norm:
        clauses.append("(LOWER(tags) LIKE ? OR LOWER(focus_tags) LIKE ?)")
        like = f"%{tag_norm}%"
        params.extend([like, like])

    if owner_user_id is not None:
        clauses.append("owner_user_id = ?")
        params.append(owner_user_id)

    if is_public is not None:
        clauses.append("is_public = ?")
        params.append(1 if is_public else 0)

    return clauses, params


# ---------------------------------------------------------------------------
# CRUD
# ---------------------------------------------------------------------------


def create_course_v2(course: CourseV2) -> str:
    """Insert a new CourseV2. Returns the course id."""
    _ensure_course_v2_tables()
    if not (course.id or "").strip():
        course.id = f"course_{uuid.uuid4().hex[:12]}"
    payload = _serialize_course(course)
    # Override timestamps on creation
    import time

    now = int(time.time())
    payload["created_at"] = course.created_at or now
    payload["updated_at"] = course.updated_at or now

    with db.connect() as conn:
        conn.execute(
            """
            INSERT INTO course_v2 (
                id, owner_user_id, access_academy_id, access_group_id, title, description, difficulty, duration,
                tags, focus_tags, target_ovr, textbook_id, textbook_pages,
                is_demo, is_public, modules_json, pass_policy_json, flow_policy_json,
                challenge_policy_json, schedule_policy_json, runtime_flags_json,
                curriculum_settings_json, challenge_settings_json,
                created_at, updated_at
            )
            VALUES (
                :id, :owner_user_id, :access_academy_id, :access_group_id, :title, :description, :difficulty, :duration,
                :tags, :focus_tags, :target_ovr, :textbook_id, :textbook_pages,
                :is_demo, :is_public, :modules_json, :pass_policy_json, :flow_policy_json,
                :challenge_policy_json, :schedule_policy_json, :runtime_flags_json,
                :curriculum_settings_json, :challenge_settings_json,
                :created_at, :updated_at
            )
            """,
            payload,
        )
        conn.commit()
    return course.id


def get_course_v2(course_id: str) -> Optional[CourseV2]:
    """Fetch a single CourseV2 by id."""
    _ensure_course_v2_tables()
    with db.connect() as conn:
        conn.row_factory = db.Row
        row = conn.execute(
            "SELECT * FROM course_v2 WHERE id = ?", (course_id,)
        ).fetchone()
        if row is None:
            return None
        return _row_to_course(row)


def update_course_v2(course: CourseV2) -> bool:
    """Upsert a CourseV2. Returns True if a row was updated/inserted."""
    _ensure_course_v2_tables()
    import time

    payload = _serialize_course(course)
    payload["updated_at"] = int(time.time())
    # 필요한 변수는 선택적 course.created_at과 현재 갱신 시각이다.
    # 작동 원리는 신규 UPSERT에서 NOT NULL 생성 시각을 채우고 기존 코스 입력값은 보존하는 것이다.
    payload["created_at"] = course.created_at or payload["updated_at"]

    with db.connect() as conn:
        cur = conn.execute(
            """
            INSERT INTO course_v2 (
                id, owner_user_id, access_academy_id, access_group_id, title, description, difficulty, duration,
                tags, focus_tags, target_ovr, textbook_id, textbook_pages,
                is_demo, is_public, modules_json, pass_policy_json, flow_policy_json,
                challenge_policy_json, schedule_policy_json, runtime_flags_json,
                curriculum_settings_json, challenge_settings_json,
                created_at, updated_at
            )
            VALUES (
                :id, :owner_user_id, :access_academy_id, :access_group_id, :title, :description, :difficulty, :duration,
                :tags, :focus_tags, :target_ovr, :textbook_id, :textbook_pages,
                :is_demo, :is_public, :modules_json, :pass_policy_json, :flow_policy_json,
                :challenge_policy_json, :schedule_policy_json, :runtime_flags_json,
                :curriculum_settings_json, :challenge_settings_json,
                :created_at, :updated_at
            )
            ON CONFLICT(id) DO UPDATE SET
                title = excluded.title,
                owner_user_id = excluded.owner_user_id,
                access_academy_id = excluded.access_academy_id,
                access_group_id = excluded.access_group_id,
                description = excluded.description,
                difficulty = excluded.difficulty,
                duration = excluded.duration,
                tags = excluded.tags,
                focus_tags = excluded.focus_tags,
                target_ovr = excluded.target_ovr,
                textbook_id = excluded.textbook_id,
                textbook_pages = excluded.textbook_pages,
                is_demo = excluded.is_demo,
                is_public = excluded.is_public,
                modules_json = excluded.modules_json,
                pass_policy_json = excluded.pass_policy_json,
                flow_policy_json = excluded.flow_policy_json,
                challenge_policy_json = excluded.challenge_policy_json,
                schedule_policy_json = excluded.schedule_policy_json,
                runtime_flags_json = excluded.runtime_flags_json,
                curriculum_settings_json = excluded.curriculum_settings_json,
                challenge_settings_json = excluded.challenge_settings_json,
                updated_at = excluded.updated_at
            """,
            payload,
        )
        conn.commit()
        return cur.rowcount > 0


def delete_course_v2(course_id: str) -> bool:
    """Delete a CourseV2 by id. Returns True if a row was deleted."""
    _ensure_course_v2_tables()
    with db.connect() as conn:
        conn.execute("DELETE FROM course_v2_runtime WHERE course_id = ?", (course_id,))
        cur = conn.execute("DELETE FROM course_v2 WHERE id = ?", (course_id,))
        conn.commit()
        return cur.rowcount > 0


def list_courses_v2(
    *,
    query: Optional[str] = None,
    tag: Optional[str] = None,
    limit: int = 50,
    offset: int = 0,
    recommend_for_ovr: Optional[int] = None,
    owner_user_id: Optional[str] = None,
    is_public: Optional[bool] = None,
    sort: Optional[str] = None,
    order: Optional[str] = None,
) -> list[CourseV2]:
    """List CourseV2 instances with optional filtering."""
    _ensure_course_v2_tables()
    sort_key, order_key = _normalize_sort(sort, order)
    clauses, params = _build_filters(
        query=query,
        tag=tag,
        owner_user_id=owner_user_id,
        is_public=is_public,
    )
    where_sql = f"WHERE {' AND '.join(clauses)}" if clauses else ""
    order_sql = f"ORDER BY {sort_key} {order_key}, id DESC"
    sql = f"SELECT * FROM course_v2 {where_sql} {order_sql} LIMIT ? OFFSET ?"
    params = list(params)
    params.extend([max(1, limit), max(0, offset)])
    with db.connect() as conn:
        conn.row_factory = db.Row
        rows = conn.execute(sql, params).fetchall()
    results = [_row_to_course(row) for row in rows]

    if recommend_for_ovr is not None:
        results.sort(key=lambda c: abs(c.target_ovr - recommend_for_ovr))

    return results[:limit]


def count_courses_v2(
    *,
    query: Optional[str] = None,
    tag: Optional[str] = None,
    owner_user_id: Optional[str] = None,
    is_public: Optional[bool] = None,
) -> int:
    _ensure_course_v2_tables()
    clauses, params = _build_filters(
        query=query,
        tag=tag,
        owner_user_id=owner_user_id,
        is_public=is_public,
    )
    where_sql = f"WHERE {' AND '.join(clauses)}" if clauses else ""
    sql = f"SELECT COUNT(*) FROM course_v2 {where_sql}"
    with db.connect() as conn:
        row = conn.execute(sql, params).fetchone()
    return int((row or [0])[0])


def count_courses_by_visibility(owner_user_id: str, is_public: bool, *, exclude_course_id: Optional[str] = None) -> int:
    _ensure_course_v2_tables()
    with db.connect() as conn:
        if exclude_course_id:
            row = conn.execute(
                """
                SELECT COUNT(*) FROM course_v2
                WHERE owner_user_id = ? AND is_public = ? AND id != ?
                """,
                (owner_user_id, 1 if is_public else 0, exclude_course_id),
            ).fetchone()
        else:
            row = conn.execute(
                "SELECT COUNT(*) FROM course_v2 WHERE owner_user_id = ? AND is_public = ?",
                (owner_user_id, 1 if is_public else 0),
            ).fetchone()
    return int((row or [0])[0])


def get_runtime_state(user_id: str, course_id: str) -> dict[str, Any]:
    _ensure_course_v2_tables()
    with db.connect() as conn:
        conn.row_factory = db.Row
        row = conn.execute(
            "SELECT state_json FROM course_v2_runtime WHERE user_id = ? AND course_id = ?",
            (user_id, course_id),
        ).fetchone()
    if row is None:
        return {}
    raw = row["state_json"]
    if not raw:
        return {}
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return {}


def list_runtime_states(user_id: str, course_ids: list[str]) -> dict[str, dict[str, Any]]:
    _ensure_course_v2_tables()
    ids = [str(course_id).strip() for course_id in course_ids if str(course_id).strip()]
    if not user_id or not ids:
        return {}
    placeholders = ",".join("?" for _ in ids)
    with db.connect() as conn:
        conn.row_factory = db.Row
        rows = conn.execute(
            f"""
            SELECT course_id, state_json
            FROM course_v2_runtime
            WHERE user_id = ? AND course_id IN ({placeholders})
            """,
            [user_id, *ids],
        ).fetchall()

    states: dict[str, dict[str, Any]] = {}
    for row in rows:
        raw = row["state_json"] or "{}"
        try:
            state = json.loads(raw)
        except json.JSONDecodeError:
            state = {}
        if isinstance(state, dict):
            states[str(row["course_id"])] = state
    return states


def upsert_runtime_state(user_id: str, course_id: str, state: dict[str, Any]) -> None:
    _ensure_course_v2_tables()
    payload = json.dumps(state, ensure_ascii=False)
    with db.connect() as conn:
        conn.execute(
            """
            INSERT INTO course_v2_runtime (user_id, course_id, state_json, created_at, updated_at)
            VALUES (?, ?, ?, strftime('%s','now'), strftime('%s','now'))
            ON CONFLICT(user_id, course_id) DO UPDATE SET
                state_json = excluded.state_json,
                updated_at = excluded.updated_at
            """,
            (user_id, course_id, payload),
        )
        conn.commit()
