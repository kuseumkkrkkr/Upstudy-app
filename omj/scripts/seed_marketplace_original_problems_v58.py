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

BATCH_ID = "marketplace-original-v58"
MODEL_NAME = "aiflow-direct-authoring-v58"
CODEBASE_BASE = 20_261_019_000
SEED_BASE = 202_607_598_000


def _checked_problem(tier: int, index: int, *, answer_check: Callable[[], Any], **kwargs: Any) -> dict[str, Any]:
    """필요 변수는 문제 명세와 독립 계산 함수다. 작동 원리는 저장 답과 별도 계산 결과를 비교하도록 검산 함수를 부착한다."""
    spec = _problem(tier, index, **kwargs)
    spec["answer_check"] = answer_check
    return spec


def _matrix_linear_diagonal_sum(first: tuple[int, int, int, int], second: tuple[int, int, int, int], first_scale: int, second_scale: int) -> int:
    """필요 변수는 두 2×2 행렬과 선형결합 계수다. 작동 원리는 각 행렬의 대각합에 계수를 곱해 더한다."""
    return first_scale * (first[0] + first[3]) + second_scale * (second[0] + second[3])


def _separated_repeated_letters(first_count: int, second_count: int) -> int:
    """필요 변수는 A와 B의 중복 개수다. 작동 원리는 C 두 개의 전체 중복순열에서 두 C를 한 덩어리로 센 경우를 뺀다."""
    if first_count < 1 or second_count < 1:
        raise ValueError("A와 B가 각각 한 개 이상 필요합니다.")
    total = math.factorial(first_count + second_count + 2) // (
        math.factorial(first_count) * math.factorial(second_count) * 2
    )
    adjacent = math.factorial(first_count + second_count + 1) // (
        math.factorial(first_count) * math.factorial(second_count)
    )
    return total - adjacent


def _line_intercept_sum(first: tuple[int, int], second: tuple[int, int]) -> Fraction:
    """필요 변수는 서로 다른 두 점이다. 작동 원리는 매개직선에서 y=0과 x=0을 각각 대입해 두 절편을 더한다."""
    dx = second[0] - first[0]
    dy = second[1] - first[1]
    if dx == 0 or dy == 0:
        raise ValueError("수직선이나 수평선이 아닌 두 점이 필요합니다.")
    x_intercept = Fraction(first[0] * dy - first[1] * dx, dy)
    y_intercept = Fraction(first[1] * dx - first[0] * dy, dx)
    return x_intercept + y_intercept


def _circle_tangent_center_intercept_sum(center: tuple[int, int], offset: tuple[int, int]) -> Fraction:
    """필요 변수는 원의 중심과 접점의 중심 기준 좌표다. 작동 원리는 반지름과 접선의 수직 조건으로 y절편을 구해 중심 좌표와 합한다."""
    horizontal, vertical = offset
    if vertical == 0:
        raise ValueError("유한한 y절편을 갖도록 접점의 세로 편차가 0이 아니어야 합니다.")
    radius_squared = horizontal**2 + vertical**2
    y_intercept = center[1] + Fraction(radius_squared + horizontal * center[0], vertical)
    return center[0] + center[1] + y_intercept


def _alternating_arithmetic_target(first: int, pair_count: int, common_difference: int) -> int:
    """필요 변수는 첫째항·항 쌍의 수·공차다. 작동 원리는 짝수 번째 합과 홀수 번째 합의 차로 공차를 복원해 다음 홀수 번째 항을 계산한다."""
    gap = pair_count * common_difference
    recovered_difference = gap // pair_count
    return first + 2 * pair_count * recovered_difference


def _exponential_quadratic_solution_sum(base: int, first_power: int, second_power: int) -> int:
    """필요 변수는 지수함수 밑과 치환식의 두 양의 근 지수다. 작동 원리는 t=b^x로 치환해 두 실근을 복원하고 더한다."""
    if base <= 1 or first_power == second_power:
        raise ValueError("1보다 큰 밑과 서로 다른 두 지수가 필요합니다.")
    roots = (base**first_power, base**second_power)
    recovered = [round(math.log(root, base)) for root in roots]
    if any(base**value != root for value, root in zip(recovered, roots)):
        raise ValueError("지수근 복원에 실패했습니다.")
    return sum(recovered)


def _weighted_polynomial_coefficient_sum(linear: int, constant: int, degree: int) -> int:
    """필요 변수는 일차식 계수와 거듭제곱 차수다. 작동 원리는 전개 계수의 가중합을 다항식값과 도함수값의 합으로 계산한다."""
    value_at_one = (linear + constant) ** degree
    derivative_at_one = degree * linear * (linear + constant) ** (degree - 1)
    return value_at_one + derivative_at_one


def _urn_at_least_one_first_probability(first_count: int, second_count: int) -> Fraction:
    """필요 변수는 두 색 공의 개수다. 작동 원리는 적어도 첫째 색 하나가 나온 조건에서 둘 다 첫째 색인 조합 수의 비를 구한다."""
    if first_count < 2 or second_count < 1:
        raise ValueError("첫째 색 공 두 개와 둘째 색 공 한 개 이상이 필요합니다.")
    favorable = math.comb(first_count, 2)
    condition = math.comb(first_count + second_count, 2) - math.comb(second_count, 2)
    return Fraction(favorable, condition)


def _parabola_fixed_point_distance_stat(height: int) -> Fraction:
    """필요 변수는 고정점의 y좌표다. 작동 원리는 u=t² 치환으로 거리 제곱의 최솟값과 최소점을 만드는 두 매개변수 제곱합을 구한다."""
    if height < 1:
        raise ValueError("서로 다른 두 최소점이 생기도록 높이는 1 이상이어야 합니다.")
    minimizing_square = Fraction(2 * height - 1, 2)
    minimum_distance_squared = Fraction(4 * height - 1, 4)
    parameter_square_sum = 2 * minimizing_square
    return minimum_distance_squared + parameter_square_sum


def _absolute_quadratic_integral(inner_root: int, boundary: int) -> Fraction:
    """필요 변수는 이차식의 양의 근과 대칭 적분 경계다. 작동 원리는 부호가 바뀌는 근에서 구간을 나눠 절댓값 정적분을 계산한다."""
    if inner_root <= 0 or boundary <= inner_root:
        raise ValueError("0보다 큰 내부 근과 그보다 큰 적분 경계가 필요합니다.")
    positive_half = Fraction(2 * inner_root**3, 3)
    outer_half = Fraction(boundary**3 - inner_root**3, 3) - inner_root**2 * (boundary - inner_root)
    return 2 * (positive_half + outer_half)


def _matrix_text(values: tuple[int, int, int, int]) -> str:
    """필요 변수는 네 행렬 성분이다. 작동 원리는 문제 본문용 2×2 LaTeX 행렬 문자열로 변환한다."""
    return rf"\begin{{pmatrix}}{values[0]}&{values[1]}\\{values[2]}&{values[3]}\end{{pmatrix}}"


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 행렬 선형결합과 중복 문자 배열이다. 작동 원리는 대각성분 합과 비인접 중복순열 문제를 각 5개 만든다."""
    specs: list[dict[str, Any]] = []
    matrix_rows = [
        ((1, 2, -1, 3), (2, 0, 4, -2), 2, -1),
        ((-2, 1, 3, 4), (5, -1, 2, 1), -1, 3),
        ((3, 0, 2, -1), (-1, 4, 0, 6), 4, 2),
        ((5, -2, 1, 2), (3, 1, -4, -3), 3, -2),
        ((0, 3, 2, 7), (4, -2, 5, 1), -2, 5),
    ]
    for index, row in enumerate(matrix_rows, 1):
        first, second, first_scale, second_scale = row
        answer = _matrix_linear_diagonal_sum(*row)
        specs.append(_checked_problem(
            1, index,
            title=rf"두 행렬 $A={_matrix_text(first)}$, $B={_matrix_text(second)}$에 대하여 행렬 $({first_scale})A+({second_scale})B$의 두 대각성분의 합을 구하시오.",
            answer=str(answer), tags=["#행렬의정의", "#행렬의덧셈", "#행렬의뺄셈", "#스칼라곱", "#성분"],
            steps=[
                ("행렬 A와 B의 두 대각성분을 확인하고 각각 지정된 스칼라를 곱한다.", "대각성분만 결과에 영향을 준다."),
                ("같은 위치끼리 더한 뒤 결과 행렬의 두 대각성분을 합한다.", rf"따라서 합은 ${answer}$이다."),
            ], answer_check=lambda values=row: _matrix_linear_diagonal_sum(*values),
        ))
    repeated_rows = [(2, 2), (3, 2), (2, 3), (4, 2), (3, 3)]
    for index, row in enumerate(repeated_rows, 6):
        first_count, second_count = row
        answer = _separated_repeated_letters(*row)
        specs.append(_checked_problem(
            1, index,
            title=rf"문자 A가 {first_count}개, B가 {second_count}개, C가 2개 있다. 이 문자를 모두 일렬로 놓을 때 두 C가 서로 이웃하지 않는 배열의 수를 구하시오.",
            answer=str(answer), tags=["#중복순열", "#순열", "#경우의수", "#여집합", "#팩토리얼"],
            steps=[
                ("같은 문자를 구별하지 않는 전체 배열 수를 중복순열로 계산한다.", "전체 팩토리얼을 A·B·C의 중복 팩토리얼로 나눈다."),
                ("CC를 한 덩어리로 본 배열 수를 전체에서 뺀다.", rf"따라서 조건을 만족하는 배열은 ${answer}$개이다."),
            ], answer_check=lambda values=row: _separated_repeated_letters(*values),
        ))
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 점을 지나는 직선과 원의 접점이다. 작동 원리는 절편 합과 접선 y절편·중심 좌표 합 문제를 각 5개 만든다."""
    specs: list[dict[str, Any]] = []
    line_rows = [((1, 4), (5, -2)), ((-2, 3), (4, 7)), ((3, -1), (7, 5)), ((-4, -2), (2, 6)), ((2, 7), (8, 1))]
    for index, row in enumerate(line_rows, 1):
        first, second = row
        answer = _line_intercept_sum(*row)
        specs.append(_checked_problem(
            2, index,
            title=rf"두 점 $P{first}$, $Q{second}$를 지나는 직선의 x절편과 y절편의 합을 구하시오.",
            answer=str(answer), tags=["#두점을지나는직선", "#직선의방정식", "#기울기", "#절편", "#y절편"],
            steps=[
                ("두 점의 좌표 차로 직선의 기울기를 구한다.", "x좌표와 y좌표가 모두 서로 다름을 확인한다."),
                ("점기울기형으로 직선의 방정식을 세우고 y=0을 대입해 x절편을 구한다.", "두 점 중 하나를 기준점으로 사용한다."),
                ("같은 직선식에 x=0을 대입해 y절편을 구한 뒤 두 절편을 더한다.", rf"따라서 합은 ${answer}$이다."),
            ], answer_check=lambda values=row: _line_intercept_sum(*values),
        ))
    circle_rows = [((1, 2), (3, 4)), ((-2, 1), (4, 3)), ((3, -1), (-3, 4)), ((-1, -2), (5, 12)), ((2, 3), (-8, 6))]
    for index, row in enumerate(circle_rows, 6):
        center, offset = row
        point = (center[0] + offset[0], center[1] + offset[1])
        radius_squared = offset[0] ** 2 + offset[1] ** 2
        answer = _circle_tangent_center_intercept_sum(*row)
        specs.append(_checked_problem(
            2, index,
            title=rf"중심이 $C{center}$이고 반지름의 제곱이 {radius_squared}인 원 위의 점 $T{point}$에서 그은 접선의 y절편을 b라 하자. $b+x_C+y_C$의 값을 구하시오.",
            answer=str(answer), tags=["#중심", "#반지름", "#원의방정식", "#접선의방정식", "#y절편"],
            steps=[
                ("중심 C에서 접점 T로 향하는 반지름 벡터를 구한다.", "접선은 이 반지름에 수직이다."),
                ("반지름 벡터를 법선벡터로 하는 접선 방정식을 세우고 x=0을 대입한다.", "세로 편차가 0이 아니므로 y절편이 유일하다."),
                ("접선의 y절편 b에 중심의 두 좌표를 더한다.", rf"따라서 값은 ${answer}$이다."),
            ], answer_check=lambda values=row: _circle_tangent_center_intercept_sum(*values),
        ))
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 등차수열 교대합과 지수 이차방정식이다. 작동 원리는 공차 복원과 지수 치환 문제를 각 5개 만든다."""
    specs: list[dict[str, Any]] = []
    sequence_rows = [(3, 4, 2), (-2, 5, 3), (7, 6, -1), (1, 7, 4), (-5, 8, 2)]
    for index, row in enumerate(sequence_rows, 1):
        first, pair_count, common_difference = row
        gap = pair_count * common_difference
        answer = _alternating_arithmetic_target(*row)
        specs.append(_checked_problem(
            3, index,
            title=rf"첫째항이 {first}인 등차수열 ${{a_n}}$에서 $(a_2+a_4+\cdots+a_{{{2*pair_count}}})-(a_1+a_3+\cdots+a_{{{2*pair_count-1}}})={gap}$이다. $a_{{{2*pair_count+1}}}$을 구하시오.",
            answer=str(answer), tags=["#등차수열", "#등차수열의합", "#등차수열의일반항", "#공차", "#합의기호시그마"],
            steps=[
                ("각 짝수 번째 항에서 바로 앞 홀수 번째 항을 짝지어 뺀다.", "각 차는 등차수열의 공차와 같다."),
                ("같은 공차가 몇 번 더해졌는지 세어 공차를 구한다.", "항의 쌍은 주어진 개수만큼 있다."),
                ("등차수열의 일반항에 첫째항과 공차를 대입한다.", "목표 항은 첫째항에서 지정 횟수만큼 공차를 더한 값이다."),
                ("목표 항을 계산한다.", rf"따라서 $a_{{{2*pair_count+1}}}={answer}$이다."),
            ], alternatives=["짝수 번째 항의 합과 홀수 번째 항의 합을 등차수열 합 공식으로 각각 계산해 차이를 비교할 수 있다."],
            answer_check=lambda values=row: _alternating_arithmetic_target(*values),
        ))
    exponential_rows = [(2, 0, 3), (2, 1, 4), (3, 0, 2), (3, 2, 4), (5, 1, 3)]
    for index, row in enumerate(exponential_rows, 6):
        base, first_power, second_power = row
        coefficient = base**first_power + base**second_power
        constant = base ** (first_power + second_power)
        answer = _exponential_quadratic_solution_sum(*row)
        specs.append(_checked_problem(
            3, index,
            title=rf"방정식 ${base}^{{2x}}-({coefficient}){base}^x+({constant})=0$의 서로 다른 모든 실근의 합을 구하시오.",
            answer=str(answer), tags=["#지수방정식", "#지수법칙", "#지수함수의성질", "#이차방정식의풀이", "#지수"],
            steps=[
                (rf"${base}^x=t$로 놓아 t에 대한 이차방정식으로 바꾼다.", "지수함수 값이므로 t는 양수이다."),
                ("이차식을 인수분해해 서로 다른 두 양의 t값을 구한다.", "두 값의 합과 곱으로도 확인한다."),
                (rf"각 t값에 대해 ${base}^x=t$를 푼다.", "주어진 t값은 밑의 정수 거듭제곱이다."),
                ("얻은 두 실근을 더한다.", rf"따라서 실근의 합은 ${answer}$이다."),
            ], alternatives=["t에 대한 이차방정식의 근과 계수 관계로 두 t근을 먼저 확인할 수 있다."],
            answer_check=lambda values=row: _exponential_quadratic_solution_sum(*values),
        ))
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 다항식 전개 계수와 두 색 공이다. 작동 원리는 계수 가중합과 조건부 조합 확률 문제를 각 5개 만든다."""
    specs: list[dict[str, Any]] = []
    polynomial_rows = [(2, 1, 4), (1, 2, 5), (3, -1, 4), (2, -1, 6), (-1, 3, 5)]
    for index, row in enumerate(polynomial_rows, 1):
        linear, constant, degree = row
        answer = _weighted_polynomial_coefficient_sum(*row)
        specs.append(_checked_problem(
            4, index,
            title=rf"다항식 $({linear}x+({constant}))^{degree}=c_0+c_1x+\cdots+c_{{{degree}}}x^{degree}$에서 $\sum_{{k=0}}^{{{degree}}}(k+1)c_k$의 값을 구하시오.",
            answer=str(answer), tags=["#다항식", "#다항식의곱셈", "#도함수", "#거듭제곱의미분", "#합의기호시그마"],
            steps=[
                ("주어진 전개식을 P(x)라 두고 x=1을 대입한다.", "$P(1)$은 모든 계수의 합이다."),
                ("P(x)를 계수형으로 미분한 뒤 x=1을 대입한다.", "$P'(1)$은 각 계수에 차수를 곱한 합이다."),
                ("연쇄법칙으로 원래 식의 도함수를 계산한다.", "일차식의 계수도 곱한다."),
                ("구하려는 가중합이 $P'(1)+P(1)$임을 확인한다.", "k가 0인 항도 P(1)에 포함된다."),
                ("두 함수값을 더한다.", rf"따라서 가중합은 ${answer}$이다."),
            ], alternatives=["전개 계수를 직접 구하지 않고 함수값과 도함수값만 이용하면 계산량을 줄일 수 있다."],
            answer_check=lambda values=row: _weighted_polynomial_coefficient_sum(*values),
        ))
    urn_rows = [(3, 2), (4, 3), (5, 2), (5, 4), (6, 3)]
    for index, row in enumerate(urn_rows, 6):
        red, blue = row
        answer = _urn_at_least_one_first_probability(*row)
        specs.append(_checked_problem(
            4, index,
            title=rf"주머니에 빨간 공 {red}개와 파란 공 {blue}개가 있다. 동시에 공 2개를 꺼냈더니 적어도 하나가 빨간 공이었다. 꺼낸 두 공이 모두 빨간 공일 조건부확률을 구하시오.",
            answer=str(answer), tags=["#사건의합", "#사건의곱", "#조합", "#경우의수", "#여집합"],
            steps=[
                ("공 두 개를 순서 없이 고르는 전체 조합 수를 구한다.", "동시에 꺼내므로 순서를 구별하지 않는다."),
                ("둘 다 파란 공인 경우를 빼 적어도 하나가 빨간 조건 사건의 크기를 구한다.", "여사건을 사용한다."),
                ("두 공이 모두 빨간 경우의 조합 수를 구한다.", "이 사건은 조건 사건에 포함된다."),
                ("유리한 경우 수를 조건 사건의 경우 수로 나눈다.", "원래 전체 경우 수가 분모가 아님에 주의한다."),
                ("기약분수로 정리한다.", rf"따라서 조건부확률은 ${answer}$이다."),
            ], alternatives=["적어도 빨간 공 하나인 경우를 빨강·빨강과 빨강·파랑으로 나누어 직접 셀 수 있다."],
            answer_check=lambda values=row: _urn_at_least_one_first_probability(*values),
        ))
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 포물선 위 움직이는 점과 절댓값 이차식이다. 작동 원리는 거리 최소화와 부호 분할 정적분 문제를 각 5개 만든다."""
    specs: list[dict[str, Any]] = []
    heights = [2, 3, 4, 5, 6]
    for index, height in enumerate(heights, 1):
        answer = _parabola_fixed_point_distance_stat(height)
        specs.append(_checked_problem(
            5, index,
            title=rf"실수 t에 따라 포물선 위를 움직이는 점 $P(t,t^2)$와 고정점 $Q(0,{height})$가 있다. 거리 $PQ$가 최소가 되는 모든 t의 제곱의 합과 그때의 $PQ^2$을 더한 값을 구하시오.",
            answer=str(answer), tags=["#두점사이의거리", "#거리공식", "#미분과최대최소", "#함수의극대와극소", "#최솟값"],
            steps=[
                ("거리의 최솟값 대신 거리 제곱의 최솟값을 구해도 됨을 확인한다.", "제곱함수는 음이 아닌 범위에서 증가한다."),
                ("두 점 사이 거리 공식으로 $PQ^2$을 t의 식으로 나타낸다.", "네제곱식이지만 t의 짝수 거듭제곱만 나타난다."),
                ("$u=t^2$로 치환해 u에 대한 이차함수를 만든다.", "u는 0 이상이다."),
                ("완전제곱 또는 미분으로 이차함수의 최소 u를 구한다.", "최소 u가 양수라서 t는 두 개다."),
                ("최소 거리 제곱과 두 t값의 제곱합을 각각 계산한다.", "두 t의 제곱은 모두 최소 u와 같다."),
                ("두 결과를 더해 기약분수로 정리한다.", rf"따라서 값은 ${answer}$이다."),
            ], alternatives=[
                "거리 제곱을 t로 직접 미분해 임계점 세 개를 비교할 수 있다.",
                "u=t² 평면에서 꼭짓점 공식을 적용해 최소 u와 함수값을 동시에 구할 수 있다.",
            ],
            answer_check=lambda value=height: _parabola_fixed_point_distance_stat(value),
        ))
    integral_rows = [(1, 2), (1, 3), (2, 3), (2, 4), (3, 5)]
    for index, row in enumerate(integral_rows, 6):
        inner_root, boundary = row
        answer = _absolute_quadratic_integral(*row)
        specs.append(_checked_problem(
            5, index,
            title=rf"정적분 $\int_{{-{boundary}}}^{{{boundary}}}|x^2-{inner_root**2}|\,dx$의 값을 구하시오.",
            answer=str(answer), tags=["#정적분", "#정적분의계산", "#정적분의성질", "#곡선과x축사이의넓이", "#이차함수"],
            steps=[
                ("절댓값 안의 이차식이 0이 되는 점을 구한다.", "두 근이 적분 구간 안에 있다."),
                ("각 근을 기준으로 이차식의 부호를 판정한다.", "두 근 사이에서는 음수이고 바깥에서는 양수이다."),
                ("함수가 짝함수이므로 0부터 양의 경계까지 적분한 값을 두 배한다.", "대칭성을 이용한다."),
                ("0부터 양의 근까지는 부호를 바꾸어 적분한다.", "절댓값을 제거할 때 음수를 붙인다."),
                ("양의 근부터 경계까지는 원래 이차식을 적분한다.", "두 구간의 원시함수 값을 계산한다."),
                ("두 적분값을 더하고 두 배해 정리한다.", rf"따라서 정적분은 ${answer}$이다."),
            ], alternatives=[
                "절댓값 그래프와 x축 사이의 넓이를 가운데 영역과 양쪽 영역으로 나눠 계산할 수 있다.",
                "전체 이차식 적분에서 음수인 가운데 영역 적분의 두 배를 빼는 방식으로도 계산할 수 있다.",
            ],
            answer_check=lambda values=row: _absolute_quadratic_integral(*values),
        ))
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v58 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v58 전체 카탈로그다. 작동 원리는 독립 정답 검산 후 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog = build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v58 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(
        catalog,
        expected_count=50,
        batch_id=BATCH_ID,
        model_name=MODEL_NAME,
        codebase_base=CODEBASE_BASE,
        seed_base=SEED_BASE,
    )


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v58 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(db_path, quests=validated_quests(), batch_id=BATCH_ID, validate_only=validate_only)


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v58 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
