from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from csat_concept_index import (
    csat_index_metadata,
    get_csat_concept_difficulty,
    get_csat_hard_combinations,
    load_csat_concept_index,
    normalize_csat_tag,
)
from exam_service import plan_exam_items
from generater.fix_gen import allowed_generation_tags
from student_problem_content_review import review_student_problem_content


def test_csat_index_uses_only_supported_generation_tags() -> None:
    """필요 변수: 수능 조합 인덱스와 허용 태그 목록. 작동 원리: 운영 생성기가 모르는 태그가 인덱스에 들어오지 않았는지 전수 비교한다."""
    allowed = {normalize_csat_tag(tag) for tag in allowed_generation_tags()}
    indexed = {
        normalize_csat_tag(tag)
        for combination in load_csat_concept_index()["combinations"]
        for tag in combination["tags"]
    }

    assert indexed
    assert indexed <= allowed
    assert csat_index_metadata() == {
        "version": "2026-07-14.v1",
        "source_count": 3,
        "combination_count": 11,
    }


def test_csat_index_returns_evidence_backed_overlap_only() -> None:
    """필요 변수: 실제 근거 태그와 미등록 태그. 작동 원리: 두 태그 이상 겹친 수능 조합만 반환하고 미등록 태그에는 점수를 만들지 않는다."""
    tags = ["#지수함수의그래프", "#지수방정식", "#두점사이의거리", "#미등록개념"]
    combinations = get_csat_hard_combinations(tags)
    difficulty = get_csat_concept_difficulty(tags)

    assert combinations
    assert set(combinations[0]) == {"#지수함수의그래프", "#지수방정식", "#두점사이의거리"}
    assert "미등록개념" not in difficulty
    assert difficulty["지수함수의그래프"] >= 4.0


def test_exam_high_tier_injects_csat_concept_combination() -> None:
    """필요 변수: 한 범위의 수능 근거 태그와 9문항. 작동 원리: 4~5티어 문항에 실제 변별 문항 조합이 두 개 이상 함께 배치되는지 검증한다."""
    tags = [
        "#지수함수의그래프",
        "#지수방정식",
        "#두점사이의거리",
        "#점과직선사이의거리",
        "#직선의방정식",
    ]
    combinations = get_csat_hard_combinations(tags)
    items = plan_exam_items(
        ranges=[{"key": "math", "tags": tags}],
        difficulty_tier=3,
        question_count=9,
        concept_difficulty_index=get_csat_concept_difficulty(tags),
        concept_combinations=combinations,
    )
    evidence_tags = set(combinations[0])

    hard_items = [item for item in items if int(item["difficulty_tier"]) >= 4]
    assert hard_items
    assert all(len(set(item["hash_tags"]) & evidence_tags) >= 2 for item in hard_items)


def test_content_review_reads_problem_answer_and_solution() -> None:
    """필요 변수: 정상 문제와 생성 메타가 노출된 문제. 작동 원리: 제목만 보지 않고 정답·풀이까지 존재해야 승인하며 메타 문구는 차단한다."""
    valid = {
        "data": {
            "quest_title": "함수 f(x)=x+1일 때 f(2)의 값을 구하시오.",
            "quest_answer": "3",
        },
        "solves": [
            {
                "flow": "함수식의 x에 2를 대입하여 값을 계산합니다.",
                "hint_riddle": "x 대신 2를 대입합니다.",
                "answer_riddle": "2+1을 계산하면 됩니다.",
            }
        ],
    }
    leaked = {
        "data": {
            "quest_title": "정수 k에 대하여 x=2가 되도록 역방향으로 설계된 문제입니다.",
            "quest_answer": "2",
        },
        "solves": valid["solves"],
    }

    assert review_student_problem_content(valid)["approved"] is True
    leaked_review = review_student_problem_content(leaked)
    assert leaked_review["approved"] is False
    assert "generation_metadata_exposed" in leaked_review["reasons"]
    assert "answer_exposed_in_problem_title" in leaked_review["reasons"]
