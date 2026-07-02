"""Idempotent migration runner.

Scans the migrations package for v*.py modules, tracks applied versions in the
_migrations table, and runs any that are missing.
"""

import importlib.util
import re
import sqlite3
from pathlib import Path
from typing import List

from infra.db.connection import get_db

MIGRATIONS_DIR = Path(__file__).parent


def _extract_sort_key(filename: str):
    """Sort key: numeric prefix after 'v', falling back to lexicographic."""
    m = re.match(r"v(\d+)", filename)
    return (int(m.group(1)), filename) if m else (0, filename)


def _list_migration_modules() -> List[Path]:
    """Return sorted list of v*.py migration files."""
    modules: List[Path] = []
    for f in MIGRATIONS_DIR.iterdir():
        if f.is_file() and f.suffix == ".py" and f.name.startswith("v"):
            modules.append(f)
    modules.sort(key=lambda p: _extract_sort_key(p.name))
    return modules


def _applied_versions(conn: sqlite3.Connection) -> set:
    """Return set of already-applied migration versions."""
    cur = conn.execute("SELECT version FROM _migrations")
    return {row[0] for row in cur.fetchall()}


def run(db_path: str = "omj/quests.db") -> None:
    """Run all pending migrations idempotently."""
    conn = get_db(db_path)
    try:
        applied = _applied_versions(conn)
        for mod_path in _list_migration_modules():
            version = mod_path.stem
            if version in applied:
                continue

            spec = importlib.util.spec_from_file_location(version, mod_path)
            if spec is None or spec.loader is None:
                raise ImportError(f"Cannot load migration {mod_path}")

            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)

            apply_fn = getattr(module, "apply", None)
            if apply_fn is None:
                raise AttributeError(
                    f"Migration {mod_path} missing required 'apply' function"
                )

            apply_fn(conn)

            conn.execute(
                "INSERT INTO _migrations (version) VALUES (?)",
                (version,),
            )
            conn.commit()
    finally:
        conn.close()
