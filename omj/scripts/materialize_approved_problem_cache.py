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


def materialize(
    quest_db: Path,
    codebase_db: Path,
    *,
    variants_per_codebase: int,
) -> dict[str, Any]:
    """필요 변수: 검증 완료 복제 DB와 코드베이스당 수량. 작동 원리: 승인 시드를 최종 문제로 재구성해 SQLite 캐시를 AI 호출 없이 채운다."""
    os.environ["QUEST_DB_PATH"] = str(quest_db.resolve())
    os.environ["CODEBASE_DB_PATH"] = str(codebase_db.resolve())
    from difficulty_contract import DIFFICULTY_CONTRACTS
    from generater.codebase_runner import run_codebase_batch
    from generater.codebase_store import compute_code_hash, load_codebases
    from generater.problem_solve import TierParams, _build_quest_from_codebase, finalize_student_quest
    from storage import storage as quest_storage

    quest_storage.DB_PATH = str(quest_db.resolve())
    quest_storage.init_db()
    connection = sqlite3.connect(codebase_db)
    connection.row_factory = sqlite3.Row
    existing_connection = sqlite3.connect(quest_db)
    existing_pairs = {
        (int(row[0]), int(row[1]))
        for row in existing_connection.execute(
            "SELECT codebase_id, seed FROM quest_data WHERE codebase_id IS NOT NULL AND seed IS NOT NULL"
        )
    }
    existing_connection.close()

    counters: Counter[str] = Counter()
    tag_coverage: set[str] = set()
    started = time.monotonic()
    codebases = load_codebases(student_ready_only=True)
    for index, entry in enumerate(codebases, start=1):
        entry_id = int(entry["id"])
        code_hash = compute_code_hash(entry.get("code") or "")
        seed_rows = connection.execute(
            """
            SELECT seed FROM codebase_quality_validation
            WHERE codebase_id=? AND code_hash=? AND status='approved'
            ORDER BY seed ASC LIMIT ?
            """,
            (entry_id, code_hash, max(1, variants_per_codebase * 3)),
        ).fetchall()
        seeds = [
            int(row["seed"])
            for row in seed_rows
            if (entry_id, int(row["seed"])) not in existing_pairs
        ][:variants_per_codebase]
        if not seeds:
            counters["codebase_without_new_seed"] += 1
            continue
        tier = max(1, min(5, int(entry.get("tier") or 3)))
        contract = DIFFICULTY_CONTRACTS[tier]
        params = TierParams(
            solves_count=contract.solves_count,
            strategy_level=contract.strategy_level,
            branch_conditions=contract.branch_conditions,
        )
        raw_results = run_codebase_batch(entry, seeds, timeout_seconds=8.0)
        for seed, raw in zip(seeds, raw_results):
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
                finalized = finalize_student_quest(quest, tier, entry.get("tags") or [])
                if not quest_storage.store_data(finalized):
                    raise RuntimeError(quest_storage.get_last_store_error() or "store failed")
                counters["stored"] += 1
                counters[f"tier_{tier}"] += 1
                existing_pairs.add((entry_id, seed))
                tag_coverage.update(str(tag).strip().lstrip("#") for tag in entry.get("tags") or [])
            except Exception:
                counters["rejected"] += 1
        if index % 25 == 0 or index == len(codebases):
            print(
                f"progress={index}/{len(codebases)} stored={counters['stored']} rejected={counters['rejected']}",
                flush=True,
            )
    connection.close()
    return {
        "quest_db": str(quest_db.resolve()),
        "codebase_db": str(codebase_db.resolve()),
        "approved_codebases": len(codebases),
        "variants_per_codebase": variants_per_codebase,
        "counts": dict(sorted(counters.items())),
        "tag_coverage": len(tag_coverage),
        "elapsed_seconds": round(time.monotonic() - started, 3),
    }


def main() -> None:
    """필요 변수: 복제 문제·코드베이스 DB. 작동 원리: 기본 세 변형씩 저장하고 결과를 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--quest-db", type=Path, required=True)
    parser.add_argument("--codebase-db", type=Path, required=True)
    parser.add_argument("--variants-per-codebase", type=int, default=3)
    args = parser.parse_args()
    result = materialize(
        args.quest_db,
        args.codebase_db,
        variants_per_codebase=max(1, min(20, args.variants_per_codebase)),
    )
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
