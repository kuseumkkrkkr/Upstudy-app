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

BATCH_ID = "marketplace-original-v18"
MODEL_NAME = "aiflow-direct-authoring-v18"
CODEBASE_BASE = 20_260_881_000
SEED_BASE = 202_607_460_000


def _checked_problem(
    tier: int,
    index: int,
    *,
    answer_check: Callable[[], Any],
    **kwargs: Any,
) -> dict[str, Any]:
    """필요 변수는 일반 문제 명세와 독립 정답 계산 함수다. 작동 원리는 저장되지 않는 검산 함수를 명세에 붙여 생산 검증 단계에서 실행한다."""
    spec = _problem(tier, index, **kwargs)
    spec["answer_check"] = answer_check
    return spec


def _quadratic_coefficient(left: tuple[int, int], right: tuple[int, int]) -> int:
    """필요 변수는 두 일차식의 상수항·일차항 계수다. 작동 원리는 배열 합성곱으로 곱의 이차항 계수를 독립 계산한다."""
    product = [0, 0, 0]
    for left_degree, left_value in enumerate(left):
        for right_degree, right_value in enumerate(right):
            product[left_degree + right_degree] += left_value * right_value
    return product[2]


def _integer_y_intercept(x_coefficient: int, y_coefficient: int, constant: int) -> int:
    """필요 변수는 직선의 세 계수다. 작동 원리는 x=0을 대입한 일차방정식을 유리수로 풀고 정수 절편을 확인한다."""
    del x_coefficient
    value = Fraction(constant, y_coefficient)
    if value.denominator != 1:
        raise ValueError("y절편이 정수가 아닙니다.")
    return value.numerator


def _exact_integer_log(base: int, value: int) -> int:
    """필요 변수는 정수 밑과 그 거듭제곱 값이다. 작동 원리는 반복 나눗셈으로 로그값을 부동소수점 없이 계산한다."""
    exponent = 0
    remaining = value
    while remaining > 1 and remaining % base == 0:
        remaining //= base
        exponent += 1
    if remaining != 1:
        raise ValueError(f"{value}는 {base}의 정수 거듭제곱이 아닙니다.")
    return exponent


def _internal_point_sum(
    point_a: tuple[int, int],
    point_b: tuple[int, int],
    left_ratio: int,
    right_ratio: int,
) -> int:
    """필요 변수는 두 끝점과 AP:PB 비다. 작동 원리는 내분점 좌표를 유리수로 계산해 두 좌표의 합을 반환한다."""
    denominator = left_ratio + right_ratio
    x = Fraction(right_ratio * point_a[0] + left_ratio * point_b[0], denominator)
    y = Fraction(right_ratio * point_a[1] + left_ratio * point_b[1], denominator)
    value = x + y
    if value.denominator != 1:
        raise ValueError("내분점 좌표합이 정수가 아닙니다.")
    return value.numerator


def _quadratic_limit(quadratic: int, linear: int, point: int) -> int:
    """필요 변수는 이차항·일차항 계수와 기준점이다. 작동 원리는 차분식의 h 일차항 계수를 소거한 뒤 h=0 계수를 읽는다."""
    difference_coefficients = [0, 2 * quadratic * point + linear, quadratic]
    quotient_coefficients = difference_coefficients[1:]
    return quotient_coefficients[0]


def _solve_linear_sum(
    first: tuple[int, int, int],
    second: tuple[int, int, int],
) -> int:
    """필요 변수는 두 일차방정식의 x·y·상수 계수다. 작동 원리는 크래머 공식으로 해를 구해 x+y를 정확한 유리수로 계산한다."""
    a1, b1, c1 = first
    a2, b2, c2 = second
    determinant = a1 * b2 - a2 * b1
    if determinant == 0:
        raise ValueError("연립방정식의 해가 하나로 정해지지 않습니다.")
    x = Fraction(c1 * b2 - c2 * b1, determinant)
    y = Fraction(a1 * c2 - a2 * c1, determinant)
    value = x + y
    if value.denominator != 1:
        raise ValueError("연립방정식 해의 합이 정수가 아닙니다.")
    return value.numerator


def _log_inequality_integer_count(base_denominator: int, shift: int, exponent: int) -> int:
    """필요 변수는 밑의 분모·진수 이동·지수 경계다. 작동 원리는 감소 로그의 진수 범위를 정수로 순회해 해의 개수를 센다."""
    upper = base_denominator ** (-exponent)
    return sum(1 for x in range(-shift + 1, upper - shift + 1) if 0 < x + shift <= upper)


def _induction_coefficient_sum(square_coefficient: int, linear_coefficient: int) -> int:
    """필요 변수는 항등식 우변의 두 계수다. 작동 원리는 n=1,2 조건의 연립방정식을 풀어 a+b를 독립 계산한다."""
    first_value = square_coefficient + linear_coefficient
    second_value = 4 * square_coefficient + 2 * linear_coefficient
    coefficient_a = second_value - 2 * first_value
    coefficient_b = first_value - coefficient_a
    return coefficient_a + coefficient_b


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 일차식의 계수와 직선의 일반형 계수다. 작동 원리는 미사용 태그 중심의 난이도 1 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    product_rows = [(2, 3, 4, -1), (-3, 5, 2, 7), (5, -2, -4, 3), (-2, -6, -5, -1), (7, 1, 3, -8)]
    for index, (left_x, left_constant, right_x, right_constant) in enumerate(product_rows, 1):
        answer = left_x * right_x
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"다항식 $(({left_x})x+({left_constant}))(({right_x})x+({right_constant}))$을 전개했을 때, $x^2$의 계수를 구하시오.",
                answer=str(answer),
                tags=["#다항식의곱셈"],
                steps=[
                    ("이차항은 두 일차항을 곱할 때 생김을 확인한다.", rf"$x^2$항은 $(({left_x})x)(({right_x})x)$에서 나온다."),
                    ("두 일차항의 계수를 곱한다.", rf"따라서 $x^2$의 계수는 $({left_x})({right_x})={answer}$이다."),
                ],
                answer_check=lambda a=left_x, b=left_constant, c=right_x, d=right_constant: _quadratic_coefficient((b, a), (d, c)),
            )
        )
    intercept_rows = [(2, 3, 18), (-1, 4, -20), (5, -2, 14), (3, -5, -25), (-4, 6, 42)]
    for index, (x_coefficient, y_coefficient, constant) in enumerate(intercept_rows, 6):
        answer = constant // y_coefficient
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"직선 $({x_coefficient})x+({y_coefficient})y={constant}$의 $y$절편을 구하시오.",
                answer=str(answer),
                tags=["#y절편"],
                steps=[
                    ("y축 위의 점에서는 x좌표가 0임을 이용한다.", rf"$x=0$을 대입하면 $({y_coefficient})y={constant}$이다."),
                    ("일차방정식을 풀어 y절편을 구한다.", rf"따라서 $y={answer}$이므로 $y$절편은 ${answer}$이다."),
                ],
                answer_check=lambda a=x_coefficient, b=y_coefficient, c=constant: _integer_y_intercept(a, b, c),
            )
        )
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 등차수열의 대칭항과 정확한 로그 진수다. 작동 원리는 미사용 태그 중심의 난이도 2 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    middle_rows = [(-4, 18), (3, 25), (-9, 15), (12, 40), (-20, 8)]
    for index, (first, third) in enumerate(middle_rows, 1):
        answer = (first + third) // 2
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"세 수 ${first},a,{third}$이 이 순서로 등차수열을 이룰 때, 등차중항 $a$를 구하시오.",
                answer=str(answer),
                tags=["#등차중항", "#등차수열"],
                steps=[
                    ("등차중항의 두 이웃과의 차가 같음을 이용한다.", rf"$a-({first})={third}-a$이다."),
                    ("양변의 a항을 한쪽으로 모은다.", rf"$2a={first}+({third})$이다."),
                    ("두 끝항의 합을 2로 나눈다.", rf"따라서 $a={answer}$이다."),
                ],
                answer_check=lambda left=first, right=third: [left, left + (right - left) // 2, right][1],
            )
        )
    logarithm_rows = [(2, 3, 4), (3, 2, 3), (5, 1, 3), (4, 2, 2), (2, 5, 2)]
    for index, (base, left_exponent, right_exponent) in enumerate(logarithm_rows, 6):
        left_value = base**left_exponent
        right_value = base**right_exponent
        answer = left_exponent + right_exponent
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"로그식 $\log_{{{base}}}{left_value}+\log_{{{base}}}{right_value}$의 값을 구하시오.",
                answer=str(answer),
                tags=["#로그의성질", "#로그법칙"],
                steps=[
                    ("같은 밑의 로그 덧셈을 진수의 곱으로 바꾼다.", rf"식은 $\log_{{{base}}}({left_value}\cdot {right_value})$이다."),
                    ("두 진수의 곱을 밑의 거듭제곱으로 나타낸다.", rf"${left_value}\cdot {right_value}={base}^{answer}$이다."),
                    ("로그의 정의로 지수를 읽는다.", rf"따라서 로그식의 값은 ${answer}$이다."),
                ],
                answer_check=lambda b=base, left=left_value, right=right_value: _exact_integer_log(b, left * right),
            )
        )
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 선분의 두 끝점·내분비와 두 무리수의 제곱이다. 작동 원리는 미사용 태그 중심의 난이도 3 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    division_rows = [
        ((0, 0), (6, 9), 1, 2),
        ((-3, 2), (9, 8), 1, 2),
        ((2, -4), (10, 8), 3, 1),
        ((-8, 9), (4, 0), 2, 1),
        ((-4, -2), (6, 8), 3, 2),
    ]
    for index, (point_a, point_b, left_ratio, right_ratio) in enumerate(division_rows, 1):
        answer = _internal_point_sum(point_a, point_b, left_ratio, right_ratio)
        denominator = left_ratio + right_ratio
        point_x = (right_ratio * point_a[0] + left_ratio * point_b[0]) // denominator
        point_y = (right_ratio * point_a[1] + left_ratio * point_b[1]) // denominator
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"점 $A({point_a[0]},{point_a[1]})$, $B({point_b[0]},{point_b[1]})$에 대하여 선분 $AB$를 $AP:PB={left_ratio}:{right_ratio}$로 내분하는 점을 $P(p,q)$라 할 때, $p+q$를 구하시오.",
                answer=str(answer),
                tags=["#선분의내분점", "#내분점공식", "#좌표평면"],
                steps=[
                    ("내분점의 x좌표 공식을 적용한다.", rf"$p=\dfrac{{{right_ratio}({point_a[0]})+{left_ratio}({point_b[0]})}}{{{denominator}}}={point_x}$이다."),
                    ("내분점의 y좌표 공식을 적용한다.", rf"$q=\dfrac{{{right_ratio}({point_a[1]})+{left_ratio}({point_b[1]})}}{{{denominator}}}={point_y}$이다."),
                    ("구한 좌표가 주어진 내분비 방향과 맞는지 확인한다.", rf"점 $P({point_x},{point_y})$는 A에서 B 쪽으로 ${left_ratio}:{right_ratio}$ 비율에 놓인다."),
                    ("내분점의 두 좌표를 더한다.", rf"따라서 $p+q={point_x}+({point_y})={answer}$이다."),
                ],
                alternatives=["x좌표와 y좌표를 각각 수직선 위의 내분 문제로 보고 같은 비율의 가중평균을 적용할 수 있다."],
                answer_check=lambda a=point_a, b=point_b, m=left_ratio, n=right_ratio: _internal_point_sum(a, b, m, n),
            )
        )
    rationalization_rows = [(7, 2), (11, 3), (13, 5), (17, 8), (19, 7)]
    for index, (radicand_left, radicand_right) in enumerate(rationalization_rows, 6):
        answer = radicand_left - radicand_right
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"양수 $a$에 대하여 $\dfrac1{{\sqrt{{{radicand_left}}}-\sqrt{{{radicand_right}}}}}=\dfrac{{\sqrt{{{radicand_left}}}+\sqrt{{{radicand_right}}}}}a$일 때, $a$를 구하시오.",
                answer=str(answer),
                tags=["#무리식", "#유리화", "#무리식의계산"],
                steps=[
                    ("분모의 켤레식을 분자와 분모에 곱한다.", rf"$\dfrac1{{\sqrt{{{radicand_left}}}-\sqrt{{{radicand_right}}}}}\cdot\dfrac{{\sqrt{{{radicand_left}}}+\sqrt{{{radicand_right}}}}}{{\sqrt{{{radicand_left}}}+\sqrt{{{radicand_right}}}}}$이다."),
                    ("분모에 차의 제곱 공식을 적용한다.", rf"분모는 ${radicand_left}-{radicand_right}={answer}$이다."),
                    ("유리화한 식을 주어진 우변과 비교한다.", rf"유리화 결과는 $\dfrac{{\sqrt{{{radicand_left}}}+\sqrt{{{radicand_right}}}}}{{{answer}}}$이다."),
                    ("분자가 같으므로 양의 분모를 확정한다.", rf"따라서 $a={answer}$이다."),
                ],
                alternatives=["두 변에 두 무리수의 차를 곱한 뒤 켤레곱이 두 제곱의 차가 됨을 이용할 수 있다."],
                answer_check=lambda left=radicand_left, right=radicand_right: left - right,
            )
        )
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 이차함수 차분식과 두 일차방정식이다. 작동 원리는 미사용 태그 중심의 난이도 4 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    limit_rows = [(2, -3, 1, 4), (-1, 5, 2, -2), (3, 4, -5, 1), (-2, -1, 6, 3), (4, -6, -2, -1)]
    for index, (quadratic, linear, constant, point) in enumerate(limit_rows, 1):
        answer = 2 * quadratic * point + linear
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"함수 $f(x)=({quadratic})x^2+({linear})x+({constant})$에 대하여 $\displaystyle\lim_{{h\to0}}\dfrac{{f({point}+h)-f({point})}}h$의 값을 구하시오.",
                answer=str(answer),
                tags=["#미분계수의정의", "#도함수의정의", "#극한값계산", "#미분계수"],
                steps=[
                    ("f(p+h)를 전개해 나타낸다.", rf"$f({point}+h)=({quadratic})({point}+h)^2+({linear})({point}+h)+({constant})$이다."),
                    ("f(p)를 빼고 동류항을 정리한다.", rf"$f({point}+h)-f({point})=h(({answer})+({quadratic})h)$이다."),
                    ("h가 0이 아닌 구간에서 공통인 h를 약분한다.", rf"$\dfrac{{f({point}+h)-f({point})}}h={answer}+({quadratic})h$이다."),
                    ("h가 0으로 갈 때 남는 항을 확인한다.", rf"$({quadratic})h$는 0으로 수렴한다."),
                    ("차분몫의 극한값을 계산한다.", rf"따라서 극한값은 ${answer}$이다."),
                ],
                alternatives=["미분계수의 정의에 해당하므로 먼저 도함수 $f'(x)$를 구한 뒤 $x=p$를 대입할 수 있다."],
                answer_check=lambda a=quadratic, b=linear, p=point: _quadratic_limit(a, b, p),
            )
        )
    system_rows = [
        ((1, 2), (3, -1), (2, 3)),
        ((2, 1), (1, -3), (-1, 4)),
        ((3, 2), (2, -1), (5, -2)),
        ((1, -2), (4, 1), (-3, -4)),
        ((2, 3), (-1, 4), (6, 1)),
    ]
    for index, (first_coefficients, second_coefficients, solution) in enumerate(system_rows, 6):
        first_constant = first_coefficients[0] * solution[0] + first_coefficients[1] * solution[1]
        second_constant = second_coefficients[0] * solution[0] + second_coefficients[1] * solution[1]
        answer = solution[0] + solution[1]
        first_equation = (first_coefficients[0], first_coefficients[1], first_constant)
        second_equation = (second_coefficients[0], second_coefficients[1], second_constant)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"연립방정식 $\begin{{cases}}({first_coefficients[0]})x+({first_coefficients[1]})y={first_constant}\\({second_coefficients[0]})x+({second_coefficients[1]})y={second_constant}\end{{cases}}$의 해를 $(p,q)$라 할 때, $p+q$를 구하시오.",
                answer=str(answer),
                tags=["#가우스소거법", "#행렬을이용한연립방정식", "#연립일차방정식과행렬", "#행렬의연산"],
                steps=[
                    ("두 방정식의 계수로 확대행렬을 만든다.", rf"$\left(\begin{{array}}{{cc|c}}{first_coefficients[0]}&{first_coefficients[1]}&{first_constant}\\{second_coefficients[0]}&{second_coefficients[1]}&{second_constant}\end{{array}}\right)$이다."),
                    ("한 미지수의 계수가 같아지도록 행을 정리한다.", "두 행의 적절한 배수를 더하거나 빼서 한 열의 성분을 0으로 만든다."),
                    ("소거된 일차방정식에서 y를 구한다.", rf"행 연산 결과 $y={solution[1]}$를 얻는다."),
                    ("구한 y를 원래 방정식에 대입해 x를 구한다.", rf"대입하면 $x={solution[0]}$이다."),
                    ("두 해를 요구한 순서로 더한다.", rf"따라서 $p+q={solution[0]}+({solution[1]})={answer}$이다."),
                ],
                alternatives=["행렬식이 0이 아님을 확인한 뒤 크래머 공식으로 x와 y를 각각 구할 수 있다."],
                answer_check=lambda first=first_equation, second=second_equation: _solve_linear_sum(first, second),
            )
        )
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 감소 로그의 진수 범위와 시그마 항등식의 두 계수다. 작동 원리는 미사용 태그 중심의 난이도 5 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    inequality_rows = [(2, 3, -2), (3, -1, -2), (2, -4, -3), (4, 2, -2), (3, 5, -3)]
    for index, (base_denominator, shift, exponent) in enumerate(inequality_rows, 1):
        upper = base_denominator ** (-exponent)
        answer = upper
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"로그부등식 $\log_{{1/{base_denominator}}}(x+({shift}))\ge {exponent}$을 만족하는 정수 $x$의 개수를 구하시오.",
                answer=str(answer),
                tags=["#로그부등식", "#로그함수의성질", "#진수조건", "#밑", "#로그함수"],
                steps=[
                    ("로그의 진수 조건을 먼저 적용한다.", rf"$x+({shift})>0$이다."),
                    ("밑이 0과 1 사이이므로 로그함수가 감소함을 확인한다.", rf"$0<1/{base_denominator}<1$이므로 부등호 방향이 지수식 변환에서 뒤집힌다."),
                    ("로그부등식을 진수의 범위로 바꾼다.", rf"$0<x+({shift})\le (1/{base_denominator})^{{{exponent}}}={upper}$이다."),
                    ("x의 정수 범위를 양 끝값으로 나타낸다.", rf"${-shift + 1}\le x\le {upper - shift}$이다."),
                    ("양 끝값을 포함한 정수의 개수를 계산한다.", rf"개수는 $({upper - shift})-({-shift + 1})+1$이다."),
                    ("정수 해의 총개수를 정리한다.", rf"따라서 정수 $x$는 모두 ${answer}$개이다."),
                ],
                alternatives=[
                    "진수 $y=x+s$를 양의 정수로 치환하면 $1$부터 상한까지 직접 셀 수 있다.",
                    "감소하는 로그함수의 그래프에서 수평선과의 위치 관계로 진수 구간을 확인할 수 있다.",
                ],
                answer_check=lambda base=base_denominator, s=shift, e=exponent: _log_inequality_integer_count(base, s, e),
            )
        )
    induction_rows = [(2, 5), (3, -1), (4, 7), (5, -3), (6, 1)]
    for index, (square_coefficient, linear_coefficient) in enumerate(induction_rows, 6):
        coefficient_a = 2 * square_coefficient
        coefficient_b = linear_coefficient - square_coefficient
        answer = coefficient_a + coefficient_b
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"모든 양의 정수 $n$에 대하여 $\displaystyle\sum_{{k=1}}^n(ak+b)={square_coefficient}n^2+({linear_coefficient})n$이 성립할 때, $a+b$를 구하시오.",
                answer=str(answer),
                tags=["#수학적귀납법", "#귀납법의원리", "#귀납법증명", "#시그마공식", "#일반항"],
                steps=[
                    ("n=1일 때의 항등식으로 첫 조건을 구한다.", rf"$a+b={square_coefficient}+({linear_coefficient})$이다."),
                    ("n일 때 항등식이 성립한다고 가정한다.", rf"$\sum_{{k=1}}^n(ak+b)={square_coefficient}n^2+({linear_coefficient})n$으로 둔다."),
                    ("n+1번째 항을 더해 좌변을 확장한다.", r"다음 합은 이전 합에 $a(n+1)+b$를 더한 값이다."),
                    ("우변의 n+1식과 n식의 차를 계산한다.", rf"차는 ${2 * square_coefficient}n+({square_coefficient + linear_coefficient})$이다."),
                    ("n의 계수와 상수항을 비교해 a와 b를 구한다.", rf"$a={coefficient_a}$이고 $a+b={square_coefficient + linear_coefficient}$이므로 $b={coefficient_b}$이다."),
                    ("두 계수를 더해 요구한 값을 계산한다.", rf"따라서 $a+b={coefficient_a}+({coefficient_b})={answer}$이다."),
                ],
                alternatives=[
                    "시그마 공식을 직접 적용해 n제곱항과 n항의 계수를 비교할 수 있다.",
                    "n=1과 n=2 두 경우에서 얻은 연립방정식만으로 a와 b를 먼저 구한 뒤 귀납 단계로 검산할 수 있다.",
                ],
                answer_check=lambda c=square_coefficient, d=linear_coefficient: _induction_coefficient_sum(c, d),
            )
        )
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v18 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v18 전체 카탈로그다. 작동 원리는 모든 정답 검산 함수를 실행한 뒤 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog = build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v18 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(catalog, expected_count=50, batch_id=BATCH_ID, model_name=MODEL_NAME, codebase_base=CODEBASE_BASE, seed_base=SEED_BASE)


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v18 전체 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(db_path, quests=validated_quests(), batch_id=BATCH_ID, validate_only=validate_only)


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v18 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
