"""Promote teacher-app accounts to role='teacher'.

Teacher accounts use an email address as username. Older local DBs may have
accounts created through the teacher app but left with the default student role.
This migration fixes only accounts that clearly match the teacher-account shape.
"""

from __future__ import annotations

import sqlite3
from pathlib import Path


def promote_teacher_roles(db_path: str | Path) -> int:
    path = Path(db_path)
    if not path.exists():
        raise FileNotFoundError(path)

    with sqlite3.connect(path) as conn:
        cur = conn.cursor()
        cur.execute("PRAGMA table_info(users)")
        columns = {row[1] for row in cur.fetchall()}
        if not columns:
            return 0
        if "role" not in columns:
            cur.execute("ALTER TABLE users ADD COLUMN role TEXT DEFAULT 'student'")
        if "email" not in columns:
            cur.execute("ALTER TABLE users ADD COLUMN email TEXT")
        if "grade" not in columns:
            cur.execute("ALTER TABLE users ADD COLUMN grade TEXT")

        cur.execute(
            """
            UPDATE users
            SET role = 'teacher',
                grade = 'teacher',
                email = COALESCE(NULLIF(email, ''), username)
            WHERE lower(COALESCE(role, 'student')) <> 'teacher'
              AND username LIKE '%@%'
              AND (
                lower(COALESCE(grade, '')) = 'teacher'
                OR lower(COALESCE(email, '')) = lower(username)
              )
            """
        )
        conn.commit()
        return cur.rowcount


if __name__ == "__main__":
    default_db = Path(__file__).resolve().parents[1] / "quests.db"
    changed = promote_teacher_roles(default_db)
    print(f"promoted_teacher_roles={changed} db={default_db}")
