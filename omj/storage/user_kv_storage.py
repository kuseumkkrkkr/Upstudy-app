import sqlite3
import time
from typing import Optional

from storage.storage import DB_PATH


def init_user_kv_db() -> None:
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS user_kv (
            user_id TEXT NOT NULL,
            key TEXT NOT NULL,
            value TEXT NOT NULL,
            updated_at INTEGER NOT NULL,
            PRIMARY KEY (user_id, key)
        )
        """
    )
    conn.commit()
    conn.close()


def get_user_kv(user_id: str, key: str) -> Optional[str]:
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        "SELECT value FROM user_kv WHERE user_id = ? AND key = ?",
        (user_id, key),
    )
    row = cur.fetchone()
    conn.close()
    return row[0] if row else None


def set_user_kv(user_id: str, key: str, value: str) -> None:
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    now_ms = int(time.time() * 1000)
    cur.execute(
        """
        INSERT INTO user_kv (user_id, key, value, updated_at)
        VALUES (?, ?, ?, ?)
        ON CONFLICT(user_id, key) DO UPDATE SET
            value = excluded.value,
            updated_at = excluded.updated_at
        """,
        (user_id, key, value, now_ms),
    )
    conn.commit()
    conn.close()


def delete_user_kv(user_id: str, key: str) -> None:
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        "DELETE FROM user_kv WHERE user_id = ? AND key = ?",
        (user_id, key),
    )
    conn.commit()
    conn.close()
