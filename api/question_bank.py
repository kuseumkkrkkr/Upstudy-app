"""Read-only access to the versioned, content-only Vercel question snapshot."""
from __future__ import annotations

import hashlib
import json
import sqlite3
import copy
from functools import lru_cache
from pathlib import Path
from typing import Any


_DATABASE = Path(__file__).resolve().parents[1] / "data" / "content" / "question-bank-v1.sqlite"
_EXPECTED_SHA256 = "a0ff8d47a4207802a25fb17b2534b8e65ead0c8d5f352e81de35bb7dc2ebd009"
_EXPECTED_QUESTION_COUNT = 3111


def _json(value: Any, fallback: Any) -> Any:
    if value is None or value == "":
        return fallback
    try:
        return json.loads(value) if isinstance(value, str) else value
    except (TypeError, ValueError):
        return fallback


def _content(value: Any) -> dict[str, Any] | None:
    if value is None:
        return None
    parsed = _json(value, value)
    if isinstance(parsed, dict) and "blocks" in parsed:
        return parsed
    if isinstance(parsed, dict) and "type" in parsed and "content" in parsed:
        return {"blocks": [parsed]}
    if isinstance(parsed, list):
        return {"blocks": parsed}
    if isinstance(parsed, dict):
        return {"blocks": [{"type": "text", "content": json.dumps(parsed, ensure_ascii=False)}]}
    return {"blocks": [{"type": "text", "content": str(parsed)}]}


def _options(value: Any) -> list[dict[str, Any]] | None:
    if value is None:
        return None
    parsed = _json(value, None)
    if parsed is None:
        parsed = [value]
    elif not isinstance(parsed, list):
        parsed = [parsed]
    result = [_content(item) for item in parsed]
    return [item for item in result if item is not None]


def _nested_steps(value: Any) -> list[dict[str, Any]]:
    parsed = _json(value, [])
    if not isinstance(parsed, list):
        return []
    result = []
    for raw in parsed:
        if not isinstance(raw, dict):
            continue
        step = dict(raw)
        for name in ("flow", "hint_riddle", "answer_riddle"):
            step[name] = _content(step.get(name))
        step["branches"] = _nested_steps(step.get("branches"))
        result.append(step)
    return result


@lru_cache(maxsize=1)
def _database_uri() -> str:
    if not _DATABASE.is_file():
        raise RuntimeError("Vercel question-bank snapshot is missing")
    digest = hashlib.sha256(_DATABASE.read_bytes()).hexdigest()
    if digest != _EXPECTED_SHA256:
        raise RuntimeError("Vercel question-bank snapshot checksum mismatch")
    uri = _DATABASE.as_uri() + "?mode=ro&immutable=1"
    with sqlite3.connect(uri, uri=True) as connection:
        count = int(connection.execute("SELECT COUNT(*) FROM quest_header").fetchone()[0])
    if count != _EXPECTED_QUESTION_COUNT:
        raise RuntimeError("Vercel question-bank snapshot row count mismatch")
    return uri


def get_question(quest_id: str) -> dict[str, Any] | None:
    """Return canonical shared question content by ID; never exposes runtime tables."""
    normalized_id = quest_id.strip()
    if not normalized_id or len(normalized_id) > 200:
        return None
    with sqlite3.connect(_database_uri(), uri=True) as connection:
        connection.row_factory = sqlite3.Row
        rows = connection.execute(
            """SELECT h.quest_id, h.quest_model,
                      i.main, i.sub, i.hash_tag AS info_hash_tag, i.flow_rate,
                      i.difficulty, i.main_huddle, i.difficulty_tier,
                      i.difficulty_score, i.tier_source, i.quality_status,
                      i.quality_reasons,
                      d.quest_title, d.quest_image, d.quest_answer,
                      d.question_type, d.quest_options, d.codebase_id, d.seed,
                      d.hash_tag AS data_hash_tag, d.choice_answer_index, d.meta_json
               FROM quest_header h
               LEFT JOIN quest_info i USING (quest_id)
               LEFT JOIN quest_data d USING (quest_id)
               WHERE h.quest_id = ? LIMIT 1""",
            (normalized_id,),
        ).fetchone()
        if rows is None:
            return None
        solve_rows = connection.execute(
            """SELECT flow, hash_tag, hint_riddle, answer_riddle, enter_huddle, branches
               FROM solve_step WHERE quest_id = ? ORDER BY id""",
            (normalized_id,),
        ).fetchall()

    meta = _json(rows["meta_json"], {})
    meta = meta if isinstance(meta, dict) else {}
    data: dict[str, Any] = {
        "quest_title": _content(rows["quest_title"]),
        "quest_image": rows["quest_image"],
        "quest_answer": _content(rows["quest_answer"]),
        "question_type": rows["question_type"],
        "quest_options": _options(rows["quest_options"]),
        "codebase_id": rows["codebase_id"],
        "seed": rows["seed"],
        "hash_tag": _json(rows["data_hash_tag"], []),
        "choice_answer_index": rows["choice_answer_index"],
        "meta": meta,
    }
    conversion = meta.get("mcq_conversion")
    if isinstance(conversion, dict):
        data["mcq_conversion"] = conversion
    elif "answer_index" in meta:
        data["mcq_conversion"] = meta

    return {
        "header": {
            "quest_id": rows["quest_id"],
            "quest_model": {"models": _json(rows["quest_model"], [])},
        },
        "info": {
            "main": rows["main"],
            "sub": _json(rows["sub"], []),
            "hash_tag": _json(rows["info_hash_tag"], []),
            "flow_rate": rows["flow_rate"],
            "difficulty": rows["difficulty"],
            "main_huddle": rows["main_huddle"],
            "difficulty_tier": rows["difficulty_tier"],
            "difficulty_score": rows["difficulty_score"] if rows["difficulty_score"] is not None else rows["difficulty"],
            "tier_source": rows["tier_source"],
            "quality_status": rows["quality_status"],
            "quality_reasons": _json(rows["quality_reasons"], []),
        },
        "data": data,
        "solves": [
            {
                "flow": _content(row["flow"]),
                "hash_tag": _json(row["hash_tag"], []),
                "hint_riddle": _content(row["hint_riddle"]),
                "answer_riddle": _content(row["answer_riddle"]),
                "enter_huddle": row["enter_huddle"],
                "branches": _nested_steps(row["branches"]),
            }
            for row in solve_rows
        ],
    }


@lru_cache(maxsize=512)
def _cached_question_by_codebase_seed(codebase_id: int, seed: int) -> dict[str, Any] | None:
    """Resolve a legacy replay key only when it identifies one canonical question."""
    if isinstance(codebase_id, bool) or not isinstance(codebase_id, int):
        return None
    if isinstance(seed, bool) or not isinstance(seed, int):
        return None
    with sqlite3.connect(_database_uri(), uri=True) as connection:
        rows = connection.execute(
            """SELECT quest_id FROM quest_data
               WHERE codebase_id = ? AND seed = ? LIMIT 2""",
            (codebase_id, seed),
        ).fetchall()
    if len(rows) != 1:
        return None
    return get_question(str(rows[0][0]))


def get_question_by_codebase_seed(codebase_id: int, seed: int) -> dict[str, Any] | None:
    """Resolve a legacy replay key without exposing a mutable shared cache value."""
    if isinstance(codebase_id, bool) or not isinstance(codebase_id, int):
        return None
    if isinstance(seed, bool) or not isinstance(seed, int):
        return None
    cached = _cached_question_by_codebase_seed(codebase_id, seed)
    return copy.deepcopy(cached) if cached is not None else None
