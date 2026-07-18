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

BATCH_ID = "marketplace-original-v20"
MODEL_NAME = "aiflow-direct-authoring-v20"
CODEBASE_BASE = 20_260_981_000
SEED_BASE = 202_607_560_000


def _checked_problem(
    tier: int,
    index: int,
    *,
    answer_check: Callable[[], Any],
    **kwargs: Any,
) -> dict[str, Any]:
    """필요 변수는 문제 명세와 독립 정답 계산 함수다. 작동 원리는 공통 생산 검증기가 실행할 검산 함수를 문제에 부착한다."""
    spec = _problem(tier, index, **kwargs)
    spec["answer_check"] = answer_check
    return spec


def _polynomial_sum_linear(left: tuple[int, int, int], right: tuple[int, int, int]) -> int:
    """필요 변수는 두 이차다항식의 내림차순 계수다. 작동 원리는 같은 차수 계수를 배열별로 더해 일차항 계수를 반환한다."""
    summed = [first + second for first, second in zip(left, right)]
    return summed[1]


def _matrix_sum_component(left: tuple[tuple[int, int], tuple[int, int]], right: tuple[tuple[int, int], tuple[int, int]]) -> int:
    """필요 변수는 두 2행 2열 행렬이다. 작동 원리는 대응 성분을 모두 더한 뒤 1행 2열 성분을 읽는다."""
    result = tuple(
        tuple(left[row][column] + right[row][column] for column in range(2))
        for row in range(2)
    )
    return result[0][1]


def _root_sum_plus_product(root_left: int, root_right: int) -> int:
    """필요 변수는 이차방정식의 두 근이다. 작동 원리는 근의 합과 곱을 서로 독립 계산한 뒤 더한다."""
    return (root_left + root_right) + root_left * root_right


def _subsets_containing_element(elements: tuple[int, ...], required: int) -> int:
    """필요 변수는 유한집합과 반드시 포함할 원소다. 작동 원리는 나머지 원소의 포함 여부를 비트로 순회해 부분집합 수를 센다."""
    if required not in elements:
        raise ValueError("필수 원소가 원래 집합에 없습니다.")
    optional_count = len(elements) - 1
    return sum(1 for _mask in range(1 << optional_count))


def _common_log_sum(left: int, right: int) -> int:
    """필요 변수는 두 양의 정수 진수다. 작동 원리는 진수 곱을 10으로 반복 나눠 정확한 상용로그 정수를 구한다."""
    value = left * right
    exponent = 0
    while value > 1 and value % 10 == 0:
        value //= 10
        exponent += 1
    if value != 1:
        raise ValueError("진수의 곱이 10의 정수 거듭제곱이 아닙니다.")
    return exponent


def _external_point_sum(
    point_a: tuple[int, int],
    point_b: tuple[int, int],
    left_ratio: int,
    right_ratio: int,
) -> int:
    """필요 변수는 두 점과 외분비 AP:PB다. 작동 원리는 외분점 공식을 유리수로 계산해 두 좌표의 합을 반환한다."""
    denominator = left_ratio - right_ratio
    if denominator == 0:
        raise ValueError("외분비의 두 수가 같습니다.")
    x = Fraction(left_ratio * point_b[0] - right_ratio * point_a[0], denominator)
    y = Fraction(left_ratio * point_b[1] - right_ratio * point_a[1], denominator)
    value = x + y
    if value.denominator != 1:
        raise ValueError("외분점 좌표합이 정수가 아닙니다.")
    return value.numerator


def _inverse_entry_sum(matrix: tuple[tuple[int, int], tuple[int, int]]) -> Fraction:
    """필요 변수는 역행렬이 존재하는 2행 2열 행렬이다. 작동 원리는 행렬식과 수반행렬로 네 성분의 합을 정확히 계산한다."""
    a, b = matrix[0]
    c, d = matrix[1]
    determinant = a * d - b * c
    if determinant == 0:
        raise ValueError("역행렬이 존재하지 않습니다.")
    return Fraction(a + d - b - c, determinant)


def _integer_solution_sum(left_root: int, right_root: int) -> int:
    """필요 변수는 위로 열린 이차식의 두 근이다. 작동 원리는 닫힌 근 구간의 모든 정수를 순회해 합한다."""
    lower, upper = sorted((left_root, right_root))
    return sum(integer for integer in range(lower, upper + 1) if (integer - lower) * (integer - upper) <= 0)


def _differentiable_parameter_sum(point: int, left_constant: int, right_constant: int) -> int:
    """필요 변수는 조각함수 경계점과 양쪽 상수다. 작동 원리는 연속·미분계수 일치 연립조건으로 두 계수를 구한다."""
    difference = right_constant - left_constant
    coefficient_b = Fraction(difference, point**2)
    coefficient_a = 2 * coefficient_b * point
    value = coefficient_a + coefficient_b
    if value.denominator != 1:
        raise ValueError("조각함수 계수합이 정수가 아닙니다.")
    return value.numerator


def _rational_sum(value: int, shift: int) -> Fraction:
    """필요 변수는 유리식에 대입할 값과 대칭 분모 이동량이다. 작동 원리는 두 분수를 정확히 더하고 정의 여부를 확인한다."""
    if value in {shift, -shift}:
        raise ValueError("유리식이 정의되지 않는 값입니다.")
    return Fraction(1, value - shift) + Fraction(1, value + shift)


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 다항식과 두 행렬의 성분이다. 작동 원리는 새 태그의 난이도 1 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    polynomial_rows = [
        ((2, 3, -1), (5, -4, 6)),
        ((-3, 7, 2), (4, 5, -8)),
        ((6, -2, 9), (-1, -3, 4)),
        ((-5, 8, -6), (2, -1, 7)),
        ((3, -9, 5), (7, 4, -2)),
    ]
    for index, (left, right) in enumerate(polynomial_rows, 1):
        answer = left[1] + right[1]
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"두 다항식 $P(x)=({left[0]})x^2+({left[1]})x+({left[2]})$, $Q(x)=({right[0]})x^2+({right[1]})x+({right[2]})$에 대하여 $P(x)+Q(x)$의 $x$의 계수를 구하시오.",
                answer=str(answer),
                tags=["#다항식의덧셈"],
                steps=[
                    ("두 다항식에서 일차항만 대응시킨다.", rf"일차항은 $({left[1]})x$와 $({right[1]})x$이다."),
                    ("두 일차항의 계수를 더한다.", rf"따라서 $x$의 계수는 ${left[1]}+({right[1]})={answer}$이다."),
                ],
                answer_check=lambda first=left, second=right: _polynomial_sum_linear(first, second),
            )
        )
    matrix_rows = [
        (((1, 2), (3, 4)), ((5, -1), (0, 2))),
        (((-2, 6), (1, 5)), ((3, 4), (-7, 2))),
        (((4, -3), (8, 1)), ((-5, 7), (2, -6))),
        (((0, 9), (-4, 3)), ((6, -2), (5, 1))),
        (((7, 5), (2, -8)), ((-3, -6), (4, 9))),
    ]
    for index, (left, right) in enumerate(matrix_rows, 6):
        answer = left[0][1] + right[0][1]
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"행렬 $A=\begin{{pmatrix}}{left[0][0]}&{left[0][1]}\\{left[1][0]}&{left[1][1]}\end{{pmatrix}}$, $B=\begin{{pmatrix}}{right[0][0]}&{right[0][1]}\\{right[1][0]}&{right[1][1]}\end{{pmatrix}}$일 때, $A+B$의 1행 2열 성분을 구하시오.",
                answer=str(answer),
                tags=["#성분"],
                steps=[
                    ("행렬의 합은 같은 위치의 성분끼리 더함을 이용한다.", rf"1행 2열 성분은 ${left[0][1]}+({right[0][1]})$이다."),
                    ("두 대응 성분을 더한다.", rf"따라서 구하는 성분은 ${answer}$이다."),
                ],
                answer_check=lambda first=left, second=right: _matrix_sum_component(first, second),
            )
        )
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 이차방정식의 두 근과 유한집합 원소다. 작동 원리는 새 태그의 난이도 2 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    root_rows = [(-2, 5), (3, 8), (-6, -1), (4, 9), (-5, 7)]
    for index, (root_left, root_right) in enumerate(root_rows, 1):
        root_sum = root_left + root_right
        root_product = root_left * root_right
        answer = _root_sum_plus_product(root_left, root_right)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"이차방정식 $x^2-({root_sum})x+({root_product})=0$의 두 근을 $\alpha,\beta$라 할 때, $\alpha+\beta+\alpha\beta$를 구하시오.",
                answer=str(answer),
                tags=["#두근의합", "#두근의곱"],
                steps=[
                    ("근과 계수의 관계로 두 근의 합을 구한다.", rf"$\alpha+\beta={root_sum}$이다."),
                    ("근과 계수의 관계로 두 근의 곱을 구한다.", rf"$\alpha\beta={root_product}$이다."),
                    ("두 결과를 더해 식의 값을 계산한다.", rf"따라서 $\alpha+\beta+\alpha\beta={root_sum}+({root_product})={answer}$이다."),
                ],
                answer_check=lambda left=root_left, right=root_right: _root_sum_plus_product(left, right),
            )
        )
    subset_rows = [
        ((1, 3, 5, 7), 3),
        ((2, 4, 6, 8, 10), 6),
        ((-3, -1, 1, 3, 5, 7), 1),
        ((4, 8, 12, 16, 20, 24, 28), 16),
        ((1, 2, 4, 8, 16, 32, 64, 128), 8),
    ]
    for index, (elements, required) in enumerate(subset_rows, 6):
        answer = 2 ** (len(elements) - 1)
        element_text = ",".join(str(value) for value in elements)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"집합 $A=\{{{element_text}\}}$의 부분집합 중 원소 ${required}$을 반드시 포함하는 부분집합의 개수를 구하시오.",
                answer=str(answer),
                tags=["#부분집합", "#원소나열법"],
                steps=[
                    ("반드시 포함할 원소를 먼저 고정한다.", rf"원소 ${required}$은 모든 대상 부분집합에 포함한다."),
                    ("나머지 원소는 각각 포함하거나 포함하지 않을 수 있다.", rf"나머지 ${len(elements) - 1}$개 원소마다 2가지 선택이 있다."),
                    ("독립인 선택의 수를 곱한다.", rf"따라서 부분집합의 개수는 $2^{{{len(elements) - 1}}}={answer}$개이다."),
                ],
                answer_check=lambda values=elements, item=required: _subsets_containing_element(values, item),
            )
        )
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 상용로그의 두 진수와 외분할 두 점·비율이다. 작동 원리는 새 태그의 난이도 3 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    logarithm_rows = [(2, 50), (4, 250), (5, 2000), (8, 12500), (20, 50000)]
    for index, (left, right) in enumerate(logarithm_rows, 1):
        answer = _common_log_sum(left, right)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"상용로그 $\log {left}+\log {right}$의 값을 구하시오.",
                answer=str(answer),
                tags=["#상용로그", "#로그", "#밑의변환"],
                steps=[
                    ("상용로그의 밑이 10임을 확인한다.", r"밑을 쓰지 않은 로그는 밑이 10인 상용로그이다."),
                    ("로그 덧셈을 진수 곱의 로그로 바꾼다.", rf"$\log {left}+\log {right}=\log({left}\cdot {right})$이다."),
                    ("진수의 곱을 10의 거듭제곱으로 나타낸다.", rf"${left}\cdot {right}=10^{answer}$이다."),
                    ("로그의 정의로 지수를 읽는다.", rf"따라서 상용로그의 값은 ${answer}$이다."),
                ],
                alternatives=["두 진수를 각각 2와 5의 거듭제곱으로 분해해 상용로그 성질로 항을 소거할 수 있다."],
                answer_check=lambda first=left, second=right: _common_log_sum(first, second),
            )
        )
    external_rows = [
        ((0, 0), (3, 6), 2, 1),
        ((1, 2), (4, 6), 2, 1),
        ((-3, 5), (2, -1), 2, 1),
        ((1, 1), (5, 3), 3, 1),
        ((2, -1), (-1, 4), 3, 2),
    ]
    for index, (point_a, point_b, left_ratio, right_ratio) in enumerate(external_rows, 6):
        denominator = left_ratio - right_ratio
        point_x = (left_ratio * point_b[0] - right_ratio * point_a[0]) // denominator
        point_y = (left_ratio * point_b[1] - right_ratio * point_a[1]) // denominator
        answer = _external_point_sum(point_a, point_b, left_ratio, right_ratio)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"두 점 $A({point_a[0]},{point_a[1]})$, $B({point_b[0]},{point_b[1]})$를 잇는 직선을 $AP:PB={left_ratio}:{right_ratio}$로 외분하는 점을 $P(p,q)$라 할 때, $p+q$를 구하시오.",
                answer=str(answer),
                tags=["#외분점", "#좌표평면", "#내분점공식"],
                steps=[
                    ("외분점의 x좌표 공식을 적용한다.", rf"$p=\dfrac{{{left_ratio}({point_b[0]})-{right_ratio}({point_a[0]})}}{{{denominator}}}={point_x}$이다."),
                    ("외분점의 y좌표 공식을 적용한다.", rf"$q=\dfrac{{{left_ratio}({point_b[1]})-{right_ratio}({point_a[1]})}}{{{denominator}}}={point_y}$이다."),
                    ("구한 점이 선분 바깥의 같은 직선 위에 있음을 확인한다.", rf"점 $P({point_x},{point_y})$는 A와 B를 지나는 직선 위의 외분점이다."),
                    ("외분점의 두 좌표를 더한다.", rf"따라서 $p+q={point_x}+({point_y})={answer}$이다."),
                ],
                alternatives=["두 좌표를 각각 수직선의 외분 문제로 보고 방향이 있는 거리 비를 적용할 수 있다."],
                answer_check=lambda a=point_a, b=point_b, m=left_ratio, n=right_ratio: _external_point_sum(a, b, m, n),
            )
        )
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 역행렬의 네 성분과 이차부등식의 두 경계다. 작동 원리는 새 태그의 난이도 4 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    inverse_rows = [
        ((2, 1), (1, 2)),
        ((3, 1), (1, 2)),
        ((4, 1), (2, 3)),
        ((5, 2), (1, 3)),
        ((2, -1), (1, 4)),
    ]
    for index, matrix in enumerate(inverse_rows, 1):
        determinant = matrix[0][0] * matrix[1][1] - matrix[0][1] * matrix[1][0]
        answer_fraction = _inverse_entry_sum(matrix)
        answer = str(answer_fraction)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"행렬 $A=\begin{{pmatrix}}{matrix[0][0]}&{matrix[0][1]}\\{matrix[1][0]}&{matrix[1][1]}\end{{pmatrix}}$의 역행렬의 네 성분의 합을 구하시오.",
                answer=answer,
                tags=["#역행렬", "#역행렬구하기", "#역행렬의정의", "#성분"],
                steps=[
                    ("2행 2열 행렬의 행렬식을 계산한다.", rf"$\det A={matrix[0][0]}({matrix[1][1]})-({matrix[0][1]})({matrix[1][0]})={determinant}$이다."),
                    ("행렬식이 0이 아니므로 역행렬이 존재함을 확인한다.", rf"${determinant}\ne0$이므로 $A^{{-1}}$가 존재한다."),
                    ("역행렬 공식으로 네 성분을 나타낸다.", rf"$A^{{-1}}=\dfrac1{{{determinant}}}\begin{{pmatrix}}{matrix[1][1]}&{-matrix[0][1]}\\{-matrix[1][0]}&{matrix[0][0]}\end{{pmatrix}}$이다."),
                    ("수반행렬의 네 성분을 먼저 더한다.", rf"분자의 합은 ${matrix[1][1]}+({-matrix[0][1]})+({-matrix[1][0]})+({matrix[0][0]})$이다."),
                    ("행렬식으로 나누어 최종 합을 구한다.", rf"따라서 네 성분의 합은 ${answer}$이다."),
                ],
                alternatives=["$AA^{-1}=I$가 되도록 역행렬의 네 미지수를 연립방정식으로 구한 뒤 합할 수 있다."],
                answer_check=lambda value=matrix: _inverse_entry_sum(value),
            )
        )
    inequality_rows = [(-3, 4), (2, 7), (-5, 1), (-2, 6), (3, 9)]
    for index, (left_root, right_root) in enumerate(inequality_rows, 6):
        lower, upper = sorted((left_root, right_root))
        answer = _integer_solution_sum(lower, upper)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"이차부등식 $(x-({left_root}))(x-({right_root}))\le0$을 만족하는 모든 정수 $x$의 합을 구하시오.",
                answer=str(answer),
                tags=["#이차부등식", "#이차부등식의풀이", "#이차부등식의해", "#이차함수와이차부등식"],
                steps=[
                    ("두 일차인수가 0이 되는 경계값을 찾는다.", rf"경계값은 $x={lower},{upper}$이다."),
                    ("최고차항 계수가 양수인 이차식의 부호를 판정한다.", "두 근 사이에서는 이차식의 값이 0 이하이다."),
                    ("부등식의 실수 해 구간을 나타낸다.", rf"해는 ${lower}\le x\le {upper}$이다."),
                    ("닫힌 구간에 포함되는 모든 정수를 확인한다.", rf"정수 해는 ${lower}$부터 ${upper}$까지 연속한다."),
                    ("등차수열의 합으로 정수 해를 모두 더한다.", rf"따라서 모든 정수 해의 합은 ${answer}$이다."),
                ],
                alternatives=["이차함수 그래프가 x축 아래에 놓이는 구간을 그려 정수 격자점을 합할 수 있다."],
                answer_check=lambda left=lower, right=upper: _integer_solution_sum(left, right),
            )
        )
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 조각함수 경계 조건과 두 유리식 분모다. 작동 원리는 새 태그의 난이도 5 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    differentiable_rows = [(1, 2, 5), (2, -1, 7), (-1, 4, -2), (3, 1, 10), (-2, 5, 1)]
    for index, (point, left_constant, right_constant) in enumerate(differentiable_rows, 1):
        difference = right_constant - left_constant
        coefficient_b = difference // (point**2)
        coefficient_a = 2 * coefficient_b * point
        answer = coefficient_a + coefficient_b
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"함수 $f(x)=\begin{{cases}}ax+({left_constant})&(x<{point})\\bx^2+({right_constant})&(x\ge {point})\end{{cases}}$가 $x={point}$에서 미분가능할 때, $a+b$를 구하시오.",
                answer=str(answer),
                tags=["#미분가능", "#연속의정의", "#연속함수의성질", "#좌극한", "#우극한"],
                steps=[
                    ("미분가능하면 먼저 연속이어야 함을 이용한다.", rf"좌극한과 우극한이 같으므로 $({point})a+({left_constant})=({point**2})b+({right_constant})$이다."),
                    ("경계점 왼쪽 식의 미분계수를 구한다.", r"왼쪽 미분계수는 $a$이다."),
                    ("경계점 오른쪽 식의 미분계수를 구한다.", rf"오른쪽 미분계수는 $2b({point})$이다."),
                    ("두 미분계수가 같다는 조건을 세운다.", rf"$a={2 * point}b$이다."),
                    ("연속 조건과 미분 조건을 함께 풀어 두 계수를 구한다.", rf"두 식을 풀면 $a={coefficient_a}$, $b={coefficient_b}$이다."),
                    ("두 계수를 더해 요구한 값을 계산한다.", rf"따라서 $a+b={coefficient_a}+({coefficient_b})={answer}$이다."),
                ],
                alternatives=[
                    "차분몫의 좌극한과 우극한을 직접 계산해 함수값 조건과 함께 연립할 수 있다.",
                    "그래프의 접점에서 두 조각의 높이와 접선 기울기가 동시에 같아야 한다고 해석할 수 있다.",
                ],
                answer_check=lambda t=point, p=left_constant, q=right_constant: _differentiable_parameter_sum(t, p, q),
            )
        )
    rational_rows = [(3, 1), (5, 3), (4, 2), (7, 5), (6, 2)]
    for index, (value, shift) in enumerate(rational_rows, 6):
        answer_fraction = _rational_sum(value, shift)
        answer = str(answer_fraction)
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"유리식 $E(x)=\dfrac1{{x-({shift})}}+\dfrac1{{x+({shift})}}$에 대하여 $E({value})$의 값을 구하시오.",
                answer=answer,
                tags=["#유리식", "#유리식의계산", "#약분", "#통분", "#유리식과유리함수"],
                steps=[
                    ("두 분모가 0이 되지 않는 정의 조건을 확인한다.", rf"$x\ne {shift},-{shift}$이고 ${value}$는 두 값을 모두 피한다."),
                    ("두 유리식의 공통분모를 만든다.", rf"공통분모는 $(x-{shift})(x+{shift})=x^2-{shift**2}$이다."),
                    ("두 분자를 공통분모 위에서 더한다.", r"분자는 $(x+s)+(x-s)=2x$로 정리된다."),
                    ("유리식을 약분 가능한 형태로 정리한다.", rf"$E(x)=\dfrac{{2x}}{{x^2-{shift**2}}}$이다."),
                    ("주어진 x값을 정리된 식에 대입한다.", rf"$E({value})=\dfrac{{{2 * value}}}{{{value**2}-{shift**2}}}$이다."),
                    ("분자와 분모의 공약수를 약분해 결과를 구한다.", rf"따라서 $E({value})={answer}$이다."),
                ],
                alternatives=[
                    "처음 식에 x값을 먼저 대입한 뒤 두 수치 분수를 통분할 수 있다.",
                    "두 분모가 켤레형이라는 점을 이용해 합의 분자와 분모를 한 번에 계산할 수 있다.",
                ],
                answer_check=lambda x=value, s=shift: _rational_sum(x, s),
            )
        )
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v20 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v20 전체 카탈로그다. 작동 원리는 모든 정답 검산 함수를 실행한 뒤 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog = build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v20 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(catalog, expected_count=50, batch_id=BATCH_ID, model_name=MODEL_NAME, codebase_base=CODEBASE_BASE, seed_base=SEED_BASE)


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v20 전체 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(db_path, quests=validated_quests(), batch_id=BATCH_ID, validate_only=validate_only)


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v20 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
