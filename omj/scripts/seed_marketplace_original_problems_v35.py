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

BATCH_ID = "marketplace-original-v35"
MODEL_NAME = "aiflow-direct-authoring-v35"
CODEBASE_BASE = 20_260_996_000
SEED_BASE = 202_607_575_000


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


def _line_y_intercept(point: tuple[int, int], slope: int) -> int:
    """필요 변수는 직선 위의 점과 기울기다. 작동 원리는 y=mx+b에 점을 대입해 y절편 b를 구한다."""
    return point[1] - slope * point[0]


def _unused_codomain_sum(
    domain: tuple[int, ...],
    codomain: tuple[int, ...],
    multiplier: int,
    offset: int,
) -> int:
    """필요 변수는 정의역·공역과 일차 대응식이다. 작동 원리는 정의역의 상을 집합으로 구한 뒤 공역에서 빠진 원소를 더한다."""
    images = {multiplier * value + offset for value in domain}
    codomain_set = set(codomain)
    if not images <= codomain_set:
        raise ValueError("모든 함숫값이 공역에 포함되어야 합니다.")
    return sum(codomain_set - images)


def _root_square_sum(quadratic: int, linear: int, constant: int) -> Fraction:
    """필요 변수는 이차방정식의 세 계수다. 작동 원리는 근과 계수 관계로 두 근의 제곱합을 계산한다."""
    if quadratic == 0 or linear**2 - 4 * quadratic * constant < 0:
        raise ValueError("실근을 갖는 이차방정식이어야 합니다.")
    root_sum = Fraction(-linear, quadratic)
    root_product = Fraction(constant, quadratic)
    return root_sum**2 - 2 * root_product


def _constrained_subset_count(total: int, required: int, excluded: int) -> int:
    """필요 변수는 전체 원소 수·반드시 포함할 수·반드시 제외할 수다. 작동 원리는 자유 원소마다 포함 여부 두 가지를 곱한다."""
    free = total - required - excluded
    if min(total, required, excluded, free) < 0:
        raise ValueError("부분집합 조건의 원소 수가 올바르지 않습니다.")
    return 2**free


def _geometric_middle(first: int, third: int) -> int:
    """필요 변수는 양의 등비수열에서 한 칸 떨어진 두 항이다. 작동 원리는 등비중항의 제곱이 두 항의 곱임을 이용한다."""
    product = first * third
    root = math.isqrt(product)
    if first <= 0 or third <= 0 or root * root != product:
        raise ValueError("양의 정수 등비중항이 존재해야 합니다.")
    return root


def _shifted_log_zero(base: int, horizontal: int, vertical: int) -> Fraction:
    """필요 변수는 로그 밑·수평 이동량·수직 이동량이다. 작동 원리는 함수값을 0으로 두고 지수식으로 바꿔 x절편을 구한다."""
    if base <= 1:
        raise ValueError("로그 밑은 1보다 커야 합니다.")
    return Fraction(horizontal, 1) + Fraction(base, 1) ** (-vertical)


def _radical_limit(point: int, constant: int) -> Fraction:
    """필요 변수는 극한점과 근호 안 상수다. 작동 원리는 켤레식을 곱해 약분한 뒤 극한점에서 값을 계산한다."""
    radicand = point + constant
    root = math.isqrt(radicand)
    if radicand <= 0 or root * root != radicand:
        raise ValueError("극한점의 근호값은 양의 정수여야 합니다.")
    return Fraction(1, 2 * root)


def _rational_discontinuity_sum(
    canceled_root: int,
    pole: int,
    lower: int,
    upper: int,
) -> int:
    """필요 변수는 약분되는 근·수직점근선의 근·검사 구간이다. 작동 원리는 구간 안에서 원래 분모가 0인 서로 다른 점을 더한다."""
    if canceled_root == pole or lower > upper:
        raise ValueError("서로 다른 두 분모 영점과 올바른 구간이 필요합니다.")
    return sum({root for root in (canceled_root, pole) if lower <= root <= upper})


def _solve_linear_system(
    matrix: tuple[tuple[int, int, int], ...],
    target: tuple[int, int, int],
) -> tuple[Fraction, Fraction, Fraction]:
    """필요 변수는 3×3 계수행렬과 상수열이다. 작동 원리는 정확한 분수 가우스 소거로 피벗을 정규화하고 해를 반환한다."""
    augmented = [
        [Fraction(value, 1) for value in (*row, target[index])]
        for index, row in enumerate(matrix)
    ]
    for column in range(3):
        pivot = next((row for row in range(column, 3) if augmented[row][column] != 0), None)
        if pivot is None:
            raise ValueError("유일한 해를 갖는 연립방정식이어야 합니다.")
        augmented[column], augmented[pivot] = augmented[pivot], augmented[column]
        pivot_value = augmented[column][column]
        augmented[column] = [value / pivot_value for value in augmented[column]]
        for row in range(3):
            if row == column:
                continue
            factor = augmented[row][column]
            augmented[row] = [
                current - factor * pivot_current
                for current, pivot_current in zip(augmented[row], augmented[column])
            ]
    return tuple(augmented[index][3] for index in range(3))  # type: ignore[return-value]


def _linear_system_solution_sum(
    matrix: tuple[tuple[int, int, int], ...],
    target: tuple[int, int, int],
) -> Fraction:
    """필요 변수는 3원 일차연립방정식의 계수와 상수열이다. 작동 원리는 가우스 소거로 구한 세 해를 더한다."""
    return sum(_solve_linear_system(matrix, target), Fraction(0, 1))


def _partial_fraction_integral(offset: int, upper: int) -> str:
    """필요 변수는 연속한 두 분모 상수와 적분 위끝이다. 작동 원리는 부분분수 적분 결과의 로그 안 비율을 정확한 분수로 계산한다."""
    if offset <= 0 or upper <= 0:
        raise ValueError("분모 상수와 적분 위끝은 양수여야 합니다.")
    second = offset + 1
    ratio = Fraction((upper + offset) * second, offset * (upper + second))
    return f"ln({ratio})"


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 점기울기 직선과 유한집합 함수다. 작동 원리는 y절편과 공역의 남는 원소 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    line_rows = [((2, 7), 3), ((-3, 4), -2), ((5, -1), 4), ((-2, -5), 3), ((4, 9), -3)]
    for index, (point, slope) in enumerate(line_rows, 1):
        answer = _line_y_intercept(point, slope)
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"점 $P{point}$를 지나고 기울기가 {slope}인 직선의 y절편을 구하시오.",
                answer=str(answer),
                tags=["#y절편", "#절편", "#점기울기형", "#기울기"],
                steps=[
                    ("직선을 점기울기형 또는 y=mx+b 꼴로 나타낸다.", rf"${point[1]}=({slope})({point[0]})+b$이다."),
                    ("일차방정식을 풀어 y절편을 구한다.", rf"따라서 y절편은 ${answer}$이다."),
                ],
                answer_check=lambda p=point, m=slope: _line_y_intercept(p, m),
            )
        )
    mapping_rows = [
        ((0, 1, 2), (1, 3, 5, 7), 2, 1),
        ((-1, 0, 1), (-5, -2, 1, 4, 7), 3, 1),
        ((1, 2, 3), (0, 2, 4, 6, 8), 2, 0),
        ((-2, 0, 2), (-7, -3, 1, 5, 9), 2, 1),
        ((0, 2, 4), (-1, 2, 5, 8, 11), 3, -1),
    ]
    for index, (domain, codomain, multiplier, offset) in enumerate(mapping_rows, 6):
        images = sorted({multiplier * value + offset for value in domain})
        unused = sorted(set(codomain) - set(images))
        answer = _unused_codomain_sum(domain, codomain, multiplier, offset)
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"함수 $f:A\to B$에서 $A=\{{{','.join(map(str, domain))}\}}$, $B=\{{{','.join(map(str, codomain))}\}}$이고 $f(x)=({multiplier})x+({offset})$이다. 공역 B에서 치역에 속하지 않는 원소의 합을 구하시오.",
                answer=str(answer),
                tags=["#공역", "#대응", "#함수", "#원소나열법"],
                steps=[
                    ("정의역의 각 원소를 대응식에 대입해 치역을 구한다.", rf"치역은 $\{{{','.join(map(str, images))}\}}$이다."),
                    ("공역에서 치역 원소를 제외하고 더한다.", rf"남는 원소 $\{{{','.join(map(str, unused))}\}}$의 합은 ${answer}$이다."),
                ],
                answer_check=lambda a=domain, b=codomain, m=multiplier, c=offset: _unused_codomain_sum(a, b, m, c),
            )
        )
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 실근 이차방정식과 원소 포함·제외 조건이다. 작동 원리는 근과 계수 및 부분집합 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    quadratic_rows = [(1, -5, 6), (2, -7, 3), (3, 1, -2), (2, 5, -3), (4, -4, -3)]
    for index, (a, b, c) in enumerate(quadratic_rows, 1):
        root_sum = Fraction(-b, a)
        root_product = Fraction(c, a)
        answer = _root_square_sum(a, b, c)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"이차방정식 $({a})x^2+({b})x+({c})=0$의 두 실근을 $\alpha,\beta$라 할 때, $\alpha^2+\beta^2$의 값을 구하시오.",
                answer=str(answer),
                tags=["#이차방정식의근과계수", "#두근의합", "#두근의곱", "#실근조건"],
                steps=[
                    ("근과 계수의 관계로 두 근의 합과 곱을 구한다.", rf"$\alpha+\beta={root_sum}$, $\alpha\beta={root_product}$이다."),
                    ("제곱합 항등식을 적용한다.", r"$\alpha^2+\beta^2=(\alpha+\beta)^2-2\alpha\beta$이다."),
                    ("합과 곱을 대입해 계산한다.", rf"따라서 제곱합은 ${answer}$이다."),
                ],
                answer_check=lambda first=a, second=b, third=c: _root_square_sum(first, second, third),
            )
        )
    subset_rows = [
        ((1, 2, 3, 4, 5, 6), (1, 3), (6,)),
        ((-2, -1, 0, 1, 2, 3, 4), (-2, 0), (3, 4)),
        ((2, 4, 6, 8, 10, 12, 14, 16), (2, 8, 14), (4,)),
        ((1, 3, 5, 7, 9), (5,), (1, 9)),
        ((0, 1, 2, 3, 4, 5, 6), (0, 6), (2,)),
    ]
    for index, (universe, required, excluded) in enumerate(subset_rows, 6):
        free = len(universe) - len(required) - len(excluded)
        answer = _constrained_subset_count(len(universe), len(required), len(excluded))
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"집합 $A=\{{{','.join(map(str, universe))}\}}$의 부분집합 중 $\{{{','.join(map(str, required))}\}}$의 모든 원소를 포함하고 $\{{{','.join(map(str, excluded))}\}}$의 모든 원소를 포함하지 않는 부분집합의 개수를 구하시오.",
                answer=str(answer),
                tags=["#부분집합", "#집합", "#원소나열법", "#공통수학2"],
                steps=[
                    ("반드시 포함할 원소와 제외할 원소를 고정한다.", rf"선택이 자유로운 원소는 ${free}$개이다."),
                    ("각 자유 원소마다 포함·미포함 두 경우가 있음을 이용한다.", rf"경우의 수는 $2^{free}$이다."),
                    ("거듭제곱을 계산한다.", rf"따라서 부분집합은 ${answer}$개이다."),
                ],
                answer_check=lambda total=len(universe), must=len(required), banned=len(excluded): _constrained_subset_count(total, must, banned),
            )
        )
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 등비수열의 두 항과 평행이동한 로그함수다. 작동 원리는 등비중항과 x절편 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    middle_rows = [(2, 18), (3, 48), (4, 100), (8, 72), (12, 75)]
    for index, (first, third) in enumerate(middle_rows, 1):
        answer = _geometric_middle(first, third)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"모든 항이 양수인 등비수열에서 연속한 세 항이 ${first}, a, {third}$일 때 a의 값을 구하시오.",
                answer=str(answer),
                tags=["#등비수열", "#등비중항", "#공비", "#수열"],
                steps=[
                    ("연속한 세 등비수열 항에서 가운데 항의 제곱 관계를 세운다.", rf"$a^2=({first})({third})$이다."),
                    ("두 바깥 항의 곱을 계산한다.", rf"$a^2={first * third}$이다."),
                    ("모든 항이 양수라는 조건을 적용한다.", "a는 양의 제곱근을 택한다."),
                    ("제곱근을 계산한다.", rf"따라서 $a={answer}$이다."),
                ],
                alternatives=["두 항의 비에서 공비를 구한 뒤 첫 항에 공비를 곱할 수 있다."],
                answer_check=lambda a=first, b=third: _geometric_middle(a, b),
            )
        )
    log_rows = [(2, 1, -3), (3, -2, -2), (4, 3, -1), (5, -1, -2), (10, 2, -1)]
    for index, (base, horizontal, vertical) in enumerate(log_rows, 6):
        answer = _shifted_log_zero(base, horizontal, vertical)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"로그함수 $f(x)=\log_{{{base}}}(x-({horizontal}))+({vertical})$의 그래프가 x축과 만나는 점의 x좌표를 구하시오.",
                answer=str(answer),
                tags=["#로그함수", "#로그함수의그래프", "#로그함수의평행이동", "#평행이동", "#진수조건"],
                steps=[
                    ("x축 위에서는 함수값이 0임을 이용한다.", rf"$\log_{{{base}}}(x-({horizontal}))=-({vertical})$이다."),
                    ("로그방정식을 지수식으로 바꾼다.", rf"$x-({horizontal})={base}^{{{-vertical}}}$이다."),
                    ("수평 이동량을 더해 x를 구한다.", rf"$x={answer}$이다."),
                    ("구한 값이 진수조건을 만족하는지 확인한다.", rf"$x-({horizontal})>0$이므로 유효하고 최종 x좌표는 ${answer}$이다."),
                ],
                alternatives=["기본 로그함수 그래프의 점을 수평·수직 이동해 x축 교점을 추적할 수 있다."],
                answer_check=lambda b=base, h=horizontal, v=vertical: _shifted_log_zero(b, h, v),
            )
        )
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 근호 차의 극한과 약분되는 유리함수다. 작동 원리는 유리화와 불연속점 판정 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    radical_rows = [(5, 4), (7, 9), (-2, 11), (10, 15), (1, 24)]
    for index, (point, constant) in enumerate(radical_rows, 1):
        root = math.isqrt(point + constant)
        answer = _radical_limit(point, constant)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"극한 $\lim_{{x\to {point}}}\dfrac{{\sqrt{{x+({constant})}}-\sqrt{{{point + constant}}}}}{{x-({point})}}$의 값을 구하시오.",
                answer=str(answer),
                tags=["#유리화를이용한극한", "#무리식", "#약분", "#극한값계산"],
                steps=[
                    ("분자와 같은 두 근호의 합인 켤레식을 준비한다.", rf"$\sqrt{{x+({constant})}}+\sqrt{{{point + constant}}}$를 곱한다."),
                    ("분자에 합차공식을 적용한다.", rf"분자는 $x+({constant})-({point + constant})=x-({point})$가 된다."),
                    ("분모의 같은 인수를 약분한다.", rf"식은 $1/(\sqrt{{x+({constant})}}+{root})$로 정리된다."),
                    ("약분한 식에 극한점을 대입한다.", rf"분모는 $2\cdot {root}$이다."),
                    ("분수를 기약분수로 정리한다.", rf"따라서 극한값은 ${answer}$이다."),
                ],
                alternatives=["$\sqrt{x}$의 미분계수 공식 $1/(2\sqrt{x})$을 이동된 함수에 적용할 수 있다."],
                answer_check=lambda p=point, c=constant: _radical_limit(p, c),
            )
        )
    discontinuity_rows = [
        (-3, 4, -5, 6, 1),
        (2, -5, -6, 4, 0),
        (-4, 3, -7, 5, 2),
        (1, 6, -2, 8, -1),
        (-6, 2, -8, 4, 3),
    ]
    for index, (canceled, pole, lower, upper, other_root) in enumerate(discontinuity_rows, 6):
        answer = _rational_discontinuity_sum(canceled, pole, lower, upper)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"함수 $f(x)=\dfrac{{(x-({canceled}))(x-({other_root}))}}{{(x-({canceled}))(x-({pole}))}}$의 구간 $[{lower},{upper}]$ 안에 있는 모든 불연속점의 x좌표의 합을 구하시오.",
                answer=str(answer),
                tags=["#불연속", "#연속의정의", "#연속함수의성질", "#유리식과유리함수", "#약분"],
                steps=[
                    ("원래 분모가 0이 되는 두 점을 찾는다.", rf"후보는 $x={canceled}, {pole}$이다."),
                    ("공통인수를 약분해 구간의 일반식을 확인한다.", rf"$x\ne {canceled}$에서 $f(x)=(x-({other_root}))/(x-({pole}))$이다."),
                    ("약분된 점이 원래 함수에서는 정의되지 않음을 확인한다.", rf"$x={canceled}$는 제거가능 불연속점이다."),
                    ("남은 분모 영점은 수직점근선임을 확인한다.", rf"$x={pole}$에서도 불연속이다."),
                    ("구간 안의 두 불연속점 좌표를 더한다.", rf"따라서 합은 ${answer}$이다."),
                ],
                alternatives=["정의역에서 제외되는 점을 먼저 구한 뒤 약분 전후의 식을 비교할 수 있다."],
                answer_check=lambda a=canceled, b=pole, low=lower, high=upper: _rational_discontinuity_sum(a, b, low, high),
            )
        )
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 3원 연립방정식과 연속한 일차인수 적분이다. 작동 원리는 가우스 소거와 부분분수 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    system_rows = [
        (((1, 1, 1), (2, -1, 1), (1, 2, -1)), (6, 3, 2)),
        (((2, 1, -1), (1, 3, 2), (3, -2, 1)), (3, 13, 2)),
        (((1, -2, 3), (2, 1, -1), (3, 1, 2)), (8, -3, 7)),
        (((3, 1, 2), (1, -1, 1), (2, 3, -1)), (4, -2, 9)),
        (((2, -1, 3), (4, 2, -1), (1, 3, 2)), (11, 1, 12)),
    ]
    for index, (matrix, target) in enumerate(system_rows, 1):
        solution = _solve_linear_system(matrix, target)
        answer = _linear_system_solution_sum(matrix, target)
        equations = []
        for row, value in zip(matrix, target):
            equations.append(rf"({row[0]})x+({row[1]})y+({row[2]})z={value}")
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"연립방정식 $\begin{{cases}}{equations[0]}\\{equations[1]}\\{equations[2]}\end{{cases}}$의 해를 $(x,y,z)$라 할 때 $x+y+z$를 구하시오.",
                answer=str(answer),
                tags=["#가우스소거법", "#연립일차방정식과행렬", "#열", "#성분"],
                steps=[
                    ("세 방정식의 계수와 상수를 확대행렬로 나타낸다.", "마지막 열에는 세 상수를 둔다."),
                    ("첫 번째 열의 피벗을 정하고 아래 성분을 0으로 만든다.", "한 행의 배수를 다른 행에서 빼는 기본행연산을 사용한다."),
                    ("두 번째 열의 피벗으로 아래 성분을 0으로 만든다.", "계단형 행렬을 얻는다."),
                    ("마지막 행부터 역대입하거나 위쪽 성분도 0으로 만든다.", "기약행사다리꼴로 정리한다."),
                    ("세 미지수의 값을 읽는다.", rf"$(x,y,z)=({solution[0]},{solution[1]},{solution[2]})$이다."),
                    ("세 해를 더하고 원래 식에 대입해 검산한다.", rf"따라서 $x+y+z={answer}$이다."),
                ],
                alternatives=[
                    "첫 두 방정식과 마지막 두 방정식에서 같은 미지수를 소거해 2원 연립방정식으로 줄일 수 있다.",
                    "가역 계수행렬의 역행렬을 구해 상수열에 곱할 수 있다.",
                ],
                answer_check=lambda coefficients=matrix, values=target: _linear_system_solution_sum(coefficients, values),
            )
        )
    integral_rows = [(1, 1), (2, 2), (3, 1), (4, 3), (5, 2)]
    for index, (offset, upper) in enumerate(integral_rows, 6):
        second = offset + 1
        answer = _partial_fraction_integral(offset, upper)
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"정적분 $\int_0^{{{upper}}}\dfrac{{1}}{{(x+{offset})(x+{second})}}\,dx$의 값을 구하시오.",
                answer=answer,
                tags=["#부분분수", "#유리식과유리함수", "#부정적분공식", "#부정적분의성질", "#정적분의계산"],
                steps=[
                    ("분모의 두 일차인수가 연속한 상수 차이를 가짐을 확인한다.", rf"두 인수의 차는 ${second}-{offset}=1$이다."),
                    ("피적분함수를 부분분수로 분해한다.", rf"$1/((x+{offset})(x+{second}))=1/(x+{offset})-1/(x+{second})$이다."),
                    ("각 부분분수의 부정적분을 구한다.", rf"$\ln(x+{offset})-\ln(x+{second})$이다."),
                    ("적분 위끝과 아래끝을 각각 대입한다.", rf"$[\ln(x+{offset})-\ln(x+{second})]_0^{{{upper}}}$이다."),
                    ("로그의 차를 몫의 로그로 합친다.", rf"$\ln\dfrac{{({upper}+{offset}){second}}}{{({upper}+{second}){offset}}}$이다."),
                    ("로그 안의 분수를 기약분수로 정리한다.", rf"따라서 정적분 값은 ${answer}$이다."),
                ],
                alternatives=[
                    "두 로그의 끝값을 네 항으로 펼친 뒤 같은 밑의 로그끼리 묶을 수 있다.",
                    "부분분수 결과를 미분해 원래 피적분함수로 돌아가는지 먼저 검산할 수 있다.",
                ],
                answer_check=lambda a=offset, end=upper: _partial_fraction_integral(a, end),
            )
        )
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v35 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v35 전체 카탈로그다. 작동 원리는 독립 정답 검산 후 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog = build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v35 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(
        catalog,
        expected_count=50,
        batch_id=BATCH_ID,
        model_name=MODEL_NAME,
        codebase_base=CODEBASE_BASE,
        seed_base=SEED_BASE,
    )


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v35 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(
        db_path,
        quests=validated_quests(),
        batch_id=BATCH_ID,
        validate_only=validate_only,
    )


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v35 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
