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

BATCH_ID = "marketplace-original-v45"
MODEL_NAME = "aiflow-direct-authoring-v45"
CODEBASE_BASE = 20_261_006_000
SEED_BASE = 202_607_585_000


def _checked_problem(tier: int, index: int, *, answer_check: Callable[[], Any], **kwargs: Any) -> dict[str, Any]:
    """필요 변수는 문제 명세와 독립 계산 함수다. 작동 원리는 저장 답과 별도 계산 결과를 비교하도록 검산 함수를 부착한다."""
    spec = _problem(tier, index, **kwargs)
    spec["answer_check"] = answer_check
    return spec


def _rational_substitution(first: int, first_pole: int, second: int, second_pole: int, value: int) -> Fraction:
    """필요 변수는 두 분수의 분자·극점과 대입값이다. 작동 원리는 각 분수를 정확한 분수로 계산해 더한다."""
    if value in {first_pole, second_pole}:
        raise ValueError("분모가 0이 아닌 대입값이 필요합니다.")
    return Fraction(first, value - first_pole) + Fraction(second, value - second_pole)


def _matrix_linear_combination_sum(first: tuple[int, int, int, int], second: tuple[int, int, int, int]) -> int:
    """필요 변수는 두 2×2 행렬의 성분이다. 작동 원리는 2A-B의 모든 성분을 계산해 합한다."""
    return sum(2 * a - b for a, b in zip(first, second))


def _condition_statement_count(universe: tuple[int, ...], p_true: tuple[int, ...], q_true: tuple[int, ...]) -> int:
    """필요 변수는 전체집합과 두 조건의 참 집합이다. 작동 원리는 네 방향의 조건명제가 전체에서 참인지 부분집합으로 판정한다."""
    p_set, q_set = set(p_true), set(q_true)
    if not p_set <= set(universe) or not q_set <= set(universe):
        raise ValueError("참 집합은 전체집합 안에 있어야 합니다.")
    return 2 * int(p_set <= q_set) + 2 * int(q_set <= p_set)


def _synthetic_quotient_remainder_sum(coefficients: tuple[int, int, int, int], root: int) -> int:
    """필요 변수는 삼차다항식 계수와 일차식의 근이다. 작동 원리는 조립제법으로 몫 계수와 나머지를 구해 모두 더한다."""
    row = [coefficients[0]]
    for coefficient in coefficients[1:]:
        row.append(coefficient + root * row[-1])
    return sum(row)


def _decimal_digit_count(characteristic: int) -> int:
    """필요 변수는 양수의 상용로그 정수부분이다. 작동 원리는 10^k≤N<10^(k+1)에서 자릿수를 k+1로 구한다."""
    if characteristic < 0:
        raise ValueError("1 이상의 수에 대한 음이 아닌 상용로그 정수부분이 필요합니다.")
    return characteristic + 1


def _geometric_partial_sum(first: int, ratio: int, count: int) -> int:
    """필요 변수는 등비수열의 첫째항·공비·항 수다. 작동 원리는 정확히 count개 항을 생성해 합한다."""
    return sum(first * ratio**index for index in range(count))


def _sign_change_interval_count(values: tuple[int, ...]) -> int:
    """필요 변수는 연속함수의 증가하는 표본점 함수값이다. 작동 원리는 인접한 두 값의 부호가 다른 구간을 센다."""
    if any(value == 0 for value in values):
        raise ValueError("끝점 자체가 근이 아닌 부호 자료가 필요합니다.")
    return sum(first * second < 0 for first, second in zip(values, values[1:]))


def _positive_rational_minimum(linear: int, reciprocal: int, constant: int) -> Fraction:
    """필요 변수는 x와 1/x의 양의 계수 및 상수다. 작동 원리는 산술·기하평균으로 양의 정의역 최솟값을 구한다."""
    if linear <= 0 or reciprocal <= 0:
        raise ValueError("양의 계수가 필요합니다.")
    root = math.isqrt(linear * reciprocal)
    if root**2 != linear * reciprocal:
        raise ValueError("정확한 정수 제곱근이 되는 계수가 필요합니다.")
    return 2 * root + constant


def _bilinear_scalar(matrix: tuple[int, int, int, int], left: tuple[int, int], right: tuple[int, int]) -> int:
    """필요 변수는 2×2 행렬과 좌우 벡터다. 작동 원리는 먼저 행렬-열벡터를 곱한 뒤 행벡터와 스칼라곱한다."""
    first = matrix[0] * right[0] + matrix[1] * right[1]
    second = matrix[2] * right[0] + matrix[3] * right[1]
    return left[0] * first + left[1] * second


def _tangent_axis_triangle_area(leading: int, linear: int, constant: int, point: int) -> Fraction:
    """필요 변수는 이차함수 계수와 접점 x좌표다. 작동 원리는 접선의 두 절편으로 좌표축 삼각형 넓이를 계산한다."""
    slope = 2 * leading * point + linear
    intercept = constant - leading * point**2
    if slope == 0 or intercept == 0:
        raise ValueError("두 좌표축과 유한한 삼각형을 만드는 접선이 필요합니다.")
    return Fraction(intercept**2, 2 * abs(slope))


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 유리식과 두 행렬이다. 작동 원리는 통분 대입값과 행렬 선형결합 성분합 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    rational_rows = [(2,1,3,-2,4), (5,-1,-2,3,2), (-3,2,4,-3,5), (1,-4,6,1,3), (7,0,-5,2,4)]
    for index, row in enumerate(rational_rows, 1):
        a,p,b,q,x=row
        answer = _rational_substitution(*row)
        specs.append(_checked_problem(
            1, index,
            title=rf"유리식 $(\dfrac{{{a}}}{{x-({p})}}+\dfrac{{{b}}}{{x-({q})}}$)에 $(x={x}$)를 대입한 값을 구하시오.",
            answer=str(answer), tags=["#유리식", "#통분", "#유리식과유리함수", "#대수"],
            steps=[("각 분모에 x값을 대입한다.", "두 분모가 모두 0이 아님을 확인한다."), ("두 분수를 통분해 더한다.", rf"따라서 값은 $({answer}$)이다.")],
            answer_check=lambda values=row: _rational_substitution(*values),
        ))
    matrix_rows = [((1,2,3,4),(4,3,2,1)), ((-1,5,2,0),(3,-2,4,1)), ((2,-3,1,6),(-2,4,5,-1)), ((4,0,-2,3),(1,5,-3,2)), ((-3,2,7,1),(6,-1,0,4))]
    for index, (first, second) in enumerate(matrix_rows, 6):
        answer = _matrix_linear_combination_sum(first, second)
        specs.append(_checked_problem(
            1, index,
            title=rf"$(A=\begin{{pmatrix}}{first[0]}&{first[1]}\\{first[2]}&{first[3]}\end{{pmatrix}}$), $(B=\begin{{pmatrix}}{second[0]}&{second[1]}\\{second[2]}&{second[3]}\end{{pmatrix}}$)일 때 행렬 $(2A-B$)의 모든 성분의 합을 구하시오.",
            answer=str(answer), tags=["#행렬의덧셈", "#행렬의뺄셈", "#행렬의연산", "#성분"],
            steps=[("A의 각 성분에 2를 곱한다.", "같은 위치의 성분끼리 계산한다."), ("2A에서 B를 빼고 네 성분을 더한다.", rf"따라서 성분의 합은 $({answer}$)이다.")],
            answer_check=lambda a=first, b=second: _matrix_linear_combination_sum(a, b),
        ))
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 조건의 참 집합과 삼차다항식 계수다. 작동 원리는 필요·충분 명제 수와 조립제법 결과합 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    condition_rows = [
        ((1,2,3,4,5),(1,2),(1,2,3)),
        ((1,2,3,4),(1,3),(1,3)),
        ((-2,-1,0,1,2),(-2,0,2),(0,2)),
        ((1,2,3,4,5,6),(2,4,6),(1,2,3,4,5,6)),
        ((0,1,2,3,4),(0,2,4),(1,3)),
    ]
    for index, (universe,p_true,q_true) in enumerate(condition_rows, 1):
        answer = _condition_statement_count(universe,p_true,q_true)
        specs.append(_checked_problem(
            2, index,
            title=rf"전체집합 $(U=\{{{','.join(map(str,universe))}\}}$)에서 조건 p, q의 참인 원소 집합이 $(\{{{','.join(map(str,p_true))}\}}$), $(\{{{','.join(map(str,q_true))}\}}$)이다. $(p\Rightarrow q$), $(q\Rightarrow p$), 각각의 대우 네 명제 중 항상 참인 명제의 개수를 구하시오.",
            answer=str(answer), tags=["#충분조건", "#필요조건", "#필요충분조건", "#충분조건과필요조건"],
            steps=[("$(p\Rightarrow q$)가 참일 조건을 참 집합의 포함관계로 바꾼다.", "p의 참 집합이 q의 참 집합의 부분집합이어야 한다."), ("역방향 명제도 같은 방식으로 판정한다.", "q의 참 집합이 p의 참 집합에 포함되는지 본다."), ("각 명제와 대우는 진리값이 같음을 적용한다.", rf"따라서 항상 참인 명제는 $({answer}$)개이다.")],
            answer_check=lambda u=universe,p=p_true,q=q_true: _condition_statement_count(u,p,q),
        ))
    synthetic_rows = [((1,-3,2,5),2), ((2,1,-4,3),-1), ((-1,4,0,6),3), ((3,-2,5,-1),1), ((2,-5,7,4),-2)]
    for index, (coefficients, root) in enumerate(synthetic_rows, 6):
        answer = _synthetic_quotient_remainder_sum(coefficients, root)
        specs.append(_checked_problem(
            2, index,
            title=rf"삼차다항식 $(P(x)={coefficients[0]}x^3+({coefficients[1]})x^2+({coefficients[2]})x+({coefficients[3]})$)를 $(x-({root})$)로 나눈 몫의 모든 계수와 나머지를 더한 값을 구하시오.",
            answer=str(answer), tags=["#조립제법", "#다항식의나눗셈", "#나머지정리활용", "#항"],
            steps=[("빠진 차수 없이 계수를 조립제법 표에 적는다.", rf"대입할 수는 $({root}$)이다."), ("내려 쓰기와 곱셈·덧셈을 차례로 수행한다.", "마지막 수는 나머지이고 앞의 수들은 몫의 계수이다."), ("얻은 네 수를 모두 더한다.", rf"따라서 값은 $({answer}$)이다.")],
            answer_check=lambda c=coefficients,r=root: _synthetic_quotient_remainder_sum(c,r),
        ))
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 상용로그의 정수부분과 등비수열 정보다. 작동 원리는 정수 자릿수와 부분합 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    log_rows = [(3,2),(5,7),(2,4),(6,1),(4,8)]
    for index, (characteristic, decimal_tenth) in enumerate(log_rows, 1):
        answer = _decimal_digit_count(characteristic)
        specs.append(_checked_problem(
            3, index,
            title=rf"양의 정수 N에 대하여 $(\log_{{10}}N={characteristic}+\dfrac{{{decimal_tenth}}}{{10}}$)이다. N의 자릿수를 구하시오.",
            answer=str(answer), tags=["#상용로그", "#로그", "#진수", "#로그의성질"],
            steps=[("상용로그의 정수부분을 확인한다.", rf"$({characteristic}\le\log_{{10}}N<{characteristic+1}$)이다."), ("지수식으로 바꾼다.", rf"$(10^{characteristic}\le N<10^{characteristic+1}$)이다."), ("이 범위의 정수 자릿수를 판정한다.", rf"N은 $({answer}$)자리 수이다."), ("소수부분은 자릿수 경계를 바꾸지 않음을 확인한다.", rf"따라서 답은 $({answer}$)이다.")],
            alternatives=["10의 거듭제곱 사이에서 정수의 자릿수를 직접 비교할 수 있다."],
            answer_check=lambda k=characteristic: _decimal_digit_count(k),
        ))
    sequence_rows = [(2,3,5), (5,2,6), (3,-2,5), (-1,4,4), (7,-1,8)]
    for index, (first,ratio,count) in enumerate(sequence_rows, 6):
        answer = _geometric_partial_sum(first,ratio,count)
        specs.append(_checked_problem(
            3, index,
            title=rf"첫째항이 $({first}$), 공비가 $({ratio}$)인 등비수열의 첫 {count}개 항의 합을 구하시오.",
            answer=str(answer), tags=["#등비수열의합", "#등비수열의일반항", "#등비수열", "#공비"],
            steps=[("공비가 1인지 확인한다.", "공비가 1이 아니므로 유한 등비급수 공식을 적용한다."), ("첫 n항의 합 공식을 쓴다.", rf"$(S_n={first}(1-({ratio})^{count})/(1-({ratio}))$)이다."), ("거듭제곱과 분자를 계산한다.", "부호를 함께 정리한다."), ("분모로 나눠 합을 구한다.", rf"따라서 합은 $({answer}$)이다.")],
            alternatives=["일반항을 첫째항부터 직접 나열해 더해 검산할 수 있다."],
            answer_check=lambda a=first,r=ratio,n=count: _geometric_partial_sum(a,r,n),
        ))
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 연속함수의 표본 부호와 양의 유리함수 계수다. 작동 원리는 중간값정리 보장 구간과 최솟값 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    sign_rows = [(-2,3,-1,4,2), (5,2,-3,-1,6), (-1,4,3,-2,-5), (2,-4,5,-6,7), (-3,-2,1,4,-1)]
    for index, values in enumerate(sign_rows, 1):
        answer = _sign_change_interval_count(values)
        samples = ", ".join(rf"f({i})={v}" for i,v in enumerate(values))
        specs.append(_checked_problem(
            4, index,
            title=rf"다항함수 f에 대하여 $({samples}$)이다. 중간값정리만으로 열린구간 $((0,1),(1,2),(2,3),(3,4)$) 중 f(x)=0인 해가 존재함을 보장할 수 있는 구간의 개수를 구하시오.",
            answer=str(answer), tags=["#중간값정리", "#연속함수의성질", "#함수의연속", "#함수"],
            steps=[("다항함수는 모든 실수에서 연속임을 확인한다.", "각 닫힌 표본 구간에 중간값정리를 적용할 수 있다."), ("인접한 두 함수값의 부호를 비교한다.", "곱이 음수이면 0이 두 함수값 사이에 있다."), ("각 부호 변화 구간을 표시한다.", "끝점 함수값은 0이 아니므로 열린구간 안에 근이 있다."), ("표시한 구간을 센다.", rf"보장되는 구간은 $({answer}$)개이다."), ("중간값정리는 구간별 최소 한 근만 보장함을 확인한다.", rf"따라서 답은 $({answer}$)이다.")],
            alternatives=["함수값을 수직선 위에 표시해 0을 가로지르는 인접 구간을 셀 수 있다."],
            answer_check=lambda row=values: _sign_change_interval_count(row),
        ))
    minimum_rows = [(1,9,2), (2,8,-3), (3,12,1), (4,16,-5), (5,20,4)]
    for index, (linear,reciprocal,constant) in enumerate(minimum_rows, 6):
        answer = _positive_rational_minimum(linear,reciprocal,constant)
        specs.append(_checked_problem(
            4, index,
            title=rf"$(x>0$)에서 함수 $(f(x)={linear}x+\dfrac{{{reciprocal}}}x+({constant})$)의 최솟값을 구하시오.",
            answer=str(answer), tags=["#함수의증가와감소", "#최솟값", "#최대최소문제", "#유리식"],
            steps=[("x항과 역수항이 모두 양수임을 확인한다.", "산술평균과 기하평균의 관계를 적용할 수 있다."), ("두 양수항의 합의 하한을 구한다.", rf"$({linear}x+{reciprocal}/x\ge2\sqrt{{{linear*reciprocal}}}$)이다."), ("등호 조건을 확인한다.", rf"$({linear}x={reciprocal}/x$)인 양의 x가 존재한다."), ("상수항을 더한다.", rf"최솟값은 $({answer}$)이다."), ("등호를 이루는 x가 정의역 안에 있음을 확인한다.", rf"따라서 답은 $({answer}$)이다.")],
            alternatives=["도함수를 0으로 놓고 감소·증가가 바뀌는 점의 함수값을 계산할 수 있다."],
            answer_check=lambda a=linear,b=reciprocal,c=constant: _positive_rational_minimum(a,b,c),
        ))
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 행렬과 두 벡터 및 포물선 접점이다. 작동 원리는 이중 스칼라곱과 접선 절편 삼각형 넓이 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    scalar_rows = [
        ((1,2,3,4),(2,-1),(1,3)),
        ((-2,1,4,0),(3,2),(-1,5)),
        ((3,-1,2,5),(1,4),(2,-2)),
        ((4,2,-3,1),(-2,3),(5,1)),
        ((1,-4,2,3),(4,-1),(-2,3)),
    ]
    for index, (matrix,left,right) in enumerate(scalar_rows, 1):
        answer = _bilinear_scalar(matrix,left,right)
        specs.append(_checked_problem(
            5, index,
            title=rf"행렬 $(A=\begin{{pmatrix}}{matrix[0]}&{matrix[1]}\\{matrix[2]}&{matrix[3]}\end{{pmatrix}}$), 행벡터 $(u=({left[0]},{left[1]})$), 열벡터 $(v=({right[0]},{right[1]})^T$)에 대하여 스칼라 $(uAv$)를 구하시오.",
            answer=str(answer), tags=["#스칼라곱", "#행", "#열", "#행렬의곱셈"],
            steps=[("먼저 Av를 계산한다.", "행렬의 각 행과 열벡터를 스칼라곱한다."), ("결과는 2×1 열벡터이다.", "행벡터 u와 곱할 수 있는 크기인지 확인한다."), ("u와 Av를 스칼라곱한다.", "두 성분의 곱을 더한다."), ("행렬 곱셈의 결합법칙에 따라 괄호 위치가 적법함을 확인한다.", "결과는 1×1 스칼라이다."), ("모든 곱셈을 계산한다.", rf"값은 $({answer}$)이다."), ("직접 uA를 먼저 계산해 같은 결과인지 검산한다.", rf"따라서 $(uAv={answer}$)이다.")],
            alternatives=["uA를 먼저 구한 뒤 v와 곱할 수 있다.", "성분별 이중합으로 한 번에 계산할 수 있다."],
            answer_check=lambda a=matrix,u=left,v=right: _bilinear_scalar(a,u,v),
        ))
    tangent_rows = [(1,2,5,1), (2,-1,6,2), (-1,5,8,1), (3,2,10,-1), (2,4,9,1)]
    for index, row in enumerate(tangent_rows, 6):
        leading,linear,constant,point=row
        slope=2*leading*point+linear
        intercept=constant-leading*point**2
        answer = _tangent_axis_triangle_area(*row)
        specs.append(_checked_problem(
            5, index,
            title=rf"포물선 $(y={leading}x^2+({linear})x+({constant})$) 위에서 x좌표가 $({point}$)인 점의 접선이 두 좌표축과 이루는 삼각형의 넓이를 구하시오.",
            answer=str(answer), tags=["#접선방정식구하기", "#접선의방정식", "#y절편", "#절편", "#미분계수의기하적의미"],
            steps=[("도함수로 접선의 기울기를 구한다.", rf"기울기는 $({slope}$)이다."), ("접점 좌표를 원래 함수에 대입해 구한다.", "점기울기형으로 접선식을 세운다."), ("접선식을 $(y=mx+b$)로 정리한다.", rf"y절편은 $({intercept}$)이다."), ("y=0을 대입해 x절편을 구한다.", rf"x절편은 $(-{intercept}/{slope}$)이다."), ("두 절편의 절댓값을 밑변과 높이로 사용한다.", "삼각형 넓이는 두 절편 절댓값의 곱의 절반이다."), ("값을 기약분수로 정리한다.", rf"따라서 넓이는 $({answer}$)이다.")],
            alternatives=["접선과 두 좌표축의 세 교점 좌표를 구해 행렬식 넓이 공식을 적용할 수 있다.", "직선의 절편형으로 바꾸어 넓이를 계산할 수 있다."],
            answer_check=lambda values=row: _tangent_axis_triangle_area(*values),
        ))
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v45 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v45 전체 카탈로그다. 작동 원리는 독립 정답 검산 후 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog = build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v45 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(catalog, expected_count=50, batch_id=BATCH_ID, model_name=MODEL_NAME, codebase_base=CODEBASE_BASE, seed_base=SEED_BASE)


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v45 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(db_path, quests=validated_quests(), batch_id=BATCH_ID, validate_only=validate_only)


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v45 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
