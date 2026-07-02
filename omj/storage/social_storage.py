import sqlite3
import uuid
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
        CREATE TABLE IF NOT EXISTS friend_requests (
            id TEXT PRIMARY KEY,
            from_user_id TEXT NOT NULL,
            to_user_id TEXT NOT NULL,
            message TEXT,
            status TEXT NOT NULL,
            created_at TEXT NOT NULL
        )
        """
    )
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
        """
        CREATE TABLE IF NOT EXISTS messages (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            peer_id TEXT NOT NULL,
            text TEXT NOT NULL,
            created_at TEXT NOT NULL,
            is_mine INTEGER NOT NULL DEFAULT 0
        )
        """
    )
    try:
        cur.execute("ALTER TABLE messages ADD COLUMN is_mine INTEGER NOT NULL DEFAULT 0")
    except sqlite3.OperationalError:
        pass
    cur.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_friend_requests_to_status
        ON friend_requests (to_user_id, status)
        """
    )
    cur.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_friend_requests_from_status
        ON friend_requests (from_user_id, status)
        """
    )
    cur.execute(
        "CREATE INDEX IF NOT EXISTS idx_messages_user_peer_created ON messages (user_id, peer_id, created_at)"
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


def get_friend_request_by_id(request_id: str) -> Optional[Dict[str, str]]:
    if not request_id:
        return None
    init_social_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        SELECT id, from_user_id, to_user_id, message, status, created_at
        FROM friend_requests
        WHERE id = ?
        """,
        (request_id,),
    )
    row = cur.fetchone()
    conn.close()
    if not row:
        return None
    return {
        "id": row[0],
        "from_user_id": row[1],
        "to_user_id": row[2],
        "message": row[3],
        "status": row[4],
        "created_at": row[5],
    }


def list_friend_requests_for_user(user_id: str) -> List[Dict[str, str]]:
    init_social_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        SELECT id, from_user_id, to_user_id, message, status, created_at
        FROM friend_requests
        WHERE from_user_id = ? OR to_user_id = ?
        ORDER BY created_at DESC
        """,
        (user_id, user_id),
    )
    rows = cur.fetchall()
    conn.close()
    return [
        {
            "id": row[0],
            "from_user_id": row[1],
            "to_user_id": row[2],
            "message": row[3],
            "status": row[4],
            "created_at": row[5],
        }
        for row in rows
    ]


def create_friend_request(
    *,
    from_user_id: str,
    to_user_id: str,
    message: Optional[str] = None,
) -> Dict[str, str]:
    if from_user_id == to_user_id:
        raise ValueError("cannot request yourself")
    init_social_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    request_id = str(uuid.uuid4())
    created_at = datetime.utcnow().isoformat(timespec="seconds") + "Z"
    try:
        cur.execute(
            """
            INSERT INTO friend_requests (id, from_user_id, to_user_id, message, status, created_at)
            VALUES (?, ?, ?, ?, 'pending', ?)
            """,
            (request_id, from_user_id, to_user_id, message or "", created_at),
        )
        conn.commit()
    finally:
        conn.close()
    return {
        "id": request_id,
        "from_user_id": from_user_id,
        "to_user_id": to_user_id,
        "message": message or "",
        "status": "pending",
        "created_at": created_at,
    }


def set_friend_request_status(request_id: str, status: str) -> Optional[Dict[str, str]]:
    init_social_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        UPDATE friend_requests
        SET status = ?
        WHERE id = ?
        """,
        (status, request_id),
    )
    conn.commit()
    conn.close()
    return get_friend_request_by_id(request_id)


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


def get_message_by_id(message_id: str) -> Optional[Dict[str, str]]:
    if not message_id:
        return None
    init_social_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        SELECT id, user_id, peer_id, text, created_at, is_mine
        FROM messages
        WHERE id = ?
        """,
        (message_id,),
    )
    row = cur.fetchone()
    conn.close()
    if not row:
        return None
    return {
        "id": row[0],
        "user_id": row[1],
        "peer_id": row[2],
        "text": row[3],
        "created_at": row[4],
        "is_mine": bool(row[5]) if len(row) > 5 else False,
    }


def delete_conversation(user_id: str, peer_id: str) -> None:
    init_social_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    try:
        cur.execute(
            """
            DELETE FROM messages
            WHERE (user_id = ? AND peer_id = ?)
               OR (user_id = ? AND peer_id = ?)
            """,
            (user_id, peer_id, peer_id, user_id),
        )
        conn.commit()
    finally:
        conn.close()


def list_messages(
    *,
    user_id: str,
    peer_id: str,
    limit: int = 30,
    before_message_id: Optional[str] = None,
) -> List[Dict[str, str]]:
    init_social_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()

    created_cutoff: Optional[str] = None
    if before_message_id:
        row = get_message_by_id(before_message_id)
        if row:
            created_cutoff = row["created_at"]

    params: List[str] = [user_id, peer_id]
    query = """
        SELECT id, user_id, peer_id, text, created_at, is_mine
        FROM messages
        WHERE user_id = ? AND peer_id = ?
    """
    if created_cutoff:
        query += " AND created_at < ?"
        params.append(created_cutoff)
    query += " ORDER BY created_at DESC LIMIT ?"
    params.append(limit)

    cur.execute(query, params)
    rows = cur.fetchall()
    conn.close()
    rows = list(reversed(rows))
    return [
        {
            "id": row[0],
            "user_id": row[1],
            "peer_id": row[2],
            "text": row[3],
            "created_at": row[4],
            "is_mine": bool(row[5]) if len(row) > 5 else False,
        }
        for row in rows
    ]


def append_message(
    *,
    message_id: str,
    user_id: str,
    peer_id: str,
    text: str,
    created_at: str,
    is_mine: bool,
    max_total: int = 2000,
) -> None:
    init_social_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    try:
        cur.execute(
            """
            INSERT INTO messages (id, user_id, peer_id, text, created_at, is_mine)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (message_id, user_id, peer_id, text, created_at, 1 if is_mine else 0),
        )
        cur.execute(
            """
            DELETE FROM messages
            WHERE id IN (
                SELECT id FROM messages
                WHERE user_id = ? AND peer_id = ?
                ORDER BY created_at DESC
                LIMIT -1 OFFSET ?
            )
            """,
            (user_id, peer_id, max_total),
        )
        conn.commit()
    finally:
        conn.close()


def list_conversations(
    *,
    user_id: str,
    limit: int = 15,
    before_created_at: Optional[str] = None,
) -> List[Dict[str, str]]:
    """Return latest message per peer for this user, ordered by recency."""
    init_social_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()

    cutoff_clause = ""
    params: List[str] = [user_id, user_id]
    if before_created_at:
        cutoff_clause = " AND created_at < ?"
        params.append(before_created_at)

    query = f"""
        SELECT m.id, m.user_id, m.peer_id, m.text, m.created_at, m.is_mine
        FROM messages m
        WHERE m.user_id = ?
          AND m.created_at = (
            SELECT MAX(created_at)
            FROM messages
            WHERE user_id = ? AND peer_id = m.peer_id{cutoff_clause}
          )
        ORDER BY m.created_at DESC
        LIMIT ?
    """
    params.append(limit)
    cur.execute(query, params)
    rows = cur.fetchall()
    conn.close()
    return [
        {
            "id": row[0],
            "user_id": row[1],
            "peer_id": row[2],
            "text": row[3],
            "created_at": row[4],
            "is_mine": bool(row[5]) if len(row) > 5 else False,
        }
        for row in rows
    ]
