import sqlite3
from datetime import datetime
from typing import Dict, List, Optional

from auth import init_user_db
from storage.storage import DB_PATH


def init_social_db() -> None:
    """Create social tables if missing (idempotent)."""
    init_user_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS friends (
            user_id TEXT NOT NULL,
            friend_id TEXT NOT NULL,
            created_at TEXT NOT NULL,
            PRIMARY KEY (user_id, friend_id)
        )
        """
    )
    cur.execute(
        "CREATE INDEX IF NOT EXISTS idx_friends_user_id ON friends (user_id)"
    )
    conn.commit()
    conn.close()


def search_users_by_username(
    query: str,
    *,
    exclude_user_id: Optional[str] = None,
    limit: int = 20,
) -> List[Dict[str, Optional[str]]]:
    query = query.strip()
    if not query:
        return []
    init_user_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    like_value = f"%{query.lower()}%"
    if exclude_user_id:
        cur.execute(
            """
            SELECT user_id, username, name, profile_image, ovr, status
            FROM users
            WHERE LOWER(username) LIKE ?
              AND user_id != ?
            ORDER BY username ASC
            LIMIT ?
            """,
            (like_value, exclude_user_id, limit),
        )
    else:
        cur.execute(
            """
            SELECT user_id, username, name, profile_image, ovr, status
            FROM users
            WHERE LOWER(username) LIKE ?
            ORDER BY username ASC
            LIMIT ?
            """,
            (like_value, limit),
        )
    rows = cur.fetchall()
    conn.close()
    return [
        {
            "user_id": row[0],
            "username": row[1],
            "name": row[2],
            "profile_image": row[3],
            "ovr": row[4] if len(row) > 4 and row[4] is not None else 0,
            "status": row[5] if len(row) > 5 and row[5] is not None else "",
        }
        for row in rows
    ]


def get_user_by_username(username: str) -> Optional[Dict[str, Optional[str]]]:
    username = username.strip()
    if not username:
        return None
    init_user_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        SELECT user_id, username, name, profile_image, ovr, status
        FROM users
        WHERE username = ?
        """,
        (username,),
    )
    row = cur.fetchone()
    conn.close()
    if not row:
        return None
    return {
        "user_id": row[0],
        "username": row[1],
        "name": row[2],
        "profile_image": row[3],
        "ovr": row[4] if len(row) > 4 and row[4] is not None else 0,
        "status": row[5] if len(row) > 5 and row[5] is not None else "",
    }


def get_user_by_id(user_id: str) -> Optional[Dict[str, Optional[str]]]:
    user_id = user_id.strip()
    if not user_id:
        return None
    init_user_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        SELECT user_id, username, name, profile_image, ovr, status
        FROM users
        WHERE user_id = ?
        """,
        (user_id,),
    )
    row = cur.fetchone()
    conn.close()
    if not row:
        return None
    return {
        "user_id": row[0],
        "username": row[1],
        "name": row[2],
        "profile_image": row[3],
        "ovr": row[4] if len(row) > 4 and row[4] is not None else 0,
        "status": row[5] if len(row) > 5 and row[5] is not None else "",
    }


def get_friends(user_id: str) -> List[Dict[str, Optional[str]]]:
    init_social_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        SELECT u.user_id, u.username, u.name, u.profile_image, u.ovr, u.status
        FROM friends f
        JOIN users u ON u.user_id = f.friend_id
        WHERE f.user_id = ?
        ORDER BY u.username ASC
        """,
        (user_id,),
    )
    rows = cur.fetchall()
    conn.close()
    return [
        {
            "user_id": row[0],
            "username": row[1],
            "name": row[2],
            "profile_image": row[3],
            "ovr": row[4] if len(row) > 4 and row[4] is not None else 0,
            "status": row[5] if len(row) > 5 and row[5] is not None else "",
        }
        for row in rows
    ]


def are_friends(user_id: str, friend_id: str) -> bool:
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        "SELECT 1 FROM friends WHERE user_id = ? AND friend_id = ?",
        (user_id, friend_id),
    )
    row = cur.fetchone()
    conn.close()
    return row is not None


def add_friend(user_id: str, friend_id: str) -> None:
    if user_id == friend_id:
        raise ValueError("cannot friend yourself")
    init_social_db()
    created_at = datetime.utcnow().isoformat(timespec="seconds") + "Z"
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    try:
        cur.execute(
            """
            INSERT OR IGNORE INTO friends (user_id, friend_id, created_at)
            VALUES (?, ?, ?)
            """,
            (user_id, friend_id, created_at),
        )
        cur.execute(
            """
            INSERT OR IGNORE INTO friends (user_id, friend_id, created_at)
            VALUES (?, ?, ?)
            """,
            (friend_id, user_id, created_at),
        )
        conn.commit()
    finally:
        conn.close()


def remove_friend(user_id: str, friend_id: str) -> None:
    init_social_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    try:
        cur.execute(
            "DELETE FROM friends WHERE user_id = ? AND friend_id = ?",
            (user_id, friend_id),
        )
        cur.execute(
            "DELETE FROM friends WHERE user_id = ? AND friend_id = ?",
            (friend_id, user_id),
        )
        conn.commit()
    finally:
        conn.close()
