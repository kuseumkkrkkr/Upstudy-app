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

BATCH_ID = "marketplace-original-v32"
MODEL_NAME = "aiflow-direct-authoring-v32"
CODEBASE_BASE = 20_260_993_000
SEED_BASE = 202_607_572_000


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


def _symmetric_polynomial_coefficient(quadratic: int, shift: int) -> int:
    """필요 변수는 이차항 계수와 대칭 이동량이다. 작동 원리는 P(x+h)-P(x-h)를 직접 전개해 x의 계수를 구한다."""
    return 4 * quadratic * shift


def _base_to_decimal(digits: tuple[int, ...], base: int) -> int:
    """필요 변수는 높은 자리부터 나열한 숫자와 밑이다. 작동 원리는 호너 방식으로 각 자릿값을 누적해 십진 정수로 바꾼다."""
    if base <= 1 or any(not 0 <= digit < base for digit in digits):
        raise ValueError("진법의 밑과 숫자가 올바르지 않습니다.")
    value = 0
    for digit in digits:
        value = value * base + digit
    return value


def _arithmetic_interpolation(
    first_index: int,
    first_value: int,
    second_index: int,
    second_value: int,
    target_index: int,
) -> Fraction:
    """필요 변수는 등차수열의 두 항과 목표 항 번호다. 작동 원리는 두 항의 차로 공차를 구해 목표 항까지 선형 보간한다."""
    if first_index == second_index:
        raise ValueError("서로 다른 두 항 번호가 필요합니다.")
    difference = Fraction(second_value - first_value, second_index - first_index)
    return Fraction(first_value, 1) + (target_index - first_index) * difference


def _intersection_sum(
    lower: int,
    upper: int,
    first_modulus: int,
    first_residue: int,
    second_modulus: int,
    second_residue: int,
) -> int:
    """필요 변수는 정수 구간과 두 나머지 조건이다. 작동 원리는 구간의 모든 정수를 순회해 두 집합의 교집합 원소를 더한다."""
    if lower > upper or first_modulus <= 0 or second_modulus <= 0:
        raise ValueError("교집합 조건이 올바르지 않습니다.")
    return sum(
        value
        for value in range(lower, upper + 1)
        if value % first_modulus == first_residue % first_modulus
        and value % second_modulus == second_residue % second_modulus
    )


def _decreasing_log_integer_count(
    denominator: int,
    shift: int,
    exponent: int,
    relation: str,
    lower: int,
    upper: int,
) -> int:
    """필요 변수는 1/denominator인 로그 밑·진수 이동·경계 지수·부등호·정수 범위다. 작동 원리는 감소성을 반영해 진수와 거듭제곱을 정확한 분수로 비교한다."""
    comparisons: dict[str, Callable[[Fraction, Fraction], bool]] = {
        ">": lambda argument, threshold: argument < threshold,
        ">=": lambda argument, threshold: argument <= threshold,
        "<": lambda argument, threshold: argument > threshold,
        "<=": lambda argument, threshold: argument >= threshold,
    }
    if denominator <= 1 or relation not in comparisons or lower > upper:
        raise ValueError("로그부등식 조건이 올바르지 않습니다.")
    threshold = Fraction(1, denominator) ** exponent
    return sum(
        x - shift > 0
        and comparisons[relation](Fraction(x - shift, 1), threshold)
        for x in range(lower, upper + 1)
    )


def _radical_equation_solution(first_constant: int, second_constant: int, total: int) -> int:
    """필요 변수는 두 근호 안의 상수와 우변이다. 작동 원리는 유한 정수 범위에서 정의역과 완전제곱 여부를 검사해 유일한 해를 반환한다."""
    solutions: list[int] = []
    for value in range(-100, 201):
        first = value + first_constant
        second = value + second_constant
        if first < 0 or second < 0:
            continue
        first_root = math.isqrt(first)
        second_root = math.isqrt(second)
        if first_root * first_root == first and second_root * second_root == second and first_root + second_root == total:
            solutions.append(value)
    if len(solutions) != 1:
        raise ValueError(f"정수해가 유일하지 않습니다: {solutions}")
    return solutions[0]


def _differentiable_parameter_sum(
    point: int,
    quadratic: tuple[int, int, int],
) -> int:
    """필요 변수는 경계점과 왼쪽 이차식 계수다. 작동 원리는 오른쪽 직선 mx+k가 함수값과 미분계수를 모두 잇도록 m+k를 구한다."""
    a, b, c = quadratic
    slope = 2 * a * point + b
    value = a * point**2 + b * point + c
    intercept = value - slope * point
    return slope + intercept


def _riemann_quadratic_integral(
    quadratic: int,
    linear: int,
    constant: int,
    upper: int,
) -> Fraction:
    """필요 변수는 이차함수 계수와 적분구간 위끝이다. 작동 원리는 오른쪽 끝점 구분구적합의 극한과 같은 정적분을 계산한다."""
    return (
        Fraction(quadratic * upper**3, 3)
        + Fraction(linear * upper**2, 2)
        + constant * upper
    )


def _quadratic_velocity_distance(
    scale: int,
    first_turn: int,
    second_turn: int,
    end_time: int,
) -> Fraction:
    """필요 변수는 속도 배수·두 방향 전환 시각·종료 시각이다. 작동 원리는 속도 원시함수를 전환점별로 평가해 변위 절댓값을 합한다."""
    if scale <= 0 or not 0 < first_turn < second_turn < end_time:
        raise ValueError("속도 전환 구간이 올바르지 않습니다.")

    def primitive(time: int) -> Fraction:
        """필요 변수는 평가할 시각이다. 작동 원리는 전개한 이차 속도의 원시함수 값을 정확히 계산한다."""
        return scale * (
            Fraction(time**3, 3)
            - Fraction((first_turn + second_turn) * time**2, 2)
            + first_turn * second_turn * time
        )

    points = [0, first_turn, second_turn, end_time]
    return sum(
        (abs(primitive(right) - primitive(left)) for left, right in zip(points, points[1:])),
        Fraction(0, 1),
    )


def _parabola_gap_area(scale: int, left_root: int, right_root: int) -> Fraction:
    """필요 변수는 두 곡선 차의 배수와 교점의 x좌표다. 작동 원리는 k(x-left)(right-x)의 정적분으로 두 곡선 사이 넓이를 구한다."""
    if scale <= 0 or left_root >= right_root:
        raise ValueError("넓이 조건이 올바르지 않습니다.")
    width = right_root - left_root
    return Fraction(scale * width**3, 6)


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 대칭 다항식과 여러 진법 수다. 작동 원리는 전개 계수와 진법 변환 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    polynomial_rows = [(2, 3, -1, 4), (-1, 2, 5, -3), (3, -2, 1, 5), (4, 1, -6, 2), (-2, -3, 4, 3)]
    for index, (quadratic, linear, constant, shift) in enumerate(polynomial_rows, 1):
        answer = _symmetric_polynomial_coefficient(quadratic, shift)
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"다항식 $P(x)={quadratic}x^2+({linear})x+({constant})$에 대하여 $P(x+({shift}))-P(x-({shift}))$에서 x의 계수를 구하시오.",
                answer=str(answer),
                tags=["#다항식", "#다항식의덧셈", "#다항식의뺄셈", "#곱셈공식"],
                steps=[
                    ("P(x+shift)와 P(x-shift)를 각각 전개한다.", "상수항과 일차항에서 생기는 같은 차수 항을 정리한다."),
                    ("두 식을 빼고 x의 계수만 모은다.", rf"이차항에서 생기는 x의 계수는 $4\cdot({quadratic})\cdot({shift})={answer}$이다."),
                ],
                answer_check=lambda a=quadratic, h=shift: _symmetric_polynomial_coefficient(a, h),
            )
        )
    base_rows = [((1, 0, 1, 1), 2), ((2, 1, 2), 3), ((3, 0, 2), 4), ((4, 1, 3), 5), ((5, 2, 4), 6)]
    for index, (digits, base) in enumerate(base_rows, 6):
        answer = _base_to_decimal(digits, base)
        digit_text = "".join(str(digit) for digit in digits)
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"{base}진법으로 나타낸 수 $({digit_text})_{{{base}}}$를 십진법 수로 바꾸시오.",
                answer=str(answer),
                tags=["#진수", "#대수"],
                steps=[
                    ("각 숫자에 자리의 밑 거듭제곱을 곱한다.", rf"가장 높은 자리는 ${base}^{{{len(digits) - 1}}}$ 자리이다."),
                    ("모든 자릿값을 더한다.", rf"따라서 십진법 값은 ${answer}$이다."),
                ],
                answer_check=lambda values=digits, radix=base: _base_to_decimal(values, radix),
            )
        )
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 등차수열의 두 항과 두 조건집합이다. 작동 원리는 선형 보간과 교집합 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    sequence_rows = [(2, 5, 8, 23, 5), (1, -3, 7, 15, 4), (3, 10, 9, -2, 6), (4, 7, 10, 31, 7), (2, -5, 12, 25, 8)]
    for index, (first_index, first_value, second_index, second_value, target_index) in enumerate(sequence_rows, 1):
        difference = Fraction(second_value - first_value, second_index - first_index)
        answer = _arithmetic_interpolation(first_index, first_value, second_index, second_value, target_index)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"등차수열 $\{{a_n\}}$에서 $a_{first_index}={first_value}$, $a_{second_index}={second_value}$일 때 $a_{target_index}$의 값을 구하시오.",
                answer=str(answer),
                tags=["#공차", "#등차중항", "#등차수열의일반항", "#수열"],
                steps=[
                    ("두 항 번호의 차와 항값의 차로 공차를 구한다.", rf"공차는 $d={difference}$이다."),
                    ("기준 항에서 목표 항까지의 항 번호 차를 구한다.", rf"차이는 ${target_index}-{first_index}={target_index - first_index}$이다."),
                    ("등차수열의 항 관계를 적용한다.", rf"따라서 $a_{target_index}={answer}$이다."),
                ],
                answer_check=lambda i=first_index, a=first_value, j=second_index, b=second_value, target=target_index: _arithmetic_interpolation(i, a, j, b, target),
            )
        )
    set_rows = [
        (-10, 20, 3, 1, 4, 2),
        (0, 30, 5, 0, 3, 1),
        (-15, 15, 4, 1, 6, 3),
        (1, 40, 7, 2, 5, 2),
        (-20, 25, 6, 4, 8, 4),
    ]
    for index, (lower, upper, first_modulus, first_residue, second_modulus, second_residue) in enumerate(set_rows, 6):
        elements = [
            value
            for value in range(lower, upper + 1)
            if value % first_modulus == first_residue % first_modulus
            and value % second_modulus == second_residue % second_modulus
        ]
        answer = _intersection_sum(lower, upper, first_modulus, first_residue, second_modulus, second_residue)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"정수 구간 ${lower}\le x\le {upper}$에서 $A=\{{x\mid x\equiv {first_residue}\pmod{{{first_modulus}}}\}}$, $B=\{{x\mid x\equiv {second_residue}\pmod{{{second_modulus}}}\}}$라 할 때, $A\cap B$의 모든 원소의 합을 구하시오.",
                answer=str(answer),
                tags=["#교집합", "#조건제시법", "#집합의표현", "#집합"],
                steps=[
                    ("첫 번째 나머지 조건을 만족하는 정수를 구한다.", "주어진 구간 안에서 A의 원소를 나열한다."),
                    ("두 번째 조건도 동시에 만족하는 원소만 남긴다.", rf"교집합은 $\{{{','.join(map(str, elements))}\}}$이다."),
                    ("교집합의 원소를 모두 더한다.", rf"따라서 합은 ${answer}$이다."),
                ],
                answer_check=lambda low=lower, high=upper, m=first_modulus, r=first_residue, n=second_modulus, s=second_residue: _intersection_sum(low, high, m, r, n, s),
            )
        )
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 감소 로그함수와 두 근호 방정식이다. 작동 원리는 단조성 부등식과 정의역 방정식 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    log_rows = [
        (2, 0, -3, ">", 0, 12),
        (3, -1, -2, ">=", -2, 15),
        (4, 2, -2, "<", 0, 20),
        (5, -2, -1, "<=", -3, 12),
        (10, 1, -1, ">", 1, 15),
    ]
    for index, (denominator, shift, exponent, relation, lower, upper) in enumerate(log_rows, 1):
        answer = _decreasing_log_integer_count(denominator, shift, exponent, relation, lower, upper)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"정수 범위 ${lower}\le x\le {upper}$에서 로그부등식 $\log_{{1/{denominator}}}(x-({shift})){relation}{exponent}$을 만족하는 정수 x의 개수를 구하시오.",
                answer=str(answer),
                tags=["#로그부등식", "#감소함수", "#밑", "#진수조건"],
                steps=[
                    ("로그의 진수조건을 구한다.", rf"$x-({shift})>0$이어야 한다."),
                    ("밑이 0과 1 사이여서 로그함수가 감소함수임을 확인한다.", "진수의 대소를 바꿀 때 부등호 방향이 반대로 대응한다."),
                    ("경계 로그값을 진수의 거듭제곱으로 바꾼다.", rf"경계 진수는 $(1/{denominator})^{{{exponent}}}$이다."),
                    ("정의역과 정수 범위를 함께 적용해 센다.", rf"따라서 정수해는 ${answer}$개이다."),
                ],
                alternatives=["범위 안의 각 정수 진수를 정확한 분수 경계와 직접 비교할 수 있다."],
                answer_check=lambda base=denominator, h=shift, power=exponent, op=relation, low=lower, high=upper: _decreasing_log_integer_count(base, h, power, op, low, high),
            )
        )
    radical_rows = [(3, 8, 5), (11, 18, 7), (-3, 21, 6), (16, 4, 6), (4, 31, 9)]
    for index, (first_constant, second_constant, total) in enumerate(radical_rows, 6):
        answer = _radical_equation_solution(first_constant, second_constant, total)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"무리방정식 $\sqrt{{x+({first_constant})}}+\sqrt{{x+({second_constant})}}={total}$을 만족하는 정수 x를 구하시오.",
                answer=str(answer),
                tags=["#무리식과무리함수", "#무리식의계산", "#유리화", "#정의역"],
                steps=[
                    ("두 근호 안이 0 이상인 정의역을 구한다.", "두 일차식이 동시에 음이 아니어야 한다."),
                    ("한 근호를 반대편으로 옮기고 양변을 제곱한다.", "첫 제곱으로 남은 한 근호를 고립한다."),
                    ("다시 제곱해 x에 대한 방정식을 얻는다.", "제곱 과정에서 생길 수 있는 무연근을 기억한다."),
                    ("후보를 원래 식에 대입해 확인한다.", rf"정의역과 원래 식을 만족하는 정수해는 $x={answer}$이다."),
                ],
                alternatives=["정의역 안의 정수에서 두 근호가 완전제곱이 되는 값을 직접 검사할 수 있다."],
                answer_check=lambda a=first_constant, b=second_constant, c=total: _radical_equation_solution(a, b, c),
            )
        )
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 미분가능 조각함수와 이차함수 구분구적 조건이다. 작동 원리는 접합 매개변수와 정적분 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    differentiable_rows = [(1, (2, -1, 3)), (-2, (1, 4, -5)), (3, (-1, 2, 6)), (0, (3, -2, 1)), (2, (-2, 5, 4))]
    for index, (point, quadratic) in enumerate(differentiable_rows, 1):
        a, b, c = quadratic
        slope = 2 * a * point + b
        value = a * point**2 + b * point + c
        intercept = value - slope * point
        answer = _differentiable_parameter_sum(point, quadratic)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"함수 $f(x)=\begin{{cases}}{a}x^2+({b})x+({c})&(x\le {point})\\mx+k&(x>{point})\end{{cases}}$가 $x={point}$에서 미분가능할 때 $m+k$를 구하시오.",
                answer=str(answer),
                tags=["#미분계수의정의", "#미분가능", "#도함수의정의", "#접선방정식구하기"],
                steps=[
                    ("왼쪽 이차식의 경계점 함수값을 계산한다.", rf"함수값은 ${value}$이다."),
                    ("왼쪽 이차식의 경계점 미분계수를 계산한다.", rf"미분계수는 ${slope}$이다."),
                    ("오른쪽 직선의 기울기를 미분계수와 같게 둔다.", rf"$m={slope}$이다."),
                    ("연속 조건으로 오른쪽 직선의 절편을 구한다.", rf"$k={intercept}$이다."),
                    ("두 매개변수를 더한다.", rf"따라서 $m+k={answer}$이다."),
                ],
                alternatives=["오른쪽 직선이 경계점에서 이차함수의 접선이라는 사실로 m과 k를 동시에 구할 수 있다."],
                answer_check=lambda boundary=point, curve=quadratic: _differentiable_parameter_sum(boundary, curve),
            )
        )
    riemann_rows = [(1, 2, 1, 3), (2, -1, 4, 4), (-1, 5, -2, 6), (3, 0, 2, 5), (2, 3, -1, 7)]
    for index, (quadratic, linear, constant, upper) in enumerate(riemann_rows, 6):
        answer = _riemann_quadratic_integral(quadratic, linear, constant, upper)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"구간 $[0,{upper}]$을 n등분한 오른쪽 끝점 구분구적합의 극한으로 $f(x)={quadratic}x^2+({linear})x+({constant})$의 정적분 값을 구하시오.",
                answer=str(answer),
                tags=["#구분구적법", "#구간의분할", "#정적분의정의", "#미적분Ⅰ"],
                steps=[
                    ("구간의 폭과 오른쪽 끝점을 나타낸다.", rf"$\Delta x={upper}/n$, $x_k={upper}k/n$이다."),
                    ("오른쪽 끝점 구분구적합을 세운다.", rf"$\sum_{{k=1}}^n f({upper}k/n)\cdot {upper}/n$이다."),
                    ("시그마의 일차·제곱 합 공식을 적용한다.", r"$\sum k=n(n+1)/2$, $\sum k^2=n(n+1)(2n+1)/6$을 사용한다."),
                    ("n이 무한대로 갈 때의 극한을 취한다.", rf"이는 $\int_0^{{{upper}}}f(x)dx$와 같다."),
                    ("이차함수의 원시함수를 양 끝에서 계산한다.", rf"따라서 정적분 값은 ${answer}$이다."),
                ],
                alternatives=["구분구적합이 정의하는 정적분을 직접 적분 공식으로 계산해 검산할 수 있다."],
                answer_check=lambda a=quadratic, b=linear, c=constant, end=upper: _riemann_quadratic_integral(a, b, c, end),
            )
        )
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 번 방향을 바꾸는 속도와 두 곡선의 차다. 작동 원리는 절댓값 적분과 곡선 사이 넓이 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    velocity_rows = [(1, 1, 3, 5), (2, 2, 4, 7), (3, 1, 4, 6), (1, 2, 5, 8), (2, 3, 6, 10)]
    for index, (scale, first_turn, second_turn, end_time) in enumerate(velocity_rows, 1):
        answer = _quadratic_velocity_distance(scale, first_turn, second_turn, end_time)
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"수직선 위 점 P의 속도가 $v(t)={scale}(t-{first_turn})(t-{second_turn})$일 때, $0\le t\le {end_time}$에서 움직인 총거리를 구하시오.",
                answer=str(answer),
                tags=["#속도와거리", "#속도와가속도", "#가속도", "#정적분과속도"],
                steps=[
                    ("속도가 0이 되는 두 시각을 찾는다.", rf"방향 전환 시각은 $t={first_turn}, {second_turn}$이다."),
                    ("세 구간에서 속도의 부호를 판정한다.", "첫 구간은 양수, 가운데는 음수, 마지막은 양수이다."),
                    ("총거리를 속도 절댓값의 정적분으로 나타낸다.", rf"$\int_0^{{{end_time}}}|v(t)|dt$이다."),
                    ("두 전환 시각을 기준으로 적분 구간을 세 부분으로 나눈다.", "가운데 구간의 부호를 바꾸어 적분한다."),
                    ("이차 속도의 원시함수를 구한다.", "세제곱·제곱·일차항으로 적분한다."),
                    ("세 구간 이동거리의 절댓값을 더한다.", rf"따라서 총거리는 ${answer}$이다."),
                ],
                alternatives=[
                    "속도-시간 그래프와 t축 사이 세 영역의 넓이를 각각 계산할 수 있다.",
                    "위치함수를 구해 네 시각의 위치 차 절댓값을 순서대로 더할 수 있다.",
                ],
                answer_check=lambda m=scale, a=first_turn, b=second_turn, end=end_time: _quadratic_velocity_distance(m, a, b, end),
            )
        )
    area_rows = [(1, -2, 4), (2, 1, 5), (3, -1, 3), (1, 0, 6), (2, -3, 2)]
    for index, (scale, left_root, right_root) in enumerate(area_rows, 6):
        answer = _parabola_gap_area(scale, left_root, right_root)
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"두 곡선 $y=f(x)$와 $y=g(x)$가 $x={left_root}, {right_root}$에서 만나고, 그 사이에서 $f(x)-g(x)={scale}(x-({left_root}))({right_root}-x)$이다. 두 곡선 사이의 넓이를 구하시오.",
                answer=str(answer),
                tags=["#두곡선사이의넓이", "#정적분과넓이", "#곡선과x축사이의넓이", "#정적분의계산"],
                steps=[
                    ("두 교점 사이에서 위쪽 곡선을 확인한다.", "주어진 차는 구간 내부에서 0 이상이므로 f가 위쪽이다."),
                    ("두 곡선 사이 넓이의 정적분을 세운다.", rf"$\int_{{{left_root}}}^{{{right_root}}}(f(x)-g(x))dx$이다."),
                    ("주어진 곡선 차를 적분식에 대입한다.", rf"$\int_{{{left_root}}}^{{{right_root}}}{scale}(x-({left_root}))({right_root}-x)dx$이다."),
                    ("구간의 왼쪽 끝을 0으로 옮겨 변수 치환한다.", rf"구간 길이는 ${right_root - left_root}$이다."),
                    ("이차식을 전개해 원시함수를 계산한다.", "일차항과 이차항의 적분값을 양 끝에서 뺀다."),
                    ("넓이를 양수로 정리한다.", rf"따라서 두 곡선 사이 넓이는 ${answer}$이다."),
                ],
                alternatives=[
                    "폭을 w라 두면 ∫₀ʷ ku(w-u)du=kw³/6 공식을 적용할 수 있다.",
                    "포물선 조각의 대칭성을 이용해 구간 중점 양쪽의 넓이를 두 배할 수 있다.",
                ],
                answer_check=lambda k=scale, left=left_root, right=right_root: _parabola_gap_area(k, left, right),
            )
        )
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v32 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v32 전체 카탈로그다. 작동 원리는 독립 정답 검산 후 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog = build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v32 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(
        catalog,
        expected_count=50,
        batch_id=BATCH_ID,
        model_name=MODEL_NAME,
        codebase_base=CODEBASE_BASE,
        seed_base=SEED_BASE,
    )


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v32 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(
        db_path,
        quests=validated_quests(),
        batch_id=BATCH_ID,
        validate_only=validate_only,
    )


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v32 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
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
