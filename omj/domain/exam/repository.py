"""SQLite CRUD repository for the Exam domain.

Uses raw sqlite3 against the shared ``quests.db`` file.
"""
import sqlite3
from datetime import datetime, timezone
from typing import List, Optional

from domain.exam.models import ExamPaper
from storage.storage import DB_PATH


def _ensure_exam_tables() -> None:
    """Create ``exam_paper`` and ``exam_layout_cache`` tables if they do not exist."""
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()

    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS exam_paper (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            course_id INTEGER NOT NULL,
            title TEXT NOT NULL,
            type TEXT NOT NULL CHECK(type IN ('daily', 'weekly', 'mock')),
            total_minutes INTEGER NOT NULL DEFAULT 0,
            layout_json TEXT,
            by_unit_json TEXT,
            created_at TEXT NOT NULL DEFAULT (datetime('now'))
        )
        """
    )

    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS exam_layout_cache (
            course_id INTEGER NOT NULL,
            seed INTEGER NOT NULL,
            layout_json TEXT NOT NULL,
            created_at TEXT NOT NULL DEFAULT (datetime('now')),
            PRIMARY KEY (course_id, seed)
        )
        """
    )

    conn.commit()
    conn.close()


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def create_exam_paper(paper: ExamPaper) -> int:
    """Insert a new exam paper and return its generated ``id``."""
    _ensure_exam_tables()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO exam_paper
            (course_id, title, type, total_minutes, layout_json, by_unit_json, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        (
            paper.course_id,
            paper.title,
            paper.type,
            paper.total_minutes,
            paper.layout_json,
            paper.by_unit_json,
            _now_iso(),
        ),
    )
    conn.commit()
    paper_id = cur.lastrowid
    conn.close()
    return paper_id


def get_exam_paper(exam_id: int) -> Optional[ExamPaper]:
    """Fetch a single exam paper by ``id``."""
    _ensure_exam_tables()
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    cur.execute("SELECT * FROM exam_paper WHERE id = ?", (exam_id,))
    row = cur.fetchone()
    conn.close()
    if row is None:
        return None
    return ExamPaper.model_validate(dict(row))


def list_exam_papers(course_id: Optional[int] = None) -> List[ExamPaper]:
    """List exam papers, optionally filtered by ``course_id``."""
    _ensure_exam_tables()
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    if course_id is not None:
        cur.execute(
            "SELECT * FROM exam_paper WHERE course_id = ? ORDER BY created_at DESC",
            (course_id,),
        )
    else:
        cur.execute("SELECT * FROM exam_paper ORDER BY created_at DESC")
    rows = cur.fetchall()
    conn.close()
    return [ExamPaper.model_validate(dict(r)) for r in rows]
