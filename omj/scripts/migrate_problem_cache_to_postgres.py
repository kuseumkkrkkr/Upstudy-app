"""SQLite 문제 payload를 PostgreSQL problem_payload 테이블로 이관한다."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
from collections import Counter
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from storage import storage as sqlite_store
from storage.postgres_problem_store import postgres_problem_store


def apply_schema_migrations() -> list[str]:
    """필요 변수: DATABASE_URL과 PostgreSQL SQL 파일. 작동 원리: 번호순 UTF-8 마이그레이션을 한 연결에서 적용하고 실패 시 전체 트랜잭션을 되돌린다."""
    database_url = os.getenv("DATABASE_URL", "").strip()
    if not database_url:
        raise RuntimeError("DATABASE_URL is required for schema migration")
    import psycopg

    migration_dir = ROOT / "migrations" / "postgres"
    files = sorted(migration_dir.glob("*.sql"))
    if not files:
        raise RuntimeError(f"PostgreSQL migration files not found: {migration_dir}")
    with psycopg.connect(database_url) as connection:
        with connection.cursor() as cursor:
            for path in files:
                cursor.execute(path.read_text(encoding="utf-8"))
        connection.commit()
    return [path.name for path in files]


def _quest_ids() -> list[str]:
    """필요 변수: SQLite 문제 DB. 작동 원리: 이관 대상 quest_id만 먼저 읽어 메모리를 일정하게 유지한다."""
    conn = sqlite_store._connect()
    try:
        rows = conn.execute(
            """
            SELECT h.quest_id
            FROM quest_header h JOIN quest_info i ON i.quest_id=h.quest_id
            WHERE i.quality_status='approved'
            ORDER BY h.quest_id ASC
            """
        ).fetchall()
        return [str(row[0]) for row in rows]
    finally:
        conn.close()


def _problem_history() -> list[tuple[str, int, str, list[str]]]:
    """필요 변수: SQLite user_habit·solve_history 행. 작동 원리: 직접 기록과 quest_id 기반 과거 풀이를 variant로 복원해 중복 제외 이력으로 옮긴다."""
    conn = sqlite_store._connect()
    try:
        try:
            habit_rows = conn.execute(
                """SELECT user_id, codebase_id, seed, tags
                FROM user_habit
                WHERE kind = 'problem' AND codebase_id IS NOT NULL AND seed IS NOT NULL"""
            ).fetchall()
            solve_rows = conn.execute(
                """
                SELECT sh.user_id, qd.codebase_id, qd.seed, qi.hash_tag
                FROM solve_history sh
                JOIN quest_data qd ON qd.quest_id=sh.quest_id
                JOIN quest_info qi ON qi.quest_id=sh.quest_id
                WHERE sh.kind='problem'
                  AND qd.codebase_id IS NOT NULL AND qd.seed IS NOT NULL
                """
            ).fetchall()
        except Exception:
            habit_rows = []
            solve_rows = []
    finally:
        conn.close()
    deduplicated: dict[tuple[str, int, str], list[str]] = {}
    for user_id, codebase_id, seed, raw_tags in [*habit_rows, *solve_rows]:
        try:
            tags = json.loads(raw_tags) if raw_tags else []
        except json.JSONDecodeError:
            tags = []
        key = (str(user_id), int(codebase_id), str(seed))
        deduplicated[key] = tags if isinstance(tags, list) else []
    return [(*key, tags) for key, tags in sorted(deduplicated.items())]


def _source_snapshot() -> dict[str, tuple[int, int]]:
    """필요 변수: 승인 SQLite 문제. 작동 원리: 전환 대상의 ID·티어·계산 점수를 전 행 기준값으로 만든다."""
    conn = sqlite_store._connect()
    try:
        rows = conn.execute(
            """
            SELECT quest_id, difficulty_tier, difficulty_score
            FROM quest_info
            WHERE quality_status='approved'
            ORDER BY quest_id
            """
        ).fetchall()
    finally:
        conn.close()
    return {str(row[0]): (int(row[1]), int(row[2])) for row in rows}


def verify_migration() -> dict[str, Any]:
    """필요 변수: SQLite 원본과 PostgreSQL 승인 snapshot. 작동 원리: ID 집합·티어·점수·payload 자체 표식을 전 행 비교해 불완전 전환을 실패시킨다."""
    source = _source_snapshot()
    target = postgres_problem_store.approved_problem_snapshot()
    source_history = {
        (user_id, codebase_id, int(seed))
        for user_id, codebase_id, seed, _tags in _problem_history()
    }
    target_history = postgres_problem_store.problem_history_keys()
    missing_history = sorted(source_history - target_history)
    missing = sorted(set(source) - set(target))
    unexpected = sorted(set(target) - set(source))
    mismatched: list[dict[str, Any]] = []
    for quest_id in sorted(set(source) & set(target)):
        expected_tier, expected_score = source[quest_id]
        tier, score, payload = target[quest_id]
        header = payload.get("header") if isinstance(payload.get("header"), dict) else {}
        info = payload.get("info") if isinstance(payload.get("info"), dict) else {}
        payload_id = str(header.get("quest_id") or "")
        payload_tier = int(info.get("difficulty_tier") or 0)
        payload_score = int(info.get("difficulty_score") or info.get("difficulty") or 0)
        if (
            (tier, score) != (expected_tier, expected_score)
            or payload_id != quest_id
            or payload_tier != expected_tier
            or payload_score != expected_score
        ):
            mismatched.append(
                {
                    "quest_id": quest_id,
                    "expected": [expected_tier, expected_score],
                    "row": [tier, score],
                    "payload": [payload_id, payload_tier, payload_score],
                }
            )
    tier_counts = Counter(tier for tier, _score in source.values())
    source_digest = hashlib.sha256(
        "\n".join(f"{quest_id}|{tier}|{score}" for quest_id, (tier, score) in sorted(source.items())).encode("utf-8")
    ).hexdigest()
    target_digest = hashlib.sha256(
        "\n".join(
            f"{quest_id}|{tier}|{score}"
            for quest_id, (tier, score, _payload) in sorted(target.items())
        ).encode("utf-8")
    ).hexdigest()
    report = {
        "verified": not missing and not unexpected and not mismatched and not missing_history,
        "source_approved": len(source),
        "target_approved": len(target),
        "tier_counts": {str(tier): tier_counts[tier] for tier in sorted(tier_counts)},
        "source_digest": source_digest,
        "target_digest": target_digest,
        "missing_count": len(missing),
        "unexpected_count": len(unexpected),
        "mismatched_count": len(mismatched),
        "source_history": len(source_history),
        "target_history": len(target_history),
        "missing_history_count": len(missing_history),
        "missing_examples": missing[:10],
        "unexpected_examples": unexpected[:10],
        "mismatched_examples": mismatched[:10],
        "missing_history_examples": missing_history[:10],
    }
    if report["verified"] is not True:
        raise RuntimeError(f"PostgreSQL migration verification failed: {json.dumps(report, ensure_ascii=False)}")
    return report


def migrate(*, batch_size: int, apply: bool) -> dict[str, Any]:
    """필요 변수: 배치 수와 실행 승인. 작동 원리: 승인 payload만 이관하고 실제 저장 성공 건만 집계한 뒤 전 행 대조한다."""
    if apply and not os.getenv("DATABASE_URL", "").strip():
        raise RuntimeError("DATABASE_URL is required for --apply")
    migrated = 0
    skipped = 0
    history_migrated = 0
    ids = _quest_ids()
    for start in range(0, len(ids), batch_size):
        quests = sqlite_store.get_quests_by_ids(ids[start : start + batch_size])
        for quest in quests:
            if not apply:
                skipped += 1
                continue
            if postgres_problem_store.upsert_problem(quest, strict=True):
                migrated += 1
    history = _problem_history()
    for user_id, codebase_id, seed, tags in history:
        if not apply:
            continue
        postgres_problem_store.record_problem_solve(
            user_id=user_id,
            codebase_id=codebase_id,
            seed=seed,
            tags=tags,
            strict=True,
        )
        history_migrated += 1
    report: dict[str, Any] = {
        "apply": apply,
        "payload_targets": len(ids),
        "payload_migrated": migrated,
        "payload_skipped": skipped,
        "history_targets": len(history),
        "history_migrated": history_migrated,
    }
    if apply:
        verification = verify_migration()
        postgres_problem_store.record_migration_audit(verification)
        report["verification"] = verification
    return report


def main() -> None:
    """필요 변수: CLI 인자. 작동 원리: 기본 dry-run으로 대상 수를 확인하고 --apply에서만 실제 데이터를 쓴다."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--batch-size", type=int, default=100)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--apply", action="store_true")
    mode.add_argument("--verify-only", action="store_true")
    parser.add_argument("--apply-schema", action="store_true")
    args = parser.parse_args()
    if args.apply_schema and not args.apply:
        parser.error("--apply-schema는 --apply와 함께 사용해야 합니다.")
    schema_files = apply_schema_migrations() if args.apply_schema else []
    if args.verify_only:
        if not os.getenv("DATABASE_URL", "").strip():
            raise RuntimeError("DATABASE_URL is required for --verify-only")
        verification = verify_migration()
        postgres_problem_store.record_migration_audit(verification)
        report = {"verification": verification}
    else:
        report = migrate(batch_size=max(1, args.batch_size), apply=args.apply)
    if schema_files:
        report["schema_migrations"] = schema_files
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
