import json
import sqlite3
from typing import Any, Dict, List, Optional

# =========================
# Database config
# =========================

DB_PATH = "quests.db"


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

    # Ensure branches column exists for legacy DBs
    _ensure_column(cursor, "solve_step", "branches", "TEXT NOT NULL DEFAULT '[]'")

    conn.commit()
    conn.close()


def store_data(storage_data: Dict[str, Any]) -> bool:
    """
    Persist normalized quest data to SQLite.

    Args:
        storage_data: Data from fix_gen() with keys header/info/data/solves.
    """
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
            INSERT INTO quest_data (quest_id, quest_title, quest_image)
            VALUES (?, ?, ?)
            """,
            (quest_id, data["quest_title"], data.get("quest_image")),
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
                    solve["flow"],
                    json.dumps(solve.get("hash_tag", [])),
                    solve["hint_riddle"],
                    solve["answer_riddle"],
                    solve["enter_huddle"],
                    json.dumps(solve.get("branches", [])),
                ),
            )

        conn.commit()
        conn.close()

        print(f"데이터베이스 저장 완료 (Quest ID: {quest_id})")
        return True

    except sqlite3.IntegrityError as e:
        print(f"무결성 오류: {e}")
        return False
    except Exception as e:
        print(f"저장 오류: {e}")
        import traceback

        traceback.print_exc()
        return False


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

        cursor.execute("SELECT * FROM quest_data WHERE quest_id = ?", (quest_id,))
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
                "quest_title": data_row[1],
                "quest_image": data_row[2],
            },
            "solves": [
                {
                    "flow": row[2],
                    "hash_tag": json.loads(row[3]),
                    "hint_riddle": row[4],
                    "answer_riddle": row[5],
                    "enter_huddle": row[6],
                    "branches": json.loads(row[7]) if len(row) > 7 else [],
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
    normalized_tag = _normalize_tag(hash_tag or "")
    normalized_text = (text_query or "").strip()
    quest_id_query = (quest_id or "").strip()

    candidate_ids: List[str] | None = None
    if quest_id_query:
        candidate_ids = _find_candidates_by_id(quest_id_query)

    if normalized_text:
        text_candidates = _find_candidates_by_text(normalized_text)
        if candidate_ids is None:
            candidate_ids = text_candidates
        else:
            candidate_set = set(candidate_ids)
            candidate_ids = [value for value in text_candidates if value in candidate_set]

    if candidate_ids is None:
        candidate_ids = _list_all_quest_ids()

    results: List[Dict[str, Any]] = []
    for quest_id_value in candidate_ids:
        quest = get_quest(quest_id_value)
        if quest and _matches_filters(quest, normalized_tag, normalized_text):
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


def _quest_matches_tag(quest: Dict[str, Any], hash_tag: str) -> bool:
    normalized = _normalize_tag(hash_tag)
    if not normalized:
        return True
    tags = quest.get("info", {}).get("hash_tag", [])
    for tag in tags:
        normalized_tag = _normalize_tag(tag)
        if normalized_tag and normalized in normalized_tag:
            return True
    return False


def _normalize_tag(tag: str) -> str:
    return tag.strip().lstrip("#").strip().lower()


def _matches_filters(
    quest: Dict[str, Any],
    hash_tag: str,
    text_query: str,
) -> bool:
    if hash_tag and not _quest_matches_tag(quest, hash_tag):
        return False
    if text_query:
        title = (quest.get("data", {}) or {}).get("quest_title", "") or ""
        if text_query.lower() not in title.lower():
            return False
    return True


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
