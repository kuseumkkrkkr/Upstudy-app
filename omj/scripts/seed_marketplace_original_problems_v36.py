from __future__ import annotations

import argparse
import json
import math
import sys
from fractions import Fraction
from pathlib import Path
from typing import Any, Callable

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.marketplace_problem_batch import seed_problem_batch, validate_problem_batch
from scripts.seed_initial_math_problems import _problem

BATCH_ID = "marketplace-original-v36"
MODEL_NAME = "aiflow-direct-authoring-v36"
CODEBASE_BASE = 20_260_997_000
SEED_BASE = 202_607_576_000


def _checked_problem(
    tier: int,
    index: int,
    *,
    answer_check: Callable[[], Any],
    **kwargs: Any,
) -> dict[str, Any]:
    """필요 변수는 문제 명세와 독립 계산 함수다. 작동 원리는 저장 답과 별도 계산 결과를 비교하도록 검산 함수를 부착한다."""
    spec = _problem(tier, index, **kwargs)
    spec["answer_check"] = answer_check
    return spec


def _perfect_square_coefficient_sum(linear: int, constant: int) -> int:
    """필요 변수는 일차식의 두 계수다. 작동 원리는 완전제곱식을 전개한 세 계수를 더한다."""
    return linear**2 + 2 * linear * constant + constant**2


def _circle_center_radius_sum(horizontal: int, vertical: int, radius: int) -> int:
    """필요 변수는 원의 중심 좌표와 반지름이다. 작동 원리는 표준형에서 읽은 세 값을 더한다."""
    if radius <= 0:
        raise ValueError("반지름은 양수여야 합니다.")
    return horizontal + vertical + radius


def _quadratic_root_distance(quadratic: int, linear: int, constant: int) -> Fraction:
    """필요 변수는 이차방정식의 세 계수다. 작동 원리는 근의 공식에서 두 실근의 차가 sqrt(D)/|a|임을 이용한다."""
    if quadratic == 0:
        raise ValueError("이차항 계수는 0이 아니어야 합니다.")
    discriminant = linear**2 - 4 * quadratic * constant
    root = math.isqrt(discriminant)
    if discriminant <= 0 or root * root != discriminant:
        raise ValueError("서로 다른 두 실근과 정수 판별식 제곱근이 필요합니다.")
    return Fraction(root, abs(quadratic))


def _pascal_combination(upper: int, lower: int) -> int:
    """필요 변수는 조합의 윗수와 아랫수다. 작동 원리는 파스칼 항등식의 합을 하나의 조합으로 바꿔 계산한다."""
    if not 0 <= lower < upper:
        raise ValueError("인접한 두 조합을 만들 수 있는 범위가 필요합니다.")
    return math.comb(upper + 1, lower + 1)


def _rational_exponent_value(base_root: int, denominator: int, numerator: int) -> int:
    """필요 변수는 완전거듭제곱의 밑·지수 분모·분자다. 작동 원리는 (k^m)^(n/m)=k^n으로 정확히 계산한다."""
    if base_root <= 0 or denominator <= 0:
        raise ValueError("양의 밑과 양의 지수 분모가 필요합니다.")
    return base_root**numerator


def _inverse_pair_sum(
    linear: int,
    constant: int,
    first_target: int,
    second_target: int,
) -> Fraction:
    """필요 변수는 일차함수 계수와 역함수에 넣을 두 값이다. 작동 원리는 g(y)=(y-b)/a를 두 번 계산해 더한다."""
    if linear == 0:
        raise ValueError("일차함수는 일대일이어야 합니다.")
    return Fraction(first_target - constant, linear) + Fraction(second_target - constant, linear)


def _quadratic_inequality_integer_square_sum(
    first_root: int,
    second_root: int,
    relation: str,
    lower: int,
    upper: int,
) -> int:
    """필요 변수는 이차식의 두 근·부등호·정수 범위다. 작동 원리는 범위의 각 정수를 이차식에 대입해 해의 제곱합을 구한다."""
    comparisons: dict[str, Callable[[int], bool]] = {
        ">": lambda value: value > 0,
        ">=": lambda value: value >= 0,
        "<": lambda value: value < 0,
        "<=": lambda value: value <= 0,
    }
    if first_root >= second_root or lower > upper or relation not in comparisons:
        raise ValueError("이차부등식 조건이 올바르지 않습니다.")
    return sum(
        value**2
        for value in range(lower, upper + 1)
        if comparisons[relation]((value - first_root) * (value - second_root))
    )


def _cubic_value(first_turn: int, second_turn: int, constant: int, value: int) -> int:
    """필요 변수는 도함수의 두 영점·상수항·평가점이다. 작동 원리는 도함수가 6(x-a)(x-b)인 삼차함수 값을 계산한다."""
    return (
        2 * value**3
        - 3 * (first_turn + second_turn) * value**2
        + 6 * first_turn * second_turn * value
        + constant
    )


def _cubic_interval_extrema_sum(
    first_turn: int,
    second_turn: int,
    constant: int,
    lower: int,
    upper: int,
) -> int:
    """필요 변수는 두 임계점·상수항·닫힌구간이다. 작동 원리는 양 끝점과 구간 안 임계점의 함수값을 비교해 최댓값과 최솟값을 더한다."""
    if first_turn >= second_turn or lower >= upper:
        raise ValueError("서로 다른 임계점과 닫힌구간이 필요합니다.")
    candidates = [lower, upper]
    candidates.extend(point for point in (first_turn, second_turn) if lower <= point <= upper)
    values = [_cubic_value(first_turn, second_turn, constant, point) for point in candidates]
    return max(values) + min(values)


def _inductive_sum(upper: int) -> int:
    """필요 변수는 합의 상한이다. 작동 원리는 k(k+1)을 직접 합산해 귀납 공식 결과를 독립 검산한다."""
    if upper < 1:
        raise ValueError("합의 상한은 1 이상이어야 합니다.")
    return sum(index * (index + 1) for index in range(1, upper + 1))


def _hyperbola_line_root_sum(
    horizontal: int,
    vertical: int,
    numerator: int,
    line_slope: int,
    line_intercept: int,
) -> Fraction:
    """필요 변수는 쌍곡선 이동량·분자와 직선 계수다. 작동 원리는 교점 방정식을 이차식으로 바꾸고 근과 계수 관계로 x좌표 합을 구한다."""
    if numerator == 0 or line_slope == 0:
        raise ValueError("쌍곡선 분자와 직선 기울기는 0이 아니어야 합니다.")
    quadratic = line_slope
    linear = line_intercept - line_slope * horizontal - vertical
    constant = -line_intercept * horizontal + vertical * horizontal - numerator
    discriminant = linear**2 - 4 * quadratic * constant
    if discriminant <= 0:
        raise ValueError("서로 다른 두 실교점이 필요합니다.")
    return Fraction(-linear, quadratic)


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 완전제곱 일차식과 원의 표준형이다. 작동 원리는 계수합과 중심·반지름 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    square_rows = [(2, 3), (-3, 5), (4, -1), (1, -6), (-2, -5)]
    for index, (linear, constant) in enumerate(square_rows, 1):
        answer = _perfect_square_coefficient_sum(linear, constant)
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"완전제곱식 $(({linear})x+({constant}))^2$을 전개했을 때 모든 계수의 합을 구하시오.",
                answer=str(answer),
                tags=["#완전제곱식", "#인수분해공식", "#다항식의곱셈"],
                steps=[
                    ("완전제곱 공식을 적용해 이차식으로 전개한다.", rf"$({linear})^2x^2+2({linear})({constant})x+({constant})^2$이다."),
                    ("x=1을 대입하는 계수합 성질로 세 계수를 더한다.", rf"따라서 계수의 합은 ${answer}$이다."),
                ],
                answer_check=lambda a=linear, b=constant: _perfect_square_coefficient_sum(a, b),
            )
        )
    circle_rows = [(2, -3, 5), (-4, 1, 3), (5, 2, 4), (-3, -2, 6), (1, 4, 7)]
    for index, (horizontal, vertical, radius) in enumerate(circle_rows, 6):
        answer = _circle_center_radius_sum(horizontal, vertical, radius)
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"원 $(x-({horizontal}))^2+(y-({vertical}))^2={radius**2}$의 중심을 $(p,q)$, 반지름을 r라 할 때 $p+q+r$을 구하시오.",
                answer=str(answer),
                tags=["#원의방정식", "#중심", "#반지름"],
                steps=[
                    ("원의 표준형에서 중심과 반지름을 읽는다.", rf"$(p,q)=({horizontal},{vertical})$이고 $r={radius}$이다."),
                    ("중심의 두 좌표와 반지름을 더한다.", rf"따라서 $p+q+r={answer}$이다."),
                ],
                answer_check=lambda h=horizontal, k=vertical, r=radius: _circle_center_radius_sum(h, k, r),
            )
        )
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 판별식이 완전제곱인 이차방정식과 인접 조합이다. 작동 원리는 근의 공식과 파스칼 항등식 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    quadratic_rows = [(1, -7, 10), (2, -10, 8), (3, -18, 15), (4, -4, -8), (5, -10, -15)]
    for index, (a, b, c) in enumerate(quadratic_rows, 1):
        discriminant = b**2 - 4 * a * c
        answer = _quadratic_root_distance(a, b, c)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"이차방정식 $({a})x^2+({b})x+({c})=0$의 두 실근 중 큰 근과 작은 근의 차를 구하시오.",
                answer=str(answer),
                tags=["#근의공식", "#이차방정식의풀이", "#실근조건", "#이차방정식의판별식"],
                steps=[
                    ("판별식을 계산해 서로 다른 두 실근임을 확인한다.", rf"$D=({b})^2-4({a})({c})={discriminant}$이다."),
                    ("근의 공식에서 두 근의 차를 정리한다.", r"큰 근과 작은 근의 차는 $\sqrt D/|a|$이다."),
                    ("판별식의 제곱근과 이차항 계수를 대입한다.", rf"따라서 두 근의 차는 ${answer}$이다."),
                ],
                answer_check=lambda first=a, second=b, third=c: _quadratic_root_distance(first, second, third),
            )
        )
    combination_rows = [(7, 2), (9, 3), (10, 4), (12, 5), (14, 6)]
    for index, (upper, lower) in enumerate(combination_rows, 6):
        answer = _pascal_combination(upper, lower)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"조합의 합 $\binom{{{upper}}}{{{lower}}}+\binom{{{upper}}}{{{lower + 1}}}$의 값을 구하시오.",
                answer=str(answer),
                tags=["#조합", "#조합의성질", "#조합의수", "#합의법칙"],
                steps=[
                    ("윗수가 같은 인접한 두 조합임을 확인한다.", "아랫수는 1만큼 차이 난다."),
                    ("파스칼 항등식을 적용한다.", rf"합은 $\binom{{{upper + 1}}}{{{lower + 1}}}$이다."),
                    ("팩토리얼 또는 약분으로 조합값을 계산한다.", rf"따라서 값은 ${answer}$이다."),
                ],
                answer_check=lambda n=upper, r=lower: _pascal_combination(n, r),
            )
        )
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 완전거듭제곱과 일차함수의 역함수다. 작동 원리는 유리수 지수와 역함숫값 합 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    exponent_rows = [(2, 3, 4), (3, 2, 3), (2, 4, 3), (5, 2, 3), (3, 3, 2)]
    for index, (root, denominator, numerator) in enumerate(exponent_rows, 1):
        base = root**denominator
        answer = _rational_exponent_value(root, denominator, numerator)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"유리수 지수의 값을 이용하여 ${base}^{{{numerator}/{denominator}}}$의 값을 구하시오.",
                answer=str(answer),
                tags=["#유리수지수", "#실수지수", "#지수의확장", "#지수법칙의성질"],
                steps=[
                    ("밑을 지수의 분모에 맞는 완전거듭제곱으로 나타낸다.", rf"${base}={root}^{denominator}$이다."),
                    ("거듭제곱의 거듭제곱 법칙을 적용한다.", rf"$({root}^{denominator})^{{{numerator}/{denominator}}}={root}^{numerator}$이다."),
                    ("지수의 분모와 밑의 지수를 약분한다.", rf"남는 지수는 ${numerator}$이다."),
                    ("자연수 거듭제곱을 계산한다.", rf"따라서 값은 ${answer}$이다."),
                ],
                alternatives=["먼저 양의 ${denominator}$제곱근을 구한 뒤 그 값을 ${numerator}$제곱할 수 있다."],
                answer_check=lambda k=root, m=denominator, n=numerator: _rational_exponent_value(k, m, n),
            )
        )
    inverse_rows = [(2, 3, 11, -1), (-3, 5, 2, 14), (4, -2, 10, 18), (5, 1, -4, 16), (-2, -3, 5, -9)]
    for index, (linear, constant, first_target, second_target) in enumerate(inverse_rows, 6):
        answer = _inverse_pair_sum(linear, constant, first_target, second_target)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"일차함수 $f(x)=({linear})x+({constant})$의 역함수를 g라 할 때, $g({first_target})+g({second_target})$의 값을 구하시오.",
                answer=str(answer),
                tags=["#역함수", "#역함수구하기", "#역함수의그래프", "#일대일함수", "#일대일대응"],
                steps=[
                    ("y=f(x)에서 x와 y를 바꾼다.", rf"$x=({linear})y+({constant})$이다."),
                    ("y에 대해 풀어 역함수식을 구한다.", rf"$g(x)=(x-({constant}))/({linear})$이다."),
                    ("두 입력값을 역함수식에 각각 대입한다.", rf"$g({first_target})$와 $g({second_target})$를 계산한다."),
                    ("두 역함숫값을 더한다.", rf"따라서 합은 ${answer}$이다."),
                ],
                alternatives=["$g(t)=s$와 $f(s)=t$가 동치임을 이용해 두 역함숫값을 따로 구할 수 있다."],
                answer_check=lambda a=linear, b=constant, p=first_target, q=second_target: _inverse_pair_sum(a, b, p, q),
            )
        )
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 근을 가진 이차부등식과 두 임계점을 가진 삼차함수다. 작동 원리는 정수해 제곱합과 닫힌구간 최대최소 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    inequality_rows = [
        (-2, 4, "<", -5, 7),
        (-3, 5, "<=", -6, 8),
        (1, 6, ">", -4, 9),
        (-5, 2, ">=", -8, 5),
        (0, 7, "<", -3, 10),
    ]
    for index, (first, second, relation, lower, upper) in enumerate(inequality_rows, 1):
        solutions = [
            value
            for value in range(lower, upper + 1)
            if {">": lambda x: x > 0, ">=": lambda x: x >= 0, "<": lambda x: x < 0, "<=": lambda x: x <= 0}[relation](
                (value - first) * (value - second)
            )
        ]
        answer = _quadratic_inequality_integer_square_sum(first, second, relation, lower, upper)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"정수 범위 ${lower}\le x\le {upper}$에서 이차부등식 $(x-({first}))(x-({second})){relation}0$을 만족하는 모든 정수 x의 제곱의 합을 구하시오.",
                answer=str(answer),
                tags=["#이차부등식", "#이차부등식의풀이", "#이차부등식의해", "#이차함수와이차부등식"],
                steps=[
                    ("이차식의 두 영점을 수직선에 표시한다.", rf"경계는 $x={first}, {second}$이다."),
                    ("최고차항 계수가 양수인 이차식의 부호를 구간별로 판정한다.", "두 근 바깥은 양수이고 두 근 사이는 음수이다."),
                    ("주어진 부등호에 맞는 실수 구간을 선택한다.", "등호 포함 여부를 경계점에 반영한다."),
                    ("제한된 정수 범위와 교집합을 구한다.", rf"정수해는 $\{{{','.join(map(str, solutions))}\}}$이다."),
                    ("각 정수해를 제곱해 모두 더한다.", rf"따라서 제곱의 합은 ${answer}$이다."),
                ],
                alternatives=["주어진 정수 범위의 각 값을 인수 두 개에 직접 대입해 부호와 제곱합을 동시에 확인할 수 있다."],
                answer_check=lambda a=first, b=second, op=relation, low=lower, high=upper: _quadratic_inequality_integer_square_sum(a, b, op, low, high),
            )
        )
    extrema_rows = [(-1, 2, 3, -2, 3), (-2, 1, -4, -3, 2), (0, 3, 5, -1, 4), (-3, 2, 1, -4, 3), (1, 4, -2, 0, 5)]
    for index, (first, second, constant, lower, upper) in enumerate(extrema_rows, 6):
        candidates = [lower, upper, first, second]
        values = [_cubic_value(first, second, constant, point) for point in candidates]
        maximum = max(values)
        minimum = min(values)
        answer = _cubic_interval_extrema_sum(first, second, constant, lower, upper)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"닫힌구간 $[{lower},{upper}]$에서 함수 $f(x)=2x^3-({3 * (first + second)})x^2+({6 * first * second})x+({constant})$의 최댓값과 최솟값의 합을 구하시오.",
                answer=str(answer),
                tags=["#정의역에서의최대최소", "#최대최소문제", "#최댓값", "#최솟값", "#도함수"],
                steps=[
                    ("함수를 미분해 도함수를 인수분해한다.", rf"$f'(x)=6(x-({first}))(x-({second}))$이다."),
                    ("구간 안의 임계점을 찾는다.", rf"$x={first}, {second}$가 모두 후보이다."),
                    ("닫힌구간 양 끝점도 후보에 포함한다.", rf"$x={lower}, {upper}$에서의 함수값도 계산한다."),
                    ("네 후보점의 함수값을 비교한다.", rf"최댓값은 ${maximum}$, 최솟값은 ${minimum}$이다."),
                    ("두 극단값을 더한다.", rf"따라서 합은 ${answer}$이다."),
                ],
                alternatives=["도함수 부호표로 증가·감소 구간을 그린 뒤 양 끝점과 극값만 비교할 수 있다."],
                answer_check=lambda a=first, b=second, c=constant, low=lower, high=upper: _cubic_interval_extrema_sum(a, b, c, low, high),
            )
        )
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 귀납 합의 상한과 직선·쌍곡선 매개변수다. 작동 원리는 귀납 공식 계산과 교점 이차방정식 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    induction_rows = [12, 15, 18, 20, 25]
    for index, upper in enumerate(induction_rows, 1):
        answer = _inductive_sum(upper)
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"수학적 귀납법으로 확인할 수 있는 합 $\sum_{{k=1}}^{{{upper}}}k(k+1)$의 값을 구하시오.",
                answer=str(answer),
                tags=["#수학적귀납법", "#귀납법의원리", "#귀납법증명", "#합의기호시그마", "#여러가지수열의합"],
                steps=[
                    ("일반 명제 $P(n)$을 합 공식으로 세운다.", r"$\sum_{k=1}^n k(k+1)=n(n+1)(n+2)/3$으로 둔다."),
                    ("n=1에서 좌변과 우변이 같음을 확인한다.", "두 값이 모두 2이므로 시작 단계가 성립한다."),
                    ("n=m에서 명제가 참이라고 가정한다.", r"$\sum_{k=1}^m k(k+1)=m(m+1)(m+2)/3$을 사용한다."),
                    ("다음 항 $(m+1)(m+2)$를 더해 n=m+1인 식으로 정리한다.", r"$(m+1)(m+2)(m+3)/3$이 되어 귀납 단계가 성립한다."),
                    ("따라서 모든 자연수 n에 합 공식이 성립함을 결론낸다.", rf"공식에 $n={upper}$을 대입한다."),
                    ("곱셈과 나눗셈을 계산해 직접 합과 대조한다.", rf"따라서 합은 ${answer}$이다."),
                ],
                alternatives=[
                    "$k(k+1)=k^2+k$로 전개해 자연수 합과 제곱합 공식을 각각 적용할 수 있다.",
                    "각 항을 직접 더해 귀납 공식의 수치 결과를 검산할 수 있다.",
                ],
                answer_check=lambda n=upper: _inductive_sum(n),
            )
        )
    hyperbola_rows = [(1, 2, 4, 1, 0), (-2, 2, 5, 2, 3), (3, -1, 2, 2, 5), (0, 3, 6, 3, -1), (-3, -2, 4, 1, 2)]
    for index, (horizontal, vertical, numerator, slope, intercept) in enumerate(hyperbola_rows, 6):
        quadratic = slope
        linear = intercept - slope * horizontal - vertical
        constant = -intercept * horizontal + vertical * horizontal - numerator
        discriminant = linear**2 - 4 * quadratic * constant
        answer = _hyperbola_line_root_sum(horizontal, vertical, numerator, slope, intercept)
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"쌍곡선 $y=\dfrac{{{numerator}}}{{x-({horizontal})}}+({vertical})$와 직선 $y=({slope})x+({intercept})$가 서로 다른 두 점에서 만난다. 두 교점의 x좌표의 합을 구하시오.",
                answer=str(answer),
                tags=["#쌍곡선", "#유리식과유리함수", "#이차함수와이차방정식", "#두근의합", "#실근조건"],
                steps=[
                    ("두 식의 y값을 같게 두어 교점 방정식을 세운다.", rf"${numerator}/(x-({horizontal}))+({vertical})=({slope})x+({intercept})$이다."),
                    ("양변에 분모 $x-({horizontal})$를 곱한다.", "정의역에서 제외되는 점을 기억하며 분모를 없앤다."),
                    ("모든 항을 한쪽으로 옮겨 이차방정식으로 정리한다.", rf"$({quadratic})x^2+({linear})x+({constant})=0$이다."),
                    ("판별식으로 서로 다른 두 실근임을 확인한다.", rf"$D={discriminant}>0$이다."),
                    ("근과 계수의 관계를 적용한다.", rf"두 x좌표의 합은 $-({linear})/({quadratic})$이다."),
                    ("정의역 제외점이 근이 아님을 확인하고 기약분수로 정리한다.", rf"따라서 두 x좌표의 합은 ${answer}$이다."),
                ],
                alternatives=[
                    "직선식을 쌍곡선식에 대입하고 통분한 뒤 두 근을 직접 구해 더할 수 있다.",
                    "교점 이차방정식의 두 근을 수직선에서 근삿값으로 확인해 실교점 두 개를 검산할 수 있다.",
                ],
                answer_check=lambda h=horizontal, v=vertical, k=numerator, m=slope, n=intercept: _hyperbola_line_root_sum(h, v, k, m, n),
            )
        )
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v36 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v36 전체 카탈로그다. 작동 원리는 독립 정답 검산 후 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog = build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v36 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(
        catalog,
        expected_count=50,
        batch_id=BATCH_ID,
        model_name=MODEL_NAME,
        codebase_base=CODEBASE_BASE,
        seed_base=SEED_BASE,
    )


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v36 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(
        db_path,
        quests=validated_quests(),
        batch_id=BATCH_ID,
        validate_only=validate_only,
    )


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v36 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
