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

BATCH_ID = "marketplace-original-v39"
MODEL_NAME = "aiflow-direct-authoring-v39"
CODEBASE_BASE = 20_261_000_000
SEED_BASE = 202_607_579_000


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


def _rational_difference(value: int, shift: int) -> Fraction:
    """필요 변수는 대입값과 분모 이동량이다. 작동 원리는 1/(x-a)-1/(x+a)를 정확한 분수로 통분한다."""
    if value in {shift, -shift}:
        raise ValueError("두 분모가 모두 0이 아니어야 합니다.")
    return Fraction(1, value - shift) - Fraction(1, value + shift)


def _matrix_difference_sum(
    first: tuple[tuple[int, int], tuple[int, int]],
    second: tuple[tuple[int, int], tuple[int, int]],
) -> int:
    """필요 변수는 같은 크기의 두 2×2 행렬이다. 작동 원리는 대응 성분을 뺀 뒤 네 성분을 모두 더한다."""
    return sum(
        first[row][column] - second[row][column]
        for row in range(2)
        for column in range(2)
    )


def _multiset_permutations(counts: tuple[int, ...]) -> int:
    """필요 변수는 같은 문자의 반복 개수들이다. 작동 원리는 전체 팩토리얼을 각 반복 개수의 팩토리얼 곱으로 나눈다."""
    if not counts or any(count <= 0 for count in counts):
        raise ValueError("각 반복 개수는 양수여야 합니다.")
    result = math.factorial(sum(counts))
    for count in counts:
        result //= math.factorial(count)
    return result


def _contrapositive_false_count(
    lower: int,
    upper: int,
    antecedent_modulus: int,
    consequent_modulus: int,
) -> int:
    """필요 변수는 정수 정의역과 두 배수 조건이다. 작동 원리는 원명제와 대우가 함께 거짓인 전건 참·후건 거짓 원소를 센다."""
    if lower > upper or antecedent_modulus <= 0 or consequent_modulus <= 0:
        raise ValueError("명제 조건이 올바르지 않습니다.")
    return sum(
        value % antecedent_modulus == 0 and value % consequent_modulus != 0
        for value in range(lower, upper + 1)
    )


def _integer_exponent_value(base: int, first: int, second: int, denominator: int) -> Fraction:
    """필요 변수는 양의 밑과 세 정수 지수다. 작동 원리는 곱셈·나눗셈의 지수법칙으로 하나의 정수 지수로 합친다."""
    if base <= 0:
        raise ValueError("밑은 양수여야 합니다.")
    exponent = first + second - denominator
    return Fraction(base, 1) ** exponent


def _quadratic_range_width(
    quadratic: int,
    horizontal: int,
    vertical: int,
    lower: int,
    upper: int,
) -> int:
    """필요 변수는 포물선 표준형과 닫힌 정의역이다. 작동 원리는 양 끝점과 구간 안 축의 함수값을 비교해 치역 폭을 구한다."""
    if quadratic == 0 or lower >= upper:
        raise ValueError("이차함수와 닫힌구간이 필요합니다.")
    candidates = [lower, upper]
    if lower <= horizontal <= upper:
        candidates.append(horizontal)
    values = [quadratic * (value - horizontal) ** 2 + vertical for value in candidates]
    return max(values) - min(values)


def _reflected_point_weighted_sum(point: tuple[int, int], line_constant: int) -> int:
    """필요 변수는 점과 직선 x+y=c의 상수다. 작동 원리는 수선의 중점 조건으로 반사점 (c-y,c-x)를 구해 p+2q를 계산한다."""
    reflected_x = line_constant - point[1]
    reflected_y = line_constant - point[0]
    return reflected_x + 2 * reflected_y


def _difference_of_squares_derivative(
    function_value: int,
    function_derivative: int,
    second_value: int,
    second_derivative: int,
) -> int:
    """필요 변수는 두 함수의 한 점 함수값과 미분계수다. 작동 원리는 (f+g)(f-g)=f²-g²를 미분해 값을 계산한다."""
    return 2 * function_value * function_derivative - 2 * second_value * second_derivative


def _matrix_equation_solution_sum(
    first: tuple[int, int, int, int],
    second: tuple[int, int, int, int],
    target: tuple[int, int],
) -> Fraction:
    """필요 변수는 두 2×2 행렬과 상수열이다. 작동 원리는 (A-B)X=C로 정리한 뒤 크래머 공식으로 두 미지수를 더한다."""
    a = first[0] - second[0]
    b = first[1] - second[1]
    c = first[2] - second[2]
    d = first[3] - second[3]
    determinant = a * d - b * c
    if determinant == 0:
        raise ValueError("A-B는 가역이어야 합니다.")
    x_value = Fraction(target[0] * d - b * target[1], determinant)
    y_value = Fraction(a * target[1] - target[0] * c, determinant)
    return x_value + y_value


def _integral_extrema_drop(first_turn: int, second_turn: int) -> Fraction:
    """필요 변수는 적분함수 도함수의 두 영점이다. 작동 원리는 F(a)-F(b)=-∫a^b(t-a)(t-b)dt를 정확히 계산한다."""
    if first_turn >= second_turn:
        raise ValueError("서로 다른 두 임계점이 필요합니다.")
    width = second_turn - first_turn
    return Fraction(width**3, 6)


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 합차 분모 유리식과 두 행렬이다. 작동 원리는 통분과 행렬 뺄셈 기초 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    rational_rows = [(5, 2), (7, 3), (-6, 1), (8, 5), (-9, 4)]
    for index, (value, shift) in enumerate(rational_rows, 1):
        answer = _rational_difference(value, shift)
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"유리식 $\dfrac1{{x-({shift})}}-\dfrac1{{x+({shift})}}$에 $x={value}$를 대입한 값을 구하시오.",
                answer=str(answer),
                tags=["#통분", "#합차공식", "#인수분해", "#유리식의계산"],
                steps=[
                    ("두 분모의 곱을 공통분모로 통분한다.", rf"분모는 $(x-({shift}))(x+({shift}))=x^2-{shift**2}$이다."),
                    ("분자를 정리한 뒤 x값을 대입한다.", rf"따라서 값은 ${answer}$이다."),
                ],
                answer_check=lambda x=value, a=shift: _rational_difference(x, a),
            )
        )
    matrix_rows = [
        (((1, 2), (3, 4)), ((4, -1), (2, 5))),
        (((-2, 5), (1, 3)), ((3, 2), (-4, 1))),
        (((6, 0), (-3, 2)), ((1, 4), (5, -2))),
        (((-5, 2), (7, 1)), ((2, -3), (4, 6))),
        (((3, 8), (-1, 5)), ((6, 1), (2, -4))),
    ]
    for index, (first, second) in enumerate(matrix_rows, 6):
        difference = tuple(
            tuple(first[row][column] - second[row][column] for column in range(2))
            for row in range(2)
        )
        answer = _matrix_difference_sum(first, second)
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"두 행렬 $A=\begin{{pmatrix}}{first[0][0]}&{first[0][1]}\\{first[1][0]}&{first[1][1]}\end{{pmatrix}}$, $B=\begin{{pmatrix}}{second[0][0]}&{second[0][1]}\\{second[1][0]}&{second[1][1]}\end{{pmatrix}}$에 대하여 A-B의 모든 성분의 합을 구하시오.",
                answer=str(answer),
                tags=["#행렬의뺄셈", "#행렬의연산", "#행렬", "#성분"],
                steps=[
                    ("같은 위치의 성분끼리 A에서 B를 뺀다.", rf"$A-B=\begin{{pmatrix}}{difference[0][0]}&{difference[0][1]}\\{difference[1][0]}&{difference[1][1]}\end{{pmatrix}}$이다."),
                    ("차행렬의 네 성분을 모두 더한다.", rf"따라서 합은 ${answer}$이다."),
                ],
                answer_check=lambda a=first, b=second: _matrix_difference_sum(a, b),
            )
        )
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 반복 문자 개수와 유한 정의역 배수명제다. 작동 원리는 중복순열과 대우의 거짓 사례 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    permutation_rows = [(3, 2, 1), (4, 2, 2), (3, 3, 2), (5, 2, 1), (4, 3, 2)]
    for index, counts in enumerate(permutation_rows, 1):
        total = sum(counts)
        answer = _multiset_permutations(counts)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"문자 A가 {counts[0]}개, B가 {counts[1]}개, C가 {counts[2]}개 있을 때, 이 {total}개 문자를 일렬로 나열하는 서로 다른 방법의 수를 구하시오.",
                answer=str(answer),
                tags=["#중복순열", "#순열", "#경우의수"],
                steps=[
                    ("모든 문자가 서로 다르다고 가정한 전체 순열 수를 구한다.", rf"전체는 ${total}!$이다."),
                    ("같은 문자끼리 바뀌어도 같은 배열이므로 각 반복 팩토리얼로 나눈다.", rf"${total}!/({counts[0]}!{counts[1]}!{counts[2]}!)$이다."),
                    ("팩토리얼을 계산하고 약분한다.", rf"따라서 방법은 ${answer}$가지이다."),
                ],
                answer_check=lambda values=counts: _multiset_permutations(values),
            )
        )
    proposition_rows = [(-12, 12, 2, 4), (-15, 15, 3, 6), (-20, 10, 4, 6), (-18, 18, 5, 10), (-10, 20, 6, 4)]
    for index, (lower, upper, first, second) in enumerate(proposition_rows, 6):
        counterexamples = [
            value
            for value in range(lower, upper + 1)
            if value % first == 0 and value % second != 0
        ]
        answer = _contrapositive_false_count(lower, upper, first, second)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"정의역 $U=\{{n\in\mathbb Z\mid {lower}\le n\le {upper}\}}$에서 명제 ‘n이 {first}의 배수이면 n은 {second}의 배수이다’와 그 대우가 동시에 거짓이 되는 n의 개수를 구하시오.",
                answer=str(answer),
                tags=["#대우", "#명제의역과대우", "#명제의참거짓", "#명제"],
                steps=[
                    ("원명제와 대우가 논리적으로 동치임을 확인한다.", "두 명제는 같은 n에서 같은 진리값을 갖는다."),
                    ("조건명제가 거짓인 전건 참·후건 거짓인 경우를 찾는다.", rf"해당 정수는 $\{{{','.join(map(str, counterexamples))}\}}$이다."),
                    ("정의역 안의 반례를 센다.", rf"따라서 동시에 거짓인 n은 ${answer}$개이다."),
                ],
                answer_check=lambda low=lower, high=upper, p=first, q=second: _contrapositive_false_count(low, high, p, q),
            )
        )
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 정수 지수식과 제한된 포물선 정의역이다. 작동 원리는 지수법칙과 치역 폭 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    exponent_rows = [(2, 3, -1, 5), (3, -2, 5, 1), (4, 2, 1, 6), (5, -1, -2, 3), (2, 6, -3, 1)]
    for index, (base, first, second, denominator) in enumerate(exponent_rows, 1):
        combined = first + second - denominator
        answer = _integer_exponent_value(base, first, second, denominator)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"정수 지수의 법칙을 이용하여 $\dfrac{{{base}^{first}\cdot {base}^{{{second}}}}}{{{base}^{denominator}}}$의 값을 구하시오.",
                answer=str(answer),
                tags=["#정수지수", "#지수", "#지수법칙의성질", "#지수의확장"],
                steps=[
                    ("같은 밑의 곱셈에서 지수를 더한다.", rf"분자의 지수는 ${first}+({second})={first + second}$이다."),
                    ("나눗셈에서 분모의 지수를 뺀다.", rf"전체 지수는 ${combined}$이다."),
                    ("지수가 음수이면 양의 지수의 역수로 바꾼다.", r"$a^{-n}=1/a^n$을 적용한다."),
                    ("거듭제곱 또는 기약분수를 계산한다.", rf"따라서 값은 ${answer}$이다."),
                ],
                alternatives=["각 거듭제곱을 분수로 직접 계산한 뒤 곱하고 나누어 검산할 수 있다."],
                answer_check=lambda a=base, p=first, q=second, r=denominator: _integer_exponent_value(a, p, q, r),
            )
        )
    range_rows = [(1, 2, -3, -1, 5), (-2, -1, 4, -4, 2), (3, 0, 1, -2, 3), (2, 4, -5, 1, 7), (-1, -3, 2, -6, 1)]
    for index, (quadratic, horizontal, vertical, lower, upper) in enumerate(range_rows, 6):
        candidates = [lower, upper] + ([horizontal] if lower <= horizontal <= upper else [])
        values = [quadratic * (value - horizontal) ** 2 + vertical for value in candidates]
        answer = _quadratic_range_width(quadratic, horizontal, vertical, lower, upper)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"정의역이 $[{lower},{upper}]$인 이차함수 $f(x)=({quadratic})(x-({horizontal}))^2+({vertical})$의 치역에서 최댓값과 최솟값의 차를 구하시오.",
                answer=str(answer),
                tags=["#치역", "#축", "#포물선", "#이차함수의최대최소", "#정의역에서의최대최소"],
                steps=[
                    ("포물선의 축과 꼭짓점을 표준형에서 읽는다.", rf"축은 $x={horizontal}$이고 꼭짓점 함수값은 ${vertical}$이다."),
                    ("축이 정의역 안에 있는지 확인하고 양 끝점도 후보로 둔다.", rf"후보 x값은 $\{{{','.join(map(str, candidates))}\}}$이다."),
                    ("후보점 함수값을 계산한다.", rf"후보 함수값은 $\{{{','.join(map(str, values))}\}}$이다."),
                    ("최댓값에서 최솟값을 뺀다.", rf"따라서 치역의 폭은 ${answer}$이다."),
                ],
                alternatives=["포물선의 증가·감소 방향을 축 기준으로 나누어 정의역 끝에서의 값을 비교할 수 있다."],
                answer_check=lambda a=quadratic, h=horizontal, k=vertical, low=lower, high=upper: _quadratic_range_width(a, h, k, low, high),
            )
        )
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 직선대칭 조건과 두 함수의 값·미분계수다. 작동 원리는 반사점과 합차 곱 미분 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    reflection_rows = [((2, 5), 4), ((-3, 1), 2), ((6, -2), 3), ((-4, -1), -2), ((3, 7), 1)]
    for index, (point, line_constant) in enumerate(reflection_rows, 1):
        reflected = (line_constant - point[1], line_constant - point[0])
        answer = _reflected_point_weighted_sum(point, line_constant)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"점 $P{point}$를 직선 $x+y={line_constant}$에 대하여 대칭이동한 점을 $Q(p,q)$라 할 때 $p+2q$를 구하시오.",
                answer=str(answer),
                tags=["#직선대칭", "#대칭이동", "#좌표평면", "#수직조건"],
                steps=[
                    ("직선 x+y=c의 법선벡터가 (1,1)임을 확인한다.", "점과 반사점을 잇는 선분은 주어진 직선에 수직이다."),
                    ("선분 PQ의 중점이 직선 위에 있다는 조건을 세운다.", "두 좌표의 중점 합이 c가 된다."),
                    ("대칭 변환 공식을 적용한다.", rf"$Q=({line_constant}-{point[1]},{line_constant}-{point[0]})={reflected}$이다."),
                    ("중점과 수직 조건을 다시 대입해 검산한다.", "PQ의 중점은 x+y=c 위에 놓인다."),
                    ("p+2q를 계산한다.", rf"따라서 값은 ${answer}$이다."),
                ],
                alternatives=["좌표를 법선 방향으로 투영한 거리를 두 배 이동해 반사점 좌표를 구할 수 있다."],
                answer_check=lambda p=point, c=line_constant: _reflected_point_weighted_sum(p, c),
            )
        )
    derivative_rows = [(2, 3, 1, -1), (-3, 2, 4, 1), (5, -2, -1, 3), (1, 4, 3, -2), (-2, -3, 5, 2)]
    for index, (f_value, f_derivative, g_value, g_derivative) in enumerate(derivative_rows, 6):
        answer = _difference_of_squares_derivative(f_value, f_derivative, g_value, g_derivative)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"미분가능한 함수 f, g가 $f(a)={f_value}$, $f'(a)={f_derivative}$, $g(a)={g_value}$, $g'(a)={g_derivative}$를 만족한다. $H(x)=(f(x)+g(x))(f(x)-g(x))$일 때 $H'(a)$를 구하시오.",
                answer=str(answer),
                tags=["#합차의미분", "#합차공식", "#도함수", "#미분계수", "#도함수공식"],
                steps=[
                    ("H의 두 인수가 합과 차임을 확인한다.", r"합차공식으로 $H(x)=f(x)^2-g(x)^2$이다."),
                    ("두 제곱함수를 미분한다.", r"$H'(x)=2f(x)f'(x)-2g(x)g'(x)$이다."),
                    ("x=a에서 주어진 네 값을 대입한다.", rf"$H'(a)=2({f_value})({f_derivative})-2({g_value})({g_derivative})$이다."),
                    ("두 항의 곱을 각각 계산한다.", "첫 항에서 둘째 항을 뺀다."),
                    ("결과를 정리한다.", rf"따라서 $H'(a)={answer}$이다."),
                ],
                alternatives=["처음부터 곱의 미분법을 적용한 뒤 동류항을 정리해도 같은 식을 얻는다."],
                answer_check=lambda f=f_value, fp=f_derivative, g=g_value, gp=g_derivative: _difference_of_squares_derivative(f, fp, g, gp),
            )
        )
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 행렬의 차로 만든 연립방정식과 적분함수 임계점이다. 작동 원리는 행렬 해와 기본정리 극값차 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    matrix_rows = [
        ((3, 1, 2, 2), (1, 0, 0, 0), (5, 4)),
        ((4, -1, 1, 3), (1, 1, -1, 1), (7, 2)),
        ((2, 3, -1, 4), (0, 1, 1, 1), (6, 5)),
        ((5, 2, 3, 1), (2, -1, 1, -2), (4, 7)),
        ((3, -2, 4, 5), (1, 1, 2, 1), (8, 3)),
    ]
    for index, (first, second, target) in enumerate(matrix_rows, 1):
        difference = (
            first[0] - second[0],
            first[1] - second[1],
            first[2] - second[2],
            first[3] - second[3],
        )
        determinant = difference[0] * difference[3] - difference[1] * difference[2]
        answer = _matrix_equation_solution_sum(first, second, target)
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"행렬 $A=\begin{{pmatrix}}{first[0]}&{first[1]}\\{first[2]}&{first[3]}\end{{pmatrix}}$, $B=\begin{{pmatrix}}{second[0]}&{second[1]}\\{second[2]}&{second[3]}\end{{pmatrix}}$와 열벡터 $C=\begin{{pmatrix}}{target[0]}\\{target[1]}\end{{pmatrix}}$에 대하여 $AX-BX=C$를 만족하는 $X=(x,y)^T$의 x+y를 구하시오.",
                answer=str(answer),
                tags=["#행렬을이용한연립방정식", "#행렬의뺄셈", "#행렬의연산", "#연립일차방정식과행렬", "#가우스소거법"],
                steps=[
                    ("분배법칙으로 AX-BX=(A-B)X로 묶는다.", "먼저 같은 위치의 행렬 성분끼리 뺀다."),
                    ("A-B를 계산한다.", rf"$A-B=\begin{{pmatrix}}{difference[0]}&{difference[1]}\\{difference[2]}&{difference[3]}\end{{pmatrix}}$이다."),
                    ("행렬 방정식을 두 개의 일차방정식으로 바꾼다.", rf"상수열은 $({target[0]},{target[1]})^T$이다."),
                    ("계수행렬의 행렬식을 확인한다.", rf"행렬식은 ${determinant}$이므로 유일한 해가 존재한다."),
                    ("가감법 또는 크래머 공식으로 x와 y를 구한다.", "두 미지수의 정확한 분수값을 얻는다."),
                    ("두 해를 더하고 원래 행렬식에 대입해 검산한다.", rf"따라서 $x+y={answer}$이다."),
                ],
                alternatives=[
                    "A-B의 역행렬을 C에 곱해 X를 바로 구할 수 있다.",
                    "두 행을 기본행연산으로 소거해 기약행사다리꼴을 만들 수 있다.",
                ],
                answer_check=lambda a=first, b=second, c=target: _matrix_equation_solution_sum(a, b, c),
            )
        )
    integral_rows = [(-2, 1), (-1, 3), (0, 4), (2, 5), (-3, 2)]
    for index, (first, second) in enumerate(integral_rows, 6):
        answer = _integral_extrema_drop(first, second)
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"함수 $F(x)=\int_0^x(t-({first}))(t-({second}))\,dt$에 대하여 $F({first})-F({second})$의 값을 구하시오.",
                answer=str(answer),
                tags=["#미적분의기본정리", "#정적분의성질", "#정적분의계산", "#함수의극대와극소", "#부정적분"],
                steps=[
                    ("적분구간의 차로 두 함수값의 차를 정리한다.", rf"$F({first})-F({second})=-\int_{{{first}}}^{{{second}}}(t-({first}))(t-({second}))dt$이다."),
                    ("두 근 사이에서 피적분함수의 부호를 판정한다.", "구간 내부에서는 두 인수의 부호가 반대이므로 곱이 음수이다."),
                    ("구간의 왼쪽 끝을 0으로 옮겨 치환한다.", rf"폭을 $w={second - first}$라 두면 적분은 $-\int_0^w u(u-w)du$이다."),
                    ("이차식을 전개해 원시함수를 구한다.", r"$-\int_0^w(u^2-wu)du$를 계산한다."),
                    ("양 끝값을 대입해 w에 대한 식을 얻는다.", r"결과는 $w^3/6$이다."),
                    ("구간 폭을 대입해 기약분수로 정리한다.", rf"따라서 함수값의 차는 ${answer}$이다."),
                ],
                alternatives=[
                    "미적분의 기본정리로 F'(x)=(x-a)(x-b)를 구해 두 극점 사이 함수값 변화를 적분할 수 있다.",
                    "F의 삼차 다항식 원시함수를 직접 구해 두 점에 대입할 수 있다.",
                ],
                answer_check=lambda a=first, b=second: _integral_extrema_drop(a, b),
            )
        )
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v39 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v39 전체 카탈로그다. 작동 원리는 독립 정답 검산 후 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog = build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v39 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(
        catalog,
        expected_count=50,
        batch_id=BATCH_ID,
        model_name=MODEL_NAME,
        codebase_base=CODEBASE_BASE,
        seed_base=SEED_BASE,
    )


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v39 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(
        db_path,
        quests=validated_quests(),
        batch_id=BATCH_ID,
        validate_only=validate_only,
    )


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v39 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
