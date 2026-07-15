from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys
import time
from collections import Counter
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))


def _prepare_schema(connection: sqlite3.Connection) -> None:
    """필요 변수: 코드베이스 DB 연결. 작동 원리: 시드별 최종 콘텐츠 검증 증거를 재실행 가능하게 저장한다."""
    connection.execute(
        """
        CREATE TABLE IF NOT EXISTS codebase_quality_validation (
            codebase_id INTEGER NOT NULL,
            code_hash TEXT NOT NULL,
            seed INTEGER NOT NULL,
            status TEXT NOT NULL CHECK(status IN ('approved','rejected')),
            reasons_json TEXT NOT NULL,
            checked_at INTEGER NOT NULL,
            PRIMARY KEY(codebase_id, code_hash, seed)
        )
        """
    )
    connection.execute(
        "CREATE INDEX IF NOT EXISTS idx_codebase_quality_status ON codebase_quality_validation(status, codebase_id)"
    )
    connection.commit()


def validate_catalog(
    database: Path,
    *,
    samples_per_codebase: int,
    required_approvals: int,
    only_status: str | None = None,
) -> dict[str, Any]:
    """필요 변수: 복제 DB와 표본·승인 수. 작동 원리: 모든 코드베이스의 기존 캐시 시드를 최종 학생 문제로 복원해 승인·격리한다."""
    os.environ["CODEBASE_DB_PATH"] = str(database.resolve())
    from generater.codebase_runner import run_codebase_batch
    from generater.codebase_store import compute_code_hash, load_codebases, update_codebase_quality
    from generater.problem_solve import TierParams, _build_quest_from_codebase
    from difficulty_contract import DIFFICULTY_CONTRACTS
    from student_problem_content_review import review_student_problem_contract

    connection = sqlite3.connect(database)
    connection.row_factory = sqlite3.Row
    _prepare_schema(connection)
    codebases = load_codebases(student_ready_only=False)
    if only_status:
        codebases = [entry for entry in codebases if entry.get("quality_status") == only_status]
    status_counts: Counter[str] = Counter()
    reason_counts: Counter[str] = Counter()
    tier_counts: Counter[str] = Counter()
    seed_status_counts: Counter[str] = Counter()
    quarantined_details: list[dict[str, Any]] = []
    started = time.monotonic()

    for index, entry in enumerate(codebases, start=1):
        entry_id = int(entry["id"])
        code_hash = compute_code_hash(entry.get("code") or "")
        seed_rows = connection.execute(
            """
            SELECT seed FROM codebase_seed_cache
            WHERE codebase_id=? AND code_hash=?
            ORDER BY seed ASC LIMIT ?
            """,
            (entry_id, code_hash, max(samples_per_codebase, required_approvals)),
        ).fetchall()
        seeds = [int(row["seed"]) for row in seed_rows]
        approved = 0
        codebase_reasons: list[str] = []
        tier = max(1, min(5, int(entry.get("tier") or 3)))
        canonical = DIFFICULTY_CONTRACTS[tier]
        params = TierParams(
            solves_count=canonical.solves_count,
            strategy_level=canonical.strategy_level,
            branch_conditions=canonical.branch_conditions,
        )
        raw_results = run_codebase_batch(entry, seeds, timeout_seconds=8.0) if seeds else []
        checked_at = int(time.time())
        validation_rows = []
        rejected_seeds = []
        for seed, raw in zip(seeds, raw_results):
            reasons: list[str] = []
            try:
                if isinstance(raw, dict) and "_error" in raw:
                    raise RuntimeError(str(raw["_error"]))
                quest = _build_quest_from_codebase(
                    entry,
                    list(entry.get("tags") or []),
                    params,
                    seed,
                    question_type="short",
                    raw_result=raw,
                )
                review = review_student_problem_contract(
                    quest,
                    expected_solve_count=params.solves_count,
                    expected_tags=entry.get("tags") or [],
                )
                reasons = [str(reason) for reason in review["reasons"]]
            except Exception as exc:
                reasons = [f"runtime:{exc.__class__.__name__}"]
            seed_status = "approved" if not reasons else "rejected"
            if seed_status == "approved":
                approved += 1
            else:
                rejected_seeds.append(seed)
                codebase_reasons.extend(reasons)
            reason_counts.update(reasons)
            seed_status_counts[seed_status] += 1
            validation_rows.append(
                (
                    entry_id,
                    code_hash,
                    seed,
                    seed_status,
                    json.dumps(reasons, ensure_ascii=False),
                    checked_at,
                )
            )

        connection.executemany(
            """
            INSERT INTO codebase_quality_validation
            (codebase_id, code_hash, seed, status, reasons_json, checked_at)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(codebase_id, code_hash,seed) DO UPDATE SET
                status=excluded.status,
                reasons_json=excluded.reasons_json,
                checked_at=excluded.checked_at
            """,
            validation_rows,
        )
        if rejected_seeds:
            placeholders = ",".join("?" for _ in rejected_seeds)
            connection.execute(
                f"DELETE FROM codebase_seed_cache WHERE codebase_id=? AND code_hash=? AND seed IN ({placeholders})",
                [entry_id, code_hash, *rejected_seeds],
            )
        connection.commit()

        if approved >= required_approvals:
            quality_status = "approved"
            quality_reasons: list[str] = []
        else:
            quality_status = "quarantined"
            quality_reasons = list(dict.fromkeys(codebase_reasons or ["insufficient_approved_seeds"]))
            quarantined_details.append(
                {
                    "codebase_id": entry_id,
                    "tier": entry.get("tier"),
                    "approved_seeds": approved,
                    "reasons": quality_reasons,
                }
            )
        update_codebase_quality(entry_id, quality_status, quality_reasons)
        status_counts[quality_status] += 1
        tier_counts[f"{entry.get('tier')}:{quality_status}"] += 1
        if index % 25 == 0 or index == len(codebases):
            print(
                f"progress={index}/{len(codebases)} approved_codebases={status_counts['approved']} "
                f"quarantined_codebases={status_counts['quarantined']}",
                flush=True,
            )

    connection.close()
    return {
        "database": str(database.resolve()),
        "codebases": len(codebases),
        "samples_per_codebase": samples_per_codebase,
        "required_approvals": required_approvals,
        "only_status": only_status,
        "codebase_status_counts": dict(sorted(status_counts.items())),
        "tier_status_counts": dict(sorted(tier_counts.items())),
        "seed_status_counts": dict(sorted(seed_status_counts.items())),
        "reason_counts": dict(sorted(reason_counts.items())),
        "quarantined_details": quarantined_details,
        "elapsed_seconds": round(time.monotonic() - started, 3),
    }


def main() -> None:
    """필요 변수: 복제 코드베이스 DB. 작동 원리: 기본 다섯 시드 중 세 개 이상 통과한 코드베이스만 학생 재사용 승인한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--database", type=Path, required=True)
    parser.add_argument("--samples-per-codebase", type=int, default=5)
    parser.add_argument("--required-approvals", type=int, default=3)
    parser.add_argument("--only-status", choices=("pending_validation", "approved", "quarantined"))
    args = parser.parse_args()
    if args.required_approvals < 1 or args.samples_per_codebase < args.required_approvals:
        raise ValueError("samples_per_codebase must be >= required_approvals >= 1")
    result = validate_catalog(
        args.database,
        samples_per_codebase=args.samples_per_codebase,
        required_approvals=args.required_approvals,
        only_status=args.only_status,
    )
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
