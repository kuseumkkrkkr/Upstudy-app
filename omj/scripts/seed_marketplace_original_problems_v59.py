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

BATCH_ID = "marketplace-original-v59"
MODEL_NAME = "aiflow-direct-authoring-v59"
CODEBASE_BASE = 20_261_020_000
SEED_BASE = 202_607_599_000


def _checked_problem(tier: int, index: int, *, answer_check: Callable[[], Any], **kwargs: Any) -> dict[str, Any]:
    """필요 변수는 문제 명세와 독립 계산 함수다. 작동 원리는 저장 답과 별도 계산 결과를 비교하도록 검산 함수를 부착한다."""
    spec = _problem(tier, index, **kwargs)
    spec["answer_check"] = answer_check
    return spec


def _congruence_pair_count(first_size: int, second_size: int, modulus: int, residue: int) -> int:
    """필요 변수는 두 자연수 집합 크기와 합동식 조건이다. 작동 원리는 모든 순서쌍을 독립 순회해 x+2y의 나머지가 맞는 쌍을 센다."""
    return sum(
        (first + 2 * second) % modulus == residue % modulus
        for first in range(1, first_size + 1)
        for second in range(1, second_size + 1)
    )


def _imaginary_power_sum_stat(lower: int, upper: int) -> int:
    """필요 변수는 허수단위 거듭제곱 지수 범위다. 작동 원리는 4주기 성분을 더해 실수부에서 허수부를 뺀다."""
    cycle = ((1, 0), (0, 1), (-1, 0), (0, -1))
    real = 0
    imaginary = 0
    for exponent in range(lower, upper + 1):
        part = cycle[exponent % 4]
        real += part[0]
        imaginary += part[1]
    return real - imaginary


def _median_x_intercept(vertex: tuple[int, int], second: tuple[int, int], third: tuple[int, int]) -> Fraction:
    """필요 변수는 삼각형의 세 꼭짓점이다. 작동 원리는 맞은편 변의 중점을 구하고 꼭짓점과 이은 중선의 x절편을 계산한다."""
    middle_x = Fraction(second[0] + third[0], 2)
    middle_y = Fraction(second[1] + third[1], 2)
    dy = middle_y - vertex[1]
    if dy == 0:
        raise ValueError("x축과 평행하지 않은 중선이 필요합니다.")
    return Fraction(vertex[0]) - Fraction(vertex[1]) * (middle_x - vertex[0]) / dy


def _quadratic_root_product_from_gap(root_sum: int, root_gap: int) -> int:
    """필요 변수는 두 정수근의 합과 양의 차다. 작동 원리는 연립한 두 근을 복원해 곱한다."""
    if root_gap <= 0 or (root_sum + root_gap) % 2:
        raise ValueError("정수근을 만드는 합과 차가 필요합니다.")
    larger = (root_sum + root_gap) // 2
    smaller = (root_sum - root_gap) // 2
    return larger * smaller


def _geometric_even_odd_stat(first: int, pair_count: int, ratio: int) -> int:
    """필요 변수는 첫째항·항 쌍의 수·양의 공비다. 작동 원리는 홀수 번째 항의 등비합과 짝수 번째 합·마지막 항을 계산한다."""
    odd_sum = sum(first * ratio ** (2 * index) for index in range(pair_count))
    even_sum = ratio * odd_sum
    last = first * ratio ** (2 * pair_count - 1)
    return last + even_sum - odd_sum


def _integer_rational_values_sum(lower: int, upper: int, numerator_shift: int, denominator_shift: int) -> int:
    """필요 변수는 정수 범위와 일차분수의 두 상수다. 작동 원리는 정의되지 않는 점을 제외하고 함수값이 정수인 x의 합과 개수를 더한다."""
    values = []
    for number in range(lower, upper + 1):
        denominator = number + denominator_shift
        if denominator == 0:
            continue
        if (number + numerator_shift) % denominator == 0:
            values.append(number)
    return sum(values) + len(values)


def _repeated_linear_remainder_sum(coefficients: tuple[int, ...], point: int) -> int:
    """필요 변수는 다항식의 내림차순 계수와 반복근 점이다. 작동 원리는 P(a)와 P'(a)로 (x-a)² 나눗셈의 일차 나머지를 복원한다."""
    degree = len(coefficients) - 1
    value = sum(coefficient * point ** (degree - index) for index, coefficient in enumerate(coefficients))
    derivative = sum(
        coefficient * (degree - index) * point ** (degree - index - 1)
        for index, coefficient in enumerate(coefficients[:-1])
    )
    return value + (1 - point) * derivative


def _exactly_one_divisor_count(upper: int, divisors: tuple[int, int, int]) -> int:
    """필요 변수는 자연수 상한과 세 약수 조건이다. 작동 원리는 각 수가 세 배수 집합 중 정확히 하나에만 속하는지 전수 판정한다."""
    return sum(
        sum(number % divisor == 0 for divisor in divisors) == 1
        for number in range(1, upper + 1)
    )


def _cubic_tangent_enclosed_area(scale: int) -> Fraction:
    """필요 변수는 양의 정수 a다. 작동 원리는 삼차함수와 x=a 접선의 차를 인수분해해 두 교점 사이 넓이를 적분한다."""
    if scale <= 0:
        raise ValueError("양의 축척이 필요합니다.")
    return Fraction(27 * scale**4, 4)


def _integral_function_range(first_root: int, second_root: int, boundary: int) -> Fraction:
    """필요 변수는 도함수의 두 근과 정의구간 오른쪽 끝이다. 작동 원리는 적분함수의 양 끝점과 임계점 함수값을 비교해 최댓값과 최솟값 차를 구한다."""
    if not 0 < first_root < second_root < boundary:
        raise ValueError("0<첫째 근<둘째 근<오른쪽 끝 조건이 필요합니다.")

    def value(x: int) -> Fraction:
        return Fraction(x**3, 3) - Fraction(first_root + second_root, 2) * x**2 + first_root * second_root * x

    candidates = [value(0), value(first_root), value(second_root), value(boundary)]
    return max(candidates) - min(candidates)


def _polynomial_text(coefficients: tuple[int, ...]) -> str:
    """필요 변수는 내림차순 다항식 계수다. 작동 원리는 0 계수를 건너뛰고 문제 본문용 다항식 문자열을 만든다."""
    degree = len(coefficients) - 1
    terms: list[str] = []
    for index, coefficient in enumerate(coefficients):
        power = degree - index
        if coefficient == 0:
            continue
        variable = "" if power == 0 else ("x" if power == 1 else f"x^{power}")
        terms.append(f"({coefficient}){variable}" if variable else f"({coefficient})")
    return "+".join(terms)


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 유한 순서쌍과 허수단위 지수 범위다. 작동 원리는 나머지 조건 경우의 수와 복소수 주기합 문제를 각 5개 만든다."""
    specs: list[dict[str, Any]] = []
    pair_rows = [(4, 5, 3, 0), (5, 6, 4, 1), (6, 4, 5, 2), (7, 5, 3, 1), (6, 7, 4, 3)]
    for index, row in enumerate(pair_rows, 1):
        first_size, second_size, modulus, residue = row
        answer = _congruence_pair_count(*row)
        specs.append(_checked_problem(
            1, index,
            title=rf"$A=\{{1,2,\ldots,{first_size}\}}$, $B=\{{1,2,\ldots,{second_size}\}}$이다. $x\in A$, $y\in B$인 순서쌍 $(x,y)$ 중 $x+2y$를 {modulus}로 나눈 나머지가 {residue}인 것의 개수를 구하시오.",
            answer=str(answer), tags=["#경우의수", "#곱의법칙", "#합의법칙", "#조건제시법"],
            steps=[
                ("x를 하나 고정하고 가능한 y를 차례로 대입한다.", "나머지는 지정된 법으로만 비교한다."),
                ("각 x에서 조건을 만족한 y의 개수를 모두 더한다.", rf"따라서 순서쌍은 ${answer}$개이다."),
            ], answer_check=lambda values=row: _congruence_pair_count(*values),
        ))
    power_rows = [(1, 8), (2, 11), (3, 14), (5, 17), (7, 20)]
    for index, row in enumerate(power_rows, 6):
        lower, upper = row
        answer = _imaginary_power_sum_stat(*row)
        specs.append(_checked_problem(
            1, index,
            title=rf"복소수 $z=\sum_{{k={lower}}}^{{{upper}}}i^k$의 실수부를 a, 허수부를 b라 할 때, $a-b$를 구하시오.",
            answer=str(answer), tags=["#허수단위", "#복소수의연산", "#이", "#합의기호시그마"],
            steps=[
                ("허수단위의 거듭제곱이 네 항마다 반복됨을 확인한다.", "$1,i,-1,-i$의 순환이다."),
                ("범위의 완전한 네 항 묶음은 소거하고 남은 항의 실수부와 허수부를 계산한다.", rf"따라서 $a-b={answer}$이다."),
            ], answer_check=lambda values=row: _imaginary_power_sum_stat(*values),
        ))
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 삼각형 중선과 이차방정식 근의 합·차다. 작동 원리는 중선 절편과 두 근의 곱 문제를 각 5개 만든다."""
    specs: list[dict[str, Any]] = []
    triangle_rows = [((1, 4), (3, 0), (7, 2)), ((-2, 3), (2, -1), (6, 5)), ((3, 5), (-1, 1), (5, -3)), ((-3, -2), (1, 4), (7, 0)), ((2, 6), (-4, 2), (8, -2))]
    for index, row in enumerate(triangle_rows, 1):
        vertex, second, third = row
        answer = _median_x_intercept(*row)
        specs.append(_checked_problem(
            2, index,
            title=rf"삼각형의 세 꼭짓점이 $A{vertex}$, $B{second}$, $C{third}$이다. 꼭짓점 A에서 변 BC로 그은 중선의 x절편을 구하시오.",
            answer=str(answer), tags=["#중점", "#두점을지나는직선", "#직선의방정식", "#기울기", "#절편"],
            steps=[
                ("변 BC의 중점 M의 좌표를 구한다.", "두 끝점의 각 좌표 평균을 사용한다."),
                ("두 점 A와 M을 지나는 중선의 방정식을 세운다.", "점기울기형을 이용한다."),
                ("중선 식에 y=0을 대입해 x절편을 계산한다.", rf"따라서 x절편은 ${answer}$이다."),
            ], answer_check=lambda values=row: _median_x_intercept(*values),
        ))
    root_rows = [(7, 3), (-1, 5), (10, 4), (2, 8), (-6, 2)]
    for index, row in enumerate(root_rows, 6):
        root_sum, root_gap = row
        answer = _quadratic_root_product_from_gap(*row)
        specs.append(_checked_problem(
            2, index,
            title=rf"최고차항의 계수가 1인 이차방정식의 두 정수근의 합이 {root_sum}이고 큰 근과 작은 근의 차가 {root_gap}이다. 이 방정식의 상수항을 구하시오.",
            answer=str(answer), tags=["#이차방정식의근과계수", "#두근의합", "#두근의곱", "#판별식과근의개수"],
            steps=[
                ("큰 근과 작은 근을 각각 α, β로 놓고 합과 차의 연립방정식을 세운다.", "$α+β$와 $α-β$가 주어졌다."),
                ("두 식을 더하고 빼서 두 정수근을 구한다.", "합과 차의 홀짝이 같아 정수가 된다."),
                ("근과 계수의 관계로 상수항이 두 근의 곱임을 이용한다.", rf"따라서 상수항은 ${answer}$이다."),
            ], answer_check=lambda values=row: _quadratic_root_product_from_gap(*values),
        ))
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 등비수열의 홀짝항 합과 유리함수 정수값 범위다. 작동 원리는 공비 복원 합과 나눗셈 조건 문제를 각 5개 만든다."""
    specs: list[dict[str, Any]] = []
    geometric_rows = [(1, 3, 2), (2, 3, 3), (3, 4, 2), (1, 4, 3), (2, 5, 2)]
    for index, row in enumerate(geometric_rows, 1):
        first, pair_count, ratio = row
        answer = _geometric_even_odd_stat(*row)
        specs.append(_checked_problem(
            3, index,
            title=rf"첫째항이 {first}인 양의 등비수열 ${{a_n}}$에서 $a_2+a_4+\cdots+a_{{{2*pair_count}}}={ratio}(a_1+a_3+\cdots+a_{{{2*pair_count-1}}})$이다. $a_{{{2*pair_count}}}$과 두 합의 차를 더한 값을 구하시오.",
            answer=str(answer), tags=["#등비수열", "#등비수열의일반항", "#등비수열의합", "#공비", "#합의기호시그마"],
            steps=[
                ("각 짝수 번째 항이 바로 앞 홀수 번째 항의 공비 배임을 이용한다.", "두 합의 비가 곧 공비이다."),
                ("홀수 번째 항들만 모으면 공비의 제곱을 새 공비로 하는 등비수열이 된다.", "첫째항부터 지정된 개수만큼 더한다."),
                ("짝수 번째 합은 홀수 번째 합에 공비를 곱해 구한다.", "두 합의 차도 함께 계산한다."),
                ("일반항으로 마지막 짝수 번째 항을 구해 합의 차와 더한다.", rf"따라서 값은 ${answer}$이다."),
            ], alternatives=["처음부터 각 항을 직접 써서 홀수항 합과 짝수항 합을 따로 계산할 수 있다."],
            answer_check=lambda values=row: _geometric_even_odd_stat(*values),
        ))
    rational_rows = [(-8, 8, 5, 1), (-10, 10, -3, 2), (-12, 9, 7, -1), (-9, 12, 4, -2), (-15, 10, -5, 3)]
    for index, row in enumerate(rational_rows, 6):
        lower, upper, numerator_shift, denominator_shift = row
        answer = _integer_rational_values_sum(*row)
        specs.append(_checked_problem(
            3, index,
            title=rf"정수 ${lower}\le x\le {upper}$에서 유리식 $\dfrac{{x+({numerator_shift})}}{{x+({denominator_shift})}}$의 값이 정수인 모든 x의 합과 그러한 x의 개수를 더한 값을 구하시오.",
            answer=str(answer), tags=["#유리식과유리함수", "#유리식의계산", "#정의역", "#몫과나머지", "#대수"],
            steps=[
                ("분자에서 분모를 한 번 빼 상수 나머지가 있는 형태로 고친다.", "유리식은 1과 상수/분모의 합이 된다."),
                ("분모가 0이 되는 x를 정의역에서 제외한다.", "제외점은 정수값 후보가 아니다."),
                ("분모가 상수 나머지의 약수일 때만 함수값이 정수임을 이용한다.", "양의 약수와 음의 약수를 모두 확인한다."),
                ("범위 안의 x만 모아 합과 개수를 더한다.", rf"따라서 값은 ${answer}$이다."),
            ], alternatives=["주어진 정수 범위를 직접 순회하면서 분자와 분모의 나머지를 검사할 수 있다."],
            answer_check=lambda values=row: _integer_rational_values_sum(*values),
        ))
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 반복 일차인수 나머지와 세 배수 집합이다. 작동 원리는 함수값·도함수 나머지와 정확히 한 집합 원소 수 문제를 각 5개 만든다."""
    specs: list[dict[str, Any]] = []
    remainder_rows = [((1, -2, 3, 1), 1), ((2, 0, -1, 4), -1), ((1, 3, -2, 0, 5), 2), ((-1, 2, 1, -3, 2), -2), ((2, -1, 0, 3, -4), 1)]
    for index, row in enumerate(remainder_rows, 1):
        coefficients, point = row
        answer = _repeated_linear_remainder_sum(*row)
        specs.append(_checked_problem(
            4, index,
            title=rf"다항식 $P(x)={_polynomial_text(coefficients)}$를 $(x-({point}))^2$으로 나눈 나머지를 $mx+n$이라 할 때, $m+n$을 구하시오.",
            answer=str(answer), tags=["#나머지정리", "#인수정리활용", "#미정계수법", "#도함수", "#다항식의나눗셈"],
            steps=[
                ("나눗셈식을 $P(x)=(x-a)^2Q(x)+mx+n$으로 놓는다.", "a는 주어진 반복근이다."),
                ("x=a를 대입해 $ma+n=P(a)$를 얻는다.", "제곱인 나누는 식이 0이 된다."),
                ("나눗셈식을 미분한 뒤 다시 x=a를 대입한다.", "$(x-a)$를 가진 항은 모두 0이 되어 $m=P'(a)$이다."),
                ("P(a)와 P'(a)를 직접 계산한다.", "내림차순 계수의 차수를 확인한다."),
                ("m과 n을 복원해 더한다.", rf"따라서 $m+n={answer}$이다."),
            ], alternatives=["나머지를 미정계수로 놓고 조립제법을 같은 값에 두 번 적용할 수 있다."],
            answer_check=lambda values=row: _repeated_linear_remainder_sum(*values),
        ))
    divisor_rows = [(60, (2, 3, 5)), (72, (2, 3, 7)), (80, (3, 4, 5)), (90, (2, 5, 9)), (100, (4, 5, 6))]
    for index, row in enumerate(divisor_rows, 6):
        upper, divisors = row
        answer = _exactly_one_divisor_count(*row)
        specs.append(_checked_problem(
            4, index,
            title=rf"1부터 {upper}까지의 자연수 중 {divisors[0]}, {divisors[1]}, {divisors[2]}의 배수라는 세 조건 가운데 정확히 하나만 만족하는 자연수의 개수를 구하시오.",
            answer=str(answer), tags=["#합집합", "#교집합", "#여집합", "#경우의수", "#합의법칙"],
            steps=[
                ("세 배수 조건을 각각 집합 A,B,C로 둔다.", "각 집합의 원소 수는 몫으로 계산한다."),
                ("두 조건을 동시에 만족하는 수는 두 수의 공배수 조건으로 센다.", "최소공배수의 배수를 사용한다."),
                ("세 조건을 모두 만족하는 수도 따로 센다.", "세 수의 최소공배수가 기준이다."),
                ("각 단일 집합에서 다른 두 집합과 겹치는 원소를 제거한다.", "세 집합 공통 원소의 보정 횟수에 주의한다."),
                ("A만, B만, C만 만족하는 원소 수를 더한다.", rf"따라서 개수는 ${answer}$이다."),
            ], alternatives=["각 자연수에 대해 세 나눗셈 조건의 참 개수가 1인지 표로 검사할 수 있다."],
            answer_check=lambda values=row: _exactly_one_divisor_count(*values),
        ))
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 삼차함수 축척과 적분함수 도함수의 두 근이다. 작동 원리는 접선 사이 넓이와 적분함수 치역 길이 문제를 각 5개 만든다."""
    specs: list[dict[str, Any]] = []
    scales = [1, 2, 3, 4, 5]
    for index, scale in enumerate(scales, 1):
        answer = _cubic_tangent_enclosed_area(scale)
        specs.append(_checked_problem(
            5, index,
            title=rf"함수 $f(x)=x^3-3({scale})^2x$의 그래프 위에서 x좌표가 {scale}인 점에서의 접선과 함수 그래프가 둘러싸는 유한한 부분의 넓이를 구하시오.",
            answer=str(answer), tags=["#접선의방정식", "#접선의기울기", "#두곡선사이의넓이", "#정적분의계산", "#인수분해"],
            steps=[
                ("도함수로 x=a에서의 접선 기울기를 구한다.", "해당 점에서는 도함수 값이 0이다."),
                ("함수값을 계산해 수평인 접선 방정식을 세운다.", "접선은 y가 일정한 직선이다."),
                ("함수와 접선의 교점을 구하도록 두 식의 차를 인수분해한다.", "접점은 중근이고 다른 교점이 하나 더 있다."),
                ("두 교점 사이에서 함수와 접선의 위아래를 판정한다.", "인수분해한 차의 부호를 사용한다."),
                ("위 함수에서 아래 함수를 빼 정적분한다.", "중근 접점까지의 유한 영역만 계산한다."),
                ("적분값을 정리한다.", rf"따라서 넓이는 ${answer}$이다."),
            ], alternatives=[
                "x=a u로 치환해 모든 길이를 a배로 축척하고 표준 영역 넓이에 a⁴을 곱할 수 있다.",
                "인수분해된 높이 차 $(x-a)^2(x+2a)$를 바로 전개해 적분할 수 있다.",
            ], answer_check=lambda value=scale: _cubic_tangent_enclosed_area(value),
        ))
    range_rows = [(1, 3, 4), (1, 4, 5), (2, 4, 6), (1, 5, 6), (2, 5, 7)]
    for index, row in enumerate(range_rows, 6):
        first_root, second_root, boundary = row
        answer = _integral_function_range(*row)
        specs.append(_checked_problem(
            5, index,
            title=rf"함수 $F(x)=\int_0^x(t-{first_root})(t-{second_root})\,dt$의 정의역이 $0\le x\le {boundary}$일 때, F의 최댓값과 최솟값의 차를 구하시오.",
            answer=str(answer), tags=["#미적분의기본정리", "#함수의극대와극소", "#도함수의부호", "#최댓값", "#최솟값", "#정적분의성질"],
            steps=[
                ("미적분의 기본정리로 $F'(x)$를 구한다.", "적분의 윗끝이 x이므로 피적분함수가 도함수다."),
                ("도함수가 0인 두 임계점을 찾는다.", "두 점 모두 주어진 닫힌구간 안에 있다."),
                ("도함수 부호로 증가·감소 구간을 판정한다.", "위로 열린 이차식의 부호 변화를 사용한다."),
                ("F(x)의 식을 적분해 구간 양 끝점과 두 임계점에 대입한다.", "닫힌구간의 최댓값·최솟값은 네 후보를 비교한다."),
                ("네 함수값 중 가장 큰 값과 가장 작은 값을 고른다.", "국소 극값만 비교하고 끝점을 빠뜨리지 않는다."),
                ("최댓값에서 최솟값을 뺀다.", rf"따라서 차는 ${answer}$이다."),
            ], alternatives=[
                "F의 원시함수를 먼저 구한 뒤 도함수와 후보값 표를 한 번에 작성할 수 있다.",
                "도함수 부호표와 끝점 함수값을 그래프 개형에 표시해 전역 범위를 확인할 수 있다.",
            ], answer_check=lambda values=row: _integral_function_range(*values),
        ))
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v59 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v59 전체 카탈로그다. 작동 원리는 독립 정답 검산 후 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog = build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v59 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(
        catalog,
        expected_count=50,
        batch_id=BATCH_ID,
        model_name=MODEL_NAME,
        codebase_base=CODEBASE_BASE,
        seed_base=SEED_BASE,
    )


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v59 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(db_path, quests=validated_quests(), batch_id=BATCH_ID, validate_only=validate_only)


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v59 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
