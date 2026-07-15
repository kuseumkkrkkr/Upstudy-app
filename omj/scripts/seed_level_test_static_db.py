"""직접 검수한 레벨테스트 문항을 전용 읽기 전용 SQLite 파일로 빌드한다."""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
import sqlite3
import sys
from collections import Counter, defaultdict
from contextlib import closing
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from domain.level_test.static_store import (
    DEFAULT_STATIC_DB_PATH,
    EXPECTED_SCHEMA_VERSION,
    EXPECTED_TEMPLATE_VERSION,
    clear_static_cache,
    validate_static_database,
)
from scripts.seed_additional_math_problems import (
    build_catalog as build_additional_catalog,
    validate_catalog as validate_additional_catalog,
)
from scripts.seed_initial_math_problems import (
    _build_quest as build_authored_quest,
    _problem as authored_problem,
    build_catalog as build_initial_catalog,
    validate_catalog as validate_initial_catalog,
)
from student_problem_content_review import review_student_problem_contract


STATIC_QUEST_PREFIX = "level-test-static/v1"
SUPPLEMENTAL_QUEST_ID = "curated/level-test-supplement-v1/t3-01"
FORM_COUNT = 5
QUESTION_COUNT = 50
CREATED_AT = "2026-07-13T15:00:00+00:00"
SUBJECT_KEYS = ("common_math_1", "common_math_2", "algebra", "calculus_1")
RATING_BANDS = {
    2: (1000.0, 1025.0, 1050.0, 1075.0, 1100.0),
    3: (1150.0, 1175.0, 1200.0, 1225.0, 1250.0),
    4: (1325.0, 1360.0, 1400.0, 1440.0, 1475.0),
    5: (1525.0, 1560.0, 1600.0, 1640.0, 1675.0),
}


def _ids(batch: str, tier: int, indexes: list[int]) -> list[str]:
    """필요 변수: 저작 배치·난이도·문항 번호. 작동 원리: 선택 목록의 오탈자를 줄이는 원본 문제 ID 배열을 만든다."""
    return [f"curated/{batch}/t{tier}-{index:02d}" for index in indexes]


# 실제 교과 태그와 문항 내용에 따라 분류한 후보군이다. 한 문제는 한 교과에만 속한다.
CANDIDATE_IDS: dict[tuple[int, str], list[str]] = {
    (2, "common_math_1"): (
        _ids("initial-math-v1", 2, [1, 2])
        + _ids("additional-math-v2", 2, list(range(1, 9)))
    ),
    (2, "common_math_2"): _ids("initial-math-v1", 2, [3, 8]),
    (2, "algebra"): (
        _ids("initial-math-v1", 2, [4, 5, 6, 7])
        + _ids("additional-math-v2", 2, list(range(9, 17)))
    ),
    (2, "calculus_1"): (
        _ids("initial-math-v1", 2, [9, 10])
        + _ids("additional-math-v2", 2, list(range(17, 21)))
    ),
    (3, "common_math_1"): (
        _ids("initial-math-v1", 3, [1])
        + _ids("additional-math-v2", 3, list(range(1, 5)))
        + [SUPPLEMENTAL_QUEST_ID]
    ),
    (3, "common_math_2"): (
        _ids("initial-math-v1", 3, [5, 6, 10])
        + _ids("additional-math-v2", 3, list(range(13, 17)))
    ),
    (3, "algebra"): (
        _ids("initial-math-v1", 3, [2, 3, 4])
        + _ids("additional-math-v2", 3, list(range(5, 13)))
    ),
    (3, "calculus_1"): (
        _ids("initial-math-v1", 3, [7, 8, 9])
        + _ids("additional-math-v2", 3, list(range(17, 21)))
    ),
    (4, "common_math_2"): (
        _ids("initial-math-v1", 4, [6, 7])
        + _ids("additional-math-v2", 4, list(range(17, 21)))
    ),
    (4, "algebra"): (
        _ids("initial-math-v1", 4, [2, 3, 4, 10])
        + _ids("additional-math-v2", 4, list(range(5, 17)))
    ),
    (4, "calculus_1"): (
        _ids("initial-math-v1", 4, [1, 5, 8])
        + _ids("additional-math-v2", 4, list(range(1, 5)))
    ),
    (5, "common_math_2"): (
        _ids("initial-math-v1", 5, [4, 7, 8, 10])
        + _ids("additional-math-v2", 5, list(range(17, 21)))
    ),
    (5, "algebra"): (
        _ids("initial-math-v1", 5, [1, 6])
        + _ids("additional-math-v2", 5, list(range(1, 5)))
    ),
    (5, "calculus_1"): (
        _ids("initial-math-v1", 5, [2, 3, 5, 9])
        + _ids("additional-math-v2", 5, list(range(5, 17)))
    ),
}


# 1단계는 기반 개념, 2단계는 중상 난도, 3단계는 상위권 변별 문항으로 구성한다.
PHASE_GROUPS: tuple[tuple[int, int, dict[str, int]], ...] = (
    (1, 2, {"common_math_1": 6, "common_math_2": 2, "algebra": 1, "calculus_1": 1}),
    (1, 3, {"common_math_1": 2, "common_math_2": 2, "algebra": 3, "calculus_1": 3}),
    (2, 3, {"common_math_1": 4, "common_math_2": 2, "algebra": 2, "calculus_1": 2}),
    (2, 4, {"common_math_2": 3, "algebra": 3, "calculus_1": 4}),
    (3, 4, {"common_math_2": 2, "algebra": 2, "calculus_1": 1}),
    (3, 5, {"common_math_2": 2, "algebra": 1, "calculus_1": 2}),
)


def _round_robin_subjects(counts: dict[str, int]) -> list[str]:
    """필요 변수: 그룹별 교과 문항 수. 작동 원리: 같은 교과가 길게 연속되지 않도록 고정 순서로 한 개씩 순환 배치한다."""
    remaining = dict(counts)
    result: list[str] = []
    while sum(remaining.values()) > 0:
        for subject in SUBJECT_KEYS:
            if remaining.get(subject, 0) <= 0:
                continue
            result.append(subject)
            remaining[subject] -= 1
    return result


def build_slot_plan() -> list[dict[str, Any]]:
    """필요 변수: 단계·난도·교과 분포 계약. 작동 원리: 앱이 요구하는 50개 슬롯을 난도 10·20·15·5와 교과 12·13·12·13으로 확정한다."""
    slots: list[dict[str, Any]] = []
    for phase, tier, subject_counts in PHASE_GROUPS:
        for subject in _round_robin_subjects(subject_counts):
            slots.append(
                {
                    "item_index": len(slots) + 1,
                    "phase": phase,
                    "difficulty_tier": tier,
                    "subject_key": subject,
                }
            )
    tier_counts = Counter(int(slot["difficulty_tier"]) for slot in slots)
    subject_counts = Counter(str(slot["subject_key"]) for slot in slots)
    if len(slots) != QUESTION_COUNT or dict(sorted(tier_counts.items())) != {2: 10, 3: 20, 4: 15, 5: 5}:
        raise RuntimeError(f"invalid level-test tier plan: {tier_counts}")
    if dict(subject_counts) != {
        "common_math_1": 12,
        "common_math_2": 13,
        "algebra": 12,
        "calculus_1": 13,
    }:
        raise RuntimeError(f"invalid level-test subject plan: {subject_counts}")
    return slots


def _load_authored_quests() -> dict[str, dict[str, Any]]:
    """필요 변수: 두 수동 저작 카탈로그. 작동 원리: 학생용 계약 검증을 다시 통과한 원본만 메모리에 합쳐 정적 DB 입력으로 사용한다."""
    quests = [
        *validate_initial_catalog(build_initial_catalog()),
        *validate_additional_catalog(build_additional_catalog()),
    ]
    supplemental = build_authored_quest(
        authored_problem(
            3,
            1,
            title=(
                "삼차다항식 $P(x)=x^3+ax^2+bx+6$이 $x-1$과 $x+2$로 "
                "각각 나누어떨어질 때, $a-b$의 값을 구하시오."
            ),
            answer="3",
            tags=["#인수정리", "#미정계수법", "#고차식인수분해"],
            steps=[
                ("$x-1$이 인수이므로 $P(1)=0$을 이용한다.", "$1+a+b+6=0$에서 $a+b=-7$이다."),
                ("$x+2$가 인수이므로 $P(-2)=0$을 이용한다.", "$-8+4a-2b+6=0$에서 $2a-b=1$이다."),
                ("두 일차방정식을 연립하여 계수를 구한다.", "$a+b=-7$, $2a-b=1$을 더하면 $a=-2$, 따라서 $b=-5$이다."),
                ("구한 두 계수의 차를 계산한다.", "$a-b=(-2)-(-5)=3$이다."),
            ],
            alternatives=[
                "세 번째 근을 $r$이라 하면 근의 곱에서 $(1)(-2)r=-6$이므로 $r=3$이고, 인수분해하여 같은 계수를 얻는다."
            ],
        )
    )
    supplemental["header"]["quest_id"] = SUPPLEMENTAL_QUEST_ID
    supplemental["data"]["codebase_id"] = -20_260_799_301
    supplemental["data"]["seed"] = 202_607_149_301
    supplemental["data"]["meta"]["batch_id"] = "level-test-supplement-v1"
    review = review_student_problem_contract(
        supplemental,
        expected_solve_count=4,
        expected_tags=supplemental["info"]["hash_tag"],
    )
    if review["approved"] is not True:
        raise RuntimeError(f"supplemental level-test quest rejected: {review['reasons']}")
    quests.append(supplemental)
    return {str(quest["header"]["quest_id"]): quest for quest in quests}


def _static_quest_id(source_quest_id: str) -> str:
    """필요 변수: 일반 문제은행의 원본 ID. 작동 원리: 별도 저장소임을 증명하는 전용 namespace로 ID를 치환한다."""
    if not source_quest_id.startswith("curated/"):
        raise ValueError(f"unsupported source quest ID: {source_quest_id}")
    return f"{STATIC_QUEST_PREFIX}/{source_quest_id.removeprefix('curated/')}"


def _calibrated_rating(tier: int, source_quest_id: str) -> float:
    """필요 변수: 난이도 티어와 원본 ID. 작동 원리: 안정 해시로 티어 내 다섯 레이팅 지점에 분산해 1000~1675 변별 구간을 만든다."""
    digest = hashlib.sha256(source_quest_id.encode("utf-8")).digest()
    band = RATING_BANDS[tier]
    return float(band[digest[0] % len(band)])


def _prepare_static_quest(
    source: dict[str, Any],
    *,
    source_quest_id: str,
    subject_key: str,
    problem_rating: float,
) -> dict[str, Any]:
    """필요 변수: 검수된 원본·교과·보정 레이팅. 작동 원리: 깊은 복사 후 전용 ID와 고정 레이팅 출처를 명시해 독립 payload를 만든다."""
    quest = copy.deepcopy(source)
    static_id = _static_quest_id(source_quest_id)
    quest["header"]["quest_id"] = static_id
    models = list(((quest["header"].get("quest_model") or {}).get("models") or []))
    quest["header"]["quest_model"] = {
        "models": list(dict.fromkeys(["level-test-static-v1", *models]))
    }
    quest["info"]["placement_rating"] = problem_rating
    quest["info"]["placement_subject_key"] = subject_key
    meta = quest["data"].setdefault("meta", {})
    meta.update(
        {
            "origin": "level_test_static_curated",
            "source_quest_id": source_quest_id,
            "static_version": EXPECTED_TEMPLATE_VERSION,
            "placement_rating": problem_rating,
            "placement_subject_key": subject_key,
        }
    )
    return quest


def build_forms() -> tuple[dict[str, dict[str, Any]], list[dict[str, Any]]]:
    """필요 변수: 검수 문제와 50칸 슬롯 계획. 작동 원리: 다섯 폼마다 중복 없는 문항을 회전 선별하고 공통 문제 payload를 한 번만 준비한다."""
    source_quests = _load_authored_quests()
    all_candidate_ids = [quest_id for values in CANDIDATE_IDS.values() for quest_id in values]
    if len(all_candidate_ids) != len(set(all_candidate_ids)):
        raise RuntimeError("a source quest is assigned to more than one subject group")
    missing = sorted(set(all_candidate_ids) - set(source_quests))
    if missing:
        raise RuntimeError(f"level-test candidates are missing: {missing}")

    slots = build_slot_plan()
    problems: dict[str, dict[str, Any]] = {}
    items: list[dict[str, Any]] = []
    for form_index in range(1, FORM_COUNT + 1):
        template_id = f"{EXPECTED_TEMPLATE_VERSION}-form-{form_index:02d}"
        cursors: defaultdict[tuple[int, str], int] = defaultdict(int)
        form_ids: set[str] = set()
        for slot in slots:
            tier = int(slot["difficulty_tier"])
            subject = str(slot["subject_key"])
            key = (tier, subject)
            candidates = CANDIDATE_IDS.get(key) or []
            if not candidates:
                raise RuntimeError(f"no level-test candidates for {key}")
            candidate_index = ((form_index - 1) * 2 + cursors[key]) % len(candidates)
            source_id = candidates[candidate_index]
            cursors[key] += 1
            static_id = _static_quest_id(source_id)
            if static_id in form_ids:
                raise RuntimeError(f"duplicate quest in {template_id}: {static_id}")
            form_ids.add(static_id)
            rating = _calibrated_rating(tier, source_id)
            if static_id not in problems:
                problems[static_id] = _prepare_static_quest(
                    source_quests[source_id],
                    source_quest_id=source_id,
                    subject_key=subject,
                    problem_rating=rating,
                )
            items.append(
                {
                    "template_id": template_id,
                    **slot,
                    "quest_id": static_id,
                    "problem_rating": rating,
                    "hash_tags": list(problems[static_id]["info"]["hash_tag"]),
                }
            )
        if len(form_ids) != QUESTION_COUNT:
            raise RuntimeError(f"{template_id} does not contain 50 unique quests")
    return problems, items


def _create_schema(connection: sqlite3.Connection) -> None:
    """필요 변수: 새 SQLite 연결. 작동 원리: 정적 문제·폼·슬롯만 가진 최소 스키마와 조회 인덱스를 UTF-8로 생성한다."""
    connection.executescript(
        """
        PRAGMA encoding='UTF-8';
        PRAGMA foreign_keys=ON;
        CREATE TABLE metadata (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );
        CREATE TABLE problem (
            quest_id TEXT PRIMARY KEY,
            source_quest_id TEXT NOT NULL UNIQUE,
            subject_key TEXT NOT NULL,
            difficulty_tier INTEGER NOT NULL CHECK(difficulty_tier BETWEEN 2 AND 5),
            problem_rating REAL NOT NULL CHECK(problem_rating BETWEEN 900 AND 1700),
            payload_json TEXT NOT NULL,
            content_sha256 TEXT NOT NULL,
            active INTEGER NOT NULL DEFAULT 1 CHECK(active IN (0, 1))
        );
        CREATE TABLE template (
            template_id TEXT PRIMARY KEY,
            version TEXT NOT NULL,
            form_index INTEGER NOT NULL UNIQUE,
            active INTEGER NOT NULL DEFAULT 1 CHECK(active IN (0, 1)),
            created_at TEXT NOT NULL
        );
        CREATE TABLE template_item (
            template_id TEXT NOT NULL REFERENCES template(template_id),
            item_index INTEGER NOT NULL CHECK(item_index BETWEEN 1 AND 50),
            phase INTEGER NOT NULL CHECK(phase BETWEEN 1 AND 3),
            subject_key TEXT NOT NULL,
            hash_tags_json TEXT NOT NULL,
            difficulty_tier INTEGER NOT NULL CHECK(difficulty_tier BETWEEN 2 AND 5),
            quest_id TEXT NOT NULL REFERENCES problem(quest_id),
            problem_rating REAL NOT NULL CHECK(problem_rating BETWEEN 900 AND 1700),
            PRIMARY KEY(template_id, item_index),
            UNIQUE(template_id, quest_id)
        );
        CREATE INDEX problem_tier_subject_idx
        ON problem(difficulty_tier, subject_key, active);
        CREATE INDEX template_item_quest_idx
        ON template_item(quest_id);
        """
    )


def seed_static_database(db_path: Path) -> dict[str, Any]:
    """필요 변수: 출력 DB 경로. 작동 원리: 임시 DB에 전체 내용을 검증·커밋한 뒤 원자 교체해 부분 파일 노출을 막는다."""
    target = db_path.resolve()
    target.parent.mkdir(parents=True, exist_ok=True)
    temp_path = target.with_name(f"{target.name}.tmp")
    if temp_path.exists():
        temp_path.unlink()
    problems, items = build_forms()
    source_subjects = {
        source_id: subject
        for (tier, subject), source_ids in CANDIDATE_IDS.items()
        for source_id in source_ids
    }
    # Windows에서도 교체 직전에 파일 핸들이 확실히 해제되도록 연결을 명시적으로 닫는다.
    with closing(sqlite3.connect(temp_path)) as connection:
        _create_schema(connection)
        connection.executemany(
            "INSERT INTO metadata(key, value) VALUES (?, ?)",
            (
                ("schema_version", EXPECTED_SCHEMA_VERSION),
                ("template_version", EXPECTED_TEMPLATE_VERSION),
                ("encoding", "UTF-8"),
                ("description", "직접 검수한 레이팅 추정용 수학 레벨테스트 정적 DB"),
            ),
        )
        for form_index in range(1, FORM_COUNT + 1):
            connection.execute(
                "INSERT INTO template(template_id, version, form_index, active, created_at) VALUES (?, ?, ?, 1, ?)",
                (
                    f"{EXPECTED_TEMPLATE_VERSION}-form-{form_index:02d}",
                    EXPECTED_TEMPLATE_VERSION,
                    form_index,
                    CREATED_AT,
                ),
            )
        for quest_id, quest in sorted(problems.items()):
            source_id = str(quest["data"]["meta"]["source_quest_id"])
            payload_json = json.dumps(quest, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
            connection.execute(
                """
                INSERT INTO problem(
                    quest_id, source_quest_id, subject_key, difficulty_tier,
                    problem_rating, payload_json, content_sha256, active
                ) VALUES (?, ?, ?, ?, ?, ?, ?, 1)
                """,
                (
                    quest_id,
                    source_id,
                    source_subjects[source_id],
                    int(quest["info"]["difficulty_tier"]),
                    float(quest["info"]["placement_rating"]),
                    payload_json,
                    hashlib.sha256(payload_json.encode("utf-8")).hexdigest(),
                ),
            )
        connection.executemany(
            """
            INSERT INTO template_item(
                template_id, item_index, phase, subject_key, hash_tags_json,
                difficulty_tier, quest_id, problem_rating
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    item["template_id"],
                    item["item_index"],
                    item["phase"],
                    item["subject_key"],
                    json.dumps(item["hash_tags"], ensure_ascii=False, separators=(",", ":")),
                    item["difficulty_tier"],
                    item["quest_id"],
                    item["problem_rating"],
                )
                for item in items
            ],
        )
        foreign_keys = list(connection.execute("PRAGMA foreign_key_check"))
        integrity = str(connection.execute("PRAGMA integrity_check").fetchone()[0])
        if foreign_keys or integrity != "ok":
            raise RuntimeError(
                f"static DB verification failed: integrity={integrity}, foreign_keys={foreign_keys}"
            )
        connection.commit()
    os.replace(temp_path, target)
    os.environ["LEVEL_TEST_STATIC_DB_PATH"] = str(target)
    clear_static_cache()
    report = validate_static_database()
    report["form_item_count"] = len(items)
    report["subject_counts_per_form"] = {
        subject: sum(
            1
            for item in items
            if item["template_id"].endswith("form-01") and item["subject_key"] == subject
        )
        for subject in SUBJECT_KEYS
    }
    report["rating_range"] = [
        min(float(item["problem_rating"]) for item in items),
        max(float(item["problem_rating"]) for item in items),
    ]
    return report


def main() -> None:
    """필요 변수: 선택적 출력 경로. 작동 원리: 전용 DB를 결정적으로 다시 만들고 UTF-8 JSON 검증 보고서를 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=DEFAULT_STATIC_DB_PATH)
    args = parser.parse_args()
    print(json.dumps(seed_static_database(args.db), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
