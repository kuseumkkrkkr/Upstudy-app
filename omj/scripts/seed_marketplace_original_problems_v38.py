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

BATCH_ID = "marketplace-original-v38"
MODEL_NAME = "aiflow-direct-authoring-v38"
CODEBASE_BASE = 20_260_999_000
SEED_BASE = 202_607_578_000


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


def _synthetic_summary(linear: int, quadratic: int, constant: int, root: int) -> int:
    """필요 변수는 최고차항이 1인 삼차식의 세 계수와 나눗식의 근이다. 작동 원리는 조립제법으로 몫 계수합과 나머지를 더한다."""
    quotient_linear = linear + root
    quotient_constant = quadratic + root * quotient_linear
    remainder = constant + root * quotient_constant
    return 1 + quotient_linear + quotient_constant + remainder


def _row_column_scalar_product(row: tuple[int, int, int], column: tuple[int, int, int]) -> int:
    """필요 변수는 3성분 행벡터와 열벡터다. 작동 원리는 대응 성분을 곱해 모두 더한다."""
    return sum(first * second for first, second in zip(row, column))


def _adjacent_circular_arrangements(people: int) -> int:
    """필요 변수는 서로 다른 사람 수다. 작동 원리는 지정된 두 사람을 한 묶음으로 보고 원순열 수에 내부 순서 2를 곱한다."""
    if people < 3:
        raise ValueError("서로 다른 사람이 3명 이상 필요합니다.")
    return 2 * math.factorial(people - 2)


def _proper_superset_count(total: int, required: int) -> int:
    """필요 변수는 전체 집합과 반드시 포함할 부분집합의 원소 수다. 작동 원리는 자유 원소 선택 수에서 전체 집합 한 경우를 뺀다."""
    if not 0 <= required < total:
        raise ValueError("진부분집합을 만들 수 있는 원소 수가 필요합니다.")
    return 2 ** (total - required) - 1


def _radical_horizontal_intersection(horizontal: int, vertical: int, height: int) -> int:
    """필요 변수는 무리함수의 평행이동량과 수평선 높이다. 작동 원리는 sqrt(x-h)=height-k를 제곱해 교점 x좌표를 구한다."""
    difference = height - vertical
    if difference < 0:
        raise ValueError("수평선은 무리함수의 시작 높이 이상이어야 합니다.")
    return horizontal + difference**2


def _exponential_inequality_count(
    base: int,
    horizontal: int,
    vertical: int,
    boundary_exponent: int,
    relation: str,
    lower: int,
    upper: int,
) -> int:
    """필요 변수는 지수함수 이동량·경계 지수·부등호·정수 범위다. 작동 원리는 증가성을 이용해 지수끼리 비교하고 정수해를 센다."""
    comparisons: dict[str, Callable[[int, int], bool]] = {
        ">": lambda value, boundary: value > boundary,
        ">=": lambda value, boundary: value >= boundary,
        "<": lambda value, boundary: value < boundary,
        "<=": lambda value, boundary: value <= boundary,
    }
    if base <= 1 or relation not in comparisons or lower > upper:
        raise ValueError("지수부등식 조건이 올바르지 않습니다.")
    threshold = base**boundary_exponent + vertical
    return sum(
        comparisons[relation](base ** (value - horizontal) + vertical, threshold)
        for value in range(lower, upper + 1)
    )


def _factored_cubic_sign_change_left_sum(
    doubled_roots: tuple[int, int, int],
    lower: int,
    upper: int,
) -> int:
    """필요 변수는 분모 2인 세 근의 분자와 정수 검사구간이다. 작동 원리는 연속 다항식의 인접 정수 함수값 부호가 바뀌는 왼쪽 끝점을 더한다."""
    if lower >= upper:
        raise ValueError("두 점 이상인 정수 구간이 필요합니다.")

    def value(x_value: int) -> int:
        """필요 변수는 정수 평가점이다. 작동 원리는 (2x-r1)(2x-r2)(2x-r3)를 직접 계산한다."""
        return math.prod(2 * x_value - root for root in doubled_roots)

    return sum(
        point
        for point in range(lower, upper)
        if value(point) * value(point + 1) < 0
    )


def _inverse_composition_constant(linear: int, constant: int) -> Fraction:
    """필요 변수는 일차함수의 기울기와 상수항이다. 작동 원리는 f(x/a+k)=x 항등식의 상수항을 0으로 두어 k를 구한다."""
    if linear == 0:
        raise ValueError("역함수가 존재하는 일차함수여야 합니다.")
    return Fraction(-constant, linear)


def _nonnegative_solution_count(total: int, variables: int) -> int:
    """필요 변수는 합의 값과 미지수 개수다. 작동 원리는 별과 막대 공식으로 음이 아닌 정수해 수를 계산한다."""
    if total < 0 or variables < 1:
        raise ValueError("음이 아닌 합과 한 개 이상의 미지수가 필요합니다.")
    return math.comb(total + variables - 1, variables - 1)


def _parallel_tangent_intercept(
    quadratic: int,
    horizontal: int,
    vertical: int,
    slope: int,
) -> Fraction:
    """필요 변수는 포물선 표준형 계수·꼭짓점과 접선 기울기다. 작동 원리는 접점 기울기 조건으로 직선의 y절편을 구한다."""
    if quadratic == 0:
        raise ValueError("포물선의 이차항 계수는 0이 아니어야 합니다.")
    return Fraction(vertical, 1) - slope * horizontal - Fraction(slope**2, 4 * quadratic)


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 삼차식 조립제법과 행·열 벡터다. 작동 원리는 나눗셈 요약과 스칼라곱 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    division_rows = [(2, -3, 5, 1), (-1, 4, -2, 2), (3, 1, -5, -1), (-4, 2, 7, 3), (1, -6, 4, -2)]
    for index, (linear, quadratic, constant, root) in enumerate(division_rows, 1):
        quotient_linear = linear + root
        quotient_constant = quadratic + root * quotient_linear
        remainder = constant + root * quotient_constant
        answer = _synthetic_summary(linear, quadratic, constant, root)
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"다항식 $P(x)=x^3+({linear})x^2+({quadratic})x+({constant})$를 $x-({root})$로 나눈 몫의 모든 계수의 합과 나머지를 다시 더한 값을 구하시오.",
                answer=str(answer),
                tags=["#조립제법", "#다항식의나눗셈", "#나머지정리증명", "#나머지정리활용"],
                steps=[
                    ("조립제법으로 몫의 두 나머지 계수와 최종 나머지를 구한다.", rf"몫은 $x^2+({quotient_linear})x+({quotient_constant})$, 나머지는 ${remainder}$이다."),
                    ("몫의 계수 세 개와 나머지를 모두 더한다.", rf"따라서 값은 ${answer}$이다."),
                ],
                answer_check=lambda a=linear, b=quadratic, c=constant, r=root: _synthetic_summary(a, b, c, r),
            )
        )
    scalar_rows = [
        ((1, 2, 3), (4, -1, 2)),
        ((-2, 5, 1), (3, 2, -4)),
        ((4, 0, -3), (-1, 6, 2)),
        ((-5, 2, 7), (2, -3, 1)),
        ((3, -4, 6), (5, 1, -2)),
    ]
    for index, (row, column) in enumerate(scalar_rows, 6):
        products = [first * second for first, second in zip(row, column)]
        answer = _row_column_scalar_product(row, column)
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"행벡터 $({row[0]},{row[1]},{row[2]})$와 열벡터 $({column[0]},{column[1]},{column[2]})^T$의 스칼라곱을 구하시오.",
                answer=str(answer),
                tags=["#스칼라곱", "#행", "#열", "#행렬의연산"],
                steps=[
                    ("서로 대응하는 행과 열의 성분을 각각 곱한다.", rf"세 곱은 ${products[0]}, {products[1]}, {products[2]}$이다."),
                    ("세 곱을 모두 더한다.", rf"따라서 스칼라곱은 ${answer}$이다."),
                ],
                answer_check=lambda first=row, second=column: _row_column_scalar_product(first, second),
            )
        )
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 원탁에 앉는 사람 수와 부분집합 포함 조건이다. 작동 원리는 인접 원순열과 진부분집합 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    people_rows = [5, 6, 7, 8, 9]
    for index, people in enumerate(people_rows, 1):
        answer = _adjacent_circular_arrangements(people)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"서로 다른 {people}명이 원탁에 둘러앉을 때, 특정한 두 사람 A와 B가 서로 이웃하도록 앉는 경우의 수를 구하시오.",
                answer=str(answer),
                tags=["#원순열", "#순열", "#경우의수", "#곱의법칙"],
                steps=[
                    ("A와 B를 하나의 묶음으로 본다.", rf"묶음을 포함해 원탁에 놓을 대상은 ${people - 1}$개이다."),
                    ("원순열과 묶음 내부 순서를 함께 계산한다.", rf"경우의 수는 $({people - 2})!\cdot2$이다."),
                    ("팩토리얼을 계산한다.", rf"따라서 경우의 수는 ${answer}$이다."),
                ],
                answer_check=lambda count=people: _adjacent_circular_arrangements(count),
            )
        )
    subset_rows = [
        ((1, 2, 3, 4, 5), (1, 3)),
        ((-2, -1, 0, 1, 2, 3), (-2, 0, 2)),
        ((2, 4, 6, 8, 10, 12, 14), (4, 8)),
        ((1, 3, 5, 7, 9, 11), (1, 5, 9, 11)),
        ((0, 1, 2, 3, 4, 5, 6, 7), (0, 7)),
    ]
    for index, (universe, required) in enumerate(subset_rows, 6):
        answer = _proper_superset_count(len(universe), len(required))
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"집합 $U=\{{{','.join(map(str, universe))}\}}$의 진부분집합 X 중 $\{{{','.join(map(str, required))}\}}\subseteq X$를 만족하는 X의 개수를 구하시오.",
                answer=str(answer),
                tags=["#진부분집합", "#부분집합", "#집합의포함관계", "#집합"],
                steps=[
                    ("반드시 포함할 원소를 고정하고 나머지 원소 수를 센다.", rf"선택이 자유로운 원소는 ${len(universe) - len(required)}$개이다."),
                    ("자유 원소의 모든 포함·미포함 경우를 계산한다.", rf"전체 후보는 $2^{{{len(universe) - len(required)}}}$개이다."),
                    ("X가 U 자체인 한 경우를 제외한다.", rf"따라서 진부분집합은 ${answer}$개이다."),
                ],
                answer_check=lambda total=len(universe), fixed=len(required): _proper_superset_count(total, fixed),
            )
        )
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 평행이동한 무리함수와 지수함수 부등식이다. 작동 원리는 수평선 교점과 정수해 개수 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    radical_rows = [(1, -2, 3), (-3, 1, 5), (4, 2, 6), (-1, -4, 2), (5, 0, 7)]
    for index, (horizontal, vertical, height) in enumerate(radical_rows, 1):
        answer = _radical_horizontal_intersection(horizontal, vertical, height)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"무리함수 $f(x)=\sqrt{{x-({horizontal})}}+({vertical})$의 그래프와 수평선 $y={height}$의 교점의 x좌표를 구하시오.",
                answer=str(answer),
                tags=["#무리함수의그래프", "#무리함수의평행이동", "#무리식", "#정의역"],
                steps=[
                    ("두 그래프의 y값을 같게 둔다.", rf"$\sqrt{{x-({horizontal})}}={height}-({vertical})$이다."),
                    ("우변이 음이 아닌지 확인한다.", rf"우변은 ${height - vertical}$이므로 교점이 존재한다."),
                    ("양변을 제곱해 x에 대한 일차방정식을 얻는다.", rf"$x-({horizontal})=({height - vertical})^2$이다."),
                    ("x를 구하고 정의역을 확인한다.", rf"따라서 교점의 x좌표는 ${answer}$이다."),
                ],
                alternatives=["기본 그래프 y=√x의 한 점을 수평·수직 이동해 수평선 교점을 추적할 수 있다."],
                answer_check=lambda h=horizontal, v=vertical, y=height: _radical_horizontal_intersection(h, v, y),
            )
        )
    exponential_rows = [
        (2, 1, 3, 2, ">", -3, 8),
        (3, -2, 1, 1, ">=", -5, 6),
        (4, 2, -1, 2, "<", -2, 10),
        (5, -1, 4, 1, "<=", -4, 7),
        (2, 3, -2, 4, ">", 0, 12),
    ]
    for index, (base, horizontal, vertical, power, relation, lower, upper) in enumerate(exponential_rows, 6):
        threshold = base**power + vertical
        boundary = horizontal + power
        answer = _exponential_inequality_count(base, horizontal, vertical, power, relation, lower, upper)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"정수 범위 ${lower}\le x\le {upper}$에서 지수부등식 ${base}^{{x-({horizontal})}}+({vertical}){relation}{threshold}$을 만족하는 정수 x의 개수를 구하시오.",
                answer=str(answer),
                tags=["#지수부등식", "#지수방정식과지수부등식", "#지수함수", "#지수함수의평행이동", "#증가함수"],
                steps=[
                    ("양변에서 같은 수직 이동량을 제거한다.", rf"${base}^{{x-({horizontal})}}{relation}{base}^{power}$이다."),
                    ("밑이 1보다 커서 지수함수가 증가함을 이용한다.", rf"지수끼리 비교하면 $x-({horizontal}){relation}{power}$이다."),
                    ("x의 경계값을 정리한다.", rf"경계는 $x={boundary}$이다."),
                    ("주어진 정수 범위와 교집합을 세어 답한다.", rf"따라서 정수해는 ${answer}$개이다."),
                ],
                alternatives=["범위 안의 각 정수를 원래 지수식에 직접 대입해 부등호를 확인할 수 있다."],
                answer_check=lambda b=base, h=horizontal, v=vertical, p=power, op=relation, low=lower, high=upper: _exponential_inequality_count(b, h, v, p, op, low, high),
            )
        )
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 반정수 근을 가진 삼차함수와 서로 역인 일차함수다. 작동 원리는 중간값정리와 합성 일치조건 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    root_rows = [((-3, 1, 5), -3, 4), ((-5, 3, 7), -4, 5), ((-1, 3, 9), -2, 6), ((-7, -1, 5), -5, 4), ((1, 5, 11), -1, 7)]
    for index, (roots, lower, upper) in enumerate(root_rows, 1):
        answer = _factored_cubic_sign_change_left_sum(roots, lower, upper)
        expression = "".join(rf"(2x-({root}))" for root in roots)
        changing = [
            point
            for point in range(lower, upper)
            if math.prod(2 * point - root for root in roots)
            * math.prod(2 * (point + 1) - root for root in roots)
            < 0
        ]
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"연속함수 $f(x)={expression}$에 대하여 정수 k가 ${lower}\le k<{upper}$이고 $f(k)f(k+1)<0$을 만족할 때, 모든 k의 합을 구하시오.",
                answer=str(answer),
                tags=["#중간값정리", "#연속함수의성질", "#연속의정의", "#함수의극한"],
                steps=[
                    ("각 일차인수에서 함수의 세 영점을 구한다.", "세 영점은 모두 반정수이므로 정수 경계와 겹치지 않는다."),
                    ("연속함수의 부호가 영점을 지날 때 바뀌는지 확인한다.", "서로 다른 일차인수 근마다 부호가 한 번 바뀐다."),
                    ("각 영점을 포함하는 단위 정수구간을 찾는다.", rf"조건을 만족하는 왼쪽 끝점은 $\{{{','.join(map(str, changing))}\}}$이다."),
                    ("중간값정리로 각 구간 안의 영점 존재를 확인한다.", "양 끝 함수값의 부호가 반대이므로 영점이 존재한다."),
                    ("해당 왼쪽 끝점을 모두 더한다.", rf"따라서 k의 합은 ${answer}$이다."),
                ],
                alternatives=["범위의 각 정수에서 함수값 부호를 직접 계산해 인접한 부호 변화만 표시할 수 있다."],
                answer_check=lambda values=roots, low=lower, high=upper: _factored_cubic_sign_change_left_sum(values, low, high),
            )
        )
    inverse_rows = [(2, 3), (-3, 5), (4, -2), (5, 1), (-2, -3)]
    for index, (linear, constant) in enumerate(inverse_rows, 6):
        answer = _inverse_composition_constant(linear, constant)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"함수 $f(x)=({linear})x+({constant})$와 $g(x)=x/({linear})+k$가 모든 실수 x에 대하여 $(f\circ g)(x)=x$를 만족할 때 상수 k를 구하시오.",
                answer=str(answer),
                tags=["#합성함수", "#합성함수의성질", "#역", "#일치조건", "#역함수"],
                steps=[
                    ("합성함수 f(g(x))를 계산한다.", rf"$f(g(x))=({linear})(x/({linear})+k)+({constant})$이다."),
                    ("x항을 정리한다.", rf"$f(g(x))=x+({linear})k+({constant})$이다."),
                    ("모든 실수에서 x와 일치하려면 상수항이 0이어야 한다.", rf"$({linear})k+({constant})=0$이다."),
                    ("일차방정식을 풀어 k를 구한다.", rf"$k={answer}$이다."),
                    ("구한 g가 f의 역함수인지 반대 합성도 확인한다.", rf"최종 상수는 ${answer}$이고 $g(f(x))=x$도 성립한다."),
                ],
                alternatives=["f의 역함수를 x와 y를 바꾸어 직접 구한 뒤 g의 상수항과 비교할 수 있다."],
                answer_check=lambda a=linear, b=constant: _inverse_composition_constant(a, b),
            )
        )
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 음이 아닌 정수해 방정식과 포물선·직선 접선 조건이다. 작동 원리는 중복조합과 중근 판정 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    combination_rows = [(12, 4), (15, 5), (18, 4), (20, 6), (25, 5)]
    for index, (total, variables) in enumerate(combination_rows, 1):
        answer = _nonnegative_solution_count(total, variables)
        variable_text = "+".join(f"x_{{{number}}}" for number in range(1, variables + 1))
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"방정식 ${variable_text}={total}$을 만족하는 음이 아닌 정수해 $(x_1,\ldots,x_{variables})$의 개수를 구하시오.",
                answer=str(answer),
                tags=["#중복조합", "#조합의성질", "#조합의수", "#경우의수"],
                steps=[
                    ("합을 별의 개수로, 미지수 사이 경계를 막대로 해석한다.", rf"별은 ${total}$개이고 막대는 ${variables - 1}$개이다."),
                    ("별과 막대의 전체 위치 수를 구한다.", rf"전체 기호 수는 ${total + variables - 1}$개이다."),
                    ("막대 위치를 선택하는 조합식을 세운다.", rf"$\binom{{{total + variables - 1}}}{{{variables - 1}}}$이다."),
                    ("0인 미지수도 인접한 막대로 자연스럽게 포함됨을 확인한다.", "음이 아닌 모든 정수해가 정확히 한 배열에 대응한다."),
                    ("조합값을 약분해 계산한다.", rf"계산 결과는 ${answer}$이다."),
                    ("작은 합에서 직접 나열하는 방식과 대응을 검산한다.", rf"따라서 정수해는 ${answer}$개이다."),
                ],
                alternatives=[
                    "$y_i=x_i+1$로 바꾸어 양의 정수해 공식으로 환원할 수 있다.",
                    "첫 미지수 값을 고정하고 남은 합의 해 개수를 재귀적으로 더할 수 있다.",
                ],
                answer_check=lambda n=total, k=variables: _nonnegative_solution_count(n, k),
            )
        )
    tangent_rows = [(1, 2, -3, 4), (2, -1, 5, 4), (-1, 3, 2, 2), (3, -2, -4, 6), (2, 4, 1, -4)]
    for index, (quadratic, horizontal, vertical, slope) in enumerate(tangent_rows, 6):
        tangent_x = Fraction(2 * quadratic * horizontal + slope, 2 * quadratic)
        answer = _parallel_tangent_intercept(quadratic, horizontal, vertical, slope)
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"포물선 $y=({quadratic})(x-({horizontal}))^2+({vertical})$에 접하고 직선 $y=({slope})x$와 평행한 직선을 $y=({slope})x+n$이라 할 때 n을 구하시오.",
                answer=str(answer),
                tags=["#포물선", "#중근조건", "#평행조건", "#이차함수와이차방정식", "#접선의방정식"],
                steps=[
                    ("평행한 직선은 같은 기울기를 가지므로 y=mx+n 꼴을 유지한다.", rf"기울기는 ${slope}$이다."),
                    ("포물선과 직선의 교점 방정식을 세운다.", rf"$({quadratic})(x-({horizontal}))^2+({vertical})=({slope})x+n$이다."),
                    ("접할 때 교점 이차방정식이 중근을 가짐을 이용한다.", "판별식을 0으로 두거나 꼭짓점 조건을 적용한다."),
                    ("포물선의 미분계수를 직선 기울기와 같게 둔다.", rf"접점의 x좌표는 ${tangent_x}$이다."),
                    ("접점의 함수값에서 기울기와 x좌표의 곱을 빼 n을 구한다.", rf"$n=f({tangent_x})-({slope})({tangent_x})$이다."),
                    ("교점 방정식에 대입해 중근이 되는지 검산한다.", rf"따라서 $n={answer}$이다."),
                ],
                alternatives=[
                    "교점 이차방정식을 전개한 뒤 판별식 D=0을 직접 풀 수 있다.",
                    "포물선 꼭짓점에서 기울기만큼 이동한 접점을 기하적으로 구해 점기울기식을 세울 수 있다.",
                ],
                answer_check=lambda a=quadratic, h=horizontal, k=vertical, m=slope: _parallel_tangent_intercept(a, h, k, m),
            )
        )
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v38 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v38 전체 카탈로그다. 작동 원리는 독립 정답 검산 후 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog = build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v38 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(
        catalog,
        expected_count=50,
        batch_id=BATCH_ID,
        model_name=MODEL_NAME,
        codebase_base=CODEBASE_BASE,
        seed_base=SEED_BASE,
    )


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v38 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(
        db_path,
        quests=validated_quests(),
        batch_id=BATCH_ID,
        validate_only=validate_only,
    )


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v38 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
