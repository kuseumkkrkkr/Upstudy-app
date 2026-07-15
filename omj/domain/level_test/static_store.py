"""레벨테스트 전용 정적 SQLite 문제 저장소.

운영 문제은행과 연결하지 않고, 빌드 시 검수된 고정 문항과 시험지만 읽는다.
"""
from __future__ import annotations

import copy
import json
import os
import sqlite3
from contextlib import closing
from functools import lru_cache
from pathlib import Path
from typing import Any, Iterable, Optional


DEFAULT_STATIC_DB_PATH = Path(__file__).resolve().parents[2] / "data" / "level_test_static.db"
EXPECTED_SCHEMA_VERSION = "1"
EXPECTED_TEMPLATE_VERSION = "placement-static-v1"
EXPECTED_TEMPLATE_COUNT = 5
EXPECTED_QUESTION_COUNT = 50


def get_static_db_path() -> Path:
    """필요 변수: 선택적 LEVEL_TEST_STATIC_DB_PATH. 작동 원리: 환경값이 없으면 배포에 포함된 전용 DB 절대 경로를 반환한다."""
    configured = os.getenv("LEVEL_TEST_STATIC_DB_PATH", "").strip()
    return Path(configured).resolve() if configured else DEFAULT_STATIC_DB_PATH.resolve()


def _connect(db_path: Optional[Path] = None) -> sqlite3.Connection:
    """필요 변수: 전용 DB 경로. 작동 원리: SQLite URI의 mode=ro와 query_only를 함께 적용해 런타임 쓰기를 차단한다."""
    selected_path = (db_path or get_static_db_path()).resolve()
    if not selected_path.is_file():
        raise RuntimeError(f"level-test static DB is missing: {selected_path}")
    connection = sqlite3.connect(f"file:{selected_path.as_posix()}?mode=ro", uri=True)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA query_only=ON")
    return connection


@lru_cache(maxsize=4)
def _cached_templates(db_path_text: str) -> tuple[dict[str, Any], ...]:
    """필요 변수: 정적 DB 절대 경로. 작동 원리: 다섯 폼 메타데이터를 프로세스당 한 번만 읽어 불변 캐시로 보관한다."""
    with closing(_connect(Path(db_path_text))) as connection:
        rows = connection.execute(
            "SELECT * FROM template WHERE active=1 ORDER BY form_index"
        ).fetchall()
    return tuple(dict(row) for row in rows)


@lru_cache(maxsize=4)
def _cached_template_items(db_path_text: str) -> tuple[dict[str, Any], ...]:
    """필요 변수: 정적 DB 절대 경로. 작동 원리: 250개 슬롯을 한 번에 읽어 답안 제출마다 SQLite를 여는 비용을 없앤다."""
    with closing(_connect(Path(db_path_text))) as connection:
        rows = connection.execute(
            """
            SELECT template_id, item_index, phase, subject_key, hash_tags_json,
                   difficulty_tier, quest_id, problem_rating
            FROM template_item
            ORDER BY template_id, item_index
            """
        ).fetchall()
    items: list[dict[str, Any]] = []
    for row in rows:
        item = dict(row)
        item["hash_tags"] = _loads_json(item.pop("hash_tags_json"), [])
        items.append(item)
    return tuple(items)


@lru_cache(maxsize=4)
def _cached_quests(db_path_text: str) -> dict[str, dict[str, Any]]:
    """필요 변수: 정적 DB 절대 경로. 작동 원리: 전체 검수 payload를 한 번에 역직렬화해 시작·채점 요청의 DB 왕복을 제거한다."""
    with closing(_connect(Path(db_path_text))) as connection:
        rows = connection.execute(
            "SELECT quest_id, payload_json FROM problem WHERE active=1"
        ).fetchall()
    result: dict[str, dict[str, Any]] = {}
    for row in rows:
        payload = _loads_json(row["payload_json"], None)
        if isinstance(payload, dict):
            result[str(row["quest_id"])] = payload
    return result


def clear_static_cache() -> None:
    """필요 변수: 없음. 작동 원리: 빌드 도구가 같은 프로세스에서 DB를 교체했을 때 세 읽기 캐시를 명시적으로 비운다."""
    _cached_templates.cache_clear()
    _cached_template_items.cache_clear()
    _cached_quests.cache_clear()


def _loads_json(raw: Any, default: Any) -> Any:
    """필요 변수: UTF-8 JSON 문자열과 기본값. 작동 원리: 손상된 정적 행이 API 전체를 깨뜨리지 않도록 형식 오류를 기본값으로 격리한다."""
    try:
        return json.loads(str(raw))
    except (TypeError, ValueError, json.JSONDecodeError):
        return default


def list_template_ids() -> list[str]:
    """필요 변수: 없음. 작동 원리: 활성화된 고정 시험지 ID를 폼 번호 순으로 한 번의 읽기 쿼리로 반환한다."""
    db_path_text = str(get_static_db_path())
    return [str(row["template_id"]) for row in _cached_templates(db_path_text)]


def get_template(template_id: str) -> Optional[dict[str, Any]]:
    """필요 변수: 정적 시험지 ID. 작동 원리: 활성 시험지의 배포 버전과 폼 정보를 조회한다."""
    db_path_text = str(get_static_db_path())
    for row in _cached_templates(db_path_text):
        if str(row["template_id"]) == template_id:
            return copy.deepcopy(row)
    return None


def get_template_items(template_id: str) -> list[dict[str, Any]]:
    """필요 변수: 정적 시험지 ID. 작동 원리: 50개 문항 슬롯을 문제 payload와 분리해 순번대로 읽는다."""
    db_path_text = str(get_static_db_path())
    return [
        copy.deepcopy(item)
        for item in _cached_template_items(db_path_text)
        if str(item["template_id"]) == template_id
    ]


def get_template_item(template_id: str, item_index: int) -> Optional[dict[str, Any]]:
    """필요 변수: 시험지 ID와 문항 번호. 작동 원리: 답안 제출이 배정된 고정 문제와 일치하는지 단건 검증한다."""
    db_path_text = str(get_static_db_path())
    for item in _cached_template_items(db_path_text):
        if str(item["template_id"]) == template_id and int(item["item_index"]) == int(item_index):
            return copy.deepcopy(item)
    return None


def get_quest(quest_id: str) -> Optional[dict[str, Any]]:
    """필요 변수: 정적 문제 ID. 작동 원리: 전용 DB의 UTF-8 payload JSON만 역직렬화하며 일반 문제은행은 조회하지 않는다."""
    payload = _cached_quests(str(get_static_db_path())).get(quest_id)
    return copy.deepcopy(payload) if payload else None


def get_quests_by_ids(quest_ids: Iterable[str]) -> dict[str, dict[str, Any]]:
    """필요 변수: 정적 문제 ID 모음. 작동 원리: 중복을 제거한 뒤 한 번의 IN 쿼리로 API 응답용 payload를 일괄 조회한다."""
    ordered_ids = list(dict.fromkeys(str(value) for value in quest_ids if str(value)))
    if not ordered_ids:
        return {}
    cached = _cached_quests(str(get_static_db_path()))
    return {
        quest_id: copy.deepcopy(cached[quest_id])
        for quest_id in ordered_ids
        if quest_id in cached
    }


def validate_static_database() -> dict[str, Any]:
    """필요 변수: 배포된 전용 DB. 작동 원리: 버전·무결성·문항 수·템플릿 분포·끊어진 참조를 읽기 전용으로 일괄 점검한다."""
    with closing(_connect()) as connection:
        integrity = str(connection.execute("PRAGMA integrity_check").fetchone()[0])
        metadata = {
            str(row[0]): str(row[1])
            for row in connection.execute("SELECT key, value FROM metadata")
        }
        problem_count = int(
            connection.execute("SELECT COUNT(*) FROM problem WHERE active=1").fetchone()[0]
        )
        template_rows = connection.execute(
            """
            SELECT t.template_id, COUNT(i.item_index), COUNT(DISTINCT i.quest_id)
            FROM template t
            LEFT JOIN template_item i ON i.template_id=t.template_id
            WHERE t.active=1
            GROUP BY t.template_id
            ORDER BY t.form_index
            """
        ).fetchall()
        stale_items = int(
            connection.execute(
                """
                SELECT COUNT(*)
                FROM template_item i
                LEFT JOIN problem p ON p.quest_id=i.quest_id AND p.active=1
                WHERE p.quest_id IS NULL
                """
            ).fetchone()[0]
        )
        tier_counts = {
            int(row[0]): int(row[1])
            for row in connection.execute(
                "SELECT difficulty_tier, COUNT(*) FROM template_item GROUP BY difficulty_tier"
            )
        }
    # 시작 검증 단계에서 전체 정적 스냅샷을 미리 적재해 첫 학생 요청의 디스크 지연을 없앤다.
    db_path_text = str(get_static_db_path())
    cached_template_count = len(_cached_templates(db_path_text))
    cached_problem_count = len(_cached_quests(db_path_text))
    cached_item_count = len(_cached_template_items(db_path_text))
    if integrity != "ok":
        raise RuntimeError(f"level-test static DB integrity failed: {integrity}")
    if metadata.get("schema_version") != EXPECTED_SCHEMA_VERSION:
        raise RuntimeError("level-test static DB schema version mismatch")
    if metadata.get("template_version") != EXPECTED_TEMPLATE_VERSION:
        raise RuntimeError("level-test static DB template version mismatch")
    if len(template_rows) != EXPECTED_TEMPLATE_COUNT:
        raise RuntimeError(f"level-test template count mismatch: {len(template_rows)}")
    if any(int(row[1]) != EXPECTED_QUESTION_COUNT or int(row[2]) != EXPECTED_QUESTION_COUNT for row in template_rows):
        raise RuntimeError("each level-test template must contain 50 unique problems")
    if stale_items:
        raise RuntimeError(f"level-test static DB has {stale_items} stale items")
    if (
        cached_template_count != EXPECTED_TEMPLATE_COUNT
        or cached_problem_count != problem_count
        or cached_item_count != EXPECTED_TEMPLATE_COUNT * EXPECTED_QUESTION_COUNT
    ):
        raise RuntimeError("level-test static DB contains an invalid UTF-8 JSON payload")
    expected_tiers = {2: 50, 3: 100, 4: 75, 5: 25}
    if tier_counts != expected_tiers:
        raise RuntimeError(f"level-test tier distribution mismatch: {tier_counts}")
    return {
        "db_path": str(get_static_db_path()),
        "integrity_check": integrity,
        "problem_count": problem_count,
        "template_count": len(template_rows),
        "template_question_counts": [int(row[1]) for row in template_rows],
        "tier_counts": tier_counts,
        "stale_items": stale_items,
    }
