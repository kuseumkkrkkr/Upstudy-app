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

BATCH_ID = "marketplace-original-v57"
MODEL_NAME = "aiflow-direct-authoring-v57"
CODEBASE_BASE = 20_261_018_000
SEED_BASE = 202_607_597_000


def _checked_problem(tier: int, index: int, *, answer_check: Callable[[], Any], **kwargs: Any) -> dict[str, Any]:
    """필요 변수는 문제 명세와 독립 계산 함수다. 작동 원리는 저장 답과 별도 계산 결과를 비교하도록 검산 함수를 부착한다."""
    spec = _problem(tier, index, **kwargs)
    spec["answer_check"] = answer_check
    return spec


def _complex_matrix_difference_imaginary_sum(first: tuple[tuple[int, int], ...], second: tuple[tuple[int, int], ...]) -> int:
    """필요 변수는 실수부·허수부 쌍으로 표현한 두 2×2 복소행렬이다. 작동 원리는 대응 성분을 빼고 모든 허수부를 더한다."""
    return sum(a[1] - b[1] for a, b in zip(first, second))


def _onto_three_letter_strings(length: int) -> int:
    """필요 변수는 문자열 길이다. 작동 원리는 세 문자를 모두 쓰는 중복순열을 포함배제로 계산한다."""
    if length < 3:
        raise ValueError("세 문자를 모두 사용할 수 있는 길이가 필요합니다.")
    return 3**length - 3 * 2**length + 3


def _reflected_external_point_sum(
    first: tuple[int, int], second: tuple[int, int], first_ratio: int, second_ratio: int
) -> Fraction:
    """필요 변수는 두 점과 외분비다. 작동 원리는 외분점 P를 구하고 선분 중점의 수직선에 대해 P를 대칭이동해 좌표합을 계산한다."""
    if first_ratio == second_ratio:
        raise ValueError("서로 다른 외분비가 필요합니다.")
    denominator = first_ratio - second_ratio
    point_x = Fraction(first_ratio * second[0] - second_ratio * first[0], denominator)
    point_y = Fraction(first_ratio * second[1] - second_ratio * first[1], denominator)
    middle_x = Fraction(first[0] + second[0], 2)
    reflected_x = 2 * middle_x - point_x
    return reflected_x + point_y


def _translated_quadratic_axis_min_sum(root_sum: int, root_product: int, horizontal: int, vertical: int) -> Fraction:
    """필요 변수는 이차방정식 근의 합·곱과 그래프 이동량이다. 작동 원리는 완전제곱으로 원래 축·최솟값을 구해 이동 후 두 값을 더한다."""
    original_axis = Fraction(root_sum, 2)
    original_minimum = root_product - Fraction(root_sum**2, 4)
    return original_axis + horizontal + original_minimum + vertical


def _rational_exponent_integer_sum(base_root: int, denominator: int, linear: int, constant: int, boundary: int, lower: int, upper: int) -> int:
    """필요 변수는 완전거듭제곱 밑·유리수 지수식·정수 범위다. 작동 원리는 증가성을 이용해 유리수 지수부등식의 정수해를 합한다."""
    base = base_root**denominator
    return sum(
        value for value in range(lower, upper + 1)
        if Fraction(linear * value + constant, denominator) < boundary
        and base > 1
    )


def _shifted_common_log_coordinate_sum(horizontal: int, vertical: int, power: int) -> int:
    """필요 변수는 상용로그 그래프 이동량과 로그값이다. 작동 원리는 수평선 교점 x좌표·점근선·치역 기준값을 더한다."""
    intersection_x = horizontal + 10**power
    asymptote_x = horizontal
    line_y = power + vertical
    return intersection_x + asymptote_x + line_y


def _logic_bidirectional_counterexamples(lower: int, upper: int, divisor: int, center: int, radius: int) -> int:
    """필요 변수는 정수 범위와 배수·절댓값 조건이다. 작동 원리는 p⇒q와 그 역의 반례를 합해 두 조건의 대칭차 크기를 구한다."""
    return sum(
        (value % divisor == 0) != (abs(value - center) <= radius)
        for value in range(lower, upper + 1)
    )


def _partial_fraction_square_sum(shift: int, upper: int) -> Fraction:
    """필요 변수는 부분분수 분모 간격과 합의 상한이다. 작동 원리는 유리항을 망원합으로 만들고 자연수 제곱합을 별도로 더한다."""
    return sum(
        (Fraction(1, value * (value + shift)) + value**2)
        for value in range(1, upper + 1)
    )


def _radical_linear_limit(linear: int, constant: int, point: int, root: int, added_linear: int) -> Fraction:
    """필요 변수는 근호 일차식·접근점·추가 일차항이다. 작동 원리는 근호 차를 유리화하고 합차 극한으로 추가항을 결합한다."""
    if linear * point + constant != root**2 or root <= 0:
        raise ValueError("접근점에서 지정한 양의 근호값을 갖는 자료가 필요합니다.")
    return Fraction(linear, 2 * root) + added_linear


def _position_gap_area_max_sum(axis: int, height: int) -> Fraction:
    """필요 변수는 두 위치함수 차의 축과 최대 높이다. 작동 원리는 [0,2a]에서 포물선 간격의 최댓값과 두 그래프 사이 넓이를 더한다."""
    if axis <= 0 or height < axis**2:
        raise ValueError("전 구간에서 음이 아닌 위치 차가 필요합니다.")
    area = 2 * axis * height - Fraction(2 * axis**3, 3)
    return height + area


def _complex_text(value: tuple[int, int]) -> str:
    """필요 변수는 복소수의 실수부·허수부다. 작동 원리는 문제 본문용 복소수 문자열로 변환한다."""
    return f"({value[0]})+({value[1]})i"


def _matrix_text(values: tuple[tuple[int, int], ...]) -> str:
    """필요 변수는 네 복소 성분이다. 작동 원리는 문제 본문용 2×2 LaTeX 행렬 문자열로 변환한다."""
    return rf"\begin{{pmatrix}}{_complex_text(values[0])}&{_complex_text(values[1])}\\{_complex_text(values[2])}&{_complex_text(values[3])}\end{{pmatrix}}"


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 복소행렬과 세 문자 문자열이다. 작동 원리는 행렬 뺄셈 허수부와 전사 중복순열 문제를 각 5개 만든다."""
    specs: list[dict[str, Any]] = []
    matrix_rows = [
        (((1, 2), (3, -1), (0, 4), (-2, 1)), ((2, -1), (1, 2), (3, 0), (1, -3))),
        (((2, 3), (-1, 4), (5, -2), (0, 1)), ((1, 1), (2, -3), (-1, 2), (4, 0))),
        (((-2, 1), (4, 2), (1, -3), (3, 5)), ((0, -2), (1, 1), (2, 4), (-1, 2))),
        (((3, -4), (2, 1), (-2, 3), (5, -1)), ((1, 2), (-3, 0), (4, -2), (2, 3))),
        (((4, 1), (-2, -3), (3, 2), (1, 4)), ((-1, 0), (2, 1), (0, -4), (3, 2))),
    ]
    for index, (first, second) in enumerate(matrix_rows, 1):
        answer = _complex_matrix_difference_imaginary_sum(first, second)
        specs.append(_checked_problem(
            1, index,
            title=rf"복소수 성분을 갖는 행렬 $A={_matrix_text(first)}$, $B={_matrix_text(second)}$에 대하여 행렬 $A-B$의 모든 성분의 허수부 합을 구하시오.",
            answer=str(answer), tags=["#행렬의뺄셈", "#행렬의정의", "#허수단위", "#복소수의연산"],
            steps=[
                ("행렬의 같은 위치에 있는 복소수 성분끼리 뺀다.", "실수부와 허수부를 각각 계산한다."),
                ("네 결과 성분의 허수부만 골라 더한다.", rf"따라서 허수부의 합은 ${answer}$이다."),
            ], answer_check=lambda a=first, b=second: _complex_matrix_difference_imaginary_sum(a, b),
        ))
    lengths = [4, 5, 6, 7, 8]
    for index, length in enumerate(lengths, 6):
        answer = _onto_three_letter_strings(length)
        specs.append(_checked_problem(
            1, index,
            title=rf"문자 A,B,C를 사용해 길이가 {length}인 문자열을 만들 때 세 문자를 모두 한 번 이상 사용하는 문자열의 개수를 구하시오.",
            answer=str(answer), tags=["#중복순열", "#중복조합", "#팩토리얼", "#경우의수", "#여집합"],
            steps=[
                ("세 문자 중복순열 전체에서 빠진 문자가 있는 경우를 포함배제로 센다.", "한 문자가 빠진 문자열과 두 문자가 빠진 문자열을 구분한다."),
                ("전체에서 빠진 문자 사건의 합을 빼고 겹쳐 뺀 경우를 보정한다.", rf"따라서 세 문자를 모두 쓰는 문자열은 ${answer}$개이다."),
            ], answer_check=lambda value=length: _onto_three_letter_strings(value),
        ))
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 외분점 대칭과 이차함수 이동이다. 작동 원리는 좌표 변환과 근·계수 완전제곱 문제를 각 5개 만든다."""
    specs: list[dict[str, Any]] = []
    point_rows = [((0, 2), (6, 8), 2, 1), ((-2, 4), (4, -2), 3, 1), ((1, -3), (9, 5), 3, 2), ((-4, 1), (6, 9), 4, 1), ((2, 6), (7, 1), 5, 2)]
    for index, row in enumerate(point_rows, 1):
        first, second, first_ratio, second_ratio = row
        answer = _reflected_external_point_sum(*row)
        specs.append(_checked_problem(
            2, index,
            title=rf"점 $A{first}$, $B{second}$를 ${first_ratio}:{second_ratio}$으로 외분하는 점을 P라 한다. 선분 AB의 중점을 M이라 할 때, P를 직선 $x=x_M$에 대칭이동한 점 Q의 좌표합을 구하시오.",
            answer=str(answer), tags=["#외분점", "#중점", "#중심", "#직선대칭", "#평행조건"],
            steps=[
                ("외분점 공식으로 P의 두 좌표를 구하고 중점 M의 x좌표를 계산한다.", "외분비의 차를 분모로 사용한다."),
                ("수직선 $x=x_M$ 대칭에서 y좌표는 유지되고 x좌표는 선 반대편으로 이동한다.", "대칭선이 PQ의 수직이등분선이다."),
                ("Q의 두 좌표를 더한다.", rf"따라서 좌표합은 ${answer}$이다."),
            ], answer_check=lambda values=row: _reflected_external_point_sum(*values),
        ))
    quadratic_rows = [(5, 6, 2, -1), (-3, -4, -2, 5), (2, -8, 3, 2), (7, 10, -1, -3), (-1, -12, 4, 1)]
    for index, row in enumerate(quadratic_rows, 6):
        root_sum, root_product, horizontal, vertical = row
        answer = _translated_quadratic_axis_min_sum(*row)
        specs.append(_checked_problem(
            2, index,
            title=rf"이차방정식 $x^2-({root_sum})x+({root_product})=0$과 같은 식을 함수로 본 그래프를 x방향으로 {horizontal}, y방향으로 {vertical}만큼 평행이동하였다. 새 그래프의 축의 x좌표와 최솟값의 합을 구하시오.",
            answer=str(answer), tags=["#이차방정식의근과계수", "#이차방정식의풀이", "#완전제곱식", "#이차함수의평행이동", "#축"],
            steps=[
                ("근과 계수 또는 완전제곱으로 원래 그래프의 축을 구한다.", "축은 두 근의 평균과 같다."),
                ("축에서의 원래 최솟값을 계산한다.", "제곱항이 0이 되는 값을 사용한다."),
                ("가로·세로 이동량을 각각 적용해 두 값을 더한다.", rf"따라서 합은 ${answer}$이다."),
            ], answer_check=lambda values=row: _translated_quadratic_axis_min_sum(*values),
        ))
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 유리수 지수부등식과 상용로그 이동이다. 작동 원리는 정수해 합과 로그 교점 좌표 문제를 각 5개 만든다."""
    specs: list[dict[str, Any]] = []
    exponent_rows = [(2, 3, 2, -1, 3, -5, 8), (3, 2, 1, 2, 4, -4, 9), (2, 4, 3, -2, 2, -6, 7), (5, 2, -1, 5, 1, -3, 10), (3, 3, 2, 1, 5, -7, 6)]
    for index, row in enumerate(exponent_rows, 1):
        answer = _rational_exponent_integer_sum(*row)
        root, denominator, linear, constant, boundary, lower, upper = row
        base = root**denominator
        specs.append(_checked_problem(
            3, index,
            title=rf"정수 ${lower}\le x\le {upper}$에서 $({base})^{{({linear}x+({constant}))/{denominator}}}<({base})^{boundary}$을 만족하는 모든 x의 합을 구하시오.",
            answer=str(answer), tags=["#유리수지수", "#정수지수", "#지수부등식", "#지수함수의성질", "#지수"],
            steps=[
                ("밑을 완전거듭제곱으로 확인해 유리수 지수를 해석한다.", "밑은 1보다 크므로 지수함수는 증가한다."),
                ("두 지수만 비교해 일차부등식을 푼다.", "분모가 양수이므로 부등호 방향이 유지된다."),
                ("주어진 정수 범위와 해 범위의 교집합을 구한다.", "엄격한 부등호 경계를 제외한다."),
                ("정수해를 모두 더한다.", rf"따라서 합은 ${answer}$이다."),
            ], alternatives=["지수함수 그래프의 증가성을 이용해 같은 지수 비교를 시각적으로 확인할 수 있다."],
            answer_check=lambda values=row: _rational_exponent_integer_sum(*values),
        ))
    log_rows = [(1, -2, 2), (-2, 3, 1), (3, 1, 2), (-3, -1, 1), (4, 2, 2)]
    for index, row in enumerate(log_rows, 6):
        horizontal, vertical, power = row
        answer = _shifted_common_log_coordinate_sum(*row)
        specs.append(_checked_problem(
            3, index,
            title=rf"상용로그함수 $y=\log(x-({horizontal}))+({vertical})$와 수평선 $y={power+vertical}$의 교점을 P라 한다. P의 x좌표, 수직점근선 x좌표, 수평선 y좌표를 모두 더하시오.",
            answer=str(answer), tags=["#상용로그", "#로그함수의평행이동", "#진수", "#치역", "#평행이동"],
            steps=[
                ("수평선 조건에서 세로 이동량을 빼 상용로그값을 구한다.", "상용로그의 밑은 10이다."),
                ("로그 정의로 진수를 10의 거듭제곱으로 바꾼다.", "진수는 양수여야 한다."),
                ("교점 x좌표와 수직점근선 좌표를 구한다.", "점근선은 진수가 0이 되는 직선이다."),
                ("두 x좌표와 수평선 y좌표를 더한다.", rf"따라서 합은 ${answer}$이다."),
            ], alternatives=["기본 상용로그 그래프의 기준점을 평행이동해 교점과 점근선을 찾을 수 있다."],
            answer_check=lambda values=row: _shifted_common_log_coordinate_sum(*values),
        ))
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 명제 조건과 부분분수·제곱합이다. 작동 원리는 양방향 반례 수와 혼합 시그마 합 문제를 각 5개 만든다."""
    specs: list[dict[str, Any]] = []
    logic_rows = [(-10, 12, 2, 1, 4), (-12, 15, 3, -2, 5), (-8, 20, 4, 3, 6), (-15, 10, 5, -1, 3), (-9, 18, 6, 2, 7)]
    for index, row in enumerate(logic_rows, 1):
        lower, upper, divisor, center, radius = row
        answer = _logic_bidirectional_counterexamples(*row)
        specs.append(_checked_problem(
            4, index,
            title=rf"정수 ${lower}\le x\le {upper}$에서 p는 ‘x가 {divisor}의 배수’, q는 ‘$|x-({center})|\le {radius}$’이다. $p\Rightarrow q$와 그 역 $q\Rightarrow p$의 반례 수의 합을 구하시오.",
            answer=str(answer), tags=["#대우", "#역", "#명제의역과대우", "#충분조건", "#필요조건", "#충분조건과필요조건"],
            steps=[
                ("p와 q를 만족하는 정수 집합 P,Q를 각각 구한다.", "범위의 양 끝을 포함한다."),
                ("p⇒q의 반례는 P-Q임을 확인한다.", "p는 참이고 q는 거짓인 원소다."),
                ("역 q⇒p의 반례는 Q-P임을 확인한다.", "역과 대우를 혼동하지 않는다."),
                ("두 차집합이 서로소임을 이용해 원소 수를 더한다.", "이는 대칭차의 크기다."),
                ("반례를 빠짐없이 세어 정리한다.", rf"따라서 합은 ${answer}$이다."),
            ], alternatives=["각 정수의 p,q 진리값 표를 만들어 두 방향 반례를 동시에 셀 수 있다."],
            answer_check=lambda values=row: _logic_bidirectional_counterexamples(*values),
        ))
    sum_rows = [(1, 5), (2, 6), (3, 7), (1, 8), (2, 9)]
    for index, row in enumerate(sum_rows, 6):
        shift, upper = row
        answer = _partial_fraction_square_sum(*row)
        specs.append(_checked_problem(
            4, index,
            title=rf"합 $\sum_{{k=1}}^{{{upper}}}\left(\dfrac1{{k(k+{shift})}}+k^2\right)$의 값을 구하시오.",
            answer=str(answer), tags=["#부분분수", "#자연수의거듭제곱의합", "#합의기호시그마", "#유리식의계산"],
            steps=[
                ("유리항을 두 일차분모의 부분분수로 분해한다.", "두 분수의 계수에 분모 간격이 반영된다."),
                ("부분분수 항을 k=1부터 상한까지 써 소거 구조를 확인한다.", "간격이 1보다 크면 앞뒤 몇 항만 남는다."),
                ("자연수 제곱합 공식을 별도로 적용한다.", "$\sum k^2=n(n+1)(2n+1)/6$이다."),
                ("망원합과 제곱합을 더한다.", "정수와 분수의 공통분모를 맞춘다."),
                ("기약분수로 정리한다.", rf"따라서 합은 ${answer}$이다."),
            ], alternatives=["유리항은 직접 공통분모를 확인하고 제곱합은 표준 공식을 귀납적으로 검산할 수 있다."],
            answer_check=lambda values=row: _partial_fraction_square_sum(*values),
        ))
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 근호 극한과 두 위치함수 차다. 작동 원리는 유리화 미분계수형 극한과 넓이·최대최소 문제를 각 5개 만든다."""
    specs: list[dict[str, Any]] = []
    limit_rows = [(2, 7, 1, 3, 4), (3, 7, 3, 4, -2), (4, 9, 4, 5, 3), (5, 11, 5, 6, -1), (6, 13, 6, 7, 2)]
    for index, row in enumerate(limit_rows, 1):
        linear, constant, point, root, added = row
        answer = _radical_linear_limit(*row)
        specs.append(_checked_problem(
            5, index,
            title=rf"극한 $\lim_{{x\to {point}}}\dfrac{{\sqrt{{{linear}x+({constant})}}-{root}+({added})(x-{point})}}{{x-{point}}}$의 값을 구하시오.",
            answer=str(answer), tags=["#유리화를이용한극한", "#상수배의미분", "#합차의미분", "#미분계수의정의", "#극한의사칙연산"],
            steps=[
                ("분자를 근호 차 항과 추가 일차항으로 나눈다.", "극한의 합차 법칙을 적용한다."),
                ("근호 차 항의 분자·분모에 켤레식을 곱한다.", "두 제곱의 차로 근호를 제거한다."),
                ("분자에서 x-접근점 인수를 찾아 약분한다.", "접근점과 근호값 조건을 사용한다."),
                ("약분한 근호 항에 접근점을 대입한다.", "켤레합은 지정 근호값의 두 배가 된다."),
                ("추가 일차항을 분모와 약분해 상수로 만든다.", "상수배 미분과 같은 결과다."),
                ("두 극한값을 더해 기약분수로 정리한다.", rf"따라서 값은 ${answer}$이다."),
            ], alternatives=[
                "근호함수와 일차함수 합의 미분계수로 해석해 도함수 값을 더할 수 있다.",
                "작은 증분 h로 치환해 차분몫을 직접 전개할 수 있다.",
            ], answer_check=lambda values=row: _radical_linear_limit(*values),
        ))
    gap_rows = [(2, 5), (3, 10), (4, 20), (5, 30), (6, 40)]
    for index, row in enumerate(gap_rows, 6):
        axis, height = row
        answer = _position_gap_area_max_sum(*row)
        specs.append(_checked_problem(
            5, index,
            title=rf"두 점의 위치함수 $s_1,s_2$가 $s_1(t)-s_2(t)={height}-(t-{axis})^2$을 만족한다. $0\le t\le {2*axis}$에서 두 위치함수 그래프 사이 넓이와 두 점 사이 거리의 최댓값의 합을 구하시오.",
            answer=str(answer), tags=["#위치함수", "#두곡선사이의넓이", "#최대최소문제", "#최댓값", "#최솟값", "#함수의증가와감소"],
            steps=[
                ("두 위치함수의 차가 전 구간에서 음이 아닌지 확인한다.", "따라서 그래프 위아래 순서가 바뀌지 않는다."),
                ("두 점 사이 거리는 위치 차의 절댓값임을 이용한다.", "현재는 위치 차 자체와 같다."),
                ("꼭짓점형에서 위치 차의 최댓값을 구한다.", "축 시각이 주어진 구간 안에 있다."),
                ("그래프 사이 넓이를 위치 차의 정적분으로 나타낸다.", "0부터 종료 시각까지 적분한다."),
                ("이차식을 적분해 양 끝점에 대입한다.", "대칭성을 이용해 계산을 줄일 수 있다."),
                ("넓이와 최대 거리를 더해 정리한다.", rf"따라서 합은 ${answer}$이다."),
            ], alternatives=[
                "위치 차 포물선의 대칭축을 기준으로 절반 넓이를 두 배할 수 있다.",
                "치환 u=t-a로 대칭구간의 짝함수 적분을 계산할 수 있다.",
            ], answer_check=lambda values=row: _position_gap_area_max_sum(*values),
        ))
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v57 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v57 전체 카탈로그다. 작동 원리는 독립 정답 검산 후 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog = build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v57 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(catalog, expected_count=50, batch_id=BATCH_ID, model_name=MODEL_NAME, codebase_base=CODEBASE_BASE, seed_base=SEED_BASE)


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v57 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(db_path, quests=validated_quests(), batch_id=BATCH_ID, validate_only=validate_only)


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v57 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
