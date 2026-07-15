from __future__ import annotations

import unittest

from student_problem_content_review import review_student_problem_contract


def _quest(*, title: str, flows: list[str], tags: list[str]) -> dict[str, object]:
    """필요 변수: 문제 본문·풀이 문장·태그. 작동 원리: 학생 문제 계약 검수에 필요한 최소 문제 구조를 만든다."""
    return {
        "info": {"hash_tag": tags},
        "data": {"quest_title": title, "quest_answer": "7", "hash_tag": tags},
        "solves": [
            {
                "flow": flow,
                "hint_riddle": "주어진 조건을 식으로 정리합니다.",
                "answer_riddle": "정리한 식을 계산해 다음 단계로 이어갑니다.",
                "branches": [],
            }
            for flow in flows
        ],
    }


class StudentProblemContentReviewTests(unittest.TestCase):
    """필요 변수: 고의로 오염한 학생 문제. 작동 원리: 상용 캐시 진입 전 의미·구조 게이트를 회귀 검증한다."""

    def test_contract_rejects_independent_questions_hidden_as_solution_steps(self) -> None:
        """필요 변수: 서로 독립적인 질문형 풀이 단계. 작동 원리: 한 문제처럼 포장한 다문항 템플릿을 학생 노출 전에 차단한다."""
        quest = _quest(
            title="주어진 여러 수학 조건을 이용하여 최종 값을 계산하시오.",
            flows=["첫 번째 수열의 제 몇 항인지 구하시오.", "별도 방정식의 최대 정수해를 구하시오."],
            tags=["#수열"],
        )

        review = review_student_problem_contract(quest, expected_solve_count=2, expected_tags=["#수열"])

        self.assertFalse(review["approved"])
        self.assertIn("independent_subproblems_hidden_in_solutions", review["reasons"])

    def test_contract_rejects_interval_partition_used_as_internal_division(self) -> None:
        """필요 변수: 구간의 분할 태그와 선분 내분 문맥. 작동 원리: 이름만 비슷한 다른 개념의 문제 재사용을 차단한다."""
        quest = _quest(
            title="두 점을 잇는 선분을 내분하는 점의 좌표를 구하시오.",
            flows=["내분 공식에 두 점의 좌표를 대입합니다.", "좌표 성분을 각각 계산합니다."],
            tags=["#구간의분할"],
        )

        review = review_student_problem_contract(
            quest,
            expected_solve_count=2,
            expected_tags=["#구간의분할"],
        )

        self.assertFalse(review["approved"])
        self.assertIn("tag_semantic_collision:구간의분할_vs_내분", review["reasons"])
