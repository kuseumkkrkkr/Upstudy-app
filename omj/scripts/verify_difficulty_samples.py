from __future__ import annotations

import json
import argparse
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from generater.problem_solve import generate_problem_set
from generater.codebase_store import load_codebases
from student_problem_content_review import content_text, review_student_problem_content


CASES = {
    1: ["#좌극한"],
    2: ["#인수정리활용"],
    3: ["#중근조건", "#수직조건", "#구간의분할"],
    4: ["#인수분해법", "#약분", "#명제의참거짓"],
    5: ["#밑", "#밑의변환", "#지수부등식", "#지수방정식", "#진수"],
}


def _catalog_cases() -> dict[int, list[str]]:
    """필요 변수: 승인 코드베이스 카탈로그. 작동 원리: 각 티어의 목표 태그 수와 정확히 맞는 승인 사례를 하나씩 선택한다."""
    target_tag_counts = {1: 1, 2: 1, 3: 3, 4: 3, 5: 3}
    cases: dict[int, list[str]] = {}
    catalog = load_codebases(student_ready_only=True)
    available_counts: dict[int, set[int]] = {}
    for entry in catalog:
        tier = int(entry.get("tier") or 0)
        tags = [str(tag) for tag in entry.get("tags") or [] if str(tag).strip()]
        available_counts.setdefault(tier, set()).add(len(tags))
        if tier in target_tag_counts and len(tags) == target_tag_counts[tier] and tier not in cases:
            cases[tier] = tags
    if set(cases) != set(target_tag_counts):
        raise RuntimeError(
            f"approved catalog does not cover all tiers: {sorted(cases)}; "
            f"tag_counts={{{', '.join(f'{tier}: {sorted(counts)}' for tier, counts in sorted(available_counts.items()))}}}"
        )
    return cases


def build_samples(*, catalog_driven: bool = False) -> list[dict[str, object]]:
    """필요 변수: 티어별 기존 코드베이스 태그. 작동 원리: 각 티어에서 한 문제만 만들고 본문·정답·전체 풀이를 읽을 수 있는 검수 결과로 펼친다."""
    samples: list[dict[str, object]] = []
    cases = _catalog_cases() if catalog_driven else CASES
    for tier, tags in cases.items():
        try:
            quest = generate_problem_set(
                hash_tags=tags,
                min_difficulty_tier=tier,
                max_difficulty_tier=tier,
                question_count=1,
                seed=20260714 + tier,
            )[0]
        except Exception as exc:
            samples.append({"tier": tier, "tags": tags, "approved": False, "error": str(exc)})
            continue
        info = quest.get("info") or {}
        data = quest.get("data") or {}
        header = quest.get("header") or {}
        solves = quest.get("solves") or []
        samples.append(
            {
                "tier": tier,
                "tags": info.get("hash_tag"),
                "difficulty": info.get("difficulty"),
                "difficulty_score": info.get("difficulty_score"),
                "flow_count": len(solves),
                "title": content_text(data.get("quest_title")),
                "answer": content_text(data.get("quest_answer")),
                "solutions": [
                    {
                        "flow": content_text(solve.get("flow")),
                        "hint": content_text(solve.get("hint_riddle")),
                        "answer_explanation": content_text(solve.get("answer_riddle")),
                    }
                    for solve in solves
                    if isinstance(solve, dict)
                ],
                "content_review": review_student_problem_content(quest),
                "quest_id": header.get("quest_id"),
            }
        )
    return samples


def main() -> None:
    """필요 변수: 없음. 작동 원리: UTF-8 JSON Lines로 소량 검증 결과를 표준 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog-driven", action="store_true")
    args = parser.parse_args()
    for sample in build_samples(catalog_driven=args.catalog_driven):
        print(json.dumps(sample, ensure_ascii=False))


if __name__ == "__main__":
    main()
