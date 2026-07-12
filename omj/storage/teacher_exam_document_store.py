from __future__ import annotations

import sqlite3
from datetime import datetime
from typing import Any, Dict, List, Optional

from storage.storage import DB_PATH


def _now_iso() -> str:
    return datetime.utcnow().isoformat(timespec="seconds") + "Z"


def init_teacher_exam_document_db() -> None:
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS teacher_exam_document (
                user_id TEXT NOT NULL,
                exam_id TEXT NOT NULL,
                title TEXT NOT NULL DEFAULT '',
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                PRIMARY KEY (user_id, exam_id)
            )
            """
        )
        conn.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_teacher_exam_document_user_updated
            ON teacher_exam_document(user_id, updated_at DESC)
            """
        )
        conn.commit()


def upsert_teacher_exam_document(
    user_id: str,
    exam_id: str,
    title: Optional[str] = None,
) -> Dict[str, Any]:
    init_teacher_exam_document_db()
    user_value = (user_id or "").strip()
    exam_value = (exam_id or "").strip()
    if not user_value:
        raise ValueError("user_id required")
    if not exam_value:
        raise ValueError("exam_id required")

    now = _now_iso()
    title_value = (title or "").strip() or "시험지"
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute(
            """
            INSERT INTO teacher_exam_document (user_id, exam_id, title, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(user_id, exam_id) DO UPDATE SET
                title = excluded.title,
                updated_at = excluded.updated_at
            """,
            (user_value, exam_value, title_value, now, now),
        )
        conn.commit()
    return {
        "user_id": user_value,
        "exam_id": exam_value,
        "title": title_value,
        "updated_at": now,
    }


def has_teacher_exam_document(user_id: str, exam_id: str) -> bool:
    init_teacher_exam_document_db()
    user_value = (user_id or "").strip()
    exam_value = (exam_id or "").strip()
    if not user_value or not exam_value:
        return False
    with sqlite3.connect(DB_PATH) as conn:
        row = conn.execute(
            """
            SELECT 1
            FROM teacher_exam_document
            WHERE user_id = ? AND exam_id = ?
            """,
            (user_value, exam_value),
        ).fetchone()
    return row is not None


def list_teacher_exam_documents(
    user_id: str,
    *,
    limit: int = 200,
) -> List[Dict[str, Any]]:
    init_teacher_exam_document_db()
    user_value = (user_id or "").strip()
    if not user_value:
        return []
    safe_limit = max(1, min(int(limit), 500))
    with sqlite3.connect(DB_PATH) as conn:
        rows = conn.execute(
            """
            SELECT exam_id, title, created_at, updated_at
            FROM teacher_exam_document
            WHERE user_id = ?
            ORDER BY updated_at DESC, exam_id ASC
            LIMIT ?
            """,
            (user_value, safe_limit),
        ).fetchall()
    return [
        {
            "exam_id": str(row[0]),
            "title": str(row[1] or ""),
            "created_at": str(row[2] or ""),
            "updated_at": str(row[3] or ""),
        }
        for row in rows
    ]
