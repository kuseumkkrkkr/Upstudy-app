"""고난도 변형 문항에서 최적 규칙 경로와 풀이 trace를 검증한다."""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from rule_based_nlp import build_solution_trace, classify, select_optimal_rule, solve_rule  # noqa: E402


CASES = [
    ("이차방정식 x²-11x+30=0의 정수근", 6),
    ("10개 중 4개를 순서 있게 뽑는 순열의 수", 5040),
    ("10개 중 4개를 뽑는 조합의 수", 210),
    ("직각삼각형 두 변 7,24일 때 빗변", 25),
    ("등차수열 첫항 17, 공차 -3일 때 a9", -7),
    ("함수 f(x)=2x+3에서 x=4일 때 함숫값", 11),
    ("등차수열 첫항 3, 공차 2, 5항까지의 합", 35),
    ("x²-5x+6을 인수분해", "(x-3)(x-2)"),
    ("합성함수 f(x)=2x+1, g(x)=3x+2일 때 f(g(4))", 29),
    ("역함수 f(x)=2x+3의 역함수", "(x-3)/2"),
    ("조건부확률 P(A∩B)=1/10, P(B)=1/2일 때 P(A|B)", 0.2),
]


def main() -> int:
    """고난도 케이스의 답·검산·trace 길이·규칙 경로를 확인한다."""
    passed = 0
    for text, expected in CASES:
        parsed = classify(text)
        result = solve_rule(parsed["domain"], parsed["slots"])
        trace = build_solution_trace(parsed, result)
        path = select_optimal_rule(parsed)
        ok = result.get("status") == "PASS" and result.get("answer") == expected and result.get("verified") is True and len(trace) >= 4 and path.get("status") == "PASS"
        print(f"{'PASS' if ok else 'FAIL'} | {parsed['domain']} | answer={result.get('answer')} | steps={len(trace)} | path={path.get('path')}")
        passed += int(ok)
    print(f"SUMMARY passed={passed} total={len(CASES)} rate={passed / len(CASES):.3f}")
    return 0 if passed == len(CASES) else 1


if __name__ == "__main__":
    raise SystemExit(main())
