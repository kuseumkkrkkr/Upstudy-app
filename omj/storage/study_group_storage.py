import hashlib
import sqlite3
import uuid
from datetime import datetime
from typing import Dict, List, Optional, Tuple

from storage.storage import DB_PATH


def init_study_group_db() -> None:
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS study_groups (
            group_id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT NOT NULL,
            max_members INTEGER NOT NULL,
            is_public INTEGER NOT NULL,
            logo_index INTEGER,
            lock_enabled INTEGER NOT NULL,
            password_hash TEXT,
            password_salt TEXT,
            created_at TEXT NOT NULL,
            creator_id TEXT NOT NULL
        )
        """
    )
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS study_group_members (
            group_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            role TEXT NOT NULL DEFAULT 'member',
            joined_at TEXT NOT NULL,
            PRIMARY KEY (group_id, user_id)
        )
        """
    )
    cur.execute(
        "CREATE INDEX IF NOT EXISTS idx_study_group_members_user_id "
        "ON study_group_members (user_id)"
    )
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS study_group_messages (
            message_id TEXT PRIMARY KEY,
            group_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            text TEXT NOT NULL,
            created_at TEXT NOT NULL
        )
        """
    )
    cur.execute(
        "CREATE INDEX IF NOT EXISTS idx_study_group_messages_group_id "
        "ON study_group_messages (group_id, created_at DESC)"
    )
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS study_group_topics (
            group_id TEXT PRIMARY KEY,
            topic TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )
        """
    )
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS study_group_exams (
            group_id TEXT NOT NULL,
            exam_id TEXT NOT NULL,
            title TEXT,
            created_at TEXT NOT NULL,
            PRIMARY KEY (group_id, exam_id)
        )
        """
    )
    cur.execute(
        "CREATE INDEX IF NOT EXISTS idx_study_group_exams_group_id "
        "ON study_group_exams (group_id, created_at DESC)"
    )
    conn.commit()
    conn.close()


def _hash_password(password: str, salt: str) -> str:
    return hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt.encode("utf-8"),
        120_000,
    ).hex()


def create_study_group(
    *,
    name: str,
    description: str,
    max_members: int,
    is_public: bool,
    creator_id: str,
    logo_index: Optional[int] = None,
    lock_enabled: bool = False,
    password: Optional[str] = None,
    member_ids: Optional[List[str]] = None,
) -> Dict[str, object]:
    name = name.strip()
    description = description.strip()
    if not name:
        raise ValueError("name is required")
    if not description:
        raise ValueError("description is required")
    if max_members < 1:
        raise ValueError("max_members must be at least 1")

    member_ids = member_ids or []
    unique_members: List[str] = []
    seen = set()
    for member_id in [creator_id] + member_ids:
        if not member_id or member_id in seen:
            continue
        seen.add(member_id)
        unique_members.append(member_id)

    if len(unique_members) > max_members:
        raise ValueError("members exceed max_members")

    password_hash = None
    password_salt = None
    if lock_enabled:
        password_value = (password or "").strip()
        if not password_value:
            raise ValueError("password is required when lock_enabled")
        password_salt = uuid.uuid4().hex
        password_hash = _hash_password(password_value, password_salt)

    init_study_group_db()
    if count_groups_created_by_user(creator_id) >= 1:
        raise ValueError("creator already owns a group")
    if count_groups_for_user(creator_id) >= 3:
        raise ValueError("user already joined maximum number of groups")
    group_id = str(uuid.uuid4())
    created_at = datetime.utcnow().isoformat(timespec="seconds") + "Z"

    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    try:
        cur.execute(
            """
            INSERT INTO study_groups (
                group_id,
                name,
                description,
                max_members,
                is_public,
                logo_index,
                lock_enabled,
                password_hash,
                password_salt,
                created_at,
                creator_id
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                group_id,
                name,
                description,
                max_members,
                1 if is_public else 0,
                logo_index,
                1 if lock_enabled else 0,
                password_hash,
                password_salt,
                created_at,
                creator_id,
            ),
        )
        for member_id in unique_members:
            role = "owner" if member_id == creator_id else "member"
            cur.execute(
                """
                INSERT OR IGNORE INTO study_group_members (
                    group_id,
                    user_id,
                    role,
                    joined_at
                )
                VALUES (?, ?, ?, ?)
                """,
                (group_id, member_id, role, created_at),
            )
        conn.commit()
    finally:
        conn.close()

    return {
        "group_id": group_id,
        "name": name,
        "description": description,
        "max_members": max_members,
        "is_public": bool(is_public),
        "logo_index": logo_index,
        "lock_enabled": bool(lock_enabled),
        "created_at": created_at,
        "creator_id": creator_id,
        "member_ids": unique_members,
    }


def _get_conn() -> sqlite3.Connection:
    init_study_group_db()
    return sqlite3.connect(DB_PATH)


def count_groups_created_by_user(user_id: str) -> int:
    conn = _get_conn()
    try:
        cur = conn.execute(
            "SELECT COUNT(*) FROM study_groups WHERE creator_id = ?",
            (user_id,),
        )
        return int(cur.fetchone()[0])
    finally:
        conn.close()


def count_groups_for_user(user_id: str) -> int:
    conn = _get_conn()
    try:
        cur = conn.execute(
            "SELECT COUNT(*) FROM study_group_members WHERE user_id = ?",
            (user_id,),
        )
        return int(cur.fetchone()[0])
    finally:
        conn.close()


def _fetch_member_ids(conn: sqlite3.Connection, group_id: str) -> List[str]:
    cur = conn.execute(
        "SELECT user_id FROM study_group_members WHERE group_id = ?",
        (group_id,),
    )
    return [row[0] for row in cur.fetchall()]


def list_groups_for_user(user_id: str) -> List[Dict[str, object]]:
    conn = _get_conn()
    try:
        cur = conn.execute(
            """
            SELECT sg.group_id,
                   sg.name,
                   sg.description,
                   sg.max_members,
                   sg.is_public,
                   sg.logo_index,
                   sg.lock_enabled,
                   sg.created_at,
                   sg.creator_id,
                   COUNT(m2.user_id) AS members
            FROM study_group_members m
            JOIN study_groups sg ON sg.group_id = m.group_id
            LEFT JOIN study_group_members m2 ON m2.group_id = m.group_id
            WHERE m.user_id = ?
            GROUP BY sg.group_id
            ORDER BY sg.created_at DESC
            """,
            (user_id,),
        )
        rows = cur.fetchall()
    finally:
        conn.close()
    results = []
    for row in rows:
        (
            group_id,
            name,
            description,
            max_members,
            is_public,
            logo_index,
            lock_enabled,
            created_at,
            creator_id,
            members,
        ) = row
        member_ids = _fetch_member_ids(conn, group_id)
        results.append(
            {
                "group_id": group_id,
                "name": name,
                "description": description,
                "max_members": int(max_members),
                "is_public": bool(is_public),
                "logo_index": logo_index,
                "lock_enabled": bool(lock_enabled),
                "created_at": created_at,
                "creator_id": creator_id,
                "members": int(members),
                "member_ids": member_ids,
            }
        )
    return results


def get_group(group_id: str) -> Optional[Dict[str, object]]:
    conn = _get_conn()
    try:
        cur = conn.execute(
            """
            SELECT group_id,
                   name,
                   description,
                   max_members,
                   is_public,
                   logo_index,
                   lock_enabled,
                   password_hash,
                   password_salt,
                   created_at,
                   creator_id
            FROM study_groups
            WHERE group_id = ?
            """,
            (group_id,),
        )
        row = cur.fetchone()
        if not row:
            return None
        cur = conn.execute(
            "SELECT user_id FROM study_group_members WHERE group_id = ?",
            (group_id,),
        )
        members = [r[0] for r in cur.fetchall()]
    finally:
        conn.close()
    (
        gid,
        name,
        description,
        max_members,
        is_public,
        logo_index,
        lock_enabled,
        password_hash,
        password_salt,
        created_at,
        creator_id,
    ) = row
    return {
        "group_id": gid,
        "name": name,
        "description": description,
        "max_members": int(max_members),
        "is_public": bool(is_public),
        "logo_index": logo_index,
        "lock_enabled": bool(lock_enabled),
        "password_hash": password_hash,
        "password_salt": password_salt,
        "created_at": created_at,
        "creator_id": creator_id,
        "member_ids": members,
    }


def _assert_can_join(user_id: str, group: Dict[str, object], password: Optional[str]) -> None:
    member_ids: List[str] = group.get("member_ids", [])
    if user_id in member_ids:
        return
    if len(member_ids) >= int(group["max_members"]):
        raise ValueError("group is full")
    if count_groups_for_user(user_id) >= 3:
        raise ValueError("user reached max groups")
    if group.get("lock_enabled"):
        password_value = (password or "").strip()
        salt = group.get("password_salt") or ""
        expected_hash = group.get("password_hash")
        if not password_value or not expected_hash:
            raise ValueError("password required")
        if _hash_password(password_value, salt) != expected_hash:
            raise ValueError("invalid password")


def join_group(group_id: str, user_id: str, password: Optional[str] = None) -> Dict[str, object]:
    init_study_group_db()
    group = get_group(group_id)
    if not group:
        raise ValueError("group not found")
    _assert_can_join(user_id, group, password)

    conn = _get_conn()
    created_at = datetime.utcnow().isoformat(timespec="seconds") + "Z"
    try:
        conn.execute(
            """
            INSERT OR IGNORE INTO study_group_members (group_id, user_id, role, joined_at)
            VALUES (?, ?, 'member', ?)
            """,
            (group_id, user_id, created_at),
        )
        conn.commit()
    finally:
        conn.close()
    group = get_group(group_id)
    return group or {}


def append_group_message(
    *,
    group_id: str,
    user_id: str,
    text: str,
    limit: int = 500,
) -> Dict[str, object]:
    if not text.strip():
        raise ValueError("text is required")
    group = get_group(group_id)
    if not group:
        raise ValueError("group not found")
    if user_id not in group.get("member_ids", []):
        raise ValueError("user not in group")
    conn = _get_conn()
    now = datetime.utcnow().isoformat(timespec="seconds") + "Z"
    message_id = str(uuid.uuid4())
    try:
        conn.execute(
            """
            INSERT INTO study_group_messages (message_id, group_id, user_id, text, created_at)
            VALUES (?, ?, ?, ?, ?)
            """,
            (message_id, group_id, user_id, text.strip(), now),
        )
        # enforce FIFO cap
        cur = conn.execute(
            "SELECT COUNT(*) FROM study_group_messages WHERE group_id = ?",
            (group_id,),
        )
        count = int(cur.fetchone()[0])
        if count > limit:
            to_remove = count - limit
            conn.execute(
                """
                DELETE FROM study_group_messages
                WHERE message_id IN (
                    SELECT message_id
                    FROM study_group_messages
                    WHERE group_id = ?
                    ORDER BY datetime(created_at) ASC
                    LIMIT ?
                )
                """,
                (group_id, to_remove),
            )
        conn.commit()
    finally:
        conn.close()
    return {
        "message_id": message_id,
        "group_id": group_id,
        "user_id": user_id,
        "text": text.strip(),
        "created_at": now,
    }


def list_group_messages(
    *,
    group_id: str,
    limit: int = 50,
    before: Optional[str] = None,
) -> List[Dict[str, object]]:
    if limit < 1:
        limit = 1
    if limit > 200:
        limit = 200
    params: Tuple[object, ...]
    query = """
        SELECT message_id, user_id, text, created_at
        FROM study_group_messages
        WHERE group_id = ?
    """
    params = (group_id,)
    if before:
        query += " AND datetime(created_at) < datetime(?)"
        params = (group_id, before)
    query += " ORDER BY datetime(created_at) DESC LIMIT ?"
    params = params + (limit,)
    conn = _get_conn()
    try:
        cur = conn.execute(query, params)
        rows = cur.fetchall()
    finally:
        conn.close()
    rows.reverse()
    return [
        {
            "message_id": r[0],
            "group_id": group_id,
            "user_id": r[1],
            "text": r[2],
            "created_at": r[3],
        }
        for r in rows
    ]


def set_group_topic(group_id: str, topic: str) -> Dict[str, object]:
    topic_value = topic.strip()
    if not topic_value:
        raise ValueError("topic is required")
    now = datetime.utcnow().isoformat(timespec="seconds") + "Z"
    conn = _get_conn()
    try:
        conn.execute(
            """
            INSERT INTO study_group_topics (group_id, topic, updated_at)
            VALUES (?, ?, ?)
            ON CONFLICT(group_id) DO UPDATE SET topic=excluded.topic, updated_at=excluded.updated_at
            """,
            (group_id, topic_value, now),
        )
        conn.commit()
    finally:
        conn.close()
    return {"group_id": group_id, "topic": topic_value, "updated_at": now}


def get_group_topic(group_id: str) -> Optional[Dict[str, object]]:
    conn = _get_conn()
    try:
        cur = conn.execute(
            "SELECT topic, updated_at FROM study_group_topics WHERE group_id = ?",
            (group_id,),
        )
        row = cur.fetchone()
    finally:
        conn.close()
    if not row:
        return None
    return {"group_id": group_id, "topic": row[0], "updated_at": row[1]}


def add_group_exam(group_id: str, exam_id: str, title: Optional[str]) -> Dict[str, object]:
    if not exam_id.strip():
        raise ValueError("exam_id required")
    now = datetime.utcnow().isoformat(timespec="seconds") + "Z"
    conn = _get_conn()
    try:
        cur = conn.execute(
            "SELECT COUNT(*) FROM study_group_exams WHERE group_id = ?",
            (group_id,),
        )
        count = int(cur.fetchone()[0])
        if count >= 3:
            raise ValueError("maximum exams reached")
        conn.execute(
            """
            INSERT OR REPLACE INTO study_group_exams (group_id, exam_id, title, created_at)
            VALUES (?, ?, ?, ?)
            """,
            (group_id, exam_id.strip(), (title or "").strip(), now),
        )
        conn.commit()
    finally:
        conn.close()
    return {"group_id": group_id, "exam_id": exam_id.strip(), "title": (title or "").strip(), "created_at": now}


def list_group_exams(group_id: str) -> List[Dict[str, object]]:
    conn = _get_conn()
    try:
        cur = conn.execute(
            """
            SELECT exam_id, title, created_at
            FROM study_group_exams
            WHERE group_id = ?
            ORDER BY datetime(created_at) DESC
            """,
            (group_id,),
        )
        rows = cur.fetchall()
    finally:
        conn.close()
    return [
        {"group_id": group_id, "exam_id": row[0], "title": row[1] or "", "created_at": row[2]}
        for row in rows
    ]
