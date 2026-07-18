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

BATCH_ID = "marketplace-original-v19"
MODEL_NAME = "aiflow-direct-authoring-v19"
CODEBASE_BASE = 20_260_931_000
SEED_BASE = 202_607_510_000


def _checked_problem(
    tier: int,
    index: int,
    *,
    answer_check: Callable[[], Any],
    **kwargs: Any,
) -> dict[str, Any]:
    """필요 변수는 문제 명세와 독립 정답 계산 함수다. 작동 원리는 저장 전 실행할 검산 함수를 일반 문제 명세에 덧붙인다."""
    spec = _problem(tier, index, **kwargs)
    spec["answer_check"] = answer_check
    return spec


def _identity_difference(number: int) -> int:
    """필요 변수는 정수 하나다. 작동 원리는 두 제곱을 각각 계산해 차를 반환한다."""
    return (number + 1) ** 2 - (number - 1) ** 2


def _integer_ratio(first: int, second: int) -> int:
    """필요 변수는 연속한 두 등비수열 항이다. 작동 원리는 정확한 유리수 나눗셈으로 정수 공비를 확인한다."""
    ratio = Fraction(second, first)
    if ratio.denominator != 1:
        raise ValueError("공비가 정수가 아닙니다.")
    return ratio.numerator


def _larger_quadratic_root(sum_of_roots: int, product_of_roots: int) -> int:
    """필요 변수는 두 근의 합과 곱이다. 작동 원리는 판별식의 정수 제곱근으로 두 근을 계산해 큰 근을 고른다."""
    discriminant = sum_of_roots**2 - 4 * product_of_roots
    square_root = math.isqrt(discriminant)
    if square_root**2 != discriminant:
        raise ValueError("판별식이 완전제곱수가 아닙니다.")
    roots = (Fraction(sum_of_roots + square_root, 2), Fraction(sum_of_roots - square_root, 2))
    larger = max(roots)
    if larger.denominator != 1:
        raise ValueError("큰 근이 정수가 아닙니다.")
    return larger.numerator


def _division_coefficient_sum(root: int, quotient_constant: int, remainder: int) -> int:
    """필요 변수는 일차식의 근·몫의 상수항·나머지다. 작동 원리는 나눗셈 항등식을 전개해 원래 이차식의 두 계수를 합한다."""
    linear_coefficient = quotient_constant - root
    constant = remainder - root * quotient_constant
    return linear_coefficient + constant


def _radical_shift_sum(domain_start: int, point_x: int, point_y: int) -> int:
    """필요 변수는 무리함수 정의역 시작점과 그래프 위 한 점이다. 작동 원리는 수평 이동량과 제곱근 높이로 수직 이동량을 복원한다."""
    radicand = point_x - domain_start
    square_root = math.isqrt(radicand)
    if square_root**2 != radicand:
        raise ValueError("그래프 점의 진수가 완전제곱수가 아닙니다.")
    vertical_shift = point_y - square_root
    return domain_start + vertical_shift


def _reflected_y_intercept(slope: int, intercept: int) -> int:
    """필요 변수는 직선의 기울기와 절편이다. 작동 원리는 x축·y축 대칭 변환을 순서대로 계수에 적용한다."""
    x_axis_reflected = (-slope, -intercept)
    y_axis_reflected = (-x_axis_reflected[0], x_axis_reflected[1])
    return y_axis_reflected[1]


def _difference_sequence_term(first: int, coefficient: int, constant: int, target: int) -> int:
    """필요 변수는 첫째항·계차식 계수·상수·목표 항이다. 작동 원리는 계차를 첫 항부터 반복해서 더해 목표 항을 계산한다."""
    value = first
    for index in range(1, target):
        value += coefficient * index + constant
    return value


def _symmetric_derivative_sum(cubic: int, quadratic: int, linear: int, point: int) -> int:
    """필요 변수는 삼차함수의 세 계수와 대칭 좌표다. 작동 원리는 도함수를 두 좌표에 각각 대입해 합한다."""
    def derivative(x: int) -> int:
        return 3 * cubic * x**2 + 2 * quadratic * x + linear

    return derivative(point) + derivative(-point)


def _motion_total_distance(scale: int) -> int:
    """필요 변수는 속도 영점 간격이다. 작동 원리는 위치함수를 방향 전환 시각에 대입해 구간별 이동거리 절댓값을 합한다."""
    def position(time: int) -> int:
        return time**3 - 6 * scale * time**2 + 9 * scale**2 * time

    times = (0, scale, 3 * scale, 4 * scale)
    positions = [position(time) for time in times]
    return sum(abs(right - left) for left, right in zip(positions, positions[1:]))


def _riemann_square_integral(coefficient: int, constant: int) -> int:
    """필요 변수는 일차식의 계수와 상수다. 작동 원리는 제곱을 전개한 뒤 0부터 1까지 정확한 유리수로 적분한다."""
    value = Fraction(coefficient**2, 3) + Fraction(coefficient * constant, 1) + Fraction(constant**2, 1)
    if value.denominator != 1:
        raise ValueError("구분구적 극한값이 정수가 아닙니다.")
    return value.numerator


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 곱셈공식의 정수와 등비수열의 연속한 두 항이다. 작동 원리는 새 태그의 난이도 1 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    for index, number in enumerate((6, 9, 13, 17, 24), 1):
        answer = 4 * number
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"곱셈공식을 이용하여 $({number}+1)^2-({number}-1)^2$의 값을 구하시오.",
                answer=str(answer),
                tags=["#곱셈공식"],
                steps=[
                    ("두 제곱의 차를 합과 차의 곱으로 바꾼다.", rf"식은 $((({number}+1)-({number}-1)))((({number}+1)+({number}-1)))$이다."),
                    ("두 괄호를 계산해 곱한다.", rf"따라서 $2\cdot {2 * number}={answer}$이다."),
                ],
                answer_check=lambda n=number: _identity_difference(n),
            )
        )
    ratio_rows = [(3, 15), (-4, 12), (7, -14), (-5, -30), (8, 32)]
    for index, (first, second) in enumerate(ratio_rows, 6):
        answer = second // first
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"등비수열의 첫째항이 ${first}$이고 둘째항이 ${second}$일 때, 공비를 구하시오.",
                answer=str(answer),
                tags=["#공비"],
                steps=[
                    ("공비는 뒤 항을 바로 앞 항으로 나눈 값이다.", rf"공비 $r=\dfrac{{{second}}}{{{first}}}$이다."),
                    ("두 정수를 나누어 공비를 계산한다.", rf"따라서 $r={answer}$이다."),
                ],
                answer_check=lambda left=first, right=second: _integer_ratio(left, right),
            )
        )
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 이차방정식의 두 근과 다항식 나눗셈 항등식이다. 작동 원리는 새 태그의 난이도 2 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    root_rows = [(-2, 5), (3, 7), (-6, -1), (2, 9), (-4, 8)]
    for index, (root_left, root_right) in enumerate(root_rows, 1):
        root_sum = root_left + root_right
        root_product = root_left * root_right
        answer = max(root_left, root_right)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"이차방정식 $x^2-({root_sum})x+({root_product})=0$의 두 실근 중 큰 근을 구하시오.",
                answer=str(answer),
                tags=["#근의공식", "#실근조건"],
                steps=[
                    ("근의 공식에 필요한 판별식을 계산한다.", rf"판별식은 $({root_sum})^2-4({root_product})={(root_left - root_right) ** 2}$이다."),
                    ("근의 공식으로 두 실근을 구한다.", rf"$x=\dfrac{{{root_sum}\pm {abs(root_left - root_right)}}}2$이므로 두 근은 ${root_left},{root_right}$이다."),
                    ("두 실근의 크기를 비교한다.", rf"따라서 큰 근은 ${answer}$이다."),
                ],
                answer_check=lambda total=root_sum, product=root_product: _larger_quadratic_root(total, product),
            )
        )
    division_rows = [(2, 3, 5), (-1, 4, 2), (3, -2, 7), (-2, -3, -1), (4, 1, -3)]
    for index, (root, quotient_constant, remainder) in enumerate(division_rows, 6):
        linear_coefficient = quotient_constant - root
        constant = remainder - root * quotient_constant
        answer = linear_coefficient + constant
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"다항식 $P(x)=x^2+bx+c$를 $x-({root})$로 나눈 몫이 $x+({quotient_constant})$, 나머지가 ${remainder}$일 때, $b+c$를 구하시오.",
                answer=str(answer),
                tags=["#다항식의나눗셈", "#몫과나머지"],
                steps=[
                    ("다항식 나눗셈의 항등식을 세운다.", rf"$P(x)=(x-({root}))(x+({quotient_constant}))+({remainder})$이다."),
                    ("오른쪽을 전개해 두 계수를 비교한다.", rf"$P(x)=x^2+({linear_coefficient})x+({constant})$이므로 $b={linear_coefficient}$, $c={constant}$이다."),
                    ("두 계수를 더해 요구한 값을 계산한다.", rf"따라서 $b+c={linear_coefficient}+({constant})={answer}$이다."),
                ],
                answer_check=lambda r=root, q=quotient_constant, rest=remainder: _division_coefficient_sum(r, q, rest),
            )
        )
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 무리함수의 정의역 시작점·그래프 점과 대칭할 직선이다. 작동 원리는 새 태그의 난이도 3 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    radical_rows = [(2, 3, -1), (-4, 2, 5), (6, 4, -3), (-7, 3, 2), (5, 5, 4)]
    for index, (horizontal_shift, square_root, vertical_shift) in enumerate(radical_rows, 1):
        point_x = horizontal_shift + square_root**2
        point_y = vertical_shift + square_root
        answer = horizontal_shift + vertical_shift
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"무리함수 $f(x)=\sqrt{{x-a}}+b$의 정의역이 $x\ge {horizontal_shift}$이고 그래프가 점 $P({point_x},{point_y})$를 지날 때, $a+b$를 구하시오.",
                answer=str(answer),
                tags=["#무리함수의그래프", "#무리함수의평행이동", "#x방향이동"],
                steps=[
                    ("제곱근의 진수 조건으로 정의역 시작점을 확인한다.", r"$x-a\ge0$이므로 정의역은 $x\ge a$이다."),
                    ("주어진 정의역과 비교해 수평 이동량을 구한다.", rf"따라서 $a={horizontal_shift}$이다."),
                    ("그래프 위 점의 좌표를 함수식에 대입한다.", rf"${point_y}=\sqrt{{{point_x}-({horizontal_shift})}}+b={square_root}+b$이므로 $b={vertical_shift}$이다."),
                    ("두 이동량을 더해 요구한 값을 구한다.", rf"따라서 $a+b={horizontal_shift}+({vertical_shift})={answer}$이다."),
                ],
                alternatives=["기본 그래프의 시작점 $(0,0)$이 이동한 새 시작점 $(a,b)$를 정의역과 주어진 점으로 복원할 수 있다."],
                answer_check=lambda start=horizontal_shift, x=point_x, y=point_y: _radical_shift_sum(start, x, y),
            )
        )
    reflection_rows = [(2, 3), (-4, 5), (3, -7), (-2, -6), (5, 4)]
    for index, (slope, intercept) in enumerate(reflection_rows, 6):
        answer = -intercept
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"직선 $y=({slope})x+({intercept})$를 먼저 $x$축에 대하여 대칭이동하고, 다시 $y$축에 대하여 대칭이동한 직선의 $y$절편을 구하시오.",
                answer=str(answer),
                tags=["#대칭이동", "#x축대칭", "#y축대칭"],
                steps=[
                    ("x축 대칭에서는 y를 -y로 바꾼다.", rf"첫 번째 대칭 직선은 $y=-({slope})x-({intercept})$이다."),
                    ("y축 대칭에서는 x를 -x로 바꾼다.", rf"두 번째 대칭 직선은 $y=({slope})x-({intercept})$이다."),
                    ("최종 직선에서 x가 0일 때의 y값을 읽는다.", rf"$x=0$이면 $y=-({intercept})$이다."),
                    ("부호를 계산해 y절편을 확정한다.", rf"따라서 $y$절편은 ${answer}$이다."),
                ],
                alternatives=["두 번의 축대칭은 원점대칭과 같으므로 원래 직선 위 점 $(x,y)$를 $(-x,-y)$로 옮겨 식을 구할 수 있다."],
                answer_check=lambda m=slope, c=intercept: _reflected_y_intercept(m, c),
            )
        )
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 계차식과 삼차함수의 대칭 미분 좌표다. 작동 원리는 새 태그의 난이도 4 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    difference_rows = [(2, 1, 3, 6), (-4, 2, -1, 5), (5, -1, 4, 7), (0, 3, -2, 4), (7, 2, 1, 8)]
    for index, (first, coefficient, constant, target) in enumerate(difference_rows, 1):
        answer = _difference_sequence_term(first, coefficient, constant, target)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"수열 $\{{a_n\}}$이 $a_1={first}$, $a_{{n+1}}-a_n=({coefficient})n+({constant})$을 만족할 때, $a_{target}$의 값을 구하시오.",
                answer=str(answer),
                tags=["#계차수열", "#수열", "#수열의정의", "#일반항"],
                steps=[
                    ("첫째항부터 목표 항 전까지의 계차를 더한다.", rf"$a_{target}=a_1+\sum_{{n=1}}^{{{target - 1}}}(({coefficient})n+({constant}))$이다."),
                    ("계차 합을 자연수 합과 상수 합으로 분리한다.", rf"$a_{target}={first}+({coefficient})\sum_{{n=1}}^{{{target - 1}}}n+({constant})({target - 1})$이다."),
                    ("자연수 합 공식을 적용한다.", rf"$\sum_{{n=1}}^{{{target - 1}}}n=\dfrac{{{target - 1}\cdot {target}}}2$이다."),
                    ("각 계차의 합을 계산한다.", rf"계차의 총합은 ${answer - first}$이다."),
                    ("첫째항에 계차의 총합을 더한다.", rf"따라서 $a_{target}={first}+({answer - first})={answer}$이다."),
                ],
                alternatives=["점화식으로 $a_2,a_3,\ldots$를 차례로 계산해 목표 항까지 직접 누적할 수 있다."],
                answer_check=lambda a=first, p=coefficient, q=constant, n=target: _difference_sequence_term(a, p, q, n),
            )
        )
    derivative_rows = [(1, 2, -3, 4, 2), (-2, 3, 5, -1, 1), (3, -4, 2, 6, 3), (-1, 5, -2, 3, 2), (2, -3, 4, -5, 1)]
    for index, (cubic, quadratic, linear, constant, point) in enumerate(derivative_rows, 6):
        answer = _symmetric_derivative_sum(cubic, quadratic, linear, point)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"함수 $f(x)=({cubic})x^3+({quadratic})x^2+({linear})x+({constant})$에 대하여 $f'({point})+f'({-point})$의 값을 구하시오.",
                answer=str(answer),
                tags=["#거듭제곱의미분", "#도함수공식", "#상수배의미분", "#합차의미분"],
                steps=[
                    ("거듭제곱과 상수배의 미분법으로 도함수를 구한다.", rf"$f'(x)=({3 * cubic})x^2+({2 * quadratic})x+({linear})$이다."),
                    ("도함수에 양의 대칭 좌표를 대입한다.", rf"$f'({point})={3 * cubic * point**2}+({2 * quadratic * point})+({linear})$이다."),
                    ("도함수에 음의 대칭 좌표를 대입한다.", rf"$f'({-point})={3 * cubic * point**2}+({-2 * quadratic * point})+({linear})$이다."),
                    ("두 값을 더해 서로 반대인 일차항을 소거한다.", rf"합은 ${6 * cubic * point**2}+({2 * linear})$이다."),
                    ("남은 두 항을 계산해 결과를 구한다.", rf"따라서 $f'({point})+f'({-point})={answer}$이다."),
                ],
                alternatives=["도함수의 짝수 부분과 홀수 부분을 나누면 대칭 좌표의 합에서 홀수 부분이 소거됨을 바로 알 수 있다."],
                answer_check=lambda a=cubic, b=quadratic, c=linear, p=point: _symmetric_derivative_sum(a, b, c, p),
            )
        )
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 위치함수의 시간 척도와 구분구적 일차식이다. 작동 원리는 새 태그의 난이도 5 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    for index, scale in enumerate((1, 2, 3, 4, 5), 1):
        answer = 12 * scale**3
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"수직선 위를 움직이는 점의 시각 $t$에서의 위치가 $s(t)=t^3-{6 * scale}t^2+{9 * scale**2}t$이다. $0\le t\le {4 * scale}$에서 점이 움직인 총거리를 구하시오.",
                answer=str(answer),
                tags=["#속도와가속도", "#위치함수", "#속도", "#가속도", "#속도와거리"],
                steps=[
                    ("위치함수를 미분해 속도와 가속도를 구한다.", rf"$v(t)=3(t-{scale})(t-{3 * scale})$, $a(t)=6t-{12 * scale}$이다."),
                    ("속도가 0이 되어 방향이 바뀔 수 있는 시각을 찾는다.", rf"$v(t)=0$인 시각은 $t={scale},{3 * scale}$이다."),
                    ("속도의 부호로 각 구간의 이동 방향을 판정한다.", "속도는 첫 구간에서 양수, 가운데 구간에서 음수, 마지막 구간에서 양수이다."),
                    ("구간 끝과 방향 전환 시각의 위치를 계산한다.", rf"$s(0)=0$, $s({scale})={4 * scale**3}$, $s({3 * scale})=0$, $s({4 * scale})={4 * scale**3}$이다."),
                    ("각 구간에서 이동한 거리를 절댓값으로 더한다.", rf"총거리는 ${4 * scale**3}+{4 * scale**3}+{4 * scale**3}$이다."),
                    ("세 구간의 이동거리를 합해 결과를 구한다.", rf"따라서 총거리는 ${answer}$이다."),
                ],
                alternatives=[
                    "속도 그래프와 t축 사이의 넓이를 구간별 절댓값으로 적분해 총거리를 계산할 수 있다.",
                    "위치가 두 값 사이를 세 번 이동한다는 점을 이용해 한 구간 거리의 세 배로 계산할 수 있다.",
                ],
                answer_check=lambda m=scale: _motion_total_distance(m),
            )
        )
    riemann_rows = [(3, 1), (3, 2), (6, 2), (-3, 4), (6, -1)]
    for index, (coefficient, constant) in enumerate(riemann_rows, 6):
        answer = _riemann_square_integral(coefficient, constant)
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"극한 $\displaystyle\lim_{{n\to\infty}}\dfrac1n\sum_{{k=1}}^n\left(({coefficient})\dfrac kn+({constant})\right)^2$의 값을 구하시오.",
                answer=str(answer),
                tags=["#구분구적법", "#구간의분할", "#정적분의정의", "#극한의정의", "#극한의사칙연산"],
                steps=[
                    ("합을 구간 [0,1]의 오른쪽 끝점 구분구적으로 해석한다.", r"$\Delta x=1/n$, $x_k=k/n$인 리만 합이다."),
                    ("구분구적법으로 대응하는 정적분을 세운다.", rf"극한은 $\int_0^1(({coefficient})x+({constant}))^2dx$이다."),
                    ("적분할 제곱식을 전개한다.", rf"$(({coefficient})x+({constant}))^2={coefficient**2}x^2+({2 * coefficient * constant})x+({constant**2})$이다."),
                    ("각 항의 원시함수를 구한다.", rf"원시함수는 ${coefficient**2}x^3/3+({coefficient * constant})x^2+({constant**2})x$이다."),
                    ("적분 구간의 양 끝값을 대입한다.", rf"값은 $\dfrac{{{coefficient**2}}}3+({coefficient * constant})+({constant**2})$이다."),
                    ("세 항을 계산해 극한값을 구한다.", rf"따라서 극한값은 ${answer}$이다."),
                ],
                alternatives=[
                    "시그마를 직접 전개한 뒤 자연수 합과 제곱합의 최고차항 극한을 적용할 수 있다.",
                    "확률변수처럼 [0,1] 균등분포에서 일차식 제곱의 평균으로 해석할 수 있다.",
                ],
                answer_check=lambda a=coefficient, b=constant: _riemann_square_integral(a, b),
            )
        )
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v19 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v19 전체 카탈로그다. 작동 원리는 모든 정답 검산 함수를 실행한 뒤 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog = build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v19 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(catalog, expected_count=50, batch_id=BATCH_ID, model_name=MODEL_NAME, codebase_base=CODEBASE_BASE, seed_base=SEED_BASE)


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v19 전체 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(db_path, quests=validated_quests(), batch_id=BATCH_ID, validate_only=validate_only)


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v19 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
