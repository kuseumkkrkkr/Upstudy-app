import json
import sqlite3
from datetime import datetime, timedelta
from typing import Optional, Dict, Any

from storage.storage import DB_PATH


_TTL_DAYS = 7


def _now_iso() -> str:
    return datetime.utcnow().isoformat(timespec="seconds") + "Z"


def _cutoff_iso() -> str:
    return (datetime.utcnow() - timedelta(days=_TTL_DAYS)).isoformat(timespec="seconds") + "Z"


def init_continue_db() -> None:
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS continue_session (
            user_id TEXT NOT NULL,
            kind TEXT NOT NULL,        -- problem | exam
            target_id TEXT NOT NULL,   -- quest_id or exam_id
            strokes TEXT NOT NULL,     -- JSON string (list of strokes)
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            PRIMARY KEY (user_id, kind)
        )
        """
    )
    cur.execute(
        "CREATE INDEX IF NOT EXISTS idx_continue_session_user ON continue_session (user_id, updated_at DESC)"
    )
    conn.commit()
    conn.close()


def _purge_expired(cur: sqlite3.Cursor, user_id: str) -> None:
    cur.execute(
        "DELETE FROM continue_session WHERE user_id = ? AND updated_at < ?",
        (user_id, _cutoff_iso()),
    )


def save_strokes(
    *,
    user_id: str,
    kind: str,
    target_id: str,
    strokes: Any,
) -> None:
    init_continue_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    _purge_expired(cur, user_id)
    now = _now_iso()
    cur.execute(
        """
        INSERT INTO continue_session (user_id, kind, target_id, strokes, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(user_id, kind) DO UPDATE SET
            target_id = excluded.target_id,
            strokes = excluded.strokes,
            updated_at = excluded.updated_at
        """,
        (user_id, kind, target_id, json.dumps(strokes, ensure_ascii=False), now, now),
    )
    conn.commit()
    conn.close()


def load_strokes(*, user_id: str, kind: str, target_id: str) -> Optional[Dict[str, Any]]:
    init_continue_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    _purge_expired(cur, user_id)
    cur.execute(
        """
        SELECT target_id, strokes, updated_at
        FROM continue_session
        WHERE user_id = ? AND kind = ?
        LIMIT 1
        """,
        (user_id, kind),
    )
    row = cur.fetchone()
    if not row:
        conn.commit()
        conn.close()
        return None
    saved_target, strokes_json, updated_at = row
    conn.commit()
    conn.close()
    if saved_target != target_id:
        return None
    try:
        strokes = json.loads(strokes_json)
    except Exception:
        strokes = []
    return {"target_id": saved_target, "strokes": strokes, "updated_at": updated_at}


def delete_strokes(*, user_id: str, kind: str, target_id: Optional[str] = None) -> None:
    init_continue_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    if target_id:
        cur.execute(
            "DELETE FROM continue_session WHERE user_id = ? AND kind = ? AND target_id = ?",
            (user_id, kind, target_id),
        )
    else:
        cur.execute("DELETE FROM continue_session WHERE user_id = ? AND kind = ?", (user_id, kind))
    conn.commit()
    conn.close()
