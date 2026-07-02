"""SQLite-backed repository for textbook blocks and graphs.

Provides:
- _ensure_textbook_tables: creates textbook_block and textbook_graph tables
- create_block, get_block, get_blocks_by_parent, list_blocks
- create_graph, get_graph, update_graph
"""
import json
import os
import sqlite3
from typing import Optional

from domain.textbook.models import TextbookBlock, TextbookGraph


DEFAULT_DB_PATH = os.getenv("TEXTBOOK_DB_PATH", "textbook.db")


def _ensure_textbook_tables(db_path: str = DEFAULT_DB_PATH) -> None:
    """Create textbook_block and textbook_graph tables if they do not exist."""
    with sqlite3.connect(db_path) as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS textbook_block (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                type TEXT NOT NULL CHECK(type IN ('chapter','section','subsection','problem')),
                title TEXT NOT NULL,
                content TEXT,
                level INTEGER NOT NULL DEFAULT 1,
                learning_objective_id INTEGER,
                parent_id INTEGER,
                course_id INTEGER NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS textbook_graph (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                course_id INTEGER NOT NULL UNIQUE,
                root_blocks TEXT NOT NULL DEFAULT '[]',
                created_at TEXT NOT NULL DEFAULT (datetime('now'))
            )
            """
        )
        conn.commit()


def create_block(block: TextbookBlock, db_path: str = DEFAULT_DB_PATH) -> int:
    """Insert a new block and return its generated id."""
    _ensure_textbook_tables(db_path)
    with sqlite3.connect(db_path) as conn:
        cur = conn.execute(
            """
            INSERT INTO textbook_block (type, title, content, level, learning_objective_id, parent_id, course_id)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (
                block.type,
                block.title,
                block.content,
                block.level,
                block.learning_objective_id,
                block.parent_id,
                block.course_id or 0,
            ),
        )
        conn.commit()
        return cur.lastrowid


def get_block(block_id: int, db_path: str = DEFAULT_DB_PATH) -> Optional[TextbookBlock]:
    """Fetch a single block by id."""
    _ensure_textbook_tables(db_path)
    with sqlite3.connect(db_path) as conn:
        conn.row_factory = sqlite3.Row
        row = conn.execute(
            "SELECT * FROM textbook_block WHERE id = ?", (block_id,)
        ).fetchone()
        if row is None:
            return None
        return TextbookBlock.model_validate(dict(row))


def get_blocks_by_parent(parent_id: int, db_path: str = DEFAULT_DB_PATH) -> list[TextbookBlock]:
    """Fetch all blocks that have the given parent_id."""
    _ensure_textbook_tables(db_path)
    with sqlite3.connect(db_path) as conn:
        conn.row_factory = sqlite3.Row
        rows = conn.execute(
            "SELECT * FROM textbook_block WHERE parent_id = ? ORDER BY id", (parent_id,)
        ).fetchall()
        return [TextbookBlock.model_validate(dict(r)) for r in rows]


def list_blocks(course_id: int, db_path: str = DEFAULT_DB_PATH) -> list[TextbookBlock]:
    """List all blocks belonging to a course."""
    _ensure_textbook_tables(db_path)
    with sqlite3.connect(db_path) as conn:
        conn.row_factory = sqlite3.Row
        rows = conn.execute(
            "SELECT * FROM textbook_block WHERE course_id = ? ORDER BY id", (course_id,)
        ).fetchall()
        return [TextbookBlock.model_validate(dict(r)) for r in rows]


def create_graph(graph: TextbookGraph, db_path: str = DEFAULT_DB_PATH) -> int:
    """Insert a new graph and return its generated id."""
    _ensure_textbook_tables(db_path)
    with sqlite3.connect(db_path) as conn:
        cur = conn.execute(
            """
            INSERT INTO textbook_graph (course_id, root_blocks, created_at)
            VALUES (?, ?, ?)
            """,
            (graph.course_id, json.dumps(graph.root_blocks), graph.created_at),
        )
        conn.commit()
        return cur.lastrowid


def get_graph(course_id: int, db_path: str = DEFAULT_DB_PATH) -> Optional[TextbookGraph]:
    """Fetch the graph for a specific course_id."""
    _ensure_textbook_tables(db_path)
    with sqlite3.connect(db_path) as conn:
        conn.row_factory = sqlite3.Row
        row = conn.execute(
            "SELECT * FROM textbook_graph WHERE course_id = ?", (course_id,)
        ).fetchone()
        if row is None:
            return None
        data = dict(row)
        data["root_blocks"] = json.loads(data.get("root_blocks", "[]"))
        return TextbookGraph.model_validate(data)


def update_graph(graph_id: int, root_blocks: list[int], db_path: str = DEFAULT_DB_PATH) -> bool:
    """Update root_blocks for an existing graph. Returns True if a row was updated."""
    _ensure_textbook_tables(db_path)
    with sqlite3.connect(db_path) as conn:
        cur = conn.execute(
            "UPDATE textbook_graph SET root_blocks = ? WHERE id = ?",
            (json.dumps(root_blocks), graph_id),
        )
        conn.commit()
        return cur.rowcount > 0
