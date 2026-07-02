"""Migrations package."""

from migrations.runner import run


def apply_all(db_path: str = "omj/quests.db") -> None:
    """Convenience entry-point to run all pending migrations."""
    run(db_path)
