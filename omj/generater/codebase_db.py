"""
Lightweight SQLite storage for generated codebases and their seeds.

- DB file: codebase.db (next to this module's parent directory)
- Tables:
    codebase(id, name, prompt, code, tags, difficulty, solves_count,
             strategy_level, branch_conditions, created_at)
    seed(id, codebase_id, seed, status, error_message, created_at)
"""

from __future__ import annotations

import json
import sqlite3
from pathlib import Path
from typing import Any, Dict, List, Optional


# ------------------------------------------------------------
# DB helpers
# ------------------------------------------------------------

def _db_path() -> Path:
    return Path(__file__).resolve().parents[1] / "codebase.db"


def _connect() -> sqlite3.Connection:
    conn = sqlite3.connect(_db_path())
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    """Create tables if they do not exist."""
    with _connect() as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS codebase (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              prompt TEXT,
              code TEXT NOT NULL,
              tags TEXT,
              difficulty INTEGER,
              solves_count INTEGER,
              strategy_level INTEGER,
              branch_conditions INTEGER,
              created_at TEXT DEFAULT CURRENT_TIMESTAMP
            );
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS seed (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              codebase_id INTEGER NOT NULL,
              seed INTEGER NOT NULL,
              status TEXT,
              error_message TEXT,
              created_at TEXT DEFAULT CURRENT_TIMESTAMP,
              UNIQUE(codebase_id, seed),
              FOREIGN KEY(codebase_id) REFERENCES codebase(id) ON DELETE CASCADE
            );
            """
        )
        conn.commit()


# ------------------------------------------------------------
# Codebase CRUD
# ------------------------------------------------------------

def save_codebase(entry: Dict[str, Any]) -> Dict[str, Any]:
    """
    Insert a codebase row.
    Required keys: code (str)
    Optional: name, prompt, tags(list[str] or str), difficulty, solves_count,
              strategy_level, branch_conditions
    """
    init_db()
    tags_raw = entry.get("tags")
    if isinstance(tags_raw, list):
        tags_raw = json.dumps(tags_raw, ensure_ascii=False)
    with _connect() as conn:
        cursor = conn.execute(
            """
            INSERT INTO codebase (
              name, prompt, code, tags, difficulty,
              solves_count, strategy_level, branch_conditions
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                entry.get("name") or "",
                entry.get("prompt") or "",
                entry.get("code") or "",
                tags_raw or "",
                entry.get("difficulty"),
                entry.get("solves_count"),
                entry.get("strategy_level"),
                entry.get("branch_conditions"),
            ),
        )
        new_id = cursor.lastrowid
        conn.commit()
    entry["id"] = new_id
    return entry


def list_codebases() -> List[Dict[str, Any]]:
    init_db()
    with _connect() as conn:
        rows = conn.execute(
            """
            SELECT id, name, prompt, code, tags, difficulty,
                   solves_count, strategy_level, branch_conditions, created_at
            FROM codebase
            ORDER BY id DESC
            """
        ).fetchall()
    results: List[Dict[str, Any]] = []
    for row in rows:
        tags = row["tags"]
        try:
            tags = json.loads(tags) if tags else []
        except Exception:
            tags = [tags] if tags else []
        results.append(
            {
                "id": row["id"],
                "name": row["name"],
                "prompt": row["prompt"],
                "code": row["code"],
                "tags": tags,
                "difficulty": row["difficulty"],
                "solves_count": row["solves_count"],
                "strategy_level": row["strategy_level"],
                "branch_conditions": row["branch_conditions"],
                "created_at": row["created_at"],
            }
        )
    return results


# ------------------------------------------------------------
# Seed CRUD
# ------------------------------------------------------------

def save_seed(
    codebase_id: int,
    seed: int,
    *,
    status: str = "success",
    error_message: Optional[str] = None,
) -> None:
    init_db()
    with _connect() as conn:
        conn.execute(
            """
            INSERT OR REPLACE INTO seed (codebase_id, seed, status, error_message)
            VALUES (?, ?, ?, ?)
            """,
            (codebase_id, int(seed), status, error_message),
        )
        conn.commit()


def list_seeds(codebase_id: Optional[int] = None) -> List[Dict[str, Any]]:
    init_db()
    sql = "SELECT id, codebase_id, seed, status, error_message, created_at FROM seed"
    params: list[Any] = []
    if codebase_id is not None:
        sql += " WHERE codebase_id = ?"
        params.append(int(codebase_id))
    sql += " ORDER BY id DESC"
    with _connect() as conn:
        rows = conn.execute(sql, params).fetchall()
    return [
        {
            "id": row["id"],
            "codebase_id": row["codebase_id"],
            "seed": row["seed"],
            "status": row["status"],
            "error_message": row["error_message"],
            "created_at": row["created_at"],
        }
        for row in rows
    ]


__all__ = [
    "init_db",
    "save_codebase",
    "list_codebases",
    "save_seed",
    "list_seeds",
]
