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

BATCH_ID = "marketplace-original-v44"
MODEL_NAME = "aiflow-direct-authoring-v44"
CODEBASE_BASE = 20_261_005_000
SEED_BASE = 202_607_584_000


def _checked_problem(tier: int, index: int, *, answer_check: Callable[[], Any], **kwargs: Any) -> dict[str, Any]:
    """필요 변수는 문제 명세와 독립 계산 함수다. 작동 원리는 저장 답과 별도 계산 결과를 비교하도록 검산 함수를 부착한다."""
    spec = _problem(tier, index, **kwargs)
    spec["answer_check"] = answer_check
    return spec


def _union_sum(upper: int, first_divisor: int, second_divisor: int) -> int:
    """필요 변수는 전체집합 상한과 두 배수 조건이다. 작동 원리는 둘 중 하나 이상의 조건을 만족하는 원소를 한 번씩 합한다."""
    return sum(x for x in range(1, upper + 1) if x % first_divisor == 0 or x % second_divisor == 0)


def _conjugate_square_sum(real: int, imaginary: int) -> int:
    """필요 변수는 복소수의 실수부와 허수부다. 작동 원리는 z²과 켤레복소수의 제곱을 더해 실수부의 두 배를 구한다."""
    return 2 * (real**2 - imaginary**2)


def _quadratic_integer_sum(first_root: int, second_root: int, lower: int, upper: int) -> int:
    """필요 변수는 이차식의 두 근과 정수 범위다. 작동 원리는 곱이 0 이하인 닫힌 근 구간의 정수만 합한다."""
    if first_root > second_root:
        first_root, second_root = second_root, first_root
    return sum(x for x in range(lower, upper + 1) if (x - first_root) * (x - second_root) <= 0)


def _external_division_coordinate_sum(
    first: tuple[int, int],
    second: tuple[int, int],
    first_weight: int,
    second_weight: int,
) -> Fraction:
    """필요 변수는 두 점과 외분비다. 작동 원리는 외분점 공식 (mB-nA)/(m-n)으로 두 좌표를 구해 더한다."""
    if first_weight == second_weight:
        raise ValueError("외분비의 두 수는 달라야 합니다.")
    denominator = first_weight - second_weight
    x_value = Fraction(first_weight * second[0] - second_weight * first[0], denominator)
    y_value = Fraction(first_weight * second[1] - second_weight * first[1], denominator)
    return x_value + y_value


def _injective_fixed_count(domain_size: int, codomain_size: int) -> int:
    """필요 변수는 정의역·공역 크기다. 작동 원리는 한 대응을 고정한 뒤 남은 원소의 일대일 배치 순열을 센다."""
    if domain_size < 1 or codomain_size < domain_size:
        raise ValueError("일대일함수가 존재하는 유한집합 크기가 필요합니다.")
    return math.perm(codomain_size - 1, domain_size - 1)


def _even_first_stars_bars(total: int, variable_count: int) -> int:
    """필요 변수는 합과 변수 개수다. 작동 원리는 첫 변수를 짝수로 고정한 각 경우에 중복조합 수를 더한다."""
    if total < 0 or variable_count < 2:
        raise ValueError("음이 아닌 합과 두 개 이상의 변수가 필요합니다.")
    return sum(
        math.comb(total - 2 * half + variable_count - 2, variable_count - 2)
        for half in range(total // 2 + 1)
    )


def _piecewise_continuity_parameter_sum(
    left_slope: int,
    middle_slope: int,
    middle_constant: int,
    right_slope: int,
    first_junction: int,
    second_junction: int,
) -> int:
    """필요 변수는 세 직선 조각과 두 접합점이다. 작동 원리는 좌우 함수값 일치로 양끝 상수항을 정해 더한다."""
    left_constant = (middle_slope - left_slope) * first_junction + middle_constant
    right_constant = (middle_slope - right_slope) * second_junction + middle_constant
    return left_constant + right_constant


def _antiderivative_coefficient_sum(first_value: int, negative_value: int, zero_value: int) -> Fraction:
    """필요 변수는 원시함수의 1,-1,0 함수값이다. 작동 원리는 F=x³+ax²+bx+c의 세 값으로 a+b+c를 푼다."""
    constant = Fraction(zero_value)
    quadratic = Fraction(first_value + negative_value - 2 * zero_value, 2)
    linear = Fraction(first_value - negative_value - 2, 2)
    return quadratic + linear + constant


def _composition_inverse_value(
    first_slope: int,
    first_constant: int,
    second_slope: int,
    second_constant: int,
    target: int,
) -> Fraction:
    """필요 변수는 두 일차함수와 합성함수 역함수의 입력값이다. 작동 원리는 합성식의 일차방정식을 풀어 원상을 구한다."""
    product = first_slope * second_slope
    if product == 0:
        raise ValueError("합성함수가 일대일이 되도록 두 기울기는 0이 아니어야 합니다.")
    return Fraction(target - first_slope * second_constant - first_constant, product)


def _resource_product_maximum(total: int, weight: int) -> Fraction:
    """필요 변수는 선형 제약의 총량과 가중치다. 작동 원리는 xy=x(S-x)/k를 완전제곱해 최댓값을 구한다."""
    if total <= 0 or weight <= 0:
        raise ValueError("양의 총량과 가중치가 필요합니다.")
    return Fraction(total**2, 4 * weight)


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 배수 집합의 합집합과 켤레복소수다. 작동 원리는 중복 없는 원소 합과 켤레 제곱합 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    set_rows = [(20,3,5), (30,4,7), (36,5,6), (42,4,9), (50,6,8)]
    for index, (upper, first, second) in enumerate(set_rows, 1):
        values = [x for x in range(1, upper + 1) if x % first == 0 or x % second == 0]
        answer = _union_sum(upper, first, second)
        specs.append(_checked_problem(
            1, index,
            title=rf"$(U=\{{1,2,\ldots,{upper}\}}$)에서 $(A$)는 {first}의 배수 집합, $(B$)는 {second}의 배수 집합이다. $(A\cup B$)의 모든 원소의 합을 구하시오.",
            answer=str(answer), tags=["#합집합", "#집합의표현", "#원소나열법", "#집합"],
            steps=[("두 배수 조건 중 하나 이상을 만족하는 원소를 중복 없이 나열한다.", rf"$(A\cup B=\{{{','.join(map(str, values))}\}}$)이다."), ("나열한 원소를 더한다.", rf"따라서 합은 $({answer}$)이다.")],
            answer_check=lambda n=upper, a=first, b=second: _union_sum(n, a, b),
        ))
    complex_rows = [(3,2), (5,1), (-2,4), (1,6), (-4,3)]
    for index, (real, imaginary) in enumerate(complex_rows, 6):
        answer = _conjugate_square_sum(real, imaginary)
        specs.append(_checked_problem(
            1, index,
            title=rf"복소수 $(z={real}+({imaginary})i$)와 그 켤레복소수 $(\overline z$)에 대하여 $(z^2+\overline z^2$)의 값을 구하시오.",
            answer=str(answer), tags=["#켤레복소수", "#복소수", "#허수단위", "#이"],
            steps=[("z와 켤레복소수를 각각 제곱한다.", "허수부가 서로 반대이므로 제곱식의 허수항도 서로 반대이다."), ("두 식을 더해 허수항을 소거한다.", rf"따라서 값은 $({answer}$)이다.")],
            answer_check=lambda a=real, b=imaginary: _conjugate_square_sum(a, b),
        ))
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 이차부등식의 두 근과 선분 외분비다. 작동 원리는 정수해 합과 외분점 좌표 합 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    inequality_rows = [(-2,5,-6,8), (1,7,-3,10), (-5,0,-8,4), (3,9,0,12), (-4,6,-10,9)]
    for index, (first, second, lower, upper) in enumerate(inequality_rows, 1):
        answer = _quadratic_integer_sum(first, second, lower, upper)
        specs.append(_checked_problem(
            2, index,
            title=rf"정수 범위 $({lower}\le x\le {upper}$)에서 이차부등식 $((x-({first}))(x-({second}))\le0$)을 만족하는 모든 x의 합을 구하시오.",
            answer=str(answer), tags=["#이차부등식", "#이차부등식의풀이", "#이차부등식의해", "#이차함수와이차부등식"],
            steps=[("이차식의 두 근을 확인한다.", rf"경계는 $(x={first}, {second}$)이다."), ("최고차항 계수가 양수이므로 두 근 사이에서 0 이하이다.", "등호가 있으므로 두 끝점도 포함한다."), ("주어진 정수 범위와 공통인 해를 더한다.", rf"따라서 합은 $({answer}$)이다.")],
            answer_check=lambda a=first, b=second, lo=lower, hi=upper: _quadratic_integer_sum(a, b, lo, hi),
        ))
    division_rows = [((1,2),(5,6),3,1), ((-2,4),(4,-2),2,1), ((3,-1),(-1,7),5,2), ((0,5),(6,1),4,1), ((-3,-4),(5,2),3,2)]
    for index, (first, second, m, n) in enumerate(division_rows, 6):
        answer = _external_division_coordinate_sum(first, second, m, n)
        specs.append(_checked_problem(
            2, index,
            title=rf"두 점 $(A{first}$), $(B{second}$)를 이은 선분 AB를 $({m}:{n}$)으로 외분하는 점 P의 x좌표와 y좌표의 합을 구하시오.",
            answer=str(answer), tags=["#외분점", "#두점사이의거리", "#좌표평면", "#공통수학2"],
            steps=[("외분점 공식을 적용한다.", rf"$(P=\dfrac{{{m}B-{n}A}}{{{m}-{n}}}$)이다."), ("x좌표와 y좌표를 각각 계산한다.", "두 좌표는 같은 분모를 갖는다."), ("두 좌표를 더해 정리한다.", rf"따라서 좌표의 합은 $({answer}$)이다.")],
            answer_check=lambda a=first, b=second, p=m, q=n: _external_division_coordinate_sum(a, b, p, q),
        ))
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 한 대응이 고정된 일대일함수와 짝수 조건 중복조합이다. 작동 원리는 순열 수와 제한된 정수해 수 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    function_rows = [(3,5), (4,6), (2,7), (5,7), (4,8)]
    for index, (domain_size, codomain_size) in enumerate(function_rows, 1):
        answer = _injective_fixed_count(domain_size, codomain_size)
        specs.append(_checked_problem(
            3, index,
            title=rf"$(|A|={domain_size}$), $(|B|={codomain_size}$)인 유한집합에서 특정한 $(a\in A$), $(b\in B$)가 고정되어 있다. $(f(a)=b$)를 만족하는 일대일함수 $(f:A\to B$)의 개수를 구하시오.",
            answer=str(answer), tags=["#일대일대응", "#일대일함수", "#함수의정의", "#순열의수"],
            steps=[("고정된 원소 a의 함수값 b를 먼저 배정한다.", "남은 정의역 원소는 서로 다른 함수값을 가져야 한다."), ("남은 공역 원소 중 필요한 수만큼 순서 있게 고른다.", rf"경우의 수는 $(P({codomain_size-1},{domain_size-1})$)이다."), ("순열식을 곱셈으로 계산한다.", rf"값은 $({answer}$)이다."), ("각 배정이 정확히 하나의 일대일함수와 대응함을 확인한다.", rf"따라서 함수의 개수는 $({answer}$)이다.")],
            alternatives=["공역에서 정의역 크기만큼 고른 뒤 고정 대응을 포함하는 전단사 수를 셀 수 있다."],
            answer_check=lambda n=domain_size, m=codomain_size: _injective_fixed_count(n, m),
        ))
    stars_rows = [(6,3), (8,4), (10,3), (7,5), (12,4)]
    for index, (total, count) in enumerate(stars_rows, 6):
        answer = _even_first_stars_bars(total, count)
        names = "+".join(f"x_{i}" for i in range(1, count+1))
        specs.append(_checked_problem(
            3, index,
            title=rf"방정식 $({names}={total}$)을 만족하는 음이 아닌 정수해 중 $(x_1$)이 짝수인 해의 개수를 구하시오.",
            answer=str(answer), tags=["#중복조합", "#중복순열", "#경우의수", "#합의법칙"],
            steps=[("$(x_1=2j$)로 놓는다.", rf"$(j=0,1,\ldots,{total//2}$)이다."), ("j를 고정하면 나머지 변수의 합은 $(N-2j$)이다.", "별과 막대 방법으로 각 경우의 음이 아닌 정수해 수를 센다."), ("각 j에 대한 중복조합 수를 모두 더한다.", rf"합의 법칙을 적용한 결과는 $({answer}$)이다."), ("서로 다른 j의 경우가 겹치지 않음을 확인한다.", rf"따라서 해의 개수는 $({answer}$)이다.")],
            alternatives=["생성함수 $((1-x^2)^{-1}(1-x)^{-(k-1)}$)에서 계수를 구할 수 있다."],
            answer_check=lambda n=total, k=count: _even_first_stars_bars(n, k),
        ))
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 세 조각 일차함수와 삼차 원시함수의 세 함수값이다. 작동 원리는 연속 조건과 적분상수 계수 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    continuity_rows = [(1,2,3,-1,0,4), (2,-1,5,3,-2,3), (-1,3,2,2,1,5), (4,1,-3,-2,0,2), (3,-2,4,1,-1,6)]
    for index, row in enumerate(continuity_rows, 1):
        left, middle, constant, right, first, second = row
        answer = _piecewise_continuity_parameter_sum(*row)
        specs.append(_checked_problem(
            4, index,
            title=rf"함수 $(f(x)=\begin{{cases}}{left}x+a&(x<{first})\\{middle}x+({constant})&({first}\le x\le {second})\\{right}x+b&(x>{second})\end{{cases}}$)가 모든 실수에서 연속일 때 $(a+b$)를 구하시오.",
            answer=str(answer), tags=["#함수의연속", "#연속의정의", "#불연속", "#일치조건"],
            steps=[("첫 접합점에서 왼쪽 함수값과 가운데 함수값을 같게 놓는다.", "이 식으로 a를 결정한다."), ("둘째 접합점에서 가운데 함수값과 오른쪽 함수값을 같게 놓는다.", "이 식으로 b를 결정한다."), ("각 상수항을 계산한다.", "두 접합점 이외에서는 일차함수이므로 자동으로 연속이다."), ("두 상수항을 더한다.", rf"$(a+b={answer}$)이다."), ("두 접합점의 좌극한·함수값·우극한이 일치함을 검산한다.", rf"따라서 답은 $({answer}$)이다.")],
            alternatives=["그래프의 세 직선 조각이 각 접합점에서 같은 점을 지나도록 절편을 정할 수 있다."],
            answer_check=lambda values=row: _piecewise_continuity_parameter_sum(*values),
        ))
    integral_rows = [(8,0,2), (3,-5,1), (10,4,-2), (-2,6,3), (7,-3,-1)]
    for index, (first_value, negative_value, zero_value) in enumerate(integral_rows, 6):
        answer = _antiderivative_coefficient_sum(first_value, negative_value, zero_value)
        specs.append(_checked_problem(
            4, index,
            title=rf"다항함수 $(F(x)=x^3+ax^2+bx+c$)가 $(F(1)={first_value}$), $(F(-1)={negative_value}$), $(F(0)={zero_value}$)을 만족할 때 $(a+b+c$)를 구하시오.",
            answer=str(answer), tags=["#부정적분공식", "#부정적분의성질", "#부정적분의정의", "#미정계수법"],
            steps=[("x=0을 대입해 적분상수 c를 구한다.", rf"$(c={zero_value}$)이다."), ("x=1과 x=-1을 대입해 a,b의 연립방정식을 세운다.", "두 식을 더하면 a, 빼면 b를 구할 수 있다."), ("두 식을 더해 a를 계산한다.", "홀수차항과 b항이 소거된다."), ("두 식을 빼 b를 계산한다.", "a항과 c항이 소거된다."), ("a,b,c를 모두 더한다.", rf"따라서 $(a+b+c={answer}$)이다.")],
            alternatives=["F(x)-F(0)을 홀수 부분과 짝수 부분으로 나누어 계수를 구할 수 있다."],
            answer_check=lambda u=first_value, v=negative_value, w=zero_value: _antiderivative_coefficient_sum(u, v, w),
        ))
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 일차함수의 합성 역함수와 선형 제약의 곱이다. 작동 원리는 원상 계산과 완전제곱 최댓값 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    composition_rows = [(2,3,4,-1,20), (3,-2,-2,5,7), (-1,4,5,2,-6), (4,1,3,-2,30), (-3,2,2,4,10)]
    for index, row in enumerate(composition_rows, 1):
        a,b,c,d,target=row
        answer = _composition_inverse_value(*row)
        specs.append(_checked_problem(
            5, index,
            title=rf"두 일차함수 $(f(x)={a}x+({b})$), $(g(x)={c}x+({d})$)에 대하여 $((f\circ g)^{{-1}}({target})$)의 값을 구하시오.",
            answer=str(answer), tags=["#합성함수의정의", "#합성함수의성질", "#역함수", "#일대일대응"],
            steps=[("합성함수의 순서에 따라 g(x)를 먼저 계산한다.", rf"$((f\circ g)(x)=f({c}x+({d}))$)이다."), ("f에 대입해 일차식으로 정리한다.", rf"기울기는 $({a*c}$)이다."), ("합성함수의 값이 주어진 목표값이 되게 방정식을 세운다.", rf"$((f\circ g)(x)={target}$)이다."), ("일차방정식을 풀어 원상 x를 구한다.", rf"$(x={answer}$)이다."), ("합성함수의 기울기가 0이 아니므로 역함수가 존재함을 확인한다.", "원상은 유일하다."), ("원래 합성식에 대입해 목표값을 얻는지 검산한다.", rf"따라서 역함수값은 $({answer}$)이다.")],
            alternatives=["합성함수의 역함수 $(g^{-1}\circ f^{-1}$)를 순서대로 적용할 수 있다.", "두 일차함수의 역함수를 각각 구해 검산할 수 있다."],
            answer_check=lambda values=row: _composition_inverse_value(*values),
        ))
    maximum_rows = [(24,2), (30,3), (40,4), (36,1), (50,5)]
    for index, (total, weight) in enumerate(maximum_rows, 6):
        answer = _resource_product_maximum(total, weight)
        specs.append(_checked_problem(
            5, index,
            title=rf"양수 x, y가 $(x+{weight}y={total}$)을 만족할 때 곱 $(xy$)의 최댓값을 구하시오.",
            answer=str(answer), tags=["#최대최소문제", "#최댓값", "#이차함수의최대최소", "#완전제곱식"],
            steps=[("제약식에서 y를 x에 관해 나타낸다.", rf"$(y=({total}-x)/{weight}$)이다."), ("곱을 x의 이차함수로 바꾼다.", rf"$(xy=x({total}-x)/{weight}$)이다."), ("아래로 열린 이차함수임을 확인한다.", "꼭짓점에서 최댓값을 갖는다."), ("완전제곱하거나 축 공식으로 꼭짓점의 x를 구한다.", rf"$(x={total}/2$)이다."), ("제약식으로 대응하는 y를 구한다.", rf"$(y={total}/(2\cdot {weight})$)이다."), ("두 값을 곱한다.", rf"따라서 최댓값은 $({answer}$)이다.")],
            alternatives=["산술평균과 기하평균의 관계를 적절히 적용할 수 있다.", "판별식이 0인 조건으로 가능한 곱의 최댓값을 구할 수 있다."],
            answer_check=lambda s=total, k=weight: _resource_product_maximum(s, k),
        ))
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v44 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v44 전체 카탈로그다. 작동 원리는 독립 정답 검산 후 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog = build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v44 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(catalog, expected_count=50, batch_id=BATCH_ID, model_name=MODEL_NAME, codebase_base=CODEBASE_BASE, seed_base=SEED_BASE)


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v44 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(db_path, quests=validated_quests(), batch_id=BATCH_ID, validate_only=validate_only)


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v44 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
