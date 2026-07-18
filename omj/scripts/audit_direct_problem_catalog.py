from __future__ import annotations

import argparse
import json
import os
import re
import sqlite3
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from difficulty_contract import DIFFICULTY_CONTRACTS
from generater.fix_gen import allowed_generation_tags
from scripts.seed_initial_math_problems import _content_text
from student_problem_content_review import review_student_problem_contract

QUEST_PREFIX = "curated/marketplace-original-v"


def _expected_counts(version: int) -> tuple[int, dict[int, int]]:
    """필요 변수는 마지막 직접 저작 배치 버전이다. 작동 원리는 v1·v2의 40문항과 이후 배치별 50문항 계약에서 누적 수량을 계산한다."""
    if version < 2:
        raise ValueError("직접 저작 전수 감사는 v2 이상에서 지원합니다.")
    return 50 * version - 20, {
        1: 10 * version,
        2: 10 * version,
        3: 10 * version,
        4: 10 * version - 10,
        5: 10 * version - 10,
    }


def _title_signature(title: Any) -> str:
    """필요 변수는 문제 제목 블록이다. 작동 원리는 숫자와 공백 차이를 제거해 배치 간 동일 문장형 문제를 탐지한다."""
    normalized = _content_text(title).lower()
    normalized = re.sub(r"-?\d+(?:\.\d+)?", "{n}", normalized)
    normalized = re.sub(r"\s+", " ", normalized)
    return normalized.strip()


def _batch_version(quest_id: str) -> int:
    """필요 변수는 직접 저작 문제 ID다. 작동 원리는 ID 안의 v숫자를 읽어 최신 배치와 과거 배치를 구분한다."""
    match = re.search(r"marketplace-original-v(\d+)/", quest_id)
    return int(match.group(1)) if match else 0


def _answer_is_explained(quest: dict[str, Any]) -> bool:
    """필요 변수는 정답과 본 풀이가 있는 문제 payload다. 작동 원리는 최종 본 풀이에 저장 정답이 실제 수식으로 등장하는지 확인한다."""
    answer = _content_text((quest.get("data") or {}).get("quest_answer")).replace(" ", "")
    solves = quest.get("solves") or []
    if not answer or not solves:
        return False
    final_explanation = _content_text((solves[-1] or {}).get("answer_riddle")).replace(" ", "")
    return answer in final_explanation


def _load_local_quests(db_path: Path) -> list[dict[str, Any]]:
    """필요 변수는 로컬 문제 DB다. 작동 원리는 승인된 직접 저작 ID를 한 번 읽고 저장 계층으로 전체 payload를 복원한다."""
    with sqlite3.connect(db_path) as connection:
        quest_ids = [
            str(row[0])
            for row in connection.execute(
                """
                SELECT h.quest_id
                FROM quest_header h
                JOIN quest_info i ON i.quest_id = h.quest_id
                WHERE h.quest_id LIKE ? AND i.quality_status = 'approved'
                ORDER BY h.quest_id
                """,
                (f"{QUEST_PREFIX}%",),
            ).fetchall()
        ]
    os.environ["QUEST_DB_PATH"] = str(db_path)
    from storage import storage as quest_storage

    quest_storage.DB_PATH = str(db_path)
    quests = quest_storage.get_quests_by_ids(quest_ids)
    if len(quests) != len(quest_ids):
        raise RuntimeError(f"로컬 문제 payload 재조회 누락: {len(quests)}/{len(quest_ids)}")
    return quests


def _audit_local(quests: list[dict[str, Any]], *, version: int) -> dict[str, Any]:
    """필요 변수는 전체 직접 저작 payload와 최신 버전이다. 작동 원리는 실행 식별자·풀이 계약·태그·제목 다양성을 전수 검사한다."""
    expected_total, expected_tiers = _expected_counts(version)
    ids: list[str] = []
    titles: list[str] = []
    codebase_ids: list[int] = []
    seeds: list[int] = []
    tier_counts: Counter[int] = Counter()
    tag_counts: Counter[str] = Counter()
    rejected: list[dict[str, Any]] = []
    unexplained_answers: list[str] = []
    signature_rows: dict[str, list[tuple[str, str]]] = defaultdict(list)
    for quest in quests:
        header = quest.get("header") or {}
        info = quest.get("info") or {}
        data = quest.get("data") or {}
        quest_id = str(header.get("quest_id") or "")
        tier = int(info.get("difficulty_tier") or 0)
        ids.append(quest_id)
        title = _content_text(data.get("quest_title"))
        titles.append(title)
        codebase_ids.append(int(data.get("codebase_id")))
        seeds.append(int(data.get("seed")))
        tier_counts[tier] += 1
        for tag in info.get("hash_tag") or []:
            tag_counts[str(tag).strip().lstrip("#")] += 1
        signature_rows[_title_signature(data.get("quest_title"))].append((quest_id, title))
        contract = DIFFICULTY_CONTRACTS[tier]
        review = review_student_problem_contract(
            quest,
            expected_solve_count=contract.solves_count,
            expected_tags=info.get("hash_tag") or [],
        )
        if review.get("approved") is not True:
            rejected.append({"quest_id": quest_id, "reasons": review.get("reasons") or []})
        if not _answer_is_explained(quest):
            unexplained_answers.append(quest_id)

    allowed = {str(tag).strip().lstrip("#") for tag in allowed_generation_tags()}
    invalid_tags = sorted(set(tag_counts) - allowed)
    unused_tags = sorted(allowed - set(tag_counts))
    least_used = sorted(
        ({"tag": tag, "count": tag_counts.get(tag, 0)} for tag in allowed),
        key=lambda item: (int(item["count"]), str(item["tag"])),
    )[:80]
    cross_batch_groups = []
    latest_overlaps = []
    for rows in signature_rows.values():
        versions = {_batch_version(quest_id) for quest_id, _title in rows}
        if len(versions) <= 1:
            continue
        group = {
            "versions": sorted(versions),
            "count": len(rows),
            "sample_titles": [title for _quest_id, title in rows[:3]],
        }
        cross_batch_groups.append(group)
        if version in versions:
            latest_overlaps.append(group)

    failures = {
        "total_mismatch": len(quests) != expected_total,
        "tier_mismatch": dict(sorted(tier_counts.items())) != expected_tiers,
        "duplicate_ids": len(ids) - len(set(ids)),
        "duplicate_titles": len(titles) - len(set(titles)),
        "duplicate_codebase_ids": len(codebase_ids) - len(set(codebase_ids)),
        "duplicate_seeds": len(seeds) - len(set(seeds)),
        "non_negative_codebase_ids": sum(value >= 0 for value in codebase_ids),
        "non_positive_seeds": sum(value <= 0 for value in seeds),
        "content_rejections": len(rejected),
        "answers_missing_from_final_explanation": len(unexplained_answers),
        "invalid_tags": len(invalid_tags),
        "latest_template_overlaps": len(latest_overlaps),
    }
    if any(bool(value) for value in failures.values()):
        raise RuntimeError(json.dumps({"failures": failures, "rejected": rejected[:5], "unexplained": unexplained_answers[:5], "invalid_tags": invalid_tags, "latest_overlaps": latest_overlaps[:5]}, ensure_ascii=False))
    return {
        "problems": len(quests),
        "tier_counts": dict(sorted(tier_counts.items())),
        "unique_codebase_ids": len(set(codebase_ids)),
        "unique_seeds": len(set(seeds)),
        "distinct_used_tags": len(tag_counts),
        "allowed_tags": len(allowed),
        "unused_allowed_tags": len(unused_tags),
        "least_used_tags": least_used,
        "cross_batch_template_groups": len(cross_batch_groups),
        "latest_template_overlaps": len(latest_overlaps),
        "checks": failures,
    }


def _audit_postgres(quests: list[dict[str, Any]]) -> dict[str, Any]:
    """필요 변수는 로컬에서 승인된 전체 직접 저작 payload다. 작동 원리는 운영 problem_payload의 ID·티어·식별자를 읽어 로컬과 대칭 비교한다."""
    from storage.postgres_problem_store import postgres_problem_store

    pool = postgres_problem_store.get_pool()
    with pool.connection() as connection, connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT quest_id, difficulty_tier, codebase_id, seed
            FROM problem_payload
            WHERE quest_id LIKE %s AND quality_status = 'approved'
            ORDER BY quest_id
            """,
            (f"{QUEST_PREFIX}%",),
        )
        rows = cursor.fetchall()
    local_rows = {
        str((quest.get("header") or {}).get("quest_id") or ""): (
            int((quest.get("info") or {}).get("difficulty_tier") or 0),
            int((quest.get("data") or {}).get("codebase_id")),
            int((quest.get("data") or {}).get("seed")),
        )
        for quest in quests
    }
    postgres_rows = {str(row[0]): (int(row[1]), int(row[2]), int(row[3])) for row in rows}
    symmetric_difference = sorted(set(local_rows) ^ set(postgres_rows))
    payload_mismatches = sorted(
        quest_id
        for quest_id in set(local_rows) & set(postgres_rows)
        if local_rows[quest_id] != postgres_rows[quest_id]
    )
    if symmetric_difference or payload_mismatches:
        raise RuntimeError(
            f"운영 문제 원장 불일치: id={symmetric_difference[:5]} payload={payload_mismatches[:5]}"
        )
    return {
        "problems": len(postgres_rows),
        "id_symmetric_difference": 0,
        "tier_codebase_seed_mismatches": 0,
    }


def audit_catalog(db_path: Path, *, version: int, check_postgres: bool) -> dict[str, Any]:
    """필요 변수는 문제 DB·최신 버전·운영 감사 여부다. 작동 원리는 로컬 전수 검사 후 필요할 때 PostgreSQL 원장까지 대조한다."""
    resolved = db_path.resolve()
    quests = _load_local_quests(resolved)
    report: dict[str, Any] = {
        "version": version,
        "db_path": str(resolved),
        "local": _audit_local(quests, version=version),
    }
    if check_postgres:
        report["postgres"] = _audit_postgres(quests)
    return report


def main() -> None:
    """필요 변수는 DB 경로·최신 버전·운영 검사 옵션이다. 작동 원리는 문제 다양성과 실행 타당성 감사 결과를 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--version", type=int, required=True)
    parser.add_argument("--check-postgres", action="store_true")
    args = parser.parse_args()
    print(json.dumps(audit_catalog(args.db, version=args.version, check_postgres=args.check_postgres), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
