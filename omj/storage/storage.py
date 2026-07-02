import json
import sqlite3
from pathlib import Path
from typing import Any, Dict, List, Optional
from typing import Iterable

from domain.quest.search_view import normalize_hash_tags

# =========================
# Database config
# =========================

DB_PATH = str((Path(__file__).resolve().parent.parent / "quests.db"))
# Keep the last store_data error so API handlers can return detail
_LAST_STORE_ERROR: Optional[str] = None


def _normalize_content(value: Any) -> dict | None:
    if value is None:
        return None
    if isinstance(value, dict):
        if "blocks" in value:
            return value
        if "type" in value and "content" in value:
            return {"blocks": [value]}
        return {"blocks": [{"type": "text", "content": json.dumps(value, ensure_ascii=False)}]}
    if isinstance(value, list):
        return {"blocks": value}
    return {"blocks": [{"type": "text", "content": str(value)}]}


def _serialize_content(value: Any) -> str | None:
    normalized = _normalize_content(value)
    if normalized is None:
        return None
    return json.dumps(normalized, ensure_ascii=False)


def _parse_content(value: Any) -> dict | None:
    if value is None:
        return None
    if isinstance(value, (dict, list)):
        return _normalize_content(value)
    if isinstance(value, str):
        if not value:
            return {"blocks": []}
        try:
            parsed = json.loads(value)
        except json.JSONDecodeError:
            return _normalize_content(value)
        return _normalize_content(parsed)
    return _normalize_content(value)


def _serialize_options(value: Any) -> str | None:
    if value is None:
        return None
    if isinstance(value, str):
        return json.dumps([_normalize_content(value)], ensure_ascii=False)
    if isinstance(value, list):
        normalized = [_normalize_content(item) for item in value]
        return json.dumps(normalized, ensure_ascii=False)
    return json.dumps([_normalize_content(value)], ensure_ascii=False)


def _parse_options(value: Any) -> list | None:
    if value is None:
        return None
    if isinstance(value, str):
        if not value:
            return []
        try:
            parsed = json.loads(value)
        except json.JSONDecodeError:
            return [_normalize_content(value)]
        if isinstance(parsed, list):
            return [_normalize_content(item) for item in parsed]
        return [_normalize_content(parsed)]
    if isinstance(value, list):
        return [_normalize_content(item) for item in value]
    return [_normalize_content(value)]


def _normalize_nested_steps(value: Any) -> List[Dict[str, Any]]:
    if value is None:
        return []
    if isinstance(value, str):
        try:
            value = json.loads(value)
        except json.JSONDecodeError:
            return []
    if not isinstance(value, list):
        return []
    normalized: List[Dict[str, Any]] = []
    for step in value:
        if not isinstance(step, dict):
            continue
        normalized.append(_normalize_nested_step(step))
    return normalized


def _normalize_nested_step(step: Dict[str, Any]) -> Dict[str, Any]:
    normalized = dict(step)
    normalized["flow"] = _parse_content(step.get("flow"))
    normalized["hint_riddle"] = _parse_content(step.get("hint_riddle"))
    normalized["answer_riddle"] = _parse_content(step.get("answer_riddle"))
    normalized["branches"] = _normalize_nested_steps(step.get("branches"))
    return normalized


def _ensure_column(cursor: sqlite3.Cursor, table: str, column: str, definition: str) -> None:
    cursor.execute(f"PRAGMA table_info({table})")
    existing = {row[1] for row in cursor.fetchall()}
    if column not in existing:
        cursor.execute(f"ALTER TABLE {table} ADD COLUMN {column} {definition}")


def init_db():
    """Initialize SQLite tables if they do not exist."""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # quest_header table
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS quest_header (
            quest_id TEXT PRIMARY KEY,
            quest_model TEXT NOT NULL
        )
        """
    )

    # quest_info table
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS quest_info (
            quest_id TEXT PRIMARY KEY,
            main INTEGER NOT NULL,
            sub TEXT NOT NULL,
            hash_tag TEXT NOT NULL,
            flow_rate INTEGER NOT NULL,
            difficulty INTEGER NOT NULL,
            main_huddle INTEGER NOT NULL,
            FOREIGN KEY (quest_id) REFERENCES quest_header(quest_id)
        )
        """
    )

    # quest_data table
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS quest_data (
            quest_id TEXT PRIMARY KEY,
            quest_title TEXT NOT NULL,
            quest_image TEXT,
            quest_answer TEXT,
            codebase_id INTEGER,
            FOREIGN KEY (quest_id) REFERENCES quest_header(quest_id)
        )
        """
    )

    # solve_step table
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS solve_step (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            quest_id TEXT NOT NULL,
            flow TEXT NOT NULL,
            hash_tag TEXT NOT NULL,
            hint_riddle TEXT NOT NULL,
            answer_riddle TEXT NOT NULL,
            enter_huddle INTEGER NOT NULL,
            branches TEXT NOT NULL DEFAULT '[]',
            FOREIGN KEY (quest_id) REFERENCES quest_header(quest_id)
        )
        """
    )

    # Ensure columns exist for legacy DBs
    _ensure_column(cursor, "solve_step", "branches", "TEXT NOT NULL DEFAULT '[]'")
    _ensure_column(cursor, "quest_data", "quest_answer", "TEXT")
    _ensure_column(cursor, "quest_data", "question_type", "TEXT")
    _ensure_column(cursor, "quest_data", "quest_options", "TEXT")
    _ensure_column(cursor, "quest_data", "codebase_id", "INTEGER")
    _ensure_column(cursor, "quest_data", "seed", "INTEGER")
    _ensure_column(cursor, "quest_data", "hash_tag", "TEXT")

    conn.commit()
    conn.close()


def store_data(storage_data: Dict[str, Any]) -> bool:
    """
    Persist normalized quest data to SQLite.

    Args:
        storage_data: Data from fix_gen() with keys header/info/data/solves.
    """
    global _LAST_STORE_ERROR
    _LAST_STORE_ERROR = None
    try:
        init_db()
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()

        header = storage_data["header"]
        info = storage_data["info"]
        data = storage_data["data"]
        solves = storage_data["solves"]

        quest_id = header["quest_id"]

        # 1. quest_header insert
        quest_model_data = header["quest_model"]
        if isinstance(quest_model_data, dict):
            models = quest_model_data.get("models", [])
        else:
            models = quest_model_data

        cursor.execute(
            """
            INSERT INTO quest_header (quest_id, quest_model)
            VALUES (?, ?)
            """,
            (quest_id, json.dumps(models)),
        )

        # 2. quest_info insert
        cursor.execute(
            """
            INSERT INTO quest_info 
            (quest_id, main, sub, hash_tag, flow_rate, difficulty, main_huddle)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (
                quest_id,
                info["main"],
                json.dumps(info.get("sub", [])),
                json.dumps(info["hash_tag"]),
                info["flow_rate"],
                info["difficulty"],
                info["main_huddle"],
            ),
        )

        # 3. quest_data insert
        cursor.execute(
            """
            INSERT INTO quest_data (
                quest_id,
                quest_title,
                quest_image,
                quest_answer,
                question_type,
                quest_options,
                codebase_id,
                seed,
                hash_tag
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                quest_id,
                _serialize_content(data["quest_title"]),
                data.get("quest_image"),
                _serialize_content(data.get("quest_answer")),
                data.get("question_type"),
                _serialize_options(data.get("quest_options")),
                data.get("codebase_id"),
                data.get("seed"),
                json.dumps(info.get("hash_tag", []), ensure_ascii=False),
            ),
        )

        # 4. solve_step insert
        for solve in solves:
            cursor.execute(
                """
                INSERT INTO solve_step 
                (quest_id, flow, hash_tag, hint_riddle, answer_riddle, enter_huddle, branches)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    quest_id,
                    _serialize_content(solve["flow"]),
                    json.dumps(solve.get("hash_tag", [])),
                    _serialize_content(solve["hint_riddle"]),
                    _serialize_content(solve["answer_riddle"]),
                    solve["enter_huddle"],
                    json.dumps(solve.get("branches", [])),
                ),
            )

        conn.commit()
        conn.close()

        print(f"데이터베이스 저장 완료 (Quest ID: {quest_id})")
        return True

    except sqlite3.IntegrityError as e:
        _LAST_STORE_ERROR = f"무결성 오류: {e}"
        print(_LAST_STORE_ERROR)
        return False
    except Exception as e:
        _LAST_STORE_ERROR = f"저장 오류: {e}"
        print(_LAST_STORE_ERROR)
        import traceback

        traceback.print_exc()
        return False


def get_last_store_error() -> Optional[str]:
    """Return the last error message set by store_data (if any)."""
    return _LAST_STORE_ERROR


def get_quest(quest_id: str) -> Dict[str, Any] | None:
    """
    Retrieve a quest by id from the database.
    """
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()

        cursor.execute("SELECT * FROM quest_header WHERE quest_id = ?", (quest_id,))
        header = cursor.fetchone()

        if not header:
            print(f"해당 문제가 없습니다: {quest_id}")
            return None

        cursor.execute("SELECT * FROM quest_info WHERE quest_id = ?", (quest_id,))
        info_row = cursor.fetchone()

        cursor.execute(
            """
            SELECT quest_id, quest_title, quest_image, quest_answer, question_type, quest_options, codebase_id, seed, hash_tag
            FROM quest_data
            WHERE quest_id = ?
            """,
            (quest_id,),
        )
        data_row = cursor.fetchone()

        cursor.execute("SELECT * FROM solve_step WHERE quest_id = ?", (quest_id,))
        solves_rows = cursor.fetchall()

        conn.close()

        result = {
            "header": {
                "quest_id": header[0],
                "quest_model": {
                    "models": json.loads(header[1])
                },
            },
            "info": {
                "main": info_row[1],
                "sub": json.loads(info_row[2]),
                "hash_tag": json.loads(info_row[3]),
                "flow_rate": info_row[4],
                "difficulty": info_row[5],
                "main_huddle": info_row[6],
            },
            "data": {
                "quest_title": _parse_content(data_row[1]) if data_row else None,
                "quest_image": data_row[2] if data_row else None,
                "quest_answer": _parse_content(data_row[3]) if data_row else None,
                "question_type": data_row[4] if data_row else None,
                "quest_options": _parse_options(data_row[5]) if data_row else None,
                "codebase_id": data_row[6] if data_row and len(data_row) > 6 else None,
                "seed": data_row[7] if data_row and len(data_row) > 7 else None,
                "hash_tag": json.loads(data_row[8]) if data_row and len(data_row) > 8 and data_row[8] else [],
            },
            "solves": [
                {
                    "flow": _parse_content(row[2]),
                    "hash_tag": json.loads(row[3]),
                    "hint_riddle": _parse_content(row[4]),
                    "answer_riddle": _parse_content(row[5]),
                    "enter_huddle": row[6],
                    "branches": _normalize_nested_steps(row[7]) if len(row) > 7 else [],
                }
                for row in solves_rows
            ],
        }

        return result

    except Exception as e:
        print(f"조회 오류: {e}")
        return None


def search_quests(
    *,
    hash_tag: Optional[str] = None,
    quest_id: Optional[str] = None,
    text_query: Optional[str] = None,
    page: int = 1,
    page_size: int = 50,
) -> Dict[str, Any]:
    normalized_tags = _parse_query_tags(hash_tag or "")
    normalized_text = (text_query or "").strip()
    quest_id_query = (quest_id or "").strip()

    candidate_ids: List[str] | None = None
    if quest_id_query:
        candidate_ids = _find_candidates_by_id(quest_id_query)

    if normalized_text and candidate_ids is not None:
        # Keep quest-id prefilter only when both quest_id and text are provided.
        # Text matching itself is handled in _matches_filters via normalized title parsing.
        candidate_ids = list(candidate_ids)

    if candidate_ids is None:
        candidate_ids = _list_all_quest_ids()

    results: List[Dict[str, Any]] = []
    for quest_id_value in candidate_ids:
        quest = get_quest(quest_id_value)
        if quest and _matches_filters(quest, normalized_tags, normalized_text):
            results.append(quest)

    total = len(results)
    safe_page = max(1, page)
    safe_page_size = max(1, min(page_size, 200))
    start = (safe_page - 1) * safe_page_size
    end = start + safe_page_size
    paged = results[start:end]

    return {
        "quests": paged,
        "total": total,
        "page": safe_page,
        "page_size": safe_page_size,
    }


def _quest_matches_tags(quest: Dict[str, Any], query_tags: List[str]) -> bool:
    if not query_tags:
        return True
    tags = [_normalize_tag(tag) for tag in normalize_hash_tags(quest)]
    tags = [tag for tag in tags if tag]
    if not tags:
        return False
    # Query semantics:
    # - one tag: include quests containing that tag token
    # - many tags: include only quests that contain all query tokens (AND)
    for query in query_tags:
        if not any(query in tag for tag in tags):
            return False
    return True


def _normalize_tag(tag: str) -> str:
    return tag.strip().lstrip("#").strip().lower()


def _parse_query_tags(raw: str) -> List[str]:
    if not raw:
        return []
    parts = [p for p in raw.replace(";", ",").split(",")]
    out: List[str] = []
    for part in parts:
        normalized = _normalize_tag(part)
        if normalized and normalized not in out:
            out.append(normalized)
    return out


def list_reusable_codebases(
    buffer_tags: Iterable[str],
    exclude_codebases: set[int],
    limit: int,
) -> List[Dict[str, Any]]:
    """
    Fetch existing quests whose tags are all within buffer_tags and codebase_id present.
    Returns at most `limit` entries with quest_id/codebase_id/seed/hash_tags/difficulty.
    """
    init_db()
    tag_set = { _normalize_tag(t) for t in buffer_tags if _normalize_tag(t) }
    if not tag_set:
        return []

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute(
        """
        SELECT qd.quest_id, qd.codebase_id, qd.seed, qd.hash_tag, qi.difficulty
        FROM quest_data qd
        JOIN quest_info qi ON qi.quest_id = qd.quest_id
        WHERE qd.codebase_id IS NOT NULL
        ORDER BY qd.rowid DESC
        LIMIT ?
        """,
        (max(10, limit * 4),),
    )
    rows = cursor.fetchall()
    conn.close()

    results: List[Dict[str, Any]] = []
    for quest_id, codebase_id, seed, hash_tag_json, difficulty in rows:
        try:
            cb = int(codebase_id)
        except Exception:
            continue
        if cb in exclude_codebases:
            continue
        try:
            tags = json.loads(hash_tag_json) if hash_tag_json else []
        except Exception:
            tags = []
        norm_tags = [_normalize_tag(t) for t in tags if _normalize_tag(t)]
        if not norm_tags:
            continue
        # must all be within buffer
        if not all(t in tag_set for t in norm_tags):
            continue
        results.append(
            {
                "quest_id": quest_id,
                "codebase_id": cb,
                "seed": seed,
                "hash_tags": tags,
                "difficulty_tier": difficulty,
            }
        )
        if len(results) >= limit:
            break
    return results


def _matches_filters(
    quest: Dict[str, Any],
    query_tags: List[str],
    text_query: str,
) -> bool:
    if query_tags and not _quest_matches_tags(quest, query_tags):
        return False
    if text_query:
        title_value = (quest.get("data", {}) or {}).get("quest_title")
        title_text = _content_to_text(title_value)
        if text_query.lower() not in title_text.lower():
            return False
    return True


def _content_to_text(value: Any) -> str:
    content = _parse_content(value)
    if not content:
        return ""
    blocks = content.get("blocks", [])
    return " ".join(
        block.get("content", "")
        for block in blocks
        if isinstance(block, dict) and block.get("content")
    )


def _hash_tag_json_matches(hash_tag_json: str, normalized_tag: str) -> bool:
    if not normalized_tag:
        return True
    try:
        tags = json.loads(hash_tag_json)
    except json.JSONDecodeError:
        tags = []
    for tag in tags:
        normalized_item = _normalize_tag(tag)
        if normalized_item and normalized_tag in normalized_item:
            return True
    return False


def _find_candidates_by_text(text_query: str) -> List[str]:
    if not text_query:
        return []
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute(
        "SELECT quest_id FROM quest_data WHERE LOWER(quest_title) LIKE ?",
        (f"%{text_query.lower()}%",),
    )
    rows = cursor.fetchall()
    conn.close()
    return [row[0] for row in rows]


def _find_candidates_by_id(quest_id_query: str) -> List[str]:
    if not quest_id_query:
        return []
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute(
        "SELECT quest_id FROM quest_header WHERE quest_id LIKE ?",
        (f"%{quest_id_query}%",),
    )
    rows = cursor.fetchall()
    conn.close()
    return [row[0] for row in rows]


def _list_all_quest_ids() -> List[str]:
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("SELECT quest_id FROM quest_header ORDER BY quest_id DESC")
    rows = cursor.fetchall()
    conn.close()
    return [row[0] for row in rows]
