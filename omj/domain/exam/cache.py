"""SQLite-backed cache for exam layouts.

Look-ups are keyed by ``(course_id, seed)``.  Entries older than 24 hours are
ignored and deleted (TTL eviction).  Uses the shared ``quests.db`` file.
"""
import sqlite3
from datetime import datetime, timedelta, timezone
from typing import Optional

from domain.exam.layout_engine import deserialize_layout, serialize_layout
from domain.exam.models import ExamPaperLayout
from domain.exam.repository import _ensure_exam_tables
from storage.storage import DB_PATH


_TTL_HOURS = 24


def get_cached_layout(course_id: int, seed: int) -> Optional[ExamPaperLayout]:
    """Return a cached layout if present and not expired."""
    _ensure_exam_tables()
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    cur.execute(
        """
        SELECT layout_json, created_at
        FROM exam_layout_cache
        WHERE course_id = ? AND seed = ?
        """,
        (course_id, seed),
    )
    row = cur.fetchone()
    if row is None:
        conn.close()
        return None

    created_at = row["created_at"]
    if _is_expired(created_at):
        cur.execute(
            "DELETE FROM exam_layout_cache WHERE course_id = ? AND seed = ?",
            (course_id, seed),
        )
        conn.commit()
        conn.close()
        return None

    conn.close()
    return deserialize_layout(row["layout_json"])


def set_cached_layout(course_id: int, seed: int, layout: ExamPaperLayout) -> None:
    """Store *layout* under the ``(course_id, seed)`` key."""
    _ensure_exam_tables()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    now = datetime.now(timezone.utc).isoformat()
    cur.execute(
        """
        INSERT INTO exam_layout_cache (course_id, seed, layout_json, created_at)
        VALUES (?, ?, ?, ?)
        ON CONFLICT(course_id, seed) DO UPDATE SET
            layout_json = excluded.layout_json,
            created_at = excluded.created_at
        """,
        (course_id, seed, serialize_layout(layout), now),
    )
    conn.commit()
    conn.close()


def _is_expired(created_at: str) -> bool:
    try:
        # Python 3.11+ fromisoformat handles timezone-aware ISO strings
        dt = datetime.fromisoformat(created_at)
    except ValueError:
        return True
    # If naive, assume UTC
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    cutoff = datetime.now(timezone.utc) - timedelta(hours=_TTL_HOURS)
    return dt < cutoff
