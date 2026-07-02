"""SQLite CRUD repository for the Challenge domain.

Uses raw sqlite3 against the shared ``quests.db`` file.
"""
from __future__ import annotations

import json
import sqlite3
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from domain.challenge.models import Challenge, StudentChallengeProgress
from storage.storage import DB_PATH


# ---------------------------------------------------------------------------
# Schema helpers
# ---------------------------------------------------------------------------


def _ensure_challenge_tables() -> None:
    """Create ``challenge`` and ``student_challenge_progress`` tables if missing."""
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()

    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS challenge (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            course_id INTEGER NOT NULL,
            title TEXT NOT NULL,
            challenge_type TEXT NOT NULL DEFAULT 'daily',
            difficulty TEXT NOT NULL DEFAULT '',
            problems_json TEXT NOT NULL DEFAULT '[]',
            reward_points INTEGER NOT NULL DEFAULT 0,
            time_limit_seconds INTEGER NOT NULL DEFAULT 300,
            start_date TEXT NOT NULL DEFAULT '',
            end_date TEXT NOT NULL DEFAULT '',
            status TEXT NOT NULL DEFAULT 'active'
        )
        """
    )

    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS student_challenge_progress (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            challenge_id INTEGER NOT NULL,
            score REAL NOT NULL DEFAULT 0,
            attempts INTEGER NOT NULL DEFAULT 0,
            best_time_seconds INTEGER NOT NULL DEFAULT 0,
            completed_at TEXT,
            reward_claimed INTEGER NOT NULL DEFAULT 0
        )
        """
    )

    conn.commit()
    conn.close()


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


# ---------------------------------------------------------------------------
# Challenge CRUD
# ---------------------------------------------------------------------------


def create_challenge(challenge: Challenge) -> int:
    """Insert a new challenge and return its generated ``id``."""
    _ensure_challenge_tables()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO challenge
            (course_id, title, challenge_type, difficulty, problems_json,
             reward_points, time_limit_seconds, start_date, end_date, status)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            challenge.course_id,
            challenge.title,
            challenge.challenge_type,
            challenge.difficulty,
            challenge.problems_json,
            challenge.reward_points,
            challenge.time_limit_seconds,
            challenge.start_date,
            challenge.end_date,
            challenge.status,
        ),
    )
    challenge_id = cur.lastrowid
    conn.commit()
    conn.close()
    return challenge_id or 0


def get_challenge(challenge_id: int) -> Optional[Challenge]:
    """Retrieve a single challenge by ``id``."""
    _ensure_challenge_tables()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("SELECT * FROM challenge WHERE id = ?", (challenge_id,))
    row = cur.fetchone()
    conn.close()
    if row is None:
        return None
    return _row_to_challenge(row)


def list_challenges() -> List[Challenge]:
    """Return all challenges ordered by newest first."""
    _ensure_challenge_tables()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("SELECT * FROM challenge ORDER BY id DESC")
    rows = cur.fetchall()
    conn.close()
    return [_row_to_challenge(row) for row in rows]


def list_active_challenges(course_id: Optional[int] = None) -> List[Challenge]:
    """Return challenges with ``status='active'``, optionally filtered by ``course_id``."""
    _ensure_challenge_tables()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    if course_id is not None:
        cur.execute(
            "SELECT * FROM challenge WHERE status = ? AND course_id = ? ORDER BY id DESC",
            ("active", course_id),
        )
    else:
        cur.execute(
            "SELECT * FROM challenge WHERE status = ? ORDER BY id DESC",
            ("active",),
        )
    rows = cur.fetchall()
    conn.close()
    return [_row_to_challenge(row) for row in rows]


def update_challenge(challenge: Challenge) -> bool:
    """Update an existing challenge. Returns ``True`` if a row was affected."""
    if challenge.id is None:
        return False
    _ensure_challenge_tables()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        UPDATE challenge
        SET course_id = ?,
            title = ?,
            challenge_type = ?,
            difficulty = ?,
            problems_json = ?,
            reward_points = ?,
            time_limit_seconds = ?,
            start_date = ?,
            end_date = ?,
            status = ?
        WHERE id = ?
        """,
        (
            challenge.course_id,
            challenge.title,
            challenge.challenge_type,
            challenge.difficulty,
            challenge.problems_json,
            challenge.reward_points,
            challenge.time_limit_seconds,
            challenge.start_date,
            challenge.end_date,
            challenge.status,
            challenge.id,
        ),
    )
    affected = cur.rowcount > 0
    conn.commit()
    conn.close()
    return affected


def delete_challenge(challenge_id: int) -> bool:
    """Delete a challenge by ``id``. Returns ``True`` if a row was deleted."""
    _ensure_challenge_tables()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("DELETE FROM challenge WHERE id = ?", (challenge_id,))
    affected = cur.rowcount > 0
    conn.commit()
    conn.close()
    return affected


# ---------------------------------------------------------------------------
# StudentChallengeProgress CRUD
# ---------------------------------------------------------------------------


def create_progress(progress: StudentChallengeProgress) -> int:
    """Insert a new progress record and return its generated ``id``."""
    _ensure_challenge_tables()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO student_challenge_progress
            (user_id, challenge_id, score, attempts, best_time_seconds,
             completed_at, reward_claimed)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        (
            progress.user_id,
            progress.challenge_id,
            progress.score,
            progress.attempts,
            progress.best_time_seconds,
            progress.completed_at,
            int(progress.reward_claimed),
        ),
    )
    progress_id = cur.lastrowid
    conn.commit()
    conn.close()
    return progress_id or 0


def get_progress(user_id: str, challenge_id: int) -> Optional[StudentChallengeProgress]:
    """Retrieve a single progress record by ``user_id`` and ``challenge_id``."""
    _ensure_challenge_tables()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        "SELECT * FROM student_challenge_progress WHERE user_id = ? AND challenge_id = ?",
        (user_id, challenge_id),
    )
    row = cur.fetchone()
    conn.close()
    if row is None:
        return None
    return _row_to_progress(row)


def list_progress_by_user(user_id: str) -> List[StudentChallengeProgress]:
    """Return all progress records for a given user."""
    _ensure_challenge_tables()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        "SELECT * FROM student_challenge_progress WHERE user_id = ? ORDER BY id DESC",
        (user_id,),
    )
    rows = cur.fetchall()
    conn.close()
    return [_row_to_progress(row) for row in rows]


def list_progress_by_challenge(challenge_id: int) -> List[StudentChallengeProgress]:
    """Return all progress records for a given challenge."""
    _ensure_challenge_tables()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        "SELECT * FROM student_challenge_progress WHERE challenge_id = ? ORDER BY id DESC",
        (challenge_id,),
    )
    rows = cur.fetchall()
    conn.close()
    return [_row_to_progress(row) for row in rows]


def update_progress(progress: StudentChallengeProgress) -> bool:
    """Update an existing progress record. Returns ``True`` if a row was affected."""
    if progress.id is None:
        return False
    _ensure_challenge_tables()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        UPDATE student_challenge_progress
        SET user_id = ?,
            challenge_id = ?,
            score = ?,
            attempts = ?,
            best_time_seconds = ?,
            completed_at = ?,
            reward_claimed = ?
        WHERE id = ?
        """,
        (
            progress.user_id,
            progress.challenge_id,
            progress.score,
            progress.attempts,
            progress.best_time_seconds,
            progress.completed_at,
            int(progress.reward_claimed),
            progress.id,
        ),
    )
    affected = cur.rowcount > 0
    conn.commit()
    conn.close()
    return affected


def delete_progress(progress_id: int) -> bool:
    """Delete a progress record by ``id``. Returns ``True`` if a row was deleted."""
    _ensure_challenge_tables()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("DELETE FROM student_challenge_progress WHERE id = ?", (progress_id,))
    affected = cur.rowcount > 0
    conn.commit()
    conn.close()
    return affected


# ---------------------------------------------------------------------------
# Row mappers
# ---------------------------------------------------------------------------


def _row_to_challenge(row: Any) -> Challenge:
    """Map a sqlite3 row tuple to a ``Challenge``."""
    return Challenge(
        id=row[0],
        course_id=row[1],
        title=row[2],
        challenge_type=row[3],
        difficulty=row[4],
        problems_json=row[5],
        reward_points=row[6],
        time_limit_seconds=row[7],
        start_date=row[8],
        end_date=row[9],
        status=row[10],
    )


def _row_to_progress(row: Any) -> StudentChallengeProgress:
    """Map a sqlite3 row tuple to a ``StudentChallengeProgress``."""
    return StudentChallengeProgress(
        id=row[0],
        user_id=row[1],
        challenge_id=row[2],
        score=row[3],
        attempts=row[4],
        best_time_seconds=row[5],
        completed_at=row[6],
        reward_claimed=bool(row[7]),
    )
