"""Thin SQLite connection helper."""

import sqlite3


def get_db(path: str = "omj/quests.db") -> sqlite3.Connection:
    """Return a SQLite connection with WAL mode and Row factory enabled."""
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
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
