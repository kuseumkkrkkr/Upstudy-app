import sqlite3
from datetime import datetime
from typing import Any, Dict, Iterable, List, Optional

from storage.storage import DB_PATH


def _now_iso() -> str:
    return datetime.utcnow().isoformat(timespec="seconds") + "Z"


def _ensure_column(cursor: sqlite3.Cursor, table: str, column: str, definition: str) -> None:
    cursor.execute(f"PRAGMA table_info({table})")
    existing = {row[1] for row in cursor.fetchall()}
    if column not in existing:
        cursor.execute(f"ALTER TABLE {table} ADD COLUMN {column} {definition}")


def init_rating_db() -> None:
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS user_rating (
            user_id TEXT PRIMARY KEY,
            rating REAL NOT NULL,
            ovr REAL NOT NULL,
            ovr_prev REAL NOT NULL,
            lose_streak INTEGER NOT NULL,
            last_attempt_at TEXT,
            recent_results TEXT NOT NULL,
            recent_index INTEGER NOT NULL,
            recent_count INTEGER NOT NULL,
            recent_sum INTEGER NOT NULL,
            tag_rating_sum REAL NOT NULL,
            tag_rating_count INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )
        """
    )

    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS user_tag_stats (
            user_id TEXT NOT NULL,
            tag TEXT NOT NULL,
            attempts INTEGER NOT NULL,
            rating REAL NOT NULL,
            rating_prev REAL NOT NULL,
            updated_at TEXT NOT NULL,
            PRIMARY KEY (user_id, tag)
        )
        """
    )

    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS rating_submission (
            user_id TEXT NOT NULL,
            submission_id TEXT NOT NULL,
            created_at TEXT NOT NULL,
            PRIMARY KEY (user_id, submission_id)
        )
        """
    )

    # Legacy safety: ensure columns exist
    _ensure_column(cursor, "user_rating", "ovr", "REAL NOT NULL DEFAULT 0")
    _ensure_column(cursor, "user_rating", "ovr_prev", "REAL NOT NULL DEFAULT 0")
    _ensure_column(cursor, "user_rating", "tag_rating_sum", "REAL NOT NULL DEFAULT 0")
    _ensure_column(cursor, "user_rating", "tag_rating_count", "INTEGER NOT NULL DEFAULT 0")
    _ensure_column(cursor, "user_tag_stats", "rating_prev", "REAL NOT NULL DEFAULT 0")

    conn.commit()
    conn.close()


def get_user(conn: sqlite3.Connection, user_id: str) -> Optional[Dict[str, Any]]:
    cursor = conn.cursor()
    cursor.execute(
        """
        SELECT
            user_id,
            rating,
            ovr,
            ovr_prev,
            lose_streak,
            last_attempt_at,
            recent_results,
            recent_index,
            recent_count,
            recent_sum,
            tag_rating_sum,
            tag_rating_count,
            created_at,
            updated_at
        FROM user_rating
        WHERE user_id = ?
        """,
        (user_id,),
    )
    row = cursor.fetchone()
    if not row:
        return None
    return {
        "user_id": row[0],
        "rating": row[1],
        "ovr": row[2],
        "ovr_prev": row[3],
        "lose_streak": row[4],
        "last_attempt_at": row[5],
        "recent_results": row[6],
        "recent_index": row[7],
        "recent_count": row[8],
        "recent_sum": row[9],
        "tag_rating_sum": row[10],
        "tag_rating_count": row[11],
        "created_at": row[12],
        "updated_at": row[13],
    }


def create_user(
    conn: sqlite3.Connection,
    *,
    user_id: str,
    rating: float,
    now_iso: Optional[str] = None,
) -> Dict[str, Any]:
    now_iso = now_iso or _now_iso()
    cursor = conn.cursor()
    cursor.execute(
        """
        INSERT INTO user_rating (
            user_id,
            rating,
            ovr,
            ovr_prev,
            lose_streak,
            last_attempt_at,
            recent_results,
            recent_index,
            recent_count,
            recent_sum,
            tag_rating_sum,
            tag_rating_count,
            created_at,
            updated_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            user_id,
            rating,
            rating,
            rating,
            0,
            None,
            "[]",
            0,
            0,
            0,
            0.0,
            0,
            now_iso,
            now_iso,
        ),
    )
    return {
        "user_id": user_id,
        "rating": rating,
        "ovr": rating,
        "ovr_prev": rating,
        "lose_streak": 0,
        "last_attempt_at": None,
        "recent_results": "[]",
        "recent_index": 0,
        "recent_count": 0,
        "recent_sum": 0,
        "tag_rating_sum": 0.0,
        "tag_rating_count": 0,
        "created_at": now_iso,
        "updated_at": now_iso,
    }


def get_tag_stats(
    conn: sqlite3.Connection,
    user_id: str,
    tags: Iterable[str],
) -> Dict[str, Dict[str, Any]]:
    tag_list = list(tags)
    if not tag_list:
        return {}
    placeholders = ",".join(["?"] * len(tag_list))
    cursor = conn.cursor()
    cursor.execute(
        f"""
        SELECT user_id, tag, attempts, rating, rating_prev, updated_at
        FROM user_tag_stats
        WHERE user_id = ? AND tag IN ({placeholders})
        """,
        (user_id, *tag_list),
    )
    rows = cursor.fetchall()
    result: Dict[str, Dict[str, Any]] = {}
    for row in rows:
        result[row[1]] = {
            "user_id": row[0],
            "tag": row[1],
            "attempts": row[2],
            "rating": row[3],
            "rating_prev": row[4],
            "updated_at": row[5],
        }
    return result


def list_tag_stats(
    conn: sqlite3.Connection,
    user_id: str,
) -> List[Dict[str, Any]]:
    cursor = conn.cursor()
    cursor.execute(
        """
        SELECT tag, attempts, rating, rating_prev, updated_at
        FROM user_tag_stats
        WHERE user_id = ?
        ORDER BY updated_at DESC
        """,
        (user_id,),
    )
    rows = cursor.fetchall()
    return [
        {
            "tag": row[0],
            "attempts": row[1],
            "rating": row[2],
            "rating_prev": row[3],
            "updated_at": row[4],
        }
        for row in rows
    ]


def upsert_tag_stats(
    conn: sqlite3.Connection,
    updates: List[Dict[str, Any]],
) -> None:
    if not updates:
        return
    cursor = conn.cursor()
    payload = [
        (
            item["user_id"],
            item["tag"],
            item["attempts"],
            item["rating"],
            item["rating_prev"],
            item["updated_at"],
        )
        for item in updates
    ]
    cursor.executemany(
        """
        INSERT INTO user_tag_stats (user_id, tag, attempts, rating, rating_prev, updated_at)
        VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(user_id, tag) DO UPDATE SET
            attempts = excluded.attempts,
            rating = excluded.rating,
            rating_prev = excluded.rating_prev,
            updated_at = excluded.updated_at
        """,
        payload,
    )


def mark_submission(
    conn: sqlite3.Connection,
    *,
    user_id: str,
    submission_id: str,
) -> bool:
    """Return False if already processed."""
    try:
        conn.execute(
            """
            INSERT INTO rating_submission (user_id, submission_id, created_at)
            VALUES (?, ?, ?)
            """,
            (user_id, submission_id, _now_iso()),
        )
        return True
    except sqlite3.IntegrityError:
        return False
