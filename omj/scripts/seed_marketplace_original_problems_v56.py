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

BATCH_ID = "marketplace-original-v56"
MODEL_NAME = "aiflow-direct-authoring-v56"
CODEBASE_BASE = 20_261_017_000
SEED_BASE = 202_607_596_000


def _checked_problem(tier: int, index: int, *, answer_check: Callable[[], Any], **kwargs: Any) -> dict[str, Any]:
    """필요 변수는 문제 명세와 독립 계산 함수다. 작동 원리는 저장 답과 별도 계산 결과를 비교하도록 검산 함수를 부착한다."""
    spec = _problem(tier, index, **kwargs)
    spec["answer_check"] = answer_check
    return spec


def _proper_subset_count_of_symmetric_difference(upper: int, first_divisor: int, second_divisor: int) -> int:
    """필요 변수는 전체집합 상한과 두 배수 조건이다. 작동 원리는 두 집합 중 정확히 하나에 속하는 원소 집합의 진부분집합 수를 센다."""
    elements = {
        value for value in range(1, upper + 1)
        if (value % first_divisor == 0) != (value % second_divisor == 0)
    }
    return 2 ** len(elements) - 1


def _complex_conjugate_cube_expression(real: int, imaginary: int) -> int:
    """필요 변수는 복소수의 실수부와 허수부다. 작동 원리는 켤레합과 켤레차를 이용해 (z+z̄)³-(z-z̄)²을 실수로 계산한다."""
    return (2 * real) ** 3 + 4 * imaginary**2


def _exponential_equation_graph_value(
    base: int,
    first_constant: int,
    second_linear: int,
    second_constant: int,
    horizontal: int,
    vertical: int,
) -> Fraction:
    """필요 변수는 같은 밑 지수방정식과 평행이동한 그래프다. 작동 원리는 지수 일대일성으로 x를 구해 그래프 함수값을 계산한다."""
    denominator = 2 - second_linear
    if base <= 1 or denominator == 0:
        raise ValueError("증가 지수함수와 유일해를 갖는 지수식이 필요합니다.")
    solution = Fraction(second_constant - first_constant, denominator)
    exponent = solution - horizontal
    if exponent.denominator != 1:
        raise ValueError("정확한 정수 지수로 검산할 수 있는 자료가 필요합니다.")
    power = int(exponent)
    value = Fraction(base**power) if power >= 0 else Fraction(1, base ** (-power))
    return value + vertical


def _parabola_tangent_coordinate_sum(
    quadratic: int,
    linear: int,
    constant: int,
    slope: int,
) -> Fraction:
    """필요 변수는 포물선 계수와 접선 기울기다. 작동 원리는 중근조건으로 접선 절편과 접점 좌표를 구해 좌표합을 계산한다."""
    if quadratic == 0:
        raise ValueError("이차함수가 필요합니다.")
    point_x = Fraction(slope - linear, 2 * quadratic)
    intercept = constant - Fraction((linear - slope) ** 2, 4 * quadratic)
    point_y = slope * point_x + intercept
    return point_x + point_y


def _geometric_difference_term(first: int, difference_first: int, ratio: int, target: int) -> int:
    """필요 변수는 첫째항·첫 계차·공비·목표 첨자다. 작동 원리는 등비수열인 계차를 목표 직전까지 합해 원수열의 항을 구한다."""
    if target < 1:
        raise ValueError("양의 목표 첨자가 필요합니다.")
    value = first
    difference = difference_first
    for _ in range(1, target):
        value += difference
        difference *= ratio
    return value


def _inverse_of_affine_composition(
    outer_linear: int,
    outer_constant: int,
    inner_linear: int,
    inner_constant: int,
    target: int,
) -> Fraction:
    """필요 변수는 두 일차함수와 합성함수 출력값이다. 작동 원리는 합성 계수를 구해 역함숫값을 정확한 분수로 계산한다."""
    composed_linear = outer_linear * inner_linear
    if composed_linear == 0:
        raise ValueError("역함수가 존재하는 일차 합성함수가 필요합니다.")
    composed_constant = outer_linear * inner_constant + outer_constant
    return Fraction(target - composed_constant, composed_linear)


def _rational_infinity_limit(numerator_leading: int, denominator_leading: int) -> Fraction:
    """필요 변수는 같은 차수 다항식의 최고차항 계수다. 작동 원리는 무한대에서 낮은 차수항을 소거해 최고차항 계수비를 반환한다."""
    if denominator_leading == 0:
        raise ValueError("0이 아닌 분모 최고차항 계수가 필요합니다.")
    return Fraction(numerator_leading, denominator_leading)


def _intermediate_target_interval_count(values: tuple[int, ...], target: int) -> int:
    """필요 변수는 연속함수의 연속한 표본값과 목표값이다. 작동 원리는 목표값이 두 끝 함수값 사이에 엄격히 놓이는 단위구간을 센다."""
    if target in values:
        raise ValueError("표본점 자체가 목표값이 아닌 자료가 필요합니다.")
    return sum((first - target) * (second - target) < 0 for first, second in zip(values, values[1:]))


def _conditional_union_probability(sum_divisor: int, product_divisor: int) -> Fraction:
    """필요 변수는 두 주사위 합·곱의 배수 조건이다. 작동 원리는 첫째 눈이 홀수인 조건부 표본공간에서 두 사건의 합사건 확률을 전수 계산한다."""
    conditioned = [(first, second) for first in range(1, 7) for second in range(1, 7) if first % 2 == 1]
    favorable = [
        pair for pair in conditioned
        if (sum(pair) % sum_divisor == 0) or ((pair[0] * pair[1]) % product_divisor == 0)
    ]
    return Fraction(len(favorable), len(conditioned))


def _matrix_row_parameter_expression(
    first: tuple[int, int, int, int],
    second: tuple[int, int, int, int],
    first_row_target: int,
    second_row_target: int,
) -> Fraction:
    """필요 변수는 두 2×2 행렬과 선형결합의 행합 두 값이다. 작동 원리는 행합 연립방정식으로 스칼라를 구해 (p-q)와 A+B 전체합의 곱을 계산한다."""
    first_rows = (first[0] + first[1], first[2] + first[3])
    second_rows = (second[0] + second[1], second[2] + second[3])
    determinant = first_rows[0] * second_rows[1] - first_rows[1] * second_rows[0]
    if determinant == 0:
        raise ValueError("두 스칼라를 유일하게 구할 수 있는 행합이 필요합니다.")
    parameter_p = Fraction(first_row_target * second_rows[1] - second_row_target * second_rows[0], determinant)
    parameter_q = Fraction(first_rows[0] * second_row_target - first_rows[1] * first_row_target, determinant)
    return (parameter_p - parameter_q) * (sum(first) + sum(second))


def _matrix_text(values: tuple[int, int, int, int]) -> str:
    """필요 변수는 행 우선 2×2 행렬 성분이다. 작동 원리는 문제 본문용 LaTeX 행렬 문자열로 변환한다."""
    return rf"\begin{{pmatrix}}{values[0]}&{values[1]}\\{values[2]}&{values[3]}\end{{pmatrix}}"


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 배수 집합과 복소수다. 작동 원리는 집합 연산 진부분집합과 켤레복소수 항등식 문제를 각 5개 만든다."""
    specs: list[dict[str, Any]] = []
    set_rows = [(18, 2, 3), (24, 3, 4), (30, 4, 5), (36, 5, 6), (40, 3, 7)]
    for index, row in enumerate(set_rows, 1):
        upper, first_divisor, second_divisor = row
        answer = _proper_subset_count_of_symmetric_difference(*row)
        specs.append(_checked_problem(
            1, index,
            title=rf"전체집합 $U=\{{1,2,\ldots,{upper}\}}$에서 A는 {first_divisor}의 배수 집합, B는 {second_divisor}의 배수 집합이다. $C=(A\cup B)-(A\cap B)$일 때 C의 진부분집합 개수를 구하시오.",
            answer=str(answer), tags=["#집합의연산", "#집합의표현", "#합집합", "#차집합", "#진부분집합"],
            steps=[
                ("A와 B 중 정확히 하나에만 속하는 원소로 C를 만든다.", "교집합 원소는 합집합에서 제외된다."),
                ("C의 원소 수를 구해 전체 부분집합에서 C 자신을 제외한다.", rf"따라서 진부분집합은 ${answer}$개이다."),
            ], answer_check=lambda values=row: _proper_subset_count_of_symmetric_difference(*values),
        ))
    complex_rows = [(1, 2), (-2, 3), (3, -1), (-1, -4), (4, 2)]
    for index, (real, imaginary) in enumerate(complex_rows, 6):
        answer = _complex_conjugate_cube_expression(real, imaginary)
        specs.append(_checked_problem(
            1, index,
            title=rf"복소수 $z=({real})+({imaginary})i$와 켤레복소수 $\overline z$에 대하여 $(z+\overline z)^3-(z-\overline z)^2$의 값을 구하시오.",
            answer=str(answer), tags=["#켤레복소수", "#복소수의연산", "#세제곱공식", "#항등식", "#항등식의성질"],
            steps=[
                ("z와 켤레복소수의 합과 차를 각각 계산한다.", "합은 실수이고 차는 순허수다."),
                ("세제곱과 제곱을 계산해 실수로 정리한다.", rf"$i^2=-1$을 적용하면 값은 ${answer}$이다."),
            ], answer_check=lambda a=real, b=imaginary: _complex_conjugate_cube_expression(a, b),
        ))
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 지수방정식·지수그래프와 포물선·접선이다. 작동 원리는 그래프 함수값과 중근 접점 문제를 각 5개 만든다."""
    specs: list[dict[str, Any]] = []
    exponent_rows = [(2, 1, 1, 5, 2, 1), (3, -1, 1, 3, 1, -2), (2, 4, 0, 8, 2, 3), (4, 2, 1, 6, 1, 1), (5, -2, 1, 2, 0, -1)]
    for index, row in enumerate(exponent_rows, 1):
        base, first_constant, second_linear, second_constant, horizontal, vertical = row
        answer = _exponential_equation_graph_value(*row)
        specs.append(_checked_problem(
            2, index,
            title=rf"방정식 ${base}^{{2x+({first_constant})}}={base}^{{{second_linear}x+({second_constant})}}$의 해를 α라 하자. 지수함수 $f(x)={base}^{{x-({horizontal})}}+({vertical})$에 대하여 $f(\alpha)$를 구하시오.",
            answer=str(answer), tags=["#지수", "#지수방정식과지수부등식", "#지수함수", "#지수함수의그래프", "#지수함수의평행이동"],
            steps=[
                ("양변의 밑이 같고 1이 아니므로 지수를 같게 놓는다.", "x에 관한 일차방정식을 푼다."),
                ("구한 α를 평행이동한 지수함수에 대입한다.", "가로 이동량의 부호를 확인한다."),
                ("거듭제곱과 세로 이동량을 계산한다.", rf"따라서 $f(\alpha)={answer}$이다."),
            ], answer_check=lambda values=row: _exponential_equation_graph_value(*values),
        ))
    tangent_rows = [(1, -2, 3, 4), (2, 1, -1, 5), (1, 4, 2, -2), (3, -3, 1, 6), (2, -5, 4, 1)]
    for index, row in enumerate(tangent_rows, 6):
        quadratic, linear, constant, slope = row
        answer = _parabola_tangent_coordinate_sum(*row)
        specs.append(_checked_problem(
            2, index,
            title=rf"포물선 $y=({quadratic})x^2+({linear})x+({constant})$에 기울기가 {slope}인 직선이 접한다. 접점의 x좌표와 y좌표의 합을 구하시오.",
            answer=str(answer), tags=["#이차함수와이차방정식", "#이차함수의그래프", "#중근조건", "#판별식과근의개수", "#포물선"],
            steps=[
                ("접선의 y절편을 미지수로 놓고 포물선 식과 같게 놓는다.", "교점 방정식은 이차방정식이다."),
                ("접하므로 판별식이 0인 중근조건을 적용한다.", "접선 절편과 중근 x좌표를 구한다."),
                ("접선 식에 x좌표를 대입해 y좌표를 구하고 더한다.", rf"따라서 접점 좌표합은 ${answer}$이다."),
            ], answer_check=lambda values=row: _parabola_tangent_coordinate_sum(*values),
        ))
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 등비 계차수열과 두 일차함수의 합성이다. 작동 원리는 계차합과 합성 역함숫값 문제를 각 5개 만든다."""
    specs: list[dict[str, Any]] = []
    difference_rows = [(2, 1, 2, 6), (-3, 2, 3, 5), (5, -1, 2, 7), (1, 3, -2, 6), (4, 2, -3, 5)]
    for index, row in enumerate(difference_rows, 1):
        first, difference_first, ratio, target = row
        answer = _geometric_difference_term(*row)
        specs.append(_checked_problem(
            3, index,
            title=rf"수열 $(a_n)$에서 $a_1={first}$이고 계차수열 $d_n=a_{{n+1}}-a_n$이 첫째항 {difference_first}, 공비 {ratio}인 등비수열이다. $a_{target}$을 구하시오.",
            answer=str(answer), tags=["#계차수열", "#등비수열의합", "#등비수열", "#항", "#수열의정의"],
            steps=[
                ("a목표항과 a₁의 차를 계차수열의 합으로 나타낸다.", "목표 직전 계차까지 더한다."),
                ("등비수열의 합 공식을 적용한다.", "공비가 음수인 경우도 같은 공식을 쓴다."),
                ("계차합을 첫째항에 더한다.", "망원합으로 중간항이 소거된다."),
                ("값을 정리한다.", rf"따라서 $a_{target}={answer}$이다."),
            ], alternatives=["계차를 순서대로 생성해 원수열 항을 반복 계산할 수 있다."],
            answer_check=lambda values=row: _geometric_difference_term(*values),
        ))
    composition_rows = [(2, 1, 3, -2, 17), (-1, 4, 2, 3, -5), (3, -2, -2, 5, 11), (4, 1, 1, -3, 21), (-2, -1, 3, 2, -10)]
    for index, row in enumerate(composition_rows, 6):
        outer_linear, outer_constant, inner_linear, inner_constant, target = row
        answer = _inverse_of_affine_composition(*row)
        specs.append(_checked_problem(
            3, index,
            title=rf"일차함수 $f(x)=({outer_linear})x+({outer_constant})$, $g(x)=({inner_linear})x+({inner_constant})$에 대하여 $h=f\circ g$라 하자. $h^{{-1}}({target})$의 값을 구하시오.",
            answer=str(answer), tags=["#합성함수의정의", "#합성함수의성질", "#역함수구하기", "#역함수의그래프", "#함수의정의"],
            steps=[
                ("f(g(x))를 전개해 h의 일차식 계수를 구한다.", "합성 순서를 바꾸지 않는다."),
                ("h(x)=목표값인 일차방정식을 세운다.", "역함숫값은 원함수의 입력값이다."),
                ("일차방정식을 풀어 x를 구한다.", "h의 기울기가 0이 아니므로 역함수가 존재한다."),
                ("h에 다시 대입해 목표 출력이 나오는지 확인한다.", rf"따라서 $h^{{-1}}({target})={answer}$이다."),
            ], alternatives=["h의 역함수 식을 먼저 구한 뒤 목표값을 직접 대입할 수 있다."],
            answer_check=lambda values=row: _inverse_of_affine_composition(*values),
        ))
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 같은 차수 유리식과 연속함수 표본값이다. 작동 원리는 무한대 극한과 중간값정리 보장 구간 문제를 각 5개 만든다."""
    specs: list[dict[str, Any]] = []
    infinity_rows = [(3, 2, -5, 4, 1, -7), (-2, 5, 4, -3, 2, 1), (5, -1, 3, 2, -4, 6), (1, 7, -2, -3, 5, 4), (-4, 2, 8, 5, 1, -9)]
    for index, row in enumerate(infinity_rows, 1):
        num_lead, num_linear, num_constant, den_lead, den_linear, den_constant = row
        answer = _rational_infinity_limit(num_lead, den_lead)
        specs.append(_checked_problem(
            4, index,
            title=rf"극한 $\lim_{{x\to\infty}}\dfrac{{({num_lead})x^2+({num_linear})x+({num_constant})}}{{({den_lead})x^2+({den_linear})x+({den_constant})}}$의 값을 구하시오.",
            answer=str(answer), tags=["#무한대의극한", "#극한의사칙연산", "#극한의성질", "#유리식의계산", "#미적분Ⅰ"],
            steps=[
                ("분자와 분모를 최고차항 x²으로 나눈다.", "각 항의 차수를 0 이하로 낮춘다."),
                ("x가 무한대로 갈 때 1/x와 1/x²의 극한을 적용한다.", "낮은 차수항은 모두 0으로 간다."),
                ("남는 최고차항 계수만 확인한다.", "분모 최고차항 계수는 0이 아니다."),
                ("두 계수의 비를 기약분수로 정리한다.", rf"따라서 극한값은 ${answer}$이다."),
                ("양의 무한대에서 분모 부호가 안정됨을 확인한다.", rf"최종 답은 ${answer}$이다."),
            ], alternatives=["분자·분모의 최고차항 성장률을 직접 비교해 계수비를 구할 수 있다."],
            answer_check=lambda a=num_lead, b=den_lead: _rational_infinity_limit(a, b),
        ))
    target_rows = [((-2, 3, 5, 1, 6), 2), ((4, 1, -3, 2, 7), 0), ((-1, 5, 2, -4, 3), 1), ((6, 3, -2, 5, -1), 2), ((2, -3, 4, 6, 1), 0)]
    for index, (values, target) in enumerate(target_rows, 6):
        answer = _intermediate_target_interval_count(values, target)
        samples = ", ".join(rf"f({i})={value}" for i, value in enumerate(values))
        specs.append(_checked_problem(
            4, index,
            title=rf"닫힌구간 $[0,4]$에서 연속인 함수 f가 ${samples}$를 만족한다. 중간값정리로 방정식 $f(x)={target}$의 해가 존재한다고 보장되는 단위 열린구간의 개수를 구하시오.",
            answer=str(answer), tags=["#중간값정리", "#함수의연속", "#연속함수의성질", "#실근조건", "#일치조건"],
            steps=[
                ("각 표본 함수값에서 목표값을 뺀 부호를 조사한다.", "표본값 자체는 목표값과 다르다."),
                ("인접한 두 차의 곱이 음수인지 확인한다.", "부호가 바뀌면 목표값을 사이에서 지난다."),
                ("함수의 연속성을 이용해 해당 열린구간에 해가 있음을 보장한다.", "한 구간에 여러 해가 있어도 구간은 한 번 센다."),
                ("모든 인접 표본 쌍을 빠짐없이 확인한다.", "총 네 단위구간을 조사한다."),
                ("보장되는 구간 수를 센다.", rf"따라서 개수는 ${answer}$이다."),
            ], alternatives=["함수값을 목표값 기준 위·아래로 표시한 부호표를 그릴 수 있다."],
            answer_check=lambda row=values, value=target: _intermediate_target_interval_count(row, value),
        ))
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 주사위 합사건과 행렬 선형결합 행합이다. 작동 원리는 조건부확률과 스칼라 역산 문제를 각 5개 만든다."""
    specs: list[dict[str, Any]] = []
    probability_rows = [(3, 2), (4, 3), (5, 2), (3, 4), (4, 5)]
    for index, row in enumerate(probability_rows, 1):
        sum_divisor, product_divisor = row
        answer = _conditional_union_probability(*row)
        specs.append(_checked_problem(
            5, index,
            title=rf"서로 다른 두 주사위를 던진다. 첫째 주사위의 눈이 홀수라는 조건에서, ‘두 눈의 합이 {sum_divisor}의 배수’ 또는 ‘두 눈의 곱이 {product_divisor}의 배수’일 조건부확률을 구하시오.",
            answer=str(answer), tags=["#사건의합", "#사건의곱", "#여집합", "#경우의수", "#합의법칙"],
            steps=[
                ("첫째 주사위가 홀수인 조건부 표본공간을 만든다.", "첫째 눈 세 가지와 둘째 눈 여섯 가지를 곱한다."),
                ("합이 지정 배수인 사건 A를 조건부 표본공간에서 찾는다.", "순서쌍을 중복 없이 기록한다."),
                ("곱이 지정 배수인 사건 B도 같은 방식으로 찾는다.", "약수 조건을 이용할 수 있다."),
                ("A∪B의 경우 수를 덧셈정리로 계산한다.", "$|A|+|B|-|A\cap B|$이다."),
                ("합사건 경우 수를 조건부 표본공간 크기로 나눈다.", "조건 밖 순서쌍은 분모에 포함하지 않는다."),
                ("기약분수로 정리한다.", rf"따라서 조건부확률은 ${answer}$이다."),
            ], alternatives=[
                "조건부 표본공간 18개를 표로 그리고 두 사건을 색칠해 합집합을 직접 셀 수 있다.",
                "여사건을 이용해 두 조건을 모두 만족하지 않는 순서쌍을 전체에서 뺄 수 있다.",
            ], answer_check=lambda values=row: _conditional_union_probability(*values),
        ))
    matrix_rows = [
        ((1, 2, 0, 3), (2, -1, 1, 1), 2, -1),
        ((2, 0, -1, 1), (1, 3, 2, -1), -1, 2),
        ((1, -2, 3, 0), (2, 1, -1, 4), 3, 1),
        ((3, 1, 2, -1), (-1, 2, 0, 3), 1, -2),
        ((2, -1, 1, 2), (1, 2, -2, 1), -2, 3),
    ]
    for index, (first, second, parameter_p, parameter_q) in enumerate(matrix_rows, 6):
        first_target = parameter_p * (first[0] + first[1]) + parameter_q * (second[0] + second[1])
        second_target = parameter_p * (first[2] + first[3]) + parameter_q * (second[2] + second[3])
        answer = _matrix_row_parameter_expression(first, second, first_target, second_target)
        specs.append(_checked_problem(
            5, index,
            title=rf"행렬 $A={_matrix_text(first)}$, $B={_matrix_text(second)}$에 대하여 $pA+qB$의 첫째 행 원소 합이 {first_target}, 둘째 행 원소 합이 {second_target}이다. $(p-q)$와 $A+B$의 모든 원소 합의 곱을 구하시오.",
            answer=str(answer), tags=["#스칼라곱", "#행", "#행렬의덧셈", "#행렬의연산", "#행렬"],
            steps=[
                ("A와 B의 각 행 원소 합을 따로 계산한다.", "행렬 선형결합의 행합도 같은 스칼라로 결합된다."),
                ("첫째 행 조건으로 p,q의 첫 일차방정식을 만든다.", "대응하는 두 행합을 계수로 사용한다."),
                ("둘째 행 조건으로 두 번째 일차방정식을 만든다.", "두 식은 독립이므로 유일해를 갖는다."),
                ("연립방정식을 풀어 p-q를 계산한다.", "구한 값은 두 행합 조건에 다시 대입한다."),
                ("A+B의 모든 원소 합을 성분별 덧셈으로 구한다.", "A 전체합과 B 전체합을 더해도 같다."),
                ("두 값을 곱해 정리한다.", rf"따라서 요구한 값은 ${answer}$이다."),
            ], alternatives=[
                "각 행을 길이 2인 벡터로 보고 성분합 함수의 선형성을 이용할 수 있다.",
                "pA+qB의 네 성분을 직접 쓴 뒤 행별로 묶어 같은 연립방정식을 얻을 수 있다.",
            ], answer_check=lambda a=first, b=second, c=first_target, d=second_target: _matrix_row_parameter_expression(a, b, c, d),
        ))
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v56 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v56 전체 카탈로그다. 작동 원리는 독립 정답 검산 후 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog = build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v56 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(catalog, expected_count=50, batch_id=BATCH_ID, model_name=MODEL_NAME, codebase_base=CODEBASE_BASE, seed_base=SEED_BASE)


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v56 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(db_path, quests=validated_quests(), batch_id=BATCH_ID, validate_only=validate_only)


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v56 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
