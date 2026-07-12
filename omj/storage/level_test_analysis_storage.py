import json
import sqlite3
from datetime import datetime, timedelta
from typing import Any, Optional

from storage.storage import DB_PATH


_RETENTION_DAYS = 7
_MAX_SESSIONS_PER_USER = 200


def _now_iso() -> str:
    return datetime.utcnow().isoformat(timespec="seconds") + "Z"


def _cutoff(days: int = _RETENTION_DAYS) -> str:
    return (datetime.utcnow() - timedelta(days=days)).isoformat(timespec="seconds") + "Z"


def init_level_test_analysis_db() -> None:
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS level_test_analysis_session (
            session_id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            course_id TEXT NOT NULL,
            module_id TEXT NOT NULL,
            exam_id TEXT,
            exam_title TEXT,
            created_at TEXT NOT NULL,
            expires_at TEXT NOT NULL,
            correct_count INTEGER NOT NULL DEFAULT 0,
            total_count INTEGER NOT NULL DEFAULT 0,
            accuracy REAL NOT NULL DEFAULT 0,
            passed INTEGER NOT NULL DEFAULT 0,
            elapsed_seconds INTEGER NOT NULL DEFAULT 0,
            tags_json TEXT NOT NULL DEFAULT '[]',
            summary_json TEXT NOT NULL DEFAULT '{}',
            raw_json TEXT NOT NULL DEFAULT '{}'
        )
        """
    )
    cur.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_level_test_analysis_user_created
        ON level_test_analysis_session(user_id, created_at DESC)
        """
    )
    cur.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_level_test_analysis_expiry
        ON level_test_analysis_session(expires_at)
        """
    )
    conn.commit()
    conn.close()


def purge_expired_level_test_analysis(user_id: Optional[str] = None) -> None:
    init_level_test_analysis_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    if user_id:
        cur.execute(
            "DELETE FROM level_test_analysis_session WHERE user_id = ? AND expires_at < ?",
            (user_id, _now_iso()),
        )
        cur.execute(
            """
            DELETE FROM level_test_analysis_session
            WHERE session_id IN (
              SELECT session_id FROM level_test_analysis_session
              WHERE user_id = ?
              ORDER BY datetime(created_at) DESC
              LIMIT -1 OFFSET ?
            )
            """,
            (user_id, _MAX_SESSIONS_PER_USER),
        )
    else:
        cur.execute("DELETE FROM level_test_analysis_session WHERE expires_at < ?", (_now_iso(),))
    conn.commit()
    conn.close()


def _problem_items(raw: dict[str, Any]) -> list[dict[str, Any]]:
    items = raw.get("problem_results")
    if not isinstance(items, list):
        return []
    return [item for item in items if isinstance(item, dict)]


def _summary_from_payload(payload: dict[str, Any]) -> dict[str, Any]:
    problems = _problem_items(payload)
    incorrect = [item for item in problems if item.get("is_correct") is False]
    tags: dict[str, int] = {}
    for item in incorrect:
        for tag in item.get("tags") or []:
            tag_text = str(tag).strip()
            if tag_text:
                tags[tag_text] = tags.get(tag_text, 0) + 1
    weak_tags = [
        {"tag": tag, "incorrect_count": count}
        for tag, count in sorted(tags.items(), key=lambda entry: (-entry[1], entry[0]))[:12]
    ]
    return {
        "course_id": str(payload.get("course_id") or ""),
        "module_id": str(payload.get("module_id") or ""),
        "exam_id": str(payload.get("exam_id") or ""),
        "exam_title": str(payload.get("exam_title") or ""),
        "correct_count": int(payload.get("correct_count") or 0),
        "total_count": int(payload.get("total_count") or 0),
        "accuracy": float(payload.get("accuracy") or 0),
        "passed": bool(payload.get("passed")),
        "elapsed_seconds": int(payload.get("elapsed_seconds") or 0),
        "incorrect_count": len(incorrect),
        "weak_tags": weak_tags,
        "analysis_model": str(payload.get("analysis_model") or "gemma-4"),
        "ai_summary": payload.get("ai_summary") if isinstance(payload.get("ai_summary"), dict) else {},
    }


def save_level_test_analysis_session(
    *,
    user_id: str,
    session_id: str,
    payload: dict[str, Any],
    retention_days: int = _RETENTION_DAYS,
) -> dict[str, Any]:
    init_level_test_analysis_db()
    retention_days = max(1, min(int(retention_days or _RETENTION_DAYS), _RETENTION_DAYS))
    created_at = str(payload.get("created_at") or _now_iso())
    expires_at = (datetime.utcnow() + timedelta(days=retention_days)).isoformat(timespec="seconds") + "Z"
    summary = _summary_from_payload(payload)
    tags = payload.get("tags")
    if not isinstance(tags, list):
        tags = []
    correct_count = int(payload.get("correct_count") or 0)
    total_count = int(payload.get("total_count") or 0)
    accuracy = float(payload.get("accuracy") or (correct_count / total_count * 100 if total_count else 0))

    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        INSERT OR REPLACE INTO level_test_analysis_session (
            session_id, user_id, course_id, module_id, exam_id, exam_title,
            created_at, expires_at, correct_count, total_count, accuracy,
            passed, elapsed_seconds, tags_json, summary_json, raw_json
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            session_id,
            user_id,
            str(payload.get("course_id") or ""),
            str(payload.get("module_id") or ""),
            str(payload.get("exam_id") or ""),
            str(payload.get("exam_title") or ""),
            created_at,
            expires_at,
            correct_count,
            total_count,
            accuracy,
            1 if bool(payload.get("passed")) else 0,
            int(payload.get("elapsed_seconds") or 0),
            json.dumps(tags, ensure_ascii=False),
            json.dumps(summary, ensure_ascii=False),
            json.dumps(payload, ensure_ascii=False),
        ),
    )
    conn.commit()
    conn.close()
    purge_expired_level_test_analysis(user_id)
    return {"session_id": session_id, "expires_at": expires_at, "summary": summary}


def list_level_test_analysis_summaries(user_id: str, *, limit: int = 20) -> list[dict[str, Any]]:
    init_level_test_analysis_db()
    purge_expired_level_test_analysis(user_id)
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        SELECT session_id, created_at, expires_at, summary_json
        FROM level_test_analysis_session
        WHERE user_id = ?
        ORDER BY datetime(created_at) DESC
        LIMIT ?
        """,
        (user_id, max(1, min(limit, 100))),
    )
    rows = cur.fetchall()
    conn.close()
    out: list[dict[str, Any]] = []
    for session_id, created_at, expires_at, summary_text in rows:
        try:
            summary = json.loads(summary_text)
        except Exception:
            summary = {}
        if not isinstance(summary, dict):
            summary = {}
        out.append(
            {
                "session_id": session_id,
                "created_at": created_at,
                "expires_at": expires_at,
                **summary,
            }
        )
    return out
