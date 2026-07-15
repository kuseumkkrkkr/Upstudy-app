from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))


def verify_samples(codebase_db: Path) -> list[dict[str, object]]:
    """필요 변수: 검증 완료 코드베이스 DB. 작동 원리: 시험지 실제 make 경로에서 티어별 한 문항을 생성하고 최종 계약을 다시 판정한다."""
    os.environ["CODEBASE_DB_PATH"] = str(codebase_db.resolve())
    from difficulty_contract import DIFFICULTY_CONTRACTS
    from generater.codebase_store import load_codebases
    from generater.make import make
    from student_problem_content_review import content_text, review_student_problem_contract

    target_counts = {1: 1, 2: 1, 3: 3, 4: 3, 5: 3}
    cases: dict[int, list[str]] = {}
    for entry in load_codebases(student_ready_only=True):
        tier = int(entry.get("tier") or 0)
        tags = [str(tag) for tag in entry.get("tags") or []]
        if tier in target_counts and len(tags) == target_counts[tier] and tier not in cases:
            cases[tier] = tags
    if set(cases) != set(target_counts):
        raise RuntimeError(f"approved exam catalog misses tiers: {sorted(cases)}")

    results: list[dict[str, object]] = []
    for tier in range(1, 6):
        contract = DIFFICULTY_CONTRACTS[tier]
        question_type = "mcq" if tier in {1, 3, 5} else "short"
        quest = make(
            cases[tier],
            contract.solves_count,
            contract.strategy_level,
            contract.branch_conditions,
            None,
            False,
            None,
            question_type,
            None,
            student_ready_only=True,
        )
        review = review_student_problem_contract(
            quest,
            expected_solve_count=contract.solves_count,
            expected_tags=cases[tier],
        )
        data = quest.get("data") or {}
        info = quest.get("info") or {}
        results.append(
            {
                "tier": tier,
                "tags": cases[tier],
                "question_type": data.get("question_type"),
                "option_count": len(data.get("quest_options") or []),
                "title": content_text(data.get("quest_title")),
                "answer": content_text(data.get("quest_answer")),
                "difficulty_score": info.get("difficulty_score"),
                "difficulty_tier": info.get("difficulty_tier"),
                "review": review,
            }
        )
    return results


def main() -> None:
    """필요 변수: 코드베이스 복제본. 작동 원리: 결과 다섯 건을 UTF-8 JSON Lines로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--codebase-db", type=Path, required=True)
    args = parser.parse_args()
    for result in verify_samples(args.codebase_db):
        print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
