from __future__ import annotations

import argparse
import json
import sqlite3
import sys
import time
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.audit_problem_data import _load_codebases, _normalized_tags, _quest_from_row
from student_problem_content_review import review_student_problem_contract


def reconcile(quest_db: Path, codebase_db: Path) -> dict[str, Any]:
    """필요 변수: 마이그레이션된 문제·코드베이스 DB. 작동 원리: 승인 코드베이스와 최종 학생 계약을 전 문제에 다시 적용해 조회 상태를 확정한다."""
    codebases = _load_codebases(codebase_db)
    connection = sqlite3.connect(quest_db)
    connection.row_factory = sqlite3.Row
    rows = connection.execute(
        """
        SELECT i.quest_id, i.difficulty, i.hash_tag AS info_tags,
               d.quest_title, d.quest_answer, d.codebase_id, d.seed,
               d.hash_tag AS data_tags
        FROM quest_info i JOIN quest_data d ON d.quest_id=i.quest_id
        ORDER BY i.quest_id
        """
    ).fetchall()
    solves_by_quest: dict[str, list[sqlite3.Row]] = defaultdict(list)
    for solve in connection.execute(
        "SELECT quest_id, flow, hint_riddle, answer_riddle, branches FROM solve_step ORDER BY quest_id, id"
    ):
        solves_by_quest[str(solve["quest_id"])].append(solve)

    status_counts: Counter[str] = Counter()
    reason_counts: Counter[str] = Counter()
    approved_tiers: Counter[str] = Counter()
    updates: list[tuple[str, str, int, str]] = []
    checked_at = int(time.time())
    for row in rows:
        quest_id = str(row["quest_id"])
        codebase_id = row["codebase_id"]
        codebase = codebases.get(int(codebase_id)) if codebase_id is not None else None
        quest = _quest_from_row(row, solves_by_quest.get(quest_id, []))
        reasons: list[str] = []
        if codebase is None:
            reasons.append("missing_codebase_reference")
            review = review_student_problem_contract(
                quest,
                expected_solve_count=len(quest.get("solves") or []),
                expected_tags=_normalized_tags(row["info_tags"], row["data_tags"]),
            )
        else:
            if codebase.get("quality_status") != "approved":
                reasons.append("codebase_not_approved")
            review = review_student_problem_contract(
                quest,
                expected_solve_count=int(codebase.get("solves_count") or 0),
                expected_tags=codebase.get("tags") or [],
            )
        review_reasons = [str(reason) for reason in review["reasons"]]
        reasons.extend(review_reasons)
        reasons = list(dict.fromkeys(reasons))
        content_reasons = {
            "problem_title_missing_or_too_short",
            "problem_answer_missing",
            "solution_content_missing",
            "generation_metadata_exposed",
            "artificial_condition_scaffolding",
            "vague_or_answer_driven_title",
            "answer_exposed_in_problem_title",
            "independent_subproblems_hidden_in_solutions",
        }
        status = "rejected" if any(reason in content_reasons for reason in reasons) else (
            "quarantined" if reasons else "approved"
        )
        if status == "approved" and codebase is not None:
            approved_tiers[str(int(codebase.get("explicit_tier") or 3))] += 1
        status_counts[status] += 1
        reason_counts.update(reasons)
        updates.append((status, json.dumps(reasons, ensure_ascii=False), checked_at, quest_id))

    connection.executemany(
        """
        UPDATE quest_info
        SET quality_status=?, quality_reasons=?, quality_checked_at=?
        WHERE quest_id=?
        """,
        updates,
    )
    connection.commit()
    connection.close()
    return {
        "rows": len(rows),
        "status_counts": dict(sorted(status_counts.items())),
        "approved_tier_counts": dict(sorted(approved_tiers.items())),
        "reason_counts": dict(sorted(reason_counts.items())),
    }


def main() -> None:
    """필요 변수: 원본 또는 복제 DB 경로. 작동 원리: 전 행 품질 상태를 재계산하고 UTF-8 JSON 집계를 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--quest-db", type=Path, required=True)
    parser.add_argument("--codebase-db", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(reconcile(args.quest_db, args.codebase_db), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
