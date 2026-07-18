from __future__ import annotations

import argparse
import json
import sys
from fractions import Fraction
from pathlib import Path
from typing import Any, Callable

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.marketplace_problem_batch import seed_problem_batch, validate_problem_batch
from scripts.seed_initial_math_problems import _problem

BATCH_ID = "marketplace-original-v29"
MODEL_NAME = "aiflow-direct-authoring-v29"
CODEBASE_BASE = 20_260_990_000
SEED_BASE = 202_607_569_000


def _checked_problem(
    tier: int,
    index: int,
    *,
    answer_check: Callable[[], Any],
    **kwargs: Any,
) -> dict[str, Any]:
    """필요 변수는 문제 명세와 독립 계산 함수다. 작동 원리는 저장 답과 별도 계산 결과를 공통 검증기가 비교하도록 검산 함수를 부착한다."""
    spec = _problem(tier, index, **kwargs)
    spec["answer_check"] = answer_check
    return spec


def _matrix_combination_trace(
    left: tuple[tuple[int, int], tuple[int, int]],
    right: tuple[tuple[int, int], tuple[int, int]],
    left_scale: int,
    right_scale: int,
) -> int:
    """필요 변수는 두 2차 정사각행렬과 두 배수다. 작동 원리는 선형결합의 주대각 성분만 계산해 대각합을 구한다."""
    return sum(
        left_scale * left[index][index] + right_scale * right[index][index]
        for index in range(2)
    )


def _conjugate_polynomial_constant(real: int, imaginary: int) -> int:
    """필요 변수는 복소수의 실수부와 허수부다. 작동 원리는 켤레인 두 근의 곱으로 실수 이차다항식의 상수항을 구한다."""
    return real * real + imaginary * imaginary


def _division_midpoint_sum(
    first: tuple[int, int],
    second: tuple[int, int],
    first_ratio: int,
    second_ratio: int,
) -> Fraction:
    """필요 변수는 두 점과 내·외분비다. 작동 원리는 내분점과 외분점을 구한 뒤 두 점의 중점 좌표 합을 계산한다."""
    if first_ratio <= 0 or second_ratio <= 0 or first_ratio == second_ratio:
        raise ValueError("양수이면서 서로 다른 내·외분비가 필요합니다.")
    internal_x = Fraction(
        second_ratio * first[0] + first_ratio * second[0],
        first_ratio + second_ratio,
    )
    internal_y = Fraction(
        second_ratio * first[1] + first_ratio * second[1],
        first_ratio + second_ratio,
    )
    external_x = Fraction(
        -second_ratio * first[0] + first_ratio * second[0],
        first_ratio - second_ratio,
    )
    external_y = Fraction(
        -second_ratio * first[1] + first_ratio * second[1],
        first_ratio - second_ratio,
    )
    return (internal_x + internal_y + external_x + external_y) / 2


def _cube_factor_coefficient_sum(constant: int) -> int:
    """필요 변수는 세제곱할 상수다. 작동 원리는 x³+c³의 이차인수 x²-cx+c²에서 모든 계수의 합을 구한다."""
    return 1 - constant + constant * constant


def _exponential_solution(base: int, shift: int, root_degree: int, exponent: int) -> int:
    """필요 변수는 밑·지수 이동량·근호 차수·목표 지수다. 작동 원리는 양의 밑의 일대일성을 적용해 지수방정식을 푼다."""
    if base <= 1 or root_degree <= 0:
        raise ValueError("지수방정식의 밑과 근호 차수가 올바르지 않습니다.")
    return root_degree * exponent - shift


def _common_log_integer_count(
    shift: int,
    exponent: int,
    relation: str,
    lower: int,
    upper: int,
) -> int:
    """필요 변수는 진수 이동량·기준 지수·부등호·정수 범위다. 작동 원리는 정의역과 10의 거듭제곱 부등식을 모든 정수에 적용한다."""
    comparisons: dict[str, Callable[[int, int], bool]] = {
        "<": lambda left, right: left < right,
        "<=": lambda left, right: left <= right,
        ">": lambda left, right: left > right,
        ">=": lambda left, right: left >= right,
    }
    if relation not in comparisons or lower > upper:
        raise ValueError("상용로그 부등식 조건이 올바르지 않습니다.")
    threshold = 10**exponent
    return sum(
        x - shift > 0 and comparisons[relation](x - shift, threshold)
        for x in range(lower, upper + 1)
    )


def _affine_inverse_intersection_sum(slope: int, intercept: int) -> Fraction:
    """필요 변수는 일차함수의 기울기와 절편이다. 작동 원리는 함수와 역함수의 교점이 y=x 위에 있음을 이용해 좌표 합을 구한다."""
    if slope == 0 or slope == 1:
        raise ValueError("역함수가 존재하고 유일한 교점을 갖는 기울기가 필요합니다.")
    coordinate = Fraction(intercept, 1 - slope)
    return 2 * coordinate


def _quadratic_extreme_sum(
    scale: int,
    axis: int,
    vertical: int,
    lower: int,
    upper: int,
) -> int:
    """필요 변수는 꼭짓점형 이차함수와 닫힌구간이다. 작동 원리는 꼭짓점과 양 끝점의 함수값을 비교해 최댓값과 최솟값을 더한다."""
    if scale == 0 or lower > upper:
        raise ValueError("이차함수와 구간 조건이 올바르지 않습니다.")
    candidates = [
        scale * (lower - axis) ** 2 + vertical,
        scale * (upper - axis) ** 2 + vertical,
    ]
    if lower <= axis <= upper:
        candidates.append(vertical)
    return min(candidates) + max(candidates)


def _union_complement_probability(
    first: Fraction,
    second: Fraction,
    intersection: Fraction,
) -> Fraction:
    """필요 변수는 두 사건과 교집합의 확률이다. 작동 원리는 합의 법칙으로 합사건을 구하고 전체에서 빼 여집합 확률을 계산한다."""
    union = first + second - intersection
    if not 0 <= intersection <= min(first, second) or not 0 <= union <= 1:
        raise ValueError("사건 확률 조건이 올바르지 않습니다.")
    return 1 - union


def _antiderivative_target(
    derivative: tuple[int, int, int, int],
    known_x: int,
    known_value: int,
    target_x: int,
) -> Fraction:
    """필요 변수는 삼차 도함수 계수·초기점 함수값·목표점이다. 작동 원리는 두 점 사이 도함수 정적분을 정확한 분수로 계산해 초기값에 더한다."""
    def primitive(value: int) -> Fraction:
        """필요 변수는 원시함수를 평가할 정수다. 작동 원리는 각 거듭제곱항의 지수를 올리고 새 지수로 나눈다."""
        a, b, c, d = derivative
        return (
            Fraction(a * value**4, 4)
            + Fraction(b * value**3, 3)
            + Fraction(c * value**2, 2)
            + d * value
        )

    return Fraction(known_value, 1) + primitive(target_x) - primitive(known_x)


def _matrix_text(matrix: tuple[tuple[int, int], tuple[int, int]]) -> str:
    """필요 변수는 2차 정사각행렬이다. 작동 원리는 본문에 사용할 LaTeX 행렬 문자열로 변환한다."""
    return rf"\begin{{pmatrix}}{matrix[0][0]}&{matrix[0][1]}\\{matrix[1][0]}&{matrix[1][1]}\end{{pmatrix}}"


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 행렬의 선형결합과 켤레인 복소수 근이다. 작동 원리는 행렬 대각합과 실수 다항식 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    matrix_rows = [
        (((1, 2), (3, 4)), ((5, -1), (2, 0)), 2, -1),
        (((-2, 3), (1, 5)), ((4, 2), (-3, 1)), -1, 3),
        (((0, -4), (6, 2)), ((3, 7), (1, -5)), 4, 2),
        (((5, 1), (-2, -3)), ((-1, 6), (4, 2)), 3, -2),
        (((2, 8), (0, 7)), ((6, -3), (5, -4)), -2, -1),
    ]
    for index, (left, right, left_scale, right_scale) in enumerate(matrix_rows, 1):
        first_diagonal = left_scale * left[0][0] + right_scale * right[0][0]
        second_diagonal = left_scale * left[1][1] + right_scale * right[1][1]
        answer = _matrix_combination_trace(left, right, left_scale, right_scale)
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"행렬 $A={_matrix_text(left)}$, $B={_matrix_text(right)}$에 대하여 ${left_scale}A+({right_scale})B$의 대각합을 구하시오.",
                answer=str(answer),
                tags=["#행렬", "#행렬의뺄셈", "#행렬의연산", "#행렬의정의"],
                steps=[
                    ("선형결합의 두 주대각 성분을 계산한다.", rf"두 성분은 ${first_diagonal}$, ${second_diagonal}$이다."),
                    ("두 주대각 성분을 더한다.", rf"따라서 대각합은 ${answer}$이다."),
                ],
                answer_check=lambda a=left, b=right, u=left_scale, v=right_scale: _matrix_combination_trace(a, b, u, v),
            )
        )
    complex_rows = [(2, 3), (-1, 4), (5, -2), (-3, -3), (4, 1)]
    for index, (real, imaginary) in enumerate(complex_rows, 6):
        answer = _conjugate_polynomial_constant(real, imaginary)
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"복소수 $z={real}+({imaginary})i$와 켤레복소수 $\overline z$를 두 근으로 갖는 최고차항 계수가 1인 이차다항식의 상수항을 구하시오.",
                answer=str(answer),
                tags=["#복소수", "#실수와허수", "#켤레복소수"],
                steps=[
                    ("두 근의 곱을 상수항과 연결한다.", r"최고차항 계수가 1인 이차다항식의 상수항은 두 근의 곱이다."),
                    ("켤레복소수의 곱을 제곱합으로 계산한다.", rf"$z\overline z={real}^2+({imaginary})^2={answer}$이다."),
                ],
                answer_check=lambda a=real, b=imaginary: _conjugate_polynomial_constant(a, b),
            )
        )
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 점의 내·외분비와 세제곱 합 인수분해다. 작동 원리는 좌표 기하와 인수분해 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    point_rows = [
        ((0, 0), (6, 3), 2, 1),
        ((-2, 1), (4, 7), 3, 1),
        ((1, -3), (7, 5), 4, 2),
        ((-4, 2), (2, -6), 5, 2),
        ((3, 1), (-5, 9), 3, 2),
    ]
    for index, (first, second, first_ratio, second_ratio) in enumerate(point_rows, 1):
        answer = _division_midpoint_sum(first, second, first_ratio, second_ratio)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"두 점 $A({first[0]},{first[1]})$, $B({second[0]},{second[1]})$에 대하여 선분 AB를 ${first_ratio}:{second_ratio}$로 내분하는 점 P와 외분하는 점 Q의 중점을 R라 할 때, R의 두 좌표의 합을 구하시오.",
                answer=str(answer),
                tags=["#선분의내분점", "#외분점", "#중점", "#내분점공식"],
                steps=[
                    ("내분점 공식으로 P의 좌표를 구한다.", rf"$P=\dfrac{{{second_ratio}A+{first_ratio}B}}{{{first_ratio + second_ratio}}}$이다."),
                    ("외분점 공식으로 Q의 좌표를 구한다.", rf"$Q=\dfrac{{-{second_ratio}A+{first_ratio}B}}{{{first_ratio - second_ratio}}}$이다."),
                    ("P와 Q의 중점 좌표를 구해 더한다.", rf"따라서 R의 두 좌표의 합은 ${answer}$이다."),
                ],
                answer_check=lambda a=first, b=second, m=first_ratio, n=second_ratio: _division_midpoint_sum(a, b, m, n),
            )
        )
    for index, constant in enumerate([2, 3, -2, 4, -3], 6):
        answer = _cube_factor_coefficient_sum(constant)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"세제곱 합 $x^3+({constant})^3$을 일차인수와 이차인수의 곱으로 인수분해했을 때, 이차인수의 모든 계수의 합을 구하시오.",
                answer=str(answer),
                tags=["#세제곱공식", "#인수분해", "#인수분해공식", "#인수분해법"],
                steps=[
                    ("세제곱 합 공식을 확인한다.", r"$a^3+b^3=(a+b)(a^2-ab+b^2)$이다."),
                    ("a=x, b=상수를 대입한다.", rf"이차인수는 $x^2-({constant})x+({constant**2})$이다."),
                    ("이차인수의 세 계수를 더한다.", rf"따라서 계수의 합은 ${answer}$이다."),
                ],
                answer_check=lambda value=constant: _cube_factor_coefficient_sum(value),
            )
        )
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 유리수 지수방정식과 상용로그 부등식이다. 작동 원리는 지수 확장과 로그 단조성 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    exponential_rows = [
        (2, 3, 2, 5),
        (3, -1, 3, 4),
        (5, 4, 2, 6),
        (4, -2, 4, 3),
        (10, 5, 5, 2),
    ]
    for index, (base, shift, root_degree, exponent) in enumerate(exponential_rows, 1):
        answer = _exponential_solution(base, shift, root_degree, exponent)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"지수방정식 $\sqrt[{root_degree}]{{{base}^{{x+({shift})}}}}={base}^{exponent}$을 만족하는 실수 x를 구하시오.",
                answer=str(answer),
                tags=["#지수", "#정수지수", "#유리수지수", "#실수지수", "#지수의확장"],
                steps=[
                    ("근호를 유리수 지수로 바꾼다.", rf"왼쪽은 ${base}^{{(x+({shift}))/{root_degree}}}$이다."),
                    ("양변의 밑이 같고 1보다 큼을 확인한다.", rf"밑 ${base}$의 지수함수는 일대일함수이다."),
                    ("두 지수를 같게 둔다.", rf"$\dfrac{{x+({shift})}}{{{root_degree}}}={exponent}$이다."),
                    ("일차방정식을 푼다.", rf"따라서 $x={answer}$이다."),
                ],
                alternatives=["양변을 root_degree제곱한 뒤 같은 밑의 지수를 비교할 수 있다."],
                answer_check=lambda a=base, p=shift, q=root_degree, r=exponent: _exponential_solution(a, p, q, r),
            )
        )
    logarithm_rows = [
        (0, 1, "<", 1, 15),
        (2, 1, ">=", 0, 18),
        (-3, 2, "<=", -5, 110),
        (5, 1, ">", 0, 22),
        (-1, 2, "<", -3, 105),
    ]
    for index, (shift, exponent, relation, lower, upper) in enumerate(logarithm_rows, 6):
        answer = _common_log_integer_count(shift, exponent, relation, lower, upper)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"정수 범위 ${lower}\le x\le {upper}$에서 상용로그 부등식 $\log(x-({shift})){relation}{exponent}$을 만족하는 정수 x의 개수를 구하시오.",
                answer=str(answer),
                tags=["#상용로그", "#로그부등식", "#로그방정식과로그부등식", "#로그의성질"],
                steps=[
                    ("로그의 진수가 양수인 정의역을 구한다.", rf"$x-({shift})>0$이어야 한다."),
                    ("상용로그 함수가 증가함수임을 이용한다.", rf"로그 부등식을 $x-({shift}){relation}10^{exponent}$로 바꾼다."),
                    ("정의역·변환한 부등식·주어진 정수 범위를 교차한다.", "세 조건을 동시에 만족하는 정수만 남긴다."),
                    ("남은 정수의 개수를 센다.", rf"따라서 조건을 만족하는 정수는 ${answer}$개이다."),
                ],
                alternatives=["주어진 정수 범위를 직접 순회하며 진수 조건과 10의 거듭제곱 경계를 함께 검사할 수 있다."],
                answer_check=lambda h=shift, power=exponent, op=relation, low=lower, high=upper: _common_log_integer_count(h, power, op, low, high),
            )
        )
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 일차함수와 역함수, 꼭짓점형 이차함수다. 작동 원리는 대칭 교점과 구간 극값 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    inverse_rows = [(2, 3), (-1, 4), (3, -6), (-2, 5), (Fraction(1, 2), 3)]
    for index, (slope, intercept) in enumerate(inverse_rows, 1):
        answer = _affine_inverse_intersection_sum(slope, intercept)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"일대일함수 $f(x)={slope}x+({intercept})$의 그래프와 역함수 $y=f^{{-1}}(x)$의 그래프가 만나는 점의 두 좌표의 합을 구하시오.",
                answer=str(answer),
                tags=["#역함수구하기", "#역함수의그래프", "#일대일함수", "#직선대칭", "#대응"],
                steps=[
                    ("함수와 역함수의 그래프 관계를 확인한다.", r"두 그래프는 직선 $y=x$에 대하여 대칭이다."),
                    ("유일한 교점은 y=x 위에 있음을 이용한다.", "교점에서는 f(x)=x가 성립한다."),
                    ("일차방정식을 세운다.", rf"${slope}x+({intercept})=x$이다."),
                    ("교점의 x좌표와 y좌표가 같음을 적용한다.", rf"두 좌표는 각각 ${answer / 2}$이다."),
                    ("두 좌표를 더한다.", rf"따라서 좌표의 합은 ${answer}$이다."),
                ],
                alternatives=["역함수 식을 직접 구한 뒤 두 일차함수의 연립방정식을 풀 수 있다."],
                answer_check=lambda m=slope, b=intercept: _affine_inverse_intersection_sum(m, b),
            )
        )
    quadratic_rows = [
        (1, 2, -3, -1, 5),
        (2, -1, 1, -4, 3),
        (-1, 3, 5, 0, 7),
        (-2, 0, 4, -3, 2),
        (3, 1, -2, -2, 4),
    ]
    for index, (scale, axis, vertical, lower, upper) in enumerate(quadratic_rows, 6):
        lower_value = scale * (lower - axis) ** 2 + vertical
        upper_value = scale * (upper - axis) ** 2 + vertical
        answer = _quadratic_extreme_sum(scale, axis, vertical, lower, upper)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"닫힌구간 $[{lower},{upper}]$에서 이차함수 $f(x)={scale}(x-({axis}))^2+({vertical})$의 최댓값과 최솟값의 합을 구하시오.",
                answer=str(answer),
                tags=["#정의역에서의최대최소", "#최댓값", "#최솟값", "#축", "#포물선"],
                steps=[
                    ("포물선의 꼭짓점과 축을 확인한다.", rf"꼭짓점은 $({axis},{vertical})$이고 축은 $x={axis}$이다."),
                    ("꼭짓점이 주어진 구간 안에 있는지 확인한다.", rf"${lower}\le {axis}\le {upper}$이다."),
                    ("구간 양 끝점의 함수값을 계산한다.", rf"$f({lower})={lower_value}$, $f({upper})={upper_value}$이다."),
                    ("꼭짓점과 양 끝점의 함수값을 비교한다.", "위로 또는 아래로 열린 방향을 함께 고려해 극값을 판정한다."),
                    ("최댓값과 최솟값을 더한다.", rf"따라서 두 극값의 합은 ${answer}$이다."),
                ],
                alternatives=["축에서의 거리와 이차항 계수의 부호를 이용해 함수값의 대소를 비교할 수 있다."],
                answer_check=lambda a=scale, h=axis, k=vertical, left=lower, right=upper: _quadratic_extreme_sum(a, h, k, left, right),
            )
        )
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 사건의 확률과 삼차 도함수 초기값이다. 작동 원리는 합사건의 여집합과 부정적분 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    probability_rows = [
        (Fraction(1, 2), Fraction(1, 3), Fraction(1, 6)),
        (Fraction(2, 5), Fraction(1, 2), Fraction(1, 5)),
        (Fraction(3, 4), Fraction(2, 3), Fraction(1, 2)),
        (Fraction(1, 3), Fraction(1, 4), Fraction(1, 12)),
        (Fraction(3, 5), Fraction(1, 2), Fraction(3, 10)),
    ]
    for index, (first, second, intersection) in enumerate(probability_rows, 1):
        union = first + second - intersection
        answer = _union_complement_probability(first, second, intersection)
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"두 사건 A, B에 대하여 $P(A)={first}$, $P(B)={second}$, $P(A\cap B)={intersection}$이다. A와 B가 모두 일어나지 않을 확률을 구하시오.",
                answer=str(answer),
                tags=["#사건의합", "#사건의곱", "#여집합", "#합의법칙"],
                steps=[
                    ("A와 B가 모두 일어나지 않는 사건을 집합 기호로 나타낸다.", r"구하는 사건은 $(A\cup B)^c$이다."),
                    ("합사건의 확률 공식을 세운다.", r"$P(A\cup B)=P(A)+P(B)-P(A\cap B)$이다."),
                    ("주어진 세 확률을 대입한다.", rf"$P(A\cup B)={first}+({second})-({intersection})$이다."),
                    ("합사건의 확률을 계산한다.", rf"$P(A\cup B)={union}$이다."),
                    ("여집합의 확률 공식을 적용한다.", r"$P((A\cup B)^c)=1-P(A\cup B)$이다."),
                    ("1에서 합사건의 확률을 뺀다.", rf"따라서 구하는 확률은 ${answer}$이다."),
                ],
                alternatives=[
                    "전체 표본공간을 A만, B만, 교집합, 둘 다 아닌 영역으로 분할해 계산할 수 있다.",
                    "벤다이어그램에 각 영역의 확률을 채운 뒤 남는 바깥 영역을 구할 수 있다.",
                ],
                answer_check=lambda a=first, b=second, overlap=intersection: _union_complement_probability(a, b, overlap),
            )
        )
    integral_rows = [
        ((4, 3, 2, 1), 0, 5, 2),
        ((3, -6, 4, -2), 0, 1, 2),
        ((2, 0, -6, 3), 1, -2, 4),
        ((-4, 6, 2, -1), -1, 3, 2),
        ((1, -3, 6, 0), 2, -4, 5),
    ]
    for index, (derivative, known_x, known_value, target_x) in enumerate(integral_rows, 6):
        answer = _antiderivative_target(derivative, known_x, known_value, target_x)
        derivative_text = rf"{derivative[0]}x^3+({derivative[1]})x^2+({derivative[2]})x+({derivative[3]})"
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"미분가능한 함수 f가 $f'(x)={derivative_text}$, $f({known_x})={known_value}$를 만족할 때 $f({target_x})$의 값을 부정적분으로 구하시오.",
                answer=str(answer),
                tags=["#부정적분공식", "#부정적분의성질", "#부정적분의정의", "#합차의미분"],
                steps=[
                    ("도함수의 각 항을 부정적분한다.", "거듭제곱항의 지수를 1 올리고 새 지수로 나눈다."),
                    ("적분상수 C를 포함한 f(x)를 나타낸다.", r"$f(x)=\int f'(x)dx+C$이다."),
                    ("주어진 초기 함수값을 대입한다.", rf"$f({known_x})={known_value}$를 이용해 C를 정한다."),
                    ("목표 x값을 복원한 함수에 대입한다.", rf"$x={target_x}$에서 각 항을 계산한다."),
                    ("초기점부터 목표점까지의 도함수 정적분으로도 확인한다.", rf"$f({target_x})-f({known_x})=\int_{{{known_x}}}^{{{target_x}}}f'(x)dx$이다."),
                    ("초기값과 변화량을 더한다.", rf"따라서 $f({target_x})={answer}$이다."),
                ],
                alternatives=[
                    "적분상수를 구하지 않고 미적분의 기본정리로 두 함수값의 차를 바로 계산할 수 있다.",
                    "구한 f(x)를 다시 미분해 주어진 f'(x)와 모든 계수가 일치하는지 검산할 수 있다.",
                ],
                answer_check=lambda coefficients=derivative, x0=known_x, y0=known_value, x1=target_x: _antiderivative_target(coefficients, x0, y0, x1),
            )
        )
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v29 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v29 전체 카탈로그다. 작동 원리는 독립 정답 검산 후 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog = build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v29 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(
        catalog,
        expected_count=50,
        batch_id=BATCH_ID,
        model_name=MODEL_NAME,
        codebase_base=CODEBASE_BASE,
        seed_base=SEED_BASE,
    )


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v29 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(
        db_path,
        quests=validated_quests(),
        batch_id=BATCH_ID,
        validate_only=validate_only,
    )


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v29 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(
        json.dumps(
            seed_database(args.db, validate_only=args.validate_only),
            ensure_ascii=False,
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
