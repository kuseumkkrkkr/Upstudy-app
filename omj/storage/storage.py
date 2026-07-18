import json
import os
import sqlite3
import threading
import time
from math import ceil
from pathlib import Path
from typing import Any, Dict, List, Optional
from typing import Iterable

from domain.quest.search_view import normalize_hash_tags
from infra.db.connection import connect_sqlite
from difficulty_contract import DIFFICULTY_CONTRACTS, resolve_difficulty_score, resolve_difficulty_tier
from student_problem_content_review import review_student_problem_contract

# =========================
# Database config
# =========================

# 필요 변수: 선택적 QUEST_DB_PATH 환경변수.
# 작동 원리: 운영 기본값은 유지하되 대규모 생성 실험은 복제 DB로 완전히 격리한다.
DB_PATH = os.environ.get(
    "QUEST_DB_PATH",
    str((Path(__file__).resolve().parent.parent / "quests.db")),
)
# Keep the last store_data error so API handlers can return detail
_LAST_STORE_ERROR: Optional[str] = None
_LAST_STORE_ERROR_LOCAL = threading.local()
_CACHE_SCHEMA_READY = False
_CACHE_SCHEMA_LOCK = threading.Lock()
_RESERVATION_LOCK = threading.Lock()
_MEMORY_RESERVATIONS: Dict[tuple[str, str], Dict[str, tuple[str, int]]] = {}


def _connect() -> sqlite3.Connection:
    return connect_sqlite(DB_PATH)


def _set_last_store_error(value: Optional[str]) -> None:
    global _LAST_STORE_ERROR
    _LAST_STORE_ERROR = value
    _LAST_STORE_ERROR_LOCAL.value = value


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


def _serialize_meta(data: Dict[str, Any]) -> str:
    raw_meta = data.get("meta")
    if isinstance(raw_meta, dict):
        meta = dict(raw_meta)
    else:
        meta = {}

    mcq_conversion = data.get("mcq_conversion")
    if isinstance(mcq_conversion, dict):
        meta["mcq_conversion"] = mcq_conversion

    for key in (
        "advanced_generation_context",
        "variant_request_signature",
        "variant_runtime_params",
        "variant_meta",
    ):
        value = data.get(key)
        if value is not None:
            meta[key] = value

    return json.dumps(meta, ensure_ascii=False)


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
    conn = _connect()
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
    _ensure_column(cursor, "quest_data", "choice_answer_index", "INTEGER")
    _ensure_column(cursor, "quest_data", "meta_json", "TEXT")
    # 필요 변수: 기존 계산 점수와 학생용 1~5 티어, 콘텐츠 검수 결과.
    # 작동 원리: 기존 difficulty 의미를 보존하면서 캐시 조회 계약을 별도 칼럼으로 분리한다.
    _ensure_column(cursor, "quest_info", "difficulty_tier", "INTEGER")
    _ensure_column(cursor, "quest_info", "difficulty_score", "INTEGER")
    _ensure_column(cursor, "quest_info", "tier_source", "TEXT")
    _ensure_column(cursor, "quest_info", "quality_status", "TEXT NOT NULL DEFAULT 'pending'")
    _ensure_column(cursor, "quest_info", "quality_reasons", "TEXT NOT NULL DEFAULT '[]'")
    _ensure_column(cursor, "quest_info", "quality_checked_at", "INTEGER")

    # 필요 변수: quest_id, 정규화된 태그.
    # 작동 원리: JSON 태그 전문 검색을 피하고, 캐시 문제 후보를 인덱스로 빠르게 좁힌다.
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS quest_tag_index (
            quest_id TEXT NOT NULL,
            tag TEXT NOT NULL,
            PRIMARY KEY (quest_id, tag)
        )
        """
    )
    cursor.execute(
        "CREATE INDEX IF NOT EXISTS idx_quest_tag_index_tag_quest ON quest_tag_index(tag, quest_id)"
    )
    cursor.execute(
        "CREATE INDEX IF NOT EXISTS idx_quest_data_cache_lookup ON quest_data(codebase_id, seed, quest_id)"
    )
    cursor.execute(
        "CREATE INDEX IF NOT EXISTS idx_quest_info_tier_quality ON quest_info(difficulty_tier, quality_status, quest_id)"
    )

    # 필요 변수: 사용자, 요청 조건 서명, 문제 ID, 상태.
    # 작동 원리: 즉시 제공할 문제와 다음 문제를 사용자별로 예약해 같은 문제 재노출을 막는다.
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS user_problem_queue (
            user_id TEXT NOT NULL,
            request_key TEXT NOT NULL,
            quest_id TEXT NOT NULL,
            state TEXT NOT NULL CHECK(state IN ('queued', 'served')),
            reserved_at INTEGER NOT NULL,
            PRIMARY KEY (user_id, request_key, quest_id)
        )
        """
    )
    cursor.execute(
        "CREATE INDEX IF NOT EXISTS idx_user_problem_queue_ready ON user_problem_queue(user_id, request_key, state, reserved_at)"
    )

    # 기존 DB는 최초 한 번만 태그 인덱스를 역채운다. 이후 저장되는 문제는 store_data에서 즉시 반영한다.
    indexed_count = cursor.execute("SELECT COUNT(*) FROM quest_tag_index").fetchone()[0]
    if indexed_count == 0:
        rows = cursor.execute(
            "SELECT quest_id, hash_tag FROM quest_data WHERE hash_tag IS NOT NULL"
        ).fetchall()
        for indexed_quest_id, raw_tags in rows:
            _insert_quest_tag_index(cursor, indexed_quest_id, raw_tags)

    conn.commit()
    conn.close()
    global _CACHE_SCHEMA_READY
    _CACHE_SCHEMA_READY = True


def store_data(storage_data: Dict[str, Any]) -> bool:
    """
    Persist normalized quest data to SQLite.

    Args:
        storage_data: Data from fix_gen() with keys header/info/data/solves.
    """
    _set_last_store_error(None)
    conn: Optional[sqlite3.Connection] = None
    try:
        # 서버 시작 후 매 저장마다 DDL과 태그 백필을 반복하지 않는다.
        if not _CACHE_SCHEMA_READY:
            with _CACHE_SCHEMA_LOCK:
                if not _CACHE_SCHEMA_READY:
                    init_db()
        conn = _connect()
        cursor = conn.cursor()

        header = storage_data["header"]
        info = storage_data["info"]
        data = storage_data["data"]
        solves = storage_data["solves"]

        quest_id = header["quest_id"]
        difficulty_score = resolve_difficulty_score(info)
        difficulty_tier, tier_source = resolve_difficulty_tier(
            info,
            solves_count=len(solves),
            strategy_level=info.get("main_huddle"),
        )
        quality_review = review_student_problem_contract(
            storage_data,
            expected_solve_count=DIFFICULTY_CONTRACTS[difficulty_tier].solves_count,
            expected_tags=info.get("hash_tag") or [],
        )
        quality_reasons = [str(reason) for reason in quality_review["reasons"]]
        quality_status = "approved" if not quality_reasons else "rejected"
        quality_checked_at = int(time.time())

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

        _insert_quest_tag_index(cursor, quest_id, info.get("hash_tag", []))

        # 2. quest_info insert
        cursor.execute(
            """
            INSERT INTO quest_info 
            (quest_id, main, sub, hash_tag, flow_rate, difficulty, main_huddle,
             difficulty_tier, difficulty_score, tier_source, quality_status,
             quality_reasons, quality_checked_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                quest_id,
                info["main"],
                json.dumps(info.get("sub", [])),
                json.dumps(info["hash_tag"]),
                info["flow_rate"],
                difficulty_score,
                info["main_huddle"],
                difficulty_tier,
                difficulty_score,
                tier_source,
                quality_status,
                json.dumps(quality_reasons, ensure_ascii=False),
                quality_checked_at,
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
                hash_tag,
                choice_answer_index,
                meta_json
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
                data.get("choice_answer_index"),
                _serialize_meta(data),
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
        conn = None

        # 필요한 변수는 PROBLEM_DUAL_WRITE_ENABLED와 검수된 문제 payload다.
        # 작동 원리는 운영에서는 SQLite 커밋 뒤 PostgreSQL 비동기 이중 기록을 유지하고,
        # 로컬 직접 생산은 이를 꺼서 외부 DB 장애가 프로세스 종료를 지연하지 않게 한다.
        dual_write_enabled = os.getenv(
            "PROBLEM_DUAL_WRITE_ENABLED",
            "true",
        ).strip().lower() in {"1", "true", "yes", "on"}
        if dual_write_enabled:
            try:
                from storage.postgres_problem_store import postgres_problem_store

                postgres_problem_store.enqueue_problem_upsert(storage_data)
            except Exception:
                pass

        if os.getenv("QUEST_STORE_LOGS", "").strip().lower() in {"1", "true", "yes"}:
            print(f"데이터베이스 저장 완료 (Quest ID: {quest_id})")
        return True

    except sqlite3.IntegrityError as e:
        _set_last_store_error(f"무결성 오류: {e}")
        print(get_last_store_error())
        return False
    except Exception as e:
        _set_last_store_error(f"저장 오류: {e}")
        print(get_last_store_error())
        import traceback

        traceback.print_exc()
        return False
    finally:
        if conn is not None:
            try:
                conn.rollback()
            except Exception:
                pass
            conn.close()


def get_last_store_error() -> Optional[str]:
    """Return the last error message set by store_data (if any)."""
    return getattr(_LAST_STORE_ERROR_LOCAL, "value", _LAST_STORE_ERROR)


def get_quest(quest_id: str) -> Dict[str, Any] | None:
    """
    Retrieve a quest by id from the database.
    """
    try:
        conn = _connect()
        cursor = conn.cursor()

        cursor.execute("SELECT * FROM quest_header WHERE quest_id = ?", (quest_id,))
        header = cursor.fetchone()

        if not header:
            print(f"해당 문제가 없습니다: {quest_id}")
            return None

        cursor.execute(
            """
            SELECT quest_id, main, sub, hash_tag, flow_rate, difficulty, main_huddle,
                   difficulty_tier, difficulty_score, tier_source, quality_status,
                   quality_reasons
            FROM quest_info WHERE quest_id = ?
            """,
            (quest_id,),
        )
        info_row = cursor.fetchone()

        cursor.execute(
            """
            SELECT quest_id, quest_title, quest_image, quest_answer, question_type, quest_options, codebase_id, seed, hash_tag, choice_answer_index, meta_json
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
                "difficulty_tier": info_row[7],
                "difficulty_score": info_row[8] if info_row[8] is not None else info_row[5],
                "tier_source": info_row[9],
                "quality_status": info_row[10],
                "quality_reasons": json.loads(info_row[11] or "[]"),
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
                "choice_answer_index": data_row[9] if data_row and len(data_row) > 9 else None,
                "meta": json.loads(data_row[10]) if data_row and len(data_row) > 10 and data_row[10] else {},
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
        if isinstance(result["data"].get("meta"), dict):
            meta = result["data"]["meta"]
            if isinstance(meta.get("mcq_conversion"), dict):
                result["data"]["mcq_conversion"] = meta["mcq_conversion"]
            elif "answer_index" in meta:
                result["data"]["mcq_conversion"] = meta

        return result

    except Exception as e:
        print(f"조회 오류: {e}")
        return None


def get_quests_by_ids(quest_ids: Iterable[str]) -> List[Dict[str, Any]]:
    """필요 변수: 문제 ID 목록. 작동 원리: 헤더·정보·본문·풀이를 각각 한 번씩만 조회해 캐시 응답의 N+1 DB 요청을 제거한다."""
    ordered_ids = [str(quest_id) for quest_id in quest_ids if str(quest_id)]
    if not ordered_ids:
        return []
    unique_ids = list(dict.fromkeys(ordered_ids))
    placeholders = ",".join("?" for _ in unique_ids)
    try:
        conn = _connect()
        try:
            headers = {
                row[0]: row[1]
                for row in conn.execute(
                    f"SELECT quest_id, quest_model FROM quest_header WHERE quest_id IN ({placeholders})",
                    unique_ids,
                ).fetchall()
            }
            infos = {
                row[0]: row
                for row in conn.execute(
                    f"SELECT quest_id, main, sub, hash_tag, flow_rate, difficulty, main_huddle, "
                    f"difficulty_tier, difficulty_score, tier_source, quality_status, quality_reasons "
                    f"FROM quest_info WHERE quest_id IN ({placeholders})",
                    unique_ids,
                ).fetchall()
            }
            data_rows = {
                row[0]: row
                for row in conn.execute(
                    f"SELECT quest_id, quest_title, quest_image, quest_answer, question_type, quest_options, "
                    f"codebase_id, seed, hash_tag, choice_answer_index, meta_json "
                    f"FROM quest_data WHERE quest_id IN ({placeholders})",
                    unique_ids,
                ).fetchall()
            }
            solves_by_quest: Dict[str, List[tuple]] = {quest_id: [] for quest_id in unique_ids}
            for row in conn.execute(
                f"SELECT quest_id, flow, hash_tag, hint_riddle, answer_riddle, enter_huddle, branches "
                f"FROM solve_step WHERE quest_id IN ({placeholders}) ORDER BY id ASC",
                unique_ids,
            ).fetchall():
                solves_by_quest.setdefault(row[0], []).append(row)
        finally:
            conn.close()
    except Exception as exc:
        print(f"일괄 조회 오류: {exc}")
        return []

    results: List[Dict[str, Any]] = []
    for quest_id in ordered_ids:
        header_model = headers.get(quest_id)
        info_row = infos.get(quest_id)
        data_row = data_rows.get(quest_id)
        if header_model is None or info_row is None:
            continue
        try:
            models = json.loads(header_model)
            info_tags = json.loads(info_row[3])
            sub = json.loads(info_row[2])
            data_tags = json.loads(data_row[8]) if data_row and data_row[8] else []
            meta = json.loads(data_row[10]) if data_row and data_row[10] else {}
        except (TypeError, json.JSONDecodeError):
            continue
        quest = {
            "header": {"quest_id": quest_id, "quest_model": {"models": models}},
            "info": {
                "main": info_row[1], "sub": sub, "hash_tag": info_tags,
                "flow_rate": info_row[4], "difficulty": info_row[5], "main_huddle": info_row[6],
                "difficulty_tier": info_row[7],
                "difficulty_score": info_row[8] if info_row[8] is not None else info_row[5],
                "tier_source": info_row[9],
                "quality_status": info_row[10],
                "quality_reasons": json.loads(info_row[11] or "[]"),
            },
            "data": {
                "quest_title": _parse_content(data_row[1]) if data_row else None,
                "quest_image": data_row[2] if data_row else None,
                "quest_answer": _parse_content(data_row[3]) if data_row else None,
                "question_type": data_row[4] if data_row else None,
                "quest_options": _parse_options(data_row[5]) if data_row else None,
                "codebase_id": data_row[6] if data_row else None,
                "seed": data_row[7] if data_row else None,
                "hash_tag": data_tags,
                "choice_answer_index": data_row[9] if data_row else None,
                "meta": meta,
            },
            "solves": [
                {
                    "flow": _parse_content(row[1]), "hash_tag": json.loads(row[2]),
                    "hint_riddle": _parse_content(row[3]), "answer_riddle": _parse_content(row[4]),
                    "enter_huddle": row[5], "branches": _normalize_nested_steps(row[6]),
                }
                for row in solves_by_quest.get(quest_id, [])
            ],
        }
        if isinstance(meta, dict):
            if isinstance(meta.get("mcq_conversion"), dict):
                quest["data"]["mcq_conversion"] = meta["mcq_conversion"]
            elif "answer_index" in meta:
                quest["data"]["mcq_conversion"] = meta
        results.append(quest)
    return results


def update_quest_mcq(
    quest_id: str,
    *,
    quest_options: list,
    choice_answer_index: int,
    meta: Optional[Dict[str, Any]] = None,
) -> bool:
    """Persist multiple-choice options and answer metadata for an existing quest."""
    # 서버 시작 시 스키마를 준비하므로 정상 요청에서는 DDL을 반복하지 않는다.
    if not _CACHE_SCHEMA_READY:
        with _CACHE_SCHEMA_LOCK:
            if not _CACHE_SCHEMA_READY:
                init_db()
    conn = _connect()
    cursor = conn.cursor()
    cursor.execute(
        """
        UPDATE quest_data
        SET question_type = ?,
            quest_options = ?,
            choice_answer_index = ?,
            meta_json = ?
        WHERE quest_id = ?
        """,
        (
            "multiple_choice",
            _serialize_options(quest_options),
            int(choice_answer_index),
            json.dumps(meta or {}, ensure_ascii=False),
            quest_id,
        ),
    )
    changed = cursor.rowcount > 0
    conn.commit()
    conn.close()
    return changed


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

    if candidate_ids is None and normalized_tags:
        candidate_ids = _find_candidates_by_tags(normalized_tags)

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


def _insert_quest_tag_index(cursor: sqlite3.Cursor, quest_id: str, raw_tags: Any) -> None:
    """필요 변수: 문제 ID와 원본 태그 목록. 작동 원리: 태그를 정규화해 역색인 테이블에 중복 없이 저장한다."""
    if isinstance(raw_tags, str):
        try:
            raw_tags = json.loads(raw_tags)
        except json.JSONDecodeError:
            raw_tags = [raw_tags]
    if not isinstance(raw_tags, list):
        return
    rows = [(quest_id, _normalize_tag(str(tag))) for tag in raw_tags]
    rows = [(qid, tag) for qid, tag in rows if tag]
    if rows:
        cursor.executemany(
            "INSERT OR IGNORE INTO quest_tag_index (quest_id, tag) VALUES (?, ?)",
            rows,
        )


def _problem_request_key(tags: Iterable[str], min_tier: int, max_tier: int) -> str:
    """필요 변수: 태그·난이도 범위. 작동 원리: 같은 조건의 사용자별 미사용 문제 큐를 공유하기 위한 안정 키를 만든다."""
    normalized = sorted({_normalize_tag(tag) for tag in tags if _normalize_tag(tag)})
    return f"{','.join(normalized)}|{int(min_tier)}|{int(max_tier)}"


def _claim_memory_reservations(
    user_id: str,
    request_key: str,
    *,
    count: int,
    now: int,
) -> tuple[List[str], set[str]]:
    """필요 변수: 사용자·요청 키·수량·현재 시각. 작동 원리: SQLite 폴백에서 사용자별 예약을 메모리 잠금 한 번으로 소비해 DB 쓰기 경합을 제거한다."""
    expires_before = now - 30 * 24 * 60 * 60
    key = (user_id, request_key)
    with _RESERVATION_LOCK:
        if len(_MEMORY_RESERVATIONS) > 20_000:
            expired_keys = [
                reservation_key
                for reservation_key, values in _MEMORY_RESERVATIONS.items()
                if not values or max(timestamp for _, timestamp in values.values()) < expires_before
            ]
            for reservation_key in expired_keys:
                _MEMORY_RESERVATIONS.pop(reservation_key, None)
            while len(_MEMORY_RESERVATIONS) > 20_000:
                _MEMORY_RESERVATIONS.pop(next(iter(_MEMORY_RESERVATIONS)), None)
        reservations = _MEMORY_RESERVATIONS.setdefault(key, {})
        for quest_id in [qid for qid, (_, timestamp) in reservations.items() if timestamp < expires_before]:
            reservations.pop(quest_id, None)
        queued = [qid for qid, (state, _) in reservations.items() if state == "queued"][:count]
        for quest_id in queued:
            reservations[quest_id] = ("served", now)
        return queued, set(reservations)


def _reserve_memory_quests(
    user_id: str,
    request_key: str,
    quest_ids: Iterable[str],
    *,
    serve_count: int,
    now: int,
) -> List[str]:
    """필요 변수: 사용자·요청 키·후보 ID·즉시 제공 수. 작동 원리: 중복 후보를 제외하고 제공분과 사전 준비분을 원자적으로 구분한다."""
    key = (user_id, request_key)
    serving: List[str] = []
    with _RESERVATION_LOCK:
        reservations = _MEMORY_RESERVATIONS.setdefault(key, {})
        for quest_id in quest_ids:
            if quest_id in reservations:
                continue
            if len(serving) < serve_count:
                reservations[quest_id] = ("served", now)
                serving.append(quest_id)
            else:
                reservations[quest_id] = ("queued", now)
    return serving


def claim_cached_quests(
    *,
    user_id: str,
    hash_tags: Iterable[str],
    min_difficulty_tier: int,
    max_difficulty_tier: int,
    question_count: int,
    prefetch_count: int = 10,
) -> tuple[List[Dict[str, Any]], Dict[str, int]]:
    """필요 변수: 사용자·태그·난이도·문항 수. 작동 원리: 최근 풀이 codebase+seed를 제외하고 100%→50%→1개 태그 순으로 캐시를 예약·반환한다."""
    tags = sorted({_normalize_tag(tag) for tag in hash_tags if _normalize_tag(tag)})
    if not user_id or not tags or question_count < 1:
        return [], {"queued": 0, "cached": 0, "match_stage": 0}

    # PostgreSQL·Redis가 준비되지 않으면 로컬 저장소로 우회하지 않고 요청을 실패시킨다.
    try:
        from storage.postgres_problem_store import postgres_problem_store

        postgres_result = postgres_problem_store.claim_cached_quests(
            user_id=user_id,
            hash_tags=list(hash_tags),
            min_difficulty_tier=min_difficulty_tier,
            max_difficulty_tier=max_difficulty_tier,
            question_count=question_count,
            prefetch_count=prefetch_count,
        )
        if postgres_result is not None:
            return postgres_result
        raise RuntimeError("PostgreSQL problem cache backend is not enabled")
    except Exception as exc:
        raise RuntimeError(
            "PostgreSQL problem cache is required and no fallback is available"
        ) from exc

    # 서버 시작 시 스키마를 준비하므로 정상 요청에서는 DDL을 반복하지 않는다.
    if not _CACHE_SCHEMA_READY:
        with _CACHE_SCHEMA_LOCK:
            if not _CACHE_SCHEMA_READY:
                init_db()
    request_key = _problem_request_key(tags, min_difficulty_tier, max_difficulty_tier)
    now = int(time.time())
    target_count = max(question_count, question_count + max(0, prefetch_count))
    selected_ids, reserved_ids = _claim_memory_reservations(
        user_id,
        request_key,
        count=question_count,
        now=now,
    )
    selected_stage = 0

    conn = _connect()
    try:
        cursor = conn.cursor()
        needed = target_count - len(selected_ids)
        # 100% 일치 → 50% 이상 → 최소 태그 1개 일치 순서로만 확장한다.
        match_stages = dict.fromkeys((len(tags), max(1, ceil(len(tags) * 0.5)), 1))
        for required_matches in match_stages:
            if needed <= 0:
                break
            if required_matches > len(tags):
                continue
            placeholders = ",".join("?" for _ in tags)
            rows = cursor.execute(
                f"""
                SELECT qd.quest_id, COUNT(DISTINCT qti.tag) AS matched_count
                FROM quest_data qd
                JOIN quest_info qi ON qi.quest_id = qd.quest_id
                JOIN quest_tag_index qti ON qti.quest_id = qd.quest_id
                WHERE qd.codebase_id IS NOT NULL
                  AND qd.seed IS NOT NULL
                  AND qi.difficulty_tier BETWEEN ? AND ?
                  AND qi.quality_status = 'approved'
                  AND qti.tag IN ({placeholders})
                  AND NOT EXISTS (
                    SELECT 1 FROM user_habit uh
                    WHERE uh.user_id = ? AND uh.kind = 'problem'
                      AND uh.codebase_id = qd.codebase_id
                      AND CAST(uh.seed AS TEXT) = CAST(qd.seed AS TEXT)
                  )
                GROUP BY qd.quest_id
                HAVING COUNT(DISTINCT qti.tag) >= ?
                ORDER BY matched_count DESC, qd.rowid DESC
                LIMIT ?
                """,
                [min_difficulty_tier, max_difficulty_tier, *tags, user_id, required_matches, max(needed * 4, 20)],
            ).fetchall()
            if not rows:
                continue
            new_ids = [str(row[0]) for row in rows if str(row[0]) not in reserved_ids]
            if not new_ids:
                continue
            if selected_stage == 0:
                selected_stage = required_matches
            serve_now = max(0, question_count - len(selected_ids))
            serving_ids = _reserve_memory_quests(
                user_id,
                request_key,
                new_ids[:needed],
                serve_count=serve_now,
                now=now,
            )
            selected_ids.extend(serving_ids)
            reserved_ids.update(new_ids[:needed])
            needed -= len(new_ids)
    except sqlite3.OperationalError:
        # 구버전 DB에서 habit 테이블 초기화가 아직 끝나지 않은 경우 요청을 실패시키지 않는다.
        selected_ids = []
    finally:
        conn.close()

    quests = get_quests_by_ids(selected_ids)
    return quests, {
        "queued": max(0, target_count - len(selected_ids)),
        "cached": len(quests),
        "match_stage": selected_stage,
    }


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

    conn = _connect()
    cursor = conn.cursor()
    cursor.execute(
        """
        SELECT qd.quest_id, qd.codebase_id, qd.seed, qd.hash_tag, qi.difficulty_tier
        FROM quest_data qd
        JOIN quest_info qi ON qi.quest_id = qd.quest_id
        WHERE qd.codebase_id IS NOT NULL
          AND qi.quality_status = 'approved'
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
    conn = _connect()
    cursor = conn.cursor()
    cursor.execute(
        "SELECT quest_id FROM quest_data WHERE LOWER(quest_title) LIKE ?",
        (f"%{text_query.lower()}%",),
    )
    rows = cursor.fetchall()
    conn.close()
    return [row[0] for row in rows]


def _tag_like_patterns(normalized_tag: str) -> List[str]:
    tag = normalized_tag.strip().lstrip("#").strip().lower()
    if not tag:
        return []
    variants = {tag, f"#{tag}"}
    for item in list(variants):
        variants.add(json.dumps(item, ensure_ascii=True)[1:-1].lower())
    return [f"%{item}%" for item in sorted(variants)]


def _find_candidates_by_tags(normalized_tags: List[str]) -> List[str]:
    clauses: List[str] = []
    params: List[str] = []
    for tag in normalized_tags:
        patterns = _tag_like_patterns(tag)
        if not patterns:
            continue
        clauses.append(
            "(" + " OR ".join("LOWER(tag_blob) LIKE ?" for _ in patterns) + ")"
        )
        params.extend(patterns)
    if not clauses:
        return []

    conn = _connect()
    cursor = conn.cursor()
    cursor.execute(
        f"""
        SELECT quest_id
        FROM (
            SELECT
                h.quest_id AS quest_id,
                COALESCE(qi.hash_tag, '') || ' ' || COALESCE(qd.hash_tag, '') AS tag_blob
            FROM quest_header h
            LEFT JOIN quest_info qi ON qi.quest_id = h.quest_id
            LEFT JOIN quest_data qd ON qd.quest_id = h.quest_id
        )
        WHERE {" AND ".join(clauses)}
        ORDER BY quest_id DESC
        """,
        params,
    )
    rows = cursor.fetchall()
    conn.close()
    return [row[0] for row in rows]


def _find_candidates_by_id(quest_id_query: str) -> List[str]:
    if not quest_id_query:
        return []
    conn = _connect()
    cursor = conn.cursor()
    cursor.execute(
        "SELECT quest_id FROM quest_header WHERE quest_id LIKE ?",
        (f"%{quest_id_query}%",),
    )
    rows = cursor.fetchall()
    conn.close()
    return [row[0] for row in rows]


def _list_all_quest_ids() -> List[str]:
    conn = _connect()
    cursor = conn.cursor()
    cursor.execute("SELECT quest_id FROM quest_header ORDER BY quest_id DESC")
    rows = cursor.fetchall()
    conn.close()
    return [row[0] for row in rows]
