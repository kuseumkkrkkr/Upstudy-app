from __future__ import annotations

import random
from fractions import Fraction
from typing import Any, Dict, Iterable, List, Optional, Sequence, Tuple

import sympy as sp

X = sp.symbols("x")

PARAM_MIN = -5
PARAM_MAX = 5
PARAM_RANGE = list(range(PARAM_MIN, PARAM_MAX + 1))
BRUTE_RANGE = list(range(-3, 4))
MAX_TRIES = 100
TARGET_DIFFICULTY = 28


def generate_problem(seed: Optional[int] = None) -> Dict[str, Any]:
    rng = random.Random(seed)
    if not _BASE_CANDIDATES:
        raise Exception("No base candidates available for problem generation.")

    for _ in range(MAX_TRIES):
        r1, r2, k, a = _choose_base_params(rng)
        if _is_symmetric(r1, r2, k):
            continue
        if _critical_point_count(r1, r2, a) <= 1:
            continue

        values = _values_in_range(r1, r2, a, BRUTE_RANGE)
        if _first_differences_constant(values):
            continue
        if _has_simple_pattern(values):
            continue

        m_candidates = [m for m in PARAM_RANGE if m not in (r1, r2, a)]
        rng.shuffle(m_candidates)
        for m in m_candidates:
            answer = _eval_poly_int(m, r1, r2, a)
            if answer == 0:
                continue
            if abs(answer) > 50:
                continue
            if abs(answer) <= 5:
                continue
            if not _sympy_validate(r1, r2, k, m, a, answer):
                continue

            problem = _build_problem_text(r1, r2, k, m)
            return {
                "problem": problem,
                "answer": int(answer),
                "meta": {
                    "difficulty": TARGET_DIFFICULTY,
                    "concept": "second_derivative",
                    "params": {"r1": r1, "r2": r2, "k": k, "m": m, "a": a},
                },
            }

    raise Exception("Failed to generate a valid problem after 100 attempts.")


def _choose_base_params(rng: random.Random) -> Tuple[int, int, int, int]:
    return rng.choice(_BASE_CANDIDATES)


def _build_base_candidates() -> List[Tuple[int, int, int, int]]:
    candidates: List[Tuple[int, int, int, int]] = []
    for r1 in PARAM_RANGE:
        for r2 in PARAM_RANGE:
            if r1 >= r2:
                continue
            for k in PARAM_RANGE:
                a = _compute_third_root(r1, r2, k)
                if not _in_range(a):
                    continue
                if a in (r1, r2):
                    continue
                candidates.append((r1, r2, k, a))
    return candidates


def _compute_third_root(r1: int, r2: int, k: int) -> int:
    return 3 * k - r1 - r2


def _in_range(value: int) -> bool:
    return PARAM_MIN <= value <= PARAM_MAX


def _eval_poly_int(x_value: int, r1: int, r2: int, a: int) -> int:
    return (x_value - r1) * (x_value - r2) * (x_value - a)


def _build_polynomial(r1: int, r2: int, a: int) -> sp.Expr:
    return sp.expand((X - r1) * (X - r2) * (X - a))


def _sympy_validate(
    r1: int,
    r2: int,
    k: int,
    m: int,
    a: int,
    expected_answer: int,
) -> bool:
    poly = _build_polynomial(r1, r2, a)
    if sp.LC(poly, X) != 1:
        return False
    if poly.subs(X, r1) != 0 or poly.subs(X, r2) != 0:
        return False

    second_at_k = sp.diff(poly, X, 2).subs(X, k)
    if sp.simplify(second_at_k) != 0:
        return False

    sympy_answer = sp.simplify(poly.subs(X, m))
    if not sympy_answer.is_integer:
        return False
    return int(sympy_answer) == int(expected_answer)


def _critical_point_count(r1: int, r2: int, a: int) -> int:
    s = r1 + r2 + a
    p = r1 * r2 + r1 * a + r2 * a
    disc = s * s - 3 * p
    if disc > 0:
        return 2
    if disc == 0:
        return 1
    return 0


def _values_in_range(r1: int, r2: int, a: int, xs: Iterable[int]) -> List[int]:
    return [_eval_poly_int(x_value, r1, r2, a) for x_value in xs]


def _first_differences_constant(values: Sequence[int]) -> bool:
    if len(values) < 2:
        return True
    diffs = [values[i + 1] - values[i] for i in range(len(values) - 1)]
    return len(set(diffs)) == 1


def _has_simple_pattern(values: Sequence[int]) -> bool:
    if _is_palindrome(values):
        return True
    if _is_antisymmetric(values):
        return True
    if _is_geometric(values):
        return True
    if values.count(0) >= 2:
        return True
    if len(set(values)) <= 3:
        return True
    if _diffs_low_var(values):
        return True
    return False


def _diffs_low_var(values: Sequence[int]) -> bool:
    if len(values) < 3:
        return True
    diffs = [values[i + 1] - values[i] for i in range(len(values) - 1)]
    return len(set(diffs)) <= 2


def _is_palindrome(values: Sequence[int]) -> bool:
    return list(values) == list(reversed(values))


def _is_antisymmetric(values: Sequence[int]) -> bool:
    return list(values) == [-v for v in reversed(values)]


def _is_geometric(values: Sequence[int]) -> bool:
    if len(values) < 3:
        return False
    if any(v == 0 for v in values):
        return False
    ratios = [Fraction(values[i + 1], values[i]) for i in range(len(values) - 1)]
    return len(set(ratios)) == 1


def _is_symmetric(r1: int, r2: int, k: int) -> bool:
    return (r1 + r2) == 2 * k


def _build_problem_text(r1: int, r2: int, k: int, m: int) -> str:
    return (
        "최고차항의 계수가 1인 삼차함수 f(x)가 서로 다른 두 정수근 "
        f"{r1}, {r2}를 가지고 f''({k})=0을 만족한다. "
        f"이때 f({m})의 값을 구하시오."
    )


_BASE_CANDIDATES = _build_base_candidates()
