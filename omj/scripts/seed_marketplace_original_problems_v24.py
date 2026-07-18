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

BATCH_ID = "marketplace-original-v24"
MODEL_NAME = "aiflow-direct-authoring-v24"
CODEBASE_BASE = 20_260_985_000
SEED_BASE = 202_607_564_000


def _checked_problem(
    tier: int,
    index: int,
    *,
    answer_check: Callable[[], Any],
    **kwargs: Any,
) -> dict[str, Any]:
    """필요 변수는 문제 명세와 독립 계산 함수다. 작동 원리는 공통 검증기가 저장 답과 별도 계산 결과를 비교하도록 검산 함수를 부착한다."""
    spec = _problem(tier, index, **kwargs)
    spec["answer_check"] = answer_check
    return spec


def _matrix_product_component(
    left: tuple[tuple[int, int], tuple[int, int]],
    right: tuple[tuple[int, int], tuple[int, int]],
) -> int:
    """필요 변수는 곱셈 가능한 두 2행 2열 행렬이다. 작동 원리는 첫째 행과 첫째 열의 내적으로 곱행렬의 첫 성분을 구한다."""
    return left[0][0] * right[0][0] + left[0][1] * right[1][0]


def _reflected_point_sum(x: int, y: int) -> int:
    """필요 변수는 평면 위 점의 좌표다. 작동 원리는 y=x 대칭 후 원점대칭을 차례로 적용해 최종 좌표합을 구한다."""
    reflected_line = (y, x)
    reflected_origin = (-reflected_line[0], -reflected_line[1])
    return sum(reflected_origin)


def _event_union_intersection_total(sample_size: int, first_divisor: int, second_divisor: int) -> int:
    """필요 변수는 유한 표본공간 크기와 두 배수 조건이다. 작동 원리는 사건의 합집합과 교집합을 집합으로 만들어 두 원소 수를 더한다."""
    sample = set(range(1, sample_size + 1))
    first = {value for value in sample if value % first_divisor == 0}
    second = {value for value in sample if value % second_divisor == 0}
    return len(first | second) + len(first & second)


def _quadratic_origin_reflection_vertex_sum(vertex_x: int, vertex_y: int) -> int:
    """필요 변수는 포물선의 꼭짓점 좌표다. 작동 원리는 원점대칭으로 두 좌표의 부호를 바꿔 새 꼭짓점의 좌표합을 구한다."""
    return -vertex_x - vertex_y


def _radical_function_value(horizontal: int, vertical: int, step: int) -> int:
    """필요 변수는 무리함수의 이동량과 완전제곱 입력 간격이다. 작동 원리는 정의역 안의 값을 대입해 제곱근을 정확히 계산한다."""
    return step + vertical


def _hyperbola_value(horizontal: int, vertical: int, scale: int, offset: int) -> Fraction:
    """필요 변수는 평행이동된 쌍곡선의 중심·상수와 x방향 간격이다. 작동 원리는 표준형에 x를 대입해 y좌표를 계산한다."""
    if offset == 0:
        raise ValueError("쌍곡선의 점근선에서는 함수값이 정의되지 않습니다.")
    return Fraction(scale, offset) + vertical


def _inverse_product_entry_sum(a: int, b: int, c: int, d: int) -> Fraction:
    """필요 변수는 두 대각행렬의 대각 성분이다. 작동 원리는 곱의 역행렬 성질로 각 대각 곱의 역수를 더한다."""
    if 0 in {a, b, c, d}:
        raise ValueError("대각 성분은 0이 아니어야 합니다.")
    return Fraction(1, a * c) + Fraction(1, b * d)


def _ivt_midpoint_sum(start: int, signs: tuple[int, ...]) -> Fraction:
    """필요 변수는 연속함수 표의 시작 정수와 각 점의 부호다. 작동 원리는 부호가 바뀌는 단위구간 중점의 합을 구한다."""
    total = Fraction(0, 1)
    for offset in range(len(signs) - 1):
        if signs[offset] * signs[offset + 1] < 0:
            left = start + offset
            total += Fraction(2 * left + 1, 2)
    return total


def _removable_discontinuity_gap(point: int, assigned_value: int) -> int:
    """필요 변수는 약분 전 유리함수의 빠진 점과 현재 함수값이다. 작동 원리는 극한값 2a와 지정값의 차이를 절댓값으로 계산한다."""
    limit_value = 2 * point
    return abs(limit_value - assigned_value)


def _radical_equation_root_sum(shift: int, right_shift: int) -> int:
    """필요 변수는 방정식 sqrt(x+h)=x-k의 두 이동량이다. 작동 원리는 제곱방정식의 후보를 모두 구하고 원래 식으로 검산해 유효근만 더한다."""
    coefficient_b = -(2 * right_shift + 1)
    coefficient_c = right_shift**2 - shift
    discriminant = coefficient_b**2 - 4 * coefficient_c
    root_discriminant = math.isqrt(discriminant)
    if root_discriminant**2 != discriminant:
        raise ValueError("정수 후보근을 만들지 못했습니다.")
    candidates = {
        Fraction(-coefficient_b + root_discriminant, 2),
        Fraction(-coefficient_b - root_discriminant, 2),
    }
    valid: list[int] = []
    for candidate in candidates:
        if candidate.denominator != 1:
            continue
        value = candidate.numerator
        if value - right_shift >= 0 and value + shift == (value - right_shift) ** 2:
            valid.append(value)
    return sum(valid)


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 행렬과 평면 위 점이다. 작동 원리는 마지막 미사용 대수·대칭 태그를 다루는 난이도 1 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    matrix_rows = [
        (((1, 2), (3, 4)), ((5, 1), (2, 0))),
        (((-2, 3), (1, 5)), ((4, -1), (2, 6))),
        (((3, -1), (2, 7)), ((-2, 5), (4, 1))),
        (((5, 2), (-3, 4)), ((1, 6), (-2, 3))),
        (((-1, 4), (6, 2)), ((3, 0), (5, -2))),
    ]
    for index, (left, right) in enumerate(matrix_rows, 1):
        first_product = left[0][0] * right[0][0]
        second_product = left[0][1] * right[1][0]
        answer = _matrix_product_component(left, right)
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"행렬 $A=\begin{{pmatrix}}{left[0][0]}&{left[0][1]}\\{left[1][0]}&{left[1][1]}\end{{pmatrix}}$, $B=\begin{{pmatrix}}{right[0][0]}&{right[0][1]}\\{right[1][0]}&{right[1][1]}\end{{pmatrix}}$일 때, $AB$의 1행 1열 성분을 구하시오.",
                answer=str(answer),
                tags=["#행렬의곱셈", "#이"],
                steps=[
                    ("A의 첫째 행과 B의 첫째 열을 대응시킨다.", rf"대응 곱은 ${left[0][0]}({right[0][0]})$와 ${left[0][1]}({right[1][0]})$이다."),
                    ("두 대응 곱을 더한다.", rf"따라서 1행 1열 성분은 ${first_product}+({second_product})={answer}$이다."),
                ],
                answer_check=lambda first=left, second=right: _matrix_product_component(first, second),
            )
        )
    for index, (x, y) in enumerate([(2, 5), (-3, 4), (6, -1), (-2, -7), (8, 3)], 6):
        line_point = (y, x)
        final_point = (-y, -x)
        answer = _reflected_point_sum(x, y)
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"점 $P({x},{y})$를 직선 $y=x$에 대하여 대칭이동한 뒤 다시 원점에 대하여 대칭이동한 점의 두 좌표의 합을 구하시오.",
                answer=str(answer),
                tags=["#직선대칭", "#원점대칭"],
                steps=[
                    ("직선 y=x 대칭으로 두 좌표를 맞바꾼다.", rf"첫 대칭점은 $({line_point[0]},{line_point[1]})$이다."),
                    ("원점대칭으로 두 좌표의 부호를 바꾼다.", rf"최종 점은 $({final_point[0]},{final_point[1]})$이고 좌표합은 ${answer}$이다."),
                ],
                answer_check=lambda first=x, second=y: _reflected_point_sum(first, second),
            )
        )
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 배수 사건과 포물선의 꼭짓점이다. 작동 원리는 마지막 미사용 확률·대칭 태그를 다루는 난이도 2 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    event_rows = [(12, 2, 3), (15, 3, 5), (20, 4, 5), (18, 2, 6), (24, 3, 4)]
    for index, (sample_size, first_divisor, second_divisor) in enumerate(event_rows, 1):
        sample = set(range(1, sample_size + 1))
        first = {value for value in sample if value % first_divisor == 0}
        second = {value for value in sample if value % second_divisor == 0}
        union_count = len(first | second)
        intersection_count = len(first & second)
        answer = _event_union_intersection_total(sample_size, first_divisor, second_divisor)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"$1$부터 ${sample_size}$까지 적힌 카드 중 한 장을 고른다. 사건 $A$는 {first_divisor}의 배수, 사건 $B$는 {second_divisor}의 배수가 나오는 사건일 때, $|A\cup B|+|A\cap B|$를 구하시오.",
                answer=str(answer),
                tags=["#사건의합", "#사건의곱"],
                steps=[
                    ("두 사건의 원소를 각각 배수 조건으로 찾는다.", rf"$|A|={len(first)}$, $|B|={len(second)}$이다."),
                    ("합사건과 곱사건의 원소 수를 센다.", rf"$|A\cup B|={union_count}$, $|A\cap B|={intersection_count}$이다."),
                    ("두 원소 수를 더한다.", rf"따라서 $|A\cup B|+|A\cap B|={answer}$이다."),
                ],
                answer_check=lambda n=sample_size, p=first_divisor, q=second_divisor: _event_union_intersection_total(n, p, q),
            )
        )
    for index, (vertex_x, vertex_y) in enumerate([(2, 3), (-1, 5), (4, -2), (-3, -4), (5, 1)], 6):
        answer = _quadratic_origin_reflection_vertex_sum(vertex_x, vertex_y)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"포물선 $y=(x-({vertex_x}))^2+({vertex_y})$를 원점에 대하여 대칭이동했을 때, 이동한 포물선의 꼭짓점 좌표의 합을 구하시오.",
                answer=str(answer),
                tags=["#이차함수의대칭이동", "#포물선", "#원점대칭"],
                steps=[
                    ("원래 포물선의 꼭짓점을 읽는다.", rf"꼭짓점은 $({vertex_x},{vertex_y})$이다."),
                    ("원점대칭으로 꼭짓점 두 좌표의 부호를 바꾼다.", rf"새 꼭짓점은 $({-vertex_x},{-vertex_y})$이다."),
                    ("새 꼭짓점의 좌표를 더한다.", rf"따라서 좌표합은 ${answer}$이다."),
                ],
                answer_check=lambda h=vertex_x, k=vertex_y: _quadratic_origin_reflection_vertex_sum(h, k),
            )
        )
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 무리함수와 평행이동된 쌍곡선 조건이다. 작동 원리는 마지막 미사용 함수 태그를 다루는 난이도 3 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    radical_rows = [(1, 2, 3), (-2, 4, 2), (3, -1, 5), (0, 6, 4), (-4, 1, 6)]
    for index, (horizontal, vertical, step) in enumerate(radical_rows, 1):
        input_value = horizontal + step**2
        answer = _radical_function_value(horizontal, vertical, step)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"무리함수 $f(x)=\sqrt{{x-({horizontal})}}+({vertical})$에 대하여 $f({input_value})$의 값을 구하시오.",
                answer=str(answer),
                tags=["#무리식과무리함수"],
                steps=[
                    ("제곱근의 진수가 음이 아닌지 확인한다.", rf"${input_value}-({horizontal})={step**2}\ge0$이므로 정의된다."),
                    ("주어진 x값을 함수에 대입한다.", rf"$f({input_value})=\sqrt{{{step**2}}}+({vertical})$이다."),
                    ("주제곱근을 계산한다.", rf"$\sqrt{{{step**2}}}={step}$이다."),
                    ("세로 이동량을 더한다.", rf"따라서 $f({input_value})={step}+({vertical})={answer}$이다."),
                ],
                alternatives=["그래프의 시작점에서 오른쪽으로 완전제곱만큼 이동했을 때의 높이를 좌표로 읽을 수 있다."],
                answer_check=lambda h=horizontal, k=vertical, s=step: _radical_function_value(h, k, s),
            )
        )
    hyperbola_rows = [(1, 2, 6, 3), (-2, 4, 8, 2), (3, -1, -12, 4), (0, 5, 15, 3), (-3, -2, 18, 6)]
    for index, (horizontal, vertical, scale, offset) in enumerate(hyperbola_rows, 6):
        input_value = horizontal + offset
        answer = _hyperbola_value(horizontal, vertical, scale, offset)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"쌍곡선 $(x-({horizontal}))(y-({vertical}))={scale}$ 위에서 x좌표가 ${input_value}$인 점의 y좌표를 구하시오.",
                answer=str(answer),
                tags=["#쌍곡선"],
                steps=[
                    ("주어진 x좌표와 중심의 가로 차를 계산한다.", rf"$x-({horizontal})={offset}$이다."),
                    ("쌍곡선의 식에 x좌표를 대입한다.", rf"${offset}(y-({vertical}))={scale}$이다."),
                    ("양변을 가로 차로 나눈다.", rf"$y-({vertical})={Fraction(scale, offset)}$이다."),
                    ("중심의 y좌표를 더한다.", rf"따라서 y좌표는 ${answer}$이다."),
                ],
                alternatives=["표준형 $y=k+\dfrac{c}{x-h}$로 고친 뒤 x좌표를 직접 대입할 수 있다."],
                answer_check=lambda h=horizontal, k=vertical, c=scale, d=offset: _hyperbola_value(h, k, c, d),
            )
        )
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 가역 대각행렬과 연속함수의 부호표다. 작동 원리는 마지막 미사용 행렬·연속 태그를 다루는 난이도 4 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    inverse_rows = [(2, 3, 4, 5), (1, 2, 3, 4), (-2, 5, 3, -1), (4, -3, -2, 6), (5, 2, 1, -4)]
    for index, (a, b, c, d) in enumerate(inverse_rows, 1):
        answer = _inverse_product_entry_sum(a, b, c, d)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"대각행렬 $A=\begin{{pmatrix}}{a}&0\\0&{b}\end{{pmatrix}}$, $B=\begin{{pmatrix}}{c}&0\\0&{d}\end{{pmatrix}}$에 대하여 $(AB)^{{-1}}$의 모든 성분의 합을 구하시오.",
                answer=str(answer),
                tags=["#역행렬의성질", "#행렬의곱셈"],
                steps=[
                    ("두 행렬이 가역인지 확인한다.", "네 대각 성분이 모두 0이 아니므로 A와 B의 역행렬이 존재한다."),
                    ("행렬곱의 역행렬 성질을 적용한다.", r"$(AB)^{-1}=B^{-1}A^{-1}$이다."),
                    ("각 대각행렬의 역행렬을 구한다.", rf"대각 성분은 각각 $1/{a},1/{b}$와 $1/{c},1/{d}$이다."),
                    ("역행렬끼리 곱해 최종 대각 성분을 구한다.", rf"$(AB)^{{-1}}$의 대각 성분은 $1/{a * c}$, $1/{b * d}$이다."),
                    ("영이 아닌 두 성분을 더한다.", rf"따라서 모든 성분의 합은 ${answer}$이다."),
                ],
                alternatives=["먼저 AB를 계산한 뒤 그 대각행렬의 각 대각 성분을 역수로 바꿀 수 있다."],
                answer_check=lambda first=a, second=b, third=c, fourth=d: _inverse_product_entry_sum(first, second, third, fourth),
            )
        )
    ivt_rows = [
        (0, (1, -1, 1, 1, -1, 1)),
        (-2, (-1, 1, 1, -1, -1, 1)),
        (1, (1, 1, -1, 1, -1, -1)),
        (-1, (-1, 1, -1, -1, 1, -1)),
        (2, (1, -1, -1, 1, 1, -1)),
    ]
    for index, (start, signs) in enumerate(ivt_rows, 6):
        points = [start + offset for offset in range(len(signs))]
        answer = _ivt_midpoint_sum(start, signs)
        value_text = ", ".join(rf"f({point})={'1' if sign > 0 else '-1'}" for point, sign in zip(points, signs))
        change_intervals = [
            (points[offset], points[offset + 1])
            for offset in range(len(signs) - 1)
            if signs[offset] * signs[offset + 1] < 0
        ]
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"구간 $[{points[0]},{points[-1]}]$에서 연속인 함수 $f$가 ${value_text}$를 만족한다. 중간값정리로 영점이 보장되는 단위구간들의 중점의 합을 구하시오.",
                answer=str(answer),
                tags=["#중간값정리"],
                steps=[
                    ("연속성이 모든 단위구간에서 성립함을 확인한다.", "주어진 전체 구간에서 연속이므로 각 닫힌 단위구간에서도 연속이다."),
                    ("양 끝 함수값의 부호가 다른 구간을 찾는다.", rf"부호가 바뀌는 구간은 ${change_intervals}$이다."),
                    ("중간값정리를 각 부호 변화 구간에 적용한다.", "각 구간 내부에서 함수값이 0인 점이 적어도 하나 존재한다."),
                    ("해당 단위구간들의 중점을 계산한다.", "각 중점은 양 끝 좌표의 평균이다."),
                    ("모든 중점을 더한다.", rf"따라서 보장된 구간 중점의 합은 ${answer}$이다."),
                ],
                alternatives=["함수값의 부호를 수직선에 표시해 부호가 바뀌는 인접 점 사이만 선택할 수 있다."],
                answer_check=lambda first=start, values=signs: _ivt_midpoint_sum(first, values),
            )
        )
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 제거 가능한 불연속점과 무리방정식의 이동량이다. 작동 원리는 마지막 미사용 불연속 태그와 고난도 검산 유형을 다루는 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    discontinuity_rows = [(2, 1), (3, 8), (-2, 5), (4, -3), (-3, -10)]
    for index, (point, assigned) in enumerate(discontinuity_rows, 1):
        limit_value = 2 * point
        answer = _removable_discontinuity_gap(point, assigned)
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"함수 $f(x)=\begin{{cases}}\dfrac{{x^2-{point**2}}}{{x-({point})}}&(x\ne {point})\\{assigned}&(x={point})\end{{cases}}$의 불연속을 제거하려면 $f({point})$의 값을 바꾸어야 한다. 기존 값과 새 값의 차의 절댓값을 구하시오.",
                answer=str(answer),
                tags=["#불연속"],
                steps=[
                    ("x가 빠진 점과 다를 때 분자를 인수분해한다.", rf"$x^2-{point**2}=(x-{point})(x+{point})$이다."),
                    ("공통인수를 약분해 주변 함수식을 구한다.", rf"$x\ne {point}$에서 $f(x)=x+({point})$이다."),
                    ("빠진 점으로 가는 극한값을 계산한다.", rf"$\lim_{{x\to {point}}}f(x)={point}+({point})={limit_value}$이다."),
                    ("현재 함수값과 극한값을 비교한다.", rf"현재 $f({point})={assigned}$이므로 두 값이 달라 불연속이다."),
                    ("연속이 되도록 새 함수값을 결정한다.", rf"$f({point})$를 ${limit_value}$로 바꾸면 제거 가능한 불연속이 사라진다."),
                    ("기존 값과 새 값의 차를 계산한다.", rf"따라서 차의 절댓값은 $|{limit_value}-({assigned})|={answer}$이다."),
                ],
                alternatives=[
                    "그래프에서 직선 위의 뚫린 점과 별도로 지정된 점의 세로 거리를 계산할 수 있다.",
                    "연속의 정의인 함수값·좌극한·우극한의 일치를 직접 확인할 수 있다.",
                ],
                answer_check=lambda a=point, k=assigned: _removable_discontinuity_gap(a, k),
            )
        )
    radical_rows = [(17, 3), (26, 4), (6, 0), (7, -1), (37, 5)]
    for index, (shift, right_shift) in enumerate(radical_rows, 6):
        answer = _radical_equation_root_sum(shift, right_shift)
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"무리방정식 $\sqrt{{x+({shift})}}=x-({right_shift})$의 모든 실근의 합을 구하시오.",
                answer=str(answer),
                tags=["#무리식과무리함수"],
                steps=[
                    ("제곱하기 전 오른쪽 변의 부호 조건을 확인한다.", rf"제곱근은 음이 아니므로 $x\ge {right_shift}$이어야 한다."),
                    ("양변을 제곱해 이차방정식을 만든다.", rf"$x+({shift})=(x-({right_shift}))^2$이다."),
                    ("이차방정식을 표준형으로 정리한다.", rf"$x^2-{2 * right_shift + 1}x+({right_shift**2 - shift})=0$이다."),
                    ("인수분해 또는 근의 공식으로 후보근을 구한다.", "제곱 과정에서 무연근이 생길 수 있으므로 아직 후보로만 둔다."),
                    ("각 후보를 원래 무리방정식에 대입한다.", "부호 조건과 원식을 모두 만족하는 후보만 실근으로 채택한다."),
                    ("유효한 모든 실근을 더한다.", rf"따라서 모든 실근의 합은 ${answer}$이다."),
                ],
                alternatives=[
                    "제곱근 그래프와 직선 그래프의 교점을 그려 유효한 해의 개수를 먼저 판정할 수 있다.",
                    "제곱 후 얻은 두 근 중 오른쪽 변이 음수가 되는 근을 부호 조건으로 바로 제외할 수 있다.",
                ],
                answer_check=lambda h=shift, k=right_shift: _radical_equation_root_sum(h, k),
            )
        )
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v24 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v24 전체 카탈로그다. 작동 원리는 모든 정답 검산 함수를 실행한 뒤 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog = build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v24 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(catalog, expected_count=50, batch_id=BATCH_ID, model_name=MODEL_NAME, codebase_base=CODEBASE_BASE, seed_base=SEED_BASE)


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v24 전체 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(db_path, quests=validated_quests(), batch_id=BATCH_ID, validate_only=validate_only)


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v24 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
