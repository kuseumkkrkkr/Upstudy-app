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

BATCH_ID = "marketplace-original-v54"
MODEL_NAME = "aiflow-direct-authoring-v54"
CODEBASE_BASE = 20_261_015_000
SEED_BASE = 202_607_594_000


def _checked_problem(tier: int, index: int, *, answer_check: Callable[[], Any], **kwargs: Any) -> dict[str, Any]:
    """필요 변수는 문제 명세와 독립 계산 함수다. 작동 원리는 저장 답과 별도 계산 결과를 비교하도록 검산 함수를 부착한다."""
    spec = _problem(tier, index, **kwargs)
    spec["answer_check"] = answer_check
    return spec


def _polynomial_product_coefficient_sum(first: tuple[int, ...], second: tuple[int, ...]) -> int:
    """필요 변수는 두 다항식의 내림차순 계수다. 작동 원리는 (P+Q)(P-Q)=P²-Q²의 전체 계수 합을 x=1의 함수값으로 계산한다."""
    first_sum = sum(first)
    second_sum = sum(second)
    return (first_sum + second_sum) * (first_sum - second_sum)


def _internal_point_line_intercept(
    first: tuple[int, int],
    second: tuple[int, int],
    first_ratio: int,
    second_ratio: int,
    through: tuple[int, int],
) -> Fraction:
    """필요 변수는 두 끝점·내분비·추가 점이다. 작동 원리는 내분점 좌표를 구하고 그 점과 추가 점을 지나는 직선의 y절편을 계산한다."""
    if min(first_ratio, second_ratio) <= 0:
        raise ValueError("양의 내분비가 필요합니다.")
    denominator = first_ratio + second_ratio
    point_x = Fraction(second_ratio * first[0] + first_ratio * second[0], denominator)
    point_y = Fraction(second_ratio * first[1] + first_ratio * second[1], denominator)
    if point_x == through[0]:
        raise ValueError("y절편을 갖는 비수직 직선이 필요합니다.")
    slope = Fraction(point_y - through[1], point_x - through[0])
    return point_y - slope * point_x


def _reflected_shifted_vertex_sum(axis: int, vertical: int, vertical_move: int) -> int:
    """필요 변수는 포물선 꼭짓점과 세로 이동량이다. 작동 원리는 x축·y축 대칭 뒤 y방향 이동한 꼭짓점 좌표합을 구한다."""
    return -axis - vertical + vertical_move


def _arithmetic_geometric_middle_sum(
    arithmetic_first: int,
    arithmetic_second: int,
    geometric_first: int,
    geometric_second: int,
) -> Fraction:
    """필요 변수는 등차·양의 등비수열의 대칭 위치 두 항이다. 작동 원리는 산술평균과 양의 기하평균을 각각 중항으로 구해 더한다."""
    product = geometric_first * geometric_second
    geometric_middle = math.isqrt(product)
    if min(geometric_first, geometric_second) <= 0 or geometric_middle**2 != product:
        raise ValueError("양의 정수 등비중항이 존재하는 두 항이 필요합니다.")
    return Fraction(arithmetic_first + arithmetic_second, 2) + geometric_middle


def _limit_algebra_value(first_limit: int, second_limit: int, coefficient: int) -> Fraction:
    """필요 변수는 두 함수의 극한과 결합 계수다. 작동 원리는 극한의 사칙연산으로 (f²+cg)/(f-g)의 극한을 계산한다."""
    if first_limit == second_limit:
        raise ValueError("분모의 극한이 0이 아니어야 합니다.")
    return Fraction(first_limit**2 + coefficient * second_limit, first_limit - second_limit)


def _bounded_log_integer_sum(
    base: int,
    shift: int,
    lower_exponent: int,
    upper_exponent: int,
    lower: int,
    upper: int,
) -> int:
    """필요 변수는 로그 밑·진수 이동·로그 범위와 정수 범위다. 작동 원리는 로그부등식을 거듭제곱 범위로 바꿔 정수해를 합한다."""
    if base <= 1 or lower_exponent >= upper_exponent or lower > upper:
        raise ValueError("증가 로그함수와 올바른 범위가 필요합니다.")
    return sum(
        value
        for value in range(lower, upper + 1)
        if base**lower_exponent <= value - shift < base**upper_exponent
    )


def _recurrence_term(first: int, linear: int, constant: int, target: int) -> int:
    """필요 변수는 첫째항·점화식 증가량 계수·목표 첨자다. 작동 원리는 aₙ₊₁-aₙ=pn+q를 반복 합산해 목표항을 구한다."""
    if target < 1:
        raise ValueError("양의 목표 첨자가 필요합니다.")
    value = first
    for index in range(1, target):
        value += linear * index + constant
    return value


def _riemann_polynomial_integral(quadratic: int, linear: int, constant: int, endpoint: int) -> Fraction:
    """필요 변수는 이차함수 계수와 양의 구간 끝점이다. 작동 원리는 오른쪽 끝점 구분구적합의 극한을 정확한 정적분 값으로 계산한다."""
    if endpoint <= 0:
        raise ValueError("양의 구간 끝점이 필요합니다.")
    return (
        Fraction(quadratic * endpoint**3, 3)
        + Fraction(linear * endpoint**2, 2)
        + constant * endpoint
    )


def _accelerated_motion_distance(
    acceleration_linear: int,
    acceleration_constant: int,
    initial_velocity: int,
    end_time: int,
) -> Fraction:
    """필요 변수는 일차 가속도·초기 속도·종료 시각이다. 작동 원리는 속도를 복원해 양수임을 확인하고 한 번 더 적분해 이동거리를 구한다."""
    if end_time <= 0:
        raise ValueError("양의 종료 시각이 필요합니다.")
    for time in range(end_time * 20 + 1):
        point = Fraction(time, 20)
        velocity = Fraction(acceleration_linear, 2) * point**2 + acceleration_constant * point + initial_velocity
        if velocity < 0:
            raise ValueError("전 구간에서 음이 아닌 속도를 갖는 자료가 필요합니다.")
    return (
        Fraction(acceleration_linear * end_time**3, 6)
        + Fraction(acceleration_constant * end_time**2, 2)
        + initial_velocity * end_time
    )


def _inverse_matrix_trace_determinant_sum(matrix: tuple[int, int, int, int]) -> Fraction:
    """필요 변수는 가역 2×2 행렬이다. 작동 원리는 역행렬 공식으로 대각합과 행렬식을 각각 구해 더한다."""
    first, second, third, fourth = matrix
    determinant = first * fourth - second * third
    if determinant == 0:
        raise ValueError("가역행렬이 필요합니다.")
    inverse_trace = Fraction(first + fourth, determinant)
    inverse_determinant = Fraction(1, determinant)
    return inverse_trace + inverse_determinant


def _poly_text(coefficients: tuple[int, ...]) -> str:
    """필요 변수는 삼차 이하 다항식의 내림차순 계수다. 작동 원리는 문제 본문용 LaTeX 다항식 문자열을 만든다."""
    degree = len(coefficients) - 1
    parts: list[str] = []
    for index, coefficient in enumerate(coefficients):
        power = degree - index
        if coefficient == 0:
            continue
        term = f"({coefficient})"
        if power == 1:
            term += "x"
        elif power > 1:
            term += f"x^{power}"
        parts.append(term)
    return "+".join(parts) or "0"


def _matrix_text(values: tuple[int, int, int, int]) -> str:
    """필요 변수는 행 우선 2×2 행렬 성분이다. 작동 원리는 문제 본문에 넣을 LaTeX 행렬 문자열로 변환한다."""
    return rf"\begin{{pmatrix}}{values[0]}&{values[1]}\\{values[2]}&{values[3]}\end{{pmatrix}}"


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 다항식과 내분점 자료다. 작동 원리는 다항식 계수합과 내분점 직선 y절편 문제를 각 5개 만든다."""
    specs: list[dict[str, Any]] = []
    polynomial_rows = [
        ((2, -1, 3), (1, 4, -2)),
        ((3, 0, -2, 5), (1, -1, 2, 0)),
        ((-2, 4, 1), (3, -1, 2)),
        ((1, 2, -3, 4), (-1, 3, 0, 2)),
        ((4, -2, 0), (2, 1, -5)),
    ]
    for index, (first, second) in enumerate(polynomial_rows, 1):
        answer = _polynomial_product_coefficient_sum(first, second)
        specs.append(_checked_problem(
            1,
            index,
            title=rf"다항식 $P(x)={_poly_text(first)}$, $Q(x)={_poly_text(second)}$에 대하여 $(P(x)+Q(x))(P(x)-Q(x))$의 모든 계수의 합을 구하시오.",
            answer=str(answer),
            tags=["#다항식의덧셈", "#다항식의뺄셈", "#다항식의곱셈", "#다항식의연산"],
            steps=[
                ("다항식의 모든 계수의 합은 x=1을 대입한 값임을 이용한다.", "주어진 곱 전체에 x=1을 대입한다."),
                ("합과 차의 곱을 두 제곱의 차로 계산한다.", rf"$P(1)^2-Q(1)^2={answer}$이므로 계수의 합은 ${answer}$이다."),
            ],
            answer_check=lambda a=first, b=second: _polynomial_product_coefficient_sum(a, b),
        ))

    line_rows = [
        ((0, 1), (6, 7), 1, 2, (1, 5)),
        ((-2, 4), (4, -2), 2, 1, (3, 3)),
        ((1, -3), (9, 5), 3, 1, (0, 4)),
        ((-4, -1), (6, 9), 2, 3, (4, -2)),
        ((2, 6), (7, 1), 4, 1, (-1, 2)),
    ]
    for index, row in enumerate(line_rows, 6):
        first, second, first_ratio, second_ratio, through = row
        answer = _internal_point_line_intercept(*row)
        specs.append(_checked_problem(
            1,
            index,
            title=rf"점 $A{first}$, $B{second}$에 대하여 $AP:PB={first_ratio}:{second_ratio}$인 내분점을 P라 한다. P와 점 $C{through}$를 지나는 직선의 y절편을 구하시오.",
            answer=str(answer),
            tags=["#내분점공식", "#선분의내분점", "#두점을지나는직선", "#공통수학2"],
            steps=[
                ("내분점 공식으로 P의 두 좌표를 구한다.", "반대쪽 비를 좌표에 곱해 비의 합으로 나눈다."),
                ("P와 C의 기울기를 구해 점기울기식에 대입한다.", rf"x=0일 때의 값을 정리하면 y절편은 ${answer}$이다."),
            ],
            answer_check=lambda values=row: _internal_point_line_intercept(*values),
        ))
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 포물선 꼭짓점 변환과 두 수열의 대칭항이다. 작동 원리는 축 대칭 좌표와 등차·등비중항 문제를 각 5개 만든다."""
    specs: list[dict[str, Any]] = []
    reflection_rows = [(2, -3, 5), (-1, 4, -2), (3, 1, 6), (-4, -2, 3), (1, 5, -4)]
    for index, row in enumerate(reflection_rows, 1):
        axis, vertical, move = row
        answer = _reflected_shifted_vertex_sum(*row)
        specs.append(_checked_problem(
            2,
            index,
            title=rf"포물선 $y=(x-({axis}))^2+({vertical})$를 x축대칭한 뒤 y축대칭하고, 마지막으로 y축 방향으로 {move}만큼 평행이동하였다. 최종 꼭짓점의 두 좌표의 합을 구하시오.",
            answer=str(answer),
            tags=["#x축대칭", "#y축대칭", "#y방향이동", "#이차함수의대칭이동"],
            steps=[
                ("처음 포물선의 꼭짓점 좌표를 읽는다.", "꼭짓점형에서 축과 세로 위치를 바로 확인한다."),
                ("x축대칭과 y축대칭을 차례로 적용한다.", "각 대칭은 해당 좌표의 부호를 바꾼다."),
                ("마지막 세로 이동량을 더해 좌표합을 계산한다.", rf"따라서 최종 꼭짓점의 좌표합은 ${answer}$이다."),
            ],
            answer_check=lambda values=row: _reflected_shifted_vertex_sum(*values),
        ))

    sequence_rows = [(3, 11, 2, 18), (-4, 10, 3, 27), (5, 17, 4, 36), (8, 20, 5, 45), (-2, 16, 8, 32)]
    for index, row in enumerate(sequence_rows, 6):
        arithmetic_first, arithmetic_second, geometric_first, geometric_second = row
        answer = _arithmetic_geometric_middle_sum(*row)
        specs.append(_checked_problem(
            2,
            index,
            title=rf"등차수열 $(a_n)$에서 $a_2={arithmetic_first}$, $a_8={arithmetic_second}$이고, 모든 항이 양수인 등비수열 $(b_n)$에서 $b_2={geometric_first}$, $b_8={geometric_second}$이다. $a_5+b_5$를 구하시오.",
            answer=str(answer),
            tags=["#등차중항", "#등비중항", "#등차수열의일반항", "#등비수열의일반항"],
            steps=[
                ("대칭 위치의 두 등차수열 항의 평균으로 가운데 항을 구한다.", "$a_5$는 $a_2$와 $a_8$의 등차중항이다."),
                ("양의 등비수열에서 가운데 항의 제곱은 양 끝항의 곱이다.", "$b_5$는 양의 제곱근을 택한다."),
                ("두 가운데 항을 더한다.", rf"따라서 $a_5+b_5={answer}$이다."),
            ],
            answer_check=lambda values=row: _arithmetic_geometric_middle_sum(*values),
        ))
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 함수의 극한과 로그부등식 범위다. 작동 원리는 극한 사칙연산과 정수 로그해 합 문제를 각 5개 만든다."""
    specs: list[dict[str, Any]] = []
    limit_rows = [(3, -1, 4), (-2, 5, 3), (4, 1, -2), (5, -3, 2), (-4, 2, 5)]
    for index, row in enumerate(limit_rows, 1):
        first_limit, second_limit, coefficient = row
        answer = _limit_algebra_value(*row)
        specs.append(_checked_problem(
            3,
            index,
            title=rf"$\lim_{{x\to a}}f(x)={first_limit}$, $\lim_{{x\to a}}g(x)={second_limit}$일 때 $\lim_{{x\to a}}\dfrac{{f(x)^2+({coefficient})g(x)}}{{f(x)-g(x)}}$의 값을 구하시오.",
            answer=str(answer),
            tags=["#극한의사칙연산", "#극한의성질", "#극한의정의", "#함수의극한"],
            steps=[
                ("분자의 제곱·상수배·합에 각각 극한 성질을 적용한다.", "유한한 두 극한이 존재하므로 항별 계산이 가능하다."),
                ("분모의 극한을 두 극한의 차로 계산한다.", "분모 극한이 0이 아닌지 확인한다."),
                ("몫의 극한 법칙을 적용한다.", "분자 극한을 분모 극한으로 나눈다."),
                ("부호와 분수를 정리한다.", rf"따라서 극한값은 ${answer}$이다."),
            ],
            alternatives=["f(x),g(x)를 각각 주어진 극한과 작은 오차의 합으로 두고 오차가 0으로 가는 과정을 확인할 수 있다."],
            answer_check=lambda values=row: _limit_algebra_value(*values),
        ))

    logarithm_rows = [(2, 1, 1, 4, -3, 20), (3, -2, 0, 3, -5, 30), (4, 3, 1, 3, 0, 70), (5, -1, 0, 2, -4, 30), (2, 4, 2, 5, 1, 40)]
    for index, row in enumerate(logarithm_rows, 6):
        base, shift, lower_exponent, upper_exponent, lower, upper = row
        answer = _bounded_log_integer_sum(*row)
        specs.append(_checked_problem(
            3,
            index,
            title=rf"정수 범위 ${lower}\le x\le {upper}$에서 로그부등식 ${lower_exponent}\le\log_{base}(x-({shift}))<{upper_exponent}$을 만족하는 모든 x의 합을 구하시오.",
            answer=str(answer),
            tags=["#로그방정식과로그부등식", "#로그부등식", "#로그의정의", "#밑", "#밑의변환"],
            steps=[
                ("로그의 밑이 1보다 큰지 확인한다.", "증가함수이므로 부등호 방향이 유지된다."),
                ("로그부등식을 진수의 거듭제곱 범위로 바꾼다.", "양 끝의 엄격·포함 부등호를 구분한다."),
                ("진수 조건과 처음 주어진 정수 범위를 함께 적용한다.", "범위의 교집합만 남긴다."),
                ("남은 정수를 빠짐없이 더한다.", rf"따라서 정수해의 합은 ${answer}$이다."),
            ],
            alternatives=["로그함수 그래프와 두 수평선 사이에 놓인 정수 x좌표를 찾아 합할 수 있다."],
            answer_check=lambda values=row: _bounded_log_integer_sum(*values),
        ))
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 일차 증가량 점화식과 이차함수 구분구적합이다. 작동 원리는 귀납적 항 계산과 정적분 극한 문제를 각 5개 만든다."""
    specs: list[dict[str, Any]] = []
    recurrence_rows = [(2, 3, -1, 8), (-4, 2, 5, 9), (5, -1, 7, 10), (1, 4, -3, 7), (6, 5, -6, 11)]
    for index, row in enumerate(recurrence_rows, 1):
        first, linear, constant, target = row
        answer = _recurrence_term(*row)
        specs.append(_checked_problem(
            4,
            index,
            title=rf"수열 $(a_n)$이 $a_1={first}$, $a_{{n+1}}=a_n+({linear})n+({constant})$을 만족한다. 점화식을 합으로 전개하고 수학적 귀납법으로 확인하여 $a_{target}$을 구하시오.",
            answer=str(answer),
            tags=["#귀납법의원리", "#귀납법증명", "#수학적귀납법", "#합의기호시그마", "#여러가지수열의합"],
            steps=[
                ("점화식을 두 이웃항의 차로 바꾼다.", "$a_{n+1}-a_n$이 n의 일차식이다."),
                ("n=1부터 목표 직전까지 양변을 더한다.", "좌변은 중간항이 소거되는 망원합이다."),
                ("자연수의 합을 사용해 일반항을 정리한다.", "첫째항을 마지막에 더한다."),
                ("n=1에서 일반항이 성립하고 n에서 n+1로 이어짐을 확인한다.", "이 과정이 수학적 귀납법 검증이다."),
                ("목표 첨자를 일반항에 대입한다.", rf"따라서 $a_{target}={answer}$이다."),
            ],
            alternatives=["점화식을 목표 첨자까지 직접 반복 계산해 일반항 결과를 검산할 수 있다."],
            answer_check=lambda values=row: _recurrence_term(*values),
        ))

    riemann_rows = [(1, 2, 1, 3), (2, -1, 4, 2), (3, 0, 2, 4), (1, -2, 5, 5), (2, 3, 1, 3)]
    for index, row in enumerate(riemann_rows, 6):
        quadratic, linear, constant, endpoint = row
        answer = _riemann_polynomial_integral(*row)
        specs.append(_checked_problem(
            4,
            index,
            title=rf"구간 $[0,{endpoint}]$을 n등분하고 $x_k=\dfrac{{{endpoint}k}}n$이라 할 때 $\lim_{{n\to\infty}}\sum_{{k=1}}^n\left(({quadratic})x_k^2+({linear})x_k+({constant})\right)\dfrac{{{endpoint}}}n$의 값을 구하시오.",
            answer=str(answer),
            tags=["#구간의분할", "#구분구적법", "#정적분의정의", "#곡선과x축사이의넓이"],
            steps=[
                ("주어진 합에서 구간 길이와 각 소구간 폭을 확인한다.", rf"$\Delta x={endpoint}/n$이다."),
                ("xₖ가 각 소구간의 오른쪽 끝점임을 확인한다.", "합은 이차함수의 오른쪽 끝점 리만합이다."),
                ("리만합의 극한을 0부터 끝점까지의 정적분으로 바꾼다.", "함수는 다항함수이므로 연속이다."),
                ("각 항의 원시함수를 구해 양 끝점에 대입한다.", "0에서의 값도 함께 뺀다."),
                ("정확한 분수로 정리한다.", rf"따라서 극한값은 ${answer}$이다."),
            ],
            alternatives=["자연수 제곱합과 일차합 공식을 합에 직접 대입한 뒤 n의 최고차항만 남겨 구할 수 있다."],
            answer_check=lambda values=row: _riemann_polynomial_integral(*values),
        ))
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 일차 가속도와 가역 2×2 행렬이다. 작동 원리는 이동거리와 역행렬 불변량 문제를 각 5개 만든다."""
    specs: list[dict[str, Any]] = []
    motion_rows = [(2, 1, 3, 4), (1, 2, 5, 6), (3, -1, 4, 3), (2, -2, 6, 5), (4, -1, 2, 4)]
    for index, row in enumerate(motion_rows, 1):
        acceleration_linear, acceleration_constant, initial_velocity, end_time = row
        answer = _accelerated_motion_distance(*row)
        specs.append(_checked_problem(
            5,
            index,
            title=rf"수직선 위를 움직이는 점의 가속도가 $a(t)=({acceleration_linear})t+({acceleration_constant})$이고 $v(0)={initial_velocity}$이다. $0\le t\le {end_time}$에서 속도가 음이 아닐 때 이 구간의 이동거리를 구하시오.",
            answer=str(answer),
            tags=["#가속도", "#속도", "#속도와가속도", "#속도와거리", "#위치변화량"],
            steps=[
                ("가속도는 속도의 도함수임을 이용한다.", "가속도를 적분해 속도함수의 기본형을 구한다."),
                ("초기 속도 조건으로 적분상수를 정한다.", "$t=0$을 속도함수에 대입한다."),
                ("완성된 속도함수가 주어진 구간에서 음이 아닌지 확인한다.", "방향 전환이 없으므로 거리와 변위가 같다."),
                ("속도함수를 다시 적분해 위치 변화량을 구한다.", "0부터 종료 시각까지의 정적분이다."),
                ("원시함수의 두 끝점 값을 뺀다.", "초기 시각의 항은 0이지만 생략 전에 확인한다."),
                ("분수와 정수를 정리한다.", rf"따라서 이동거리는 ${answer}$이다."),
            ],
            alternatives=[
                "가속도 그래프 아래 넓이로 속도 변화를 구한 뒤 속도함수 아래 넓이를 계산할 수 있다.",
                "위치함수를 삼차식으로 두고 두 번 미분해 가속도와 초기 속도 조건을 맞출 수 있다.",
            ],
            answer_check=lambda values=row: _accelerated_motion_distance(*values),
        ))

    matrix_rows = [(2, 1, 1, 3), (1, -2, 3, 4), (4, 1, -1, 2), (3, -1, 2, 1), (5, 2, 1, 1)]
    for index, matrix in enumerate(matrix_rows, 6):
        answer = _inverse_matrix_trace_determinant_sum(matrix)
        specs.append(_checked_problem(
            5,
            index,
            title=rf"가역행렬 $A={_matrix_text(matrix)}$에 대하여 역행렬 $A^{{-1}}$의 대각 성분의 합과 $\det(A^{{-1}})$의 합을 구하시오.",
            answer=str(answer),
            tags=["#역행렬", "#역행렬구하기", "#역행렬의성질", "#역행렬의정의", "#행렬의연산"],
            steps=[
                ("A의 행렬식을 계산해 0이 아님을 확인한다.", "가역성은 행렬식이 0이 아닌 것과 동치다."),
                ("2×2 역행렬 공식에서 대각 성분을 교환한다.", "비대각 성분에는 음의 부호를 붙인다."),
                ("바뀐 행렬 전체에 원래 행렬식의 역수를 곱한다.", "이로써 $A^{-1}$을 구한다."),
                ("역행렬의 두 대각 성분을 더한다.", "공통분모인 원래 행렬식을 유지한다."),
                ("행렬식 성질로 역행렬의 행렬식을 구한다.", "$\det(A^{-1})=1/\det(A)$이다."),
                ("두 값을 더해 기약분수로 정리한다.", rf"따라서 요구한 합은 ${answer}$이다."),
            ],
            alternatives=[
                "미지 행렬 B를 두고 AB=I의 네 성분 연립방정식을 풀어 역행렬을 구할 수 있다.",
                "고유값의 합·곱 관계를 이용해 역행렬의 대각합과 행렬식을 확인할 수 있다.",
            ],
            answer_check=lambda values=matrix: _inverse_matrix_trace_determinant_sum(values),
        ))
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v54 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v54 전체 카탈로그다. 작동 원리는 독립 정답 검산 후 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog = build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v54 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(
        catalog,
        expected_count=50,
        batch_id=BATCH_ID,
        model_name=MODEL_NAME,
        codebase_base=CODEBASE_BASE,
        seed_base=SEED_BASE,
    )


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v54 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(db_path, quests=validated_quests(), batch_id=BATCH_ID, validate_only=validate_only)


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v54 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
