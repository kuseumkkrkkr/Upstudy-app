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

BATCH_ID = "marketplace-original-v23"
MODEL_NAME = "aiflow-direct-authoring-v23"
CODEBASE_BASE = 20_260_984_000
SEED_BASE = 202_607_563_000


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


def _proper_subset_count(lower: int, upper: int) -> int:
    """필요 변수는 연속한 정수 집합의 양 끝값이다. 작동 원리는 원소 수를 세고 전체 부분집합에서 자기 자신 하나를 제외한다."""
    element_count = upper - lower + 1
    if element_count < 0:
        raise ValueError("집합의 범위가 뒤집혔습니다.")
    return 2**element_count - 1


def _matrix_difference_row_sum(
    left: tuple[tuple[int, int], tuple[int, int]],
    right: tuple[tuple[int, int], tuple[int, int]],
) -> int:
    """필요 변수는 두 2행 2열 행렬이다. 작동 원리는 대응 성분을 빼 첫 번째 행의 두 성분을 더한다."""
    first_row = tuple(left[0][column] - right[0][column] for column in range(2))
    return sum(first_row)


def _cube_factor_linear_coefficient(shift: int) -> int:
    """필요 변수는 두 세제곱 합의 상수다. 작동 원리는 합의 세제곱 인수분해 공식에서 이차인수의 일차항 계수를 구한다."""
    return -shift


def _repeated_selection_total(symbols: int, length: int) -> int:
    """필요 변수는 기호 종류 수와 선택 길이다. 작동 원리는 중복순열 수와 중복조합 수를 독립 계산해 더한다."""
    return symbols**length + math.comb(symbols + length - 1, length)


def _double_root_constant(linear_sum: int) -> int:
    """필요 변수는 이차방정식의 두 근 합이다. 작동 원리는 판별식이 0인 조건으로 상수항을 계산한다."""
    if linear_sum % 2:
        raise ValueError("정수 중근을 만들려면 두 근의 합이 짝수여야 합니다.")
    return (linear_sum // 2) ** 2


def _line_intersection_sum(
    slope_first: int,
    point_x: int,
    point_y: int,
    slope_second: int,
    intercept: int,
) -> Fraction:
    """필요 변수는 점기울기형 직선과 기울기절편형 직선이다. 작동 원리는 두 식을 연립해 교점 좌표의 합을 정확히 구한다."""
    denominator = slope_first - slope_second
    if denominator == 0:
        raise ValueError("두 직선이 평행해 교점이 없습니다.")
    x = Fraction(intercept - point_y + slope_first * point_x, denominator)
    y = slope_second * x + intercept
    return x + y


def _exponential_shift_value(base: int, horizontal: int, vertical: int) -> int:
    """필요 변수는 지수함수의 밑과 가로·세로 이동량이다. 작동 원리는 x=h+1을 대입해 정수지수 값을 계산한다."""
    return base + vertical


def _logarithm_shift_intercept(base: int, horizontal: int, vertical: int) -> Fraction:
    """필요 변수는 로그함수의 밑과 가로·세로 이동량이다. 작동 원리는 y=0을 놓고 로그 정의로 x절편을 계산한다."""
    return Fraction(horizontal, 1) + Fraction(1, base**vertical)


def _quadratic_maximum(a: int, b: int, c: int) -> Fraction:
    """필요 변수는 아래로 열린 이차함수의 양의 크기 a와 나머지 계수다. 작동 원리는 도함수가 0인 꼭짓점에서 최댓값을 구한다."""
    if a <= 0:
        raise ValueError("a는 양수여야 합니다.")
    vertex = Fraction(b, 2 * a)
    return -a * vertex**2 + b * vertex + c


def _antiderivative_origin(a: int, b: int, c: int, point: int, value: int) -> int:
    """필요 변수는 도함수 계수와 한 점에서의 원시함수 값이다. 작동 원리는 일반 원시함수에 조건을 대입해 F(0)의 적분상수를 구한다."""
    polynomial_value = a * point**3 + b * point**2 + c * point
    return value - polynomial_value


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 조건제시 집합의 경계와 두 행렬이다. 작동 원리는 미사용 태그를 다루는 난이도 1 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    for index, (lower, upper) in enumerate([(1, 3), (2, 5), (-2, 2), (4, 9), (-3, 3)], 1):
        count = upper - lower + 1
        answer = _proper_subset_count(lower, upper)
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"조건제시법으로 나타낸 집합 $A=\{{x\mid x$는 정수, ${lower}\le x\le {upper}\}}$의 진부분집합의 개수를 구하시오.",
                answer=str(answer),
                tags=["#진부분집합", "#집합의포함관계", "#조건제시법", "#공통수학1"],
                steps=[
                    ("조건을 만족하는 집합 A의 원소 수를 센다.", rf"${lower}$부터 ${upper}$까지 정수는 ${count}$개이다."),
                    ("전체 부분집합에서 A 자신을 제외한다.", rf"따라서 진부분집합은 $2^{count}-1={answer}$개이다."),
                ],
                answer_check=lambda left=lower, right=upper: _proper_subset_count(left, right),
            )
        )
    matrix_rows = [
        (((3, 7), (1, 4)), ((1, 2), (0, 3))),
        (((-2, 8), (5, 1)), ((3, -1), (2, 4))),
        (((6, -3), (2, 9)), ((-1, 4), (7, 0))),
        (((5, 2), (-4, 6)), ((2, -5), (1, 3))),
        (((-3, 10), (8, -2)), ((4, 1), (-1, 5))),
    ]
    for index, (left, right) in enumerate(matrix_rows, 6):
        first_left = left[0][0] - right[0][0]
        second_left = left[0][1] - right[0][1]
        answer = _matrix_difference_row_sum(left, right)
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"두 행렬 $A=\begin{{pmatrix}}{left[0][0]}&{left[0][1]}\\{left[1][0]}&{left[1][1]}\end{{pmatrix}}$, $B=\begin{{pmatrix}}{right[0][0]}&{right[0][1]}\\{right[1][0]}&{right[1][1]}\end{{pmatrix}}$에 대하여 $A-B$의 첫째 행 성분의 합을 구하시오.",
                answer=str(answer),
                tags=["#행", "#열", "#행렬", "#행렬의뺄셈", "#행렬의정의", "#공통수학2"],
                steps=[
                    ("같은 행과 열에 놓인 성분끼리 뺀다.", rf"첫째 행은 $({first_left},{second_left})$이다."),
                    ("첫째 행의 두 성분을 더한다.", rf"따라서 구하는 합은 ${first_left}+({second_left})={answer}$이다."),
                ],
                answer_check=lambda first=left, second=right: _matrix_difference_row_sum(first, second),
            )
        )
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 세제곱 합의 상수와 중복 선택 조건이다. 작동 원리는 미사용 태그를 다루는 난이도 2 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    for index, shift in enumerate([2, 3, 4, 5, 6], 1):
        answer = _cube_factor_linear_coefficient(shift)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"항등식 $x^3+{shift**3}=(x+{shift})(x^2+px+{shift**2})$가 성립할 때, 상수 $p$를 구하시오.",
                answer=str(answer),
                tags=["#세제곱공식", "#인수분해법", "#대수", "#인수정리증명", "#나머지정리증명"],
                steps=[
                    ("x=-a를 대입해 일차인수가 되는 이유를 확인한다.", rf"$(-{shift})^3+{shift**3}=0$이므로 인수정리에 따라 $x+{shift}$는 인수이다."),
                    ("세제곱의 합 공식을 적용한다.", rf"$x^3+{shift}^3=(x+{shift})(x^2-{shift}x+{shift**2})$이다."),
                    ("이차인수의 일차항 계수를 비교한다.", rf"따라서 $p={answer}$이다."),
                ],
                answer_check=lambda value=shift: _cube_factor_linear_coefficient(value),
            )
        )
    for index, (symbols, length) in enumerate([(3, 2), (4, 3), (5, 2), (3, 4), (6, 2)], 6):
        sequence_count = symbols**length
        multiset_count = math.comb(symbols + length - 1, length)
        answer = _repeated_selection_total(symbols, length)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"서로 다른 ${symbols}$종류의 기호에서 중복을 허용해 길이 ${length}$인 문자열을 만드는 경우의 수와, 순서를 무시하고 ${length}$개를 고르는 경우의 수의 합을 구하시오.",
                answer=str(answer),
                tags=["#중복순열", "#중복조합"],
                steps=[
                    ("순서를 구별하는 중복순열 수를 계산한다.", rf"각 자리마다 ${symbols}$가지이므로 ${symbols}^{length}={sequence_count}$가지이다."),
                    ("순서를 무시하는 중복조합 수를 계산한다.", rf"$\binom{{{symbols}+{length}-1}}{{{length}}}={multiset_count}$가지이다."),
                    ("서로 다른 두 경우의 수를 더한다.", rf"따라서 요구한 합은 ${sequence_count}+{multiset_count}={answer}$이다."),
                ],
                answer_check=lambda n=symbols, r=length: _repeated_selection_total(n, r),
            )
        )
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 이차방정식의 일차항과 두 직선 조건이다. 작동 원리는 미사용 태그를 다루는 난이도 3 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    for index, linear_sum in enumerate([6, 8, 10, 12, 14], 1):
        root = linear_sum // 2
        answer = _double_root_constant(linear_sum)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"이차방정식 $x^2-{linear_sum}x+k=0$이 중근을 가질 때, 상수 $k$를 구하시오.",
                answer=str(answer),
                tags=["#이차방정식의근과계수", "#이차방정식의풀이", "#중근조건"],
                steps=[
                    ("중근 조건을 판별식으로 나타낸다.", rf"판별식은 $D=(-{linear_sum})^2-4k$이고 중근이면 $D=0$이다."),
                    ("판별식 방정식을 정리한다.", rf"${linear_sum**2}-4k=0$이다."),
                    ("근과 계수의 관계로도 중근을 확인한다.", rf"두 근의 합이 ${linear_sum}$이므로 중근은 ${root}$이다."),
                    ("중근의 곱을 상수항으로 계산한다.", rf"따라서 $k={root}^2={answer}$이다."),
                ],
                alternatives=["완전제곱식 $(x-r)^2$의 전개식과 계수를 직접 비교할 수 있다."],
                answer_check=lambda value=linear_sum: _double_root_constant(value),
            )
        )
    line_rows = [
        (2, 1, 3, 1, 4),
        (3, -1, 2, 2, 1),
        (-2, 2, 1, 1, 3),
        (4, 0, -1, -2, 7),
        (-3, 1, 4, 2, -5),
    ]
    for index, (first_slope, point_x, point_y, second_slope, intercept) in enumerate(line_rows, 6):
        denominator = first_slope - second_slope
        x = Fraction(intercept - point_y + first_slope * point_x, denominator)
        y = second_slope * x + intercept
        answer = _line_intersection_sum(first_slope, point_x, point_y, second_slope, intercept)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"두 직선 $y-({point_y})={first_slope}(x-({point_x}))$와 $y={second_slope}x+({intercept})$의 교점을 $P(p,q)$라 할 때, $p+q$를 구하시오.",
                answer=str(answer),
                tags=["#두직선의위치관계", "#점기울기형", "#절편"],
                steps=[
                    ("첫 번째 직선이 점기울기형임을 확인한다.", rf"기울기는 ${first_slope}$이고 점 $({point_x},{point_y})$를 지난다."),
                    ("두 직선의 기울기가 달라 한 점에서 만남을 확인한다.", rf"${first_slope}\ne {second_slope}$이므로 교점이 하나이다."),
                    ("두 y식을 같게 놓아 x좌표를 구한다.", rf"연립하면 $p={x}$이다."),
                    ("구한 x좌표를 두 번째 식에 대입한다.", rf"$q={second_slope}({x})+({intercept})={y}$이므로 $p+q={answer}$이다."),
                ],
                alternatives=["두 직선의 일반형을 만든 뒤 두 일차방정식을 소거법으로 풀 수 있다."],
                answer_check=lambda m=first_slope, px=point_x, py=point_y, n=second_slope, b=intercept: _line_intersection_sum(m, px, py, n, b),
            )
        )
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 지수·로그함수의 평행이동량이다. 작동 원리는 미사용 태그를 다루는 난이도 4 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    exponential_rows = [(2, 1, 3), (3, -2, 4), (5, 2, -1), (4, -1, 5), (6, 3, -2)]
    for index, (base, horizontal, vertical) in enumerate(exponential_rows, 1):
        point = horizontal + 1
        answer = _exponential_shift_value(base, horizontal, vertical)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"지수함수 $y={base}^x$의 그래프를 x방향으로 ${horizontal}$, y방향으로 ${vertical}$만큼 평행이동한 함수 $f$에 대하여 $f({point})$를 구하시오.",
                answer=str(answer),
                tags=["#지수", "#정수지수", "#실수지수", "#지수함수의평행이동", "#y방향이동", "#평행이동"],
                steps=[
                    ("가로 평행이동을 식에 반영한다.", rf"x 대신 $x-({horizontal})$를 넣는다."),
                    ("세로 평행이동을 상수항으로 반영한다.", rf"$f(x)={base}^{{x-({horizontal})}}+({vertical})$이다."),
                    ("주어진 x값을 이동된 함수에 대입한다.", rf"$f({point})={base}^{{{point}-({horizontal})}}+({vertical})$이다."),
                    ("지수의 값을 계산한다.", rf"지수는 $1$이므로 거듭제곱 값은 ${base}$이다."),
                    ("세로 이동량을 더한다.", rf"따라서 $f({point})={base}+({vertical})={answer}$이다."),
                ],
                alternatives=["원래 그래프의 점 $(1,{base})$가 이동 후 어느 점으로 옮겨지는지 좌표로 추적할 수 있다."],
                answer_check=lambda a=base, h=horizontal, k=vertical: _exponential_shift_value(a, h, k),
            )
        )
    logarithm_rows = [(2, 1, 2), (3, -1, 1), (5, 2, 1), (2, -3, 3), (4, 3, 1)]
    for index, (base, horizontal, vertical) in enumerate(logarithm_rows, 6):
        answer = _logarithm_shift_intercept(base, horizontal, vertical)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"로그함수 $y=\log_{{{base}}}x$의 그래프를 x방향으로 ${horizontal}$, y방향으로 ${vertical}$만큼 평행이동한 그래프의 x절편을 구하시오.",
                answer=str(answer),
                tags=["#로그함수의평행이동", "#y방향이동", "#평행이동"],
                steps=[
                    ("평행이동된 로그함수 식을 세운다.", rf"$y=\log_{{{base}}}(x-({horizontal}))+({vertical})$이다."),
                    ("x절편에서는 y가 0임을 이용한다.", rf"$\log_{{{base}}}(x-({horizontal}))=-{vertical}$이다."),
                    ("로그식을 지수식으로 바꾼다.", rf"$x-({horizontal})={base}^{{-{vertical}}}$이다."),
                    ("음의 지수를 분수로 계산한다.", rf"${base}^{{-{vertical}}}=\dfrac1{{{base**vertical}}}$이다."),
                    ("가로 이동량을 더해 x좌표를 구한다.", rf"따라서 x절편은 ${answer}$이다."),
                ],
                alternatives=["원래 로그함수에서 함수값이 세로 이동량의 반대가 되는 점을 찾은 뒤 좌표를 평행이동할 수 있다."],
                answer_check=lambda a=base, h=horizontal, k=vertical: _logarithm_shift_intercept(a, h, k),
            )
        )
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 이차함수 계수와 원시함수의 한 점 조건이다. 작동 원리는 미사용 태그를 다루는 난이도 5 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    for index, (a, b, c) in enumerate([(1, 4, 3), (2, 8, 1), (1, 6, -2), (3, 12, 5), (2, 12, -4)], 1):
        vertex = Fraction(b, 2 * a)
        answer = _quadratic_maximum(a, b, c)
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"함수 $f(x)=-{a}x^2+{b}x+({c})$의 도함수를 이용하여 최댓값을 구하시오.",
                answer=str(answer),
                tags=["#미분계수의기하적의미", "#미분과최대최소", "#미적분Ⅰ", "#함수의증가와감소"],
                steps=[
                    ("거듭제곱의 미분법으로 도함수를 구한다.", rf"$f'(x)=-{2 * a}x+{b}$이다."),
                    ("도함수가 0이 되는 임계점을 찾는다.", rf"$-{2 * a}x+{b}=0$이므로 $x={vertex}$이다."),
                    ("도함수의 부호가 바뀌는 방향을 확인한다.", rf"$x<{vertex}$에서는 $f'(x)>0$, $x>{vertex}$에서는 $f'(x)<0$이다."),
                    ("함수의 증가·감소로 극댓값이 전역 최댓값임을 판정한다.", "함수는 임계점까지 증가하고 이후 감소하므로 그 점에서 최대이다."),
                    ("임계점의 함수값을 계산한다.", rf"$f({vertex})=-{a}({vertex})^2+{b}({vertex})+({c})$이다."),
                    ("계산을 정리해 최댓값을 구한다.", rf"따라서 최댓값은 ${answer}$이다."),
                ],
                alternatives=[
                    "도함수 값은 접선의 기울기이므로 기울기가 양수에서 음수로 바뀌는 점을 찾을 수 있다.",
                    "이차식을 완전제곱식으로 바꾸어 꼭짓점의 함수값과 미분 결과를 교차 검산할 수 있다.",
                ],
                answer_check=lambda first=a, second=b, third=c: _quadratic_maximum(first, second, third),
            )
        )
    antiderivative_rows = [(1, 2, 3, 1, 10), (2, -1, 4, 2, 25), (-1, 3, 2, 2, 15), (2, 1, -2, 2, 30), (1, -2, 5, 3, 40)]
    for index, (a, b, c, point, value) in enumerate(antiderivative_rows, 6):
        answer = _antiderivative_origin(a, b, c, point, value)
        expression_value = a * point**3 + b * point**2 + c * point
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"미분가능한 함수 $F$가 $F'(x)=({3 * a})x^2+({2 * b})x+({c})$, $F({point})={value}$를 만족할 때, $F(0)$을 구하시오.",
                answer=str(answer),
                tags=["#부정적분의성질", "#미적분Ⅰ"],
                steps=[
                    ("F'의 각 항을 부정적분한다.", rf"$F(x)=({a})x^3+({b})x^2+({c})x+C$이다."),
                    ("부정적분의 적분상수 C가 필요함을 확인한다.", "도함수가 같은 함수들은 상수만큼 차이 날 수 있다."),
                    ("주어진 점을 일반 원시함수에 대입한다.", rf"$F({point})={expression_value}+C={value}$이다."),
                    ("상수에 대한 일차방정식을 푼다.", rf"$C={value}-({expression_value})={answer}$이다."),
                    ("x=0에서 다항식 항이 모두 0이 됨을 확인한다.", r"$F(0)=C$이다."),
                    ("구한 적분상수를 함수값으로 읽는다.", rf"따라서 $F(0)={answer}$이다."),
                ],
                alternatives=[
                    "정적분 관계 $F(t)-F(0)=\int_0^t F'(x)\,dx$를 사용해 F(0)을 바로 구할 수 있다.",
                    "구한 F를 다시 미분해 F'와 일치하고 주어진 점 조건을 만족하는지 검산할 수 있다.",
                ],
                answer_check=lambda first=a, second=b, third=c, t=point, target=value: _antiderivative_origin(first, second, third, t, target),
            )
        )
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v23 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v23 전체 카탈로그다. 작동 원리는 모든 정답 검산 함수를 실행한 뒤 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog = build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v23 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(catalog, expected_count=50, batch_id=BATCH_ID, model_name=MODEL_NAME, codebase_base=CODEBASE_BASE, seed_base=SEED_BASE)


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v23 전체 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(db_path, quests=validated_quests(), batch_id=BATCH_ID, validate_only=validate_only)


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v23 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
