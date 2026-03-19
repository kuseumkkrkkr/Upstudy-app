import hashlib
import sqlite3
import uuid
from datetime import datetime
from typing import List, Optional, Dict

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
