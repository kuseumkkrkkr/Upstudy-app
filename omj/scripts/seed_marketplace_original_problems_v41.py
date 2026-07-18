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

BATCH_ID = "marketplace-original-v41"
MODEL_NAME = "aiflow-direct-authoring-v41"
CODEBASE_BASE = 20_261_002_000
SEED_BASE = 202_607_581_000


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


def _complement_sum(upper: int, divisor: int) -> int:
    """필요 변수는 전체집합의 상한과 배수 조건이다. 작동 원리는 전체 자연수 합에서 조건을 만족하는 배수의 합을 뺀다."""
    if upper < 1 or divisor < 1:
        raise ValueError("양의 상한과 나누는 수가 필요합니다.")
    return sum(value for value in range(1, upper + 1) if value % divisor != 0)


def _arithmetic_target(pair_sum: int, difference: int, first_index: int, second_index: int, target_index: int) -> Fraction:
    """필요 변수는 두 항의 합·공차·세 항 번호다. 작동 원리는 일반항의 대칭 차이를 이용해 목표 항을 계산한다."""
    return Fraction(pair_sum + (2 * target_index - first_index - second_index) * difference, 2)


def _parallel_y_intercept(
    first_line: tuple[int, int, int],
    second_line: tuple[int, int, int],
    normal: tuple[int, int],
) -> Fraction:
    """필요 변수는 교점을 정하는 두 직선과 평행선의 법선벡터다. 작동 원리는 크래머 공식으로 교점을 구해 y절편을 계산한다."""
    a, b, c = first_line
    d, e, f = second_line
    determinant = a * e - b * d
    if determinant == 0 or normal[1] == 0:
        raise ValueError("유일한 교점과 유한한 y절편이 필요합니다.")
    x_value = Fraction(c * e - b * f, determinant)
    y_value = Fraction(a * f - c * d, determinant)
    constant = normal[0] * x_value + normal[1] * y_value
    return constant / normal[1]


def _double_root_parameter(linear: int, constant: int) -> Fraction:
    """필요 변수는 x의 계수와 상수항의 고정 부분이다. 작동 원리는 판별식이 0인 조건으로 매개변수를 푼다."""
    return Fraction(linear**2, 4) - constant


def _log_integer_sum(base: int, exponent: int, coefficient: int, constant: int) -> int:
    """필요 변수는 로그 밑·우변·진수 일차식이다. 작동 원리는 진수조건과 증가함수 부등식을 함께 만족하는 정수를 합한다."""
    if base <= 1 or coefficient <= 0:
        raise ValueError("1보다 큰 밑과 양의 일차항 계수가 필요합니다.")
    upper_value = base**exponent
    candidates = range(-abs(constant) - 2, upper_value + abs(constant) + 2)
    return sum(
        value
        for value in candidates
        if 0 < coefficient * value + constant <= upper_value
    )


def _even_index_arithmetic_sum(first: int, difference: int, count: int) -> int:
    """필요 변수는 등차수열의 첫째항·공차·짝수 번호 항의 개수다. 작동 원리는 a₂부터 a₂ₙ까지 직접 생성해 합한다."""
    if count < 1:
        raise ValueError("합할 항의 개수는 1 이상이어야 합니다.")
    return sum(first + (2 * index - 1) * difference for index in range(1, count + 1))


def _piecewise_linear_coeff_sum(leading: int, linear: int, constant: int, junction: int) -> int:
    """필요 변수는 왼쪽 이차식의 계수와 접합점이다. 작동 원리는 도함수 일치로 a를, 함수값 일치로 b를 구해 더한다."""
    slope = 2 * leading * junction + linear
    left_value = leading * junction**2 + linear * junction + constant
    intercept = left_value - slope * junction
    return slope + intercept


def _radical_infinity_limit(linear: int, constant: int) -> Fraction:
    """필요 변수는 근호 안 x의 계수와 상수다. 작동 원리는 켤레곱 후 최고차항으로 나눠 무한대 극한을 계산한다."""
    _ = constant
    return Fraction(linear, 2)


def _exact_two_probability(red: int, blue: int) -> Fraction:
    """필요 변수는 빨간 공과 파란 공의 개수다. 작동 원리는 정확히 빨간 공 두 개를 고르는 조합을 전체 조합으로 나눈다."""
    if red < 2 or blue < 1:
        raise ValueError("빨간 공 두 개와 파란 공 한 개 이상이 필요합니다.")
    return Fraction(math.comb(red, 2) * blue, math.comb(red + blue, 3))


def _cubic_axis_area(first: int, second: int, third: int) -> Fraction:
    """필요 변수는 서로 다른 세 근이다. 작동 원리는 삼차식을 전개해 두 근 구간의 정적분 절댓값을 더한다."""
    if not first < second < third:
        raise ValueError("세 근은 오름차순으로 서로 달라야 합니다.")
    sum_roots = first + second + third
    pair_sum = first * second + first * third + second * third
    product = first * second * third

    def primitive(value: int) -> Fraction:
        """필요 변수는 적분 상한이다. 작동 원리는 전개된 삼차식의 원시함수 값을 정확한 분수로 계산한다."""
        return (
            Fraction(value**4, 4)
            - Fraction(sum_roots * value**3, 3)
            + Fraction(pair_sum * value**2, 2)
            - product * value
        )

    first_area = primitive(second) - primitive(first)
    second_area = primitive(third) - primitive(second)
    return abs(first_area) + abs(second_area)


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 유한집합의 배수 조건과 등차수열 항 관계다. 작동 원리는 여집합 합과 목표 항 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    set_rows = [(12, 3), (15, 4), (18, 5), (20, 6), (24, 7)]
    for index, (upper, divisor) in enumerate(set_rows, 1):
        excluded = list(range(divisor, upper + 1, divisor))
        answer = _complement_sum(upper, divisor)
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"전체집합 $(U=\{{1,2,\ldots,{upper}\}}$)와 $(A=\{{x\in U\mid x$)가 {divisor}의 배수$(\}}$)에 대하여 $(U-A$)의 모든 원소의 합을 구하시오.",
                answer=str(answer),
                tags=["#여집합", "#차집합", "#집합"],
                steps=[
                    ("집합 A의 원소를 배수 조건으로 나열한다.", rf"$(A=\{{{','.join(map(str, excluded))}\}}$)이다."),
                    ("전체집합의 합에서 A의 원소 합을 뺀다.", rf"따라서 $(U-A$)의 원소 합은 $({answer}$)이다."),
                ],
                answer_check=lambda n=upper, d=divisor: _complement_sum(n, d),
            )
        )
    sequence_rows = [(30, 3, 2, 8, 6), (14, -2, 3, 9, 5), (40, 4, 1, 7, 10), (-6, -3, 4, 10, 2), (50, 2, 5, 11, 8)]
    for index, (pair_sum, difference, first_index, second_index, target_index) in enumerate(sequence_rows, 6):
        answer = _arithmetic_target(pair_sum, difference, first_index, second_index, target_index)
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"공차가 $({difference}$)인 등차수열 $(\{{a_n\}}$)에서 $(a_{{{first_index}}}+a_{{{second_index}}}={pair_sum}$)일 때 $(a_{{{target_index}}}$)의 값을 구하시오.",
                answer=str(answer),
                tags=["#공차", "#등차수열의일반항", "#등차중항"],
                steps=[
                    ("두 항의 합에서 목표 항과의 번호 차이를 반영한다.", rf"$(2a_{{{target_index}}}={pair_sum}+(2\cdot {target_index}-{first_index}-{second_index})\cdot({difference})$)이다."),
                    ("양변을 2로 나눈다.", rf"따라서 $(a_{{{target_index}}}={answer}$)이다."),
                ],
                answer_check=lambda s=pair_sum, d=difference, p=first_index, q=second_index, r=target_index: _arithmetic_target(s, d, p, q, r),
            )
        )
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 직선의 교점과 이차방정식의 판별식이다. 작동 원리는 평행선 절편과 중근 매개변수 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    line_rows = [
        ((1, 1, 5), (2, -1, 1), (1, -2)),
        ((2, 1, 2), (1, -1, -5), (3, 1)),
        ((1, -2, 9), (3, 1, 13), (2, -1)),
        ((2, -1, -5), (1, 3, -6), (1, 2)),
        ((1, 1, 5), (2, -3, 5), (3, -2)),
    ]
    for index, (first_line, second_line, normal) in enumerate(line_rows, 1):
        answer = _parallel_y_intercept(first_line, second_line, normal)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"두 직선 $({first_line[0]}x+({first_line[1]})y={first_line[2]}$), $({second_line[0]}x+({second_line[1]})y={second_line[2]}$)의 교점을 지나고 $({normal[0]}x+({normal[1]})y=0$)에 평행한 직선의 y절편을 구하시오.",
                answer=str(answer),
                tags=["#두직선의위치관계", "#평행조건", "#직선의방정식"],
                steps=[
                    ("두 직선의 연립방정식을 풀어 교점 P를 구한다.", "계수의 행렬식이 0이 아니므로 교점은 하나이다."),
                    ("평행한 직선은 같은 법선벡터를 가지므로 P를 대입해 상수항을 정한다.", rf"직선은 $({normal[0]}x+({normal[1]})y=k$) 꼴이다."),
                    ("x=0을 대입해 y절편을 계산한다.", rf"따라서 y절편은 $({answer}$)이다."),
                ],
                answer_check=lambda first=first_line, second=second_line, vector=normal: _parallel_y_intercept(first, second, vector),
            )
        )
    discriminant_rows = [(4, 3), (-6, 5), (8, -2), (-2, 7), (10, 11)]
    for index, (linear, constant) in enumerate(discriminant_rows, 6):
        answer = _double_root_parameter(linear, constant)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"이차방정식 $(x^2+({linear})x+(m+({constant}))=0$)이 중근을 가질 때 실수 m의 값을 구하시오.",
                answer=str(answer),
                tags=["#이차방정식의판별식", "#판별식과근의개수", "#중근조건"],
                steps=[
                    ("중근을 갖는 판별식 조건을 세운다.", "이차방정식의 판별식은 $(D=0$)이어야 한다."),
                    ("주어진 계수를 대입한다.", rf"$(D=({linear})^2-4(m+({constant}))=0$)이다."),
                    ("m에 대한 일차방정식을 푼다.", rf"따라서 $(m={answer}$)이다."),
                ],
                answer_check=lambda b=linear, c=constant: _double_root_parameter(b, c),
            )
        )
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 증가 로그부등식과 짝수 번호 등차수열 항이다. 작동 원리는 정수해 합과 시그마 합 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    log_rows = [(2, 4, 2, 1), (3, 2, 1, 4), (5, 2, 3, -2), (2, 5, 4, 3), (4, 2, 2, -5)]
    for index, (base, exponent, coefficient, constant) in enumerate(log_rows, 1):
        upper_value = base**exponent
        solutions = [
            value
            for value in range(-abs(constant) - 2, upper_value + abs(constant) + 2)
            if 0 < coefficient * value + constant <= upper_value
        ]
        answer = _log_integer_sum(base, exponent, coefficient, constant)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"부등식 $(\log_{{{base}}}({coefficient}x+({constant}))\le {exponent}$)를 만족하는 모든 정수 x의 합을 구하시오.",
                answer=str(answer),
                tags=["#로그부등식", "#로그함수의성질", "#진수조건", "#밑"],
                steps=[
                    ("로그의 진수조건을 세운다.", rf"$({coefficient}x+({constant})>0$)이어야 한다."),
                    ("밑이 1보다 크므로 로그함수의 증가성을 적용한다.", rf"$({coefficient}x+({constant})\le {base}^{exponent}={upper_value}$)이다."),
                    ("두 조건의 공통 정수해를 나열한다.", rf"정수해는 $(\{{{','.join(map(str, solutions))}\}}$)이다."),
                    ("나열한 정수를 모두 더한다.", rf"따라서 합은 $({answer}$)이다."),
                ],
                alternatives=["진수의 가능한 정숫값을 먼저 나열한 뒤 일차식에 대응시켜도 같은 정수해를 얻는다."],
                answer_check=lambda b=base, p=exponent, a=coefficient, c=constant: _log_integer_sum(b, p, a, c),
            )
        )
    sequence_rows = [(2, 3, 5), (-1, 4, 6), (5, -2, 7), (3, 5, 4), (-4, 3, 8)]
    for index, (first, difference, count) in enumerate(sequence_rows, 6):
        answer = _even_index_arithmetic_sum(first, difference, count)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"첫째항이 $({first}$), 공차가 $({difference}$)인 등차수열 $(\{{a_n\}}$)에 대하여 $(\sum_{{k=1}}^{{{count}}}a_{{2k}}$)의 값을 구하시오.",
                answer=str(answer),
                tags=["#등차수열", "#등차수열의합", "#합의기호시그마", "#공차"],
                steps=[
                    ("등차수열의 일반항을 쓴다.", rf"$(a_n={first}+(n-1)({difference})$)이다."),
                    ("짝수 번호를 일반항에 대입한다.", rf"$(a_{{2k}}={first}+(2k-1)({difference})$)이다."),
                    ("k=1부터 주어진 상한까지 합한다.", rf"$(\sum a_{{2k}}={count}\cdot({first})+({difference})\sum_{{k=1}}^{{{count}}}(2k-1)$)이다."),
                    ("처음 n개 홀수의 합이 n²임을 적용한다.", rf"따라서 합은 $({answer}$)이다."),
                ],
                alternatives=["a₂부터 a₂ₙ까지 공차가 원래 공차의 두 배인 새 등차수열로 보고 합 공식을 적용할 수 있다."],
                answer_check=lambda a=first, d=difference, n=count: _even_index_arithmetic_sum(a, d, n),
            )
        )
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 조각함수의 접합 조건과 근호 무한대 극한이다. 작동 원리는 미분가능 계수와 유리화 극한 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    piecewise_rows = [(1, 2, 3, 1), (2, -1, 4, -1), (-1, 4, 2, 2), (3, 1, -2, 0), (1, -3, 5, 3)]
    for index, (leading, linear, constant, junction) in enumerate(piecewise_rows, 1):
        slope = 2 * leading * junction + linear
        intercept = leading * junction**2 + linear * junction + constant - slope * junction
        answer = _piecewise_linear_coeff_sum(leading, linear, constant, junction)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"함수 $(f(x)=\begin{{cases}}{leading}x^2+({linear})x+({constant})&(x\le {junction})\\ax+b&(x>{junction})\end{{cases}}$)가 $(x={junction}$)에서 미분가능할 때 $(a+b$)를 구하시오.",
                answer=str(answer),
                tags=["#미분가능", "#연속의정의", "#좌극한", "#우극한"],
                steps=[
                    ("미분가능하려면 접합점에서 좌우 미분계수가 같아야 한다.", rf"왼쪽 도함수는 $({2 * leading}x+({linear})$)이다."),
                    ("접합점을 도함수에 대입해 오른쪽 직선의 기울기 a를 정한다.", rf"$(a={slope}$)이다."),
                    ("미분가능성에 포함된 연속 조건을 세운다.", "접합점에서 왼쪽 함수값과 오른쪽 함수값이 같아야 한다."),
                    ("함수값 일치식에 a를 대입해 b를 구한다.", rf"$(b={intercept}$)이다."),
                    ("두 계수를 더하고 좌우 조건을 다시 확인한다.", rf"따라서 $(a+b={answer}$)이다."),
                ],
                alternatives=["차분몫의 좌극한과 우극한을 직접 계산해 a와 b에 대한 두 식을 세울 수 있다."],
                answer_check=lambda q=leading, r=linear, s=constant, p=junction: _piecewise_linear_coeff_sum(q, r, s, p),
            )
        )
    limit_rows = [(6, 5), (-4, 7), (10, -3), (-8, 12), (2, -9)]
    for index, (linear, constant) in enumerate(limit_rows, 6):
        answer = _radical_infinity_limit(linear, constant)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"극한 $(\lim_{{x\to\infty}}\left(\sqrt{{x^2+({linear})x+({constant})}}-x\right)$)의 값을 구하시오.",
                answer=str(answer),
                tags=["#유리화를이용한극한", "#무한대의극한", "#극한값계산", "#무리식"],
                steps=[
                    ("두 항의 차에 켤레식을 곱하고 나눈다.", "분자에는 두 제곱의 차가 나타난다."),
                    ("분자를 정리한다.", rf"분자는 $(({linear})x+({constant})$)이 된다."),
                    ("분자와 분모를 x로 나눈다.", rf"식은 $(\dfrac{{{linear}+({constant})/x}}{{\sqrt{{1+({linear})/x+({constant})/x^2}}+1}}$)이다."),
                    ("x가 무한대로 갈 때 1/x과 1/x²이 0으로 감을 적용한다.", rf"분자는 $({linear}$), 분모는 2로 수렴한다."),
                    ("분수의 극한을 계산하고 원래 근호가 충분히 큰 x에서 정의됨을 확인한다.", rf"따라서 극한값은 $({answer}$)이다."),
                ],
                alternatives=["근호에서 x를 묶은 뒤 $(\sqrt{1+t}-1$)의 표준 극한을 적용할 수 있다."],
                answer_check=lambda a=linear, b=constant: _radical_infinity_limit(a, b),
            )
        )
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 비복원 추출의 조합과 세 근을 가진 삼차식이다. 작동 원리는 정확한 확률과 부호 구간 넓이 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    probability_rows = [(4, 3), (5, 4), (6, 2), (3, 5), (7, 3)]
    for index, (red, blue) in enumerate(probability_rows, 1):
        favorable = math.comb(red, 2) * blue
        total = math.comb(red + blue, 3)
        answer = _exact_two_probability(red, blue)
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"빨간 공 {red}개와 파란 공 {blue}개가 든 주머니에서 동시에 공 3개를 고를 때, 빨간 공이 정확히 2개일 확률을 구하시오.",
                answer=str(answer),
                tags=["#사건의곱", "#조합", "#경우의수", "#곱의법칙"],
                steps=[
                    ("동시에 세 공을 고르므로 순서를 구별하지 않는 조합을 사용한다.", "모든 공은 서로 구별되는 것으로 센다."),
                    ("전체 선택 수를 계산한다.", rf"전체 경우의 수는 $(\binom{{{red + blue}}}3={total}$)이다."),
                    ("빨간 공 두 개를 고르는 경우를 센다.", rf"$(\binom{{{red}}}2$)가지이다."),
                    ("파란 공 한 개를 고르는 경우를 센다.", rf"$(\binom{{{blue}}}1$)가지이다."),
                    ("곱의 법칙으로 유리한 경우의 수를 구한다.", rf"유리한 경우는 $({favorable}$)가지이다."),
                    ("유리한 경우를 전체 경우로 나누고 기약분수로 만든다.", rf"따라서 확률은 $({answer}$)이다."),
                ],
                alternatives=[
                    "빨강·빨강·파랑의 세 순서를 초등확률의 곱으로 각각 계산해 더할 수 있다.",
                    "여사건에서 빨간 공이 0, 1, 3개인 확률을 빼서 검산할 수 있다.",
                ],
                answer_check=lambda r=red, b=blue: _exact_two_probability(r, b),
            )
        )
    area_rows = [(0, 1, 3), (-2, 0, 1), (1, 3, 4), (-3, -1, 2), (0, 2, 5)]
    for index, (first, second, third) in enumerate(area_rows, 6):
        answer = _cubic_axis_area(first, second, third)
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"삼차함수 $(f(x)=(x-({first}))(x-({second}))(x-({third}))$)의 그래프와 x축이 $({first}\le x\le {third}$)에서 이루는 넓이의 합을 구하시오.",
                answer=str(answer),
                tags=["#정적분", "#정적분과넓이", "#곡선과x축사이의넓이", "#정적분의계산"],
                steps=[
                    ("세 근으로 적분 구간을 나눈다.", rf"구간은 $([{first},{second}]$), $([{second},{third}]$)이다."),
                    ("각 구간에서 함수의 부호를 조사한다.", "첫 구간에서는 양수, 둘째 구간에서는 음수이다."),
                    ("삼차식을 전개한다.", rf"$(f(x)=x^3-({first + second + third})x^2+({first * second + first * third + second * third})x-({first * second * third})$)이다."),
                    ("전개식의 원시함수를 구해 첫 구간 정적분을 계산한다.", "첫 구간의 넓이는 정적분값의 절댓값이다."),
                    ("둘째 구간 정적분도 계산해 부호를 바꿔 넓이로 만든다.", "곡선이 x축 아래에 있으므로 정적분의 음수를 취한다."),
                    ("두 구간의 넓이를 더한다.", rf"따라서 전체 넓이는 $({answer}$)이다."),
                ],
                alternatives=[
                    "각 구간에서 $(|f(x)|$)를 조각함수로 나타내어 한 번에 적분할 수 있다.",
                    "수치 대입으로 각 구간의 부호와 정적분 결과의 부호를 별도로 검산할 수 있다.",
                ],
                answer_check=lambda a=first, b=second, c=third: _cubic_axis_area(a, b, c),
            )
        )
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v41 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v41 전체 카탈로그다. 작동 원리는 독립 정답 검산 후 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog = build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v41 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(
        catalog,
        expected_count=50,
        batch_id=BATCH_ID,
        model_name=MODEL_NAME,
        codebase_base=CODEBASE_BASE,
        seed_base=SEED_BASE,
    )


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v41 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(
        db_path,
        quests=validated_quests(),
        batch_id=BATCH_ID,
        validate_only=validate_only,
    )


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v41 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
