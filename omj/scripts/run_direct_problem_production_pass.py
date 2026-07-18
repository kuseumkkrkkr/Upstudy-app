from __future__ import annotations

import argparse
import importlib
import json
import os
import sqlite3
import sys
from pathlib import Path
from typing import Any, Callable

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.audit_direct_problem_catalog import audit_catalog

LATEST_VERSION = 59
QUEST_PREFIX = "curated/marketplace-original-v"


def _seed_function(version: int) -> Callable[..., dict[str, Any]]:
    """필요 변수는 직접 저작 배치 버전이다. 작동 원리는 v1의 기본 모듈명과 v2 이후 접미사 모듈명을 구분해 시드 함수를 불러온다."""
    module_name = "scripts.seed_marketplace_original_problems"
    if version > 1:
        module_name = f"{module_name}_v{version}"
    module = importlib.import_module(module_name)
    seed_database = getattr(module, "seed_database", None)
    if not callable(seed_database):
        raise RuntimeError(f"직접 저작 배치 시드 함수 누락: {module_name}")
    return seed_database


def _approved_problem_ids(db_path: Path) -> list[str]:
    """필요 변수는 로컬 문제 DB다. 작동 원리는 승인된 직접 저작 문제 ID만 정렬해 운영 동기화 대상을 고정한다."""
    with sqlite3.connect(db_path) as connection:
        return [
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


def _sync_postgres(db_path: Path, problem_ids: list[str]) -> int:
    """필요 변수는 로컬 DB와 승인 문제 ID다. 작동 원리는 상품 원장을 거치지 않고 검증된 문제 payload만 운영 PostgreSQL에 엄격 UPSERT한다."""
    os.environ["QUEST_DB_PATH"] = str(db_path)
    from storage import storage as quest_storage
    from storage.postgres_problem_store import postgres_problem_store

    quest_storage.DB_PATH = str(db_path)
    quests = quest_storage.get_quests_by_ids(problem_ids)
    if len(quests) != len(problem_ids):
        raise RuntimeError(f"운영 동기화 원본 문제 누락: {len(quests)}/{len(problem_ids)}")
    for quest in quests:
        postgres_problem_store.upsert_problem(quest, strict=True)
    return len(quests)


def run_direct_problem_pass(
    db_path: Path,
    *,
    latest_version: int,
    sync_postgres: bool,
    validate_only: bool,
) -> dict[str, Any]:
    """필요 변수는 DB·최신 버전·운영 동기화·검증 모드다. 작동 원리는 문제 배치만 멱등 실행하고 저장 시 전수 감사까지 수행한다."""
    resolved = db_path.resolve()
    batches = [
        _seed_function(version)(resolved, validate_only=validate_only)
        for version in range(1, latest_version + 1)
    ]
    report: dict[str, Any] = {
        "latest_version": latest_version,
        "problem_batches": batches,
        "inventory_touched": False,
    }
    if validate_only:
        return report
    problem_ids = _approved_problem_ids(resolved)
    report["approved_problem_ids"] = len(problem_ids)
    if sync_postgres:
        report["postgres_problems_upserted"] = _sync_postgres(resolved, problem_ids)
    report["audit"] = audit_catalog(
        resolved,
        version=latest_version,
        check_postgres=sync_postgres,
    )
    return report


def main() -> None:
    """필요 변수는 DB 경로·최신 버전·동기화·검증 옵션이다. 작동 원리는 상품과 분리된 문제 생산 결과를 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--latest-version", type=int, default=LATEST_VERSION)
    parser.add_argument("--sync-postgres", action="store_true")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    report = run_direct_problem_pass(
        args.db,
        latest_version=args.latest_version,
        sync_postgres=args.sync_postgres,
        validate_only=args.validate_only,
    )
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
