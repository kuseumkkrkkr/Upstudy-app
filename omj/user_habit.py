import sqlite3
import json
from datetime import datetime, timedelta
from typing import Dict, List, Optional

from storage.storage import DB_PATH


def _now_iso() -> str:
    return datetime.utcnow().isoformat(timespec="seconds") + "Z"


def _cutoff_iso(days: int) -> str:
    return (datetime.utcnow() - timedelta(days=days)).isoformat(timespec="seconds") + "Z"


def init_habit_db() -> None:
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS user_habit (
            user_id TEXT NOT NULL,
            kind TEXT NOT NULL, -- problem | exam | textbook
            codebase_id INTEGER,
            seed TEXT,
            exam_id TEXT,
            textbook_id TEXT,
            tags TEXT, -- JSON array string
            quest_title TEXT,
            retry_count INTEGER NOT NULL DEFAULT 1,
            updated_at TEXT NOT NULL,
            PRIMARY KEY (user_id, kind, codebase_id, seed, exam_id, textbook_id)
        )
        """
    )
    conn.commit()
    conn.close()


def _purge_old(days: int = 60) -> None:
    init_habit_db()
    cutoff = _cutoff_iso(days)
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("DELETE FROM user_habit WHERE updated_at < ?", (cutoff,))
    conn.commit()
    conn.close()


def record_problem_attempt(
    *,
    user_id: str,
    codebase_id: int,
    seed: str,
    tags_json: str,
    quest_title: str,
    now_iso: Optional[str] = None,
) -> Dict[str, str | int]:
    init_habit_db()
    _purge_old()
    now_iso = now_iso or _now_iso()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO user_habit (
            user_id, kind, codebase_id, seed, tags, quest_title, retry_count, updated_at
        ) VALUES (?, 'problem', ?, ?, ?, ?, 1, ?)
        ON CONFLICT(user_id, kind, codebase_id, seed, exam_id, textbook_id)
        DO UPDATE SET
            retry_count = user_habit.retry_count + 1,
            tags = excluded.tags,
            quest_title = excluded.quest_title,
            updated_at = excluded.updated_at
        """,
        (user_id, codebase_id, seed, tags_json, quest_title, now_iso),
    )
    conn.commit()
    cur.execute(
        """
        SELECT codebase_id, seed, tags, quest_title, retry_count, updated_at
        FROM user_habit
        WHERE user_id = ? AND kind = 'problem' AND codebase_id = ? AND seed = ?
        """,
        (user_id, codebase_id, seed),
    )
    row = cur.fetchone()
    conn.close()
    # PostgreSQL 전환 중에도 최근 풀이 이력을 함께 기록해 사용자별 중복 제외 기준을 유지한다.
    try:
        from storage.postgres_problem_store import postgres_problem_store

        postgres_problem_store.enqueue_problem_solve(
            user_id=user_id,
            codebase_id=codebase_id,
            seed=seed,
            tags=json.loads(tags_json) if tags_json else [],
        )
    except Exception:
        pass
    return {
        "codebase_id": row[0],
        "seed": row[1],
        "tags": row[2],
        "quest_title": row[3],
        "retry_count": row[4],
        "updated_at": row[5],
    }


def record_exam_attempt(*, user_id: str, exam_id: str, now_iso: Optional[str] = None) -> None:
    init_habit_db()
    _purge_old()
    now_iso = now_iso or _now_iso()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO user_habit (
            user_id, kind, exam_id, retry_count, updated_at
        ) VALUES (?, 'exam', ?, 1, ?)
        ON CONFLICT(user_id, kind, codebase_id, seed, exam_id, textbook_id)
        DO UPDATE SET
            retry_count = user_habit.retry_count + 1,
            updated_at = excluded.updated_at
        """,
        (user_id, exam_id, now_iso),
    )
    conn.commit()
    conn.close()


def record_textbook_view(*, user_id: str, textbook_id: str, now_iso: Optional[str] = None) -> None:
    init_habit_db()
    _purge_old()
    now_iso = now_iso or _now_iso()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO user_habit (
            user_id, kind, textbook_id, retry_count, updated_at
        ) VALUES (?, 'textbook', ?, 1, ?)
        ON CONFLICT(user_id, kind, codebase_id, seed, exam_id, textbook_id)
        DO UPDATE SET
            retry_count = user_habit.retry_count + 1,
            updated_at = excluded.updated_at
        """,
        (user_id, textbook_id, now_iso),
    )
    conn.commit()
    conn.close()


def list_problem_history(
    *,
    user_id: str,
    days: int = 60,
    tag_filter: Optional[str] = None,
    limit: int = 200,
) -> List[Dict[str, str | int]]:
    init_habit_db()
    _purge_old(days)
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    params = [user_id]
    query = """
        SELECT codebase_id, seed, tags, quest_title, retry_count, updated_at
        FROM user_habit
        WHERE user_id = ? AND kind = 'problem'
    """
    if tag_filter:
        query += " AND LOWER(tags) LIKE ?"
        params.append(f"%{tag_filter.lower()}%")
    query += " ORDER BY updated_at DESC LIMIT ?"
    params.append(limit)
    cur.execute(query, params)
    rows = cur.fetchall()
    conn.close()
    return [
        {
          "codebase_id": row[0],
          "seed": row[1],
          "tags": row[2],
          "quest_title": row[3],
          "retry_count": row[4],
          "updated_at": row[5],
        }
        for row in rows
    ]
