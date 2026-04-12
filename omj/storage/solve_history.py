import json
import sqlite3
from datetime import datetime, timedelta
from typing import Any, Dict, Optional

from storage.storage import DB_PATH


_RETENTION_FULL_DAYS = 30
_RETENTION_MAX_DAYS = 150


def _now_iso() -> str:
    return datetime.utcnow().isoformat(timespec="seconds") + "Z"


def _cutoff(days: int) -> str:
    return (datetime.utcnow() - timedelta(days=days)).isoformat(timespec="seconds") + "Z"


def init_solve_history_db() -> None:
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS solve_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            kind TEXT NOT NULL, -- problem | exam
            quest_id TEXT,
            exam_id TEXT,
            codebase_id INTEGER,
            seed INTEGER,
            created_at TEXT NOT NULL,
            data TEXT NOT NULL,
            compressed INTEGER NOT NULL DEFAULT 0
        )
        """
    )
    cur.execute(
        "CREATE INDEX IF NOT EXISTS idx_solve_history_user_created ON solve_history (user_id, created_at DESC)"
    )
    conn.commit()
    conn.close()


def _compress_payload(raw: Dict[str, Any]) -> Dict[str, Any]:
    """Keep only lightweight fields for long-term storage."""
    return {
        "status": raw.get("status"),
        "in_panic": raw.get("in_panic"),
        "ai_opinion": raw.get("ai_opinion"),
        "quest_id": raw.get("quest_id"),
        "quest_model": raw.get("quest_model"),
        "exam_id": raw.get("exam_id"),
        "codebase_id": raw.get("codebase_id"),
        "seed": raw.get("seed"),
        "all_formulas": raw.get("all_formulas"),
        "ocr_all_formulas": raw.get("ocr_all_formulas"),
        "ocr_purple_formulas": raw.get("ocr_purple_formulas"),
    }


def _purge_and_compress(user_id: str, *, delete_after_max: bool = True) -> None:
    init_solve_history_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    # Compress entries older than 30 days but newer than 150 days
    cutoff_full = _cutoff(_RETENTION_FULL_DAYS)
    cutoff_max = _cutoff(_RETENTION_MAX_DAYS)
    cur.execute(
        """
        SELECT id, data FROM solve_history
        WHERE user_id = ? AND compressed = 0 AND created_at < ? AND created_at >= ?
        """,
        (user_id, cutoff_full, cutoff_max),
    )
    rows = cur.fetchall()
    for row_id, data_text in rows:
        try:
            data = json.loads(data_text)
        except Exception:
            continue
        compressed = _compress_payload(data)
        cur.execute(
            "UPDATE solve_history SET data = ?, compressed = 1 WHERE id = ?",
            (json.dumps(compressed, ensure_ascii=False), row_id),
        )

    # Delete anything older than 150 days (server-side policy; skip for local-only mode)
    if delete_after_max:
        cur.execute(
            "DELETE FROM solve_history WHERE user_id = ? AND created_at < ?",
            (user_id, cutoff_max),
        )
    conn.commit()
    conn.close()


def save_solve_history(
    *,
    user_id: str,
    kind: str,
    quest_id: Optional[str] = None,
    exam_id: Optional[str] = None,
    codebase_id: Optional[int] = None,
    seed: Optional[int] = None,
    payload: Dict[str, Any],
    created_at: Optional[str] = None,
    delete_after_max: bool = True,
) -> None:
    """Persist full solve payload then enforce retention/compression policy."""
    init_solve_history_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO solve_history (
            user_id, kind, quest_id, exam_id, codebase_id, seed, created_at, data, compressed
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0)
        """,
        (
            user_id,
            kind,
            quest_id,
            exam_id,
            codebase_id,
            seed,
            created_at or _now_iso(),
            json.dumps(payload, ensure_ascii=False),
        ),
    )
    conn.commit()
    conn.close()
    _purge_and_compress(user_id, delete_after_max=delete_after_max)


def is_latest_fully_correct(
    *,
    user_id: str,
    kind: str,
    quest_id: Optional[str] = None,
    exam_id: Optional[str] = None,
) -> bool:
    """
    Check the most recent solve record for the given target and see if all steps were correct.
    """
    init_solve_history_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    where = ["user_id = ?", "kind = ?"]
    params: list[Any] = [user_id, kind]
    if quest_id:
        where.append("quest_id = ?")
        params.append(quest_id)
    if exam_id:
        where.append("exam_id = ?")
        params.append(exam_id)
    cur.execute(
        f"""
        SELECT data
        FROM solve_history
        WHERE {" AND ".join(where)}
        ORDER BY datetime(created_at) DESC
        LIMIT 1
        """,
        params,
    )
    row = cur.fetchone()
    conn.close()
    if not row:
        return False
    try:
        data = json.loads(row[0])
    except Exception:
        return False
    status_list = data.get("status")
    if not isinstance(status_list, list) or not status_list:
        return False
    try:
        return all((str(item.get("status")).upper() == "O") for item in status_list if isinstance(item, dict))
    except Exception:
        return False
