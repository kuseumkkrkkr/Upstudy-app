"""SQLite-backed repository for curriculum domain.

Provides:
- _ensure_curriculum_tables: idempotent schema init
- save_ovr / get_ovr: StudentOVR persistence
- save_path / get_path / get_latest_path: CurriculumPath persistence
"""
from __future__ import annotations

import json
import sqlite3
import time
from typing import Optional

from storage.storage import DB_PATH
from domain.curriculum.models import CurriculumPath, PathStep, StudentOVR


def _ensure_curriculum_tables() -> None:
    """Create curriculum tables if they do not exist."""
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS student_ovr_snapshot (
                user_id TEXT PRIMARY KEY,
                accuracy_json TEXT NOT NULL DEFAULT '{}',
                speed_json TEXT NOT NULL DEFAULT '{}',
                power_json TEXT NOT NULL DEFAULT '{}',
                last_updated INTEGER DEFAULT (strftime('%s','now'))
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS curriculum_path (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id TEXT NOT NULL,
                course_id TEXT NOT NULL,
                sequence_json TEXT NOT NULL DEFAULT '[]',
                estimated_weeks INTEGER NOT NULL DEFAULT 12,
                target_mastery REAL NOT NULL DEFAULT 0.8,
                adaptive_rules_json TEXT NOT NULL DEFAULT '{}',
                created_at INTEGER DEFAULT (strftime('%s','now')),
                updated_at INTEGER DEFAULT (strftime('%s','now'))
            )
            """
        )
        conn.commit()


def _ovr_to_row(ovr: StudentOVR) -> dict[str, object]:
    return {
        "user_id": ovr.user_id,
        "accuracy_json": json.dumps(ovr.accuracy_by_topic, ensure_ascii=False),
        "speed_json": json.dumps(ovr.speed_by_topic, ensure_ascii=False),
        "power_json": json.dumps(ovr.power_by_topic, ensure_ascii=False),
        "last_updated": ovr.last_updated or int(time.time()),
    }


def _row_to_ovr(row: sqlite3.Row) -> StudentOVR:
    data = dict(row)
    return StudentOVR(
        user_id=data["user_id"],
        accuracy_by_topic=json.loads(data.get("accuracy_json", "{}") or "{}"),
        speed_by_topic=json.loads(data.get("speed_json", "{}") or "{}"),
        power_by_topic=json.loads(data.get("power_json", "{}") or "{}"),
        last_updated=data.get("last_updated"),
    )


def save_ovr(ovr: StudentOVR) -> bool:
    """Upsert a StudentOVR snapshot. Returns True on success."""
    _ensure_curriculum_tables()
    payload = _ovr_to_row(ovr)
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute(
            """
            INSERT INTO student_ovr_snapshot (
                user_id, accuracy_json, speed_json, power_json, last_updated
            )
            VALUES (
                :user_id, :accuracy_json, :speed_json, :power_json, :last_updated
            )
            ON CONFLICT(user_id) DO UPDATE SET
                accuracy_json = excluded.accuracy_json,
                speed_json = excluded.speed_json,
                power_json = excluded.power_json,
                last_updated = excluded.last_updated
            """,
            payload,
        )
        conn.commit()
    return True


def get_ovr(user_id: str) -> Optional[StudentOVR]:
    """Fetch a StudentOVR by user_id."""
    _ensure_curriculum_tables()
    with sqlite3.connect(DB_PATH) as conn:
        conn.row_factory = sqlite3.Row
        row = conn.execute(
            "SELECT * FROM student_ovr_snapshot WHERE user_id = ?",
            (user_id,),
        ).fetchone()
        if row is None:
            return None
        return _row_to_ovr(row)


def _path_to_row(path: CurriculumPath, user_id: str) -> dict[str, object]:
    return {
        "course_id": path.course_id,
        "sequence_json": json.dumps(
            [s.model_dump(mode="json") for s in path.sequence],
            ensure_ascii=False,
        ),
        "estimated_weeks": path.estimated_weeks,
        "target_mastery": path.target_mastery,
        "adaptive_rules_json": path.adaptive_rules_json,
        "user_id": user_id,
        "updated_at": int(time.time()),
    }


def _row_to_path(row: sqlite3.Row) -> CurriculumPath:
    data = dict(row)
    sequence_raw = json.loads(data.get("sequence_json", "[]") or "[]")
    sequence = [PathStep.model_validate(s) for s in sequence_raw]
    return CurriculumPath(
        course_id=data["course_id"],
        sequence=sequence,
        estimated_weeks=data.get("estimated_weeks", 12),
        target_mastery=data.get("target_mastery", 0.8),
        adaptive_rules_json=data.get("adaptive_rules_json", "{}"),
    )


def save_path(path: CurriculumPath, *, user_id: str) -> int:
    """Insert a CurriculumPath. Returns the generated path id."""
    _ensure_curriculum_tables()
    payload = _path_to_row(path, user_id)
    with sqlite3.connect(DB_PATH) as conn:
        cur = conn.execute(
            """
            INSERT INTO curriculum_path (
                user_id, course_id, sequence_json, estimated_weeks,
                target_mastery, adaptive_rules_json, created_at, updated_at
            )
            VALUES (
                :user_id, :course_id, :sequence_json, :estimated_weeks,
                :target_mastery, :adaptive_rules_json,
                strftime('%s','now'), :updated_at
            )
            """,
            payload,
        )
        conn.commit()
        return cur.lastrowid or 0


def get_path(user_id: str, course_id: str) -> Optional[CurriculumPath]:
    """Fetch the most recent CurriculumPath for a user and course."""
    _ensure_curriculum_tables()
    with sqlite3.connect(DB_PATH) as conn:
        conn.row_factory = sqlite3.Row
        row = conn.execute(
            """
            SELECT * FROM curriculum_path
            WHERE user_id = ? AND course_id = ?
            ORDER BY updated_at DESC
            LIMIT 1
            """,
            (user_id, course_id),
        ).fetchone()
        if row is None:
            return None
        return _row_to_path(row)


def get_path_by_id(path_id: int) -> Optional[tuple[CurriculumPath, str]]:
    """Fetch a CurriculumPath by its id. Returns (path, user_id) or None."""
    _ensure_curriculum_tables()
    with sqlite3.connect(DB_PATH) as conn:
        conn.row_factory = sqlite3.Row
        row = conn.execute(
            "SELECT * FROM curriculum_path WHERE id = ?",
            (path_id,),
        ).fetchone()
        if row is None:
            return None
        return _row_to_path(row), row["user_id"]


def get_latest_path(user_id: str) -> Optional[CurriculumPath]:
    """Fetch the most recent CurriculumPath for a user (any course)."""
    _ensure_curriculum_tables()
    with sqlite3.connect(DB_PATH) as conn:
        conn.row_factory = sqlite3.Row
        row = conn.execute(
            """
            SELECT * FROM curriculum_path
            WHERE user_id = ?
            ORDER BY updated_at DESC
            LIMIT 1
            """,
            (user_id,),
        ).fetchone()
        if row is None:
            return None
        return _row_to_path(row)
