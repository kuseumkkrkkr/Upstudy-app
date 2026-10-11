"""The approved SQLite question content must be present in its SQL seed."""
import json
import re
import sqlite3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
QUESTION_DB = ROOT / "data/content/leveltest-expanded-v1/leveltest_final_expanded.db"
SEED_SQL = ROOT / "omj/migrations/postgres/009_level_test_question_bank.sql"


def test_approved_level_test_questions_are_intact_and_seeded():
    with sqlite3.connect(f"file:{QUESTION_DB.as_posix()}?mode=ro", uri=True) as db:
        assert db.execute("PRAGMA integrity_check").fetchone() == ("ok",)
        rows = db.execute(
            "SELECT quest_title, quest_answer, solves_json FROM question"
        ).fetchall()

    seed = SEED_SQL.read_text(encoding="utf-8")
    assert len(rows) == 776
    seed_rows = re.findall(
        r"^\('([^']+)', 'expanded-v1', (\d+),",
        seed,
        flags=re.MULTILINE,
    )
    assert len(seed_rows) == len(rows)
    assert len({question_id for question_id, _ in seed_rows}) == len(rows)
    assert [int(index) for _, index in seed_rows] == list(range(1, len(rows) + 1))
    for title, answer, solves_json in rows:
        assert title.strip() and answer.strip()
        assert isinstance(json.loads(solves_json), list)
        assert "'" + title.replace("'", "''") + "'" in seed
        assert "'" + answer.replace("'", "''") + "'" in seed
        assert "'" + solves_json.replace("'", "''") + "'::jsonb" in seed
