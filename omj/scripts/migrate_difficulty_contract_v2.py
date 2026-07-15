from __future__ import annotations

import argparse
import json
import sqlite3
import sys
import time
from datetime import datetime
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from difficulty_contract import DIFFICULTY_CONTRACTS, infer_tier_from_contract
from scripts.audit_problem_data import (
    _connect_readonly,
    _load_codebases,
    _normalized_tags,
    _parse_json,
    _quest_from_row,
)
from student_problem_content_review import content_text, review_student_problem_content


MIGRATION_VERSION = "difficulty-contract-v2"


def _clone_sqlite(source: Path, target: Path) -> None:
    """필요 변수: 원본·대상 SQLite 경로. 작동 원리: WAL 상태까지 일관된 SQLite backup API로 복제본을 만든다."""
    source_connection = _connect_readonly(source)
    target.parent.mkdir(parents=True, exist_ok=True)
    target_connection = sqlite3.connect(target)
    try:
        source_connection.backup(target_connection)
    finally:
        target_connection.close()
        source_connection.close()


def _backup_pair(quest_db: Path, codebase_db: Path, backup_dir: Path) -> dict[str, Path]:
    """필요 변수: 원본 문제·코드베이스 DB와 백업 폴더. 작동 원리: 동일 실행 식별자로 두 DB의 일관된 SQLite 백업을 만든다."""
    run_id = datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    backup_dir.mkdir(parents=True, exist_ok=True)
    backups = {
        "quests": backup_dir / f"quests-{run_id}.db",
        "codebases": backup_dir / f"codebases-{run_id}.db",
    }
    _clone_sqlite(quest_db, backups["quests"])
    _clone_sqlite(codebase_db, backups["codebases"])
    return backups


def _restore_pair(backups: dict[str, Path], quest_db: Path, codebase_db: Path) -> None:
    """필요 변수: 두 백업 경로와 복원 대상. 작동 원리: 부분 마이그레이션 실패 시 두 원본을 같은 백업 세트로 되돌린다."""
    _clone_sqlite(backups["quests"], quest_db)
    _clone_sqlite(backups["codebases"], codebase_db)


def _ensure_column(cursor: sqlite3.Cursor, table: str, column: str, definition: str) -> None:
    """필요 변수: 테이블·칼럼·정의. 작동 원리: 재실행 가능한 방식으로 누락 칼럼만 추가한다."""
    columns = {str(row[1]) for row in cursor.execute(f"PRAGMA table_info({table})")}
    if column not in columns:
        cursor.execute(f"ALTER TABLE {table} ADD COLUMN {column} {definition}")


def _resolve_tier(codebase: dict[str, Any] | None, row: sqlite3.Row) -> tuple[int, str]:
    """필요 변수: 선택적 코드베이스와 문제 계약 행. 작동 원리: 코드베이스 명시값·구조·문제 구조 순으로 모든 문제 티어를 복원한다."""
    if codebase:
        explicit = codebase.get("explicit_tier")
        if isinstance(explicit, int) and 1 <= explicit <= 5:
            source = str(codebase.get("tier_source") or "explicit")
            return explicit, f"codebase_{source}"
        tier, source = infer_tier_from_contract(
            codebase.get("solves_count"),
            codebase.get("strategy_level"),
            codebase.get("branch_conditions"),
        )
        return tier, f"codebase_{source}"
    tier, source = infer_tier_from_contract(row["flow_rate"], row["main_huddle"], None)
    return tier, f"quest_{source}"


def migrate_quest_database(quest_db: Path, codebase_db: Path) -> dict[str, Any]:
    """필요 변수: 복제 문제 DB와 코드베이스 DB. 작동 원리: 점수 보존, 티어 백필, 품질 격리와 인덱스를 한 트랜잭션에 적용한다."""
    codebases = _load_codebases(codebase_db)
    connection = sqlite3.connect(quest_db)
    connection.row_factory = sqlite3.Row
    cursor = connection.cursor()
    try:
        _ensure_column(cursor, "quest_info", "difficulty_tier", "INTEGER")
        _ensure_column(cursor, "quest_info", "difficulty_score", "INTEGER")
        _ensure_column(cursor, "quest_info", "tier_source", "TEXT")
        _ensure_column(cursor, "quest_info", "quality_status", "TEXT NOT NULL DEFAULT 'pending'")
        _ensure_column(cursor, "quest_info", "quality_reasons", "TEXT NOT NULL DEFAULT '[]'")
        _ensure_column(cursor, "quest_info", "quality_checked_at", "INTEGER")

        rows = cursor.execute(
            """
            SELECT i.quest_id, i.difficulty, i.flow_rate, i.main_huddle,
                   i.hash_tag AS info_tags, d.quest_title, d.quest_answer,
                   d.codebase_id, d.seed, d.hash_tag AS data_tags
            FROM quest_info i JOIN quest_data d ON d.quest_id=i.quest_id
            ORDER BY i.quest_id
            """
        ).fetchall()
        solves_by_quest: dict[str, list[sqlite3.Row]] = defaultdict(list)
        for solve in cursor.execute(
            """
            SELECT quest_id, flow, hint_riddle, answer_riddle, branches
            FROM solve_step ORDER BY quest_id, id
            """
        ):
            solves_by_quest[str(solve["quest_id"])].append(solve)

        status_counts: Counter[str] = Counter()
        tier_counts: Counter[str] = Counter()
        reason_counts: Counter[str] = Counter()
        source_counts: Counter[str] = Counter()
        updates = []
        checked_at = int(time.time())
        for row in rows:
            quest_id = str(row["quest_id"])
            codebase_id = row["codebase_id"]
            codebase = codebases.get(int(codebase_id)) if codebase_id is not None else None
            tier, tier_source = _resolve_tier(codebase, row)
            quest = _quest_from_row(row, solves_by_quest.get(quest_id, []))
            review = review_student_problem_content(quest)
            reasons = [str(reason) for reason in review["reasons"]]

            quest_tags = set(_normalized_tags(row["info_tags"], row["data_tags"]))
            if codebase is None:
                reasons.append("missing_codebase_reference")
            else:
                codebase_tags = set(codebase.get("tags") or [])
                if not quest_tags.issubset(codebase_tags):
                    reasons.append("quest_tags_outside_codebase")
                if len(quest.get("solves") or []) != int(codebase.get("solves_count") or 0):
                    reasons.append("solve_count_vs_codebase")

            reasons = list(dict.fromkeys(reasons))
            content_failure = bool(review["reasons"])
            status = "rejected" if content_failure else ("quarantined" if reasons else "approved")
            score = max(1, int(row["difficulty"] or 1))
            updates.append(
                (
                    tier,
                    score,
                    tier_source,
                    status,
                    json.dumps(reasons, ensure_ascii=False),
                    checked_at,
                    quest_id,
                )
            )
            status_counts[status] += 1
            tier_counts[str(tier)] += 1
            source_counts[tier_source] += 1
            reason_counts.update(reasons)

        cursor.executemany(
            """
            UPDATE quest_info
            SET difficulty_tier=?, difficulty_score=?, tier_source=?,
                quality_status=?, quality_reasons=?, quality_checked_at=?
            WHERE quest_id=?
            """,
            updates,
        )
        cursor.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_quest_info_tier_quality
            ON quest_info(difficulty_tier, quality_status, quest_id)
            """
        )
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS schema_migration_audit (
                version TEXT PRIMARY KEY,
                applied_at INTEGER NOT NULL,
                summary_json TEXT NOT NULL
            )
            """
        )
        summary = {
            "version": MIGRATION_VERSION,
            "rows": len(rows),
            "status_counts": dict(sorted(status_counts.items())),
            "tier_counts": dict(sorted(tier_counts.items())),
            "tier_source_counts": dict(sorted(source_counts.items())),
            "reason_counts": dict(sorted(reason_counts.items())),
        }
        cursor.execute(
            """
            INSERT INTO schema_migration_audit(version, applied_at, summary_json)
            VALUES (?, ?, ?)
            ON CONFLICT(version) DO UPDATE SET
                applied_at=excluded.applied_at,
                summary_json=excluded.summary_json
            """,
            (MIGRATION_VERSION, checked_at, json.dumps(summary, ensure_ascii=False)),
        )
        connection.commit()

        verified = cursor.execute(
            """
            SELECT COUNT(*) AS total,
                   SUM(CASE WHEN difficulty_tier BETWEEN 1 AND 5 THEN 1 ELSE 0 END) AS tiered,
                   SUM(CASE WHEN difficulty_score = difficulty THEN 1 ELSE 0 END) AS score_preserved,
                   SUM(CASE WHEN quality_status IN ('approved','quarantined','rejected') THEN 1 ELSE 0 END) AS reviewed
            FROM quest_info
            """
        ).fetchone()
        summary["verification"] = dict(verified)
        return summary
    except Exception:
        connection.rollback()
        raise
    finally:
        connection.close()


def migrate_codebase_database(codebase_db: Path) -> dict[str, Any]:
    """필요 변수: 복제 코드베이스 DB. 작동 원리: 명시되지 않은 티어를 구조 계약으로 백필하고 생성 검증 대기 상태를 기록한다."""
    connection = sqlite3.connect(codebase_db)
    connection.row_factory = sqlite3.Row
    cursor = connection.cursor()
    try:
        _ensure_column(cursor, "codebases", "tier_source", "TEXT")
        _ensure_column(cursor, "codebases", "quality_status", "TEXT NOT NULL DEFAULT 'pending'")
        _ensure_column(cursor, "codebases", "quality_reasons", "TEXT NOT NULL DEFAULT '[]'")
        rows = cursor.execute(
            """
            SELECT id, tier, solves_count, strategy_level, branch_conditions,
                   tier_source,
                   quality_status, quality_reasons
            FROM codebases ORDER BY id
            """
        ).fetchall()
        tier_counts: Counter[str] = Counter()
        source_counts: Counter[str] = Counter()
        updates = []
        for row in rows:
            explicit = row["tier"]
            if isinstance(explicit, int) and 1 <= explicit <= 5:
                contract = DIFFICULTY_CONTRACTS[explicit]
                if (
                    int(row["solves_count"] or 0) == contract.solves_count
                    and int(row["strategy_level"] or 0) == contract.strategy_level
                    and int(row["branch_conditions"] or 0) == contract.branch_conditions
                ):
                    tier, source = explicit, "explicit"
                else:
                    tier, contract_source = infer_tier_from_contract(
                        row["solves_count"], row["strategy_level"], row["branch_conditions"]
                    )
                    source = f"explicit_conflict_{contract_source}"
            else:
                tier, contract_source = infer_tier_from_contract(
                    row["solves_count"], row["strategy_level"], row["branch_conditions"]
                )
                source = contract_source
            previous_source = str(row["tier_source"] or "").strip()
            if previous_source and isinstance(explicit, int) and explicit == tier:
                source = previous_source
            previous_status = str(row["quality_status"] or "")
            if previous_status in {"approved", "quarantined"}:
                quality_status = previous_status
                quality_reasons = str(row["quality_reasons"] or "[]")
            else:
                quality_status = "pending_validation"
                quality_reasons = "[]"
            updates.append((tier, source, quality_status, quality_reasons, row["id"]))
            tier_counts[str(tier)] += 1
            source_counts[source] += 1
        cursor.executemany(
            """
            UPDATE codebases
            SET tier=?, tier_source=?, quality_status=?, quality_reasons=?
            WHERE id=?
            """,
            updates,
        )
        cursor.execute(
            "CREATE INDEX IF NOT EXISTS idx_codebases_tier_quality ON codebases(tier, quality_status, id)"
        )
        connection.commit()
        return {
            "rows": len(rows),
            "tier_counts": dict(sorted(tier_counts.items())),
            "source_counts": dict(sorted(source_counts.items())),
        }
    except Exception:
        connection.rollback()
        raise
    finally:
        connection.close()


def main() -> None:
    """필요 변수: 원본·선택적 복제 대상·백업 경로. 작동 원리: 리허설 또는 자동 백업이 포함된 원본 마이그레이션을 실행한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--quest-source", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--codebase-source", type=Path, default=ROOT / "codebases.db")
    parser.add_argument("--quest-target", type=Path)
    parser.add_argument("--codebase-target", type=Path)
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--apply-in-place", action="store_true")
    parser.add_argument("--backup-dir", type=Path, default=ROOT / "data" / "migration_backups")
    args = parser.parse_args()

    if args.apply_in_place:
        if args.quest_target or args.codebase_target:
            parser.error("--apply-in-place에서는 target 옵션을 함께 사용할 수 없습니다.")
        backups = _backup_pair(args.quest_source, args.codebase_source, args.backup_dir)
        try:
            codebase_summary = migrate_codebase_database(args.codebase_source)
            quest_summary = migrate_quest_database(args.quest_source, args.codebase_source)
        except Exception:
            _restore_pair(backups, args.quest_source, args.codebase_source)
            raise
        print(
            json.dumps(
                {
                    "backups": {key: str(path.resolve()) for key, path in backups.items()},
                    "codebases": codebase_summary,
                    "quests": quest_summary,
                },
                ensure_ascii=False,
                indent=2,
            )
        )
        return

    if not args.quest_target or not args.codebase_target:
        parser.error("리허설에는 --quest-target과 --codebase-target이 모두 필요합니다.")
    for target in (args.quest_target, args.codebase_target):
        if target.exists() and not args.overwrite:
            raise FileExistsError(f"target already exists: {target}")
        if target.exists():
            target.unlink()
    _clone_sqlite(args.quest_source, args.quest_target)
    _clone_sqlite(args.codebase_source, args.codebase_target)
    codebase_summary = migrate_codebase_database(args.codebase_target)
    quest_summary = migrate_quest_database(args.quest_target, args.codebase_target)
    print(
        json.dumps(
            {"codebases": codebase_summary, "quests": quest_summary},
            ensure_ascii=False,
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
