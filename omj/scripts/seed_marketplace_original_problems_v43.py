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

BATCH_ID = "marketplace-original-v43"
MODEL_NAME = "aiflow-direct-authoring-v43"
CODEBASE_BASE = 20_261_004_000
SEED_BASE = 202_607_583_000


def _checked_problem(tier: int, index: int, *, answer_check: Callable[[], Any], **kwargs: Any) -> dict[str, Any]:
    """필요 변수는 문제 명세와 독립 계산 함수다. 작동 원리는 저장 답과 별도 계산 결과를 비교하도록 검산 함수를 부착한다."""
    spec = _problem(tier, index, **kwargs)
    spec["answer_check"] = answer_check
    return spec


def _intersection_sum(upper: int, divisor: int, remainder: int, modulus: int) -> int:
    """필요 변수는 전체집합 상한과 두 조건이다. 작동 원리는 배수 조건과 나머지 조건을 동시에 만족하는 원소를 합한다."""
    return sum(x for x in range(1, upper + 1) if x % divisor == 0 and x % modulus == remainder)


def _shifted_root_product(root_sum: int, root_product: int) -> int:
    """필요 변수는 이차방정식 두 근의 합과 곱이다. 작동 원리는 (α+1)(β+1)을 대칭식으로 계산한다."""
    return root_product + root_sum + 1


def _contrapositive_false_count(universe: tuple[int, ...], p_true: tuple[int, ...], q_true: tuple[int, ...]) -> int:
    """필요 변수는 전체 원소와 두 조건의 참 집합이다. 작동 원리는 대우가 거짓인 P 참·Q 거짓 원소를 센다."""
    allowed = set(universe)
    if not set(p_true) <= allowed or not set(q_true) <= allowed:
        raise ValueError("조건의 참 집합은 전체집합 안에 있어야 합니다.")
    return len(set(p_true) - set(q_true))


def _exponential_integer_sum(
    numerator: int,
    denominator: int,
    linear: int,
    constant: int,
    boundary: int,
    lower: int,
    upper: int,
) -> int:
    """필요 변수는 지수함수의 밑·지수식·정수 범위다. 작동 원리는 밑의 증감에 따라 지수 부등식을 비교해 해를 합한다."""
    base = Fraction(numerator, denominator)
    if not 0 < base or base == 1 or lower > upper:
        raise ValueError("양수이면서 1이 아닌 밑과 올바른 정수 범위가 필요합니다.")
    return sum(
        x
        for x in range(lower, upper + 1)
        if (linear * x + constant >= boundary) == (base > 1)
    )


def _inverse_rational_value(matrix: tuple[int, int, int, int], target: Fraction) -> Fraction:
    """필요 변수는 일차분수함수 계수와 역함수 입력값이다. 작동 원리는 y=(ax+b)/(cx+d)를 x에 대해 풀어 대입한다."""
    a, b, c, d = matrix
    if a * d - b * c == 0 or c * target == a:
        raise ValueError("일대일 일차분수함수와 정의 가능한 역함수값이 필요합니다.")
    return Fraction(b - d * target, c * target - a)


def _radical_endpoint_intercept_sum(horizontal: int, vertical: int) -> int:
    """필요 변수는 무리함수의 수평·수직 이동량이다. 작동 원리는 정의역 왼쪽 끝과 x절편을 구해 더한다."""
    if vertical > 0:
        raise ValueError("x절편이 존재하도록 수직 이동량은 0 이하여야 합니다.")
    x_intercept = horizontal + vertical**2
    return horizontal + x_intercept


def _scaled_inverse_trace(matrix: tuple[int, int, int, int]) -> int:
    """필요 변수는 2×2 가역행렬이다. 작동 원리는 det(A)tr(A^-1)=tr(adj A)=대각합을 이용한다."""
    a, b, c, d = matrix
    if a * d - b * c == 0:
        raise ValueError("가역행렬이 필요합니다.")
    return a + d


def _hyperbola_intersection_distance_squared(horizontal: int, vertical: int, numerator: int, slope: int) -> Fraction:
    """필요 변수는 유리함수 이동량·분자·직선 기울기다. 작동 원리는 중심 좌표로 치환해 두 교점 거리 제곱을 계산한다."""
    _ = horizontal, vertical
    ratio = Fraction(numerator, slope)
    if ratio <= 0:
        raise ValueError("서로 다른 두 실교점이 필요합니다.")
    return 4 * ratio * (1 + slope**2)


def _riemann_square_limit(scale: int, shift: int) -> Fraction:
    """필요 변수는 리만합 안 일차식의 계수다. 작동 원리는 0부터 1까지 그 제곱의 정적분을 정확히 계산한다."""
    return Fraction(scale**2, 3) + scale * shift + shift**2


def _affine_recurrence_term(first: int, ratio: int, constant: int, target: int) -> int:
    """필요 변수는 첫째항·재귀 계수·상수·목표 번호다. 작동 원리는 재귀식을 반복 적용해 일반항 결과를 독립 검산한다."""
    if target < 1:
        raise ValueError("목표 번호는 1 이상이어야 합니다.")
    value = first
    for _ in range(1, target):
        value = ratio * value + constant
    return value


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 조건의 교집합과 이차방정식의 대칭식이다. 작동 원리는 교집합 원소 합과 이동된 근의 곱 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    set_rows = [(30, 3, 1, 4), (40, 4, 2, 5), (50, 5, 2, 3), (36, 6, 0, 4), (60, 4, 1, 3)]
    for index, (upper, divisor, remainder, modulus) in enumerate(set_rows, 1):
        values = [x for x in range(1, upper + 1) if x % divisor == 0 and x % modulus == remainder]
        answer = _intersection_sum(upper, divisor, remainder, modulus)
        specs.append(_checked_problem(
            1, index,
            title=rf"전체집합 $(U=\{{1,2,\ldots,{upper}\}}$)에서 $(A=\{{x\in U\mid x$)는 {divisor}의 배수$(\}}$), $(B=\{{x\in U\mid x$)를 {modulus}로 나눈 나머지가 {remainder}$(\}}$)라 하자. $(A\cap B$)의 원소 합을 구하시오.",
            answer=str(answer), tags=["#교집합", "#조건제시법", "#집합의표현", "#집합"],
            steps=[("두 조건을 동시에 만족하는 원소를 찾는다.", rf"$(A\cap B=\{{{','.join(map(str, values))}\}}$)이다."), ("원소를 모두 더한다.", rf"따라서 합은 $({answer}$)이다.")],
            answer_check=lambda n=upper, d=divisor, r=remainder, m=modulus: _intersection_sum(n, d, r, m),
        ))
    root_rows = [(7, 10), (9, 14), (11, 24), (4, -5), (-3, -10)]
    for index, (root_sum, root_product) in enumerate(root_rows, 6):
        answer = _shifted_root_product(root_sum, root_product)
        specs.append(_checked_problem(
            1, index,
            title=rf"이차방정식 $(x^2-({root_sum})x+({root_product})=0$)의 두 근을 $(\alpha,\beta$)라 할 때 $((\alpha+1)(\beta+1)$)의 값을 구하시오.",
            answer=str(answer), tags=["#근의공식", "#두근의곱", "#이차방정식의근과계수", "#완성제곱법"],
            steps=[("근과 계수의 관계로 두 근의 합과 곱을 읽는다.", rf"$(\alpha+\beta={root_sum},\ \alpha\beta={root_product}$)이다."), ("식을 전개해 대칭식 값을 대입한다.", rf"따라서 값은 $({answer}$)이다.")],
            answer_check=lambda s=root_sum, p=root_product: _shifted_root_product(s, p),
        ))
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 조건명제의 참 집합과 지수부등식의 정수 범위다. 작동 원리는 대우의 거짓 개수와 정수해 합 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    logic_rows = [
        ((1,2,3,4,5,6), (1,2,4,6), (2,3,6)),
        ((-2,-1,0,1,2), (-2,0,1), (-1,0,2)),
        ((1,2,3,4,5,6,7), (2,3,5,7), (3,4,5)),
        ((0,1,2,3,4,5), (0,2,4,5), (1,2,3,4)),
        ((1,3,5,7,9), (1,5,7,9), (3,5,9)),
    ]
    for index, (universe, p_true, q_true) in enumerate(logic_rows, 1):
        bad = sorted(set(p_true) - set(q_true))
        answer = _contrapositive_false_count(universe, p_true, q_true)
        specs.append(_checked_problem(
            2, index,
            title=rf"전체집합 $(U=\{{{','.join(map(str, universe))}\}}$)에서 조건 p, q의 참인 원소 집합이 각각 $(\{{{','.join(map(str, p_true))}\}}$), $(\{{{','.join(map(str, q_true))}\}}$)이다. 명제 $(p\Rightarrow q$)의 대우가 거짓이 되는 x의 개수를 구하시오.",
            answer=str(answer), tags=["#대우", "#명제의역과대우", "#명제", "#명제의참거짓"],
            steps=[("명제의 대우를 쓴다.", "대우는 $(\lnot q\Rightarrow\lnot p$)이다."), ("함의가 거짓인 조건을 적용한다.", rf"p는 참이고 q는 거짓인 원소는 $(\{{{','.join(map(str, bad))}\}}$)이다."), ("원소 수를 센다.", rf"따라서 개수는 $({answer}$)이다.")],
            answer_check=lambda u=universe, p=p_true, q=q_true: _contrapositive_false_count(u, p, q),
        ))
    exponent_rows = [(2,1,2,-1,7,-3,8), (1,2,3,2,5,-4,6), (3,1,-1,4,0,-5,7), (1,3,2,5,9,-2,9), (5,1,3,-4,8,-6,5)]
    for index, row in enumerate(exponent_rows, 6):
        numerator, denominator, linear, constant, boundary, lower, upper = row
        answer = _exponential_integer_sum(*row)
        sign = r"\ge"
        specs.append(_checked_problem(
            2, index,
            title=rf"정수 범위 $({lower}\le x\le {upper}$)에서 지수부등식 $(\left(\dfrac{{{numerator}}}{{{denominator}}}\right)^{{{linear}x+({constant})}}{sign}\left(\dfrac{{{numerator}}}{{{denominator}}}\right)^{{{boundary}}}$)를 만족하는 모든 x의 합을 구하시오.",
            answer=str(answer), tags=["#지수부등식", "#지수방정식과지수부등식", "#지수함수의성질", "#실수지수"],
            steps=[("밑이 1보다 큰지 작은지 확인한다.", "밑이 1보다 작으면 지수의 대소관계가 반대로 바뀐다."), ("두 지수를 비교해 일차부등식을 세운다.", rf"지수식은 $({linear}x+({constant})$)와 $({boundary}$)이다."), ("주어진 정수 범위와 공통인 해를 합한다.", rf"따라서 정수해의 합은 $({answer}$)이다.")],
            answer_check=lambda values=row: _exponential_integer_sum(*values),
        ))
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 일차분수함수의 역함수와 평행이동한 무리함수다. 작동 원리는 역함수값과 정의역 끝점·절편 합 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    inverse_rows = [((2,3,1,4), Fraction(1)), ((3,-2,2,5), Fraction(2)), ((1,4,-1,3), Fraction(2)), ((4,1,1,2), Fraction(3)), ((2,-5,3,1), Fraction(0))]
    for index, (matrix, target) in enumerate(inverse_rows, 1):
        answer = _inverse_rational_value(matrix, target)
        specs.append(_checked_problem(
            3, index,
            title=rf"일차분수함수 $(f(x)=\dfrac{{{matrix[0]}x+({matrix[1]})}}{{{matrix[2]}x+({matrix[3]})}}$)에 대하여 $(f^{{-1}}({target})$)의 값을 구하시오.",
            answer=str(answer), tags=["#역함수", "#역함수구하기", "#역함수의그래프", "#일대일함수"],
            steps=[("$(y=f(x)$)로 놓고 분모를 곱한다.", rf"$(y({matrix[2]}x+({matrix[3]}))={matrix[0]}x+({matrix[1]})$)이다."), ("x에 관해 정리해 역함수 식을 얻는다.", "x와 y의 역할을 바꿔 $(f^{-1}$)을 나타낸다."), ("주어진 입력값을 대입한다.", rf"계산 결과는 $({answer}$)이다."), ("원래 함수에 결과를 대입해 함수값이 목표값인지 검산한다.", rf"따라서 $(f^{{-1}}({target})={answer}$)이다.")],
            alternatives=["$(f(x)=t$) 방정식을 직접 풀어 역함수값만 구할 수 있다."],
            answer_check=lambda m=matrix, t=target: _inverse_rational_value(m, t),
        ))
    radical_rows = [(2,-3), (-1,-4), (5,-2), (-3,-5), (4,-6)]
    for index, (horizontal, vertical) in enumerate(radical_rows, 6):
        x_intercept = horizontal + vertical**2
        answer = _radical_endpoint_intercept_sum(horizontal, vertical)
        specs.append(_checked_problem(
            3, index,
            title=rf"무리함수 $(y=\sqrt{{x-({horizontal})}}+({vertical})$)의 정의역에서 가장 작은 x와 그래프의 x절편을 더한 값을 구하시오.",
            answer=str(answer), tags=["#무리식과무리함수", "#무리함수의그래프", "#무리함수의평행이동", "#정의역"],
            steps=[("근호 안이 0 이상인 조건을 세운다.", rf"$(x\ge {horizontal}$)이므로 정의역의 왼쪽 끝은 $({horizontal}$)이다."), ("y=0을 놓아 x절편을 구한다.", rf"$(\sqrt{{x-({horizontal})}}={-vertical}$)이다."), ("양변을 제곱해 x를 구한다.", rf"x절편은 $({x_intercept}$)이다."), ("두 값을 더한다.", rf"따라서 합은 $({answer}$)이다.")],
            alternatives=["기본 그래프 $(y=\sqrt{x}$)의 시작점과 평행이동량으로 정의역 끝점을 바로 읽을 수 있다."],
            answer_check=lambda h=horizontal, k=vertical: _radical_endpoint_intercept_sum(h, k),
        ))
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 2×2 역행렬과 유리함수·직선 교점이다. 작동 원리는 스케일된 역행렬 대각합과 두 교점 거리 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    matrix_rows = [(2,1,3,2), (4,-1,2,1), (3,2,1,1), (-2,1,3,-1), (5,2,-1,1)]
    for index, matrix in enumerate(matrix_rows, 1):
        determinant = matrix[0]*matrix[3]-matrix[1]*matrix[2]
        answer = _scaled_inverse_trace(matrix)
        specs.append(_checked_problem(
            4, index,
            title=rf"가역행렬 $(A=\begin{{pmatrix}}{matrix[0]}&{matrix[1]}\\{matrix[2]}&{matrix[3]}\end{{pmatrix}}$)에 대하여 $((\det A)\operatorname{{tr}}(A^{{-1}})$)의 값을 구하시오.",
            answer=str(answer), tags=["#역행렬", "#역행렬의성질", "#역행렬의정의", "#행렬의곱셈"],
            steps=[("행렬식을 계산해 가역성을 확인한다.", rf"$(\det A={determinant}\ne0$)이다."), ("2×2 역행렬 공식을 쓴다.", "역행렬은 수반행렬을 행렬식으로 나눈 것이다."), ("역행렬의 대각성분을 더해 trace를 구한다.", "대각성분에는 공통으로 $(1/\det A$)가 있다."), ("주어진 행렬식을 곱해 분모를 없앤다.", "결과는 원래 행렬의 대각합이다."), ("대각성분을 더한다.", rf"따라서 값은 $({answer}$)이다.")],
            alternatives=["$((\det A)A^{-1}=\operatorname{adj}A$)의 양변에 trace를 적용할 수 있다."],
            answer_check=lambda m=matrix: _scaled_inverse_trace(m),
        ))
    hyperbola_rows = [(1,2,2,2), (-2,1,3,3), (4,-1,8,2), (0,3,12,3), (-3,-2,20,5)]
    for index, (horizontal, vertical, numerator, slope) in enumerate(hyperbola_rows, 6):
        answer = _hyperbola_intersection_distance_squared(horizontal, vertical, numerator, slope)
        specs.append(_checked_problem(
            4, index,
            title=rf"유리함수 $(y=\dfrac{{{numerator}}}{{x-({horizontal})}}+({vertical})$)의 그래프와 직선 $(y={slope}(x-({horizontal}))+({vertical})$)의 두 교점 사이 거리의 제곱을 구하시오.",
            answer=str(answer), tags=["#쌍곡선", "#유리함수의평행이동", "#유리함수의그래프", "#두점사이의거리"],
            steps=[("중심을 원점으로 옮기도록 $(X=x-h,\ Y=y-v$)로 놓는다.", rf"두 식은 $(Y={numerator}/X$), $(Y={slope}X$)이다."), ("두 식을 같게 놓아 교점의 X좌표 제곱을 구한다.", rf"$(X^2={numerator}/{slope}$)이다."), ("두 교점의 X좌표가 서로 반대임을 이용한다.", "Y좌표도 직선식에 따라 서로 반대이다."), ("좌표 차의 제곱합을 계산한다.", rf"거리 제곱은 $(4X^2(1+{slope}^2)$)이다."), ("X² 값을 대입한다.", rf"따라서 거리의 제곱은 $({answer}$)이다.")],
            alternatives=["두 교점 좌표를 각각 구한 뒤 거리 공식을 직접 적용할 수 있다."],
            answer_check=lambda h=horizontal, v=vertical, k=numerator, m=slope: _hyperbola_intersection_distance_squared(h, v, k, m),
        ))
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 제곱함수 리만합과 일차 점화식이다. 작동 원리는 정적분 극한과 귀납적으로 확인한 목표 항 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    riemann_rows = [(2,1), (3,2), (-2,4), (4,2), (5,-2)]
    for index, (scale, shift) in enumerate(riemann_rows, 1):
        answer = _riemann_square_limit(scale, shift)
        specs.append(_checked_problem(
            5, index,
            title=rf"극한 $(\lim_{{n\to\infty}}\dfrac1n\sum_{{k=1}}^n\left({scale}\dfrac kn+({shift})\right)^2$)의 값을 구하시오.",
            answer=str(answer), tags=["#구분구적법", "#구간의분할", "#정적분의정의", "#미적분Ⅰ"],
            steps=[("$(\Delta x=1/n$), $(x_k=k/n$)인 $([0,1]$)의 오른쪽 끝점 분할로 본다.", "주어진 합은 함수값과 구간 폭의 곱이다."), ("대응하는 함수를 정한다.", rf"$(f(x)=({scale}x+({shift}))^2$)이다."), ("구분구적합을 정적분으로 바꾼다.", "극한은 $(\int_0^1 f(x)dx$)이다."), ("제곱식을 전개한다.", rf"$(f(x)={scale**2}x^2+({2*scale*shift})x+({shift**2})$)이다."), ("각 항을 0부터 1까지 적분한다.", rf"값은 $({scale**2}/3+({scale*shift})+({shift**2})$)이다."), ("기약분수로 정리한다.", rf"따라서 극한값은 $({answer}$)이다.")],
            alternatives=["자연수의 합과 제곱합 공식을 합에 직접 대입해 n의 최고차항만 남길 수 있다.", "정적분의 선형성과 치환을 이용해 계산할 수 있다."],
            answer_check=lambda a=scale, b=shift: _riemann_square_limit(a, b),
        ))
    recurrence_rows = [(1,2,1,8), (2,3,-1,6), (-1,2,3,7), (4,-2,5,6), (3,2,-4,9)]
    for index, (first, ratio, constant, target) in enumerate(recurrence_rows, 6):
        answer = _affine_recurrence_term(first, ratio, constant, target)
        specs.append(_checked_problem(
            5, index,
            title=rf"수열 $(\{{a_n\}}$)이 $(a_1={first}$), $(a_{{n+1}}={ratio}a_n+({constant})$)을 만족한다. 점화식에서 얻은 일반항이 모든 자연수 n에 성립함을 수학적 귀납법으로 확인하여 $(a_{{{target}}}$)을 구하시오.",
            answer=str(answer), tags=["#수학적귀납법", "#귀납법의원리", "#귀납법증명", "#수열의정의"],
            steps=[("상수항을 없애는 고정점 이동 $(b_n=a_n-L$)을 정한다.", "$(L=rL+c$)를 만족하는 L을 택하면 $(b_{n+1}=rb_n$)이다."), ("변환된 수열의 일반항을 구한다.", "$(b_n=b_1r^{n-1}$)이다."), ("n=1에서 일반항이 첫째항과 일치함을 확인한다.", "수학적 귀납법의 기초 단계가 성립한다."), ("n=k에서 성립한다고 가정하고 점화식에 대입한다.", "$(k+1$)의 식이 같은 꼴로 정리되어 귀납 단계가 성립한다."), ("따라서 모든 자연수에서 일반항이 성립함을 결론낸다.", rf"그 식에 $(n={target}$)을 대입한다."), ("목표 항을 계산한다.", rf"따라서 $(a_{{{target}}}={answer}$)이다.")],
            alternatives=["점화식을 목표 번호까지 반복 대입해 값을 직접 검산할 수 있다.", "등비수열의 합으로 누적된 상수항을 계산할 수 있다."],
            answer_check=lambda a=first, r=ratio, c=constant, n=target: _affine_recurrence_term(a, r, c, n),
        ))
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v43 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v43 전체 카탈로그다. 작동 원리는 독립 정답 검산 후 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog = build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v43 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(catalog, expected_count=50, batch_id=BATCH_ID, model_name=MODEL_NAME, codebase_base=CODEBASE_BASE, seed_base=SEED_BASE)


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v43 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(db_path, quests=validated_quests(), batch_id=BATCH_ID, validate_only=validate_only)


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v43 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
