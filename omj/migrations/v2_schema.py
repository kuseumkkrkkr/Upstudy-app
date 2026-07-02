"""Migration: v2 schema additions.

Adds all v2 tables (course_v2, challenge, level_test, academy,
academy_group, academy_group_member) and composite indexes.
Reuses the existing job_state helper instead of duplicating it.
"""

import sqlite3

from services.jobs.store import JobStore


def _ensure_column(conn: sqlite3.Connection, table: str, column: str, definition: str) -> None:
    """Adds missing column to an existing table (no-op if present)."""
    cur = conn.cursor()
    cur.execute(f"PRAGMA table_info({table})")
    cols = [row[1] for row in cur.fetchall()]
    if column not in cols:
        cur.execute(f"ALTER TABLE {table} ADD COLUMN {definition}")
        conn.commit()


def apply(conn: sqlite3.Connection) -> None:
    """Apply the v2 schema migration."""
    cur = conn.cursor()

    # Determine DB path so we can delegate to JobStore._ensure_tables()
    db_path = ""
    for seq, name, file in conn.execute("PRAGMA database_list").fetchall():
        if name == "main":
            db_path = file or ""
            break

    # --- course_v2 ---
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS course_v2 (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            description TEXT NOT NULL DEFAULT '',
            difficulty TEXT NOT NULL DEFAULT '',
            duration TEXT NOT NULL DEFAULT '',
            tags TEXT NOT NULL DEFAULT '[]',
            focus_tags TEXT NOT NULL DEFAULT '[]',
            target_ovr INTEGER DEFAULT 0,
            textbook_id TEXT,
            textbook_pages INTEGER DEFAULT 0,
            is_demo INTEGER NOT NULL DEFAULT 0,
            modules_json TEXT NOT NULL DEFAULT '[]',
            pass_policy_json TEXT,
            flow_policy_json TEXT,
            challenge_policy_json TEXT,
            schedule_policy_json TEXT,
            runtime_flags_json TEXT,
            created_at INTEGER DEFAULT (strftime('%s','now')),
            updated_at INTEGER DEFAULT (strftime('%s','now'))
        )
        """
    )

    # --- challenge ---
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS challenge (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            course_id TEXT,
            type TEXT NOT NULL,
            module_id TEXT,
            title TEXT NOT NULL,
            detail TEXT,
            due_date TEXT,
            status TEXT DEFAULT 'pending',
            payload_json TEXT,
            created_at INTEGER DEFAULT (strftime('%s','now')),
            updated_at INTEGER DEFAULT (strftime('%s','now'))
        )
        """
    )

    # --- level_test ---
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS level_test (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            type TEXT NOT NULL,
            title TEXT NOT NULL,
            detail TEXT,
            score INTEGER,
            max_score INTEGER,
            status TEXT DEFAULT 'pending',
            payload_json TEXT,
            created_at INTEGER DEFAULT (strftime('%s','now')),
            updated_at INTEGER DEFAULT (strftime('%s','now'))
        )
        """
    )

    # --- academy ---
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS academy (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            description TEXT,
            location TEXT,
            contact_email TEXT,
            metadata_json TEXT,
            created_at INTEGER DEFAULT (strftime('%s','now')),
            updated_at INTEGER DEFAULT (strftime('%s','now'))
        )
        """
    )

    # --- academy_group ---
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS academy_group (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            academy_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            description TEXT,
            metadata_json TEXT,
            created_at INTEGER DEFAULT (strftime('%s','now'))
        )
        """
    )

    # --- academy_group_member ---
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS academy_group_member (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            academy_id INTEGER NOT NULL,
            group_id INTEGER NOT NULL,
            user_id TEXT NOT NULL,
            role TEXT DEFAULT 'member',
            joined_at INTEGER DEFAULT (strftime('%s','now'))
        )
        """
    )

    # --- job_state / job_event_log via existing helper ---
    if db_path:
        JobStore(db_path)._ensure_tables()

    # --- Composite indexes ---
    # user_id + course_id
    cur.execute(
        "CREATE INDEX IF NOT EXISTS idx_challenge_user_course ON challenge(user_id, course_id)"
    )
    # module_id
    cur.execute(
        "CREATE INDEX IF NOT EXISTS idx_challenge_module_id ON challenge(module_id)"
    )
    # due_date
    cur.execute(
        "CREATE INDEX IF NOT EXISTS idx_challenge_due_date ON challenge(due_date)"
    )
    # codebase_id + seed (on v1 quest_data — guarded to avoid errors when table is absent)
    cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='quest_data'")
    if cur.fetchone():
        _ensure_column(conn, "quest_data", "codebase_id", "codebase_id INTEGER")
        _ensure_column(conn, "quest_data", "seed", "seed INTEGER")
        cur.execute(
            "CREATE INDEX IF NOT EXISTS idx_quest_data_codebase_seed ON quest_data(codebase_id, seed)"
        )

    # academy_id + group_id
    cur.execute(
        "CREATE INDEX IF NOT EXISTS idx_academy_group_member_academy_group ON academy_group_member(academy_id, group_id)"
    )

    conn.commit()
