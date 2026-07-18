from __future__ import annotations

import argparse
import itertools
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

BATCH_ID = "marketplace-original-v31"
MODEL_NAME = "aiflow-direct-authoring-v31"
CODEBASE_BASE = 20_260_992_000
SEED_BASE = 202_607_571_000


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


def _rational_identity_coefficient(constant: int) -> int:
    """필요 변수는 두 일차식의 대칭 상수다. 작동 원리는 두 유리식을 통분하고 합차공식으로 분자를 전개해 x의 계수를 구한다."""
    return 4 * constant


def _matrix_solution_square_sum(
    matrix: tuple[tuple[int, int], tuple[int, int]],
    constants: tuple[int, int],
) -> Fraction:
    """필요 변수는 가역 2차 행렬과 상수 벡터다. 작동 원리는 크래머 공식으로 두 미지수를 구해 제곱합을 계산한다."""
    (a, b), (c, d) = matrix
    first, second = constants
    determinant = a * d - b * c
    if determinant == 0:
        raise ValueError("가역인 계수행렬이 필요합니다.")
    x_value = Fraction(first * d - b * second, determinant)
    y_value = Fraction(a * second - first * c, determinant)
    return x_value * x_value + y_value * y_value


def _transformed_quadratic_root_product(
    base_axis: int,
    base_radius: int,
    right_shift: int,
    new_radius: int,
) -> int:
    """필요 변수는 원래 포물선 축·절편 반폭·대칭 후 가로 이동·새 반폭이다. 작동 원리는 변환된 축과 두 x절편으로 근의 곱을 구한다."""
    center = right_shift - base_axis
    return (center - new_radius) * (center + new_radius)


def _interval_guarantee_count(
    roots: tuple[int, int, int],
    intervals: tuple[tuple[int, int], ...],
) -> int:
    """필요 변수는 삼차함수의 세 근과 후보 구간들이다. 작동 원리는 각 구간 양 끝 함수값의 부호가 반대인 경우를 센다."""
    def value(x: int) -> int:
        """필요 변수는 함수값을 구할 정수다. 작동 원리는 세 일차인수를 직접 곱한다."""
        return (x - roots[0]) * (x - roots[1]) * (x - roots[2])

    return sum(value(left) * value(right) < 0 for left, right in intervals)


def _repeated_log_solution(base: int, shift: int, exponent: int) -> int:
    """필요 변수는 로그 밑·진수 이동량·우변 지수다. 작동 원리는 같은 로그 두 개를 하나로 모아 양의 진수 해를 구한다."""
    if base <= 1:
        raise ValueError("로그의 밑은 1보다 커야 합니다.")
    return shift + base**exponent


def _revenue_vertex_score(price_sum: int, cost_floor: int) -> Fraction:
    """필요 변수는 수익 이차식의 두 영점이다. 작동 원리는 두 영점의 중점과 꼭짓점 수익을 구해 합한다."""
    vertex = Fraction(price_sum + cost_floor, 2)
    maximum = Fraction((price_sum - cost_floor) ** 2, 4)
    return vertex + maximum


def _composition_constant_difference(
    first: tuple[int, int],
    second: tuple[int, int],
) -> int:
    """필요 변수는 두 일차함수의 기울기와 절편이다. 작동 원리는 두 합성함수를 전개해 공통 일차항을 소거하고 상수 차를 구한다."""
    a, b = first
    c, d = second
    return a * d + b - c * b - d


def _tangent_length_square(
    center: tuple[int, int],
    radius: int,
    point: tuple[int, int],
) -> int:
    """필요 변수는 원의 중심·반지름과 외부점이다. 작동 원리는 중심·접점·외부점 직각삼각형에서 접선 길이의 제곱을 구한다."""
    distance_square = (point[0] - center[0]) ** 2 + (point[1] - center[1]) ** 2
    answer = distance_square - radius * radius
    if answer <= 0:
        raise ValueError("점은 원의 외부에 있어야 합니다.")
    return answer


def _one_red_probability(red: int, blue: int) -> Fraction:
    """필요 변수는 빨간 공과 파란 공의 개수다. 작동 원리는 라벨이 있는 공의 모든 두 공 조합을 열거해 정확히 한 빨간 공인 비율을 구한다."""
    balls = tuple([1] * red + [0] * blue)
    outcomes = list(itertools.combinations(range(len(balls)), 2))
    favorable = sum(balls[first] + balls[second] == 1 for first, second in outcomes)
    return Fraction(favorable, len(outcomes))


def _zero_integral_parameter(
    lower: int,
    upper: int,
    quadratic: int,
    linear: int,
) -> Fraction:
    """필요 변수는 적분구간과 이차·일차항 계수다. 작동 원리는 상수항을 제외한 정적분을 계산해 전체 적분이 0이 되는 상수를 구한다."""
    if lower == upper:
        raise ValueError("길이가 양수인 적분구간이 필요합니다.")
    nonconstant = (
        Fraction(quadratic * (upper**3 - lower**3), 3)
        + Fraction(linear * (upper**2 - lower**2), 2)
    )
    return -nonconstant / (upper - lower)


def _matrix_text(matrix: tuple[tuple[int, int], tuple[int, int]]) -> str:
    """필요 변수는 2차 정사각행렬이다. 작동 원리는 본문에 사용할 LaTeX 행렬 문자열로 변환한다."""
    return rf"\begin{{pmatrix}}{matrix[0][0]}&{matrix[0][1]}\\{matrix[1][0]}&{matrix[1][1]}\end{{pmatrix}}"


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 유리식 항등식과 행렬 연립방정식이다. 작동 원리는 통분·합차공식과 행렬 성분 비교 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    for index, constant in enumerate([2, 3, -2, 4, -3], 1):
        answer = _rational_identity_coefficient(constant)
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"항등식 $\dfrac{{x+({constant})}}{{x-({constant})}}-\dfrac{{x-({constant})}}{{x+({constant})}}=\dfrac{{Kx}}{{x^2-{constant**2}}}$에서 상수 K를 구하시오.",
                answer=str(answer),
                tags=["#통분", "#합차공식", "#항등식의성질", "#유리식의계산"],
                steps=[
                    ("왼쪽 두 유리식을 공통분모로 통분한다.", rf"공통분모는 $(x-{constant})(x+{constant})=x^2-{constant**2}$이다."),
                    ("분자를 합차공식으로 전개해 x의 계수를 비교한다.", rf"분자는 $(x+{constant})^2-(x-{constant})^2={answer}x$이므로 $K={answer}$이다."),
                ],
                answer_check=lambda value=constant: _rational_identity_coefficient(value),
            )
        )
    matrix_rows = [
        (((1, 2), (3, 1)), (2, 1)),
        (((2, -1), (1, 2)), (-1, 3)),
        (((3, 1), (-1, 2)), (2, -3)),
        (((4, -1), (2, 3)), (-2, -1)),
        (((1, -3), (2, 5)), (3, 2)),
    ]
    for index, (matrix, solution) in enumerate(matrix_rows, 6):
        constants = (
            matrix[0][0] * solution[0] + matrix[0][1] * solution[1],
            matrix[1][0] * solution[0] + matrix[1][1] * solution[1],
        )
        answer = _matrix_solution_square_sum(matrix, constants)
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"행렬의 곱 ${_matrix_text(matrix)}\begin{{pmatrix}}x\\y\end{{pmatrix}}=\begin{{pmatrix}}{constants[0]}\\{constants[1]}\end{{pmatrix}}$에서 성분을 비교하여 $x^2+y^2$을 구하시오.",
                answer=str(answer),
                tags=["#행렬을이용한연립방정식", "#행렬의곱셈", "#이"],
                steps=[
                    ("행렬 곱의 각 행에서 연립일차방정식을 얻는다.", "첫째 행과 둘째 행의 성분을 각각 상수 벡터와 같게 둔다."),
                    ("연립방정식을 풀어 두 미지수의 제곱을 더한다.", rf"$(x,y)=({solution[0]},{solution[1]})$이므로 $x^2+y^2={answer}$이다."),
                ],
                answer_check=lambda coefficients=matrix, vector=constants: _matrix_solution_square_sum(coefficients, vector),
            )
        )
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 변환된 이차함수와 삼차함수 후보 구간이다. 작동 원리는 그래프 이동과 중간값정리 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    transform_rows = [
        (1, 4, 3, 2),
        (-2, 5, 4, 3),
        (3, 6, -1, 4),
        (-1, 4, 5, 1),
        (2, 7, 0, 5),
    ]
    for index, (base_axis, base_radius, right_shift, new_radius) in enumerate(transform_rows, 1):
        vertical_shift = base_radius**2 - new_radius**2
        center = right_shift - base_axis
        answer = _transformed_quadratic_root_product(base_axis, base_radius, right_shift, new_radius)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"이차함수 $f(x)=(x-({base_axis}))^2-{base_radius**2}$의 그래프를 y축 대칭이동한 뒤 오른쪽으로 {right_shift}, 위로 {vertical_shift}만큼 평행이동해 얻은 그래프와 x축의 두 교점의 x좌표의 곱을 구하시오.",
                answer=str(answer),
                tags=["#이차함수와이차방정식", "#이차함수의대칭이동", "#이차함수의평행이동", "#대칭이동"],
                steps=[
                    ("y축 대칭이동은 식의 x를 -x로 바꾼다.", rf"포물선의 축은 $x={-base_axis}$로 이동한다."),
                    ("가로·세로 평행이동 후 꼭짓점형을 정리한다.", rf"새 식은 $(x-({center}))^2-{new_radius**2}$이다."),
                    ("x축과의 교점에서 함수값을 0으로 두고 두 근의 곱을 구한다.", rf"두 근은 ${center}-{new_radius}, {center}+{new_radius}$이므로 곱은 ${answer}$이다."),
                ],
                answer_check=lambda h=base_axis, r=base_radius, p=right_shift, s=new_radius: _transformed_quadratic_root_product(h, r, p, s),
            )
        )
    interval_rows = [
        ((-3, 1, 4), ((-5, -4), (-4, 0), (0, 3), (2, 5))),
        ((-4, -1, 3), ((-6, -3), (-3, 0), (0, 2), (2, 5))),
        ((-2, 2, 5), ((-4, 0), (-1, 1), (1, 4), (4, 7))),
        ((-5, 0, 4), ((-7, -4), (-4, -1), (1, 3), (3, 6))),
        ((-1, 3, 6), ((-3, 0), (0, 2), (2, 5), (5, 8))),
    ]
    for index, (roots, intervals) in enumerate(interval_rows, 6):
        answer = _interval_guarantee_count(roots, intervals)
        interval_text = ", ".join(rf"[{left},{right}]" for left, right in intervals)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"연속함수 $f(x)=(x-({roots[0]}))(x-({roots[1]}))(x-({roots[2]}))$에 대하여 후보 구간 ${interval_text}$ 중 중간값정리로 내부에 영점이 존재함을 보장할 수 있는 구간의 개수를 구하시오.",
                answer=str(answer),
                tags=["#중간값정리", "#함수의연속", "#함수"],
                steps=[
                    ("다항함수는 모든 실수에서 연속임을 확인한다.", "각 후보 닫힌구간에서 중간값정리를 적용할 수 있다."),
                    ("각 구간 양 끝의 함수값 부호를 비교한다.", "곱이 음수이면 0이 두 함수값 사이에 있다."),
                    ("부호가 반대인 후보 구간을 센다.", rf"따라서 영점 존재가 보장되는 구간은 ${answer}$개이다."),
                ],
                answer_check=lambda zeros=roots, candidates=intervals: _interval_guarantee_count(zeros, candidates),
            )
        )
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 같은 진수의 로그방정식과 수익 이차함수다. 작동 원리는 진수조건과 최대화 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    log_rows = [(2, 1, 3), (3, -2, 2), (5, 4, 2), (4, -1, 3), (10, 2, 2)]
    for index, (base, shift, exponent) in enumerate(log_rows, 1):
        answer = _repeated_log_solution(base, shift, exponent)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"로그방정식 $\log_{{{base}}}(x-({shift}))+\log_{{{base}}}(x-({shift}))={2 * exponent}$을 만족하는 실수 x를 구하시오.",
                answer=str(answer),
                tags=["#진수", "#진수조건", "#로그방정식", "#로그방정식과로그부등식"],
                steps=[
                    ("로그의 진수조건을 확인한다.", rf"$x-({shift})>0$이어야 한다."),
                    ("같은 로그 두 항을 계수 2로 묶는다.", rf"$2\log_{{{base}}}(x-({shift}))={2 * exponent}$이다."),
                    ("양변을 2로 나누고 로그 정의를 적용한다.", rf"$x-({shift})={base}^{exponent}$이다."),
                    ("구한 값이 진수조건을 만족하는지 확인한다.", rf"따라서 $x={answer}$이다."),
                ],
                alternatives=["두 로그를 곱의 로그로 합쳐 (x-shift)²에 대한 방정식을 푼 뒤 진수조건으로 양의 해만 선택할 수 있다."],
                answer_check=lambda a=base, h=shift, n=exponent: _repeated_log_solution(a, h, n),
            )
        )
    revenue_rows = [(10, 2), (15, 3), (8, -2), (20, 4), (13, 1)]
    for index, (price_sum, cost_floor) in enumerate(revenue_rows, 6):
        vertex = Fraction(price_sum + cost_floor, 2)
        maximum = Fraction((price_sum - cost_floor) ** 2, 4)
        answer = _revenue_vertex_score(price_sum, cost_floor)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"판매량 x에 따른 수익이 $R(x)=({price_sum}-x)(x-({cost_floor}))$이고 ${cost_floor}\le x\le {price_sum}$일 때, 수익을 최대로 만드는 x와 최대 수익의 합을 구하시오.",
                answer=str(answer),
                tags=["#최대최소문제", "#증가함수", "#감소함수", "#이차함수의최대최소"],
                steps=[
                    ("수익식을 아래로 열린 이차함수로 확인한다.", "두 일차인수의 최고차항 곱은 -x²이다."),
                    ("두 영점의 중점으로 꼭짓점의 x좌표를 구한다.", rf"수익을 최대로 만드는 값은 $x={vertex}$이다."),
                    ("꼭짓점의 x를 수익식에 대입한다.", rf"최대 수익은 ${maximum}$이다."),
                    ("최적 판매량과 최대 수익을 더한다.", rf"따라서 합은 ${answer}$이다."),
                ],
                alternatives=["R'(x)의 부호가 꼭짓점 전에는 양수, 후에는 음수임을 이용해 최대를 판정할 수 있다."],
                answer_check=lambda upper=price_sum, lower=cost_floor: _revenue_vertex_score(upper, lower),
            )
        )
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 일차함수와 원·외부점이다. 작동 원리는 합성함수 차와 접선 길이 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    composition_rows = [
        ((2, 3), (4, -1)),
        ((-1, 5), (3, 2)),
        ((4, -2), (-2, 3)),
        ((3, 1), (5, -4)),
        ((-3, -1), (2, 6)),
    ]
    for index, (first, second) in enumerate(composition_rows, 1):
        answer = _composition_constant_difference(first, second)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"일차함수 $f(x)={first[0]}x+({first[1]})$, $g(x)={second[0]}x+({second[1]})$에 대하여 $(f\circ g)(x)-(g\circ f)(x)$의 값을 구하시오.",
                answer=str(answer),
                tags=["#합성함수의성질", "#합성함수의정의", "#합성함수", "#함수"],
                steps=[
                    ("g(x)를 f의 입력에 대입한다.", rf"$(f\circ g)(x)={first[0]}({second[0]}x+({second[1]}))+({first[1]})$이다."),
                    ("f(x)를 g의 입력에 대입한다.", rf"$(g\circ f)(x)={second[0]}({first[0]}x+({first[1]}))+({second[1]})$이다."),
                    ("두 합성함수의 일차항을 비교한다.", rf"두 식의 x계수는 모두 ${first[0] * second[0]}$이다."),
                    ("두 식을 빼 공통 일차항을 소거한다.", "차는 x와 무관한 상수이다."),
                    ("남은 상수항을 계산한다.", rf"따라서 값은 ${answer}$이다."),
                ],
                alternatives=["합성 순서 교환에서 생기는 상수 차 공식을 직접 유도해 대입할 수 있다."],
                answer_check=lambda f=first, g=second: _composition_constant_difference(f, g),
            )
        )
    tangent_rows = [
        ((0, 0), 3, (5, 4)),
        ((2, -1), 4, (8, 7)),
        ((-3, 2), 5, (4, 8)),
        ((1, 3), 2, (-4, 7)),
        ((-2, -2), 6, (6, 5)),
    ]
    for index, (center, radius, point) in enumerate(tangent_rows, 6):
        distance_square = (point[0] - center[0]) ** 2 + (point[1] - center[1]) ** 2
        answer = _tangent_length_square(center, radius, point)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"원 $(x-({center[0]}))^2+(y-({center[1]}))^2={radius**2}$의 외부점 $P({point[0]},{point[1]})$에서 그은 접선의 길이의 제곱을 구하시오.",
                answer=str(answer),
                tags=["#원의방정식", "#접선의방정식", "#접선의기울기", "#두점사이의거리"],
                steps=[
                    ("원의 중심과 반지름을 읽는다.", rf"중심은 $({center[0]},{center[1]})$이고 반지름은 ${radius}$이다."),
                    ("중심과 외부점 사이 거리의 제곱을 구한다.", rf"$OP^2={distance_square}$이다."),
                    ("접점에서 반지름과 접선이 수직임을 이용한다.", "중심·접점·외부점이 직각삼각형을 이룬다."),
                    ("피타고라스 정리를 접선 길이 T에 적용한다.", rf"$T^2=OP^2-{radius}^2$이다."),
                    ("두 제곱값의 차를 계산한다.", rf"따라서 접선 길이의 제곱은 ${answer}$이다."),
                ],
                alternatives=["원의 방정식과 외부점을 지나는 직선을 연립해 판별식이 0이 되는 접선 조건으로 검산할 수 있다."],
                answer_check=lambda origin=center, r=radius, external=point: _tangent_length_square(origin, r, external),
            )
        )
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 비복원 추출 공 개수와 정적분 매개변수다. 작동 원리는 조합 확률과 적분 조건 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    probability_rows = [(3, 5), (4, 6), (5, 3), (2, 7), (6, 4)]
    for index, (red, blue) in enumerate(probability_rows, 1):
        favorable = red * blue
        total = (red + blue) * (red + blue - 1) // 2
        answer = _one_red_probability(red, blue)
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"서로 구별되는 빨간 공 {red}개와 파란 공 {blue}개가 든 상자에서 동시에 공 2개를 뽑을 때, 정확히 한 개만 빨간 공일 확률을 구하시오.",
                answer=str(answer),
                tags=["#사건의곱", "#조합", "#경우의수", "#곱의법칙"],
                steps=[
                    ("전체 공의 개수를 구한다.", rf"전체는 ${red + blue}$개이다."),
                    ("순서를 구별하지 않는 두 공 선택의 전체 경우를 센다.", rf"전체 경우는 $\binom{{{red + blue}}}2={total}$이다."),
                    ("빨간 공 한 개를 고르는 경우를 센다.", rf"${red}$가지이다."),
                    ("파란 공 한 개를 고르는 경우를 센다.", rf"${blue}$가지이다."),
                    ("곱의 법칙으로 유리한 경우를 구한다.", rf"유리한 경우는 ${red}\cdot {blue}={favorable}$가지이다."),
                    ("유리한 경우를 전체 경우로 나눈다.", rf"따라서 확률은 ${answer}$이다."),
                ],
                alternatives=[
                    "첫 추출의 색에 따라 빨강-파랑과 파랑-빨강 두 순서 확률을 더할 수 있다.",
                    "라벨이 있는 모든 두 공 조합을 열거해 색 합이 1인 경우를 직접 셀 수 있다.",
                ],
                answer_check=lambda first=red, second=blue: _one_red_probability(first, second),
            )
        )
    integral_rows = [
        (0, 3, 2, -1),
        (-1, 2, 3, 4),
        (1, 4, -2, 5),
        (-2, 3, 1, -3),
        (2, 6, 4, 2),
    ]
    for index, (lower, upper, quadratic, linear) in enumerate(integral_rows, 6):
        answer = _zero_integral_parameter(lower, upper, quadratic, linear)
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"정적분 $\int_{{{lower}}}^{{{upper}}}({quadratic}x^2+({linear})x+k)dx=0$을 만족하는 상수 k를 구하시오.",
                answer=str(answer),
                tags=["#정적분", "#정적분의성질", "#정적분의계산", "#미정계수법"],
                steps=[
                    ("적분의 합에 대한 선형성을 적용한다.", "이차항·일차항·상수항의 적분을 분리한다."),
                    ("이차항을 적분한다.", rf"$\int {quadratic}x^2dx=\dfrac{{{quadratic}}}3x^3$이다."),
                    ("일차항을 적분한다.", rf"$\int ({linear})x dx=\dfrac{{{linear}}}2x^2$이다."),
                    ("상수항의 정적분을 계산한다.", rf"$\int_{{{lower}}}^{{{upper}}}kdx=({upper - lower})k$이다."),
                    ("세 적분의 합을 0과 같게 둔다.", "k에 대한 일차방정식을 얻는다."),
                    ("방정식을 풀어 상수를 구한다.", rf"따라서 $k={answer}$이다."),
                ],
                alternatives=[
                    "k를 제외한 부분의 부호 있는 넓이를 먼저 구하고 같은 크기의 반대 상수 넓이를 정할 수 있다.",
                    "구한 k를 원래 정적분에 대입해 정확한 분수 연산으로 결과가 0인지 검산할 수 있다.",
                ],
                answer_check=lambda left=lower, right=upper, a=quadratic, b=linear: _zero_integral_parameter(left, right, a, b),
            )
        )
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v31 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v31 전체 카탈로그다. 작동 원리는 독립 정답 검산 후 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog = build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v31 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(
        catalog,
        expected_count=50,
        batch_id=BATCH_ID,
        model_name=MODEL_NAME,
        codebase_base=CODEBASE_BASE,
        seed_base=SEED_BASE,
    )


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v31 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(
        db_path,
        quests=validated_quests(),
        batch_id=BATCH_ID,
        validate_only=validate_only,
    )


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v31 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
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
