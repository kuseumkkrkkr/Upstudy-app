"""시중 문제집 스타일 변형 문항으로 규칙기반 NLP를 검증한다.

저작권 보호를 위해 특정 교재 문항을 복제하지 않고, 공개된 중3 단원 범위에
맞춘 독자적인 짧은 문항을 사용한다. 각 케이스는 기대 도메인·정답을 고정한다.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from rule_based_nlp import classify, solve_rule  # noqa: E402


CASES = [
    ("2x+7=19에서 x의 값", "cm_linear", 6),
    ("3x-5=10에서 x의 값", "cm_linear", 5),
    ("등차수열 첫항 4, 공차 3일 때 a5", "cm_arith_sequence", 16),
    ("|A|=18, |B|=12, |A∩B|=5일 때 합집합의 원소 수", "cm_set", 25),
    ("이차방정식 x²-7x+12=0의 정수근", "cm_quadratic", 4),
    ("확률 3/8", "cm_probability", 3 / 8),
    ("확률 25%", "cm_probability", 0.25),
    ("6개 중 2개를 뽑는 조합의 수", "cm_probability", 15),
    ("6개 중 2개를 순서 있게 뽑는 순열의 수", "cm_probability", 30),
    ("직각삼각형의 두 변이 5,12일 때 빗변", "cm_geometry", 13),
    ("삼각형의 넓이 밑변 8 높이 5", "cm_geometry", 20),
    ("직사각형 둘레 가로 7 세로 4", "cm_geometry", 22),
]


def main() -> int:
    """변형 문항 12개를 분류·계산·검산하고 통과율을 출력한다."""
    passed = 0
    for index, (text, domain, expected) in enumerate(CASES, start=1):
        parsed = classify(text)
        result = solve_rule(parsed["domain"], parsed["slots"])
        ok = parsed["domain"] == domain and result.get("status") == "PASS" and result.get("verified") is True and result.get("answer") == expected
        print(f"{index:02d} {'PASS' if ok else 'FAIL'} | {domain} | {result.get('answer')} | {text}")
        passed += int(ok)
    print(f"SUMMARY passed={passed} total={len(CASES)} rate={passed / len(CASES):.3f}")
    return 0 if passed == len(CASES) else 1


if __name__ == "__main__":
    raise SystemExit(main())
