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

BATCH_ID = "marketplace-original-v37"
MODEL_NAME = "aiflow-direct-authoring-v37"
CODEBASE_BASE = 20_260_998_000
SEED_BASE = 202_607_577_000


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


def _cube_coefficient_sum(linear: int, constant: int) -> int:
    """필요 변수는 일차식의 두 계수다. 작동 원리는 세제곱 전개식의 계수합을 x=1 대입값으로 계산한다."""
    return (linear + constant) ** 3


def _matrix_row_column_difference(matrix: tuple[tuple[int, int, int], tuple[int, int, int]]) -> int:
    """필요 변수는 2×3 행렬이다. 작동 원리는 첫째 행의 합에서 셋째 열의 합을 뺀다."""
    return sum(matrix[0]) - (matrix[0][2] + matrix[1][2])


def _condition_relationship(antecedent_divisor: int, consequent_divisor: int) -> str:
    """필요 변수는 두 배수 명제의 나눗수다. 작동 원리는 두 배수집합의 포함관계로 필요·충분 여부를 판정한다."""
    if antecedent_divisor <= 0 or consequent_divisor <= 0:
        raise ValueError("양의 나눗수가 필요합니다.")
    antecedent_implies = antecedent_divisor % consequent_divisor == 0
    consequent_implies = consequent_divisor % antecedent_divisor == 0
    if antecedent_implies and consequent_implies:
        return "필요충분조건"
    if antecedent_implies:
        return "충분조건"
    if consequent_implies:
        return "필요조건"
    return "어느조건도아님"


def _complex_power_sum(exponents: tuple[int, ...]) -> str:
    """필요 변수는 i의 지수 목록이다. 작동 원리는 네 제곱 주기로 실수부·허수부를 누적해 표준 복소수 문자열을 만든다."""
    real = 0
    imaginary = 0
    for exponent in exponents:
        cycle = exponent % 4
        if cycle == 0:
            real += 1
        elif cycle == 1:
            imaginary += 1
        elif cycle == 2:
            real -= 1
        else:
            imaginary -= 1
    if imaginary == 0:
        return str(real)
    imaginary_text = "i" if abs(imaginary) == 1 else f"{abs(imaginary)}i"
    if real == 0:
        return imaginary_text if imaginary > 0 else f"-{imaginary_text}"
    sign = "+" if imaginary > 0 else "-"
    return f"{real}{sign}{imaginary_text}"


def _power_digit_count(exponent: int, log_numerator: int = 3010, log_denominator: int = 10000) -> int:
    """필요 변수는 2의 지수와 상용로그 근삿값 분수다. 작동 원리는 floor(n log10 2)+1로 자릿수를 구한다."""
    if exponent <= 0 or log_denominator <= 0:
        raise ValueError("양의 지수와 로그 분모가 필요합니다.")
    return exponent * log_numerator // log_denominator + 1


def _external_division_sum(
    first: tuple[int, int],
    second: tuple[int, int],
    first_ratio: int,
    second_ratio: int,
) -> Fraction:
    """필요 변수는 두 점과 외분비다. 작동 원리는 (mB-nA)/(m-n) 공식으로 외분점 좌표를 구해 더한다."""
    if first_ratio <= 0 or second_ratio <= 0 or first_ratio == second_ratio:
        raise ValueError("서로 다른 양의 외분비가 필요합니다.")
    denominator = first_ratio - second_ratio
    x_value = Fraction(first_ratio * second[0] - second_ratio * first[0], denominator)
    y_value = Fraction(first_ratio * second[1] - second_ratio * first[1], denominator)
    return x_value + y_value


def _scaled_derivative_limit(
    cubic: int,
    quadratic: int,
    linear: int,
    point: int,
    scale: int,
) -> int:
    """필요 변수는 삼차함수 계수·극한점·증분 배수다. 작동 원리는 합성 증분의 극한을 scale·f'(point)로 계산한다."""
    derivative = 3 * cubic * point**2 + 2 * quadratic * point + linear
    return scale * derivative


def _transformed_parabola_vertex_sum(
    horizontal: int,
    vertical: int,
    shift_x: int,
    shift_y: int,
) -> int:
    """필요 변수는 포물선 꼭짓점과 평행이동 벡터다. 작동 원리는 원점대칭 후 평행이동한 꼭짓점 좌표를 더한다."""
    final_x = -horizontal + shift_x
    final_y = -vertical + shift_y
    return final_x + final_y


def _quadratic_velocity_gap(
    scale: int,
    first_turn: int,
    second_turn: int,
    end_time: int,
) -> Fraction:
    """필요 변수는 이차 속도의 배수·두 영점·종료 시각이다. 작동 원리는 총거리에서 변위 절댓값을 빼 방향 상쇄량을 구한다."""
    if scale <= 0 or not 0 < first_turn < second_turn < end_time:
        raise ValueError("속도 부호가 세 구간으로 나뉘는 조건이 필요합니다.")

    def primitive(time: int) -> Fraction:
        """필요 변수는 평가 시각이다. 작동 원리는 전개한 이차 속도의 원시함수를 정확한 분수로 계산한다."""
        return scale * (
            Fraction(time**3, 3)
            - Fraction((first_turn + second_turn) * time**2, 2)
            + first_turn * second_turn * time
        )

    points = (0, first_turn, second_turn, end_time)
    changes = [primitive(right) - primitive(left) for left, right in zip(points, points[1:])]
    total_distance = sum((abs(change) for change in changes), Fraction(0, 1))
    displacement = sum(changes, Fraction(0, 1))
    return total_distance - abs(displacement)


def _interpolated_cubic_value(
    first_root: int,
    second_root: int,
    sample_x: int,
    sample_value: int,
    target_x: int,
) -> Fraction:
    """필요 변수는 두 근·한 함수값·목표점이다. 작동 원리는 P(x)=(x-r1)(x-r2)(x-u)에서 셋째 근을 복원해 목표값을 구한다."""
    denominator = (sample_x - first_root) * (sample_x - second_root)
    if denominator == 0:
        raise ValueError("표본점은 알려진 두 근과 달라야 합니다.")
    third_root = Fraction(sample_x, 1) - Fraction(sample_value, denominator)
    return (
        Fraction(target_x - first_root, 1)
        * Fraction(target_x - second_root, 1)
        * (Fraction(target_x, 1) - third_root)
    )


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 일차식 세제곱과 2×3 행렬이다. 작동 원리는 계수합과 행·열 계산 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    cube_rows = [(2, 1), (-3, 5), (4, -2), (1, -4), (-2, -3)]
    for index, (linear, constant) in enumerate(cube_rows, 1):
        answer = _cube_coefficient_sum(linear, constant)
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"다항식 $(({linear})x+({constant}))^3$을 전개했을 때 모든 계수의 합을 구하시오.",
                answer=str(answer),
                tags=["#세제곱공식", "#인수분해공식", "#다항식의곱셈"],
                steps=[
                    ("다항식의 계수합은 x=1을 대입한 값임을 이용한다.", rf"$x=1$을 넣으면 $(({linear})+({constant}))^3$이다."),
                    ("괄호 안을 계산한 뒤 세제곱한다.", rf"따라서 계수의 합은 ${answer}$이다."),
                ],
                answer_check=lambda a=linear, b=constant: _cube_coefficient_sum(a, b),
            )
        )
    matrix_rows = [
        ((1, 2, 3), (4, 5, 6)),
        ((-2, 4, 1), (3, -1, 5)),
        ((5, 0, -3), (2, 7, 1)),
        ((-4, -2, 6), (1, 3, -5)),
        ((3, 8, 2), (-1, 4, 7)),
    ]
    for index, matrix in enumerate(matrix_rows, 6):
        first_row_sum = sum(matrix[0])
        third_column_sum = matrix[0][2] + matrix[1][2]
        answer = _matrix_row_column_difference(matrix)
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"행렬 $A=\begin{{pmatrix}}{matrix[0][0]}&{matrix[0][1]}&{matrix[0][2]}\\{matrix[1][0]}&{matrix[1][1]}&{matrix[1][2]}\end{{pmatrix}}$에서 첫째 행 성분의 합에서 셋째 열 성분의 합을 뺀 값을 구하시오.",
                answer=str(answer),
                tags=["#행", "#열", "#행렬", "#행렬의정의", "#성분"],
                steps=[
                    ("첫째 행과 셋째 열의 성분을 각각 읽어 합한다.", rf"두 합은 ${first_row_sum}$과 ${third_column_sum}$이다."),
                    ("첫째 행의 합에서 셋째 열의 합을 뺀다.", rf"따라서 값은 ${answer}$이다."),
                ],
                answer_check=lambda values=matrix: _matrix_row_column_difference(values),
            )
        )
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 배수 명제와 i의 지수 목록이다. 작동 원리는 조건 관계와 복소수 주기 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    condition_rows = [(6, 3), (3, 6), (4, 4), (4, 6), (10, 5)]
    for index, (first, second) in enumerate(condition_rows, 1):
        answer = _condition_relationship(first, second)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"모든 정수 n에 대하여 조건 P를 ‘n은 {first}의 배수이다’, 조건 Q를 ‘n은 {second}의 배수이다’라 할 때, P가 Q이기 위한 조건 관계를 판정하시오.",
                answer=answer,
                tags=["#필요조건", "#충분조건", "#필요충분조건", "#충분조건과필요조건", "#명제"],
                steps=[
                    ("P를 만족하는 정수들이 Q도 만족하는지 확인한다.", rf"{first}의 배수가 항상 {second}의 배수인지 판정한다."),
                    ("Q를 만족하는 정수들이 P도 만족하는지 역방향을 확인한다.", rf"{second}의 배수가 항상 {first}의 배수인지 판정한다."),
                    ("두 방향의 함의 결과로 조건 관계를 정리한다.", rf"따라서 P는 Q이기 위한 ${answer}$이다."),
                ],
                answer_check=lambda p=first, q=second: _condition_relationship(p, q),
            )
        )
    complex_rows = [(0, 1, 2, 2), (1, 2, 4, 5), (2, 3, 6, 7), (1, 3, 5, 7), (0, 4, 8, 12)]
    for index, exponents in enumerate(complex_rows, 6):
        answer = _complex_power_sum(exponents)
        expression = "+".join(rf"i^{{{exponent}}}" for exponent in exponents)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"복소수의 합 ${expression}$을 $a+bi$ 꼴로 간단히 나타내시오.",
                answer=answer,
                tags=["#복소수", "#복소수의연산", "#이", "#실수와허수"],
                steps=[
                    ("각 i의 거듭제곱을 4로 나눈 나머지에 따라 정리한다.", r"$i^0=1,i^1=i,i^2=-1,i^3=-i$의 주기를 사용한다."),
                    ("실수항과 허수항을 각각 모은다.", "동류항끼리 계수를 더한다."),
                    ("표준 복소수 꼴로 정리한다.", rf"따라서 합은 ${answer}$이다."),
                ],
                answer_check=lambda powers=exponents: _complex_power_sum(powers),
            )
        )
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 2의 지수와 선분 외분 조건이다. 작동 원리는 상용로그 자릿수와 외분점 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    exponent_rows = [20, 35, 50, 75, 100]
    for index, exponent in enumerate(exponent_rows, 1):
        log_value = Fraction(exponent * 3010, 10000)
        answer = _power_digit_count(exponent)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"$\log_{{10}}2=0.3010$을 이용하여 자연수 $2^{{{exponent}}}$의 자릿수를 구하시오.",
                answer=str(answer),
                tags=["#상용로그", "#로그", "#로그의성질"],
                steps=[
                    ("주어진 수의 상용로그를 지수법칙으로 나타낸다.", rf"$\log(2^{{{exponent}}})={exponent}\log2$이다."),
                    ("주어진 근삿값을 곱한다.", rf"로그값은 ${log_value}$이다."),
                    ("양의 정수 N의 자릿수 공식을 적용한다.", r"자릿수는 $\lfloor\log N\rfloor+1$이다."),
                    ("로그값의 정수부분에 1을 더한다.", rf"따라서 자릿수는 ${answer}$이다."),
                ],
                alternatives=["$10^k\le2^n<10^{k+1}$을 로그 부등식으로 바꿔 같은 k를 찾을 수 있다."],
                answer_check=lambda n=exponent: _power_digit_count(n),
            )
        )
    division_rows = [
        ((-2, 1), (6, 5), 3, 1),
        ((3, -4), (-5, 8), 2, 5),
        ((0, 2), (8, -6), 4, 1),
        ((-7, -3), (1, 9), 5, 2),
        ((4, 6), (-2, -8), 3, 5),
    ]
    for index, (first, second, first_ratio, second_ratio) in enumerate(division_rows, 6):
        denominator = first_ratio - second_ratio
        x_value = Fraction(first_ratio * second[0] - second_ratio * first[0], denominator)
        y_value = Fraction(first_ratio * second[1] - second_ratio * first[1], denominator)
        answer = _external_division_sum(first, second, first_ratio, second_ratio)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"두 점 $A{first}$, $B{second}$를 잇는 선분을 ${first_ratio}:{second_ratio}$로 외분하는 점 P의 두 좌표의 합을 구하시오.",
                answer=str(answer),
                tags=["#외분점", "#좌표평면", "#내분점공식", "#선분의내분점"],
                steps=[
                    ("외분비의 두 수가 다른지 확인한다.", rf"분모는 ${first_ratio}-{second_ratio}={denominator}$이다."),
                    ("외분점 공식에 두 점과 비를 대입한다.", r"$P=(mB-nA)/(m-n)$을 사용한다."),
                    ("x좌표와 y좌표를 각각 계산한다.", rf"$P=({x_value},{y_value})$이다."),
                    ("두 좌표를 더한다.", rf"따라서 좌표의 합은 ${answer}$이다."),
                ],
                alternatives=["벡터 관계 $\overrightarrow{AP}:\overrightarrow{PB}=m:n$을 방향부호와 함께 세워 좌표를 구할 수 있다."],
                answer_check=lambda a=first, b=second, m=first_ratio, n=second_ratio: _external_division_sum(a, b, m, n),
            )
        )
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 삼차함수의 증분 극한과 포물선 복합이동이다. 작동 원리는 미분계수와 꼭짓점 변환 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    derivative_rows = [(1, -2, 3, 1, 2), (2, 1, -4, -1, 3), (-1, 3, 2, 2, -2), (3, -1, 0, -2, 2), (1, 4, -2, 3, -3)]
    for index, (cubic, quadratic, linear, point, scale) in enumerate(derivative_rows, 1):
        derivative = 3 * cubic * point**2 + 2 * quadratic * point + linear
        answer = _scaled_derivative_limit(cubic, quadratic, linear, point, scale)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"함수 $f(x)=({cubic})x^3+({quadratic})x^2+({linear})x$에 대하여 극한 $\lim_{{h\to0}}\dfrac{{f({point}+({scale})h)-f({point})}}{{h}}$의 값을 구하시오.",
                answer=str(answer),
                tags=["#미분계수의기하적의미", "#도함수공식", "#상수배의미분", "#함수의극한"],
                steps=[
                    ("분자의 증분을 표준 미분계수 꼴로 맞춘다.", rf"$u=({scale})h$로 두면 $u\to0$이다."),
                    ("분모 h와 새 증분 u의 비를 정리한다.", rf"원래 극한은 $({scale})f'({point})$이다."),
                    ("삼차함수를 항별로 미분한다.", rf"$f'(x)=({3 * cubic})x^2+({2 * quadratic})x+({linear})$이다."),
                    ("접점의 미분계수를 계산한다.", rf"$f'({point})={derivative}$이다."),
                    ("증분 배수를 곱한다.", rf"따라서 극한값은 ${answer}$이다."),
                ],
                alternatives=["f(p+kh)를 직접 전개해 h의 일차항만 남기고 h로 나눈 뒤 극한을 취할 수 있다."],
                answer_check=lambda a=cubic, b=quadratic, c=linear, p=point, k=scale: _scaled_derivative_limit(a, b, c, p, k),
            )
        )
    transform_rows = [(2, -3, 5, 1), (-4, 1, 2, -5), (5, 2, -3, 4), (-3, -2, 6, -1), (1, 4, -2, 3)]
    for index, (horizontal, vertical, shift_x, shift_y) in enumerate(transform_rows, 6):
        after_origin = (-horizontal, -vertical)
        final = (after_origin[0] + shift_x, after_origin[1] + shift_y)
        answer = _transformed_parabola_vertex_sum(horizontal, vertical, shift_x, shift_y)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"포물선 $y=(x-({horizontal}))^2+({vertical})$의 그래프를 원점에 대칭이동한 뒤 x방향으로 {shift_x}, y방향으로 {shift_y}만큼 평행이동했다. 최종 꼭짓점의 두 좌표의 합을 구하시오.",
                answer=str(answer),
                tags=["#이차함수의대칭이동", "#이차함수의평행이동", "#원점대칭", "#꼭짓점", "#대칭이동"],
                steps=[
                    ("원래 포물선의 꼭짓점을 읽는다.", rf"원래 꼭짓점은 $({horizontal},{vertical})$이다."),
                    ("원점대칭으로 두 좌표의 부호를 모두 바꾼다.", rf"꼭짓점은 ${after_origin}$가 된다."),
                    ("주어진 평행이동 벡터를 더한다.", rf"최종 꼭짓점은 ${final}$이다."),
                    ("변환 순서가 그래프 전체에 동일하게 적용됨을 확인한다.", "꼭짓점도 같은 점변환을 따른다."),
                    ("최종 두 좌표를 더한다.", rf"따라서 합은 ${answer}$이다."),
                ],
                alternatives=["변환된 함수식을 $y=-f(-x-shift)+shift$ 꼴로 만든 뒤 완전제곱해 꼭짓점을 구할 수 있다."],
                answer_check=lambda h=horizontal, v=vertical, x=shift_x, y=shift_y: _transformed_parabola_vertex_sum(h, v, x, y),
            )
        )
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 방향이 바뀌는 이차 속도와 두 근이 알려진 삼차다항식이다. 작동 원리는 거리·변위 차와 인수정리 보간 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    velocity_rows = [(1, 1, 3, 5), (2, 2, 4, 7), (3, 1, 4, 6), (1, 2, 5, 8), (2, 3, 6, 10)]
    for index, (scale, first, second, end) in enumerate(velocity_rows, 1):
        answer = _quadratic_velocity_gap(scale, first, second, end)
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"수직선 위 점 P의 속도가 $v(t)={scale}(t-{first})(t-{second})$일 때, $0\le t\le {end}$에서 총이동거리와 변위의 절댓값의 차를 구하시오.",
                answer=str(answer),
                tags=["#속도", "#속도와거리", "#위치변화량", "#정적분과속도", "#부정적분의정의"],
                steps=[
                    ("속도가 0인 두 시각으로 운동 구간을 나눈다.", rf"방향 전환 시각은 $t={first}, {second}$이다."),
                    ("세 구간에서 속도의 부호를 판정한다.", "양수·음수·양수 순서로 방향이 바뀐다."),
                    ("속도의 원시함수를 구한다.", "이차식을 전개해 세제곱·제곱·일차항으로 적분한다."),
                    ("각 구간의 변위를 구하고 절댓값을 더해 총거리를 계산한다.", "세 구간 이동량의 크기를 모두 합한다."),
                    ("전체 변위는 세 구간 변위의 부호 있는 합으로 계산한다.", "시작과 종료 위치의 차와 같다."),
                    ("총거리에서 전체 변위의 절댓값을 뺀다.", rf"따라서 차는 ${answer}$이다."),
                ],
                alternatives=[
                    "속도-시간 그래프에서 서로 반대 방향 영역 중 상쇄되는 넓이의 두 배로 계산할 수 있다.",
                    "위치함수를 네 경계 시각에 대입해 각 위치 차와 전체 위치 차를 비교할 수 있다.",
                ],
                answer_check=lambda k=scale, a=first, b=second, finish=end: _quadratic_velocity_gap(k, a, b, finish),
            )
        )
    interpolation_rows = [
        (-1, 2, 0, 8, 3),
        (1, 3, 0, 6, 4),
        (-2, 2, 1, 12, 3),
        (0, 4, 2, -20, 5),
        (-4, 1, 0, 12, 2),
    ]
    for index, (first, second, sample_x, sample_value, target_x) in enumerate(interpolation_rows, 6):
        denominator = (sample_x - first) * (sample_x - second)
        third_root = Fraction(sample_x, 1) - Fraction(sample_value, denominator)
        answer = _interpolated_cubic_value(first, second, sample_x, sample_value, target_x)
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"최고차항의 계수가 1인 삼차다항식 P(x)가 $P({first})=P({second})=0$, $P({sample_x})={sample_value}$를 만족할 때 $P({target_x})$의 값을 구하시오.",
                answer=str(answer),
                tags=["#인수정리증명", "#인수정리활용", "#항등식", "#항등식의성질", "#인수분해법"],
                steps=[
                    ("두 영점에 인수정리를 적용한다.", rf"$P(x)=(x-({first}))(x-({second}))Q(x)$이다."),
                    ("P가 최고차항 계수 1인 삼차식이므로 남은 인수를 정한다.", r"$Q(x)=x-u$인 일차식이다."),
                    ("알려진 함수값을 대입해 u에 대한 방정식을 세운다.", rf"$({sample_x}-({first}))({sample_x}-({second}))({sample_x}-u)={sample_value}$이다."),
                    ("방정식을 풀어 셋째 근을 구한다.", rf"$u={third_root}$이다."),
                    ("완성된 인수분해식에 목표 x값을 대입한다.", rf"$P({target_x})=({target_x}-({first}))({target_x}-({second}))({target_x}-({third_root}))$이다."),
                    ("세 인수의 곱을 계산해 원래 조건과 함께 검산한다.", rf"따라서 $P({target_x})={answer}$이다."),
                ],
                alternatives=[
                    "P(x)를 x³+ax²+bx+c로 두고 세 조건의 연립방정식을 풀 수 있다.",
                    "두 근의 곱으로 나눈 몫이 일차식임을 이용해 표본점에서 몫의 값을 바로 구할 수 있다.",
                ],
                answer_check=lambda a=first, b=second, s=sample_x, value=sample_value, target=target_x: _interpolated_cubic_value(a, b, s, value, target),
            )
        )
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v37 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v37 전체 카탈로그다. 작동 원리는 독립 정답 검산 후 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog = build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v37 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(
        catalog,
        expected_count=50,
        batch_id=BATCH_ID,
        model_name=MODEL_NAME,
        codebase_base=CODEBASE_BASE,
        seed_base=SEED_BASE,
    )


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v37 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(
        db_path,
        quests=validated_quests(),
        batch_id=BATCH_ID,
        validate_only=validate_only,
    )


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v37 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
