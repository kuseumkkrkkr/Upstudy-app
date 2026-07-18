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

BATCH_ID = "marketplace-original-v27"
MODEL_NAME = "aiflow-direct-authoring-v27"
CODEBASE_BASE = 20_260_988_000
SEED_BASE = 202_607_567_000


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


def _row_column_product(
    left: tuple[tuple[int, int], tuple[int, int]],
    right: tuple[tuple[int, int], tuple[int, int]],
    row_index: int,
    column_index: int,
) -> int:
    """필요 변수는 두 2차 정사각행렬과 행·열 번호다. 작동 원리는 선택한 행과 열의 대응 성분을 곱해 합한다."""
    return sum(
        left[row_index - 1][offset] * right[offset][column_index - 1]
        for offset in range(2)
    )


def _linear_combination_coefficient(
    first: tuple[int, int, int],
    second: tuple[int, int, int],
    first_scale: int,
    second_scale: int,
) -> int:
    """필요 변수는 두 이차다항식의 계수와 선형결합 배수다. 작동 원리는 x의 계수끼리 지정된 배수로 결합한다."""
    return first_scale * first[1] + second_scale * second[1]


def _quadratic_root_distance(a: int, b: int, c: int) -> Fraction:
    """필요 변수는 이차방정식의 세 계수다. 작동 원리는 판별식을 확인하고 근의 공식으로 두 실근의 거리를 구한다."""
    discriminant = b * b - 4 * a * c
    root = math.isqrt(discriminant)
    if root * root != discriminant:
        raise ValueError("판별식이 완전제곱이 아닙니다.")
    first = Fraction(-b + root, 2 * a)
    second = Fraction(-b - root, 2 * a)
    return abs(first - second)


def _perpendicular_intercept(slope: int, point_x: int, point_y: int) -> Fraction:
    """필요 변수는 기준 직선의 기울기와 통과점이다. 작동 원리는 수직 기울기 -1/m을 적용해 y절편을 정확한 분수로 구한다."""
    if slope == 0:
        raise ValueError("기준 직선의 기울기는 0이 아니어야 합니다.")
    return Fraction(point_y, 1) + Fraction(point_x, slope)


def _matrix_solution_sum(
    matrix: tuple[tuple[int, int], tuple[int, int]],
    constants: tuple[int, int],
) -> Fraction:
    """필요 변수는 가역 2차 정사각행렬과 상수 벡터다. 작동 원리는 행렬식과 크래머 공식으로 두 미지수의 합을 구한다."""
    (a, b), (c, d) = matrix
    first_constant, second_constant = constants
    determinant = a * d - b * c
    if determinant == 0:
        raise ValueError("계수행렬이 가역이 아닙니다.")
    x_value = Fraction(first_constant * d - b * second_constant, determinant)
    y_value = Fraction(a * second_constant - first_constant * c, determinant)
    return x_value + y_value


def _log_horizontal_intersection(base: int, shift_x: int, shift_y: int, height: int) -> int:
    """필요 변수는 로그함수의 밑·평행이동량과 수평선 높이다. 작동 원리는 로그 정의를 지수식으로 바꿔 교점의 x좌표를 구한다."""
    if base <= 1 or height < shift_y:
        raise ValueError("정수 좌표 로그 교점 조건을 만족하지 않습니다.")
    return shift_x + base ** (height - shift_y)


def _continuity_value(
    point: int,
    left: tuple[int, int],
    right: tuple[int, int],
) -> int:
    """필요 변수는 경계점과 좌우 일차식 계수다. 작동 원리는 두 편극한을 계산해 일치할 때 연속이 되는 함수값을 반환한다."""
    left_limit = left[0] * point + left[1]
    right_limit = right[0] * point + right[1]
    if left_limit != right_limit:
        raise ValueError("좌극한과 우극한이 일치하지 않습니다.")
    return left_limit


def _radical_limit(point: int, constant: int) -> Fraction:
    """필요 변수는 극한점과 제곱근 안의 상수다. 작동 원리는 켤레식으로 유리화한 분모를 극한점에서 계산한다."""
    radicand = point + constant
    root = math.isqrt(radicand)
    if root == 0 or root * root != radicand:
        raise ValueError("양의 완전제곱 근호만 사용할 수 있습니다.")
    return Fraction(1, 2 * root)


def _travel_distance(scale: int, turning_time: int, end_time: int) -> Fraction:
    """필요 변수는 속도 비례상수·방향 전환 시각·종료 시각이다. 작동 원리는 속도의 절댓값을 두 삼각형 넓이로 적분한다."""
    if scale <= 0 or not 0 < turning_time < end_time:
        raise ValueError("속도와 시간 구간 조건이 올바르지 않습니다.")
    return Fraction(
        scale * (turning_time**2 + (end_time - turning_time) ** 2),
        2,
    )


def _shifted_radical_intersection(shift_x: int, shift_y: int, height: int) -> int:
    """필요 변수는 무리함수의 가로·세로 이동량과 수평선 높이다. 작동 원리는 정의역 조건을 확인한 뒤 제곱해 x좌표를 구한다."""
    difference = height - shift_y
    if difference < 0:
        raise ValueError("수평선이 무리함수의 시작점보다 낮습니다.")
    return shift_x + difference**2


def _matrix_text(matrix: tuple[tuple[int, int], tuple[int, int]]) -> str:
    """필요 변수는 2차 정사각행렬이다. 작동 원리는 본문에 사용할 LaTeX 행렬 문자열로 변환한다."""
    return rf"\begin{{pmatrix}}{matrix[0][0]}&{matrix[0][1]}\\{matrix[1][0]}&{matrix[1][1]}\end{{pmatrix}}"


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 행렬과 두 다항식의 계수다. 작동 원리는 행·열 연산과 다항식 선형결합 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    matrix_rows = [
        (((1, 2), (3, 4)), ((5, 6), (7, 8)), 1, 2),
        (((-2, 3), (4, 1)), ((1, -1), (5, 2)), 2, 1),
        (((0, 5), (-3, 2)), ((4, 7), (-2, 1)), 1, 1),
        (((6, -1), (2, 3)), ((-2, 4), (5, -3)), 2, 2),
        (((3, 4), (-1, 6)), ((2, 0), (7, -5)), 1, 2),
    ]
    for index, (left, right, row_index, column_index) in enumerate(matrix_rows, 1):
        answer = _row_column_product(left, right, row_index, column_index)
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"행렬 $A={_matrix_text(left)}$, $B={_matrix_text(right)}$일 때, A의 {row_index}번째 행과 B의 {column_index}번째 열의 스칼라곱을 구하시오.",
                answer=str(answer),
                tags=["#스칼라곱", "#행", "#열", "#공통수학2"],
                steps=[
                    ("지정된 행과 열의 성분을 순서대로 찾는다.", rf"A의 {row_index}번째 행과 B의 {column_index}번째 열을 선택한다."),
                    ("대응 성분의 곱을 더한다.", rf"두 곱의 합은 ${answer}$이다."),
                ],
                answer_check=lambda a=left, b=right, r=row_index, c=column_index: _row_column_product(a, b, r, c),
            )
        )
    polynomial_rows = [
        ((2, 3, -1), (1, -2, 4), 2, -3),
        ((-1, 5, 2), (3, 1, -6), 4, -2),
        ((4, -3, 7), (-2, 6, 1), -1, 2),
        ((3, 2, -5), (5, -4, 3), 3, -1),
        ((-2, -1, 6), (1, 7, -2), -2, 3),
    ]
    for index, (first, second, first_scale, second_scale) in enumerate(polynomial_rows, 6):
        answer = _linear_combination_coefficient(first, second, first_scale, second_scale)
        first_text = rf"{first[0]}x^2+({first[1]})x+({first[2]})"
        second_text = rf"{second[0]}x^2+({second[1]})x+({second[2]})"
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"다항식 $P(x)={first_text}$, $Q(x)={second_text}$일 때, ${first_scale}P(x)+({second_scale})Q(x)$에서 x의 계수를 구하시오.",
                answer=str(answer),
                tags=["#다항식", "#다항식의덧셈", "#다항식의뺄셈"],
                steps=[
                    ("두 다항식에서 x의 계수만 찾는다.", rf"P와 Q의 x의 계수는 각각 ${first[1]}$, ${second[1]}$이다."),
                    ("선형결합의 배수를 계수에 적용한다.", rf"${first_scale}\cdot({first[1]})+({second_scale})\cdot({second[1]})={answer}$이다."),
                ],
                answer_check=lambda p=first, q=second, u=first_scale, v=second_scale: _linear_combination_coefficient(p, q, u, v),
            )
        )
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 이차방정식의 근과 직선의 기울기·통과점이다. 작동 원리는 근의 공식과 수직 조건 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    root_rows = [(-2, 5), (1, 6), (-4, 2), (3, 9), (-5, -1)]
    for index, (first_root, second_root) in enumerate(root_rows, 1):
        b = -(first_root + second_root)
        c = first_root * second_root
        discriminant = b * b - 4 * c
        answer = _quadratic_root_distance(1, b, c)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"이차방정식 $x^2+({b})x+({c})=0$의 두 실근 사이의 거리를 근의 공식으로 구하시오.",
                answer=str(answer),
                tags=["#근의공식", "#실근조건", "#이차방정식의풀이"],
                steps=[
                    ("판별식을 계산해 실근 조건을 확인한다.", rf"$D=({b})^2-4\cdot1\cdot({c})={discriminant}$이다."),
                    ("근의 공식에 계수를 대입한다.", rf"$x=\dfrac{{-({b})\pm\sqrt{{{discriminant}}}}}2$이다."),
                    ("두 근의 차의 절댓값을 계산한다.", rf"두 실근 사이의 거리는 ${answer}$이다."),
                ],
                answer_check=lambda coefficient_b=b, coefficient_c=c: _quadratic_root_distance(1, coefficient_b, coefficient_c),
            )
        )
    line_rows = [(2, 4, 3), (-3, 6, 1), (4, 8, -2), (-2, -4, 5), (5, 10, -1)]
    for index, (slope, point_x, point_y) in enumerate(line_rows, 6):
        answer = _perpendicular_intercept(slope, point_x, point_y)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"기울기가 ${slope}$인 직선에 수직이고 점 $({point_x},{point_y})$을 지나는 직선의 y절편을 구하시오.",
                answer=str(answer),
                tags=["#수직조건", "#점기울기형", "#절편"],
                steps=[
                    ("수직인 두 직선의 기울기 곱을 이용한다.", rf"구할 직선의 기울기는 $-\dfrac1{{{slope}}}$이다."),
                    ("점기울기형에 통과점을 대입한다.", rf"$y-({point_y})=-\dfrac1{{{slope}}}(x-({point_x}))$이다."),
                    ("x=0을 대입해 y절편을 구한다.", rf"따라서 y절편은 ${answer}$이다."),
                ],
                answer_check=lambda m=slope, x=point_x, y=point_y: _perpendicular_intercept(m, x, y),
            )
        )
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 가역행렬 연립방정식과 평행이동한 로그함수다. 작동 원리는 역행렬과 로그 정의 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    matrix_rows = [
        (((2, 1), (1, -1)), (3, 2)),
        (((1, 2), (3, 4)), (-1, 3)),
        (((3, -1), (2, 1)), (2, -4)),
        (((4, 1), (-2, 3)), (1, 5)),
        (((2, -3), (5, 2)), (-2, 1)),
    ]
    for index, (matrix, solution) in enumerate(matrix_rows, 1):
        constants = (
            matrix[0][0] * solution[0] + matrix[0][1] * solution[1],
            matrix[1][0] * solution[0] + matrix[1][1] * solution[1],
        )
        determinant = matrix[0][0] * matrix[1][1] - matrix[0][1] * matrix[1][0]
        answer = _matrix_solution_sum(matrix, constants)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"행렬방정식 ${_matrix_text(matrix)}\begin{{pmatrix}}x\\y\end{{pmatrix}}=\begin{{pmatrix}}{constants[0]}\\{constants[1]}\end{{pmatrix}}$을 역행렬로 풀어 $x+y$를 구하시오.",
                answer=str(answer),
                tags=["#역행렬", "#역행렬구하기", "#역행렬의성질", "#역행렬의정의", "#연립일차방정식과행렬"],
                steps=[
                    ("계수행렬의 행렬식을 계산한다.", rf"행렬식은 ${determinant}$이므로 역행렬이 존재한다."),
                    ("2차 정사각행렬의 역행렬 공식을 적용한다.", "주대각 성분을 바꾸고 나머지 두 성분의 부호를 바꾼다."),
                    ("양변의 왼쪽에 역행렬을 곱한다.", rf"해는 $(x,y)=({solution[0]},{solution[1]})$이다."),
                    ("두 미지수의 값을 더한다.", rf"따라서 $x+y={answer}$이다."),
                ],
                alternatives=["두 연립일차방정식을 가감법으로 풀어 역행렬 계산 결과를 검산할 수 있다."],
                answer_check=lambda coefficients=matrix, vector=constants: _matrix_solution_sum(coefficients, vector),
            )
        )
    log_rows = [(2, 1, -1, 3), (3, -2, 1, 3), (4, 3, 0, 2), (5, -1, 2, 4), (10, 2, -2, 1)]
    for index, (base, shift_x, shift_y, height) in enumerate(log_rows, 6):
        answer = _log_horizontal_intersection(base, shift_x, shift_y, height)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"로그함수 $y=\log_{{{base}}}(x-({shift_x}))+({shift_y})$와 직선 $y={height}$의 교점의 x좌표를 구하시오.",
                answer=str(answer),
                tags=["#로그함수", "#로그함수의그래프", "#로그함수의성질", "#로그함수의평행이동"],
                steps=[
                    ("두 그래프의 y값을 같게 둔다.", rf"$\log_{{{base}}}(x-({shift_x}))+({shift_y})={height}$이다."),
                    ("로그항만 남긴다.", rf"$\log_{{{base}}}(x-({shift_x}))={height - shift_y}$이다."),
                    ("로그 정의로 지수식으로 바꾼다.", rf"$x-({shift_x})={base}^{{{height - shift_y}}}$이다."),
                    ("x를 구하고 정의역을 확인한다.", rf"교점의 x좌표는 ${answer}$이다."),
                ],
                alternatives=["기본 로그함수의 대표점을 주어진 만큼 평행이동해 교점을 읽을 수 있다."],
                answer_check=lambda a=base, h=shift_x, k=shift_y, c=height: _log_horizontal_intersection(a, h, k, c),
            )
        )
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 조각함수의 경계식과 근호 극한 조건이다. 작동 원리는 연속의 정의와 유리화 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    continuity_rows = [
        (1, (2, 3), (-1, 6)),
        (2, (3, -1), (1, 3)),
        (-1, (2, 4), (-3, -1)),
        (3, (-1, 7), (2, -2)),
        (-2, (4, 10), (-1, 0)),
    ]
    for index, (point, left, right) in enumerate(continuity_rows, 1):
        answer = _continuity_value(point, left, right)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"함수 $f(x)=\begin{{cases}}{left[0]}x+({left[1]})&(x<{point})\\k&(x={point})\\{right[0]}x+({right[1]})&(x>{point})\end{{cases}}$가 $x={point}$에서 연속일 때 k를 구하시오.",
                answer=str(answer),
                tags=["#연속의정의", "#연속함수의성질", "#좌극한", "#우극한"],
                steps=[
                    ("왼쪽 식으로 좌극한을 계산한다.", rf"$\lim_{{x\to {point}-}}f(x)={answer}$이다."),
                    ("오른쪽 식으로 우극한을 계산한다.", rf"$\lim_{{x\to {point}+}}f(x)={answer}$이다."),
                    ("두 편극한이 같아 극한이 존재함을 확인한다.", rf"$\lim_{{x\to {point}}}f(x)={answer}$이다."),
                    ("연속이면 함수값과 극한값이 같다.", rf"$k={answer}$이다."),
                    ("구한 값을 대입해 세 값이 일치하는지 검산한다.", rf"좌극한, 우극한, 함수값이 모두 ${answer}$이다."),
                ],
                alternatives=["조각함수의 두 직선이 경계점에서 만나는 y좌표를 각각 계산할 수 있다."],
                answer_check=lambda boundary=point, low=left, high=right: _continuity_value(boundary, low, high),
            )
        )
    radical_rows = [(1, 8), (4, 12), (-5, 30), (7, 29), (10, 39)]
    for index, (point, constant) in enumerate(radical_rows, 6):
        root = math.isqrt(point + constant)
        answer = _radical_limit(point, constant)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"극한 $\lim_{{x\to {point}}}\dfrac{{\sqrt{{x+{constant}}}-{root}}}{{x-({point})}}$의 값을 유리화하여 구하시오.",
                answer=str(answer),
                tags=["#유리화", "#유리화를이용한극한", "#극한값계산"],
                steps=[
                    ("직접 대입해 0/0 꼴임을 확인한다.", "분자와 분모가 모두 0이므로 식을 변형해야 한다."),
                    ("분자와 분모에 켤레식을 곱한다.", rf"$\sqrt{{x+{constant}}}+{root}$을 이용한다."),
                    ("분자의 제곱의 차를 계산한다.", rf"분자는 $x+{constant}-{root**2}=x-({point})$가 된다."),
                    ("공통인수를 약분한다.", rf"식은 $\dfrac1{{\sqrt{{x+{constant}}}+{root}}}$로 정리된다."),
                    ("극한점을 대입한다.", rf"따라서 극한값은 $\dfrac1{{2\cdot {root}}}={answer}$이다."),
                ],
                alternatives=["제곱근 함수의 미분계수 공식을 적용해 결과를 검산할 수 있다."],
                answer_check=lambda boundary=point, offset=constant: _radical_limit(boundary, offset),
            )
        )
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 부호가 변하는 속도와 평행이동한 무리함수다. 작동 원리는 절댓값 적분과 그래프 교점 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    velocity_rows = [(2, 2, 6), (3, 1, 5), (4, 3, 7), (5, 2, 8), (6, 4, 10)]
    for index, (scale, turning_time, end_time) in enumerate(velocity_rows, 1):
        answer = _travel_distance(scale, turning_time, end_time)
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"수직선 위 점 P의 속도가 $v(t)={scale}(t-{turning_time})$이다. $0\le t\le {end_time}$에서 움직인 총거리를 구하시오.",
                answer=str(answer),
                tags=["#속도", "#속도와가속도", "#속도와거리", "#위치함수"],
                steps=[
                    ("속도가 0이 되는 방향 전환 시각을 찾는다.", rf"$v(t)=0$에서 $t={turning_time}$이다."),
                    ("전환점 전후의 속도 부호를 확인한다.", rf"$t<{turning_time}$에서는 음수, 이후에는 양수이다."),
                    ("총거리를 속도의 절댓값 적분으로 나타낸다.", rf"$\int_0^{{{end_time}}}|{scale}(t-{turning_time})|dt$이다."),
                    ("전환점을 기준으로 적분 구간을 나눈다.", rf"$-\int_0^{{{turning_time}}}v(t)dt+\int_{{{turning_time}}}^{{{end_time}}}v(t)dt$이다."),
                    ("두 구간의 거리를 계산한다.", "속도-시간 그래프에서 두 삼각형의 넓이와 같다."),
                    ("두 거리를 더한다.", rf"따라서 총거리는 ${answer}$이다."),
                ],
                alternatives=[
                    "속도-시간 그래프와 t축 사이 두 삼각형의 넓이를 직접 더할 수 있다.",
                    "위치함수의 전환점 전후 변위를 각각 절댓값으로 바꾸어 합할 수 있다.",
                ],
                answer_check=lambda m=scale, r=turning_time, end=end_time: _travel_distance(m, r, end),
            )
        )
    radical_rows = [(1, 2, 5), (-3, 1, 4), (4, -2, 2), (-1, 3, 8), (2, -1, 5)]
    for index, (shift_x, shift_y, height) in enumerate(radical_rows, 6):
        answer = _shifted_radical_intersection(shift_x, shift_y, height)
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"무리함수 $y=\sqrt{{x-({shift_x})}}+({shift_y})$와 직선 $y={height}$가 만나는 점의 x좌표를 구하시오.",
                answer=str(answer),
                tags=["#무리식", "#무리식의계산", "#무리함수의그래프", "#무리함수의평행이동"],
                steps=[
                    ("두 그래프의 y값을 같게 둔다.", rf"$\sqrt{{x-({shift_x})}}+({shift_y})={height}$이다."),
                    ("제곱근 항만 남긴다.", rf"$\sqrt{{x-({shift_x})}}={height - shift_y}$이다."),
                    ("우변이 0 이상인지 확인한다.", rf"${height - shift_y}\ge0$이므로 제곱할 수 있다."),
                    ("양변을 제곱한다.", rf"$x-({shift_x})=({height - shift_y})^2$이다."),
                    ("x를 구한다.", rf"$x={answer}$이다."),
                    ("원래 식에 대입해 무연근이 아님을 확인한다.", rf"교점의 x좌표는 ${answer}$이다."),
                ],
                alternatives=[
                    "기본 그래프 y=√x의 시작점을 평행이동한 뒤 수평선과의 거리를 이용할 수 있다.",
                    "구한 x를 원래 무리식에 대입해 y좌표가 주어진 높이와 같은지 검산할 수 있다.",
                ],
                answer_check=lambda h=shift_x, k=shift_y, c=height: _shifted_radical_intersection(h, k, c),
            )
        )
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v27 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v27 전체 카탈로그다. 작동 원리는 독립 정답 검산 후 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog = build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v27 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(
        catalog,
        expected_count=50,
        batch_id=BATCH_ID,
        model_name=MODEL_NAME,
        codebase_base=CODEBASE_BASE,
        seed_base=SEED_BASE,
    )


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v27 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(
        db_path,
        quests=validated_quests(),
        batch_id=BATCH_ID,
        validate_only=validate_only,
    )


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v27 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
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
