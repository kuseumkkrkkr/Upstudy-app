"""Contracts for the content-only canonical question snapshot bundled by Vercel."""
from __future__ import annotations

import sqlite3
import json
from pathlib import Path

from api import index
from api.question_bank import _DATABASE, get_question, get_question_by_codebase_seed


QUESTION_ID = "001/260715/151557852092"


def test_snapshot_contains_only_shared_question_tables_and_expected_rows():
    with sqlite3.connect(f"file:{_DATABASE.as_posix()}?mode=ro", uri=True) as connection:
        tables = {
            row[0]
            for row in connection.execute(
                "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
            )
        }
        assert tables == {"quest_header", "quest_info", "quest_data", "solve_step"}
        assert connection.execute("SELECT COUNT(*) FROM quest_header").fetchone()[0] == 3111
        assert connection.execute("SELECT COUNT(*) FROM solve_step").fetchone()[0] == 12392


def test_snapshot_is_included_in_vercel_function_bundle():
    root = Path(__file__).resolve().parents[1]
    config = json.loads((root / "vercel.json").read_text(encoding="utf-8"))
    assert config["functions"]["api/index.py"]["includeFiles"] == "data/content/**"
    ignore_rules = (root / ".vercelignore").read_text(encoding="utf-8").splitlines()
    assert "data/content/leveltest-expanded-v1/" in ignore_rules
    assert "data/content/" not in ignore_rules


def test_canonical_question_load_preserves_the_server_question_shape():
    question = get_question(QUESTION_ID)
    assert question is not None
    assert question["header"]["quest_id"] == QUESTION_ID
    assert isinstance(question["header"]["quest_model"]["models"], list)
    assert isinstance(question["info"]["hash_tag"], list)
    assert isinstance(question["data"]["quest_title"]["blocks"], list)
    assert question["solves"]
    assert all("answer_riddle" in step and "branches" in step for step in question["solves"])
    assert get_question("not-a-canonical-question") is None


def test_legacy_replay_pair_lookup_returns_unique_copy_not_shared_mutable_cache():
    first = get_question_by_codebase_seed(-20261020510, 202607599510)
    assert first is not None
    assert first["header"]["quest_id"] == "curated/marketplace-original-v59/t5-10"
    first["header"]["quest_id"] = "modified"
    second = get_question_by_codebase_seed(-20261020510, 202607599510)
    assert second is not None
    assert second["header"]["quest_id"] == "curated/marketplace-original-v59/t5-10"
    assert get_question_by_codebase_seed(1, 1) is None


def test_vercel_question_lookup_falls_back_to_canonical_snapshot(monkeypatch):
    monkeypatch.setattr(index, "_find_marketplace_question", lambda _quest_id: None)
    question = index._find_vercel_question(QUESTION_ID)
    assert question is not None
    assert question["header"]["quest_id"] == QUESTION_ID


def test_quests_endpoint_returns_canonical_snapshot_question():
    response = index.list_quests(quest_id=QUESTION_ID, _user_id="student-fixture")
    assert response["total"] == 1
    assert response["quests"][0]["header"]["quest_id"] == QUESTION_ID
