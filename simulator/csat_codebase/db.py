from __future__ import annotations

import json
import sqlite3
from pathlib import Path
from typing import Any, Dict, List, Optional


DB_PATH = Path(__file__).resolve().parents[1] / "csat_codebases.db"


def get_db_connection() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    with get_db_connection() as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS codebases (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              prompt TEXT NOT NULL,
              code TEXT NOT NULL,
              mode TEXT,
              tags TEXT,
              difficulty INTEGER,
              tier INTEGER,
              solves_count INTEGER,
              strategy_level INTEGER,
              branch_conditions INTEGER,
              created_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
            """
        )
        conn.commit()


def load_codebases() -> List[Dict[str, Any]]:
    init_db()
    with get_db_connection() as conn:
        rows = conn.execute(
            """
            SELECT id, name, prompt, code, mode, tags, difficulty, tier,
                   solves_count, strategy_level, branch_conditions, created_at
            FROM codebases
            ORDER BY id ASC
            """
        ).fetchall()
    results: List[Dict[str, Any]] = []
    for row in rows:
        tags_raw = row["tags"] or ""
        try:
            tags = json.loads(tags_raw) if tags_raw else []
        except Exception:
            tags = []
        results.append(
            {
                "id": row["id"],
                "name": row["name"],
                "prompt": row["prompt"],
                "code": row["code"],
                "mode": row["mode"],
                "tags": tags,
                "difficulty": row["difficulty"],
                "tier": row["tier"],
                "solves_count": row["solves_count"],
                "strategy_level": row["strategy_level"],
                "branch_conditions": row["branch_conditions"],
                "created_at": row["created_at"],
                "module": None,
            }
        )
    return results


def save_codebase(entry: Dict[str, Any]) -> Dict[str, Any]:
    init_db()
    with get_db_connection() as conn:
        cursor = conn.execute(
            """
            INSERT INTO codebases (
              name, prompt, code, mode, tags, difficulty, tier,
              solves_count, strategy_level, branch_conditions
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                entry.get("name") or "",
                entry.get("prompt") or "",
                entry.get("code") or "",
                entry.get("mode"),
                json.dumps(entry.get("tags") or [], ensure_ascii=False),
                entry.get("difficulty"),
                entry.get("tier"),
                entry.get("solves_count"),
                entry.get("strategy_level"),
                entry.get("branch_conditions"),
            ),
        )
        new_id = cursor.lastrowid
        name = entry.get("name") or f"CB-{new_id:03d}"
        conn.execute("UPDATE codebases SET name = ? WHERE id = ?", (name, new_id))
        conn.commit()
    entry["id"] = new_id
    entry["name"] = name
    return entry


def update_codebase(entry_id: int, code: str, prompt: Optional[str] = None) -> None:
    init_db()
    with get_db_connection() as conn:
        if prompt is None:
            conn.execute("UPDATE codebases SET code = ? WHERE id = ?", (code, entry_id))
        else:
            conn.execute(
                "UPDATE codebases SET code = ?, prompt = ? WHERE id = ?",
                (code, prompt, entry_id),
            )
        conn.commit()
