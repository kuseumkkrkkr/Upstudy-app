from __future__ import annotations

import argparse
import json
import sys
from fractions import Fraction
from functools import lru_cache
from pathlib import Path
from typing import Any, Callable

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.marketplace_problem_batch import seed_problem_batch, validate_problem_batch
from scripts.seed_initial_math_problems import _problem

BATCH_ID = "marketplace-original-v52"
MODEL_NAME = "aiflow-direct-authoring-v52"
CODEBASE_BASE = 20_261_013_000
SEED_BASE = 202_607_592_000


def _checked_problem(tier: int, index: int, *, answer_check: Callable[[], Any], **kwargs: Any) -> dict[str, Any]:
    """필요 변수는 문제 명세와 독립 계산 함수다. 작동 원리는 저장 답과 별도 계산 결과를 비교하도록 검산 함수를 부착한다."""
    spec = _problem(tier, index, **kwargs)
    spec["answer_check"] = answer_check
    return spec


def _constrained_proper_subset_count(total: int, required: tuple[int, ...], forbidden: tuple[int, ...]) -> int:
    """필요 변수는 전체 원소 수와 필수·금지 원소다. 작동 원리는 모든 부분집합을 비트로 순회해 조건을 만족하는 진부분집합을 센다."""
    universe = set(range(1, total + 1))
    required_set, forbidden_set = set(required), set(forbidden)
    if not required_set <= universe or not forbidden_set <= universe or required_set & forbidden_set:
        raise ValueError("필수·금지 원소는 전체집합 안에서 서로소여야 합니다.")
    count = 0
    for mask in range(1 << total):
        subset = {value for value in universe if mask & (1 << (value - 1))}
        if subset != universe and required_set <= subset and not subset & forbidden_set:
            count += 1
    return count


def _identity_coefficient_difference(root_left: int, shift_right: int, linear: int, constant: int) -> Fraction:
    """필요 변수는 두 일차식의 이동량과 항등식 우변 계수다. 작동 원리는 동류항 계수 비교로 두 미지 계수를 구해 차를 반환한다."""
    denominator = root_left + shift_right
    if denominator == 0:
        raise ValueError("두 계수를 유일하게 정할 수 있는 항등식이 필요합니다.")
    first = Fraction(shift_right * linear - constant, denominator)
    second = Fraction(root_left * linear + constant, denominator)
    return first - second


def _transformed_parabola_axis_intercept_sum(
    leading: int,
    axis: int,
    vertical: int,
    horizontal_move: int,
    vertical_move: int,
) -> int:
    """필요 변수는 꼭짓점형 이차함수와 이동량이다. 작동 원리는 평행이동 뒤 원점대칭한 그래프의 축과 y절편을 더한다."""
    moved_axis = axis + horizontal_move
    final_axis = -moved_axis
    final_y_intercept = -leading * moved_axis**2 - vertical - vertical_move
    return final_axis + final_y_intercept


def _root_symmetric_product(root_sum: int, root_product: int) -> int:
    """필요 변수는 이차방정식 두 근의 합과 곱이다. 작동 원리는 대칭식을 전개해 (α²+1)(β²+1)을 계산한다."""
    square_sum = root_sum**2 - 2 * root_product
    return root_product**2 + square_sum + 1


def _shifted_exponential_coordinate_sum(base: int, horizontal: int, vertical: int, exponent: int) -> int:
    """필요 변수는 지수함수 밑·이동량과 교점 지수다. 작동 원리는 수평선 교점의 x좌표와 점근선 y좌표를 더한다."""
    if base <= 0 or base == 1:
        raise ValueError("양수이면서 1이 아닌 지수함수의 밑이 필요합니다.")
    return exponent + horizontal + vertical


def _recover_affine_function_value(
    inner_linear: int,
    inner_constant: int,
    composed_linear: int,
    composed_constant: int,
    argument: int,
) -> Fraction:
    """필요 변수는 일차함수 g와 합성함수 f∘g의 계수다. 작동 원리는 계수를 역산해 f의 지정한 함수값을 구한다."""
    if inner_linear == 0:
        raise ValueError("역산 가능한 일차함수 g가 필요합니다.")
    outer_linear = Fraction(composed_linear, inner_linear)
    outer_constant = composed_constant - outer_linear * inner_constant
    return outer_linear * argument + outer_constant


def _factor_remainder_unknown_sum(leading_second: int, factor_root: int, test_point: int, remainder: int) -> Fraction:
    """필요 변수는 삼차식의 이차항 계수·인수의 근·나머지 조건이다. 작동 원리는 두 함수값 식을 풀어 일차항과 상수항 계수 합을 구한다."""
    if factor_root == test_point:
        raise ValueError("서로 다른 두 대입점이 필요합니다.")
    root_fixed = -factor_root**3 - leading_second * factor_root**2
    test_fixed = remainder - test_point**3 - leading_second * test_point**2
    linear = Fraction(test_fixed - root_fixed, test_point - factor_root)
    constant = root_fixed - linear * factor_root
    return linear + constant


def _implication_counterexample_sum(
    lower: int,
    upper: int,
    first_divisor: int,
    second_divisor: int,
    second_remainder: int,
) -> int:
    """필요 변수는 정수 전체집합과 두 조건이다. 작동 원리는 p⇒q와 그 역 q⇒p의 반례를 각각 세어 합한다."""
    if lower > upper or first_divisor <= 0 or second_divisor <= 0:
        raise ValueError("유효한 정수 범위와 양의 나누는 수가 필요합니다.")
    first_not_second = 0
    second_not_first = 0
    for value in range(lower, upper + 1):
        first = value % first_divisor == 0
        second = value % second_divisor == second_remainder
        first_not_second += first and not second
        second_not_first += second and not first
    return first_not_second + second_not_first


def _nonadjacent_multiset_permutations(counts: tuple[int, ...]) -> int:
    """필요 변수는 문자별 중복 개수다. 작동 원리는 직전 문자와 남은 개수를 상태로 메모이제이션해 같은 문자가 이웃하지 않는 배열을 센다."""
    if not counts or any(count < 0 for count in counts):
        raise ValueError("0 이상의 문자 개수가 필요합니다.")

    @lru_cache(maxsize=None)
    def visit(remaining: tuple[int, ...], previous: int) -> int:
        """필요 변수는 남은 문자 수와 직전 문자 번호다. 작동 원리는 직전 문자 이외의 선택지를 재귀 합산한다."""
        if sum(remaining) == 0:
            return 1
        total = 0
        for index, count in enumerate(remaining):
            if count == 0 or index == previous:
                continue
            next_counts = list(remaining)
            next_counts[index] -= 1
            total += visit(tuple(next_counts), index)
        return total

    return visit(counts, -1)


def _matrix_parameter_expression(
    first: tuple[int, int, int, int],
    second: tuple[int, int, int, int],
    result: tuple[int, int, int, int],
) -> Fraction:
    """필요 변수는 두 2×2 행렬과 선형결합 결과다. 작동 원리는 독립인 두 성분으로 결합계수를 복원해 (p-q)det(A+B)를 계산한다."""
    parameter_p: Fraction | None = None
    parameter_q: Fraction | None = None
    for left in range(4):
        for right in range(left + 1, 4):
            determinant = first[left] * second[right] - first[right] * second[left]
            if determinant == 0:
                continue
            parameter_p = Fraction(result[left] * second[right] - result[right] * second[left], determinant)
            parameter_q = Fraction(first[left] * result[right] - first[right] * result[left], determinant)
            break
        if parameter_p is not None:
            break
    if parameter_p is None or parameter_q is None:
        raise ValueError("결합계수를 유일하게 복원할 수 있는 행렬이 필요합니다.")
    if any(parameter_p * a + parameter_q * b != c for a, b, c in zip(first, second, result)):
        raise ValueError("주어진 결과 행렬이 두 행렬의 일관된 선형결합이 아닙니다.")
    summed = tuple(a + b for a, b in zip(first, second))
    determinant_sum = summed[0] * summed[3] - summed[1] * summed[2]
    return (parameter_p - parameter_q) * determinant_sum


def _matrix_text(values: tuple[int, int, int, int]) -> str:
    """필요 변수는 행 우선 2×2 행렬 성분이다. 작동 원리는 문제 본문에 넣을 LaTeX 행렬 문자열로 변환한다."""
    return rf"\begin{{pmatrix}}{values[0]}&{values[1]}\\{values[2]}&{values[3]}\end{{pmatrix}}"


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 포함·배제 조건과 일차 항등식이다. 작동 원리는 진부분집합과 계수 비교 문제를 각 5개 만든다."""
    specs: list[dict[str, Any]] = []
    subset_rows = [
        (7, (1, 2), (7,)),
        (8, (2, 5), (1, 8)),
        (9, (1, 4, 7), (3,)),
        (10, (2, 6), (9, 10)),
        (11, (1, 5, 8), (2, 11)),
    ]
    for index, row in enumerate(subset_rows, 1):
        total, required, forbidden = row
        answer = _constrained_proper_subset_count(*row)
        required_text = ",".join(map(str, required))
        forbidden_text = ",".join(map(str, forbidden))
        specs.append(_checked_problem(
            1,
            index,
            title=rf"전체집합 $U=\{{1,2,\ldots,{total}\}}$의 진부분집합 X 중 $\{{{required_text}\}}\subseteq X$이고 $X\cap\{{{forbidden_text}\}}=\varnothing$인 X의 개수를 구하시오.",
            answer=str(answer),
            tags=["#진부분집합", "#집합의포함관계", "#교집합", "#집합"],
            steps=[
                ("반드시 포함할 원소와 반드시 제외할 원소를 고정한다.", "두 조건의 원소는 서로 겹치지 않는다."),
                ("나머지 원소의 포함 여부를 정해 경우의 수를 계산한다.", rf"금지 원소가 있어 X는 자동으로 U와 다르므로 조건을 만족하는 진부분집합은 ${answer}$개이다."),
            ],
            answer_check=lambda values=row: _constrained_proper_subset_count(*values),
        ))

    identity_rows = [(1, 2, 4, -1), (2, 3, -2, 5), (3, 1, 5, 2), (4, 3, -3, -2), (2, 5, 6, 1)]
    for index, (root_left, shift_right, first, second) in enumerate(identity_rows, 6):
        linear = first + second
        constant = -root_left * first + shift_right * second
        answer = _identity_coefficient_difference(root_left, shift_right, linear, constant)
        specs.append(_checked_problem(
            1,
            index,
            title=rf"x에 대한 항등식 $a(x-{root_left})+b(x+{shift_right})\equiv {linear}x+({constant})$가 성립할 때 $a-b$를 구하시오.",
            answer=str(answer),
            tags=["#항등식", "#항등식의성질", "#다항식의연산", "#공통수학1"],
            steps=[
                ("좌변을 전개하고 항등식의 같은 차수 계수를 비교한다.", "$x$의 계수와 상수항에서 a,b에 관한 두 일차방정식을 얻는다."),
                ("연립방정식을 풀어 두 계수의 차를 계산한다.", rf"따라서 $a-b={answer}$이다."),
            ],
            answer_check=lambda r=root_left, s=shift_right, p=linear, q=constant: _identity_coefficient_difference(r, s, p, q),
        ))
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 이동·대칭할 포물선과 이차방정식 근 정보다. 작동 원리는 그래프 좌표와 근의 대칭식 문제를 각 5개 만든다."""
    specs: list[dict[str, Any]] = []
    parabola_rows = [(1, 2, -1, 3, 2), (2, -1, 3, 4, -2), (-1, 3, 2, -2, 5), (3, 0, -4, 2, 1), (-2, -2, 1, 5, 3)]
    for index, row in enumerate(parabola_rows, 1):
        leading, axis, vertical, horizontal_move, vertical_move = row
        answer = _transformed_parabola_axis_intercept_sum(*row)
        specs.append(_checked_problem(
            2,
            index,
            title=rf"포물선 $y={leading}(x-({axis}))^2+({vertical})$를 x축 방향으로 {horizontal_move}, y축 방향으로 {vertical_move}만큼 평행이동한 뒤 원점대칭하였다. 최종 그래프의 축의 x좌표와 y절편의 합을 구하시오.",
            answer=str(answer),
            tags=["#이차함수의평행이동", "#이차함수의대칭이동", "#원점대칭", "#축"],
            steps=[
                ("평행이동 뒤 꼭짓점의 좌표를 구한다.", "가로와 세로 이동량을 각각 기존 꼭짓점에 더한다."),
                ("원점대칭은 모든 점의 두 좌표 부호를 바꾼다.", "포물선의 축도 원점 반대편으로 이동한다."),
                ("변환된 식의 y절편을 구해 축 좌표와 더한다.", rf"x=0을 대입하면 되므로 요구한 합은 ${answer}$이다."),
            ],
            answer_check=lambda values=row: _transformed_parabola_axis_intercept_sum(*values),
        ))

    root_rows = [(5, 6), (-3, -4), (2, -8), (7, 10), (-1, -12)]
    for index, (root_sum, root_product) in enumerate(root_rows, 6):
        answer = _root_symmetric_product(root_sum, root_product)
        specs.append(_checked_problem(
            2,
            index,
            title=rf"이차방정식 $x^2-({root_sum})x+({root_product})=0$의 두 근을 $\alpha,\beta$라 할 때 $(\alpha^2+1)(\beta^2+1)$의 값을 구하시오.",
            answer=str(answer),
            tags=["#이차방정식의근과계수", "#두근의합", "#두근의곱", "#이차방정식의풀이"],
            steps=[
                ("근과 계수의 관계로 두 근의 합과 곱을 읽는다.", rf"$\alpha+\beta={root_sum}$, $\alpha\beta={root_product}$이다."),
                ("주어진 곱을 전개하고 두 근의 제곱합을 바꾼다.", "$\alpha^2\beta^2+\alpha^2+\beta^2+1$에서 $\alpha^2+\beta^2=(\alpha+\beta)^2-2\alpha\beta$를 쓴다."),
                ("값을 대입해 계산한다.", rf"따라서 값은 ${answer}$이다."),
            ],
            answer_check=lambda s=root_sum, p=root_product: _root_symmetric_product(s, p),
        ))
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 평행이동한 지수함수와 일차 합성함수다. 작동 원리는 교점·점근선 및 외부함수 역산 문제를 각 5개 만든다."""
    specs: list[dict[str, Any]] = []
    exponential_rows = [(2, 3, -2, 4), (3, -1, 2, 3), (4, 2, 1, -2), (5, -3, -1, 2), (2, 4, 3, -3)]
    for index, row in enumerate(exponential_rows, 1):
        base, horizontal, vertical, exponent = row
        line_value = base**exponent + vertical
        if isinstance(line_value, float):
            line_text = str(Fraction(1, base ** (-exponent)) + vertical)
        else:
            line_text = str(line_value)
        answer = _shifted_exponential_coordinate_sum(*row)
        specs.append(_checked_problem(
            3,
            index,
            title=rf"지수함수 $y={base}^{{x-({horizontal})}}+({vertical})$의 그래프와 수평선 $y={line_text}$의 교점을 P라 하자. P의 x좌표와 지수함수 그래프의 수평점근선 y좌표의 합을 구하시오.",
            answer=str(answer),
            tags=["#지수함수", "#지수함수의평행이동", "#평행이동", "#치역"],
            steps=[
                ("수평선의 y값에서 세로 이동량을 뺀다.", "남은 값을 주어진 밑의 거듭제곱으로 나타낸다."),
                ("지수가 같아지도록 x에 관한 방정식을 푼다.", "가로 이동량의 부호를 주의한다."),
                ("지수함수의 수평점근선을 읽는다.", rf"수평점근선은 $y={vertical}$이다."),
                ("교점의 x좌표와 점근선 y좌표를 더한다.", rf"따라서 합은 ${answer}$이다."),
            ],
            alternatives=["평행이동 전 기본 지수함수의 대응점과 점근선을 함께 이동시켜 좌표를 구할 수 있다."],
            answer_check=lambda values=row: _shifted_exponential_coordinate_sum(*values),
        ))

    composition_rows = [(2, 1, 3, -2, 5), (-3, 4, 2, 1, -1), (4, -2, -1, 5, 3), (5, 3, 2, -4, 0), (-2, -3, 4, 2, 6)]
    for index, (inner_linear, inner_constant, outer_linear, outer_constant, argument) in enumerate(composition_rows, 6):
        composed_linear = outer_linear * inner_linear
        composed_constant = outer_linear * inner_constant + outer_constant
        answer = _recover_affine_function_value(inner_linear, inner_constant, composed_linear, composed_constant, argument)
        specs.append(_checked_problem(
            3,
            index,
            title=rf"일차함수 $g(x)={inner_linear}x+({inner_constant})$와 함수 f가 $(f\circ g)(x)={composed_linear}x+({composed_constant})$를 만족한다. $f({argument})$의 값을 구하시오.",
            answer=str(answer),
            tags=["#합성함수의정의", "#합성함수", "#함수", "#대응"],
            steps=[
                ("f도 일차함수 $f(x)=ax+b$로 놓는다.", "g의 일차항 계수가 0이 아니므로 f의 계수를 역산할 수 있다."),
                ("f(g(x))를 전개한다.", "x의 계수와 상수항을 각각 정리한다."),
                ("주어진 합성함수와 계수를 비교해 a,b를 구한다.", "두 계수 조건을 차례로 사용한다."),
                ("구한 f에 지정한 입력값을 대입한다.", rf"따라서 $f({argument})={answer}$이다."),
            ],
            alternatives=["g의 역함수를 이용해 $f=(f\circ g)\circ g^{-1}$로 구할 수 있다."],
            answer_check=lambda a=inner_linear, b=inner_constant, c=composed_linear, d=composed_constant, x=argument: _recover_affine_function_value(a, b, c, d, x),
        ))
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 삼차식의 인수·나머지 조건과 유한집합 명제다. 작동 원리는 미지 계수와 두 방향 함의 반례 문제를 각 5개 만든다."""
    specs: list[dict[str, Any]] = []
    factor_rows = [(2, 1, 3, -4), (-1, -2, 1, 5), (3, 2, -1, 4), (-2, 3, 0, -5), (1, -1, 2, 6)]
    for index, (leading_second, factor_root, test_point, linear) in enumerate(factor_rows, 1):
        constant = -factor_root**3 - leading_second * factor_root**2 - linear * factor_root
        remainder = test_point**3 + leading_second * test_point**2 + linear * test_point + constant
        answer = _factor_remainder_unknown_sum(leading_second, factor_root, test_point, remainder)
        specs.append(_checked_problem(
            4,
            index,
            title=rf"다항식 $P(x)=x^3+({leading_second})x^2+ax+b$가 $x-({factor_root})$로 나누어떨어지고, $x-({test_point})$로 나눈 나머지가 {remainder}이다. $a+b$를 구하시오.",
            answer=str(answer),
            tags=["#나머지정리증명", "#인수정리증명", "#인수정리활용", "#조립제법"],
            steps=[
                ("인수정리에 따라 첫 번째 조건을 함수값 식으로 바꾼다.", rf"$P({factor_root})=0$이다."),
                ("나머지정리에 따라 두 번째 조건도 함수값 식으로 바꾼다.", rf"$P({test_point})={remainder}$이다."),
                ("두 대입식을 전개해 a,b의 연립방정식을 세운다.", "이미 주어진 삼차항과 이차항 값을 상수 쪽으로 옮긴다."),
                ("두 식을 빼서 a를 먼저 구한다.", "서로 다른 대입점이므로 계수가 0이 되지 않는다."),
                ("a를 대입해 b를 구하고 두 계수를 더한다.", rf"다른 나머지 조건에 대입해 검산하면 $a+b={answer}$이다."),
            ],
            alternatives=["조립제법 표 두 개를 작성해 나머지 행으로 연립방정식을 만들 수 있다."],
            answer_check=lambda a=leading_second, r=factor_root, s=test_point, value=remainder: _factor_remainder_unknown_sum(a, r, s, value),
        ))

    logic_rows = [(-8, 12, 2, 3, 1), (-10, 15, 3, 4, 2), (1, 24, 4, 5, 0), (-12, 18, 5, 3, 2), (0, 30, 6, 4, 1)]
    for index, row in enumerate(logic_rows, 6):
        lower, upper, first_divisor, second_divisor, second_remainder = row
        answer = _implication_counterexample_sum(*row)
        specs.append(_checked_problem(
            4,
            index,
            title=rf"전체집합 $U=\{{x\in\mathbb Z\mid {lower}\le x\le {upper}\}}$에서 p는 ‘x가 {first_divisor}의 배수’, q는 ‘x를 {second_divisor}로 나눈 나머지가 {second_remainder}’이다. 명제 $p\Rightarrow q$의 반례 수와 그 역 $q\Rightarrow p$의 반례 수의 합을 구하시오.",
            answer=str(answer),
            tags=["#역", "#대우", "#충분조건과필요조건", "#필요충분조건"],
            steps=[
                ("조건 p와 q를 만족하는 원소 집합 P,Q를 각각 만든다.", "전체집합의 유한한 정수만 조사한다."),
                ("p⇒q의 반례는 P에는 속하고 Q에는 속하지 않는 원소다.", "$P-Q$의 원소 수를 센다."),
                ("역 q⇒p의 반례는 Q에는 속하고 P에는 속하지 않는 원소다.", "$Q-P$의 원소 수를 센다."),
                ("원래 명제의 대우는 원래 명제와 동치임을 확인한다.", "대우를 역과 혼동하지 않는다."),
                ("두 차집합의 개수를 범위 끝까지 세어 더한다.", rf"두 집합은 서로소이므로 반례 수의 합은 ${answer}$이다."),
            ],
            alternatives=["각 정수에 대해 p,q의 진리값 표를 만들어 두 종류의 반례를 동시에 셀 수 있다."],
            answer_check=lambda values=row: _implication_counterexample_sum(*values),
        ))
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 중복 문자의 개수와 행렬 선형결합이다. 작동 원리는 인접 제한 배열과 결합계수·행렬식 문제를 각 5개 만든다."""
    specs: list[dict[str, Any]] = []
    permutation_rows = [(3, 2, 1), (3, 2, 2), (4, 3, 1), (3, 3, 2), (4, 2, 2)]
    for index, counts in enumerate(permutation_rows, 1):
        answer = _nonadjacent_multiset_permutations(counts)
        total = sum(counts)
        specs.append(_checked_problem(
            5,
            index,
            title=rf"서로 같은 문자 A가 {counts[0]}개, B가 {counts[1]}개, C가 {counts[2]}개 있다. 이 {total}개를 일렬로 모두 나열할 때 같은 문자가 서로 이웃하지 않는 서로 다른 문자열의 개수를 구하시오.",
            answer=str(answer),
            tags=["#중복순열", "#순열", "#경우의수", "#곱의법칙"],
            steps=[
                ("상태를 각 문자의 남은 개수와 직전에 놓인 문자로 정한다.", "같은 중복 문자는 서로 구별하지 않는다."),
                ("첫 자리에는 남아 있는 세 문자 중 하나를 고른다.", "선택한 문자의 남은 개수만 1 줄인다."),
                ("둘째 자리부터는 직전 문자와 다른 문자만 고른다.", "인접 금지 조건을 매 단계에서 적용한다."),
                ("남은 개수와 직전 문자가 같은 경우의 수는 한 번만 계산한다.", "중복 상태를 합치면 중복순열을 과대 계산하지 않는다."),
                ("모든 남은 개수가 0인 상태를 한 가지 완성으로 센다.", "도중에 선택할 문자가 없으면 0가지다."),
                ("가능한 첫 선택에서 시작한 완성 수를 모두 더한다.", rf"따라서 문자열은 ${answer}$개이다."),
            ],
            alternatives=[
                "가장 개수가 많은 문자를 먼저 배치하고 빈칸에 나머지 문자를 넣은 뒤 포함배제로 겹침을 조정할 수 있다.",
                "가능한 중복순열을 사전식으로 생성해 인접 문자가 다른 배열만 남겨 검산할 수 있다.",
            ],
            answer_check=lambda values=counts: _nonadjacent_multiset_permutations(values),
        ))

    matrix_rows = [
        ((1, 2, 0, 3), (2, -1, 1, 1), 2, -1),
        ((2, 0, -1, 1), (1, 3, 2, -2), -1, 2),
        ((1, -2, 3, 0), (2, 1, -1, 4), 3, 1),
        ((3, 1, 2, -1), (-1, 2, 0, 3), 1, -2),
        ((2, -1, 1, 2), (1, 2, -2, 1), -2, 3),
    ]
    for index, (first, second, parameter_p, parameter_q) in enumerate(matrix_rows, 6):
        result = tuple(parameter_p * a + parameter_q * b for a, b in zip(first, second))
        answer = _matrix_parameter_expression(first, second, result)
        specs.append(_checked_problem(
            5,
            index,
            title=rf"두 행렬 $A={_matrix_text(first)}$, $B={_matrix_text(second)}$와 실수 p,q가 $pA+qB={_matrix_text(result)}$를 만족한다. $(p-q)\det(A+B)$의 값을 구하시오.",
            answer=str(answer),
            tags=["#행렬의덧셈", "#행렬", "#행렬의연산", "#행렬을이용한연립방정식"],
            steps=[
                ("행렬 등식은 대응하는 각 성분이 같다는 뜻이다.", "독립인 두 성분을 골라 p,q의 일차방정식 두 개를 만든다."),
                ("두 일차방정식의 계수행렬식이 0이 아닌지 확인한다.", "0이 아닌 성분 쌍을 쓰면 두 계수가 유일하게 정해진다."),
                ("연립방정식을 풀어 p와 q를 구한다.", "나머지 두 성분에도 대입해 행렬 등식을 검산한다."),
                ("A+B를 성분별로 계산한다.", "같은 위치의 원소끼리 더한다."),
                ("2×2 행렬식 공식을 적용한다.", "$\det\begin{pmatrix}a&b\\c&d\end{pmatrix}=ad-bc$이다."),
                ("행렬식에 p-q를 곱한다.", rf"따라서 요구한 값은 ${answer}$이다."),
            ],
            alternatives=[
                "네 성분을 벡터로 펴서 두 벡터의 선형결합 계수를 가우스 소거로 구할 수 있다.",
                "독립인 두 성분에 크래머 공식을 적용한 뒤 나머지 성분으로 검산할 수 있다.",
            ],
            answer_check=lambda a=first, b=second, c=result: _matrix_parameter_expression(a, b, c),
        ))
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v52 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v52 전체 카탈로그다. 작동 원리는 독립 정답 검산 후 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog = build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v52 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(
        catalog,
        expected_count=50,
        batch_id=BATCH_ID,
        model_name=MODEL_NAME,
        codebase_base=CODEBASE_BASE,
        seed_base=SEED_BASE,
    )


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v52 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(db_path, quests=validated_quests(), batch_id=BATCH_ID, validate_only=validate_only)


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v52 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
