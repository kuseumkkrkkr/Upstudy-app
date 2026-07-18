from __future__ import annotations

import argparse
import json
import math
import sys
from collections import Counter
from fractions import Fraction
from pathlib import Path
from typing import Any, Callable

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.marketplace_problem_batch import seed_problem_batch, validate_problem_batch
from scripts.seed_initial_math_problems import _problem

BATCH_ID = "marketplace-original-v42"
MODEL_NAME = "aiflow-direct-authoring-v42"
CODEBASE_BASE = 20_261_003_000
SEED_BASE = 202_607_582_000


def _checked_problem(
    tier: int,
    index: int,
    *,
    answer_check: Callable[[], Any],
    **kwargs: Any,
) -> dict[str, Any]:
    """필요 변수는 문제 명세와 독립 계산 함수다. 작동 원리는 저장 답과 별도 계산 결과를 비교하도록 검산 함수를 부착한다."""
    spec = _problem(tier, index, **kwargs)
    spec["answer_check"] = answer_check
    return spec


def _polynomial_combination_value(first: tuple[int, int, int], second: tuple[int, int, int]) -> int:
    """필요 변수는 두 이차다항식의 계수다. 작동 원리는 합의 일차항 계수와 차의 상수항을 각각 계산해 더한다."""
    return first[1] + second[1] + first[2] - second[2]


def _exact_double_image_sum(codomain: tuple[int, ...], outputs: tuple[int, ...]) -> int:
    """필요 변수는 공역과 대응 결과다. 작동 원리는 각 공역 원소의 원상 개수를 세어 정확히 두 개인 원소만 합한다."""
    if any(value not in codomain for value in outputs):
        raise ValueError("모든 대응 결과는 공역에 속해야 합니다.")
    counts = Counter(outputs)
    return sum(value for value in codomain if counts[value] == 2)


def _reflected_parabola_coefficient_sum(leading: int, linear: int, constant: int) -> int:
    """필요 변수는 원래 이차함수의 세 계수다. 작동 원리는 x축 대칭 후 y축 대칭한 식 -f(-x)의 계수합을 구한다."""
    return -leading + linear - constant


def _geometric_target(product: int, ratio: int, first_index: int, second_index: int, target_index: int) -> int:
    """필요 변수는 두 항의 곱·공비·세 항 번호다. 작동 원리는 양의 등비중항을 구한 뒤 공비의 번호 차 거듭제곱을 곱한다."""
    if ratio <= 0 or (first_index + second_index) % 2:
        raise ValueError("양의 공비와 정수인 중간 항 번호가 필요합니다.")
    middle_value = math.isqrt(product)
    if middle_value**2 != product:
        raise ValueError("두 항의 곱은 완전제곱이어야 합니다.")
    middle_index = (first_index + second_index) // 2
    exponent = target_index - middle_index
    result = Fraction(middle_value) * Fraction(ratio) ** exponent
    if result.denominator != 1:
        raise ValueError("정수 답이 되도록 출제 변수를 정해야 합니다.")
    return result.numerator


def _changed_base_log_value(log_value: Fraction, base_power: int, argument_power: int) -> Fraction:
    """필요 변수는 log_a b와 새 밑·진수의 지수다. 작동 원리는 밑변환으로 지수 배율을 적용한다."""
    if base_power == 0:
        raise ValueError("새 로그의 밑 지수는 0일 수 없습니다.")
    return log_value * Fraction(argument_power, base_power)


def _quadratic_divisor_remainder_sum(
    first_root: int,
    second_root: int,
    first_value: int,
    second_value: int,
) -> Fraction:
    """필요 변수는 두 나눗셈 근과 그 점에서의 다항식값이다. 작동 원리는 일차 나머지 mx+n의 두 값을 연립해 m+n을 구한다."""
    if first_root == second_root:
        raise ValueError("서로 다른 두 근이 필요합니다.")
    slope = Fraction(second_value - first_value, second_root - first_root)
    intercept = first_value - slope * first_root
    return slope + intercept


def _scaled_power_difference_limit(point: int, scale: int, power: int) -> int:
    """필요 변수는 기준점·증분 배율·거듭제곱 차수다. 작동 원리는 미분계수 정의와 연쇄 배율로 극한을 계산한다."""
    if power < 1:
        raise ValueError("양의 거듭제곱 차수가 필요합니다.")
    return scale * power * point ** (power - 1)


def _cubic_extrema_gap(critical_point: int) -> int:
    """필요 변수는 양의 극값 위치 p다. 작동 원리는 x³-3p²x+c의 x=-p 극댓값과 x=p 극솟값 차를 계산한다."""
    if critical_point <= 0:
        raise ValueError("양의 극값 위치가 필요합니다.")
    return 4 * critical_point**3


def _circular_mixed_adjacency_count(people: int) -> int:
    """필요 변수는 서로 다른 사람 수다. 작동 원리는 CD 인접 원순열에서 AB도 인접한 경우를 포함배제로 뺀다."""
    if people < 4:
        raise ValueError("서로 다른 네 명을 포함해야 합니다.")
    cd_adjacent = 2 * math.factorial(people - 2)
    both_adjacent = 4 * math.factorial(people - 3)
    return cd_adjacent - both_adjacent


def _velocity_total_distance(first_zero: int, second_zero: int, end_time: int) -> Fraction:
    """필요 변수는 속도의 두 영점과 종료 시각이다. 작동 원리는 부호가 바뀌는 세 구간의 변위를 적분해 절댓값을 합한다."""
    if not 0 < first_zero < second_zero < end_time:
        raise ValueError("두 영점은 측정 구간 내부에서 오름차순이어야 합니다.")
    pair_sum = first_zero + second_zero
    product = first_zero * second_zero

    def primitive(time: int) -> Fraction:
        """필요 변수는 시각이다. 작동 원리는 v(t)=t²-(a+b)t+ab의 원시함수 값을 정확한 분수로 계산한다."""
        return Fraction(time**3, 3) - Fraction(pair_sum * time**2, 2) + product * time

    points = (0, first_zero, second_zero, end_time)
    return sum(abs(primitive(right) - primitive(left)) for left, right in zip(points, points[1:]))


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 다항식 계수와 유한함수 대응표다. 작동 원리는 합차 계수와 두 원상을 가진 공역 원소 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    polynomial_rows = [
        ((2, -3, 5), (1, 4, -2)),
        ((-1, 6, 3), (3, -2, 7)),
        ((4, 1, -5), (-2, 3, 6)),
        ((3, -7, 2), (5, 1, -4)),
        ((-2, 5, 8), (4, -6, 1)),
    ]
    for index, (first, second) in enumerate(polynomial_rows, 1):
        answer = _polynomial_combination_value(first, second)
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"$(P(x)={first[0]}x^2+({first[1]})x+({first[2]})$), $(Q(x)={second[0]}x^2+({second[1]})x+({second[2]})$)라 하자. $(P+Q$)의 x의 계수와 $(P-Q$)의 상수항의 합을 구하시오.",
                answer=str(answer),
                tags=["#다항식의덧셈", "#다항식의뺄셈", "#다항식"],
                steps=[
                    ("P+Q에서 같은 차수의 항을 더해 x의 계수를 구한다.", rf"x의 계수는 $({first[1]}+({second[1]})$)이다."),
                    ("P-Q의 상수항을 구한 뒤 두 결과를 더한다.", rf"따라서 요구한 합은 $({answer}$)이다."),
                ],
                answer_check=lambda p=first, q=second: _polynomial_combination_value(p, q),
            )
        )
    mapping_rows = [
        ((1, 2, 3, 4), (1, 2, 2, 3)),
        ((-2, -1, 0, 1, 2), (-2, 0, 0, 2, 2, 2)),
        ((3, 5, 7, 9), (3, 3, 5, 7, 7)),
        ((1, 4, 6, 8), (4, 4, 6, 6, 8)),
        ((-3, 0, 2, 5), (-3, 0, 0, 2, 2, 5, 5)),
    ]
    for index, (codomain, outputs) in enumerate(mapping_rows, 6):
        pairs = ", ".join(f"f({position})={value}" for position, value in enumerate(outputs, 1))
        answer = _exact_double_image_sum(codomain, outputs)
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"함수 $(f:\{{1,2,\ldots,{len(outputs)}\}}\to\{{{','.join(map(str, codomain))}\}}$)의 대응이 $({pairs}$)일 때, 원상을 정확히 2개 갖는 공역 원소의 합을 구하시오.",
                answer=str(answer),
                tags=["#공역", "#대응", "#함수", "#원소나열법"],
                steps=[
                    ("대응표에서 각 공역 원소가 함수값으로 나타나는 횟수를 센다.", "그 횟수가 해당 원소의 원상 개수이다."),
                    ("횟수가 정확히 2인 공역 원소만 골라 더한다.", rf"따라서 요구한 합은 $({answer}$)이다."),
                ],
                answer_check=lambda b=codomain, values=outputs: _exact_double_image_sum(b, values),
            )
        )
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 이차함수의 대칭이동과 양의 등비수열이다. 작동 원리는 변환된 계수합과 중항 기반 목표 항 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    reflection_rows = [(1, 2, -3), (2, -5, 4), (-1, 3, 6), (3, 1, -2), (-2, -4, 5)]
    for index, (leading, linear, constant) in enumerate(reflection_rows, 1):
        answer = _reflected_parabola_coefficient_sum(leading, linear, constant)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"이차함수 $(y={leading}x^2+({linear})x+({constant})$)의 그래프를 x축에 대칭이동한 뒤 다시 y축에 대칭이동하여 $(y=Ax^2+Bx+C$)를 얻었다. $(A+B+C$)를 구하시오.",
                answer=str(answer),
                tags=["#x축대칭", "#y축대칭", "#대칭이동", "#이차함수의대칭이동"],
                steps=[
                    ("x축 대칭이동은 함수값의 부호를 바꾸므로 식 전체에 -1을 곱한다.", "변환식은 $(y=-f(x)$)이다."),
                    ("이어서 y축 대칭이동은 x를 -x로 바꾼다.", "최종 식은 $(y=-f(-x)$)이다."),
                    ("최종 식의 세 계수를 더한다.", rf"따라서 $(A+B+C={answer}$)이다."),
                ],
                answer_check=lambda a=leading, b=linear, c=constant: _reflected_parabola_coefficient_sum(a, b, c),
            )
        )
    sequence_rows = [(81, 2, 2, 6, 5), (16, 3, 1, 7, 5), (100, 2, 3, 9, 7), (36, 3, 2, 8, 6), (64, 2, 4, 10, 8)]
    for index, (product, ratio, first_index, second_index, target_index) in enumerate(sequence_rows, 6):
        middle_index = (first_index + second_index) // 2
        middle_value = math.isqrt(product)
        answer = _geometric_target(product, ratio, first_index, second_index, target_index)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"모든 항이 양수이고 공비가 $({ratio}$)인 등비수열 $(\{{a_n\}}$)에서 $(a_{{{first_index}}}a_{{{second_index}}}={product}$)일 때 $(a_{{{target_index}}}$)의 값을 구하시오.",
                answer=str(answer),
                tags=["#등비수열", "#등비수열의일반항", "#등비중항", "#공비"],
                steps=[
                    ("두 항 번호의 평균에 있는 등비중항을 찾는다.", rf"중간 번호는 $({middle_index}$)이다."),
                    ("양의 항 조건을 이용해 중간 항을 곱의 양의 제곱근으로 구한다.", rf"$(a_{{{middle_index}}}=\sqrt{{{product}}}={middle_value}$)이다."),
                    ("중간 항에서 목표 항까지 공비를 필요한 횟수만큼 곱한다.", rf"따라서 $(a_{{{target_index}}}={answer}$)이다."),
                ],
                answer_check=lambda value=product, r=ratio, p=first_index, q=second_index, t=target_index: _geometric_target(value, r, p, q, t),
            )
        )
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 로그의 밑·진수 거듭제곱과 이차식 나눗셈의 일차 나머지다. 작동 원리는 밑변환과 두 점 연립 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    log_rows = [
        (Fraction(2, 3), 2, 3),
        (Fraction(3, 2), 4, 2),
        (Fraction(-1, 2), 3, 4),
        (Fraction(5, 3), 5, 2),
        (Fraction(4, 5), 2, 5),
    ]
    for index, (log_value, base_power, argument_power) in enumerate(log_rows, 1):
        answer = _changed_base_log_value(log_value, base_power, argument_power)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"양수 a, b에 대하여 $(a\ne1$), $(\log_a b={log_value}$)이다. $(\log_{{a^{base_power}}}(b^{argument_power})$)의 값을 구하시오.",
                answer=str(answer),
                tags=["#밑의변환", "#로그", "#로그의성질", "#로그함수"],
                steps=[
                    ("새 로그에 밑변환 공식을 적용한다.", rf"$(\log_{{a^{base_power}}}(b^{argument_power})=\dfrac{{\log_a(b^{argument_power})}}{{\log_a(a^{base_power})}}$)이다."),
                    ("진수와 밑의 거듭제곱을 로그 앞으로 내린다.", rf"값은 $(\dfrac{{{argument_power}}}{{{base_power}}}\log_a b$)이다."),
                    ("주어진 로그값을 대입한다.", rf"$(\dfrac{{{argument_power}}}{{{base_power}}}\cdot({log_value})$)이다."),
                    ("기약분수로 정리한다.", rf"따라서 값은 $({answer}$)이다."),
                ],
                alternatives=["$(a^u$)를 새 밑으로 보고 $(b^v$)를 그 밑의 지수로 직접 나타낼 수 있다."],
                answer_check=lambda value=log_value, u=base_power, v=argument_power: _changed_base_log_value(value, u, v),
            )
        )
    remainder_rows = [
        (-1, 2, 5, 11),
        (0, 3, -2, 7),
        (-2, 1, 8, -1),
        (1, 4, 6, 0),
        (-3, 2, -4, 16),
    ]
    for index, (first_root, second_root, first_value, second_value) in enumerate(remainder_rows, 6):
        slope = Fraction(second_value - first_value, second_root - first_root)
        intercept = first_value - slope * first_root
        answer = _quadratic_divisor_remainder_sum(first_root, second_root, first_value, second_value)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"다항식 P(x)가 $(P({first_root})={first_value}$), $(P({second_root})={second_value}$)를 만족한다. P(x)를 $((x-({first_root}))(x-({second_root}))$)로 나눈 나머지가 $(mx+n$)일 때 $(m+n$)을 구하시오.",
                answer=str(answer),
                tags=["#다항식의나눗셈", "#몫과나머지", "#나머지정리증명", "#인수정리"],
                steps=[
                    ("나눗셈 알고리즘으로 P=(이차식)Q+mx+n을 쓴다.", "이차식의 두 근을 대입하면 몫 부분이 0이 된다."),
                    ("x에 첫째 근을 대입해 m과 n의 첫 식을 얻는다.", rf"$({first_root}m+n={first_value}$)이다."),
                    ("둘째 근도 대입하고 두 식을 풀어 계수를 구한다.", rf"$(m={slope},\ n={intercept}$)이다."),
                    ("두 계수를 더한다.", rf"따라서 $(m+n={answer}$)이다."),
                ],
                alternatives=["두 점을 지나는 일차함수의 기울기와 절편으로 나머지를 바로 구할 수 있다."],
                answer_check=lambda a=first_root, b=second_root, u=first_value, v=second_value: _quadratic_divisor_remainder_sum(a, b, u, v),
            )
        )
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 거듭제곱 차분몫과 삼차함수의 두 극값이다. 작동 원리는 정의 기반 미분계수와 극댓값·극솟값 차 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    derivative_rows = [(2, 3, 4), (-1, 2, 5), (3, -2, 3), (-2, 3, 4), (1, 5, 6)]
    for index, (point, scale, power) in enumerate(derivative_rows, 1):
        answer = _scaled_power_difference_limit(point, scale, power)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"극한 $(\lim_{{h\to0}}\dfrac{{({point}+{scale}h)^{power}-({point})^{power}}}h$)의 값을 미분계수의 정의를 이용하여 구하시오.",
                answer=str(answer),
                tags=["#거듭제곱의미분", "#도함수의정의", "#미분계수의정의", "#상수배의미분"],
                steps=[
                    ("함수 $(g(x)=x^{power}$)의 차분몫과 비교한다.", "증분이 h가 아니라 주어진 배수의 h임을 확인한다."),
                    ("분모에도 같은 증분이 오도록 배율을 분리한다.", rf"원래 극한은 $({scale}g'({point})$)이다."),
                    ("거듭제곱 함수의 도함수를 정의에서 얻는다.", rf"$(g'(x)={power}x^{power - 1}$)이다."),
                    ("기준점을 대입한다.", rf"$(g'({point})={power}({point})^{power - 1}$)이다."),
                    ("증분 배율을 곱해 정리한다.", rf"따라서 극한값은 $({answer}$)이다."),
                ],
                alternatives=["이항정리로 분자를 전개하고 h가 없는 일차항만 남겨 직접 극한을 계산할 수 있다."],
                answer_check=lambda x=point, k=scale, n=power: _scaled_power_difference_limit(x, k, n),
            )
        )
    extrema_rows = [(1, 2), (2, -3), (3, 5), (4, 1), (5, -7)]
    for index, (critical_point, constant) in enumerate(extrema_rows, 6):
        answer = _cubic_extrema_gap(critical_point)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"함수 $(f(x)=x^3-3({critical_point})^2x+({constant})$)의 극댓값에서 극솟값을 뺀 값을 구하시오.",
                answer=str(answer),
                tags=["#함수의극대와극소", "#도함수의부호", "#극값의판정", "#극댓값", "#극솟값", "#미분과최대최소"],
                steps=[
                    ("도함수를 구하고 인수분해한다.", rf"$(f'(x)=3(x-{critical_point})(x+{critical_point})$)이다."),
                    ("도함수의 부호 변화를 조사한다.", rf"$(x=-{critical_point}$)에서 극대, $(x={critical_point}$)에서 극소이다."),
                    ("두 극값에 해당하는 함수값을 각각 계산한다.", "상수항은 두 함수값에 똑같이 포함된다."),
                    ("극댓값에서 극솟값을 빼며 상수항을 소거한다.", rf"차는 $(4\cdot {critical_point}^3$)이다."),
                    ("거듭제곱을 계산한다.", rf"따라서 요구한 값은 $({answer}$)이다."),
                ],
                alternatives=["삼차함수의 홀수차 부분만 비교해 $(f(-p)-f(p)$)를 바로 계산할 수 있다."],
                answer_check=lambda p=critical_point: _cubic_extrema_gap(p),
            )
        )
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 혼합 인접 조건 원순열과 부호가 바뀌는 속도다. 작동 원리는 포함배제 배열 수와 총 이동거리 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    for index, people in enumerate(range(6, 11), 1):
        cd_adjacent = 2 * math.factorial(people - 2)
        both_adjacent = 4 * math.factorial(people - 3)
        answer = _circular_mixed_adjacency_count(people)
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"A, B, C, D를 포함한 서로 다른 {people}명이 원탁에 앉는다. C와 D는 이웃하고 A와 B는 이웃하지 않게 앉는 경우의 수를 구하시오. 회전하여 같은 배치는 하나로 본다.",
                answer=str(answer),
                tags=["#원순열", "#순열", "#순열의수", "#경우의수", "#곱의법칙"],
                steps=[
                    ("먼저 C와 D를 하나의 묶음으로 본다.", rf"묶음을 포함한 대상은 $({people - 1}$)개이다."),
                    ("C와 D의 내부 순서를 반영해 C,D가 이웃한 원순열 수를 구한다.", rf"$(2({people - 2})!={cd_adjacent}$)이다."),
                    ("빼야 할 경우는 A,B도 동시에 이웃한 배치이다.", "A,B와 C,D를 각각 하나의 묶음으로 본다."),
                    ("두 묶음의 내부 순서와 원순열을 계산한다.", rf"두 쌍이 모두 이웃한 경우는 $(4({people - 3})!={both_adjacent}$)이다."),
                    ("C,D 인접 경우에서 두 쌍 모두 인접한 경우를 뺀다.", rf"$({cd_adjacent}-{both_adjacent}$)이다."),
                    ("회전 동치가 원순열 계수에 이미 반영되었음을 확인한다.", rf"따라서 경우의 수는 $({answer}$)이다."),
                ],
                alternatives=[
                    "C,D 묶음의 양옆 자리 중 A,B가 동시에 배치되는 경우를 직접 분류해 제외할 수 있다.",
                    "작은 인원수에서는 한 사람의 자리를 고정한 뒤 나머지 순열을 나열해 검산할 수 있다.",
                ],
                answer_check=lambda n=people: _circular_mixed_adjacency_count(n),
            )
        )
    motion_rows = [(1, 3, 5), (1, 4, 6), (2, 5, 7), (2, 4, 8), (3, 6, 9)]
    for index, (first_zero, second_zero, end_time) in enumerate(motion_rows, 6):
        answer = _velocity_total_distance(first_zero, second_zero, end_time)
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"수직선 위를 움직이는 점의 속도가 $(v(t)=(t-{first_zero})(t-{second_zero})$)이다. $(t=0$)부터 $(t={end_time}$)까지 점이 움직인 총거리를 구하시오.",
                answer=str(answer),
                tags=["#속도", "#속도와거리", "#위치변화량", "#정적분과속도", "#부정적분의정의"],
                steps=[
                    ("속도가 0이 되는 시각을 찾아 구간을 나눈다.", rf"방향이 바뀌는 시각은 $(t={first_zero}, {second_zero}$)이다."),
                    ("각 구간에서 속도의 부호를 조사한다.", "첫 구간은 양수, 가운데는 음수, 마지막은 양수이다."),
                    ("속도를 전개하고 원시함수를 구한다.", rf"$(v(t)=t^2-{first_zero + second_zero}t+{first_zero * second_zero}$)이다."),
                    ("$([0,{first_zero}]$)의 변위를 적분해 절댓값을 취한다.", "속도가 양수이므로 이 구간에서는 변위와 거리가 같다."),
                    ("나머지 두 구간도 적분하고 각 변위의 절댓값을 취한다.", "가운데 구간의 음의 변위는 부호를 바꿔 거리로 더한다."),
                    ("세 구간의 거리를 모두 합한다.", rf"따라서 총거리는 $({answer}$)이다."),
                ],
                alternatives=[
                    "위치함수의 극댓값·극솟값을 구해 연속한 위치 차의 절댓값을 합할 수 있다.",
                    "$(\int_0^T|v(t)|dt$)를 부호 구간별 조각적분으로 계산할 수 있다.",
                ],
                answer_check=lambda a=first_zero, b=second_zero, end=end_time: _velocity_total_distance(a, b, end),
            )
        )
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v42 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v42 전체 카탈로그다. 작동 원리는 독립 정답 검산 후 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog = build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v42 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(
        catalog,
        expected_count=50,
        batch_id=BATCH_ID,
        model_name=MODEL_NAME,
        codebase_base=CODEBASE_BASE,
        seed_base=SEED_BASE,
    )


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v42 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(
        db_path,
        quests=validated_quests(),
        batch_id=BATCH_ID,
        validate_only=validate_only,
    )


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v42 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
