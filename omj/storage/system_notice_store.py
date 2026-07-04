from __future__ import annotations

import sqlite3
import uuid
from datetime import datetime
from typing import Dict, List

from storage.storage import DB_PATH


def _now_iso() -> str:
    return datetime.utcnow().isoformat(timespec="seconds") + "Z"


def init_system_notice_db() -> None:
    conn = sqlite3.connect(DB_PATH)
    try:
        cur = conn.cursor()
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS system_notice (
                notice_id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                content_html TEXT NOT NULL,
                created_by_user_id TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """
        )
        cur.execute(
            "CREATE UNIQUE INDEX IF NOT EXISTS idx_system_notice_title "
            "ON system_notice (title)"
        )
        cur.execute(
            "CREATE INDEX IF NOT EXISTS idx_system_notice_updated "
            "ON system_notice (updated_at DESC)"
        )
        conn.commit()
    finally:
        conn.close()


def upsert_system_notice(
    *,
    title: str,
    content_html: str,
    created_by_user_id: str,
) -> Dict[str, object]:
    init_system_notice_db()
    clean_title = (title or "").strip()
    clean_content = (content_html or "").strip()
    if not clean_title:
        raise ValueError("title is required")
    if not clean_content:
        raise ValueError("content_html is required")

    now = _now_iso()
    conn = sqlite3.connect(DB_PATH)
    try:
        cur = conn.cursor()
        cur.execute(
            """
            SELECT notice_id, created_at
            FROM system_notice
            WHERE title = ?
            LIMIT 1
            """,
            (clean_title,),
        )
        row = cur.fetchone()
        if row:
            notice_id = row[0]
            created_at = row[1]
            cur.execute(
                """
                UPDATE system_notice
                SET content_html = ?, created_by_user_id = ?, updated_at = ?
                WHERE notice_id = ?
                """,
                (clean_content, created_by_user_id, now, notice_id),
            )
        else:
            notice_id = str(uuid.uuid4())
            created_at = now
            cur.execute(
                """
                INSERT INTO system_notice (
                    notice_id,
                    title,
                    content_html,
                    created_by_user_id,
                    created_at,
                    updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (
                    notice_id,
                    clean_title,
                    clean_content,
                    created_by_user_id,
                    created_at,
                    now,
                ),
            )
        conn.commit()
    finally:
        conn.close()

    return {
        "notice_id": notice_id,
        "title": clean_title,
        "content_html": clean_content,
        "created_by_user_id": created_by_user_id,
        "created_at": created_at,
        "updated_at": now,
        "scope": "global",
    }


def list_system_notices(*, limit: int = 50) -> List[Dict[str, object]]:
    init_system_notice_db()
    conn = sqlite3.connect(DB_PATH)
    try:
        cur = conn.cursor()
        cur.execute(
            """
            SELECT notice_id, title, content_html, created_by_user_id, created_at, updated_at
            FROM system_notice
            ORDER BY datetime(updated_at) DESC, datetime(created_at) DESC
            LIMIT ?
            """,
            (max(1, min(limit, 100)),),
        )
        rows = cur.fetchall()
    finally:
        conn.close()

    return [
        {
            "notice_id": row[0],
            "title": row[1],
            "content_html": row[2],
            "created_by_user_id": row[3],
            "created_at": row[4],
            "updated_at": row[5],
            "scope": "global",
        }
        for row in rows
    ]


def delete_system_notice_by_title(title: str) -> bool:
    init_system_notice_db()
    clean_title = (title or "").strip()
    if not clean_title:
        raise ValueError("title is required")

    conn = sqlite3.connect(DB_PATH)
    try:
        cur = conn.cursor()
        cur.execute("DELETE FROM system_notice WHERE title = ?", (clean_title,))
        conn.commit()
        return cur.rowcount > 0
    finally:
        conn.close()
