"""규칙기반 NLP 핵심 회귀 테스트."""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from rule_based_nlp import classify, solve_rule  # noqa: E402


def test_core_domains() -> None:
    """중3 핵심 도메인이 분류·계산·검산까지 통과하는지 확인한다."""
    cases = [
        ("등차수열 a1=5,d=3일 때 a3", "cm_arith_sequence", 11),
        ("|A|=24,|B|=10,|A∩B|=6", "cm_set", 28),
        ("2x+3=9", "cm_linear", 3),
        ("이차방정식 1x²-5x+6=0", "cm_quadratic", 3),
        ("비례식 2:3=4:6", "cm_ratio", 2 / 3),
        ("확률 1/6", "cm_probability", 1 / 6),
        ("확률 50%", "cm_probability", 0.5),
        ("5개 중 2개를 뽑는 경우의 수", "cm_probability", 10),
        ("5개 중 2개를 순서 있게 뽑는 순열", "cm_probability", 20),
        ("피타고라스 3,4,5", "cm_geometry", 5),
        ("삼각형의 넓이 밑변 6 높이 4", "cm_geometry", 12),
        ("원의 넓이 반지름 2", "cm_geometry", 3.141592653589793 * 4),
        ("직사각형 넓이 가로 5 세로 3", "cm_geometry", 15),
        ("직사각형 둘레 가로 5 세로 3", "cm_geometry", 16),
    ]
    for text, domain, expected in cases:
        parsed = classify(text)
        assert parsed["domain"] == domain
        result = solve_rule(domain, parsed["slots"])
        assert result["status"] == "PASS"
        assert result["verified"] is True
        assert result["answer"] == expected


def test_invalid_geometry_is_rejected() -> None:
    """피타고라스 조건을 만족하지 않는 입력은 성공으로 처리하지 않는다."""
    parsed = classify("피타고라스 3,4,6")
    result = solve_rule(parsed["domain"], parsed["slots"])
    assert result["status"] == "FAIL"


if __name__ == "__main__":
    test_core_domains()
    test_invalid_geometry_is_rejected()
    print("PASS: rule_based_nlp core domains")
