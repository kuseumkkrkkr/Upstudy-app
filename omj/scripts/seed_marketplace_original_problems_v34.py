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

BATCH_ID = "marketplace-original-v34"
MODEL_NAME = "aiflow-direct-authoring-v34"
CODEBASE_BASE = 20_260_995_000
SEED_BASE = 202_607_574_000


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


def _linear_product_coefficient(first: tuple[int, int], second: tuple[int, int]) -> int:
    """필요 변수는 두 일차식의 계수쌍이다. 작동 원리는 교차곱 두 개을 더해 곱의 일차항 계수를 구한다."""
    return first[0] * second[1] + first[1] * second[0]


def _transformed_point_sum(point: tuple[int, int], shift: tuple[int, int]) -> int:
    """필요 변수는 원래 점과 평행이동 벡터다. 작동 원리는 x축 대칭·평행이동·y축 대칭을 차례로 적용해 최종 좌표를 더한다."""
    reflected_x = (point[0], -point[1])
    moved = (reflected_x[0] + shift[0], reflected_x[1] + shift[1])
    reflected_y = (-moved[0], moved[1])
    return reflected_y[0] + reflected_y[1]


def _division_constant_remainder_sum(linear: int, constant: int, root: int) -> int:
    """필요 변수는 이차식의 일차·상수항과 일차 나눗식의 근이다. 작동 원리는 조립제법으로 몫의 상수항과 나머지를 더한다."""
    quotient_constant = linear + root
    remainder = root**2 + linear * root + constant
    return quotient_constant + remainder


def _perpendicular_line_intersection_sum(
    first_x: int,
    first_y: int,
    first_constant: int,
    second_constant: int,
) -> Fraction:
    """필요 변수는 첫 직선의 두 계수와 두 상수다. 작동 원리는 서로 수직인 ax+by=c, bx-ay=d를 연립해 교점 좌표 합을 구한다."""
    denominator = first_x**2 + first_y**2
    if denominator == 0:
        raise ValueError("직선의 두 계수가 동시에 0일 수 없습니다.")
    x_value = Fraction(first_x * first_constant + first_y * second_constant, denominator)
    y_value = Fraction(first_y * first_constant - first_x * second_constant, denominator)
    return x_value + y_value


def _geometric_sum(first: int, ratio: int, count: int) -> int:
    """필요 변수는 첫째항·공비·항 개수다. 작동 원리는 등비수열 합 공식을 적용하고 직접 합산 결과와 같은 정수를 반환한다."""
    if count < 1 or ratio == 1:
        raise ValueError("항 개수는 양수이고 공비는 1이 아니어야 합니다.")
    return first * (ratio**count - 1) // (ratio - 1)


def _chained_log_value(
    first_numerator: int,
    first_denominator: int,
    second_numerator: int,
    second_denominator: int,
) -> Fraction:
    """필요 변수는 두 로그값의 분자·분모다. 작동 원리는 밑변환 관계 log_a(c)=log_a(b)log_b(c)로 두 분수를 곱한다."""
    return Fraction(first_numerator, first_denominator) * Fraction(second_numerator, second_denominator)


def _rational_difference_limit(first_leads: tuple[int, int], second_leads: tuple[int, int]) -> Fraction:
    """필요 변수는 두 이차 유리식의 최고차항 계수쌍이다. 작동 원리는 각 무한대 극한을 최고차항 계수비로 바꿔 뺀다."""
    first_numerator, first_denominator = first_leads
    second_numerator, second_denominator = second_leads
    if first_denominator == 0 or second_denominator == 0:
        raise ValueError("분모의 최고차항 계수는 0이 아니어야 합니다.")
    return Fraction(first_numerator, first_denominator) - Fraction(second_numerator, second_denominator)


def _quartic_extrema_sum(parameter: int) -> int:
    """필요 변수는 양의 매개변수다. 작동 원리는 x^4-2ax^2의 세 극점 함수값을 모두 더한다."""
    if parameter <= 0:
        raise ValueError("극점 매개변수는 양수여야 합니다.")
    return -2 * parameter**2


def _matrix_solution_trace(
    matrix: tuple[int, int, int, int],
    target: tuple[int, int, int, int],
) -> Fraction:
    """필요 변수는 2×2 가역행렬 A와 행렬 B의 성분이다. 작동 원리는 X=A^{-1}B의 두 대각성분을 크래머 공식으로 구해 더한다."""
    a, b, c, d = matrix
    e, f, g, h = target
    determinant = a * d - b * c
    if determinant == 0:
        raise ValueError("행렬 A는 가역이어야 합니다.")
    return Fraction(d * e - b * g - c * f + a * h, determinant)


def _exactly_one_event_count(
    singles: tuple[int, int, int],
    pairs: tuple[int, int, int],
    triple: int,
) -> int:
    """필요 변수는 세 사건·세 쌍의 교집합·삼중 교집합 크기다. 작동 원리는 각 사건만 단독으로 속한 원소 수를 포함배제로 합한다."""
    return sum(singles) - 2 * sum(pairs) + 3 * triple


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 일차식과 좌표변환 조건이다. 작동 원리는 곱셈과 대칭·평행이동 기초 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    product_rows = [(2, 3, 4, -1), (-1, 5, 3, 2), (4, -2, -3, 5), (3, 1, 2, 6), (-2, -3, 5, -4)]
    for index, (a, b, c, d) in enumerate(product_rows, 1):
        answer = _linear_product_coefficient((a, b), (c, d))
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"다항식 $(({a})x+({b}))(({c})x+({d}))$에서 x의 계수를 구하시오.",
                answer=str(answer),
                tags=["#다항식의곱셈", "#다항식", "#곱셈공식"],
                steps=[
                    ("x의 일차항을 만드는 두 교차곱을 찾는다.", rf"$(({a})x)({d})+({b})(({c})x)$이다."),
                    ("두 계수를 더해 x의 계수를 구한다.", rf"따라서 x의 계수는 ${answer}$이다."),
                ],
                answer_check=lambda first=(a, b), second=(c, d): _linear_product_coefficient(first, second),
            )
        )
    transform_rows = [((2, 3), (4, -1)), ((-3, 5), (2, 6)), ((4, -2), (-5, 3)), ((-1, -4), (6, 2)), ((5, 1), (-2, -7))]
    for index, (point, shift) in enumerate(transform_rows, 6):
        after_x = (point[0], -point[1])
        moved = (after_x[0] + shift[0], after_x[1] + shift[1])
        final = (-moved[0], moved[1])
        answer = _transformed_point_sum(point, shift)
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"점 $P{point}$를 x축에 대칭이동한 뒤 x방향으로 {shift[0]}, y방향으로 {shift[1]}만큼 평행이동하고 다시 y축에 대칭이동했다. 최종 점의 두 좌표의 합을 구하시오.",
                answer=str(answer),
                tags=["#대칭이동", "#x축대칭", "#y축대칭", "#x방향이동", "#y방향이동"],
                steps=[
                    ("세 좌표변환을 주어진 순서대로 적용한다.", rf"중간 좌표를 거쳐 최종 점은 ${final}$이다."),
                    ("최종 점의 두 좌표를 더한다.", rf"따라서 합은 ${answer}$이다."),
                ],
                answer_check=lambda p=point, move=shift: _transformed_point_sum(p, move),
            )
        )
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 이차다항식의 나눗셈과 수직인 두 직선이다. 작동 원리는 조립제법과 연립방정식 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    division_rows = [(3, 5, 2), (-2, 7, 3), (4, -3, -2), (1, 6, -3), (-5, 2, 4)]
    for index, (linear, constant, root) in enumerate(division_rows, 1):
        quotient_constant = linear + root
        remainder = root**2 + linear * root + constant
        answer = _division_constant_remainder_sum(linear, constant, root)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"다항식 $x^2+({linear})x+({constant})$를 $x-({root})$로 나눈 몫의 상수항과 나머지의 합을 구하시오.",
                answer=str(answer),
                tags=["#다항식의나눗셈", "#몫과나머지", "#나머지정리활용"],
                steps=[
                    ("조립제법으로 몫을 구한다.", rf"몫은 $x+({quotient_constant})$이다."),
                    ("나머지정리로 x에 나눗식의 근을 대입한다.", rf"나머지는 ${remainder}$이다."),
                    ("몫의 상수항과 나머지를 더한다.", rf"따라서 합은 ${answer}$이다."),
                ],
                answer_check=lambda a=linear, b=constant, r=root: _division_constant_remainder_sum(a, b, r),
            )
        )
    line_rows = [(1, 2, 5, 0), (2, 1, 7, -1), (3, -1, 8, 2), (2, -3, 1, 4), (-1, 4, 6, -3)]
    for index, (a, b, c, d) in enumerate(line_rows, 6):
        denominator = a**2 + b**2
        x_value = Fraction(a * c + b * d, denominator)
        y_value = Fraction(b * c - a * d, denominator)
        answer = _perpendicular_line_intersection_sum(a, b, c, d)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"서로 수직인 두 직선 $({a})x+({b})y={c}$, $({b})x-({a})y={d}$의 교점을 $(p,q)$라 할 때 $p+q$를 구하시오.",
                answer=str(answer),
                tags=["#두직선의위치관계", "#수직조건", "#직선의방정식"],
                steps=[
                    ("두 직선의 계수로 연립일차방정식을 세운다.", rf"계수 제곱합은 ${denominator}$이다."),
                    ("가감법으로 교점 좌표를 구한다.", rf"$p={x_value}$, $q={y_value}$이다."),
                    ("두 좌표를 더한다.", rf"따라서 $p+q={answer}$이다."),
                ],
                answer_check=lambda x=a, y=b, first=c, second=d: _perpendicular_line_intersection_sum(x, y, first, second),
            )
        )
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 유한 등비수열과 연쇄 로그값이다. 작동 원리는 등비합과 밑변환 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    sequence_rows = [(2, 3, 6), (5, 2, 7), (3, 4, 5), (-2, 3, 5), (7, 2, 6)]
    for index, (first, ratio, count) in enumerate(sequence_rows, 1):
        last = first * ratio ** (count - 1)
        answer = _geometric_sum(first, ratio, count)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"첫째항이 {first}, 공비가 {ratio}인 등비수열의 첫째항부터 제{count}항까지의 합을 구하시오.",
                answer=str(answer),
                tags=["#등비수열", "#공비", "#등비수열의합", "#항"],
                steps=[
                    ("등비수열의 마지막 항을 확인한다.", rf"제{count}항은 ${last}$이다."),
                    ("유한 등비수열 합 공식을 세운다.", r"$S_n=a(r^n-1)/(r-1)$을 사용한다."),
                    ("첫째항·공비·항 개수를 대입한다.", rf"$S_{count}={first}({ratio}^{count}-1)/({ratio}-1)$이다."),
                    ("거듭제곱과 나눗셈을 계산한다.", rf"따라서 합은 ${answer}$이다."),
                ],
                alternatives=["각 항을 공비만큼 차례로 곱해 나열한 뒤 직접 더해 검산할 수 있다."],
                answer_check=lambda a=first, r=ratio, n=count: _geometric_sum(a, r, n),
            )
        )
    log_rows = [(2, 3, 3, 4), (3, 2, 5, 3), (4, 5, 2, 3), (5, 2, 3, 7), (7, 4, 5, 6)]
    for index, (p, q, r, s) in enumerate(log_rows, 6):
        answer = _chained_log_value(p, q, r, s)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"$a,b,c>0$이고 $a,b\ne1$일 때 $\log_a b={p}/{q}$, $\log_b c={r}/{s}$이다. $\log_a c$의 값을 구하시오.",
                answer=str(answer),
                tags=["#로그", "#밑의변환", "#로그의성질", "#로그함수의성질"],
                steps=[
                    ("구하려는 로그의 밑을 a로 통일한다.", r"$\log_a c=\log_a b\cdot\log_b c$이다."),
                    ("주어진 두 로그값을 대입한다.", rf"$\log_a c=({p}/{q})({r}/{s})$이다."),
                    ("분자끼리, 분모끼리 곱한다.", rf"곱은 ${p * r}/{q * s}$이다."),
                    ("분수를 기약분수로 정리한다.", rf"따라서 $\log_a c={answer}$이다."),
                ],
                alternatives=["밑변환 공식으로 두 로그를 자연로그의 비로 바꾸면 중간의 ln b가 약분된다."],
                answer_check=lambda a=p, b=q, c=r, d=s: _chained_log_value(a, b, c, d),
            )
        )
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 이차 유리식과 짝수차 함수다. 작동 원리는 무한대 최고차항 비교와 도함수 부호 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    limit_rows = [
        ((2, 1, -3, 3, 4, 1), (1, -2, 5, 4, 3, -1)),
        ((-3, 2, 1, 2, -1, 4), (2, 5, -2, 5, 1, 3)),
        ((5, -1, 2, 4, 2, 3), (-2, 3, 1, 3, -4, 2)),
        ((1, 4, -5, 2, 3, 1), (3, -2, 4, 7, 1, -3)),
        ((-4, 2, 6, 3, -1, 5), (1, 4, -2, 2, 3, 1)),
    ]
    for index, (first, second) in enumerate(limit_rows, 1):
        a, b, c, d, e, f = first
        p, q, r, s, t, u = second
        answer = _rational_difference_limit((a, d), (p, s))
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"극한 $\lim_{{x\to\infty}}\left(\dfrac{{{a}x^2+({b})x+({c})}}{{{d}x^2+({e})x+({f})}}-\dfrac{{{p}x^2+({q})x+({r})}}{{{s}x^2+({t})x+({u})}}\right)$의 값을 구하시오.",
                answer=str(answer),
                tags=["#무한대의극한", "#극한의사칙연산", "#극한의정의", "#극한값계산"],
                steps=[
                    ("각 분수의 분자와 분모를 x의 최고차수로 나눈다.", r"모든 항을 $x^2$으로 나눈다."),
                    ("x가 무한대로 갈 때 일차·상수항의 비가 0으로 감을 이용한다.", "각 분수에는 최고차항 계수만 남는다."),
                    ("첫 번째 유리식의 극한을 구한다.", rf"첫 극한은 ${Fraction(a, d)}$이다."),
                    ("두 번째 유리식의 극한을 구한다.", rf"둘째 극한은 ${Fraction(p, s)}$이다."),
                    ("극한의 차를 계산한다.", rf"따라서 전체 극한은 ${answer}$이다."),
                ],
                alternatives=["두 유리식을 먼저 통분한 뒤 합쳐진 분자·분모의 최고차항 계수비를 계산할 수 있다."],
                answer_check=lambda left=(a, d), right=(p, s): _rational_difference_limit(left, right),
            )
        )
    extrema_rows = [2, 3, 4, 5, 6]
    for index, parameter in enumerate(extrema_rows, 6):
        answer = _quartic_extrema_sum(parameter)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"함수 $f(x)=x^4-{2 * parameter}x^2$의 모든 극대점과 극소점에서의 함수값을 각각 한 번씩 더한 값을 구하시오.",
                answer=str(answer),
                tags=["#함수의극대와극소", "#도함수의부호", "#극값의판정", "#극댓값", "#극솟값", "#미분과최대최소"],
                steps=[
                    ("함수를 미분하고 인수분해한다.", rf"$f'(x)=4x(x^2-{parameter})$이다."),
                    ("도함수가 0인 세 점을 구한다.", rf"$x=0,\pm\sqrt{{{parameter}}}$이다."),
                    ("세 구간 사이에서 도함수의 부호 변화를 판정한다.", "가운데 점은 극대점이고 양옆 두 점은 극소점이다."),
                    ("각 극점의 함수값을 계산한다.", rf"극댓값은 0, 두 극솟값은 각각 $-{parameter**2}$이다."),
                    ("세 함수값을 모두 더한다.", rf"따라서 합은 ${answer}$이다."),
                ],
                alternatives=["짝함수 그래프의 대칭성을 이용하면 양쪽 두 극솟값이 같음을 먼저 알 수 있다."],
                answer_check=lambda a=parameter: _quartic_extrema_sum(a),
            )
        )
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 가역행렬 방정식과 세 사건의 교집합 수다. 작동 원리는 역행렬과 포함배제 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    matrix_rows = [
        ((2, 1, 1, 1), (3, 2, 1, 4)),
        ((3, -1, 2, 1), (4, 1, -2, 6)),
        ((1, 2, -1, 3), (5, -2, 4, 1)),
        ((4, 1, 2, 3), (-1, 5, 3, 2)),
        ((2, -3, 1, 2), (6, 1, -2, 7)),
    ]
    for index, (matrix, target) in enumerate(matrix_rows, 1):
        a, b, c, d = matrix
        e, f, g, h = target
        determinant = a * d - b * c
        answer = _matrix_solution_trace(matrix, target)
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"행렬 $A=\begin{{pmatrix}}{a}&{b}\\{c}&{d}\end{{pmatrix}}$, $B=\begin{{pmatrix}}{e}&{f}\\{g}&{h}\end{{pmatrix}}$에 대하여 $AX=B$를 만족하는 2×2 행렬 X의 대각합을 구하시오.",
                answer=str(answer),
                tags=["#역행렬", "#역행렬구하기", "#역행렬의정의", "#역행렬의성질", "#성분", "#연립일차방정식과행렬"],
                steps=[
                    ("행렬 A의 행렬식을 계산한다.", rf"$\det A={a}({d})-({b})({c})={determinant}$이다."),
                    ("행렬식이 0이 아니므로 역행렬이 존재함을 확인한다.", "따라서 양변의 왼쪽에 A의 역행렬을 곱할 수 있다."),
                    ("2×2 역행렬 공식을 적용한다.", rf"$A^{{-1}}=\dfrac1{{{determinant}}}\begin{{pmatrix}}{d}&{-b}\\{-c}&{a}\end{{pmatrix}}$이다."),
                    ("$X=A^{-1}B$를 계산한다.", "행과 열의 대응 성분을 곱해 X의 성분을 구한다."),
                    ("X의 두 대각성분만 골라 더한다.", rf"대각합은 $({d * e - b * g - c * f + a * h})/{determinant}$이다."),
                    ("분수를 기약분수로 정리해 검산한다.", rf"따라서 X의 대각합은 ${answer}$이다."),
                ],
                alternatives=[
                    "AX=B의 각 열을 서로 독립인 두 연립일차방정식으로 풀어 X를 구할 수 있다.",
                    "대각합의 선형성을 이용해 A^{-1}B의 대각성분 계산만 수행할 수 있다.",
                ],
                answer_check=lambda left=matrix, right=target: _matrix_solution_trace(left, right),
            )
        )
    event_rows = [
        ((40, 35, 30), (15, 12, 10), 5),
        ((50, 45, 25), (20, 15, 10), 4),
        ((28, 32, 36), (8, 9, 11), 3),
        ((60, 40, 30), (25, 18, 12), 7),
        ((45, 38, 33), (14, 13, 9), 2),
    ]
    for index, (singles, pairs, triple) in enumerate(event_rows, 6):
        a, b, c = singles
        ab, ac, bc = pairs
        only_a = a - ab - ac + triple
        only_b = b - ab - bc + triple
        only_c = c - ac - bc + triple
        answer = _exactly_one_event_count(singles, pairs, triple)
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"유한 표본공간의 세 사건 A, B, C가 $|A|={a}$, $|B|={b}$, $|C|={c}$, $|A\cap B|={ab}$, $|A\cap C|={ac}$, $|B\cap C|={bc}$, $|A\cap B\cap C|={triple}$을 만족한다. 정확히 한 사건에만 속하는 원소의 수를 구하시오.",
                answer=str(answer),
                tags=["#사건의합", "#사건의곱", "#여집합", "#합의법칙"],
                steps=[
                    ("A에만 속하는 원소 수를 포함배제로 구한다.", rf"${a}-{ab}-{ac}+{triple}={only_a}$이다."),
                    ("B에만 속하는 원소 수를 구한다.", rf"${b}-{ab}-{bc}+{triple}={only_b}$이다."),
                    ("C에만 속하는 원소 수를 구한다.", rf"${c}-{ac}-{bc}+{triple}={only_c}$이다."),
                    ("세 단독 영역이 서로 겹치지 않음을 확인한다.", "정확히 한 사건에 속하는 경우는 세 영역의 합이다."),
                    ("세 단독 영역의 크기를 더한다.", rf"${only_a}+{only_b}+{only_c}={answer}$이다."),
                    ("전체 포함배제식으로 다시 검산한다.", rf"$|A|+|B|+|C|-2\sum|교집합|+3|A\cap B\cap C|={answer}$이다."),
                ],
                alternatives=[
                    "벤다이어그램의 일곱 영역을 중심의 삼중 교집합부터 바깥쪽으로 채울 수 있다.",
                    "각 원소의 소속 사건 수를 가중치로 세어 정확히 한 번 센 원소만 분리할 수 있다.",
                ],
                answer_check=lambda one=singles, two=pairs, three=triple: _exactly_one_event_count(one, two, three),
            )
        )
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v34 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v34 전체 카탈로그다. 작동 원리는 독립 정답 검산 후 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog = build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v34 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(
        catalog,
        expected_count=50,
        batch_id=BATCH_ID,
        model_name=MODEL_NAME,
        codebase_base=CODEBASE_BASE,
        seed_base=SEED_BASE,
    )


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v34 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(
        db_path,
        quests=validated_quests(),
        batch_id=BATCH_ID,
        validate_only=validate_only,
    )


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v34 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
