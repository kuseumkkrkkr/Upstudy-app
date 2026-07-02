"""SQLite CRUD repository for the Quest Variant domain.

Uses raw sqlite3 against the shared ``quests.db`` file.
"""
from __future__ import annotations

import json
import sqlite3
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from domain.quest.models import QuestFlow, QuestVariant
from storage.storage import DB_PATH


# ---------------------------------------------------------------------------
# Schema helpers
# ---------------------------------------------------------------------------


def _ensure_quest_tables() -> None:
    """Create ``quest_variant`` and ``quest_flow`` tables if missing."""
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()

    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS quest_variant (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            original_quest_id INTEGER NOT NULL,
            variant_type TEXT NOT NULL,
            generated_problem_json TEXT NOT NULL,
            difficulty_adjustment INTEGER NOT NULL DEFAULT 0,
            ai_confidence REAL,
            created_at TEXT NOT NULL DEFAULT (datetime('now'))
        )
        """
    )

    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS quest_flow (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            course_id INTEGER NOT NULL,
            quest_sequence_json TEXT NOT NULL DEFAULT '[]',
            flow_rules_json TEXT
        )
        """
    )

    conn.commit()
    conn.close()


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


# ---------------------------------------------------------------------------
# QuestVariant CRUD
# ---------------------------------------------------------------------------


def create_variant(variant: QuestVariant) -> int:
    """Insert a new quest variant and return its generated ``id``."""
    _ensure_quest_tables()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO quest_variant
            (original_quest_id, variant_type, generated_problem_json,
             difficulty_adjustment, ai_confidence, created_at)
        VALUES (?, ?, ?, ?, ?, ?)
        """,
        (
            variant.original_quest_id,
            variant.variant_type,
            variant.generated_problem_json,
            variant.difficulty_adjustment,
            variant.ai_confidence,
            variant.created_at or _now_iso(),
        ),
    )
    variant_id = cur.lastrowid
    conn.commit()
    conn.close()
    return variant_id or 0


def get_variant(variant_id: int) -> Optional[QuestVariant]:
    """Retrieve a single quest variant by ``id``."""
    _ensure_quest_tables()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        "SELECT * FROM quest_variant WHERE id = ?",
        (variant_id,),
    )
    row = cur.fetchone()
    conn.close()
    if row is None:
        return None
    return _row_to_variant(row)


def list_variants_by_original(original_quest_id: int) -> List[QuestVariant]:
    """Return all variants for a given original quest id."""
    _ensure_quest_tables()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        "SELECT * FROM quest_variant WHERE original_quest_id = ? ORDER BY created_at DESC",
        (original_quest_id,),
    )
    rows = cur.fetchall()
    conn.close()
    return [_row_to_variant(row) for row in rows]


def update_variant(variant: QuestVariant) -> bool:
    """Update an existing quest variant. Returns ``True`` if a row was affected."""
    if variant.id is None:
        return False
    _ensure_quest_tables()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        UPDATE quest_variant
        SET original_quest_id = ?,
            variant_type = ?,
            generated_problem_json = ?,
            difficulty_adjustment = ?,
            ai_confidence = ?,
            created_at = ?
        WHERE id = ?
        """,
        (
            variant.original_quest_id,
            variant.variant_type,
            variant.generated_problem_json,
            variant.difficulty_adjustment,
            variant.ai_confidence,
            variant.created_at or _now_iso(),
            variant.id,
        ),
    )
    affected = cur.rowcount > 0
    conn.commit()
    conn.close()
    return affected


def delete_variant(variant_id: int) -> bool:
    """Delete a quest variant by ``id``. Returns ``True`` if a row was deleted."""
    _ensure_quest_tables()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("DELETE FROM quest_variant WHERE id = ?", (variant_id,))
    affected = cur.rowcount > 0
    conn.commit()
    conn.close()
    return affected


# ---------------------------------------------------------------------------
# QuestFlow CRUD
# ---------------------------------------------------------------------------


def create_flow(flow: QuestFlow) -> int:
    """Insert a new quest flow and return its generated ``id``."""
    _ensure_quest_tables()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO quest_flow
            (course_id, quest_sequence_json, flow_rules_json)
        VALUES (?, ?, ?)
        """,
        (
            flow.course_id,
            json.dumps(flow.quest_sequence, ensure_ascii=False),
            flow.flow_rules_json,
        ),
    )
    flow_id = cur.lastrowid
    conn.commit()
    conn.close()
    return flow_id or 0


def get_flow(flow_id: int) -> Optional[QuestFlow]:
    """Retrieve a single quest flow by ``id``."""
    _ensure_quest_tables()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("SELECT * FROM quest_flow WHERE id = ?", (flow_id,))
    row = cur.fetchone()
    conn.close()
    if row is None:
        return None
    return _row_to_flow(row)


def list_flows_by_course(course_id: int) -> List[QuestFlow]:
    """Return all quest flows for a given course id."""
    _ensure_quest_tables()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        "SELECT * FROM quest_flow WHERE course_id = ? ORDER BY id DESC",
        (course_id,),
    )
    rows = cur.fetchall()
    conn.close()
    return [_row_to_flow(row) for row in rows]


def update_flow(flow: QuestFlow) -> bool:
    """Update an existing quest flow. Returns ``True`` if a row was affected."""
    if flow.id is None:
        return False
    _ensure_quest_tables()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        UPDATE quest_flow
        SET course_id = ?,
            quest_sequence_json = ?,
            flow_rules_json = ?
        WHERE id = ?
        """,
        (
            flow.course_id,
            json.dumps(flow.quest_sequence, ensure_ascii=False),
            flow.flow_rules_json,
            flow.id,
        ),
    )
    affected = cur.rowcount > 0
    conn.commit()
    conn.close()
    return affected


def delete_flow(flow_id: int) -> bool:
    """Delete a quest flow by ``id``. Returns ``True`` if a row was deleted."""
    _ensure_quest_tables()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("DELETE FROM quest_flow WHERE id = ?", (flow_id,))
    affected = cur.rowcount > 0
    conn.commit()
    conn.close()
    return affected


# ---------------------------------------------------------------------------
# Row mappers
# ---------------------------------------------------------------------------


def _row_to_variant(row: Any) -> QuestVariant:
    """Map a sqlite3 row tuple to a ``QuestVariant``."""
    return QuestVariant(
        id=row[0],
        original_quest_id=row[1],
        variant_type=row[2],
        generated_problem_json=row[3],
        difficulty_adjustment=row[4],
        ai_confidence=row[5],
        created_at=row[6],
    )


def _row_to_flow(row: Any) -> QuestFlow:
    """Map a sqlite3 row tuple to a ``QuestFlow``."""
    sequence: List[int] = []
    if row[2]:
        try:
            parsed = json.loads(row[2])
            if isinstance(parsed, list):
                sequence = [int(x) for x in parsed]
        except (json.JSONDecodeError, ValueError):
            sequence = []
    return QuestFlow(
        id=row[0],
        course_id=row[1],
        quest_sequence=sequence,
        flow_rules_json=row[3],
    )
