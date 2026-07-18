"""PostgreSQL CRUD repository for the Academy domain.

기존 동기 CRUD 계약을 유지하면서 공유 PostgreSQL 연결 풀을 사용한다.

All public functions call ``_ensure_academy_tables()`` idempotently
before executing queries.
"""
import json
from infra.db import postgres_compat as db
import uuid
from datetime import datetime, timezone, timedelta
from typing import Optional, List, Dict, Any

def _normalize_user_ids(user_ids: Optional[List[str]]) -> List[str]:
    if not user_ids:
        return []
    result: List[str] = []
    seen = set()
    for raw in user_ids:
        value = str(raw or "").strip()
        if not value or value in seen:
            continue
        seen.add(value)
        result.append(value)
    return result


# ---------------------------------------------------------------------------
# Table bootstrap
# ---------------------------------------------------------------------------

def _ensure_academy_tables() -> None:
    """Create academy-related tables if they do not yet exist."""
    conn = db.connect()
    cur = conn.cursor()

    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS academy (
            academy_id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            address TEXT,
            phone TEXT,
            admin_user_id TEXT,
            created_at TEXT,
            updated_at TEXT
        )
        """
    )

    # Backward-compat migration:
    # Older local DBs may have `academy(id INTEGER PK, description, location, ...)`.
    # Rebuild to the new schema expected by API code.
    cur.execute("PRAGMA table_info(academy)")
    academy_cols = [row[1] for row in cur.fetchall()]
    if academy_cols and "academy_id" not in academy_cols:
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS academy_new (
                academy_id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                address TEXT,
                phone TEXT,
                admin_user_id TEXT,
                created_at TEXT,
                updated_at TEXT
            )
            """
        )
        cur.execute(
            """
            INSERT INTO academy_new (academy_id, name, address, phone, admin_user_id, created_at, updated_at)
            SELECT
                CASE
                    WHEN id IS NULL THEN lower(hex(randomblob(16)))
                    ELSE 'legacy_' || CAST(id AS TEXT)
                END AS academy_id,
                name,
                location AS address,
                contact_email AS phone,
                NULL AS admin_user_id,
                CAST(created_at AS TEXT) AS created_at,
                CAST(updated_at AS TEXT) AS updated_at
            FROM academy
            """
        )
        cur.execute("DROP TABLE academy")
        cur.execute("ALTER TABLE academy_new RENAME TO academy")

    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS academy_group (
            group_id TEXT PRIMARY KEY,
            academy_id TEXT NOT NULL,
            name TEXT NOT NULL,
            grade TEXT,
            subject TEXT,
            teacher_user_id TEXT,
            group_type TEXT NOT NULL DEFAULT 'academy_tutoring_group',
            searchable INTEGER NOT NULL DEFAULT 0,
            friend_verification_required INTEGER NOT NULL DEFAULT 1,
            max_members INTEGER NOT NULL DEFAULT 20,
            style_border_color TEXT,
            style_badge_text TEXT,
            schedule_json TEXT,
            timetable_plan_json TEXT,
            timetable_version TEXT,
            timetable_generated_at TEXT,
            created_at TEXT
        )
        """
    )

    # Backward-compat migration for legacy academy_group schema.
    # Legacy columns: id, academy_id(INTEGER), name, description, metadata_json, created_at(INTEGER)
    cur.execute("PRAGMA table_info(academy_group)")
    group_cols = [row[1] for row in cur.fetchall()]
    if group_cols and "group_id" not in group_cols:
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS academy_group_new (
                group_id TEXT PRIMARY KEY,
                academy_id TEXT NOT NULL,
                name TEXT NOT NULL,
                grade TEXT,
                subject TEXT,
                teacher_user_id TEXT,
                group_type TEXT NOT NULL DEFAULT 'academy_tutoring_group',
                searchable INTEGER NOT NULL DEFAULT 0,
                friend_verification_required INTEGER NOT NULL DEFAULT 1,
                max_members INTEGER NOT NULL DEFAULT 20,
                style_border_color TEXT,
                style_badge_text TEXT,
                schedule_json TEXT,
                timetable_plan_json TEXT,
                timetable_version TEXT,
                timetable_generated_at TEXT,
                created_at TEXT
            )
            """
        )
        cur.execute(
            """
            INSERT INTO academy_group_new (
                group_id, academy_id, name, grade, subject, teacher_user_id,
                group_type, searchable, friend_verification_required, max_members,
                style_border_color, style_badge_text, schedule_json, timetable_plan_json,
                timetable_version, timetable_generated_at, created_at
            )
            SELECT
                CASE
                    WHEN id IS NULL THEN lower(hex(randomblob(16)))
                    ELSE 'legacy_group_' || CAST(id AS TEXT)
                END AS group_id,
                CAST(academy_id AS TEXT) AS academy_id,
                name,
                NULL AS grade,
                NULL AS subject,
                NULL AS teacher_user_id,
                'academy_tutoring_group' AS group_type,
                0 AS searchable,
                1 AS friend_verification_required,
                20 AS max_members,
                NULL AS style_border_color,
                NULL AS style_badge_text,
                NULL AS schedule_json,
                NULL AS timetable_plan_json,
                NULL AS timetable_version,
                NULL AS timetable_generated_at,
                CAST(created_at AS TEXT) AS created_at
            FROM academy_group
            """
        )
        cur.execute("DROP TABLE academy_group")
        cur.execute("ALTER TABLE academy_group_new RENAME TO academy_group")

    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS academy_group_member (
            member_id TEXT PRIMARY KEY,
            group_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            role TEXT NOT NULL DEFAULT 'student',
            joined_at TEXT,
            removed_at TEXT,
            status TEXT NOT NULL DEFAULT 'active'
        )
        """
    )
    cur.execute("PRAGMA table_info(academy_group_member)")
    member_cols = {row[1] for row in cur.fetchall()}
    if "role" not in member_cols:
        cur.execute("ALTER TABLE academy_group_member ADD COLUMN role TEXT NOT NULL DEFAULT 'student'")
    if "joined_at" not in member_cols:
        cur.execute("ALTER TABLE academy_group_member ADD COLUMN joined_at TEXT")
    if "removed_at" not in member_cols:
        cur.execute("ALTER TABLE academy_group_member ADD COLUMN removed_at TEXT")
    if "status" not in member_cols:
        cur.execute("ALTER TABLE academy_group_member ADD COLUMN status TEXT NOT NULL DEFAULT 'active'")
    if "member_id" not in member_cols:
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS academy_group_member_new (
                member_id TEXT PRIMARY KEY,
                group_id TEXT NOT NULL,
                user_id TEXT NOT NULL,
                role TEXT NOT NULL DEFAULT 'student',
                joined_at TEXT,
                removed_at TEXT,
                status TEXT NOT NULL DEFAULT 'active'
            )
            """
        )
        cur.execute(
            """
            INSERT INTO academy_group_member_new (
                member_id, group_id, user_id, role, joined_at, removed_at, status
            )
            SELECT
                lower(hex(randomblob(16))),
                group_id,
                user_id,
                COALESCE(role, 'student'),
                joined_at,
                removed_at,
                COALESCE(status, 'active')
            FROM academy_group_member
            """
        )
        cur.execute("DROP TABLE academy_group_member")
        cur.execute("ALTER TABLE academy_group_member_new RENAME TO academy_group_member")

    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS member_event_log (
            event_id TEXT PRIMARY KEY,
            group_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            event_type TEXT NOT NULL,
            triggered_by_user_id TEXT,
            reason TEXT,
            created_at TEXT
        )
        """
    )

    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS attendance_log (
            log_id TEXT PRIMARY KEY,
            group_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            date TEXT NOT NULL,
            status TEXT NOT NULL,
            checked_by_user_id TEXT,
            checked_at TEXT,
            note TEXT
        )
        """
    )

    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS tuition_payment (
            payment_id TEXT PRIMARY KEY,
            academy_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            amount INTEGER NOT NULL,
            month_label TEXT NOT NULL,
            method TEXT,
            paid_at TEXT,
            receipt_url TEXT,
            memo TEXT
        )
        """
    )

    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS finance_ledger (
            ledger_id TEXT PRIMARY KEY,
            academy_id TEXT NOT NULL,
            category TEXT NOT NULL,
            amount INTEGER NOT NULL,
            description TEXT,
            transaction_date TEXT NOT NULL,
            recorded_by_user_id TEXT,
            created_at TEXT
        )
        """
    )

    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS parent_consult_note (
            note_id TEXT PRIMARY KEY,
            academy_id TEXT NOT NULL,
            student_user_id TEXT NOT NULL,
            parent_name TEXT,
            parent_contact TEXT,
            topic TEXT,
            content TEXT,
            consulted_by_user_id TEXT,
            consulted_at TEXT,
            follow_up_date TEXT
        )
        """
    )

    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS group_assignment (
            assignment_id TEXT PRIMARY KEY,
            group_id TEXT NOT NULL,
            sender_user_id TEXT NOT NULL,
            kind TEXT NOT NULL,
            ref_id TEXT NOT NULL,
            title TEXT,
            message TEXT,
            due_date TEXT,
            created_at TEXT
        )
        """
    )

    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS group_submission (
            submission_id TEXT PRIMARY KEY,
            assignment_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'pending',
            submitted_at TEXT,
            data_json TEXT
        )
        """
    )

    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS submission_report (
            report_id TEXT PRIMARY KEY,
            submission_id TEXT NOT NULL,
            correct_rate REAL,
            time_spent_seconds INTEGER,
            weak_tags_json TEXT,
            feedback TEXT,
            created_at TEXT
        )
        """
    )

    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS timetable_preference (
            preference_id TEXT PRIMARY KEY,
            group_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            day_of_week TEXT NOT NULL,
            time_slot TEXT NOT NULL,
            priority INTEGER NOT NULL DEFAULT 1,
            created_at TEXT
        )
        """
    )

    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS timetable_plan (
            plan_id TEXT PRIMARY KEY,
            group_id TEXT NOT NULL,
            plan_json TEXT NOT NULL,
            version TEXT NOT NULL DEFAULT 'v1',
            generated_at TEXT,
            applied INTEGER NOT NULL DEFAULT 0
        )
        """
    )

    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS student_overview_snapshot (
            snapshot_id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            academy_id TEXT NOT NULL,
            group_id TEXT,
            overall_score REAL,
            attendance_rate REAL,
            tuition_status TEXT,
            last_consult_note_id TEXT,
            summary_json TEXT,
            created_at TEXT
        )
        """
    )

    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS student_schedule_task (
            task_id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            date TEXT NOT NULL,
            title TEXT NOT NULL,
            source TEXT NOT NULL DEFAULT 'student',
            created_at TEXT,
            updated_at TEXT
        )
        """
    )
    cur.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_student_schedule_task_user_date
        ON student_schedule_task (user_id, date)
        """
    )

    conn.commit()
    conn.close()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def _generate_id() -> str:
    return str(uuid.uuid4())


def _row_to_dict(cur: db.Cursor, row: db.Row) -> Dict[str, Any]:
    """Convert a db Row to a plain dict using cursor description."""
    return {
        desc[0]: value for desc, value in zip(cur.description, row)
    }


# ---------------------------------------------------------------------------
# Academy
# ---------------------------------------------------------------------------

def create_academy(
    *,
    name: str,
    address: Optional[str] = None,
    phone: Optional[str] = None,
    admin_user_id: Optional[str] = None,
) -> Dict[str, Any]:
    _ensure_academy_tables()
    academy_id = _generate_id()
    now = _now_iso()
    conn = db.connect()
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO academy (academy_id, name, address, phone, admin_user_id, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        (academy_id, name, address, phone, admin_user_id, now, now),
    )
    conn.commit()
    conn.close()
    return {
        "academy_id": academy_id,
        "name": name,
        "address": address,
        "phone": phone,
        "admin_user_id": admin_user_id,
        "created_at": now,
        "updated_at": now,
    }


def get_academy(academy_id: str) -> Optional[Dict[str, Any]]:
    _ensure_academy_tables()
    conn = db.connect()
    conn.row_factory = db.Row
    cur = conn.cursor()
    cur.execute("SELECT * FROM academy WHERE academy_id = ?", (academy_id,))
    row = cur.fetchone()
    conn.close()
    return dict(row) if row else None


def list_academies() -> List[Dict[str, Any]]:
    _ensure_academy_tables()
    conn = db.connect()
    conn.row_factory = db.Row
    cur = conn.cursor()
    cur.execute("SELECT * FROM academy ORDER BY created_at DESC")
    rows = cur.fetchall()
    conn.close()
    return [dict(r) for r in rows]


def update_academy(
    academy_id: str,
    *,
    name: Optional[str] = None,
    address: Optional[str] = None,
    phone: Optional[str] = None,
    admin_user_id: Optional[str] = None,
) -> Optional[Dict[str, Any]]:
    _ensure_academy_tables()
    now = _now_iso()
    fields: List[str] = []
    values: List[Any] = []
    if name is not None:
        fields.append("name = ?")
        values.append(name)
    if address is not None:
        fields.append("address = ?")
        values.append(address)
    if phone is not None:
        fields.append("phone = ?")
        values.append(phone)
    if admin_user_id is not None:
        fields.append("admin_user_id = ?")
        values.append(admin_user_id)
    if not fields:
        return get_academy(academy_id)
    fields.append("updated_at = ?")
    values.append(now)
    values.append(academy_id)
    conn = db.connect()
    cur = conn.cursor()
    cur.execute(
        f"UPDATE academy SET {', '.join(fields)} WHERE academy_id = ?",
        values,
    )
    conn.commit()
    conn.close()
    return get_academy(academy_id)


def delete_academy(academy_id: str) -> bool:
    _ensure_academy_tables()
    conn = db.connect()
    cur = conn.cursor()
    cur.execute("DELETE FROM academy WHERE academy_id = ?", (academy_id,))
    conn.commit()
    deleted = cur.rowcount > 0
    conn.close()
    return deleted


# ---------------------------------------------------------------------------
# AcademyGroup
# ---------------------------------------------------------------------------

def create_group(
    *,
    academy_id: str,
    name: str,
    grade: Optional[str] = None,
    subject: Optional[str] = None,
    teacher_user_id: Optional[str] = None,
    group_type: str = "academy_tutoring_group",
    searchable: bool = False,
    friend_verification_required: bool = True,
    max_members: int = 20,
    style_border_color: Optional[str] = None,
    style_badge_text: Optional[str] = None,
    schedule_json: Optional[str] = None,
) -> Dict[str, Any]:
    _ensure_academy_tables()
    group_id = _generate_id()
    now = _now_iso()
    conn = db.connect()
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO academy_group (
            group_id, academy_id, name, grade, subject, teacher_user_id,
            group_type, searchable, friend_verification_required, max_members,
            style_border_color, style_badge_text, schedule_json, created_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            group_id, academy_id, name, grade, subject, teacher_user_id,
            group_type, int(searchable), int(friend_verification_required), max_members,
            style_border_color, style_badge_text, schedule_json, now,
        ),
    )
    conn.commit()
    conn.close()
    return {
        "group_id": group_id,
        "academy_id": academy_id,
        "name": name,
        "grade": grade,
        "subject": subject,
        "teacher_user_id": teacher_user_id,
        "group_type": group_type,
        "searchable": searchable,
        "friend_verification_required": friend_verification_required,
        "max_members": max_members,
        "style_border_color": style_border_color,
        "style_badge_text": style_badge_text,
        "schedule_json": schedule_json,
        "created_at": now,
    }


def get_group(group_id: str) -> Optional[Dict[str, Any]]:
    _ensure_academy_tables()
    conn = db.connect()
    conn.row_factory = db.Row
    cur = conn.cursor()
    cur.execute("SELECT * FROM academy_group WHERE group_id = ?", (group_id,))
    row = cur.fetchone()
    conn.close()
    if row is None:
        return None
    d = dict(row)
    d["searchable"] = bool(d.get("searchable", 0))
    d["friend_verification_required"] = bool(d.get("friend_verification_required", 1))
    return d


def list_groups(
    academy_id: Optional[str] = None,
    group_type: Optional[str] = None,
    searchable: Optional[bool] = None,
) -> List[Dict[str, Any]]:
    _ensure_academy_tables()
    conn = db.connect()
    conn.row_factory = db.Row
    cur = conn.cursor()
    conditions: List[str] = []
    params: List[Any] = []
    if academy_id:
        conditions.append("academy_id = ?")
        params.append(academy_id)
    if group_type:
        conditions.append("group_type = ?")
        params.append(group_type)
    if searchable is not None:
        conditions.append("searchable = ?")
        params.append(int(searchable))
    where = f"WHERE {' AND '.join(conditions)}" if conditions else ""
    cur.execute(
        f"SELECT * FROM academy_group {where} ORDER BY created_at DESC",
        params,
    )
    rows = cur.fetchall()
    conn.close()
    result = []
    for r in rows:
        d = dict(r)
        d["searchable"] = bool(d.get("searchable", 0))
        d["friend_verification_required"] = bool(d.get("friend_verification_required", 1))
        result.append(d)
    return result


def update_group(
    group_id: str,
    *,
    name: Optional[str] = None,
    grade: Optional[str] = None,
    subject: Optional[str] = None,
    teacher_user_id: Optional[str] = None,
    group_type: Optional[str] = None,
    searchable: Optional[bool] = None,
    friend_verification_required: Optional[bool] = None,
    max_members: Optional[int] = None,
    style_border_color: Optional[str] = None,
    style_badge_text: Optional[str] = None,
    schedule_json: Optional[str] = None,
    timetable_plan_json: Optional[str] = None,
    timetable_version: Optional[str] = None,
) -> Optional[Dict[str, Any]]:
    _ensure_academy_tables()
    fields: List[str] = []
    values: List[Any] = []
    if name is not None:
        fields.append("name = ?")
        values.append(name)
    if grade is not None:
        fields.append("grade = ?")
        values.append(grade)
    if subject is not None:
        fields.append("subject = ?")
        values.append(subject)
    if teacher_user_id is not None:
        fields.append("teacher_user_id = ?")
        values.append(teacher_user_id)
    if group_type is not None:
        fields.append("group_type = ?")
        values.append(group_type)
    if searchable is not None:
        fields.append("searchable = ?")
        values.append(int(searchable))
    if friend_verification_required is not None:
        fields.append("friend_verification_required = ?")
        values.append(int(friend_verification_required))
    if max_members is not None:
        fields.append("max_members = ?")
        values.append(max_members)
    if style_border_color is not None:
        fields.append("style_border_color = ?")
        values.append(style_border_color)
    if style_badge_text is not None:
        fields.append("style_badge_text = ?")
        values.append(style_badge_text)
    if schedule_json is not None:
        fields.append("schedule_json = ?")
        values.append(schedule_json)
    if timetable_plan_json is not None:
        fields.append("timetable_plan_json = ?")
        values.append(timetable_plan_json)
    if timetable_version is not None:
        fields.append("timetable_version = ?")
        values.append(timetable_version)
    if not fields:
        return get_group(group_id)
    values.append(group_id)
    conn = db.connect()
    cur = conn.cursor()
    cur.execute(
        f"UPDATE academy_group SET {', '.join(fields)} WHERE group_id = ?",
        values,
    )
    conn.commit()
    conn.close()
    return get_group(group_id)


def delete_group(group_id: str) -> bool:
    _ensure_academy_tables()
    conn = db.connect()
    cur = conn.cursor()
    cur.execute("DELETE FROM academy_group WHERE group_id = ?", (group_id,))
    conn.commit()
    deleted = cur.rowcount > 0
    conn.close()
    return deleted


# ---------------------------------------------------------------------------
# Membership limits & counting
# ---------------------------------------------------------------------------

def count_groups_for_user(user_id: str, group_type: Optional[str] = None) -> int:
    """Count active academy group memberships for a user."""
    _ensure_academy_tables()
    conn = db.connect()
    cur = conn.cursor()
    if group_type:
        cur.execute(
            """
            SELECT COUNT(*) FROM academy_group_member m
            JOIN academy_group g ON m.group_id = g.group_id
            WHERE m.user_id = ? AND m.status = 'active' AND g.group_type = ?
            """,
            (user_id, group_type),
        )
    else:
        cur.execute(
            """
            SELECT COUNT(*) FROM academy_group_member m
            JOIN academy_group g ON m.group_id = g.group_id
            WHERE m.user_id = ? AND m.status = 'active'
            """,
            (user_id,),
        )
    row = cur.fetchone()
    conn.close()
    return int(row[0]) if row else 0


def count_groups_created_by_user(user_id: str, academy_id: str) -> int:
    """Count groups created by a user within an academy."""
    _ensure_academy_tables()
    conn = db.connect()
    cur = conn.cursor()
    cur.execute(
        """
        SELECT COUNT(*) FROM academy_group
        WHERE teacher_user_id = ? AND academy_id = ?
        """,
        (user_id, academy_id),
    )
    row = cur.fetchone()
    conn.close()
    return int(row[0]) if row else 0


def get_group_member_count(group_id: str) -> int:
    """Count active members in a group."""
    _ensure_academy_tables()
    conn = db.connect()
    cur = conn.cursor()
    cur.execute(
        "SELECT COUNT(*) FROM academy_group_member WHERE group_id = ? AND status = 'active'",
        (group_id,),
    )
    row = cur.fetchone()
    conn.close()
    return int(row[0]) if row else 0


# ---------------------------------------------------------------------------
# AcademyGroupMember
# ---------------------------------------------------------------------------

def add_group_member(
    *,
    group_id: str,
    user_id: str,
    role: str = "student",
    status: str = "active",
) -> Dict[str, Any]:
    _ensure_academy_tables()
    member_id = _generate_id()
    now = _now_iso()
    conn = db.connect()
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO academy_group_member (member_id, group_id, user_id, role, joined_at, status)
        VALUES (?, ?, ?, ?, ?, ?)
        """,
        (member_id, group_id, user_id, role, now, status),
    )
    conn.commit()
    conn.close()
    return {
        "member_id": member_id,
        "group_id": group_id,
        "user_id": user_id,
        "role": role,
        "joined_at": now,
        "status": status,
    }


def get_group_member(member_id: str) -> Optional[Dict[str, Any]]:
    _ensure_academy_tables()
    conn = db.connect()
    conn.row_factory = db.Row
    cur = conn.cursor()
    cur.execute("SELECT * FROM academy_group_member WHERE member_id = ?", (member_id,))
    row = cur.fetchone()
    conn.close()
    return dict(row) if row else None


def list_group_members(
    group_id: Optional[str] = None,
    user_id: Optional[str] = None,
    status: Optional[str] = None,
) -> List[Dict[str, Any]]:
    _ensure_academy_tables()
    conn = db.connect()
    conn.row_factory = db.Row
    cur = conn.cursor()
    conditions: List[str] = []
    params: List[Any] = []
    if group_id:
        conditions.append("group_id = ?")
        params.append(group_id)
    if user_id:
        conditions.append("user_id = ?")
        params.append(user_id)
    if status:
        conditions.append("status = ?")
        params.append(status)
    where = f"WHERE {' AND '.join(conditions)}" if conditions else ""
    cur.execute(
        f"SELECT * FROM academy_group_member {where} ORDER BY joined_at DESC",
        params,
    )
    rows = cur.fetchall()
    conn.close()
    return [dict(r) for r in rows]


def is_active_group_member(*, group_id: str, user_id: str) -> bool:
    _ensure_academy_tables()
    conn = db.connect()
    cur = conn.cursor()
    cur.execute(
        """
        SELECT 1
        FROM academy_group_member
        WHERE group_id = ? AND user_id = ? AND status = 'active'
        LIMIT 1
        """,
        (group_id, user_id),
    )
    ok = cur.fetchone() is not None
    conn.close()
    return ok


def is_active_academy_teacher(*, academy_id: str, user_id: str) -> bool:
    _ensure_academy_tables()
    conn = db.connect()
    cur = conn.cursor()
    cur.execute(
        """
        SELECT 1
        FROM academy_group g
        JOIN academy_group_member m ON m.group_id = g.group_id
        WHERE g.academy_id = ?
          AND m.user_id = ?
          AND m.status = 'active'
          AND lower(COALESCE(m.role, 'student')) IN ('teacher', 'admin')
        LIMIT 1
        """,
        (academy_id, user_id),
    )
    ok = cur.fetchone() is not None
    conn.close()
    return ok


def is_active_academy_member(*, academy_id: str, user_id: str) -> bool:
    _ensure_academy_tables()
    conn = db.connect()
    cur = conn.cursor()
    cur.execute(
        """
        SELECT 1
        FROM academy_group g
        JOIN academy_group_member m ON m.group_id = g.group_id
        WHERE g.academy_id = ?
          AND m.user_id = ?
          AND m.status = 'active'
        LIMIT 1
        """,
        (academy_id, user_id),
    )
    ok = cur.fetchone() is not None
    conn.close()
    return ok


def remove_group_member(member_id: str, reason: Optional[str] = None) -> bool:
    _ensure_academy_tables()
    now = _now_iso()
    conn = db.connect()
    cur = conn.cursor()
    # Get member info before removing
    cur.execute(
        "SELECT group_id, user_id FROM academy_group_member WHERE member_id = ?",
        (member_id,),
    )
    row = cur.fetchone()
    if row is None:
        conn.close()
        return False
    group_id, user_id = row
    cur.execute(
        "UPDATE academy_group_member SET status = 'removed', removed_at = ? WHERE member_id = ?",
        (now, member_id),
    )
    # Log event
    event_id = _generate_id()
    cur.execute(
        """
        INSERT INTO member_event_log (event_id, group_id, user_id, event_type, reason, created_at)
        VALUES (?, ?, ?, 'removed', ?, ?)
        """,
        (event_id, group_id, user_id, reason, now),
    )
    conn.commit()
    conn.close()
    return True


def update_member_status(member_id: str, status: str) -> Optional[Dict[str, Any]]:
    """Update member status (e.g., pending -> active)."""
    _ensure_academy_tables()
    conn = db.connect()
    cur = conn.cursor()
    cur.execute(
        "UPDATE academy_group_member SET status = ? WHERE member_id = ?",
        (status, member_id),
    )
    conn.commit()
    conn.close()
    return get_group_member(member_id)


# ---------------------------------------------------------------------------
# MemberEventLog
# ---------------------------------------------------------------------------

def log_member_event(
    *,
    group_id: str,
    user_id: str,
    event_type: str,
    triggered_by_user_id: Optional[str] = None,
    reason: Optional[str] = None,
) -> Dict[str, Any]:
    _ensure_academy_tables()
    event_id = _generate_id()
    now = _now_iso()
    conn = db.connect()
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO member_event_log (event_id, group_id, user_id, event_type, triggered_by_user_id, reason, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        (event_id, group_id, user_id, event_type, triggered_by_user_id, reason, now),
    )
    conn.commit()
    conn.close()
    return {
        "event_id": event_id,
        "group_id": group_id,
        "user_id": user_id,
        "event_type": event_type,
        "triggered_by_user_id": triggered_by_user_id,
        "reason": reason,
        "created_at": now,
    }


def list_member_events(
    group_id: Optional[str] = None,
    user_id: Optional[str] = None,
    event_type: Optional[str] = None,
    limit: int = 100,
) -> List[Dict[str, Any]]:
    _ensure_academy_tables()
    conn = db.connect()
    conn.row_factory = db.Row
    cur = conn.cursor()
    conditions: List[str] = []
    params: List[Any] = []
    if group_id:
        conditions.append("group_id = ?")
        params.append(group_id)
    if user_id:
        conditions.append("user_id = ?")
        params.append(user_id)
    if event_type:
        conditions.append("event_type = ?")
        params.append(event_type)
    where = f"WHERE {' AND '.join(conditions)}" if conditions else ""
    cur.execute(
        f"SELECT * FROM member_event_log {where} ORDER BY created_at DESC LIMIT ?",
        (*params, limit),
    )
    rows = cur.fetchall()
    conn.close()
    return [dict(r) for r in rows]


# ---------------------------------------------------------------------------
# AttendanceLog
# ---------------------------------------------------------------------------

def record_attendance(
    *,
    group_id: str,
    user_id: str,
    date: str,
    status: str,
    checked_by_user_id: Optional[str] = None,
    note: Optional[str] = None,
) -> Dict[str, Any]:
    _ensure_academy_tables()
    log_id = _generate_id()
    now = _now_iso()
    conn = db.connect()
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO attendance_log (log_id, group_id, user_id, date, status, checked_by_user_id, checked_at, note)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (log_id, group_id, user_id, date, status, checked_by_user_id, now, note),
    )
    conn.commit()
    conn.close()
    return {
        "log_id": log_id,
        "group_id": group_id,
        "user_id": user_id,
        "date": date,
        "status": status,
        "checked_by_user_id": checked_by_user_id,
        "checked_at": now,
        "note": note,
    }


def get_attendance_log(log_id: str) -> Optional[Dict[str, Any]]:
    _ensure_academy_tables()
    conn = db.connect()
    conn.row_factory = db.Row
    cur = conn.cursor()
    cur.execute("SELECT * FROM attendance_log WHERE log_id = ?", (log_id,))
    row = cur.fetchone()
    conn.close()
    return dict(row) if row else None


def list_attendance(
    *,
    group_id: Optional[str] = None,
    user_id: Optional[str] = None,
    date: Optional[str] = None,
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
) -> List[Dict[str, Any]]:
    _ensure_academy_tables()
    conn = db.connect()
    conn.row_factory = db.Row
    cur = conn.cursor()
    conditions: List[str] = []
    params: List[Any] = []
    if group_id:
        conditions.append("group_id = ?")
        params.append(group_id)
    if user_id:
        conditions.append("user_id = ?")
        params.append(user_id)
    if date:
        conditions.append("date = ?")
        params.append(date)
    if date_from:
        conditions.append("date >= ?")
        params.append(date_from)
    if date_to:
        conditions.append("date <= ?")
        params.append(date_to)
    where = f"WHERE {' AND '.join(conditions)}" if conditions else ""
    cur.execute(
        f"SELECT * FROM attendance_log {where} ORDER BY checked_at DESC",
        params,
    )
    rows = cur.fetchall()
    conn.close()
    return [dict(r) for r in rows]


def list_attendance_for_teacher(
    *,
    teacher_user_id: str,
    group_id: Optional[str] = None,
    user_id: Optional[str] = None,
    date: Optional[str] = None,
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
) -> List[Dict[str, Any]]:
    _ensure_academy_tables()
    conn = db.connect()
    conn.row_factory = db.Row
    cur = conn.cursor()
    conditions: List[str] = [
        "m.user_id = ?",
        "m.status = 'active'",
        "lower(COALESCE(m.role, 'student')) IN ('teacher', 'admin')",
    ]
    params: List[Any] = [teacher_user_id]
    if group_id:
        conditions.append("a.group_id = ?")
        params.append(group_id)
    if user_id:
        conditions.append("a.user_id = ?")
        params.append(user_id)
    if date:
        conditions.append("a.date = ?")
        params.append(date)
    if date_from:
        conditions.append("a.date >= ?")
        params.append(date_from)
    if date_to:
        conditions.append("a.date <= ?")
        params.append(date_to)
    cur.execute(
        f"""
        SELECT a.*
        FROM attendance_log a
        JOIN academy_group_member m ON m.group_id = a.group_id
        WHERE {' AND '.join(conditions)}
        ORDER BY a.checked_at DESC
        """,
        params,
    )
    rows = cur.fetchall()
    conn.close()
    return [dict(r) for r in rows]


def update_attendance(
    log_id: str,
    *,
    status: Optional[str] = None,
    note: Optional[str] = None,
) -> Optional[Dict[str, Any]]:
    _ensure_academy_tables()
    fields: List[str] = []
    values: List[Any] = []
    if status is not None:
        fields.append("status = ?")
        values.append(status)
    if note is not None:
        fields.append("note = ?")
        values.append(note)
    if not fields:
        return get_attendance_log(log_id)
    values.append(log_id)
    conn = db.connect()
    cur = conn.cursor()
    cur.execute(
        f"UPDATE attendance_log SET {', '.join(fields)} WHERE log_id = ?",
        values,
    )
    conn.commit()
    conn.close()
    return get_attendance_log(log_id)


def delete_attendance(log_id: str) -> bool:
    _ensure_academy_tables()
    conn = db.connect()
    cur = conn.cursor()
    cur.execute("DELETE FROM attendance_log WHERE log_id = ?", (log_id,))
    conn.commit()
    deleted = cur.rowcount > 0
    conn.close()
    return deleted


def get_attendance_stats(
    user_id: str,
    group_id: str,
    days: int = 30,
) -> Dict[str, Any]:
    """Get attendance statistics for a user in a group over N days."""
    _ensure_academy_tables()
    cutoff = (datetime.now(timezone.utc) - timedelta(days=days)).strftime("%Y-%m-%d")
    conn = db.connect()
    cur = conn.cursor()

    # Total records in period
    cur.execute(
        """
        SELECT COUNT(*) FROM attendance_log
        WHERE user_id = ? AND group_id = ? AND date >= ?
        """,
        (user_id, group_id, cutoff),
    )
    total = int(cur.fetchone()[0])

    # Count by status
    cur.execute(
        """
        SELECT status, COUNT(*) FROM attendance_log
        WHERE user_id = ? AND group_id = ? AND date >= ?
        GROUP BY status
        """,
        (user_id, group_id, cutoff),
    )
    status_counts = {row[0]: int(row[1]) for row in cur.fetchall()}

    # Consecutive attendance (streak)
    cur.execute(
        """
        SELECT date, status FROM attendance_log
        WHERE user_id = ? AND group_id = ? AND date >= ?
        ORDER BY date DESC
        """,
        (user_id, group_id, cutoff),
    )
    rows = cur.fetchall()
    conn.close()

    streak = 0
    for date_str, status in rows:
        if status in ("present", "late"):
            streak += 1
        elif status == "absent":
            break

    present = status_counts.get("present", 0)
    late = status_counts.get("late", 0)
    absent = status_counts.get("absent", 0)
    attended = present + late
    attendance_rate = round(attended / total * 100, 2) if total > 0 else 0.0
    late_rate = round(late / total * 100, 2) if total > 0 else 0.0
    absence_rate = round(absent / total * 100, 2) if total > 0 else 0.0

    return {
        "user_id": user_id,
        "group_id": group_id,
        "days": days,
        "total_records": total,
        "present": present,
        "late": late,
        "absent": absent,
        "attendance_rate": attendance_rate,
        "late_rate": late_rate,
        "absence_rate": absence_rate,
        "consecutive_attendance": streak,
    }


# ---------------------------------------------------------------------------
# TuitionPayment
# ---------------------------------------------------------------------------

def create_tuition_payment(
    *,
    academy_id: str,
    user_id: str,
    amount: int,
    month_label: str,
    method: Optional[str] = None,
    receipt_url: Optional[str] = None,
    memo: Optional[str] = None,
) -> Dict[str, Any]:
    _ensure_academy_tables()
    payment_id = _generate_id()
    now = _now_iso()
    conn = db.connect()
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO tuition_payment (payment_id, academy_id, user_id, amount, month_label, method, paid_at, receipt_url, memo)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (payment_id, academy_id, user_id, amount, month_label, method, now, receipt_url, memo),
    )
    conn.commit()
    conn.close()
    return {
        "payment_id": payment_id,
        "academy_id": academy_id,
        "user_id": user_id,
        "amount": amount,
        "month_label": month_label,
        "method": method,
        "paid_at": now,
        "receipt_url": receipt_url,
        "memo": memo,
    }


def get_tuition_payment(payment_id: str) -> Optional[Dict[str, Any]]:
    _ensure_academy_tables()
    conn = db.connect()
    conn.row_factory = db.Row
    cur = conn.cursor()
    cur.execute("SELECT * FROM tuition_payment WHERE payment_id = ?", (payment_id,))
    row = cur.fetchone()
    conn.close()
    return dict(row) if row else None


def list_tuition_payments(
    *,
    academy_id: Optional[str] = None,
    user_id: Optional[str] = None,
    month_label: Optional[str] = None,
) -> List[Dict[str, Any]]:
    _ensure_academy_tables()
    conn = db.connect()
    conn.row_factory = db.Row
    cur = conn.cursor()
    conditions: List[str] = []
    params: List[Any] = []
    if academy_id:
        conditions.append("academy_id = ?")
        params.append(academy_id)
    if user_id:
        conditions.append("user_id = ?")
        params.append(user_id)
    if month_label:
        conditions.append("month_label = ?")
        params.append(month_label)
    where = f"WHERE {' AND '.join(conditions)}" if conditions else ""
    cur.execute(
        f"SELECT * FROM tuition_payment {where} ORDER BY paid_at DESC",
        params,
    )
    rows = cur.fetchall()
    conn.close()
    return [dict(r) for r in rows]


def list_tuition_payments_for_teacher(
    *,
    teacher_user_id: str,
    academy_id: Optional[str] = None,
    user_id: Optional[str] = None,
    month_label: Optional[str] = None,
) -> List[Dict[str, Any]]:
    _ensure_academy_tables()
    conn = db.connect()
    conn.row_factory = db.Row
    cur = conn.cursor()
    conditions: List[str] = [
        """
        EXISTS (
            SELECT 1
            FROM academy_group g
            JOIN academy_group_member m ON m.group_id = g.group_id
            WHERE g.academy_id = p.academy_id
              AND m.user_id = ?
              AND m.status = 'active'
              AND lower(COALESCE(m.role, 'student')) IN ('teacher', 'admin')
        )
        """,
    ]
    params: List[Any] = [teacher_user_id]
    if academy_id:
        conditions.append("p.academy_id = ?")
        params.append(academy_id)
    if user_id:
        conditions.append("p.user_id = ?")
        params.append(user_id)
    if month_label:
        conditions.append("p.month_label = ?")
        params.append(month_label)
    cur.execute(
        f"""
        SELECT p.*
        FROM tuition_payment p
        WHERE {' AND '.join(conditions)}
        ORDER BY p.paid_at DESC
        """,
        params,
    )
    rows = cur.fetchall()
    conn.close()
    return [dict(r) for r in rows]


def update_tuition_payment(
    payment_id: str,
    *,
    amount: Optional[int] = None,
    method: Optional[str] = None,
    receipt_url: Optional[str] = None,
    memo: Optional[str] = None,
) -> Optional[Dict[str, Any]]:
    _ensure_academy_tables()
    fields: List[str] = []
    values: List[Any] = []
    if amount is not None:
        fields.append("amount = ?")
        values.append(amount)
    if method is not None:
        fields.append("method = ?")
        values.append(method)
    if receipt_url is not None:
        fields.append("receipt_url = ?")
        values.append(receipt_url)
    if memo is not None:
        fields.append("memo = ?")
        values.append(memo)
    if not fields:
        return get_tuition_payment(payment_id)
    values.append(payment_id)
    conn = db.connect()
    cur = conn.cursor()
    cur.execute(
        f"UPDATE tuition_payment SET {', '.join(fields)} WHERE payment_id = ?",
        values,
    )
    conn.commit()
    conn.close()
    return get_tuition_payment(payment_id)


def delete_tuition_payment(payment_id: str) -> bool:
    _ensure_academy_tables()
    conn = db.connect()
    cur = conn.cursor()
    cur.execute("DELETE FROM tuition_payment WHERE payment_id = ?", (payment_id,))
    conn.commit()
    deleted = cur.rowcount > 0
    conn.close()
    return deleted


def get_tuition_summary(academy_id: str, month_label: str) -> Dict[str, Any]:
    """Get tuition summary for an academy in a given month."""
    _ensure_academy_tables()
    conn = db.connect()
    conn.row_factory = db.Row
    cur = conn.cursor()
    cur.execute(
        """
        SELECT COUNT(*) as paid_count, SUM(amount) as total_amount
        FROM tuition_payment
        WHERE academy_id = ? AND month_label = ?
        """,
        (academy_id, month_label),
    )
    row = cur.fetchone()
    conn.close()
    if row:
        return {
            "academy_id": academy_id,
            "month_label": month_label,
            "paid_count": row["paid_count"] or 0,
            "total_amount": row["total_amount"] or 0,
        }
    return {
        "academy_id": academy_id,
        "month_label": month_label,
        "paid_count": 0,
        "total_amount": 0,
    }


# ---------------------------------------------------------------------------
# FinanceLedger
# ---------------------------------------------------------------------------

def create_ledger_entry(
    *,
    academy_id: str,
    category: str,
    amount: int,
    description: Optional[str] = None,
    transaction_date: str,
    recorded_by_user_id: Optional[str] = None,
) -> Dict[str, Any]:
    _ensure_academy_tables()
    ledger_id = _generate_id()
    now = _now_iso()
    conn = db.connect()
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO finance_ledger (ledger_id, academy_id, category, amount, description, transaction_date, recorded_by_user_id, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (ledger_id, academy_id, category, amount, description, transaction_date, recorded_by_user_id, now),
    )
    conn.commit()
    conn.close()
    return {
        "ledger_id": ledger_id,
        "academy_id": academy_id,
        "category": category,
        "amount": amount,
        "description": description,
        "transaction_date": transaction_date,
        "recorded_by_user_id": recorded_by_user_id,
        "created_at": now,
    }


def get_ledger_entry(ledger_id: str) -> Optional[Dict[str, Any]]:
    _ensure_academy_tables()
    conn = db.connect()
    conn.row_factory = db.Row
    cur = conn.cursor()
    cur.execute("SELECT * FROM finance_ledger WHERE ledger_id = ?", (ledger_id,))
    row = cur.fetchone()
    conn.close()
    return dict(row) if row else None


def list_ledger_entries(
    *,
    academy_id: Optional[str] = None,
    category: Optional[str] = None,
    transaction_date_from: Optional[str] = None,
    transaction_date_to: Optional[str] = None,
) -> List[Dict[str, Any]]:
    _ensure_academy_tables()
    conn = db.connect()
    conn.row_factory = db.Row
    cur = conn.cursor()
    conditions: List[str] = []
    params: List[Any] = []
    if academy_id:
        conditions.append("academy_id = ?")
        params.append(academy_id)
    if category:
        conditions.append("category = ?")
        params.append(category)
    if transaction_date_from:
        conditions.append("transaction_date >= ?")
        params.append(transaction_date_from)
    if transaction_date_to:
        conditions.append("transaction_date <= ?")
        params.append(transaction_date_to)
    where = f"WHERE {' AND '.join(conditions)}" if conditions else ""
    cur.execute(
        f"SELECT * FROM finance_ledger {where} ORDER BY transaction_date DESC, created_at DESC",
        params,
    )
    rows = cur.fetchall()
    conn.close()
    return [dict(r) for r in rows]


def list_ledger_entries_for_teacher(
    *,
    teacher_user_id: str,
    academy_id: Optional[str] = None,
    category: Optional[str] = None,
    transaction_date_from: Optional[str] = None,
    transaction_date_to: Optional[str] = None,
) -> List[Dict[str, Any]]:
    _ensure_academy_tables()
    conn = db.connect()
    conn.row_factory = db.Row
    cur = conn.cursor()
    conditions: List[str] = [
        """
        EXISTS (
            SELECT 1
            FROM academy_group g
            JOIN academy_group_member m ON m.group_id = g.group_id
            WHERE g.academy_id = l.academy_id
              AND m.user_id = ?
              AND m.status = 'active'
              AND lower(COALESCE(m.role, 'student')) IN ('teacher', 'admin')
        )
        """,
    ]
    params: List[Any] = [teacher_user_id]
    if academy_id:
        conditions.append("l.academy_id = ?")
        params.append(academy_id)
    if category:
        conditions.append("l.category = ?")
        params.append(category)
    if transaction_date_from:
        conditions.append("l.transaction_date >= ?")
        params.append(transaction_date_from)
    if transaction_date_to:
        conditions.append("l.transaction_date <= ?")
        params.append(transaction_date_to)
    cur.execute(
        f"""
        SELECT l.*
        FROM finance_ledger l
        WHERE {' AND '.join(conditions)}
        ORDER BY l.transaction_date DESC, l.created_at DESC
        """,
        params,
    )
    rows = cur.fetchall()
    conn.close()
    return [dict(r) for r in rows]


def update_ledger_entry(
    ledger_id: str,
    *,
    category: Optional[str] = None,
    amount: Optional[int] = None,
    description: Optional[str] = None,
    transaction_date: Optional[str] = None,
) -> Optional[Dict[str, Any]]:
    _ensure_academy_tables()
    fields: List[str] = []
    values: List[Any] = []
    if category is not None:
        fields.append("category = ?")
        values.append(category)
    if amount is not None:
        fields.append("amount = ?")
        values.append(amount)
    if description is not None:
        fields.append("description = ?")
        values.append(description)
    if transaction_date is not None:
        fields.append("transaction_date = ?")
        values.append(transaction_date)
    if not fields:
        return get_ledger_entry(ledger_id)
    values.append(ledger_id)
    conn = db.connect()
    cur = conn.cursor()
    cur.execute(
        f"UPDATE finance_ledger SET {', '.join(fields)} WHERE ledger_id = ?",
        values,
    )
    conn.commit()
    conn.close()
    return get_ledger_entry(ledger_id)


def delete_ledger_entry(ledger_id: str) -> bool:
    _ensure_academy_tables()
    conn = db.connect()
    cur = conn.cursor()
    cur.execute("DELETE FROM finance_ledger WHERE ledger_id = ?", (ledger_id,))
    conn.commit()
    deleted = cur.rowcount > 0
    conn.close()
    return deleted


def get_ledger_summary(
    academy_id: str,
    transaction_date_from: Optional[str] = None,
    transaction_date_to: Optional[str] = None,
) -> Dict[str, Any]:
    """Get ledger summary (income, expense, net) for an academy."""
    _ensure_academy_tables()
    conn = db.connect()
    cur = conn.cursor()
    conditions = ["academy_id = ?"]
    params: List[Any] = [academy_id]
    if transaction_date_from:
        conditions.append("transaction_date >= ?")
        params.append(transaction_date_from)
    if transaction_date_to:
        conditions.append("transaction_date <= ?")
        params.append(transaction_date_to)
    where = f"WHERE {' AND '.join(conditions)}"
    cur.execute(
        f"SELECT category, SUM(amount) FROM finance_ledger {where} GROUP BY category",
        params,
    )
    rows = cur.fetchall()
    conn.close()
    income = 0
    expense = 0
    for category, amount in rows:
        if category == "income":
            income = amount or 0
        elif category == "expense":
            expense = amount or 0
    return {
        "academy_id": academy_id,
        "income": income,
        "expense": expense,
        "net": income - expense,
    }


# ---------------------------------------------------------------------------
# ParentConsultNote
# ---------------------------------------------------------------------------

def create_consult_note(
    *,
    academy_id: str,
    student_user_id: str,
    parent_name: Optional[str] = None,
    parent_contact: Optional[str] = None,
    topic: Optional[str] = None,
    content: Optional[str] = None,
    consulted_by_user_id: Optional[str] = None,
    follow_up_date: Optional[str] = None,
) -> Dict[str, Any]:
    _ensure_academy_tables()
    note_id = _generate_id()
    now = _now_iso()
    conn = db.connect()
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO parent_consult_note (note_id, academy_id, student_user_id, parent_name, parent_contact, topic, content, consulted_by_user_id, consulted_at, follow_up_date)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (note_id, academy_id, student_user_id, parent_name, parent_contact, topic, content, consulted_by_user_id, now, follow_up_date),
    )
    conn.commit()
    conn.close()
    return {
        "note_id": note_id,
        "academy_id": academy_id,
        "student_user_id": student_user_id,
        "parent_name": parent_name,
        "parent_contact": parent_contact,
        "topic": topic,
        "content": content,
        "consulted_by_user_id": consulted_by_user_id,
        "consulted_at": now,
        "follow_up_date": follow_up_date,
    }


def get_consult_note(note_id: str) -> Optional[Dict[str, Any]]:
    _ensure_academy_tables()
    conn = db.connect()
    conn.row_factory = db.Row
    cur = conn.cursor()
    cur.execute("SELECT * FROM parent_consult_note WHERE note_id = ?", (note_id,))
    row = cur.fetchone()
    conn.close()
    return dict(row) if row else None


def list_consult_notes(
    *,
    academy_id: Optional[str] = None,
    student_user_id: Optional[str] = None,
) -> List[Dict[str, Any]]:
    _ensure_academy_tables()
    conn = db.connect()
    conn.row_factory = db.Row
    cur = conn.cursor()
    conditions: List[str] = []
    params: List[Any] = []
    if academy_id:
        conditions.append("academy_id = ?")
        params.append(academy_id)
    if student_user_id:
        conditions.append("student_user_id = ?")
        params.append(student_user_id)
    where = f"WHERE {' AND '.join(conditions)}" if conditions else ""
    cur.execute(
        f"SELECT * FROM parent_consult_note {where} ORDER BY consulted_at DESC",
        params,
    )
    rows = cur.fetchall()
    conn.close()
    return [dict(r) for r in rows]


def list_consult_notes_for_teacher(
    *,
    teacher_user_id: str,
    academy_id: Optional[str] = None,
    student_user_id: Optional[str] = None,
) -> List[Dict[str, Any]]:
    _ensure_academy_tables()
    conn = db.connect()
    conn.row_factory = db.Row
    cur = conn.cursor()
    conditions: List[str] = [
        """
        EXISTS (
            SELECT 1
            FROM academy_group g
            JOIN academy_group_member m ON m.group_id = g.group_id
            WHERE g.academy_id = n.academy_id
              AND m.user_id = ?
              AND m.status = 'active'
              AND lower(COALESCE(m.role, 'student')) IN ('teacher', 'admin')
        )
        """,
    ]
    params: List[Any] = [teacher_user_id]
    if academy_id:
        conditions.append("n.academy_id = ?")
        params.append(academy_id)
    if student_user_id:
        conditions.append("n.student_user_id = ?")
        params.append(student_user_id)
    cur.execute(
        f"""
        SELECT n.*
        FROM parent_consult_note n
        WHERE {' AND '.join(conditions)}
        ORDER BY n.consulted_at DESC
        """,
        params,
    )
    rows = cur.fetchall()
    conn.close()
    return [dict(r) for r in rows]


def update_consult_note(
    note_id: str,
    *,
    parent_name: Optional[str] = None,
    parent_contact: Optional[str] = None,
    topic: Optional[str] = None,
    content: Optional[str] = None,
    follow_up_date: Optional[str] = None,
) -> Optional[Dict[str, Any]]:
    _ensure_academy_tables()
    fields: List[str] = []
    values: List[Any] = []
    if parent_name is not None:
        fields.append("parent_name = ?")
        values.append(parent_name)
    if parent_contact is not None:
        fields.append("parent_contact = ?")
        values.append(parent_contact)
    if topic is not None:
        fields.append("topic = ?")
        values.append(topic)
    if content is not None:
        fields.append("content = ?")
        values.append(content)
    if follow_up_date is not None:
        fields.append("follow_up_date = ?")
        values.append(follow_up_date)
    if not fields:
        return get_consult_note(note_id)
    values.append(note_id)
    conn = db.connect()
    cur = conn.cursor()
    cur.execute(
        f"UPDATE parent_consult_note SET {', '.join(fields)} WHERE note_id = ?",
        values,
    )
    conn.commit()
    conn.close()
    return get_consult_note(note_id)


def delete_consult_note(note_id: str) -> bool:
    _ensure_academy_tables()
    conn = db.connect()
    cur = conn.cursor()
    cur.execute("DELETE FROM parent_consult_note WHERE note_id = ?", (note_id,))
    conn.commit()
    deleted = cur.rowcount > 0
    conn.close()
    return deleted


# ---------------------------------------------------------------------------
# GroupAssignment
# ---------------------------------------------------------------------------

def create_assignment(
    *,
    group_id: str,
    sender_user_id: str,
    kind: str,
    ref_id: str,
    title: Optional[str] = None,
    message: Optional[str] = None,
    due_date: Optional[str] = None,
    target_user_ids: Optional[List[str]] = None,
) -> Dict[str, Any]:
    _ensure_academy_tables()
    assignment_id = _generate_id()
    now = _now_iso()
    conn = db.connect()
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO group_assignment (assignment_id, group_id, sender_user_id, kind, ref_id, title, message, due_date, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (assignment_id, group_id, sender_user_id, kind, ref_id, title, message, due_date, now),
    )
    conn.commit()
    conn.close()

    submissions = _auto_create_submissions(assignment_id, group_id, target_user_ids)

    return {
        "assignment_id": assignment_id,
        "group_id": group_id,
        "sender_user_id": sender_user_id,
        "kind": kind,
        "ref_id": ref_id,
        "title": title,
        "message": message,
        "due_date": due_date,
        "created_at": now,
        "target_user_ids": [item["user_id"] for item in submissions],
        "submission_count": len(submissions),
    }


def _active_group_user_ids(group_id: str) -> List[str]:
    _ensure_academy_tables()
    conn = db.connect()
    cur = conn.cursor()
    cur.execute(
        """
        SELECT user_id
        FROM academy_group_member
        WHERE group_id = ?
          AND status = 'active'
          AND lower(COALESCE(role, 'student')) = 'student'
        """,
        (group_id,),
    )
    rows = cur.fetchall()
    conn.close()
    user_ids = [str(row[0]) for row in rows if row and row[0]]
    if user_ids:
        return user_ids
    try:
        from storage.study_group_storage import get_group, list_member_ids

        group = get_group(group_id) or {}
        creator_id = str(group.get("creator_id") or "")
        return [
            str(user_id)
            for user_id in list_member_ids(group_id)
            if str(user_id) and str(user_id) != creator_id
        ]
    except Exception:
        return []


def _auto_create_submissions(
    assignment_id: str,
    group_id: str,
    target_user_ids: Optional[List[str]] = None,
) -> List[Dict[str, Any]]:
    """Create pending submissions for selected active group members."""
    active_users = set(_active_group_user_ids(group_id))
    selected = _normalize_user_ids(target_user_ids)
    if selected:
        user_ids = [user_id for user_id in selected if user_id in active_users]
    else:
        user_ids = list(active_users)

    _ensure_academy_tables()
    conn = db.connect()
    cur = conn.cursor()
    submissions: List[Dict[str, Any]] = []
    for user_id in user_ids:
        submission_id = _generate_id()
        cur.execute(
            """
            INSERT INTO group_submission (submission_id, assignment_id, user_id, status)
            VALUES (?, ?, ?, 'pending')
            """,
            (submission_id, assignment_id, user_id),
        )
        submissions.append(
            {
                "submission_id": submission_id,
                "assignment_id": assignment_id,
                "user_id": user_id,
                "status": "pending",
            }
        )
    conn.commit()
    conn.close()
    return submissions


def get_assignment(assignment_id: str) -> Optional[Dict[str, Any]]:
    _ensure_academy_tables()
    conn = db.connect()
    conn.row_factory = db.Row
    cur = conn.cursor()
    cur.execute("SELECT * FROM group_assignment WHERE assignment_id = ?", (assignment_id,))
    row = cur.fetchone()
    conn.close()
    return dict(row) if row else None


def list_assignments(
    group_id: Optional[str] = None,
    kind: Optional[str] = None,
) -> List[Dict[str, Any]]:
    _ensure_academy_tables()
    conn = db.connect()
    conn.row_factory = db.Row
    cur = conn.cursor()
    conditions: List[str] = []
    params: List[Any] = []
    if group_id:
        conditions.append("group_id = ?")
        params.append(group_id)
    if kind:
        conditions.append("kind = ?")
        params.append(kind)
    where = f"WHERE {' AND '.join(conditions)}" if conditions else ""
    cur.execute(
        f"SELECT * FROM group_assignment {where} ORDER BY created_at DESC",
        params,
    )
    rows = cur.fetchall()
    conn.close()
    return [dict(r) for r in rows]


def list_assignments_for_teacher(
    *,
    user_id: str,
    group_id: Optional[str] = None,
    kind: Optional[str] = None,
) -> List[Dict[str, Any]]:
    _ensure_academy_tables()
    conn = db.connect()
    conn.row_factory = db.Row
    cur = conn.cursor()
    conditions: List[str] = [
        "m.user_id = ?",
        "m.status = 'active'",
        "lower(COALESCE(m.role, 'student')) IN ('teacher', 'admin')",
    ]
    params: List[Any] = [user_id]
    if group_id:
        conditions.append("a.group_id = ?")
        params.append(group_id)
    if kind:
        conditions.append("a.kind = ?")
        params.append(kind)
    cur.execute(
        f"""
        SELECT DISTINCT a.*
        FROM group_assignment a
        JOIN academy_group_member m ON m.group_id = a.group_id
        WHERE {' AND '.join(conditions)}
        ORDER BY a.created_at DESC
        """,
        params,
    )
    rows = cur.fetchall()
    conn.close()
    return [dict(r) for r in rows]


def list_my_assignments(user_id: str, kind: Optional[str] = None) -> List[Dict[str, Any]]:
    _ensure_academy_tables()
    conn = db.connect()
    conn.row_factory = db.Row
    cur = conn.cursor()
    params: List[Any] = [user_id]
    kind_sql = ""
    if kind:
        kind_sql = "AND a.kind = ?"
        params.append(kind)
    cur.execute(
        f"""
        SELECT
            a.*,
            s.submission_id,
            s.user_id AS submission_user_id,
            s.status AS submission_status,
            s.submitted_at,
            s.data_json
        FROM group_submission s
        JOIN group_assignment a ON a.assignment_id = s.assignment_id
        WHERE s.user_id = ?
        {kind_sql}
        ORDER BY COALESCE(a.due_date, a.created_at) ASC, a.created_at DESC
        """,
        params,
    )
    rows = cur.fetchall()
    conn.close()
    return [dict(r) for r in rows]


def update_assignment(
    assignment_id: str,
    *,
    title: Optional[str] = None,
    message: Optional[str] = None,
    due_date: Optional[str] = None,
) -> Optional[Dict[str, Any]]:
    _ensure_academy_tables()
    fields: List[str] = []
    values: List[Any] = []
    if title is not None:
        fields.append("title = ?")
        values.append(title)
    if message is not None:
        fields.append("message = ?")
        values.append(message)
    if due_date is not None:
        fields.append("due_date = ?")
        values.append(due_date)
    if not fields:
        return get_assignment(assignment_id)
    values.append(assignment_id)
    conn = db.connect()
    cur = conn.cursor()
    cur.execute(
        f"UPDATE group_assignment SET {', '.join(fields)} WHERE assignment_id = ?",
        values,
    )
    conn.commit()
    changed = cur.rowcount > 0
    conn.close()
    return get_assignment(assignment_id) if changed else None


def delete_assignment(assignment_id: str) -> bool:
    _ensure_academy_tables()
    conn = db.connect()
    cur = conn.cursor()
    cur.execute("DELETE FROM group_submission WHERE assignment_id = ?", (assignment_id,))
    cur.execute("DELETE FROM group_assignment WHERE assignment_id = ?", (assignment_id,))
    conn.commit()
    deleted = cur.rowcount > 0
    conn.close()
    return deleted


# ---------------------------------------------------------------------------
# StudentScheduleTask
# ---------------------------------------------------------------------------

def replace_student_schedule_tasks(
    *,
    user_id: str,
    tasks_by_date: Dict[str, List[str]],
    source: str = "student",
) -> List[Dict[str, Any]]:
    _ensure_academy_tables()
    now = _now_iso()
    clean: List[Dict[str, Any]] = []
    for date, titles in (tasks_by_date or {}).items():
        date_text = str(date or "").strip()
        if not date_text:
            continue
        for title in titles or []:
            title_text = str(title or "").strip()
            if not title_text:
                continue
            clean.append(
                {
                    "task_id": _generate_id(),
                    "user_id": user_id,
                    "date": date_text,
                    "title": title_text,
                    "source": source,
                    "created_at": now,
                    "updated_at": now,
                }
            )
    conn = db.connect()
    cur = conn.cursor()
    cur.execute(
        "DELETE FROM student_schedule_task WHERE user_id = ? AND source = ?",
        (user_id, source),
    )
    cur.executemany(
        """
        INSERT INTO student_schedule_task (
            task_id, user_id, date, title, source, created_at, updated_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        [
            (
                item["task_id"],
                item["user_id"],
                item["date"],
                item["title"],
                item["source"],
                item["created_at"],
                item["updated_at"],
            )
            for item in clean
        ],
    )
    conn.commit()
    conn.close()
    return clean


def list_student_schedule_tasks(
    *,
    user_id: str,
    limit: int = 100,
) -> List[Dict[str, Any]]:
    _ensure_academy_tables()
    conn = db.connect()
    conn.row_factory = db.Row
    cur = conn.cursor()
    cur.execute(
        """
        SELECT *
        FROM student_schedule_task
        WHERE user_id = ?
        ORDER BY date ASC, created_at ASC
        LIMIT ?
        """,
        (user_id, max(1, min(limit, 500))),
    )
    rows = cur.fetchall()
    conn.close()
    return [dict(r) for r in rows]


# ---------------------------------------------------------------------------
# GroupSubmission
# ---------------------------------------------------------------------------

def create_submission(
    *,
    assignment_id: str,
    user_id: str,
    data_json: Optional[str] = None,
) -> Dict[str, Any]:
    _ensure_academy_tables()
    submission_id = _generate_id()
    now = _now_iso()
    conn = db.connect()
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO group_submission (submission_id, assignment_id, user_id, status, submitted_at, data_json)
        VALUES (?, ?, ?, 'submitted', ?, ?)
        """,
        (submission_id, assignment_id, user_id, now, data_json),
    )
    conn.commit()
    conn.close()
    return {
        "submission_id": submission_id,
        "assignment_id": assignment_id,
        "user_id": user_id,
        "status": "submitted",
        "submitted_at": now,
        "data_json": data_json,
    }


def get_submission(submission_id: str) -> Optional[Dict[str, Any]]:
    _ensure_academy_tables()
    conn = db.connect()
    conn.row_factory = db.Row
    cur = conn.cursor()
    cur.execute("SELECT * FROM group_submission WHERE submission_id = ?", (submission_id,))
    row = cur.fetchone()
    conn.close()
    return dict(row) if row else None


def list_submissions(
    assignment_id: Optional[str] = None,
    user_id: Optional[str] = None,
    status: Optional[str] = None,
) -> List[Dict[str, Any]]:
    _ensure_academy_tables()
    conn = db.connect()
    conn.row_factory = db.Row
    cur = conn.cursor()
    conditions: List[str] = []
    params: List[Any] = []
    if assignment_id:
        conditions.append("assignment_id = ?")
        params.append(assignment_id)
    if user_id:
        conditions.append("user_id = ?")
        params.append(user_id)
    if status:
        conditions.append("status = ?")
        params.append(status)
    where = f"WHERE {' AND '.join(conditions)}" if conditions else ""
    cur.execute(
        f"SELECT * FROM group_submission {where} ORDER BY submitted_at DESC",
        params,
    )
    rows = cur.fetchall()
    conn.close()
    return [dict(r) for r in rows]


def list_submissions_for_teacher(
    *,
    teacher_user_id: str,
    assignment_id: Optional[str] = None,
    user_id: Optional[str] = None,
    status: Optional[str] = None,
) -> List[Dict[str, Any]]:
    _ensure_academy_tables()
    conn = db.connect()
    conn.row_factory = db.Row
    cur = conn.cursor()
    conditions: List[str] = [
        "m.user_id = ?",
        "m.status = 'active'",
        "lower(COALESCE(m.role, 'student')) IN ('teacher', 'admin')",
    ]
    params: List[Any] = [teacher_user_id]
    if assignment_id:
        conditions.append("s.assignment_id = ?")
        params.append(assignment_id)
    if user_id:
        conditions.append("s.user_id = ?")
        params.append(user_id)
    if status:
        conditions.append("s.status = ?")
        params.append(status)
    cur.execute(
        f"""
        SELECT s.*
        FROM group_submission s
        JOIN group_assignment a ON a.assignment_id = s.assignment_id
        JOIN academy_group_member m ON m.group_id = a.group_id
        WHERE {' AND '.join(conditions)}
        ORDER BY s.submitted_at DESC
        """,
        params,
    )
    rows = cur.fetchall()
    conn.close()
    return [dict(r) for r in rows]


def update_submission_status(
    submission_id: str,
    status: str,
    data_json: Optional[str] = None,
) -> Optional[Dict[str, Any]]:
    _ensure_academy_tables()
    now = _now_iso()
    conn = db.connect()
    cur = conn.cursor()
    if data_json is not None:
        cur.execute(
            "UPDATE group_submission SET status = ?, submitted_at = ?, data_json = ? WHERE submission_id = ?",
            (status, now, data_json, submission_id),
        )
    else:
        cur.execute(
            "UPDATE group_submission SET status = ?, submitted_at = ? WHERE submission_id = ?",
            (status, now, submission_id),
        )
    conn.commit()
    conn.close()
    return get_submission(submission_id)


# ---------------------------------------------------------------------------
# SubmissionReport
# ---------------------------------------------------------------------------

def create_submission_report(
    *,
    submission_id: str,
    correct_rate: Optional[float] = None,
    time_spent_seconds: Optional[int] = None,
    weak_tags: Optional[List[str]] = None,
    feedback: Optional[str] = None,
) -> Dict[str, Any]:
    _ensure_academy_tables()
    report_id = _generate_id()
    now = _now_iso()
    weak_tags_json = json.dumps(weak_tags, ensure_ascii=False) if weak_tags else None
    conn = db.connect()
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO submission_report (report_id, submission_id, correct_rate, time_spent_seconds, weak_tags_json, feedback, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        (report_id, submission_id, correct_rate, time_spent_seconds, weak_tags_json, feedback, now),
    )
    conn.commit()
    conn.close()
    return {
        "report_id": report_id,
        "submission_id": submission_id,
        "correct_rate": correct_rate,
        "time_spent_seconds": time_spent_seconds,
        "weak_tags": weak_tags,
        "feedback": feedback,
        "created_at": now,
    }


def get_submission_report(report_id: str) -> Optional[Dict[str, Any]]:
    _ensure_academy_tables()
    conn = db.connect()
    conn.row_factory = db.Row
    cur = conn.cursor()
    cur.execute("SELECT * FROM submission_report WHERE report_id = ?", (report_id,))
    row = cur.fetchone()
    conn.close()
    if row is None:
        return None
    d = dict(row)
    if d.get("weak_tags_json"):
        try:
            d["weak_tags"] = json.loads(d["weak_tags_json"])
        except json.JSONDecodeError:
            d["weak_tags"] = []
        del d["weak_tags_json"]
    return d


def get_report_by_submission(submission_id: str) -> Optional[Dict[str, Any]]:
    _ensure_academy_tables()
    conn = db.connect()
    conn.row_factory = db.Row
    cur = conn.cursor()
    cur.execute("SELECT * FROM submission_report WHERE submission_id = ?", (submission_id,))
    row = cur.fetchone()
    conn.close()
    if row is None:
        return None
    d = dict(row)
    if d.get("weak_tags_json"):
        try:
            d["weak_tags"] = json.loads(d["weak_tags_json"])
        except json.JSONDecodeError:
            d["weak_tags"] = []
        del d["weak_tags_json"]
    return d


def delete_submission_report(report_id: str) -> bool:
    _ensure_academy_tables()
    conn = db.connect()
    cur = conn.cursor()
    cur.execute("DELETE FROM submission_report WHERE report_id = ?", (report_id,))
    conn.commit()
    deleted = cur.rowcount > 0
    conn.close()
    return deleted


# ---------------------------------------------------------------------------
# TimetablePreference
# ---------------------------------------------------------------------------

def create_timetable_preference(
    *,
    group_id: str,
    user_id: str,
    day_of_week: str,
    time_slot: str,
    priority: int = 1,
) -> Dict[str, Any]:
    _ensure_academy_tables()
    preference_id = _generate_id()
    now = _now_iso()
    conn = db.connect()
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO timetable_preference (preference_id, group_id, user_id, day_of_week, time_slot, priority, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        (preference_id, group_id, user_id, day_of_week, time_slot, priority, now),
    )
    conn.commit()
    conn.close()
    return {
        "preference_id": preference_id,
        "group_id": group_id,
        "user_id": user_id,
        "day_of_week": day_of_week,
        "time_slot": time_slot,
        "priority": priority,
        "created_at": now,
    }


def list_timetable_preferences(
    group_id: Optional[str] = None,
    user_id: Optional[str] = None,
) -> List[Dict[str, Any]]:
    _ensure_academy_tables()
    conn = db.connect()
    conn.row_factory = db.Row
    cur = conn.cursor()
    conditions: List[str] = []
    params: List[Any] = []
    if group_id:
        conditions.append("group_id = ?")
        params.append(group_id)
    if user_id:
        conditions.append("user_id = ?")
        params.append(user_id)
    where = f"WHERE {' AND '.join(conditions)}" if conditions else ""
    cur.execute(
        f"SELECT * FROM timetable_preference {where} ORDER BY priority DESC, created_at DESC",
        params,
    )
    rows = cur.fetchall()
    conn.close()
    return [dict(r) for r in rows]


def get_timetable_preference(preference_id: str) -> Optional[Dict[str, Any]]:
    _ensure_academy_tables()
    conn = db.connect()
    conn.row_factory = db.Row
    cur = conn.cursor()
    cur.execute("SELECT * FROM timetable_preference WHERE preference_id = ?", (preference_id,))
    row = cur.fetchone()
    conn.close()
    return dict(row) if row else None


def delete_timetable_preference(preference_id: str) -> bool:
    _ensure_academy_tables()
    conn = db.connect()
    cur = conn.cursor()
    cur.execute("DELETE FROM timetable_preference WHERE preference_id = ?", (preference_id,))
    conn.commit()
    deleted = cur.rowcount > 0
    conn.close()
    return deleted


# ---------------------------------------------------------------------------
# TimetablePlan
# ---------------------------------------------------------------------------

def create_timetable_plan(
    *,
    group_id: str,
    plan_json: str,
    version: str = "v1",
) -> Dict[str, Any]:
    _ensure_academy_tables()
    plan_id = _generate_id()
    now = _now_iso()
    conn = db.connect()
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO timetable_plan (plan_id, group_id, plan_json, version, generated_at, applied)
        VALUES (?, ?, ?, ?, ?, 0)
        """,
        (plan_id, group_id, plan_json, version, now),
    )
    conn.commit()
    conn.close()
    return {
        "plan_id": plan_id,
        "group_id": group_id,
        "plan_json": plan_json,
        "version": version,
        "generated_at": now,
        "applied": False,
    }


def get_timetable_plan(plan_id: str) -> Optional[Dict[str, Any]]:
    _ensure_academy_tables()
    conn = db.connect()
    conn.row_factory = db.Row
    cur = conn.cursor()
    cur.execute("SELECT * FROM timetable_plan WHERE plan_id = ?", (plan_id,))
    row = cur.fetchone()
    conn.close()
    if row is None:
        return None
    d = dict(row)
    d["applied"] = bool(d.get("applied", 0))
    return d


def list_timetable_plans(group_id: str) -> List[Dict[str, Any]]:
    _ensure_academy_tables()
    conn = db.connect()
    conn.row_factory = db.Row
    cur = conn.cursor()
    cur.execute(
        "SELECT * FROM timetable_plan WHERE group_id = ? ORDER BY generated_at DESC",
        (group_id,),
    )
    rows = cur.fetchall()
    conn.close()
    result = []
    for r in rows:
        d = dict(r)
        d["applied"] = bool(d.get("applied", 0))
        result.append(d)
    return result


def apply_timetable_plan(plan_id: str) -> Optional[Dict[str, Any]]:
    """Mark a timetable plan as applied and update the group's schedule."""
    _ensure_academy_tables()
    conn = db.connect()
    cur = conn.cursor()
    # Get plan
    cur.execute("SELECT group_id, plan_json FROM timetable_plan WHERE plan_id = ?", (plan_id,))
    row = cur.fetchone()
    if row is None:
        conn.close()
        return None
    group_id, plan_json = row
    # Mark all plans for this group as not applied
    cur.execute(
        "UPDATE timetable_plan SET applied = 0 WHERE group_id = ?",
        (group_id,),
    )
    # Mark this plan as applied
    cur.execute(
        "UPDATE timetable_plan SET applied = 1 WHERE plan_id = ?",
        (plan_id,),
    )
    # Update group schedule
    cur.execute(
        "UPDATE academy_group SET schedule_json = ?, timetable_plan_json = ?, timetable_version = 'v1' WHERE group_id = ?",
        (plan_json, plan_json, group_id),
    )
    conn.commit()
    conn.close()
    return get_timetable_plan(plan_id)


def delete_timetable_plan(plan_id: str) -> bool:
    _ensure_academy_tables()
    conn = db.connect()
    cur = conn.cursor()
    cur.execute("DELETE FROM timetable_plan WHERE plan_id = ?", (plan_id,))
    conn.commit()
    deleted = cur.rowcount > 0
    conn.close()
    return deleted


# ---------------------------------------------------------------------------
# Timetable heuristic v1
# ---------------------------------------------------------------------------

def generate_timetable_heuristic_v1(group_id: str) -> Dict[str, Any]:
    """Generate a timetable plan using heuristic v1.

    Algorithm:
    1. Collect all preferences for the group
    2. Find time slots with maximum intersection (most members available)
    3. Minimize conflicts (avoid slots where few members are available)
    4. Prevent student over-concentration (max 2 sessions per day per student)
    5. Return plan with version/timestamp
    """
    _ensure_academy_tables()
    prefs = list_timetable_preferences(group_id=group_id)

    if not prefs:
        return {
            "group_id": group_id,
            "plan": [],
            "version": "v1",
            "message": "No preferences available",
        }

    # Aggregate preferences by (day, time_slot)
    from collections import defaultdict
    slot_votes = defaultdict(list)  # (day, slot) -> [(user_id, priority)]
    user_day_slots = defaultdict(lambda: defaultdict(list))  # user -> day -> [slots]

    for p in prefs:
        day = p["day_of_week"]
        slot = p["time_slot"]
        user = p["user_id"]
        priority = p.get("priority", 1)
        slot_votes[(day, slot)].append((user, priority))
        user_day_slots[user][day].append(slot)

    # Score each slot: sum of priorities, penalize over-concentration
    slot_scores = {}
    for (day, slot), voters in slot_votes.items():
        total_priority = sum(priority for _, priority in voters)
        unique_users = len(set(user for user, _ in voters))
        # Penalize if any user already has 2+ slots on this day
        over_concentration_penalty = 0
        for user, _ in voters:
            if len(user_day_slots[user].get(day, [])) >= 3:
                over_concentration_penalty += 5
        score = total_priority + unique_users * 2 - over_concentration_penalty
        slot_scores[(day, slot)] = {
            "day": day,
            "time_slot": slot,
            "score": score,
            "available_members": unique_users,
            "member_ids": list(set(user for user, _ in voters)),
        }

    # Sort by score descending, pick top slots ensuring no day has > 2 slots per user
    sorted_slots = sorted(slot_scores.values(), key=lambda x: x["score"], reverse=True)

    # Greedily select slots while respecting per-user per-day limit
    selected = []
    user_day_count = defaultdict(lambda: defaultdict(int))

    for slot in sorted_slots:
        day = slot["day"]
        can_add = True
        for user_id in slot["member_ids"]:
            if user_day_count[user_id][day] >= 2:
                can_add = False
                break
        if can_add:
            selected.append(slot)
            for user_id in slot["member_ids"]:
                user_day_count[user_id][day] += 1

    # Limit to reasonable number of sessions per week
    selected = selected[:10]

    plan = {
        "group_id": group_id,
        "sessions": [
            {
                "day": s["day"],
                "time_slot": s["time_slot"],
                "available_members": s["available_members"],
                "member_ids": s["member_ids"],
            }
            for s in selected
        ],
        "version": "v1",
        "generated_at": _now_iso(),
    }

    # Save plan
    plan_json = json.dumps(plan, ensure_ascii=False)
    create_timetable_plan(group_id=group_id, plan_json=plan_json, version="v1")

    return plan


# ---------------------------------------------------------------------------
# StudentOverviewSnapshot
# ---------------------------------------------------------------------------

def create_snapshot(
    *,
    user_id: str,
    academy_id: str,
    group_id: Optional[str] = None,
    overall_score: Optional[float] = None,
    attendance_rate: Optional[float] = None,
    tuition_status: Optional[str] = None,
    last_consult_note_id: Optional[str] = None,
    summary_json: Optional[str] = None,
) -> Dict[str, Any]:
    _ensure_academy_tables()
    snapshot_id = _generate_id()
    now = _now_iso()
    conn = db.connect()
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO student_overview_snapshot (snapshot_id, user_id, academy_id, group_id, overall_score, attendance_rate, tuition_status, last_consult_note_id, summary_json, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (snapshot_id, user_id, academy_id, group_id, overall_score, attendance_rate, tuition_status, last_consult_note_id, summary_json, now),
    )
    conn.commit()
    conn.close()
    return {
        "snapshot_id": snapshot_id,
        "user_id": user_id,
        "academy_id": academy_id,
        "group_id": group_id,
        "overall_score": overall_score,
        "attendance_rate": attendance_rate,
        "tuition_status": tuition_status,
        "last_consult_note_id": last_consult_note_id,
        "summary_json": summary_json,
        "created_at": now,
    }


def get_snapshot(snapshot_id: str) -> Optional[Dict[str, Any]]:
    _ensure_academy_tables()
    conn = db.connect()
    conn.row_factory = db.Row
    cur = conn.cursor()
    cur.execute("SELECT * FROM student_overview_snapshot WHERE snapshot_id = ?", (snapshot_id,))
    row = cur.fetchone()
    conn.close()
    return dict(row) if row else None


def list_snapshots(
    *,
    user_id: Optional[str] = None,
    academy_id: Optional[str] = None,
    group_id: Optional[str] = None,
    limit: int = 50,
) -> List[Dict[str, Any]]:
    _ensure_academy_tables()
    conn = db.connect()
    conn.row_factory = db.Row
    cur = conn.cursor()
    conditions: List[str] = []
    params: List[Any] = []
    if user_id:
        conditions.append("user_id = ?")
        params.append(user_id)
    if academy_id:
        conditions.append("academy_id = ?")
        params.append(academy_id)
    if group_id:
        conditions.append("group_id = ?")
        params.append(group_id)
    where = f"WHERE {' AND '.join(conditions)}" if conditions else ""
    cur.execute(
        f"SELECT * FROM student_overview_snapshot {where} ORDER BY created_at DESC LIMIT ?",
        (*params, limit),
    )
    rows = cur.fetchall()
    conn.close()
    return [dict(r) for r in rows]


def delete_snapshot(snapshot_id: str) -> bool:
    _ensure_academy_tables()
    conn = db.connect()
    cur = conn.cursor()
    cur.execute("DELETE FROM student_overview_snapshot WHERE snapshot_id = ?", (snapshot_id,))
    conn.commit()
    deleted = cur.rowcount > 0
    conn.close()
    return deleted


def build_student_overview(
    user_id: str,
    academy_id: str,
    group_id: Optional[str] = None,
) -> Dict[str, Any]:
    """Build a comprehensive student overview snapshot from multiple data sources.

    Aggregates:
    - Attendance stats (last 30 days)
    - Tuition status (current month)
    - Latest consult note
    - Placeholder for course progress, solve history, OVR (to be wired)
    """
    _ensure_academy_tables()
    now = datetime.now(timezone.utc)
    month_label = now.strftime("%Y-%m")

    # Attendance
    attendance_stats = {"attendance_rate": 0.0, "consecutive_attendance": 0}
    if group_id:
        attendance_stats = get_attendance_stats(user_id, group_id, days=30)

    # Tuition
    payments = list_tuition_payments(academy_id=academy_id, user_id=user_id, month_label=month_label)
    tuition_status = "paid" if payments else "unpaid"

    # Latest consult note
    notes = list_consult_notes(academy_id=academy_id, student_user_id=user_id)
    last_consult_note_id = notes[0]["note_id"] if notes else None

    summary = {
        "generated_at": now.isoformat(),
        "daily_login": True,  # placeholder
        "course_progress": {},  # placeholder - to be wired with course_storage
        "problem_solving_count": 0,  # placeholder - to be wired with solve_history
        "exam_solving_count": 0,  # placeholder - to be wired with exam_storage
        "daily_score": 0.0,  # placeholder
        "ovr_summary": {},  # placeholder
        "curriculum_achievements": [],  # placeholder
        "relocation_history": [],  # placeholder
        "attendance": attendance_stats,
        "tuition": {
            "month_label": month_label,
            "status": tuition_status,
        },
        "latest_consult": {
            "note_id": last_consult_note_id,
            "topic": notes[0]["topic"] if notes else None,
            "consulted_at": notes[0]["consulted_at"] if notes else None,
        } if notes else None,
    }

    snapshot = create_snapshot(
        user_id=user_id,
        academy_id=academy_id,
        group_id=group_id,
        overall_score=summary.get("daily_score"),
        attendance_rate=attendance_stats.get("attendance_rate"),
        tuition_status=tuition_status,
        last_consult_note_id=last_consult_note_id,
        summary_json=json.dumps(summary, ensure_ascii=False),
    )
    snapshot["summary"] = summary
    return snapshot
