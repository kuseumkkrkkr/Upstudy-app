from __future__ import annotations

import sys
from pathlib import Path
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from exam_service import plan_exam_items
from generater import problem_solve


def _fake_codebase(tags: list[str], tier: int, _rng: object) -> dict[str, object]:
    """필요 변수: 문제별 태그와 티어. 작동 원리: 외부 AI 호출 없이 생성 계획만 검증할 가짜 코드베이스를 반환한다."""
    return {"id": tier, "code": "", "tags": tags, "tier": tier}


def _fake_quest(
    entry: dict[str, object],
    tags: list[str],
    params: problem_solve.TierParams,
    seed: int,
    question_type: str,
    raw_result: dict[str, object] | None = None,
) -> dict[str, object]:
    """필요 변수: 생성 엔트리·태그·티어 파라미터·시드. 작동 원리: 난도별 풀이 단계 수를 가진 최소 문제를 즉시 만든다."""
    del question_type, raw_result
    tier = int(entry["tier"])
    return {
        "header": {"quest_id": f"tier-{entry['tier']}-{seed}"},
        "info": {"difficulty": 99, "hash_tag": tags},
        "data": {
            "quest_title": f"다항식 x+{tier}의 값을 조건에 따라 계산하시오.",
            "quest_answer": str(tier + 1),
        },
        "solves": [
            {
                "flow": f"조건을 정리하는 풀이 단계 {index + 1}입니다.",
                "hint_riddle": "주어진 식의 항을 차례대로 정리합니다.",
                "answer_riddle": "정리한 값을 다음 단계에 대입합니다.",
                "branches": [],
            }
            for index in range(params.solves_count)
        ],
    }


def test_student_bulk_generation_preserves_all_five_tiers() -> None:
    """필요 변수: 5개 개념과 5문항. 작동 원리: 외부 생성만 대체하고 실제 대량 계획기로 티어 1~5를 한 번씩 만든다."""
    with (
        patch.object(problem_solve, "load_codebases", return_value=[]),
        patch.object(problem_solve, "_generate_and_store_codebase", side_effect=_fake_codebase),
        patch.object(problem_solve, "_build_quest_from_codebase", side_effect=_fake_quest),
        patch.object(
            problem_solve,
            "run_codebase_batch",
            side_effect=lambda _entry, seeds, **_kwargs: [{"ok": True} for _ in seeds],
        ),
    ):
        quests = problem_solve.generate_problem_set(
            hash_tags=["#개념1", "#개념2", "#개념3", "#개념4", "#개념5"],
            min_difficulty_tier=1,
            max_difficulty_tier=5,
            question_count=5,
            seed=20260714,
        )

    assert [quest["info"]["difficulty"] for quest in quests] == [99] * 5
    assert [quest["info"]["difficulty_tier"] for quest in quests] == [1, 2, 3, 4, 5]
    assert [quest["info"]["difficulty_score"] for quest in quests] == [99] * 5
    assert [len(quest["solves"]) for quest in quests] == [2, 3, 4, 5, 6]


def test_student_bulk_reuses_only_matching_tier_codebase() -> None:
    """필요 변수: 같은 선택 태그의 1·5티어 코드베이스. 작동 원리: 5티어 요청이 1티어 재사용 후보를 고르지 않는지 검증한다."""
    entries = [
        {
            "id": 1,
            "code": "",
            "tags": ["#개념1", "#개념2", "#개념3", "#개념4", "#개념5"],
            "tier": 1,
            "solves_count": 2,
            "strategy_level": 1,
            "branch_conditions": 0,
        },
        {
            "id": 5,
            "code": "",
            "tags": ["#개념1", "#개념2", "#개념3", "#개념4", "#개념5"],
            "tier": 5,
            "solves_count": 6,
            "strategy_level": 3,
            "branch_conditions": 2,
        },
    ]
    used_entry_ids: list[int] = []

    def record_entry(entry: dict[str, object], *args: object, **kwargs: object) -> dict[str, object]:
        """필요 변수: 선택된 코드베이스. 작동 원리: 실제 문제 대신 재사용된 ID를 기록한다."""
        del args, kwargs
        used_entry_ids.append(int(entry["id"]))
        return {
            "header": {"quest_id": "reuse-test"},
            "info": {"hash_tag": ["#개념1", "#개념2", "#개념3", "#개념4", "#개념5"]},
            "data": {
                "quest_title": "다항식 x+1에 x=1을 대입한 값을 구하시오.",
                "quest_answer": "2",
            },
            "solves": [
                {
                    "flow": f"문자 x에 주어진 수를 대입하는 풀이 단계 {index + 1}입니다.",
                    "hint_riddle": "x 대신 1을 씁니다.",
                    "answer_riddle": "1+1을 계산합니다.",
                    "branches": [],
                }
                for index in range(6)
            ],
        }

    with (
        patch.object(problem_solve, "load_codebases", return_value=entries),
        patch.object(problem_solve, "list_cached_seeds", return_value=[123]),
        patch.object(problem_solve, "run_codebase_batch", return_value=[{"ok": True}]),
        patch.object(problem_solve, "_build_quest_from_codebase", side_effect=record_entry),
    ):
        problem_solve.generate_problem_set(
            hash_tags=["#개념1", "#개념2", "#개념3", "#개념4", "#개념5"],
            min_difficulty_tier=5,
            max_difficulty_tier=5,
            question_count=1,
            seed=20260714,
        )

    assert used_entry_ids == [5]


def test_aiflow_exam_varies_tiers_and_includes_hardest_concept() -> None:
    """필요 변수: 복수 개념·기준 티어 3·9문항. 작동 원리: 난이도 곡선과 고난도 개념 강제 포함을 함께 검증한다."""
    items = plan_exam_items(
        ranges=[{"key": "math", "tags": ["#쉬운개념", "#중간개념", "#어려운개념"]}],
        difficulty_tier=3,
        question_count=9,
        concept_difficulty_index={"쉬운개념": 1.0, "중간개념": 3.0, "어려운개념": 5.0},
    )

    tiers = [int(item["difficulty_tier"]) for item in items]
    assert min(tiers) == 1
    assert max(tiers) == 5
    assert len(set(tiers)) == 5
    assert all(
        "#어려운개념" in item["hash_tags"]
        for item in items
        if int(item["difficulty_tier"]) >= 4
    )


def test_csat_hard_items_keep_optional_and_hardest_concepts() -> None:
    """필요 변수: 공통·선택 개념과 수능 30문항. 작동 원리: 선택 과목 보존 상태에서 최고 난도 개념도 함께 포함되는지 검증한다."""
    items = plan_exam_items(
        ranges=[
            {"key": "common-1", "tags": ["#공통쉬움", "#공통어려움"]},
            {"key": "optional", "tags": ["#선택쉬움", "#선택어려움"]},
        ],
        difficulty_tier=5,
        question_count=30,
        paper_type="csat",
        concept_difficulty_index={
            "공통쉬움": 1.0,
            "공통어려움": 4.0,
            "선택쉬움": 2.0,
            "선택어려움": 5.0,
        },
    )

    optional_hard_items = [
        item
        for item in items
        if int(item["item_index"]) >= 23 and int(item["difficulty_tier"]) >= 4
    ]
    assert optional_hard_items
    assert all("#선택어려움" in item["hash_tags"] for item in optional_hard_items)
    assert all(
        any(tag.startswith("#선택") for tag in item["hash_tags"])
        for item in optional_hard_items
    )
