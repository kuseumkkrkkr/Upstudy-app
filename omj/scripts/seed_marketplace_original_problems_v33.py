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

BATCH_ID = "marketplace-original-v33"
MODEL_NAME = "aiflow-direct-authoring-v33"
CODEBASE_BASE = 20_260_994_000
SEED_BASE = 202_607_573_000


def _checked_problem(
    tier: int,
    index: int,
    *,
    answer_check: Callable[[], Any],
    **kwargs: Any,
) -> dict[str, Any]:
    """필요 변수는 문제 명세와 독립 계산 함수다. 작동 원리는 저장 답과 별도 계산 결과를 공통 검증기가 비교하도록 검산 함수를 부착한다."""
    spec = _problem(tier, index, **kwargs)
    spec["answer_check"] = answer_check
    return spec


def _complex_power_sum(real: int, imaginary: int, exponent: int) -> int:
    """필요 변수는 복소수의 실수부·허수부와 i의 지수다. 작동 원리는 i의 네 제곱 주기를 적용해 곱의 실수부와 허수부를 더한다."""
    rotations = ((real, imaginary), (-imaginary, real), (-real, -imaginary), (imaginary, -real))
    result_real, result_imaginary = rotations[exponent % 4]
    return result_real + result_imaginary


def _symmetric_difference_sum(first: tuple[int, ...], second: tuple[int, ...]) -> int:
    """필요 변수는 두 유한 정수 집합이다. 작동 원리는 한 집합에만 속하는 대칭차 원소를 골라 합한다."""
    return sum(set(first) ^ set(second))


def _implication_true_count(
    lower: int,
    upper: int,
    antecedent_modulus: int,
    consequent_modulus: int,
) -> int:
    """필요 변수는 정수 범위와 두 배수 조건이다. 작동 원리는 전건이 거짓이거나 후건이 참인 경우를 조건명제가 참인 경우로 센다."""
    if lower > upper or antecedent_modulus <= 0 or consequent_modulus <= 0:
        raise ValueError("조건명제의 범위와 나눗수가 올바르지 않습니다.")
    return sum(
        value % antecedent_modulus != 0 or value % consequent_modulus == 0
        for value in range(lower, upper + 1)
    )


def _parallelogram_vertex_sum(
    first: tuple[int, int],
    opposite: tuple[int, int],
    adjacent: tuple[int, int],
) -> int:
    """필요 변수는 평행사변형의 한 대각선 양 끝점과 인접 꼭짓점이다. 작동 원리는 두 대각선의 중점 일치 조건으로 남은 꼭짓점을 구해 좌표를 더한다."""
    fourth_x = first[0] + opposite[0] - adjacent[0]
    fourth_y = first[1] + opposite[1] - adjacent[1]
    return fourth_x + fourth_y


def _affine_recurrence(
    first: int,
    multiplier: int,
    offset: int,
    target_index: int,
) -> int:
    """필요 변수는 첫째항·배수·상수항·목표 번호다. 작동 원리는 일차 점화식을 목표 항까지 반복 적용한다."""
    if target_index < 1:
        raise ValueError("목표 항 번호는 1 이상이어야 합니다.")
    value = first
    for _ in range(1, target_index):
        value = multiplier * value + offset
    return value


def _weighted_natural_sum(upper: int, shift: int) -> int:
    """필요 변수는 시그마 상한과 일차식의 이동량이다. 작동 원리는 각 자연수 k에 k(k+shift)를 곱해 직접 합산한다."""
    if upper < 1:
        raise ValueError("시그마 상한은 1 이상이어야 합니다.")
    return sum(index * (index + shift) for index in range(1, upper + 1))


def _piecewise_limit_parameter(
    point: int,
    left_quadratic: tuple[int, int, int],
    right_constant: int,
) -> Fraction:
    """필요 변수는 0이 아닌 경계점·왼쪽 이차식·오른쪽 상수항이다. 작동 원리는 좌극한과 mx+c 꼴 우극한을 같게 두어 m을 구한다."""
    if point == 0:
        raise ValueError("오른쪽 식의 계수를 결정하려면 경계점은 0이 아니어야 합니다.")
    a, b, c = left_quadratic
    left_limit = a * point**2 + b * point + c
    return Fraction(left_limit - right_constant, point)


def _cubic_tangent_y_intercept(
    cubic: int,
    quadratic: int,
    linear: int,
    constant: int,
    point: int,
) -> int:
    """필요 변수는 삼차함수 계수와 접점의 x좌표다. 작동 원리는 접점 함수값에서 접선 기울기와 x좌표의 곱을 빼 y절편을 구한다."""
    value = cubic * point**3 + quadratic * point**2 + linear * point + constant
    slope = 3 * cubic * point**2 + 2 * quadratic * point + linear
    return value - slope * point


def _position_from_acceleration(
    acceleration_linear: int,
    acceleration_constant: int,
    initial_velocity: int,
    initial_position: int,
    end_time: int,
) -> Fraction:
    """필요 변수는 일차 가속도 계수·초기 속도·초기 위치·종료 시각이다. 작동 원리는 가속도를 두 번 정확히 적분해 종료 위치를 계산한다."""
    if end_time < 0:
        raise ValueError("종료 시각은 0 이상이어야 합니다.")
    return (
        Fraction(acceleration_linear * end_time**3, 6)
        + Fraction(acceleration_constant * end_time**2, 2)
        + initial_velocity * end_time
        + initial_position
    )


def _symmetric_parabola_area(scale: int, radius: int) -> Fraction:
    """필요 변수는 아래로 열린 포물선의 배수와 양의 근이다. 작동 원리는 짝함수의 대칭성과 정적분으로 x축 사이 넓이를 구한다."""
    if scale <= 0 or radius <= 0:
        raise ValueError("포물선의 배수와 근은 양수여야 합니다.")
    return Fraction(4 * scale * radius**3, 3)


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 복소수 회전과 두 유한 집합이다. 작동 원리는 i의 주기와 대칭차를 이용하는 기초 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    complex_rows = [(1, 2, 1), (2, -1, 2), (-3, 1, 3), (4, 2, 5), (-2, -5, 6)]
    for index, (real, imaginary, exponent) in enumerate(complex_rows, 1):
        answer = _complex_power_sum(real, imaginary, exponent)
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"복소수 $z=({real})+({imaginary})i$에 대하여 $zi^{exponent}=p+qi$일 때, $p+q$를 구하시오.",
                answer=str(answer),
                tags=["#복소수", "#복소수의연산", "#실수와허수"],
                steps=[
                    ("i의 거듭제곱을 네 제곱 주기로 정리한다.", rf"$i^{exponent}=i^{{{exponent % 4}}}$로 계수를 회전시킨다."),
                    ("곱의 실수부와 허수부를 구해 더한다.", rf"따라서 $p+q={answer}$이다."),
                ],
                answer_check=lambda a=real, b=imaginary, n=exponent: _complex_power_sum(a, b, n),
            )
        )
    set_rows = [
        ((-3, -1, 1, 3, 5), (-1, 0, 1, 2, 3)),
        ((1, 2, 4, 8, 16), (2, 3, 5, 8, 13)),
        ((-5, -2, 0, 4, 7), (-2, 1, 4, 6, 7)),
        ((2, 6, 10, 14), (4, 6, 8, 10, 12)),
        ((-8, -4, 0, 4, 8), (-6, -4, 0, 2, 8)),
    ]
    for index, (first, second) in enumerate(set_rows, 6):
        symmetric = sorted(set(first) ^ set(second))
        answer = _symmetric_difference_sum(first, second)
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"두 집합 $A=\{{{','.join(map(str, first))}\}}$, $B=\{{{','.join(map(str, second))}\}}$에 대하여 $(A-B)\cup(B-A)$의 모든 원소의 합을 구하시오.",
                answer=str(answer),
                tags=["#집합의연산", "#차집합", "#합집합", "#집합"],
                steps=[
                    ("두 집합에 공통으로 속한 원소를 제외한다.", rf"한쪽에만 속한 원소는 $\{{{','.join(map(str, symmetric))}\}}$이다."),
                    ("남은 원소를 모두 더한다.", rf"따라서 합은 ${answer}$이다."),
                ],
                answer_check=lambda a=first, b=second: _symmetric_difference_sum(a, b),
            )
        )
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 유한 정의역 조건명제와 평행사변형의 세 점이다. 작동 원리는 진리값 판정과 대각선 중점 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    proposition_rows = [(-10, 10, 2, 4), (-12, 12, 3, 6), (-15, 15, 4, 2), (-20, 10, 5, 3), (-8, 18, 6, 2)]
    for index, (lower, upper, antecedent, consequent) in enumerate(proposition_rows, 1):
        answer = _implication_true_count(lower, upper, antecedent, consequent)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"정의역 $U=\{{n\in\mathbb Z\mid {lower}\le n\le {upper}\}}$에서 조건명제 ‘n이 {antecedent}의 배수이면 n은 {consequent}의 배수이다’가 참이 되는 n의 개수를 구하시오.",
                answer=str(answer),
                tags=["#명제", "#명제의참거짓", "#조건제시법"],
                steps=[
                    ("전건과 후건의 배수 조건을 각각 판정한다.", "전건이 참이고 후건이 거짓인 경우만 조건명제가 거짓이다."),
                    ("정의역에서 거짓인 경우를 제외한다.", rf"전체 ${upper - lower + 1}$개 정수에 조건을 적용한다."),
                    ("남은 참인 경우를 센다.", rf"따라서 조건명제가 참인 n은 ${answer}$개이다."),
                ],
                answer_check=lambda low=lower, high=upper, p=antecedent, q=consequent: _implication_true_count(low, high, p, q),
            )
        )
    coordinate_rows = [
        ((-2, 1), (6, 5), (1, 4)),
        ((3, -4), (-5, 8), (2, 1)),
        ((0, 2), (8, -6), (5, -1)),
        ((-7, -3), (1, 9), (-2, 4)),
        ((4, 6), (-2, -8), (3, -5)),
    ]
    for index, (first, opposite, adjacent) in enumerate(coordinate_rows, 6):
        fourth = (first[0] + opposite[0] - adjacent[0], first[1] + opposite[1] - adjacent[1])
        answer = _parallelogram_vertex_sum(first, opposite, adjacent)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"평행사변형 ABCD에서 $A{first}$와 $C{opposite}$가 서로 마주 보는 꼭짓점이고 $B{adjacent}$일 때, 점 D의 두 좌표의 합을 구하시오.",
                answer=str(answer),
                tags=["#중점", "#좌표평면", "#선분의내분점"],
                steps=[
                    ("평행사변형의 두 대각선이 서로를 이등분함을 이용한다.", "대각선 AC와 BD의 중점이 같다."),
                    ("좌표 관계 $A+C=B+D$를 세운다.", rf"따라서 $D=A+C-B={fourth}$이다."),
                    ("점 D의 두 좌표를 더한다.", rf"구하는 합은 ${answer}$이다."),
                ],
                answer_check=lambda a=first, c=opposite, b=adjacent: _parallelogram_vertex_sum(a, c, b),
            )
        )
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 일차 점화식과 가중 자연수 합이다. 작동 원리는 반복 계산과 시그마 분해 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    recurrence_rows = [(1, 2, 1, 6), (3, -1, 4, 7), (-2, 3, 2, 5), (5, 2, -3, 6), (4, -2, 1, 5)]
    for index, (first, multiplier, offset, target) in enumerate(recurrence_rows, 1):
        answer = _affine_recurrence(first, multiplier, offset, target)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"수열 $\{{a_n\}}$이 $a_1={first}$, $a_{{n+1}}=({multiplier})a_n+({offset})$을 만족할 때 $a_{target}$의 값을 구하시오.",
                answer=str(answer),
                tags=["#수열", "#수열의정의", "#일반항", "#계차수열"],
                steps=[
                    ("첫째항을 점화식에 대입해 다음 항을 구한다.", "각 단계에서 앞 항에 배수를 곱하고 상수항을 더한다."),
                    ("같은 계산을 목표 항 직전까지 반복한다.", rf"$a_1$부터 $a_{target}$까지 순서대로 계산한다."),
                    ("마지막 반복 결과를 목표 항으로 정리한다.", rf"$a_{target}={answer}$이다."),
                    ("구한 항을 직전 항과 점화식에 다시 대입해 검산한다.", rf"좌변과 우변이 일치하므로 최종값은 $a_{target}={answer}$이다."),
                ],
                alternatives=["고정점을 이용해 b_n=a_n-c 꼴로 치환한 뒤 등비수열로 계산할 수 있다."],
                answer_check=lambda a=first, r=multiplier, c=offset, n=target: _affine_recurrence(a, r, c, n),
            )
        )
    sigma_rows = [(8, 1), (10, 2), (12, -1), (15, 3), (20, -2)]
    for index, (upper, shift) in enumerate(sigma_rows, 6):
        answer = _weighted_natural_sum(upper, shift)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"합 $\sum_{{k=1}}^{{{upper}}}k(k+({shift}))$의 값을 구하시오.",
                answer=str(answer),
                tags=["#수열의표현", "#시그마공식", "#자연수의거듭제곱의합", "#시그마의성질"],
                steps=[
                    ("시그마 안의 곱을 전개한다.", rf"$k(k+({shift}))=k^2+({shift})k$이다."),
                    ("합을 제곱합과 자연수 합으로 나눈다.", r"$\sum k^2+({shift})\sum k$ 꼴이다."),
                    ("두 합의 공식을 적용한다.", r"$\sum k=n(n+1)/2$와 $\sum k^2=n(n+1)(2n+1)/6$을 사용한다."),
                    ("상한과 이동량을 대입해 계산한다.", rf"따라서 합은 ${answer}$이다."),
                ],
                alternatives=["각 k에 대한 k(k+shift)를 직접 계산해 모두 더하여 검산할 수 있다."],
                answer_check=lambda n=upper, c=shift: _weighted_natural_sum(n, c),
            )
        )
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 조각함수 극한 조건과 삼차함수 접선이다. 작동 원리는 좌우극한 일치와 미분을 이용하는 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    limit_rows = [
        (1, (1, 2, 3), 1),
        (-1, (2, 1, 4), 1),
        (2, (-1, 3, 2), 0),
        (-2, (1, -2, 5), 3),
        (3, (2, -1, -4), 2),
    ]
    for index, (point, quadratic, right_constant) in enumerate(limit_rows, 1):
        a, b, c = quadratic
        left_limit = a * point**2 + b * point + c
        answer = _piecewise_limit_parameter(point, quadratic, right_constant)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"함수 $f(x)=\begin{{cases}}{a}x^2+({b})x+({c})&(x<{point})\\mx+({right_constant})&(x>{point})\end{{cases}}$에서 $\lim_{{x\to {point}}}f(x)$가 존재할 때 m을 구하시오.",
                answer=str(answer),
                tags=["#함수의극한", "#좌극한", "#우극한", "#미정계수법"],
                steps=[
                    ("왼쪽 식에 경계점을 대입해 좌극한을 구한다.", rf"좌극한은 ${left_limit}$이다."),
                    ("오른쪽 식으로 우극한을 나타낸다.", rf"우극한은 $({point})m+({right_constant})$이다."),
                    ("두 방향의 극한이 같다는 방정식을 세운다.", rf"$({point})m+({right_constant})={left_limit}$이다."),
                    ("일차방정식을 풀어 m을 구한다.", rf"$m={answer}$이다."),
                    ("구한 m을 양쪽 식에 대입해 극한이 일치하는지 확인한다.", rf"$m={answer}$일 때 좌극한과 우극한이 모두 ${left_limit}$이다."),
                ],
                alternatives=["두 조각의 그래프가 경계점에서 같은 높이에 접근한다는 조건으로 직선의 계수를 정할 수 있다."],
                answer_check=lambda x=point, curve=quadratic, d=right_constant: _piecewise_limit_parameter(x, curve, d),
            )
        )
    tangent_rows = [
        (1, 0, 3, 7, 1),
        (2, 1, -4, 3, -1),
        (-1, 3, 2, -5, 2),
        (3, -1, 0, 4, -2),
        (1, 4, -2, 6, 3),
    ]
    for index, (cubic, quadratic, linear, constant, point) in enumerate(tangent_rows, 6):
        value = cubic * point**3 + quadratic * point**2 + linear * point + constant
        slope = 3 * cubic * point**2 + 2 * quadratic * point + linear
        answer = _cubic_tangent_y_intercept(cubic, quadratic, linear, constant, point)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"삼차함수 $f(x)={cubic}x^3+({quadratic})x^2+({linear})x+({constant})$의 $x={point}$에서의 접선이 y축과 만나는 점의 y좌표를 구하시오.",
                answer=str(answer),
                tags=["#도함수", "#접선의기울기", "#접선의방정식", "#거듭제곱의미분"],
                steps=[
                    ("삼차함수를 미분해 도함수를 구한다.", rf"$f'(x)={3 * cubic}x^2+({2 * quadratic})x+({linear})$이다."),
                    ("접점의 x좌표를 도함수에 대입한다.", rf"접선의 기울기는 ${slope}$이다."),
                    ("접점의 함수값을 계산한다.", rf"접점은 $({point},{value})$이다."),
                    ("점기울기식으로 접선 방정식을 세운다.", rf"$y-{value}={slope}(x-({point}))$이다."),
                    ("x=0을 대입해 y절편을 구한다.", rf"따라서 y좌표는 ${answer}$이다."),
                ],
                alternatives=["접선의 y절편이 f(p)-pf'(p)임을 바로 적용해 계산할 수 있다."],
                answer_check=lambda a=cubic, b=quadratic, c=linear, d=constant, p=point: _cubic_tangent_y_intercept(a, b, c, d, p),
            )
        )
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 일차 가속도와 대칭 포물선이다. 작동 원리는 두 번 적분한 위치와 짝함수 넓이 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    motion_rows = [(2, 1, 0, 3, 3), (3, -2, 4, -1, 4), (-2, 5, -3, 2, 6), (4, -1, 2, 0, 5), (1, 3, -2, 7, 6)]
    for index, (linear, constant, initial_velocity, initial_position, end_time) in enumerate(motion_rows, 1):
        final_velocity = Fraction(linear * end_time**2, 2) + constant * end_time + initial_velocity
        answer = _position_from_acceleration(linear, constant, initial_velocity, initial_position, end_time)
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"수직선 위 점 P의 가속도가 $a(t)=({linear})t+({constant})$이고 $v(0)={initial_velocity}$, $s(0)={initial_position}$일 때 $s({end_time})$를 구하시오.",
                answer=str(answer),
                tags=["#속도와가속도", "#가속도", "#위치함수", "#부정적분"],
                steps=[
                    ("가속도를 적분해 속도의 일반형을 구한다.", rf"$v(t)=({linear})t^2/2+({constant})t+C_1$이다."),
                    ("초기 속도를 대입해 첫 적분상수를 정한다.", rf"$C_1={initial_velocity}$이다."),
                    ("속도를 다시 적분해 위치의 일반형을 구한다.", rf"$s(t)=({linear})t^3/6+({constant})t^2/2+({initial_velocity})t+C_2$이다."),
                    ("초기 위치를 대입해 두 번째 적분상수를 정한다.", rf"$C_2={initial_position}$이다."),
                    ("종료 시각을 위치함수에 대입한다.", rf"$s({end_time})={answer}$이다."),
                    ("위치함수를 미분해 속도와 가속도로 되돌아가는지 검산한다.", rf"종료 속도는 ${final_velocity}$이고 미분 관계가 성립하므로 $s({end_time})={answer}$이다."),
                ],
                alternatives=[
                    "초기 속도에 가속도의 정적분을 더해 v(t)를 구한 뒤 다시 정적분할 수 있다.",
                    "가속도-시간 그래프의 넓이로 속도 변화를 먼저 구하고 위치 변화를 계산할 수 있다.",
                ],
                answer_check=lambda m=linear, n=constant, v=initial_velocity, s=initial_position, end=end_time: _position_from_acceleration(m, n, v, s, end),
            )
        )
    area_rows = [(1, 2), (2, 3), (3, 1), (1, 5), (4, 2)]
    for index, (scale, radius) in enumerate(area_rows, 6):
        answer = _symmetric_parabola_area(scale, radius)
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"곡선 $y={scale}({radius**2}-x^2)$와 x축으로 둘러싸인 부분의 넓이를 구하시오.",
                answer=str(answer),
                tags=["#정적분과넓이", "#정적분의성질", "#곡선과x축사이의넓이", "#정적분의계산"],
                steps=[
                    ("곡선이 x축과 만나는 두 점을 구한다.", rf"$x=\pm {radius}$에서 y=0이다."),
                    ("두 근 사이에서 함수의 부호를 확인한다.", "구간 안에서는 함수값이 0 이상이다."),
                    ("넓이를 정적분으로 나타낸다.", rf"$\int_{{-{radius}}}^{{{radius}}}{scale}({radius**2}-x^2)dx$이다."),
                    ("피적분함수가 짝함수임을 이용한다.", rf"$2\int_0^{{{radius}}}{scale}({radius**2}-x^2)dx$로 바꾼다."),
                    ("상수항과 이차항을 각각 적분한다.", r"$\int(r^2-x^2)dx=r^2x-x^3/3$이다."),
                    ("양 끝값을 대입해 넓이를 정리한다.", rf"따라서 넓이는 ${answer}$이다."),
                ],
                alternatives=[
                    "전체 구간에서 직접 원시함수 값을 빼서 계산할 수 있다.",
                    "폭 2r인 포물선 조각의 넓이 공식을 유도해 $4kr^3/3$을 적용할 수 있다.",
                ],
                answer_check=lambda k=scale, r=radius: _symmetric_parabola_area(k, r),
            )
        )
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v33 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v33 전체 카탈로그다. 작동 원리는 독립 정답 검산 후 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog = build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v33 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(
        catalog,
        expected_count=50,
        batch_id=BATCH_ID,
        model_name=MODEL_NAME,
        codebase_base=CODEBASE_BASE,
        seed_base=SEED_BASE,
    )


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v33 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(
        db_path,
        quests=validated_quests(),
        batch_id=BATCH_ID,
        validate_only=validate_only,
    )


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v33 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(
        json.dumps(
            seed_database(args.db, validate_only=args.validate_only),
            ensure_ascii=False,
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
