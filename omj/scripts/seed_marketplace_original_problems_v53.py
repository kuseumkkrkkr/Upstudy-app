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

BATCH_ID = "marketplace-original-v53"
MODEL_NAME = "aiflow-direct-authoring-v53"
CODEBASE_BASE = 20_261_014_000
SEED_BASE = 202_607_593_000


def _checked_problem(tier: int, index: int, *, answer_check: Callable[[], Any], **kwargs: Any) -> dict[str, Any]:
    """필요 변수는 문제 명세와 독립 계산 함수다. 작동 원리는 저장 답과 별도 계산 결과를 비교하도록 검산 함수를 부착한다."""
    spec = _problem(tier, index, **kwargs)
    spec["answer_check"] = answer_check
    return spec


def _rational_exponent_sum(root: int, positive_power: int, negative_power: int) -> Fraction:
    """필요 변수는 양의 거듭제곱근과 두 유리수 지수의 분자다. 작동 원리는 밑의 거듭제곱근을 기준으로 양·음의 지수를 정확한 분수로 계산한다."""
    if root <= 0 or positive_power < 0 or negative_power <= 0:
        raise ValueError("양의 근과 올바른 지수가 필요합니다.")
    return Fraction(root**positive_power) + Fraction(1, root**negative_power)


def _common_denominator_value(first_pole: int, second_pole: int, argument: int) -> Fraction:
    """필요 변수는 두 분모의 영점과 대입값이다. 작동 원리는 두 유리식을 공통분모로 합친 뒤 정확한 함수값을 계산한다."""
    if argument in {first_pole, second_pole}:
        raise ValueError("분모가 0이 아닌 대입값이 필요합니다.")
    return Fraction(1, argument - first_pole) + Fraction(1, argument - second_pole)


def _parabola_horizontal_chord_length(axis: int, vertical: int, level: int) -> int:
    """필요 변수는 꼭짓점형 포물선과 수평선 높이다. 작동 원리는 교점 방정식의 두 근 차로 수평 현의 길이를 구한다."""
    del axis
    square = level - vertical
    root = math.isqrt(square) if square >= 0 else -1
    if root < 0 or root * root != square:
        raise ValueError("두 교점 거리가 정수가 되는 수평선이 필요합니다.")
    return 2 * root


def _circle_center_radius_expression(linear_x: int, linear_y: int, constant: int) -> Fraction:
    """필요 변수는 원의 일반형 세 계수다. 작동 원리는 완전제곱으로 중심과 반지름 제곱을 복원해 중심 좌표합과 더한다."""
    center_x = Fraction(-linear_x, 2)
    center_y = Fraction(-linear_y, 2)
    radius_squared = center_x**2 + center_y**2 - constant
    if radius_squared <= 0:
        raise ValueError("양의 반지름을 갖는 원이 필요합니다.")
    return center_x + center_y + radius_squared


def _shifted_log_coordinate_sum(base: int, horizontal: int, vertical: int, log_value: int) -> Fraction:
    """필요 변수는 로그함수의 밑·이동량과 교점의 로그값이다. 작동 원리는 교점 x좌표와 수직점근선 x좌표를 더한다."""
    del vertical
    if base <= 0 or base == 1:
        raise ValueError("양수이면서 1이 아닌 로그함수의 밑이 필요합니다.")
    power = Fraction(base**log_value) if log_value >= 0 else Fraction(1, base ** (-log_value))
    return 2 * horizontal + power


def _quartic_nonnegative_root_sum(first_root: int, second_root: int) -> int:
    """필요 변수는 짝수차 다항식의 두 양의 제곱근이다. 작동 원리는 x²에 대한 이차식으로 인수분해해 음이 아닌 근만 더한다."""
    if first_root <= 0 or second_root <= 0 or first_root == second_root:
        raise ValueError("서로 다른 양의 두 근이 필요합니다.")
    return first_root + second_root


def _bounded_stars_and_bars_count(total: int, first_cap: int, second_cap: int) -> int:
    """필요 변수는 네 변수의 합과 앞 두 변수 상한이다. 작동 원리는 상한 안의 두 변수를 순회하고 남은 합의 두 변수 분배 수를 더한다."""
    if min(total, first_cap, second_cap) < 0:
        raise ValueError("0 이상의 합과 상한이 필요합니다.")
    count = 0
    for first in range(first_cap + 1):
        for second in range(second_cap + 1):
            remaining = total - first - second
            if remaining >= 0:
                count += remaining + 1
    return count


def _condition_symmetric_difference_count(
    lower: int,
    upper: int,
    first_radius: int,
    second_center: int,
    second_radius: int,
) -> int:
    """필요 변수는 정수 전체집합과 두 절댓값 구간 조건이다. 작동 원리는 정확히 한 조건만 참인 원소를 세어 필요·충분 관계의 양방향 반례 수를 구한다."""
    if lower > upper or min(first_radius, second_radius) < 0:
        raise ValueError("올바른 정수 범위와 음이 아닌 반지름이 필요합니다.")
    return sum(
        (value * value <= first_radius**2) != (abs(value - second_center) <= second_radius)
        for value in range(lower, upper + 1)
    )


def _linear_sigma_coefficient_sum(index: int, first_sum: int, second_sum: int) -> Fraction:
    """필요 변수는 연속한 두 부분합과 작은 쪽 첨자다. 작동 원리는 Σ(ak+b)의 두 식을 정확한 분수 연립방정식으로 풀어 a+b를 구한다."""
    if index <= 0:
        raise ValueError("양의 부분합 첨자가 필요합니다.")
    first_linear = Fraction(index * (index + 1), 2)
    first_constant = Fraction(index)
    next_index = index + 1
    second_linear = Fraction(next_index * (next_index + 1), 2)
    second_constant = Fraction(next_index)
    determinant = first_linear * second_constant - second_linear * first_constant
    coefficient_a = Fraction(first_sum * second_constant - second_sum * first_constant, determinant)
    coefficient_b = Fraction(first_linear * second_sum - second_linear * first_sum, determinant)
    return coefficient_a + coefficient_b


def _derivative_sign_count_difference(
    cubic: int,
    quadratic: int,
    linear: int,
    lower: int,
    upper: int,
) -> int:
    """필요 변수는 f-g의 삼차식 계수와 정수 범위다. 작동 원리는 합차 미분으로 얻은 도함수 부호별 정수 개수의 차를 계산한다."""
    if cubic == 0 or lower > upper:
        raise ValueError("삼차식과 올바른 정수 범위가 필요합니다.")
    positive = 0
    negative = 0
    for value in range(lower, upper + 1):
        derivative = 3 * cubic * value**2 + 2 * quadratic * value + linear
        positive += derivative > 0
        negative += derivative < 0
    return positive - negative


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 유리수 지수와 두 유리식이다. 작동 원리는 지수 확장과 통분 계산 문제를 각 5개 만든다."""
    specs: list[dict[str, Any]] = []
    exponent_rows = [(2, 3, 2, 4), (3, 2, 1, 3), (4, 3, 2, 2), (5, 2, 3, 3), (2, 5, 1, 5)]
    for index, (root, denominator, positive_power, negative_power) in enumerate(exponent_rows, 1):
        answer = _rational_exponent_sum(root, positive_power, negative_power)
        base = root**denominator
        specs.append(_checked_problem(
            1,
            index,
            title=rf"양수 $a={base}$에 대하여 $a^{{{positive_power}/{denominator}}}+a^{{-{negative_power}/{denominator}}}$의 값을 구하시오.",
            answer=str(answer),
            tags=["#유리수지수", "#지수의확장", "#지수법칙의성질", "#실수지수"],
            steps=[
                ("a를 주어진 분모 차수의 완전거듭제곱으로 나타낸다.", rf"$a={root}^{denominator}$이므로 $a^{{1/{denominator}}}={root}$이다."),
                ("유리수 지수와 음의 지수 법칙을 차례로 적용한다.", rf"두 항을 정확한 분수로 더하면 ${answer}$이다."),
            ],
            answer_check=lambda r=root, p=positive_power, q=negative_power: _rational_exponent_sum(r, p, q),
        ))

    rational_rows = [(1, -2, 3), (-1, 2, 4), (2, 5, 0), (-3, 1, 5), (4, -2, 1)]
    for index, row in enumerate(rational_rows, 6):
        first_pole, second_pole, argument = row
        answer = _common_denominator_value(*row)
        specs.append(_checked_problem(
            1,
            index,
            title=rf"유리식 $R(x)=\dfrac1{{x-({first_pole})}}+\dfrac1{{x-({second_pole})}}$를 통분하여 정리한 뒤 $R({argument})$의 값을 구하시오.",
            answer=str(answer),
            tags=["#통분", "#유리식", "#유리식의계산", "#약분"],
            steps=[
                ("두 일차분모의 곱을 공통분모로 정한다.", "각 분자에는 다른 쪽 분모를 곱해 더한다."),
                ("분자를 정리하고 지정한 x값을 대입한다.", rf"분모가 0이 아님을 확인하면 $R({argument})={answer}$이다."),
            ],
            answer_check=lambda values=row: _common_denominator_value(*values),
        ))
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 포물선의 수평 현과 원의 일반형이다. 작동 원리는 그래프 교점 거리와 중심·반지름 식 문제를 각 5개 만든다."""
    specs: list[dict[str, Any]] = []
    parabola_rows = [(2, -3, 13), (-1, 2, 27), (4, 1, 17), (0, -5, 44), (3, 4, 40)]
    for index, row in enumerate(parabola_rows, 1):
        axis, vertical, level = row
        answer = _parabola_horizontal_chord_length(*row)
        specs.append(_checked_problem(
            2,
            index,
            title=rf"포물선 $y=(x-({axis}))^2+({vertical})$와 직선 $y={level}$의 두 교점을 A,B라 할 때 선분 AB의 길이를 구하시오.",
            answer=str(answer),
            tags=["#이차함수와이차방정식", "#이차함수의그래프", "#포물선", "#이차방정식"],
            steps=[
                ("두 그래프의 y값을 같게 놓아 교점의 x좌표 방정식을 만든다.", "꼭짓점형의 제곱항만 한쪽에 남긴다."),
                ("서로 대칭인 두 x좌표를 구한다.", "두 교점은 같은 수평선 위에 있으므로 y좌표가 같다."),
                ("두 x좌표의 차의 절댓값을 계산한다.", rf"따라서 $AB={answer}$이다."),
            ],
            answer_check=lambda values=row: _parabola_horizontal_chord_length(*values),
        ))

    circle_rows = [(2, -1, 4), (-3, 2, 9), (1, 4, 16), (-2, -3, 25), (4, -2, 10)]
    for index, (center_x, center_y, radius_squared) in enumerate(circle_rows, 6):
        linear_x = -2 * center_x
        linear_y = -2 * center_y
        constant = center_x**2 + center_y**2 - radius_squared
        answer = _circle_center_radius_expression(linear_x, linear_y, constant)
        specs.append(_checked_problem(
            2,
            index,
            title=rf"원 $x^2+y^2+({linear_x})x+({linear_y})y+({constant})=0$의 중심을 $(a,b)$, 반지름을 r이라 할 때 $a+b+r^2$의 값을 구하시오.",
            answer=str(answer),
            tags=["#중심", "#원의방정식", "#반지름", "#완성제곱법"],
            steps=[
                ("x항과 y항을 각각 묶어 완전제곱한다.", "일차항 계수의 절반을 이용한다."),
                ("원의 표준형에서 중심과 반지름 제곱을 읽는다.", "우변이 양수인지 확인한다."),
                ("중심의 두 좌표와 반지름 제곱을 더한다.", rf"따라서 $a+b+r^2={answer}$이다."),
            ],
            answer_check=lambda p=linear_x, q=linear_y, c=constant: _circle_center_radius_expression(p, q, c),
        ))
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 평행이동한 로그함수와 짝수차 다항식이다. 작동 원리는 교점·점근선 및 인수분해 근 문제를 각 5개 만든다."""
    specs: list[dict[str, Any]] = []
    logarithm_rows = [(2, 3, -1, 4), (3, -2, 2, 2), (4, 1, 3, -1), (5, -3, -2, 3), (2, 4, 1, -2)]
    for index, row in enumerate(logarithm_rows, 1):
        base, horizontal, vertical, log_value = row
        line_value = vertical + log_value
        answer = _shifted_log_coordinate_sum(*row)
        specs.append(_checked_problem(
            3,
            index,
            title=rf"로그함수 $y=\log_{base}(x-({horizontal}))+({vertical})$의 그래프와 수평선 $y={line_value}$의 교점을 P라 하자. P의 x좌표와 수직점근선의 x좌표의 합을 구하시오.",
            answer=str(answer),
            tags=["#로그함수의평행이동", "#로그함수", "#로그함수의그래프", "#진수조건"],
            steps=[
                ("함수값을 수평선의 y좌표와 같게 놓는다.", "세로 이동량을 이항해 로그값을 구한다."),
                ("로그의 정의를 이용해 진수의 값을 거듭제곱으로 바꾼다.", "밑과 로그값의 부호를 그대로 유지한다."),
                ("진수 방정식을 풀어 교점의 x좌표를 구한다.", "구한 좌표는 진수 조건을 자동으로 만족한다."),
                ("괄호 안 진수가 0이 되는 수직점근선 좌표를 더한다.", rf"따라서 요구한 합은 ${answer}$이다."),
            ],
            alternatives=["기본 로그함수의 알려진 점과 수직점근선을 가로·세로로 함께 이동시켜 구할 수 있다."],
            answer_check=lambda values=row: _shifted_log_coordinate_sum(*values),
        ))

    factor_rows = [(2, 5), (3, 7), (4, 6), (5, 8), (6, 9)]
    for index, (first_root, second_root) in enumerate(factor_rows, 6):
        root_square_sum = first_root**2 + second_root**2
        root_square_product = (first_root * second_root) ** 2
        answer = _quartic_nonnegative_root_sum(first_root, second_root)
        specs.append(_checked_problem(
            3,
            index,
            title=rf"방정식 $x^4-{root_square_sum}x^2+{root_square_product}=0$의 음이 아닌 모든 실근의 합을 구하시오.",
            answer=str(answer),
            tags=["#인수분해법", "#인수정리", "#고차식인수분해", "#인수분해"],
            steps=[
                ("x²을 하나의 문자로 보아 이차식으로 해석한다.", "곱이 상수항이고 합이 x² 계수인 두 수를 찾는다."),
                ("두 이차식의 곱으로 인수분해한다.", "각 인수는 $x^2-a^2$ 꼴이다."),
                ("각 인수에 차의 제곱 공식을 적용해 네 실근을 구한다.", "양수와 음수 근이 쌍으로 나온다."),
                ("조건에 따라 음이 아닌 근만 골라 더한다.", rf"따라서 합은 ${answer}$이다."),
            ],
            alternatives=["$t=x^2$로 치환해 t의 두 근을 구한 뒤 각각의 양의 제곱근만 더할 수 있다."],
            answer_check=lambda a=first_root, b=second_root: _quartic_nonnegative_root_sum(a, b),
        ))
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 상한이 있는 정수해와 두 조건 구간이다. 작동 원리는 중복조합과 필요·충분 조건 반례 문제를 각 5개 만든다."""
    specs: list[dict[str, Any]] = []
    combination_rows = [(8, 2, 3), (10, 3, 4), (12, 4, 2), (9, 1, 5), (14, 5, 3)]
    for index, row in enumerate(combination_rows, 1):
        total, first_cap, second_cap = row
        answer = _bounded_stars_and_bars_count(*row)
        specs.append(_checked_problem(
            4,
            index,
            title=rf"방정식 $x_1+x_2+x_3+x_4={total}$을 만족하는 음이 아닌 정수해 중 $x_1\le {first_cap}$이고 $x_2\le {second_cap}$인 해의 개수를 구하시오.",
            answer=str(answer),
            tags=["#중복조합", "#조합의성질", "#조합의수", "#경우의수"],
            steps=[
                ("상한이 있는 x₁의 가능한 값을 고정한다.", rf"$0\le x_1\le {first_cap}$이다."),
                ("각 x₁에 대해 상한 안의 x₂ 값을 고정한다.", rf"$0\le x_2\le {second_cap}$이다."),
                ("남은 합을 x₃+x₄의 꼴로 정리한다.", "남은 값이 음수인 경우는 제외한다."),
                ("남은 합이 m이면 음이 아닌 두 변수의 해가 m+1개임을 이용한다.", "이는 두 종류에서 m개를 고르는 중복조합이다."),
                ("모든 x₁,x₂ 경우의 해 개수를 더한다.", rf"따라서 조건을 만족하는 해는 ${answer}$개이다."),
            ],
            alternatives=["전체 중복조합에서 x₁ 또는 x₂가 상한을 넘는 경우를 포함배제로 뺄 수 있다."],
            answer_check=lambda values=row: _bounded_stars_and_bars_count(*values),
        ))

    condition_rows = [(-8, 10, 4, 2, 3), (-10, 12, 5, -2, 4), (-12, 9, 3, 1, 5), (-15, 15, 6, 3, 2), (-9, 14, 2, -3, 6)]
    for index, row in enumerate(condition_rows, 6):
        lower, upper, first_radius, second_center, second_radius = row
        answer = _condition_symmetric_difference_count(*row)
        specs.append(_checked_problem(
            4,
            index,
            title=rf"정수 전체집합 $U=\{{x\mid {lower}\le x\le {upper}\}}$에서 조건 p는 $x^2\le {first_radius**2}$, 조건 q는 $|x-({second_center})|\le {second_radius}$이다. p가 q의 충분조건이 되지 못하게 하는 원소 수와 q가 p의 충분조건이 되지 못하게 하는 원소 수의 합을 구하시오.",
            answer=str(answer),
            tags=["#충분조건", "#필요조건", "#필요충분조건", "#명제"],
            steps=[
                ("조건 p의 정수해 집합 P를 구한다.", "$x^2\le a^2$를 절댓값 부등식으로 바꾼다."),
                ("조건 q의 정수해 집합 Q를 구한다.", "절댓값 부등식을 중심이 있는 닫힌구간으로 바꾼다."),
                ("p가 q의 충분조건이 되지 못하는 반례를 찾는다.", "$P-Q$의 원소가 해당한다."),
                ("q가 p의 충분조건이 되지 못하는 반례도 찾는다.", "$Q-P$의 원소가 해당한다."),
                ("두 차집합의 원소 수를 더한다.", rf"필요조건 방향까지 함께 확인하면 요구한 합은 ${answer}$이다."),
            ],
            alternatives=["두 조건의 해 구간을 수직선에 겹쳐 그려 한쪽에만 색칠된 정수를 셀 수 있다."],
            answer_check=lambda values=row: _condition_symmetric_difference_count(*values),
        ))
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 연속한 두 시그마 부분합과 함수 차의 삼차식이다. 작동 원리는 계수 복원과 도함수 부호 개수차 문제를 각 5개 만든다."""
    specs: list[dict[str, Any]] = []
    sigma_rows = [(4, 7, 4), (5, 8, 5), (6, 10, 7), (7, 11, 8), (8, 14, 9)]
    for index, (upper, coefficient_a, coefficient_b) in enumerate(sigma_rows, 1):
        first_sum = coefficient_a * upper * (upper + 1) // 2 + coefficient_b * upper
        next_upper = upper + 1
        second_sum = coefficient_a * next_upper * (next_upper + 1) // 2 + coefficient_b * next_upper
        answer = _linear_sigma_coefficient_sum(upper, first_sum, second_sum)
        specs.append(_checked_problem(
            5,
            index,
            title=rf"실수 a,b에 대하여 $\sum_{{k=1}}^{{{upper}}}(ak+b)={first_sum}$이고 $\sum_{{k=1}}^{{{next_upper}}}(ak+b)={second_sum}$이다. $a+b$의 값을 구하시오.",
            answer=str(answer),
            tags=["#합의기호시그마", "#시그마의성질", "#여러가지수열의합", "#미정계수법"],
            steps=[
                ("첫 번째 시그마를 a와 b에 관한 식으로 분리한다.", "합의 선형성을 이용한다."),
                ("자연수의 합 공식과 상수항의 합을 적용한다.", "a의 계수와 b의 계수를 각각 계산한다."),
                ("둘째 시그마에도 같은 계산을 적용한다.", "상한이 1 증가했으므로 계수가 달라진다."),
                ("두 결과로 a,b의 연립방정식을 만든다.", "두 식의 계수행렬식은 0이 아니다."),
                ("연립방정식을 풀고 두 원래 합에 대입해 검산한다.", "상한까지의 항 개수를 정확히 센다."),
                ("구한 두 계수를 더한다.", rf"따라서 $a+b={answer}$이다."),
            ],
            alternatives=[
                "두 번째 부분합에서 첫 번째 부분합을 빼 새로 추가된 한 항의 값을 먼저 구할 수 있다.",
                "각 시그마를 등차수열의 합으로 보고 첫째항과 끝항 공식으로 연립할 수 있다.",
            ],
            answer_check=lambda n=upper, first=first_sum, second=second_sum: _linear_sigma_coefficient_sum(n, first, second),
        ))

    derivative_rows = [(1, -3, 2, -3, 5), (-1, 2, 5, -4, 6), (2, -1, -6, -5, 4), (1, 4, -5, -6, 3), (-2, 3, 8, -3, 7)]
    for index, row in enumerate(derivative_rows, 6):
        cubic, quadratic, linear, lower, upper = row
        answer = _derivative_sign_count_difference(*row)
        specs.append(_checked_problem(
            5,
            index,
            title=rf"두 미분가능한 함수 f,g가 $f(x)-g(x)=({cubic})x^3+({quadratic})x^2+({linear})x+1$을 만족한다. 정수 ${lower}\le x\le {upper}$ 중 $f'(x)>g'(x)$인 x의 개수에서 $f'(x)<g'(x)$인 x의 개수를 뺀 값을 구하시오.",
            answer=str(answer),
            tags=["#합차의미분", "#도함수", "#도함수공식", "#증가함수", "#감소함수"],
            steps=[
                ("주어진 함수 차의 양변을 미분한다.", "$f'(x)-g'(x)$는 우변 삼차식의 도함수와 같다."),
                ("거듭제곱 미분법으로 이차 도함수를 구한다.", "상수항의 도함수는 0이다."),
                ("도함수가 0이 되는 경계 또는 부호가 바뀌는 위치를 찾는다.", "이차식의 근이 정수가 아닐 수도 있다."),
                ("주어진 범위의 각 정수를 부호 구간에 배치한다.", "도함수가 0인 정수는 두 개수에서 모두 제외한다."),
                ("양수인 경우와 음수인 경우의 개수를 각각 센다.", "이는 함수 차의 증가·감소를 비교하는 것과 같다."),
                ("양수 쪽 개수에서 음수 쪽 개수를 뺀다.", rf"따라서 요구한 값은 ${answer}$이다."),
            ],
            alternatives=[
                "도함수 이차식의 부호표를 그려 각 정수 구간의 부호를 한꺼번에 판정할 수 있다.",
                "제한된 정수 범위에 도함수 값을 직접 대입해 양수·음수·0으로 분류해 검산할 수 있다.",
            ],
            answer_check=lambda values=row: _derivative_sign_count_difference(*values),
        ))
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v53 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v53 전체 카탈로그다. 작동 원리는 독립 정답 검산 후 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog = build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v53 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(
        catalog,
        expected_count=50,
        batch_id=BATCH_ID,
        model_name=MODEL_NAME,
        codebase_base=CODEBASE_BASE,
        seed_base=SEED_BASE,
    )


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v53 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(db_path, quests=validated_quests(), batch_id=BATCH_ID, validate_only=validate_only)


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v53 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
