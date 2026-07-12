import sqlite3
import threading
import time
from typing import Optional

from infra.db.connection import connect_sqlite
from storage.storage import DB_PATH

_SQLITE_TIMEOUT_SECONDS = 30.0
_USER_KV_READY: set[str] = set()
_USER_KV_LOCK = threading.Lock()


def _connect() -> sqlite3.Connection:
    return connect_sqlite(DB_PATH)


def init_user_kv_db() -> None:
    if DB_PATH in _USER_KV_READY:
        return
    with _USER_KV_LOCK:
        if DB_PATH in _USER_KV_READY:
            return
        conn = _connect()
        conn.execute("PRAGMA journal_mode = WAL")
        conn.execute("PRAGMA synchronous = NORMAL")
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
        _USER_KV_READY.add(DB_PATH)


def get_user_kv(user_id: str, key: str) -> Optional[str]:
    init_user_kv_db()
    conn = _connect()
    cur = conn.cursor()
    cur.execute(
        "SELECT value FROM user_kv WHERE user_id = ? AND key = ?",
        (user_id, key),
    )
    row = cur.fetchone()
    conn.close()
    return row[0] if row else None


def set_user_kv(user_id: str, key: str, value: str) -> None:
    init_user_kv_db()
    conn = _connect()
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
    init_user_kv_db()
    conn = _connect()
    cur = conn.cursor()
    cur.execute(
        "DELETE FROM user_kv WHERE user_id = ? AND key = ?",
        (user_id, key),
    )
    conn.commit()
    conn.close()
