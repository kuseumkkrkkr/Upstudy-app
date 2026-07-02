"""SQLite CRUD repository for the Objective Graph domain.

Uses raw sqlite3 against the shared ``quests.db`` file.
"""
from __future__ import annotations

import json
import sqlite3
from typing import List, Optional

from domain.graph.models import LearningObjective, ObjectiveGraph, StudentObjectiveState
from storage.storage import DB_PATH


# ---------------------------------------------------------------------------
# Schema helpers
# ---------------------------------------------------------------------------


def _ensure_graph_tables() -> None:
    """Create ``learning_objective``, ``objective_graph``, and ``student_objective_state`` tables if missing."""
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()

    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS learning_objective (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT NOT NULL,
            title TEXT NOT NULL,
            description TEXT NOT NULL DEFAULT '',
            parent_id INTEGER,
            level INTEGER NOT NULL DEFAULT 1,
            topic TEXT NOT NULL,
            prerequisites_json TEXT NOT NULL DEFAULT '[]',
            estimated_minutes INTEGER NOT NULL DEFAULT 30
        )
        """
    )

    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS objective_graph (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            course_id INTEGER NOT NULL,
            edges_json TEXT NOT NULL DEFAULT '[]'
        )
        """
    )

    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS student_objective_state (
            user_id TEXT NOT NULL,
            objective_id INTEGER NOT NULL,
            status TEXT NOT NULL DEFAULT 'locked',
            mastery_score REAL NOT NULL DEFAULT 0.0,
            last_attempted_at TEXT,
            mastered_at TEXT,
            PRIMARY KEY (user_id, objective_id)
        )
        """
    )

    conn.commit()
    conn.close()


# ---------------------------------------------------------------------------
# LearningObjective CRUD
# ---------------------------------------------------------------------------


def create_learning_objective(obj: LearningObjective) -> int:
    """Insert a new learning objective and return its generated ``id``."""
    _ensure_graph_tables()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO learning_objective
            (code, title, description, parent_id, level, topic, prerequisites_json, estimated_minutes)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            obj.code,
            obj.title,
            obj.description,
            obj.parent_id,
            obj.level,
            obj.topic,
            json.dumps(obj.prerequisites, ensure_ascii=False),
            obj.estimated_minutes,
        ),
    )
    conn.commit()
    obj_id = cur.lastrowid
    conn.close()
    return obj_id or 0


def get_learning_objective(obj_id: int) -> Optional[LearningObjective]:
    """Fetch a single learning objective by ``id``."""
    _ensure_graph_tables()
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    cur.execute("SELECT * FROM learning_objective WHERE id = ?", (obj_id,))
    row = cur.fetchone()
    conn.close()
    if row is None:
        return None
    return _row_to_learning_objective(row)


def list_learning_objectives(course_id: int) -> List[LearningObjective]:
    """List all learning objectives that belong to a course.

    Uses the ``objective_graph`` table to resolve membership: objectives
    referenced by the graph for ``course_id`` are returned.
    """
    _ensure_graph_tables()
    graph = get_graph_by_course(course_id)
    if graph is None:
        return []
    return graph.objectives


def update_learning_objective(obj: LearningObjective) -> bool:
    """Update an existing learning objective. Returns ``True`` if a row was affected."""
    if obj.id is None:
        return False
    _ensure_graph_tables()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        UPDATE learning_objective SET
            code = ?,
            title = ?,
            description = ?,
            parent_id = ?,
            level = ?,
            topic = ?,
            prerequisites_json = ?,
            estimated_minutes = ?
        WHERE id = ?
        """,
        (
            obj.code,
            obj.title,
            obj.description,
            obj.parent_id,
            obj.level,
            obj.topic,
            json.dumps(obj.prerequisites, ensure_ascii=False),
            obj.estimated_minutes,
            obj.id,
        ),
    )
    conn.commit()
    affected = cur.rowcount > 0
    conn.close()
    return affected


def delete_learning_objective(obj_id: int) -> bool:
    """Delete a learning objective by ``id``. Returns ``True`` if a row was deleted."""
    _ensure_graph_tables()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("DELETE FROM learning_objective WHERE id = ?", (obj_id,))
    conn.commit()
    affected = cur.rowcount > 0
    conn.close()
    return affected


# ---------------------------------------------------------------------------
# ObjectiveGraph CRUD
# ---------------------------------------------------------------------------


def create_objective_graph(graph: ObjectiveGraph) -> int:
    """Insert a new objective graph and return its generated ``id``."""
    _ensure_graph_tables()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO objective_graph (course_id, edges_json)
        VALUES (?, ?)
        """,
        (graph.course_id, graph.edges_json),
    )
    conn.commit()
    graph_id = cur.lastrowid
    conn.close()
    return graph_id or 0


def get_graph_by_course(course_id: int) -> Optional[ObjectiveGraph]:
    """Fetch the objective graph for a ``course_id``, hydrated with objectives."""
    _ensure_graph_tables()
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()

    cur.execute("SELECT * FROM objective_graph WHERE course_id = ?", (course_id,))
    row = cur.fetchone()
    if row is None:
        conn.close()
        return None

    graph_id = row["id"]
    edges_json = row["edges_json"]

    # Load all objectives (repository keeps them in a single table)
    cur.execute("SELECT * FROM learning_objective ORDER BY id")
    obj_rows = cur.fetchall()
    conn.close()

    objectives = [_row_to_learning_objective(r) for r in obj_rows]

    return ObjectiveGraph(
        id=graph_id,
        course_id=course_id,
        objectives=objectives,
        edges_json=edges_json,
    )


def update_objective_graph(graph: ObjectiveGraph) -> bool:
    """Update an existing objective graph. Returns ``True`` if a row was affected."""
    if graph.id is None:
        return False
    _ensure_graph_tables()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        UPDATE objective_graph SET
            course_id = ?,
            edges_json = ?
        WHERE id = ?
        """,
        (graph.course_id, graph.edges_json, graph.id),
    )
    conn.commit()
    affected = cur.rowcount > 0
    conn.close()
    return affected


def delete_objective_graph(graph_id: int) -> bool:
    """Delete an objective graph by ``id``. Returns ``True`` if a row was deleted."""
    _ensure_graph_tables()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("DELETE FROM objective_graph WHERE id = ?", (graph_id,))
    conn.commit()
    affected = cur.rowcount > 0
    conn.close()
    return affected


# ---------------------------------------------------------------------------
# StudentObjectiveState CRUD
# ---------------------------------------------------------------------------


def create_student_state(state: StudentObjectiveState) -> bool:
    """Insert a new student objective state. Returns ``True`` on success."""
    _ensure_graph_tables()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    try:
        cur.execute(
            """
            INSERT INTO student_objective_state
                (user_id, objective_id, status, mastery_score, last_attempted_at, mastered_at)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (
                state.user_id,
                state.objective_id,
                state.status,
                state.mastery_score,
                state.last_attempted_at,
                state.mastered_at,
            ),
        )
        conn.commit()
        return True
    except sqlite3.IntegrityError:
        return False
    finally:
        conn.close()


def get_student_state(user_id: str, objective_id: int) -> Optional[StudentObjectiveState]:
    """Fetch a single student objective state."""
    _ensure_graph_tables()
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    cur.execute(
        "SELECT * FROM student_objective_state WHERE user_id = ? AND objective_id = ?",
        (user_id, objective_id),
    )
    row = cur.fetchone()
    conn.close()
    if row is None:
        return None
    return _row_to_student_state(row)


def get_student_states(user_id: str, course_id: int) -> List[StudentObjectiveState]:
    """Fetch all student objective states for a user within a course.

    States are returned for every objective that appears in the graph for
    ``course_id``.
    """
    _ensure_graph_tables()
    graph = get_graph_by_course(course_id)
    if graph is None:
        return []

    objective_ids = [obj.id for obj in graph.objectives if obj.id is not None]
    if not objective_ids:
        return []

    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    placeholders = ",".join("?" * len(objective_ids))
    cur.execute(
        f"""
        SELECT * FROM student_objective_state
        WHERE user_id = ? AND objective_id IN ({placeholders})
        """,
        (user_id, *objective_ids),
    )
    rows = cur.fetchall()
    conn.close()
    return [_row_to_student_state(r) for r in rows]


def update_student_state(state: StudentObjectiveState) -> bool:
    """Upsert a student objective state. Returns ``True`` if a row was affected."""
    _ensure_graph_tables()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO student_objective_state
            (user_id, objective_id, status, mastery_score, last_attempted_at, mastered_at)
        VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(user_id, objective_id) DO UPDATE SET
            status = excluded.status,
            mastery_score = excluded.mastery_score,
            last_attempted_at = excluded.last_attempted_at,
            mastered_at = excluded.mastered_at
        """,
        (
            state.user_id,
            state.objective_id,
            state.status,
            state.mastery_score,
            state.last_attempted_at,
            state.mastered_at,
        ),
    )
    conn.commit()
    affected = cur.rowcount > 0
    conn.close()
    return affected


def delete_student_state(user_id: str, objective_id: int) -> bool:
    """Delete a student objective state. Returns ``True`` if a row was deleted."""
    _ensure_graph_tables()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        "DELETE FROM student_objective_state WHERE user_id = ? AND objective_id = ?",
        (user_id, objective_id),
    )
    conn.commit()
    affected = cur.rowcount > 0
    conn.close()
    return affected


# ---------------------------------------------------------------------------
# Row mappers
# ---------------------------------------------------------------------------


def _row_to_learning_objective(row: sqlite3.Row) -> LearningObjective:
    prereqs: List[int] = []
    prereqs_json = row["prerequisites_json"]
    if prereqs_json:
        try:
            prereqs = json.loads(prereqs_json)
        except json.JSONDecodeError:
            prereqs = []
    return LearningObjective(
        id=row["id"],
        code=row["code"],
        title=row["title"],
        description=row["description"],
        parent_id=row["parent_id"],
        level=row["level"],
        topic=row["topic"],
        prerequisites=prereqs,
        estimated_minutes=row["estimated_minutes"],
    )


def _row_to_student_state(row: sqlite3.Row) -> StudentObjectiveState:
    return StudentObjectiveState(
        user_id=row["user_id"],
        objective_id=row["objective_id"],
        status=row["status"],
        mastery_score=row["mastery_score"],
        last_attempted_at=row["last_attempted_at"],
        mastered_at=row["mastered_at"],
    )
