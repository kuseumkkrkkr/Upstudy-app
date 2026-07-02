import json
import sqlite3
from typing import Any, Dict, List, Optional, Tuple

DB_PATH = "quests.db"


def _conn():
    return sqlite3.connect(DB_PATH)


def _ensure_column(conn: sqlite3.Connection, table: str, column: str, definition: str) -> None:
    """
    Adds missing column to an existing table (no-op if present).
    """
    cur = conn.cursor()
    cur.execute(f"PRAGMA table_info({table})")
    cols = [row[1] for row in cur.fetchall()]
    if column not in cols:
        cur.execute(f"ALTER TABLE {table} ADD COLUMN {definition}")
        conn.commit()


def init_course_db() -> None:
    conn = _conn()
    cur = conn.cursor()
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS course (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            description TEXT NOT NULL,
            difficulty TEXT NOT NULL,
            duration TEXT NOT NULL,
            tags TEXT NOT NULL,
            focus_tags TEXT NOT NULL,
            schedule TEXT,
            target_ovr INTEGER DEFAULT 0,
            textbook_id TEXT,
            textbook_pages INTEGER DEFAULT 0,
            is_demo INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER DEFAULT (strftime('%s','now')),
            updated_at INTEGER DEFAULT (strftime('%s','now'))
        )
        """
    )
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS course_unit (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            course_id TEXT NOT NULL,
            title TEXT NOT NULL,
            type TEXT NOT NULL,
            detail TEXT NOT NULL,
            estimated_minutes INTEGER DEFAULT 0,
            position INTEGER DEFAULT 0,
            FOREIGN KEY (course_id) REFERENCES course(id)
        )
        """
    )
    _ensure_column(conn, "course", "textbook_id", "textbook_id TEXT")
    _ensure_column(conn, "course", "textbook_pages", "textbook_pages INTEGER DEFAULT 0")
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS course_mission (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            unit_id INTEGER NOT NULL,
            title TEXT NOT NULL,
            detail TEXT NOT NULL,
            action_label TEXT NOT NULL DEFAULT 'Start',
            FOREIGN KEY (unit_id) REFERENCES course_unit(id)
        )
        """
    )
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS user_course (
            user_id TEXT NOT NULL,
            course_id TEXT NOT NULL,
            progress_json TEXT NOT NULL DEFAULT '{}',
            percent REAL NOT NULL DEFAULT 0.0,
            status TEXT NOT NULL DEFAULT 'enrolled',
            last_action TEXT,
            PRIMARY KEY (user_id, course_id),
            FOREIGN KEY (course_id) REFERENCES course(id)
        )
        """
    )
    _ensure_column(conn, "user_course", "sort_order", "sort_order INTEGER DEFAULT 0")
    conn.commit()
    conn.close()


def upsert_course(payload: Dict[str, Any], *, is_demo: bool = False) -> str:
    """
    Insert or update a course. Returns course_id.
    Required keys: id, title, description, difficulty, duration, tags (list), focus_tags (list),
    schedule (str | None), target_ovr (int), units (list of dicts with missions list).
    """
    init_course_db()
    cid = (payload.get("id") or "").strip()
    if not cid:
        raise ValueError("course id is required")
    title = payload.get("title") or ""
    desc = payload.get("description") or ""
    difficulty = payload.get("difficulty") or ""
    duration = payload.get("duration") or ""
    tags = payload.get("tags") or payload.get("description_tags") or []
    focus_tags = payload.get("focus_tags") or payload.get("description_tags") or []
    textbook_id = (payload.get("textbook_id") or "").strip()
    textbook_pages = int(payload.get("textbook_pages") or 0)
    schedule = payload.get("schedule")
    target_ovr = int(payload.get("target_ovr") or 0)
    units = payload.get("units") or []
    if not title or not desc or not difficulty or not duration:
        raise ValueError("missing required course fields")
    if not textbook_id:
        raise ValueError("textbook_id is required")
    if not isinstance(units, list) or len(units) == 0:
        raise ValueError("at least one unit is required")
    # Ensure there is at least one mission across the course (필수 동작 한 개 이상)
    has_mission = False
    for unit in units:
        missions = unit.get("missions") or []
        if missions:
            has_mission = True
            break
    if not has_mission:
        raise ValueError("each course requires at least one mission")

    conn = _conn()
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO course (id, title, description, difficulty, duration, tags, focus_tags, schedule, target_ovr, textbook_id, textbook_pages, is_demo, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, strftime('%s','now'), strftime('%s','now'))
        ON CONFLICT(id) DO UPDATE SET
            title=excluded.title,
            description=excluded.description,
            difficulty=excluded.difficulty,
            duration=excluded.duration,
            tags=excluded.tags,
            focus_tags=excluded.focus_tags,
            schedule=excluded.schedule,
            target_ovr=excluded.target_ovr,
            textbook_id=excluded.textbook_id,
            textbook_pages=excluded.textbook_pages,
            is_demo=excluded.is_demo,
            updated_at=strftime('%s','now')
        """,
        (
            cid,
            title,
            desc,
            difficulty,
            duration,
            json.dumps(tags, ensure_ascii=False),
            json.dumps(focus_tags, ensure_ascii=False),
            schedule,
            target_ovr,
            textbook_id,
            textbook_pages,
            1 if is_demo else 0,
        ),
    )
    # Replace units
    cur.execute("DELETE FROM course_mission WHERE unit_id IN (SELECT id FROM course_unit WHERE course_id = ?)", (cid,))
    cur.execute("DELETE FROM course_unit WHERE course_id = ?", (cid,))
    for idx, unit in enumerate(units):
        cur.execute(
            """
            INSERT INTO course_unit (course_id, title, type, detail, estimated_minutes, position)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (
                cid,
                unit.get("title") or "",
                unit.get("type") or "",
                unit.get("detail") or "",
                int(unit.get("estimated_minutes") or 0),
                idx,
            ),
        )
        unit_id = cur.lastrowid
        for mission in unit.get("missions") or []:
            cur.execute(
                """
                INSERT INTO course_mission (unit_id, title, detail, action_label)
                VALUES (?, ?, ?, ?)
                """,
                (
                    unit_id,
                    mission.get("title") or "",
                    mission.get("detail") or "",
                    mission.get("action_label") or "Start",
                ),
            )
    conn.commit()
    conn.close()
    return cid


def list_courses(
    *,
    query: Optional[str] = None,
    tag: Optional[str] = None,
    limit: int = 50,
    recommend_for_ovr: Optional[float] = None,
) -> List[Dict[str, Any]]:
    init_course_db()
    conn = _conn()
    cur = conn.cursor()
    cur.execute(
        """
        SELECT id, title, description, difficulty, duration, tags, focus_tags, schedule, target_ovr, textbook_id, textbook_pages, is_demo
        FROM course
        ORDER BY updated_at DESC
        """
    )
    rows = cur.fetchall()
    conn.close()
    results: List[Dict[str, Any]] = []
    q_norm = (query or "").strip().lower()
    tag_norm = (tag or "").strip().lower()
    for row in rows:
        tags = json.loads(row[5]) if row[5] else []
        if q_norm and q_norm not in row[1].lower() and q_norm not in row[2].lower():
            continue
        if tag_norm:
            tag_hit = False
            for t in tags:
                if tag_norm in str(t).lower():
                    tag_hit = True
                    break
            if not tag_hit:
                continue
        results.append(
            {
                "id": row[0],
                "title": row[1],
                "description": row[2],
                "difficulty": row[3],
                "duration": row[4],
                "tags": tags,
                "focus_tags": json.loads(row[6]) if row[6] else [],
                "schedule": row[7],
                "target_ovr": row[8] or 0,
                "textbook_id": row[9] or "",
                "textbook_pages": int(row[10] or 0),
                "is_demo": bool(row[11]),
            }
        )
    if recommend_for_ovr is not None:
        results.sort(key=lambda c: abs((c.get("target_ovr") or 0) - recommend_for_ovr))
    return results[: limit or 50]


def get_course(course_id: str) -> Optional[Dict[str, Any]]:
    init_course_db()
    conn = _conn()
    cur = conn.cursor()
    cur.execute(
        """
        SELECT id, title, description, difficulty, duration, tags, focus_tags, schedule, target_ovr, textbook_id, textbook_pages, is_demo
        FROM course WHERE id = ?
        """,
        (course_id,),
    )
    row = cur.fetchone()
    if not row:
        conn.close()
        return None
    cur.execute(
        "SELECT id, title, type, detail, estimated_minutes FROM course_unit WHERE course_id = ? ORDER BY position ASC, id ASC",
        (course_id,),
    )
    units_raw = cur.fetchall()
    units: List[Dict[str, Any]] = []
    for u in units_raw:
        cur.execute(
            "SELECT id, title, detail, action_label FROM course_mission WHERE unit_id = ? ORDER BY id ASC",
            (u[0],),
        )
        missions = [
            {"mission_id": m[0], "title": m[1], "detail": m[2], "action_label": m[3]}
            for m in cur.fetchall()
        ]
        units.append(
            {
                "unit_id": u[0],
                "title": u[1],
                "type": u[2],
                "detail": u[3],
                "estimated_minutes": u[4],
                "missions": missions,
            }
        )
    conn.close()
    return {
        "id": row[0],
        "title": row[1],
        "description": row[2],
        "difficulty": row[3],
        "duration": row[4],
        "tags": json.loads(row[5]) if row[5] else [],
        "focus_tags": json.loads(row[6]) if row[6] else [],
        "schedule": row[7],
        "target_ovr": row[8] or 0,
        "textbook_id": row[9] or "",
        "textbook_pages": int(row[10] or 0),
        "is_demo": bool(row[11]),
        "units": units,
    }


def enroll_course(user_id: str, course_id: str) -> Dict[str, Any]:
    init_course_db()
    conn = _conn()
    cur = conn.cursor()
    cur.execute(
        "SELECT COUNT(*) FROM user_course WHERE user_id = ?",
        (user_id,),
    )
    row = cur.fetchone()
    current_count = int(row[0] if row and row[0] is not None else 0)
    if current_count >= 4:
        conn.close()
        raise ValueError("course_limit_exceeded")

    cur.execute(
        "SELECT COALESCE(MAX(sort_order), -1) FROM user_course WHERE user_id = ?",
        (user_id,),
    )
    max_order_row = cur.fetchone()
    next_order = int(max_order_row[0] if max_order_row and max_order_row[0] is not None else -1) + 1
    cur.execute(
        """
        INSERT INTO user_course (user_id, course_id, progress_json, percent, status, last_action, sort_order)
        VALUES (?, ?, '{}', 0.0, 'enrolled', NULL, ?)
        ON CONFLICT(user_id, course_id) DO NOTHING
        """,
        (user_id, course_id, next_order),
    )
    conn.commit()
    cur.execute(
        "SELECT progress_json, percent, status, last_action FROM user_course WHERE user_id = ? AND course_id = ?",
        (user_id, course_id),
    )
    row = cur.fetchone()
    conn.close()
    if not row:
        raise ValueError("failed to enroll")
    return {
        "course_id": course_id,
        "progress": json.loads(row[0]) if row[0] else {},
        "percent": float(row[1] or 0.0),
        "status": row[2] or "enrolled",
        "last_action": row[3],
    }


def list_enrollments(user_id: str) -> List[Dict[str, Any]]:
    init_course_db()
    conn = _conn()
    cur = conn.cursor()
    # One-time validation on read:
    # if a course was deleted from server DB, remove stale enrollment rows.
    cur.execute(
        """
        DELETE FROM user_course
        WHERE user_id = ?
          AND course_id NOT IN (SELECT id FROM course)
        """,
        (user_id,),
    )
    conn.commit()
    cur.execute(
        """
        SELECT course_id, progress_json, percent, status, last_action, sort_order
        FROM user_course WHERE user_id = ?
        ORDER BY sort_order ASC, percent DESC, course_id ASC
        """,
        (user_id,),
    )
    rows = cur.fetchall()
    conn.close()
    return [
        {
            "course_id": r[0],
            "progress": json.loads(r[1]) if r[1] else {},
            "percent": float(r[2] or 0.0),
            "status": r[3] or "enrolled",
            "last_action": r[4],
            "sort_order": r[5],
        }
        for r in rows
    ]


def drop_enrollment(user_id: str, course_id: str) -> None:
    init_course_db()
    conn = _conn()
    cur = conn.cursor()
    cur.execute(
        "DELETE FROM user_course WHERE user_id = ? AND course_id = ?",
        (user_id, course_id),
    )
    conn.commit()
    conn.close()


def reorder_enrollments(user_id: str, course_ids: List[str]) -> None:
    init_course_db()
    conn = _conn()
    cur = conn.cursor()
    conn.execute("BEGIN")
    try:
        for idx, cid in enumerate(course_ids):
            cur.execute(
                """
                UPDATE user_course
                SET sort_order = ?
                WHERE user_id = ? AND course_id = ?
                """,
                (idx, user_id, cid),
            )
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def get_enrollment(user_id: str, course_id: str) -> Optional[Dict[str, Any]]:
    init_course_db()
    conn = _conn()
    cur = conn.cursor()
    cur.execute(
        """
        SELECT course_id, progress_json, percent, status, last_action
        FROM user_course
        WHERE user_id = ? AND course_id = ?
        LIMIT 1
        """,
        (user_id, course_id),
    )
    row = cur.fetchone()
    conn.close()
    if not row:
        return None
    return {
        "course_id": row[0],
        "progress": json.loads(row[1]) if row[1] else {},
        "percent": float(row[2] or 0.0),
        "status": row[3] or "enrolled",
        "last_action": row[4],
    }


def update_unit_detail(unit_id: int, detail: str) -> None:
    init_course_db()
    conn = _conn()
    cur = conn.cursor()
    cur.execute(
        "UPDATE course_unit SET detail = ? WHERE id = ?",
        (detail, unit_id),
    )
    conn.commit()
    conn.close()


def update_mission_detail(mission_id: int, detail: str) -> None:
    init_course_db()
    conn = _conn()
    cur = conn.cursor()
    cur.execute(
        "UPDATE course_mission SET detail = ? WHERE id = ?",
        (detail, mission_id),
    )
    conn.commit()
    conn.close()


def update_progress(user_id: str, course_id: str, progress: Dict[str, Any], percent: float, last_action: Optional[str] = None) -> Dict[str, Any]:
    init_course_db()
    conn = _conn()
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO user_course (user_id, course_id, progress_json, percent, status, last_action)
        VALUES (?, ?, ?, ?, 'enrolled', ?)
        ON CONFLICT(user_id, course_id) DO UPDATE SET
            progress_json = excluded.progress_json,
            percent = excluded.percent,
            last_action = excluded.last_action,
            status = excluded.status
        """,
        (user_id, course_id, json.dumps(progress, ensure_ascii=False), percent, last_action),
    )
    conn.commit()
    conn.close()
    return {
        "course_id": course_id,
        "progress": progress,
        "percent": percent,
        "last_action": last_action,
        "status": "enrolled",
    }
