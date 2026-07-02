import hashlib
import sqlite3
import uuid
from datetime import datetime
from typing import Dict, List, Optional, Tuple

from storage.storage import DB_PATH


def _normalize_invite_code(value: Optional[str]) -> Optional[str]:
    if value is None:
        return None
    code = "".join(ch for ch in value.strip().upper() if not ch.isspace())
    return code or None


def _is_valid_invite_code(value: Optional[str]) -> bool:
    if not value:
        return False
    if len(value) < 6 or len(value) > 12:
        return False
    return value.isalnum()


def _invite_code_exists(invite_code: str) -> bool:
    conn = sqlite3.connect(DB_PATH)
    try:
        cur = conn.execute(
            "SELECT 1 FROM study_groups WHERE invite_code = ? LIMIT 1",
            (invite_code,),
        )
        return cur.fetchone() is not None
    finally:
        conn.close()


def _next_invite_code() -> str:
    for _ in range(32):
        candidate = uuid.uuid4().hex[:8].upper()
        if not _invite_code_exists(candidate):
            return candidate
    raise RuntimeError("failed to generate unique invite code")


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
            owner_role TEXT NOT NULL DEFAULT 'student',
            invite_code TEXT,
            created_at TEXT NOT NULL,
            creator_id TEXT NOT NULL
        )
        """
    )
    try:
        cur.execute(
            "ALTER TABLE study_groups ADD COLUMN owner_role TEXT NOT NULL DEFAULT 'student'"
        )
    except sqlite3.OperationalError:
        pass
    try:
        cur.execute("ALTER TABLE study_groups ADD COLUMN invite_code TEXT")
    except sqlite3.OperationalError:
        pass
    cur.execute(
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_study_groups_invite_code ON study_groups (invite_code)"
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
    # Shared problem/exam tables for group collaboration features.
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS study_group_shared_problems (
            share_id TEXT PRIMARY KEY,
            group_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            codebase_id INTEGER NOT NULL,
            seed INTEGER NOT NULL,
            created_at TEXT NOT NULL
        )
        """
    )
    cur.execute(
        "CREATE INDEX IF NOT EXISTS idx_shared_probs_group ON study_group_shared_problems (group_id, datetime(created_at) DESC)"
    )
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS study_group_shared_exams (
            share_id TEXT PRIMARY KEY,
            group_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            exam_id TEXT NOT NULL,
            seed INTEGER NOT NULL,
            created_at TEXT NOT NULL
        )
        """
    )
    cur.execute(
        "CREATE INDEX IF NOT EXISTS idx_shared_exams_group ON study_group_shared_exams (group_id, datetime(created_at) DESC)"
    )
    conn.commit()
    conn.close()


def _ensure_shared_flows_table() -> None:
    init_study_group_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS study_group_shared_flows (
            share_id TEXT PRIMARY KEY,
            group_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            codebase_id INTEGER NOT NULL,
            seed INTEGER NOT NULL,
            quest_id TEXT,
            quest_title TEXT,
            status_json TEXT,
            all_formulas TEXT,
            answer_riddle TEXT,
            tags TEXT,
            difficulty INTEGER,
            created_at TEXT NOT NULL
        )
        """
    )
    try:
        cur.execute("ALTER TABLE study_group_shared_flows ADD COLUMN tags TEXT")
    except sqlite3.OperationalError:
        pass
    try:
        cur.execute(
            "ALTER TABLE study_group_shared_flows ADD COLUMN difficulty INTEGER"
        )
    except sqlite3.OperationalError:
        pass
    cur.execute(
        "CREATE INDEX IF NOT EXISTS idx_shared_flows_group ON study_group_shared_flows (group_id, datetime(created_at) DESC)"
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
    owner_role: str = "student",
    invite_code: Optional[str] = None,
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

    normalized_owner_role = (owner_role or "student").strip().lower()
    if normalized_owner_role not in ("student", "teacher"):
        normalized_owner_role = "student"

    effective_invite_code: Optional[str]
    if normalized_owner_role == "teacher":
        normalized_invite_code = _normalize_invite_code(invite_code)
        if normalized_invite_code:
            if not _is_valid_invite_code(normalized_invite_code):
                raise ValueError("invite code must be 6-12 alphanumeric characters")
            if _invite_code_exists(normalized_invite_code):
                raise ValueError("invite code already exists")
            effective_invite_code = normalized_invite_code
        else:
            effective_invite_code = _next_invite_code()
    else:
        effective_invite_code = None

    init_study_group_db()
    if count_groups_created_by_user(creator_id) >= 3:
        raise ValueError("creator already owns maximum number of groups")
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
                owner_role,
                invite_code,
                created_at,
                creator_id
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
                normalized_owner_role,
                effective_invite_code,
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
        "owner_role": normalized_owner_role,
        "invite_code": effective_invite_code,
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


def list_member_ids(group_id: str) -> List[str]:
    """Return member user_ids for the given group."""
    conn = _get_conn()
    try:
        return _fetch_member_ids(conn, group_id)
    finally:
        conn.close()


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
                   sg.owner_role,
                   sg.invite_code,
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
                owner_role,
                invite_code,
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
                    "owner_role": owner_role or "student",
                    "invite_code": invite_code,
                    "created_at": created_at,
                    "creator_id": creator_id,
                    "members": int(members),
                    "member_ids": member_ids,
                }
            )
        return results
    finally:
        conn.close()


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
                   owner_role,
                   invite_code,
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
        owner_role,
        invite_code,
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
        "owner_role": owner_role or "student",
        "invite_code": invite_code,
        "created_at": created_at,
        "creator_id": creator_id,
        "member_ids": members,
    }


def get_group_by_invite_code(invite_code: str) -> Optional[Dict[str, object]]:
    normalized = _normalize_invite_code(invite_code)
    if not _is_valid_invite_code(normalized):
        return None
    conn = _get_conn()
    try:
        cur = conn.execute(
            """
            SELECT group_id
            FROM study_groups
            WHERE invite_code = ?
            LIMIT 1
            """,
            (normalized,),
        )
        row = cur.fetchone()
    finally:
        conn.close()
    if not row:
        return None
    return get_group(str(row[0]))


def join_group_by_invite_code(
    user_id: str,
    invite_code: str,
    password: Optional[str] = None,
) -> Dict[str, object]:
    group = get_group_by_invite_code(invite_code)
    if not group:
        raise ValueError("invalid invite code")
    return join_group(str(group["group_id"]), user_id, password)


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


def share_group_problem(group_id: str, user_id: str, codebase_id: int, seed: int, *, cap: int = 30) -> Dict[str, object]:
    """Append a shared problem for the group, enforcing FIFO cap."""
    init_study_group_db()
    now = datetime.utcnow().isoformat(timespec="seconds") + "Z"
    share_id = str(uuid.uuid4())
    conn = _get_conn()
    try:
        conn.execute(
            """
            INSERT INTO study_group_shared_problems (share_id, group_id, user_id, codebase_id, seed, created_at)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (share_id, group_id, user_id, int(codebase_id), int(seed), now),
        )
        # Trim oldest rows beyond cap to keep storage small.
        cur = conn.execute(
            "SELECT COUNT(*) FROM study_group_shared_problems WHERE group_id = ?",
            (group_id,),
        )
        total = int(cur.fetchone()[0])
        if total > cap:
            to_remove = total - cap
            conn.execute(
                """
                DELETE FROM study_group_shared_problems
                WHERE share_id IN (
                    SELECT share_id FROM study_group_shared_problems
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
        "share_id": share_id,
        "group_id": group_id,
        "user_id": user_id,
        "codebase_id": int(codebase_id),
        "seed": int(seed),
        "created_at": now,
    }


def list_shared_group_problems(group_id: str, *, limit: int = 30) -> List[Dict[str, object]]:
    init_study_group_db()
    if limit < 1:
        limit = 1
    if limit > 30:
        limit = 30
    conn = _get_conn()
    try:
        cur = conn.execute(
            """
            SELECT share_id, user_id, codebase_id, seed, created_at
            FROM study_group_shared_problems
            WHERE group_id = ?
            ORDER BY datetime(created_at) DESC
            LIMIT ?
            """,
            (group_id, limit),
        )
        rows = cur.fetchall()
    finally:
        conn.close()
    return [
        {
            "share_id": row[0],
            "group_id": group_id,
            "user_id": row[1],
            "codebase_id": int(row[2]),
            "seed": int(row[3]),
            "created_at": row[4],
        }
        for row in rows
    ]


def share_group_flow(
    group_id: str,
    user_id: str,
    codebase_id: int,
    seed: int,
    *,
    quest_id: Optional[str],
    quest_title: Optional[str],
    status_json: str,
    all_formulas: str,
    answer_riddle: str,
    tags: Optional[str] = None,
    difficulty: Optional[int] = None,
    cap: int = 50,
) -> Dict[str, object]:
    _ensure_shared_flows_table()
    now = datetime.utcnow().isoformat(timespec="seconds") + "Z"
    share_id = str(uuid.uuid4())
    conn = sqlite3.connect(DB_PATH)
    try:
        conn.execute(
            """
            INSERT INTO study_group_shared_flows
            (share_id, group_id, user_id, codebase_id, seed, quest_id, quest_title, status_json, all_formulas, answer_riddle, tags, difficulty, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                share_id,
                group_id,
                user_id,
                int(codebase_id),
                int(seed),
                quest_id,
                quest_title,
                status_json,
                all_formulas,
                answer_riddle,
                tags,
                difficulty,
                now,
            ),
        )
        cur = conn.execute(
            "SELECT COUNT(*) FROM study_group_shared_flows WHERE group_id = ?",
            (group_id,),
        )
        total = int(cur.fetchone()[0])
        if total > cap:
            to_remove = total - cap
            conn.execute(
                """
                DELETE FROM study_group_shared_flows
                WHERE share_id IN (
                    SELECT share_id FROM study_group_shared_flows
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
        "share_id": share_id,
        "group_id": group_id,
        "user_id": user_id,
        "codebase_id": int(codebase_id),
        "seed": int(seed),
        "quest_id": quest_id or "",
        "quest_title": quest_title or "",
        "status_json": status_json,
        "all_formulas": all_formulas,
        "answer_riddle": answer_riddle,
        "tags": _split_tags(tags),
        "difficulty": difficulty,
        "created_at": now,
    }


def list_shared_group_flows(
    group_id: str,
    *,
    limit: int = 30,
    tags: Optional[List[str]] = None,
    user_id: Optional[str] = None,
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
) -> List[Dict[str, object]]:
    """List shared flows with optional filters."""
    _ensure_shared_flows_table()
    if limit < 1:
        limit = 1
    if limit > 50:
        limit = 50
    conn = sqlite3.connect(DB_PATH)
    try:
        clauses = ["group_id = ?"]
        params: List[object] = [group_id]
        if user_id:
            clauses.append("user_id = ?")
            params.append(user_id)
        if date_from:
            clauses.append("datetime(created_at) >= datetime(?)")
            params.append(date_from)
        if date_to:
            clauses.append("datetime(created_at) <= datetime(?)")
            params.append(date_to)
        if tags:
            for tag in tags:
                clauses.append("tags LIKE ?")
                params.append(f"%{tag}%")
        where_clause = " AND ".join(clauses)
        query = f"""
            SELECT share_id, user_id, codebase_id, seed, quest_id, quest_title,
                   status_json, all_formulas, answer_riddle, tags, difficulty, created_at
            FROM study_group_shared_flows
            WHERE {where_clause}
            ORDER BY datetime(created_at) DESC
            LIMIT ?
        """
        params.append(limit)
        cur = conn.execute(query, tuple(params))
        rows = cur.fetchall()
    finally:
        conn.close()
    return [
        {
            "share_id": row[0],
            "group_id": group_id,
            "user_id": row[1],
            "codebase_id": int(row[2]),
            "seed": int(row[3]),
            "quest_id": row[4] or "",
            "quest_title": row[5] or "",
            "status_json": row[6] or "",
            "all_formulas": row[7] or "",
            "answer_riddle": row[8] or "",
            "tags": _split_tags(row[9]),
            "difficulty": row[10],
            "created_at": row[11],
        }
        for row in rows
    ]


def delete_shared_flow(share_id: str, *, user_id: str) -> bool:
    """Delete a shared flow if owned by user."""
    _ensure_shared_flows_table()
    conn = sqlite3.connect(DB_PATH)
    try:
        cur = conn.execute(
            "SELECT user_id FROM study_group_shared_flows WHERE share_id = ?",
            (share_id,),
        )
        row = cur.fetchone()
        if not row or row[0] != user_id:
            return False
        conn.execute(
            "DELETE FROM study_group_shared_flows WHERE share_id = ?",
            (share_id,),
        )
        conn.commit()
        return True
    finally:
        conn.close()


def get_shared_flow(share_id: str) -> Optional[Dict[str, object]]:
    _ensure_shared_flows_table()
    conn = sqlite3.connect(DB_PATH)
    try:
        cur = conn.execute(
            """
            SELECT share_id, group_id, user_id, codebase_id, seed, quest_id, quest_title, status_json, all_formulas, answer_riddle, tags, difficulty, created_at
            FROM study_group_shared_flows
            WHERE share_id = ?
            """,
            (share_id,),
        )
        row = cur.fetchone()
    finally:
        conn.close()
    if not row:
        return None
    return {
        "share_id": row[0],
        "group_id": row[1],
        "user_id": row[2],
        "codebase_id": int(row[3]),
        "seed": int(row[4]),
        "quest_id": row[5] or "",
        "quest_title": row[6] or "",
        "status_json": row[7] or "",
        "all_formulas": row[8] or "",
        "answer_riddle": row[9] or "",
        "tags": _split_tags(row[10]),
        "difficulty": row[11],
        "created_at": row[12],
    }


def _split_tags(raw: object) -> List[str]:
    if raw is None:
        return []
    if isinstance(raw, list):
        return [str(x) for x in raw if str(x).strip()]
    return [
        part.strip()
        for part in str(raw).split(",")
        if part and part.strip()
    ]


def share_group_exam(group_id: str, user_id: str, exam_id: str, seed: int, *, cap: int = 5) -> Dict[str, object]:
    """Append a shared exam entry for the group, enforcing FIFO cap."""
    init_study_group_db()
    exam_value = exam_id.strip()
    if not exam_value:
        raise ValueError("exam_id required")
    now = datetime.utcnow().isoformat(timespec="seconds") + "Z"
    share_id = str(uuid.uuid4())
    conn = _get_conn()
    try:
        conn.execute(
            """
            INSERT INTO study_group_shared_exams (share_id, group_id, user_id, exam_id, seed, created_at)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (share_id, group_id, user_id, exam_value, int(seed), now),
        )
        cur = conn.execute(
            "SELECT COUNT(*) FROM study_group_shared_exams WHERE group_id = ?",
            (group_id,),
        )
        total = int(cur.fetchone()[0])
        if total > cap:
            to_remove = total - cap
            conn.execute(
                """
                DELETE FROM study_group_shared_exams
                WHERE share_id IN (
                    SELECT share_id FROM study_group_shared_exams
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
        "share_id": share_id,
        "group_id": group_id,
        "user_id": user_id,
        "exam_id": exam_value,
        "seed": int(seed),
        "created_at": now,
    }


def list_shared_group_exams(group_id: str, *, limit: int = 5) -> List[Dict[str, object]]:
    init_study_group_db()
    if limit < 1:
        limit = 1
    if limit > 50:
        limit = 50
    conn = _get_conn()
    try:
        cur = conn.execute(
            """
            SELECT share_id, user_id, exam_id, seed, created_at
            FROM study_group_shared_exams
            WHERE group_id = ?
            ORDER BY datetime(created_at) DESC
            LIMIT ?
            """,
            (group_id, limit),
        )
        rows = cur.fetchall()
    finally:
        conn.close()
    return [
        {
            "share_id": row[0],
            "group_id": group_id,
            "user_id": row[1],
            "exam_id": row[2],
            "seed": int(row[3]),
            "created_at": row[4],
        }
        for row in rows
    ]


def search_study_groups(
    keyword: str,
    *,
    limit: int = 20,
    exclude_user_id: Optional[str] = None,
    include_teacher_groups: bool = False,
) -> List[Dict[str, object]]:
    """Search public study groups by (case-insensitive) name substring."""
    query = keyword.strip()
    if not query:
        return []
    if limit < 1:
        limit = 1
    if limit > 50:
        limit = 50

    conn = _get_conn()
    try:
        params: List[object] = [f"%{query.lower()}%"]
        teacher_filter = (
            "AND LOWER(COALESCE(sg.owner_role, 'student')) != 'teacher'"
            if not include_teacher_groups
            else ""
        )
        exclude_clause = ""
        if exclude_user_id:
            exclude_clause = (
                "AND sg.group_id NOT IN ("
                "SELECT group_id FROM study_group_members WHERE user_id = ?)"
            )
            params.append(exclude_user_id)
        params.append(limit)
        cur = conn.execute(
            f"""
            SELECT sg.group_id,
                   sg.name,
                   sg.description,
                   sg.max_members,
                   sg.is_public,
                   sg.logo_index,
                   sg.lock_enabled,
                   sg.owner_role,
                   sg.invite_code,
                   sg.created_at,
                   sg.creator_id,
                   COUNT(m.user_id) AS members
            FROM study_groups sg
            LEFT JOIN study_group_members m ON sg.group_id = m.group_id
            WHERE sg.is_public = 1
              {teacher_filter}
              AND lower(sg.name) LIKE ?
              {exclude_clause}
            GROUP BY sg.group_id
            ORDER BY datetime(sg.created_at) DESC
            LIMIT ?
            """,
            tuple(params),
        )
        rows = cur.fetchall()
        results: List[Dict[str, object]] = []
        for row in rows:
            (
                group_id,
                name,
                description,
                max_members,
                is_public,
                logo_index,
                lock_enabled,
                owner_role,
                invite_code,
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
                    "owner_role": owner_role or "student",
                    "invite_code": (
                        invite_code
                        if include_teacher_groups and (owner_role or "student") == "teacher"
                        else None
                    ),
                    "created_at": created_at,
                    "creator_id": creator_id,
                    "members": int(members),
                    "member_ids": member_ids,
                }
            )
        return results
    finally:
        conn.close()
