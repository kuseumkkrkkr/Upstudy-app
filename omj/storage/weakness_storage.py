import sqlite3
from datetime import datetime
from typing import Dict, Iterable, List

from storage.storage import DB_PATH


def _now_iso() -> str:
    return datetime.utcnow().isoformat(timespec="seconds") + "Z"


def init_weakness_db() -> None:
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS user_weakness_tags (
            user_id TEXT NOT NULL,
            tag TEXT NOT NULL,
            count INTEGER NOT NULL,
            updated_at TEXT NOT NULL,
            PRIMARY KEY (user_id, tag)
        )
        """
    )
    conn.commit()
    conn.close()


def increment_weakness_tags(
    *,
    user_id: str,
    tags: Iterable[str],
    now_iso: str | None = None,
) -> None:
    tag_list = [tag.strip() for tag in tags if str(tag).strip()]
    if not tag_list:
        return
    now_iso = now_iso or _now_iso()
    init_weakness_db()
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    counts: Dict[str, int] = {}
    for tag in tag_list:
        counts[tag] = counts.get(tag, 0) + 1
    payload = [(user_id, tag, delta, now_iso) for tag, delta in counts.items()]
    cursor.executemany(
        """
        INSERT INTO user_weakness_tags (user_id, tag, count, updated_at)
        VALUES (?, ?, ?, ?)
        ON CONFLICT(user_id, tag) DO UPDATE SET
            count = user_weakness_tags.count + excluded.count,
            updated_at = excluded.updated_at
        """,
        payload,
    )
    conn.commit()
    conn.close()


def list_weakness_tags(user_id: str) -> List[Dict[str, str | int]]:
    init_weakness_db()
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute(
        """
        SELECT tag, count, updated_at
        FROM user_weakness_tags
        WHERE user_id = ?
        ORDER BY count DESC, updated_at DESC
        """,
        (user_id,),
    )
    rows = cursor.fetchall()
    conn.close()
    return [
        {"tag": row[0], "count": row[1], "updated_at": row[2]}
        for row in rows
    ]

