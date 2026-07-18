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

BATCH_ID = "marketplace-original-v25"
MODEL_NAME = "aiflow-direct-authoring-v25"
CODEBASE_BASE = 20_260_986_000
SEED_BASE = 202_607_565_000


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


def _translated_line_y_intercept(slope: int, intercept: int, horizontal: int, vertical: int) -> int:
    """필요 변수는 직선 계수와 가로·세로 이동량이다. 작동 원리는 x를 x-h로 바꾸고 k를 더해 새 y절편을 구한다."""
    return -slope * horizontal + intercept + vertical


def _axis_reflection_sum(x: int, y: int) -> int:
    """필요 변수는 점의 두 좌표다. 작동 원리는 x축대칭과 y축대칭을 차례로 적용해 최종 좌표합을 구한다."""
    after_x_axis = (x, -y)
    after_y_axis = (-after_x_axis[0], after_x_axis[1])
    return sum(after_y_axis)


def _arithmetic_target(
    first_index: int,
    first_value: int,
    second_index: int,
    second_value: int,
    target_index: int,
) -> int:
    """필요 변수는 등차수열의 두 항과 목표 항 번호다. 작동 원리는 두 항의 차로 공차를 구해 목표 항을 계산한다."""
    interval = second_index - first_index
    difference = second_value - first_value
    if interval == 0 or difference % interval:
        raise ValueError("정수 공차를 만들 수 없습니다.")
    common_difference = difference // interval
    return first_value + (target_index - first_index) * common_difference


def _product_rule_choices(first: int, second: int, third: int) -> int:
    """필요 변수는 세 단계의 독립 선택 수다. 작동 원리는 곱의 법칙으로 모든 선택 순서의 수를 계산한다."""
    return first * second * third


def _monotone_exponential_integer_sum(
    mode: str,
    horizontal: int,
    threshold: int,
    lower: int,
    upper: int,
) -> int:
    """필요 변수는 지수함수 단조 유형·지수 이동·비교 지수·정수 구간이다. 작동 원리는 단조성으로 지수 부등식을 바꿔 해를 순회한다."""
    values = range(lower, upper + 1)
    if mode == "increasing":
        return sum(value for value in values if value + horizontal > threshold)
    if mode == "decreasing":
        return sum(value for value in values if value + horizontal < threshold)
    raise ValueError("지원하지 않는 단조 유형입니다.")


def _linear_system_sum(
    first: tuple[int, int, int],
    second: tuple[int, int, int],
) -> Fraction:
    """필요 변수는 두 일차방정식의 x·y·상수 계수다. 작동 원리는 행렬식에 기반한 소거 결과로 x+y를 정확히 구한다."""
    a, b, c = first
    d, e, f = second
    determinant = a * e - b * d
    if determinant == 0:
        raise ValueError("연립방정식의 해가 하나가 아닙니다.")
    x = Fraction(c * e - b * f, determinant)
    y = Fraction(a * f - c * d, determinant)
    return x + y


def _velocity_from_acceleration(coefficient: int, constant: int, initial_velocity: int, end_time: int) -> Fraction:
    """필요 변수는 일차 가속도 계수·초기속도·종료시각이다. 작동 원리는 가속도를 적분하고 초기조건을 적용해 속도를 구한다."""
    return Fraction(coefficient * end_time**2, 2) + constant * end_time + initial_velocity


def _power_derivative_value(coefficient: int, exponent: int, constant: int, point: int) -> int:
    """필요 변수는 거듭제곱함수 계수·지수·상수항·미분점이다. 작동 원리는 도함수 공식을 독립 적용해 미분계수를 계산한다."""
    return coefficient * exponent * point ** (exponent - 1)


def _complex_quotient_component_sum(
    numerator: tuple[int, int],
    denominator: tuple[int, int],
) -> Fraction:
    """필요 변수는 분자·분모 복소수의 실수부와 허수부다. 작동 원리는 분모의 켤레복소수를 곱해 실수부와 허수부의 합을 구한다."""
    a, b = numerator
    c, d = denominator
    norm = c**2 + d**2
    if norm == 0:
        raise ValueError("0인 복소수로 나눌 수 없습니다.")
    real = Fraction(a * c + b * d, norm)
    imaginary = Fraction(b * c - a * d, norm)
    return real + imaginary


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 이동할 직선과 두 축에 대칭할 점이다. 작동 원리는 저사용 좌표 태그를 보강하는 난이도 1 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    line_rows = [(2, 3, 1, 4), (-1, 5, 3, -2), (4, -3, -2, 1), (-3, 2, 2, 5), (5, 1, -1, -4)]
    for index, (slope, intercept, horizontal, vertical) in enumerate(line_rows, 1):
        answer = _translated_line_y_intercept(slope, intercept, horizontal, vertical)
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"직선 $y={slope}x+({intercept})$를 x방향으로 ${horizontal}$, y방향으로 ${vertical}$만큼 평행이동한 직선의 y절편을 구하시오.",
                answer=str(answer),
                tags=["#x방향이동", "#y절편", "#평행이동"],
                steps=[
                    ("가로·세로 이동을 직선의 식에 반영한다.", rf"이동한 식은 $y={slope}(x-({horizontal}))+({intercept})+({vertical})$이다."),
                    ("x=0을 대입해 y절편을 계산한다.", rf"따라서 y절편은 ${answer}$이다."),
                ],
                answer_check=lambda m=slope, b=intercept, h=horizontal, k=vertical: _translated_line_y_intercept(m, b, h, k),
            )
        )
    for index, (x, y) in enumerate([(3, 5), (-2, 7), (6, -4), (-5, -1), (8, 2)], 6):
        first_point = (x, -y)
        final_point = (-x, -y)
        answer = _axis_reflection_sum(x, y)
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"점 $P({x},{y})$를 x축에 대하여 대칭이동한 뒤 y축에 대하여 대칭이동한 점의 두 좌표의 합을 구하시오.",
                answer=str(answer),
                tags=["#x축대칭", "#y축대칭", "#대칭이동"],
                steps=[
                    ("x축대칭으로 y좌표의 부호를 바꾼다.", rf"첫 대칭점은 $({first_point[0]},{first_point[1]})$이다."),
                    ("y축대칭으로 x좌표의 부호를 바꾸고 더한다.", rf"최종 점은 $({final_point[0]},{final_point[1]})$이므로 좌표합은 ${answer}$이다."),
                ],
                answer_check=lambda first=x, second=y: _axis_reflection_sum(first, second),
            )
        )
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 등차수열의 두 항과 세 단계 선택 수다. 작동 원리는 저사용 수열·경우의 수 태그를 보강하는 난이도 2 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    arithmetic_rows = [
        (2, 7, 5, 16, 8),
        (3, -1, 7, 7, 10),
        (1, 5, 4, -1, 7),
        (4, 10, 9, 30, 2),
        (5, -3, 8, 12, 11),
    ]
    for index, (p, first_value, q, second_value, target) in enumerate(arithmetic_rows, 1):
        difference = (second_value - first_value) // (q - p)
        answer = _arithmetic_target(p, first_value, q, second_value, target)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"등차수열 $\{{a_n\}}$에서 $a_{p}={first_value}$, $a_{q}={second_value}$일 때, $a_{target}$의 값을 구하시오.",
                answer=str(answer),
                tags=["#공차", "#등차수열의일반항", "#등차중항"],
                steps=[
                    ("두 항의 차를 항 번호의 차로 나누어 공차를 구한다.", rf"공차는 $d=\dfrac{{{second_value}-({first_value})}}{{{q}-{p}}}={difference}$이다."),
                    ("한 기준 항에서 목표 항까지 공차를 누적한다.", rf"$a_{target}=a_{p}+({target}-{p})d$이다."),
                    ("값을 대입해 목표 항을 계산한다.", rf"따라서 $a_{target}={answer}$이다."),
                ],
                answer_check=lambda i=p, u=first_value, j=q, v=second_value, n=target: _arithmetic_target(i, u, j, v, n),
            )
        )
    for index, (first, second, third) in enumerate([(3, 4, 5), (2, 6, 7), (5, 3, 8), (4, 7, 2), (6, 5, 3)], 6):
        answer = _product_rule_choices(first, second, third)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"서로 독립인 세 단계 선택에서 첫 단계는 ${first}$가지, 둘째 단계는 ${second}$가지, 셋째 단계는 ${third}$가지 방법이 있다. 전체 선택 순서의 수를 구하시오.",
                answer=str(answer),
                tags=["#곱의법칙"],
                steps=[
                    ("각 단계의 선택이 서로 독립임을 확인한다.", "앞 단계의 선택과 관계없이 다음 단계의 모든 선택이 가능하다."),
                    ("곱의 법칙으로 단계별 경우의 수를 곱한다.", rf"전체 수는 ${first}\cdot {second}\cdot {third}$이다."),
                    ("곱을 계산한다.", rf"따라서 전체 선택 순서는 ${answer}$가지이다."),
                ],
                answer_check=lambda a=first, b=second, c=third: _product_rule_choices(a, b, c),
            )
        )
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 증가·감소 지수함수와 제한 정수 구간이다. 작동 원리는 최저 사용 태그 두 종류를 균형 보강하는 난이도 3 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    increasing_rows = [(2, 1, 4, -2, 7), (3, -1, 3, -4, 6), (5, 2, 6, -1, 8), (4, 0, 2, -3, 5), (6, -2, 1, -5, 4)]
    for index, (base, horizontal, threshold, lower, upper) in enumerate(increasing_rows, 1):
        answer = _monotone_exponential_integer_sum("increasing", horizontal, threshold, lower, upper)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"증가함수 $f(x)={base}^{{x+({horizontal})}}$에 대하여 $f(x)>{base}^{threshold}$를 만족하는 구간 ${lower}\le x\le {upper}$의 모든 정수 $x$의 합을 구하시오.",
                answer=str(answer),
                tags=["#증가함수", "#함수의증가와감소", "#지수함수의성질"],
                steps=[
                    ("밑이 1보다 커 함수가 증가함을 확인한다.", rf"${base}>1$이므로 지수의 대소관계가 함수값에 그대로 반영된다."),
                    ("함수값 부등식을 지수 부등식으로 바꾼다.", rf"$x+({horizontal})>{threshold}$이다."),
                    ("주어진 닫힌구간과 지수 부등식을 함께 만족하는 정수를 찾는다.", rf"정수 후보는 $[{lower},{upper}]$ 안에서 고른다."),
                    ("조건을 만족하는 정수를 모두 더한다.", rf"따라서 정수 해의 합은 ${answer}$이다."),
                ],
                alternatives=["구간의 각 정수에서 지수만 비교해 함수값을 직접 계산하지 않고 선별할 수 있다."],
                answer_check=lambda h=horizontal, t=threshold, left=lower, right=upper: _monotone_exponential_integer_sum("increasing", h, t, left, right),
            )
        )
    decreasing_rows = [(2, 1, 4, -2, 7), (3, -1, 3, -4, 6), (5, 2, 6, -1, 8), (4, 0, 2, -3, 5), (6, -2, 1, -5, 4)]
    for index, (base, horizontal, threshold, lower, upper) in enumerate(decreasing_rows, 6):
        answer = _monotone_exponential_integer_sum("decreasing", horizontal, threshold, lower, upper)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"감소함수 $g(x)=(\dfrac1{{{base}}})^{{x+({horizontal})}}$에 대하여 $g(x)>(\dfrac1{{{base}}})^{threshold}$를 만족하는 구간 ${lower}\le x\le {upper}$의 모든 정수 $x$의 합을 구하시오.",
                answer=str(answer),
                tags=["#감소함수", "#함수의증가와감소", "#지수함수의성질"],
                steps=[
                    ("밑이 0과 1 사이여서 함수가 감소함을 확인한다.", rf"$0<1/{base}<1$이므로 지수가 커질수록 함수값은 작아진다."),
                    ("함수값 부등식을 반대 방향의 지수 부등식으로 바꾼다.", rf"$x+({horizontal})<{threshold}$이다."),
                    ("주어진 닫힌구간과 지수 부등식을 함께 만족하는 정수를 찾는다.", rf"정수 후보는 $[{lower},{upper}]$ 안에서 고른다."),
                    ("조건을 만족하는 정수를 모두 더한다.", rf"따라서 정수 해의 합은 ${answer}$이다."),
                ],
                alternatives=["감소함수 그래프에서 기준 함수값보다 위쪽에 놓이는 x구간을 먼저 읽을 수 있다."],
                answer_check=lambda h=horizontal, t=threshold, left=lower, right=upper: _monotone_exponential_integer_sum("decreasing", h, t, left, right),
            )
        )
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 연립방정식 계수와 일차 가속도 조건이다. 작동 원리는 저사용 선형대수·운동 태그를 보강하는 난이도 4 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    system_rows: list[tuple[tuple[int, int, int], tuple[int, int, int]]] = []
    system_sources = [(2, 1, 1, -1, 3, 2), (3, -2, 1, 4, -1, 5), (1, 3, -2, 2, 4, -1), (4, 1, 2, -3, 1, 6), (2, -5, -1, 3, -2, 4)]
    for a, b, d, e, root_x, root_y in system_sources:
        system_rows.append(((a, b, a * root_x + b * root_y), (d, e, d * root_x + e * root_y)))
    for index, (first, second) in enumerate(system_rows, 1):
        answer = _linear_system_sum(first, second)
        a, b, c = first
        d, e, f = second
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"연립일차방정식 $\begin{{cases}}{a}x+({b})y={c}\\{d}x+({e})y={f}\end{{cases}}$를 가우스 소거법으로 풀 때, $x+y$를 구하시오.",
                answer=str(answer),
                tags=["#가우스소거법"],
                steps=[
                    ("두 방정식의 계수를 확대행렬로 나타낸다.", rf"확대행렬의 두 행은 $({a},{b}\mid {c})$, $({d},{e}\mid {f})$이다."),
                    ("행 연산으로 한 미지수의 계수를 소거한다.", "한 행의 배수를 다른 행에 더해 y 또는 x의 계수를 0으로 만든다."),
                    ("남은 일차방정식에서 첫 미지수를 구한다.", "소거된 행을 이용해 한 미지수 값을 결정한다."),
                    ("구한 값을 원래 행에 대입해 다른 미지수를 구한다.", "두 행을 모두 만족하는 유일해를 얻는다."),
                    ("두 해를 더한다.", rf"따라서 $x+y={answer}$이다."),
                ],
                alternatives=["크래머 공식으로 두 행렬식을 계산해 같은 x와 y를 얻을 수 있다."],
                answer_check=lambda left=first, right=second: _linear_system_sum(left, right),
            )
        )
    acceleration_rows = [(2, 3, 1, 4), (4, -1, 5, 3), (-2, 6, -3, 5), (6, 2, 0, 2), (3, -4, 7, 6)]
    for index, (coefficient, constant, initial_velocity, end_time) in enumerate(acceleration_rows, 6):
        answer = _velocity_from_acceleration(coefficient, constant, initial_velocity, end_time)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"직선 운동에서 가속도가 $a(t)=({coefficient})t+({constant})$이고 초기속도가 $v(0)={initial_velocity}$일 때, $v({end_time})$를 구하시오.",
                answer=str(answer),
                tags=["#가속도", "#부정적분"],
                steps=[
                    ("가속도는 속도의 도함수임을 식으로 쓴다.", r"$v'(t)=a(t)$이다."),
                    ("가속도를 항별로 부정적분한다.", rf"$v(t)=({coefficient})\dfrac{{t^2}}2+({constant})t+C$이다."),
                    ("초기속도 조건으로 적분상수를 구한다.", rf"$v(0)=C={initial_velocity}$이다."),
                    ("완성된 속도함수에 종료시각을 대입한다.", rf"$v({end_time})=({coefficient})\dfrac{{{end_time}^2}}2+({constant})({end_time})+({initial_velocity})$이다."),
                    ("각 항을 계산해 속도를 구한다.", rf"따라서 $v({end_time})={answer}$이다."),
                ],
                alternatives=["속도 변화량을 $\int_0^T a(t)\,dt$로 계산해 초기속도에 더할 수 있다."],
                answer_check=lambda first=coefficient, second=constant, initial=initial_velocity, end=end_time: _velocity_from_acceleration(first, second, initial, end),
            )
        )
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 거듭제곱함수와 복소수 나눗셈 성분이다. 작동 원리는 저사용 미분·복소수 태그를 보강하는 난이도 5 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    derivative_rows = [(2, 3, 1, 2), (-1, 4, 5, -2), (3, 2, -4, 5), (1, 5, 2, -1), (-2, 3, 7, 3)]
    for index, (coefficient, exponent, constant, point) in enumerate(derivative_rows, 1):
        answer = _power_derivative_value(coefficient, exponent, constant, point)
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"함수 $f(x)=({coefficient})x^{exponent}+({constant})$의 $x={point}$에서의 미분계수를 도함수의 극한 정의로 구하시오.",
                answer=str(answer),
                tags=["#거듭제곱의미분", "#도함수공식", "#도함수의정의", "#미분계수의정의"],
                steps=[
                    ("미분계수의 극한 정의를 세운다.", rf"$f'({point})=\lim_{{h\to0}}\dfrac{{f({point}+h)-f({point})}}{{h}}$이다."),
                    ("함수식을 차분몫에 대입한다.", rf"상수항 ${constant}$는 두 함수값의 차에서 소거된다."),
                    ("거듭제곱의 차를 전개한다.", rf"$({point}+h)^{exponent}-{point}^{exponent}$에서 모든 항은 h를 인수로 갖는다."),
                    ("분자와 분모의 공통인수 h를 약분한다.", "h가 0이 아닌 단계에서 약분한 뒤 극한을 취한다."),
                    ("h가 0으로 갈 때 남는 항을 계산한다.", rf"거듭제곱 미분 결과는 $({coefficient})({exponent})({point})^{{{exponent - 1}}}$이다."),
                    ("수치를 계산해 미분계수를 구한다.", rf"따라서 $f'({point})={answer}$이다."),
                ],
                alternatives=[
                    "거듭제곱 도함수 공식 $(x^n)'=nx^{n-1}$을 적용한 뒤 극한 정의 결과와 비교할 수 있다.",
                    "미분계수를 그래프의 접선 기울기로 해석해 부호와 크기를 검산할 수 있다.",
                ],
                answer_check=lambda a=coefficient, n=exponent, c=constant, x=point: _power_derivative_value(a, n, c, x),
            )
        )
    complex_rows = [
        ((2, 3), (1, -1)),
        ((4, -2), (3, 1)),
        ((-1, 5), (2, -3)),
        ((6, 1), (-2, 2)),
        ((3, -4), (1, 2)),
    ]
    for index, (numerator, denominator) in enumerate(complex_rows, 6):
        a, b = numerator
        c, d = denominator
        norm = c**2 + d**2
        real = Fraction(a * c + b * d, norm)
        imaginary = Fraction(b * c - a * d, norm)
        answer = _complex_quotient_component_sum(numerator, denominator)
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"복소수 $\dfrac{{{a}+({b})i}}{{{c}+({d})i}}=p+qi$일 때, $p+q$를 구하시오.",
                answer=str(answer),
                tags=["#복소수", "#복소수의연산", "#켤레복소수"],
                steps=[
                    ("분모의 켤레복소수를 확인한다.", rf"켤레복소수는 ${c}-({d})i$이다."),
                    ("분자와 분모에 같은 켤레복소수를 곱한다.", "복소수의 값은 유지하면서 분모를 실수로 만든다."),
                    ("분모를 제곱합으로 계산한다.", rf"분모는 ${c}^2+({d})^2={norm}$이다."),
                    ("분자를 전개해 실수부와 허수부를 분리한다.", rf"실수부는 ${a * c + b * d}$, 허수부 계수는 ${b * c - a * d}$이다."),
                    ("분모로 나누어 p와 q를 구한다.", rf"$p={real}$, $q={imaginary}$이다."),
                    ("두 성분을 더한다.", rf"따라서 $p+q={answer}$이다."),
                ],
                alternatives=[
                    "복소수 나눗셈의 실수부·허수부 공식을 직접 적용할 수 있다.",
                    "구한 몫에 원래 분모를 곱해 분자가 복원되는지 검산할 수 있다.",
                ],
                answer_check=lambda first=numerator, second=denominator: _complex_quotient_component_sum(first, second),
            )
        )
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v25 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v25 전체 카탈로그다. 작동 원리는 모든 정답 검산 함수를 실행한 뒤 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog = build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v25 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(catalog, expected_count=50, batch_id=BATCH_ID, model_name=MODEL_NAME, codebase_base=CODEBASE_BASE, seed_base=SEED_BASE)


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v25 전체 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(db_path, quests=validated_quests(), batch_id=BATCH_ID, validate_only=validate_only)


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v25 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
