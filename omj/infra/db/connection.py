"""Thin SQLite connection helper."""

import os
import sqlite3
from os import PathLike
from typing import Optional


def _sqlite_timeout_seconds() -> float:
    return max(1.0, float(os.environ.get("OMJ_SQLITE_TIMEOUT_SECONDS", "30")))


def _sqlite_busy_timeout_ms() -> int:
    configured = os.environ.get("OMJ_SQLITE_BUSY_TIMEOUT_MS")
    if configured is not None:
        return max(1000, int(configured))
    return int(_sqlite_timeout_seconds() * 1000)


def connect_sqlite(
    path: str | PathLike[str],
    *,
    row_factory: Optional[type] = None,
) -> sqlite3.Connection:
    """Return a SQLite connection configured for concurrent API traffic."""
    conn = sqlite3.connect(str(path), timeout=_sqlite_timeout_seconds())
    if row_factory is not None:
        conn.row_factory = row_factory
    busy_timeout_ms = _sqlite_busy_timeout_ms()
    conn.execute(f"PRAGMA busy_timeout = {busy_timeout_ms}")
    conn.execute("PRAGMA journal_mode = WAL")
    conn.execute("PRAGMA synchronous = NORMAL")
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def get_db(path: str = "omj/quests.db") -> sqlite3.Connection:
    """Return a SQLite connection with WAL mode and Row factory enabled."""
    conn = connect_sqlite(path, row_factory=sqlite3.Row)
    _ensure_migrations_table(conn)
    return conn


def _ensure_migrations_table(conn: sqlite3.Connection) -> None:
    """Ensure the internal migration-tracking table exists."""
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS _migrations (
            version TEXT PRIMARY KEY,
            applied_at TEXT NOT NULL DEFAULT (datetime('now'))
        )
        """
    )
    conn.commit()
