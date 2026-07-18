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

BATCH_ID = "marketplace-original-v50"
MODEL_NAME = "aiflow-direct-authoring-v50"
CODEBASE_BASE = 20_261_011_000
SEED_BASE = 202_607_590_000


def _checked_problem(tier: int, index: int, *, answer_check: Callable[[], Any], **kwargs: Any) -> dict[str, Any]:
    """필요 변수는 문제 명세와 독립 계산 함수다. 작동 원리는 저장 답과 별도 계산 결과를 비교하도록 검산 함수를 부착한다."""
    spec = _problem(tier, index, **kwargs)
    spec["answer_check"] = answer_check
    return spec


def _exponent_law_value(base: int, first: int, second: int, divisor: int) -> Fraction:
    """필요 변수는 밑과 곱·나눗셈 지수다. 작동 원리는 지수법칙으로 지수를 더하고 빼 정확한 값을 계산한다."""
    if base == 0 and first + second - divisor <= 0:
        raise ValueError("정의되는 거듭제곱식이 필요합니다.")
    exponent = first + second - divisor
    return Fraction(base**exponent) if exponent >= 0 else Fraction(1, base ** (-exponent))


def _cube_identity_value(first: int, second: int) -> int:
    """필요 변수는 두 수다. 작동 원리는 (a+b)^3+(a-b)^3=2a^3+6ab^2로 계산한다."""
    return (first + second) ** 3 + (first - second) ** 3


def _perpendicular_y_intercept(point: tuple[int, int], original_normal: tuple[int, int]) -> Fraction:
    """필요 변수는 한 점과 기준 직선의 법선벡터다. 작동 원리는 수직선 기울기 b/a를 사용해 y절편을 구한다."""
    a, b = original_normal
    if a == 0:
        raise ValueError("수직선이 수직선이 되지 않도록 기준 법선 x계수는 0이 아니어야 합니다.")
    slope = Fraction(b, a)
    return point[1] - slope * point[0]


def _mixed_selection_count(total: int, special: int, selected: int, special_selected: int) -> int:
    """필요 변수는 전체·특별 집단·선택 인원과 특별 선택 인원이다. 작동 원리는 두 집단 조합 수를 곱한다."""
    if not 0 <= special_selected <= special or selected - special_selected > total - special:
        raise ValueError("가능한 선택 조건이 필요합니다.")
    return math.comb(special, special_selected) * math.comb(total - special, selected - special_selected)


def _next_power_of_ten(characteristic: int) -> int:
    """필요 변수는 양의 수 상용로그의 정수부분이다. 작동 원리는 수보다 큰 가장 작은 10의 거듭제곱을 구한다."""
    if characteristic < 0:
        raise ValueError("1 이상인 수의 상용로그 정수부분이 필요합니다.")
    return 10 ** (characteristic + 1)


def _linear_inverse_pair_sum(slope: int, intercept: int, value: int) -> Fraction:
    """필요 변수는 일차함수 계수와 입력값이다. 작동 원리는 f(t)와 f^-1(t)를 각각 계산해 더한다."""
    if slope == 0:
        raise ValueError("역함수가 존재하는 일차함수가 필요합니다.")
    return slope * value + intercept + Fraction(value - intercept, slope)


def _normal_line_y_intercept(leading: int, linear: int, constant: int, point: int) -> Fraction:
    """필요 변수는 포물선 계수와 접점 x좌표다. 작동 원리는 접선 기울기의 음의 역수로 법선 y절편을 계산한다."""
    tangent_slope = 2 * leading * point + linear
    if tangent_slope == 0:
        raise ValueError("유한한 법선 기울기가 필요합니다.")
    point_y = leading * point**2 + linear * point + constant
    normal_slope = Fraction(-1, tangent_slope)
    return point_y - normal_slope * point


def _antiderivative_parameter_product(first_increment: int, second_increment: int) -> Fraction:
    """필요 변수는 F(1)-F(0), F(2)-F(1)이다. 작동 원리는 두 정적분 식으로 a,b를 풀어 곱한다."""
    quadratic = Fraction(second_increment - first_increment - 6, 2)
    linear = first_increment - 1 - quadratic
    return quadratic * linear


def _three_consecutive_circle_count(people: int) -> int:
    """필요 변수는 서로 다른 사람 수다. 작동 원리는 지정된 세 명을 한 블록으로 보고 내부 순서 3!을 곱한다."""
    if people < 3:
        raise ValueError("세 명 이상이 필요합니다.")
    return math.factorial(people - 3) * math.factorial(3)


def _hyperbola_tangent_triangle_area(numerator: int) -> int:
    """필요 변수는 중심 이동된 쌍곡선의 양의 분자다. 작동 원리는 접선의 두 점근선 절편으로 삼각형 넓이 2k를 구한다."""
    if numerator <= 0:
        raise ValueError("양의 분자가 필요합니다.")
    return 2 * numerator


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 지수법칙 식과 세제곱 대칭식이다. 작동 원리는 거듭제곱 값과 곱셈공식 문제 10개를 만든다."""
    specs: list[dict[str, Any]]=[]
    exponent_rows=[(2,5,3,6),(3,4,2,3),(5,3,1,2),(2,2,1,5),(4,3,2,4)]
    for index,row in enumerate(exponent_rows,1):
        base,first,second,divisor=row
        answer=_exponent_law_value(*row)
        specs.append(_checked_problem(
            1,index,
            title=rf"거듭제곱식 $\dfrac{{{base}^{first}\cdot {base}^{second}}}{{{base}^{divisor}}}$의 값을 구하시오.",
            answer=str(answer), tags=["#지수","#정수지수","#지수법칙의성질","#대수"],
            steps=[("같은 밑의 곱셈과 나눗셈 지수법칙을 적용한다.", rf"지수는 ${first}+{second}-{divisor}$이다."), ("정리된 거듭제곱을 계산한다.", rf"따라서 값은 ${answer}$이다.")],
            answer_check=lambda values=row:_exponent_law_value(*values),
        ))
    cube_rows=[(3,2),(5,1),(-2,4),(4,-3),(-5,-1)]
    for index,(first,second) in enumerate(cube_rows,6):
        answer=_cube_identity_value(first,second)
        specs.append(_checked_problem(
            1,index,
            title=rf"$(({first})+({second}))^3+(({first})-({second}))^3$의 값을 세제곱 공식을 이용하여 구하시오.",
            answer=str(answer), tags=["#세제곱공식","#인수분해공식","#곱셈공식","#공통수학1"],
            steps=[("$(a+b)^3$과 $(a-b)^3$을 각각 전개한다.", "a²b항과 b³항은 서로 소거된다."), ("남은 $2a^3+6ab^2$을 계산한다.", rf"따라서 값은 ${answer}$이다.")],
            answer_check=lambda a=first,b=second:_cube_identity_value(a,b),
        ))
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 기준 직선과 한 점 및 두 집단 선택 조건이다. 작동 원리는 수직선 y절편과 조합 수 문제 10개를 만든다."""
    specs:list[dict[str,Any]]=[]
    line_rows=[((2,3),(1,2)),((-1,4),(3,-1)),((5,-2),(2,3)),((-3,1),(4,1)),((4,5),(3,2))]
    for index,(point,normal) in enumerate(line_rows,1):
        answer=_perpendicular_y_intercept(point,normal)
        specs.append(_checked_problem(
            2,index,
            title=rf"점 $P{point}$를 지나고 직선 ${normal[0]}x+({normal[1]})y=0$에 수직인 직선의 y절편을 구하시오.",
            answer=str(answer), tags=["#수직조건","#점기울기형","#절편","#두직선의위치관계"],
            steps=[("기준 직선의 기울기에서 수직인 직선의 기울기를 구한다.", rf"수직선의 기울기는 ${Fraction(normal[1],normal[0])}$이다."), ("점기울기형으로 직선식을 세운다.", "주어진 점을 지나도록 상수항을 정한다."), ("x=0을 대입해 y절편을 계산한다.", rf"따라서 y절편은 ${answer}$이다.")],
            answer_check=lambda p=point,n=normal:_perpendicular_y_intercept(p,n),
        ))
    selection_rows=[(10,4,5,2),(12,5,6,3),(9,3,4,1),(15,6,7,4),(11,5,5,2)]
    for index,row in enumerate(selection_rows,6):
        total,special,selected,special_selected=row
        answer=_mixed_selection_count(*row)
        specs.append(_checked_problem(
            2,index,
            title=rf"서로 다른 {total}명 중 특별 집단에 속한 사람이 {special}명이다. 전체에서 {selected}명을 고르되 특별 집단에서 정확히 {special_selected}명을 고르는 경우의 수를 구하시오.",
            answer=str(answer), tags=["#조합의수","#조합의성질","#경우의수","#곱의법칙"],
            steps=[("특별 집단에서 필요한 인원을 조합으로 고른다.", rf"$\binom{{{special}}}{{{special_selected}}}$가지이다."), ("나머지 집단에서 남은 인원을 고른다.", rf"$\binom{{{total-special}}}{{{selected-special_selected}}}$가지이다."), ("두 선택이 독립이므로 곱의 법칙을 적용한다.", rf"따라서 경우의 수는 ${answer}$이다.")],
            answer_check=lambda values=row:_mixed_selection_count(*values),
        ))
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 상용로그 정수부분과 일차함수 역함수다. 작동 원리는 다음 10의 거듭제곱과 함수값 합 문제 10개를 만든다."""
    specs:list[dict[str,Any]]=[]
    log_rows=[(2,3),(4,7),(5,2),(3,8),(6,1)]
    for index,(characteristic,tenth) in enumerate(log_rows,1):
        answer=_next_power_of_ten(characteristic)
        specs.append(_checked_problem(
            3,index,
            title=rf"양수 N이 $\log_{{10}}N={characteristic}+\dfrac{{{tenth}}}{{10}}$을 만족한다. N보다 큰 10의 거듭제곱 중 가장 작은 값을 구하시오.",
            answer=str(answer), tags=["#상용로그","#로그함수의그래프","#진수","#로그의성질"],
            steps=[("상용로그 정수부분으로 N의 범위를 정한다.", rf"$10^{characteristic}<N<10^{characteristic+1}$이다."), ("소수부분이 0보다 크므로 아래 경계와 같지 않음을 확인한다.", "N은 두 연속한 10의 거듭제곱 사이에 있다."), ("N보다 큰 가장 작은 10의 거듭제곱을 고른다.", rf"그 값은 $10^{characteristic+1}$이다."), ("거듭제곱을 계산한다.", rf"따라서 값은 ${answer}$이다.")],
            alternatives=["상용로그 그래프에서 정수부분이 나타내는 자릿수 구간을 이용할 수 있다."],
            answer_check=lambda k=characteristic:_next_power_of_ten(k),
        ))
    inverse_rows=[(2,3,4),(3,-1,5),(-2,4,3),(5,2,-1),(-3,-2,6)]
    for index,(slope,intercept,value) in enumerate(inverse_rows,6):
        answer=_linear_inverse_pair_sum(slope,intercept,value)
        specs.append(_checked_problem(
            3,index,
            title=rf"일차함수 $f(x)={slope}x+({intercept})$에 대하여 $f({value})+f^{{-1}}({value})$의 값을 구하시오.",
            answer=str(answer), tags=["#역함수구하기","#역함수의그래프","#일대일함수","#직선대칭"],
            steps=[("f에 주어진 입력값을 대입한다.", "일차식의 함수값을 계산한다."), ("$y=f(x)$를 x에 대해 풀어 역함수를 구한다.", rf"$f^{{-1}}(y)=(y-({intercept}))/{slope}$이다."), ("역함수에도 같은 입력값을 대입한다.", "두 함수값을 정확한 분수로 계산한다."), ("두 결과를 더한다.", rf"따라서 합은 ${answer}$이다.")],
            alternatives=["$f(x)=t$의 해를 직접 구해 $f^{-1}(t)$를 계산할 수 있다."],
            answer_check=lambda a=slope,b=intercept,t=value:_linear_inverse_pair_sum(a,b,t),
        ))
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 포물선의 접점과 원시함수 증가량이다. 작동 원리는 법선 y절편과 적분계수 곱 문제 10개를 만든다."""
    specs:list[dict[str,Any]]=[]
    normal_rows=[(1,2,3,1),(2,-1,4,2),(-1,5,6,1),(3,1,-2,-1),(2,4,5,1)]
    for index,row in enumerate(normal_rows,1):
        leading,linear,constant,point=row
        answer=_normal_line_y_intercept(*row)
        specs.append(_checked_problem(
            4,index,
            title=rf"포물선 $y={leading}x^2+({linear})x+({constant})$ 위에서 x좌표가 {point}인 점을 지나고 그 점의 접선에 수직인 법선의 y절편을 구하시오.",
            answer=str(answer), tags=["#미분계수의기하적의미","#접선방정식구하기","#수직조건","#점기울기형"],
            steps=[("도함수에 접점 x좌표를 대입해 접선 기울기를 구한다.", "미분계수는 접선의 기울기이다."), ("법선 기울기를 접선 기울기의 음의 역수로 구한다.", "두 직선 기울기의 곱은 -1이다."), ("원래 함수에 접점 x좌표를 대입해 접점 y좌표를 구한다.", "법선이 지나는 점을 확정한다."), ("점기울기형으로 법선식을 세운다.", "x=0을 대입한다."), ("y절편을 기약분수로 정리한다.", rf"따라서 y절편은 ${answer}$이다.")],
            alternatives=["접선의 법선벡터를 직접 구해 직선 방정식을 세울 수 있다."],
            answer_check=lambda values=row:_normal_line_y_intercept(*values),
        ))
    integral_rows=[(5,14),(2,11),(8,19),(-1,7),(10,25)]
    for index,(first_increment,second_increment) in enumerate(integral_rows,6):
        answer=_antiderivative_parameter_product(first_increment,second_increment)
        specs.append(_checked_problem(
            4,index,
            title=rf"다항함수 F가 $F'(x)=3x^2+2ax+b$, $F(1)-F(0)={first_increment}$, $F(2)-F(1)={second_increment}$을 만족할 때 ab를 구하시오.",
            answer=str(answer), tags=["#부정적분","#부정적분의성질","#상수배의미분","#미정계수법"],
            steps=[("F의 한 원시함수를 쓴다.", "$F(x)=x^3+ax^2+bx+C$이다."), ("첫 증가량 조건을 대입한다.", rf"$1+a+b={first_increment}$이다."), ("둘째 증가량 조건을 계산한다.", rf"$7+3a+b={second_increment}$이다."), ("두 일차방정식을 빼 a를 구하고 b를 구한다.", "적분상수 C는 증가량에서 소거된다."), ("두 계수를 곱한다.", rf"따라서 $ab={answer}$이다.")],
            alternatives=["두 증가량을 각각 정적분 $\int F'$으로 나타내어 a,b를 구할 수 있다."],
            answer_check=lambda u=first_increment,v=second_increment:_antiderivative_parameter_product(u,v),
        ))
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 지정 세 명의 원순열 블록과 쌍곡선 접선이다. 작동 원리는 연속 착석 수와 점근선 삼각형 넓이 문제 10개를 만든다."""
    specs:list[dict[str,Any]]=[]
    for index,people in enumerate(range(6,11),1):
        answer=_three_consecutive_circle_count(people)
        specs.append(_checked_problem(
            5,index,
            title=rf"서로 다른 {people}명이 원탁에 앉을 때, 지정된 세 사람 A, B, C가 순서와 관계없이 서로 연속하여 앉는 경우의 수를 구하시오. 회전하여 같은 배치는 하나로 본다.",
            answer=str(answer), tags=["#원순열","#팩토리얼","#순열의수","#곱의법칙"],
            steps=[("A,B,C를 하나의 블록으로 본다.", rf"블록을 포함한 원순열 대상은 ${people-2}$개이다."), ("대상들의 원순열 수를 계산한다.", rf"$({people-3})!$가지이다."), ("블록 내부 세 사람의 순서를 센다.", "$3!$가지이다."), ("외부 원순열과 내부 순서를 곱한다.", rf"경우의 수는 $3!({people-3})!$이다."), ("회전 동치가 원순열 계수에 이미 반영되었음을 확인한다.", "별도로 사람 수로 나누지 않는다."), ("팩토리얼을 계산한다.", rf"따라서 경우의 수는 ${answer}$이다.")],
            alternatives=["한 사람의 자리를 고정한 뒤 세 사람 블록의 시작 위치를 세어 검산할 수 있다.", "선형 배열에서 블록을 센 뒤 회전 수로 나눌 수 있다."],
            answer_check=lambda n=people:_three_consecutive_circle_count(n),
        ))
    hyperbola_rows=[(2,1,3,2),(3,-2,1,1),(5,4,-3,2),(7,0,2,3),(11,-1,-2,1)]
    for index,(numerator,horizontal,vertical,point_offset) in enumerate(hyperbola_rows,6):
        answer=_hyperbola_tangent_triangle_area(numerator)
        specs.append(_checked_problem(
            5,index,
            title=rf"쌍곡선 $y=\dfrac{{{numerator}}}{{x-({horizontal})}}+({vertical})$ 위에서 $x={horizontal+point_offset}$인 점의 접선이 두 점근선과 이루는 삼각형의 넓이를 구하시오.",
            answer=str(answer), tags=["#쌍곡선","#유리함수의평행이동","#유리식의계산","#접선방정식구하기"],
            steps=[("중심을 원점으로 옮겨 $X=x-h,\ Y=y-v$로 놓는다.", rf"쌍곡선은 $Y={numerator}/X$이다."), ("접점의 X좌표와 Y좌표를 구한다.", rf"$X={point_offset},\ Y={numerator}/{point_offset}$이다."), ("도함수로 접선 기울기를 구한다.", "$dY/dX=-k/X^2$이다."), ("접선이 X축·Y축과 만나는 절편을 구한다.", "두 절편은 각각 접점 좌표의 두 배이다."), ("점근선이 좌표축 역할을 하므로 삼각형 넓이를 계산한다.", "넓이는 절편 절댓값 곱의 절반이다."), ("접점 좌표 곱이 k임을 적용한다.", rf"따라서 넓이는 ${answer}$이다.")],
            alternatives=["쌍곡선 접선식 $XX_0+YY_0=2k$를 사용해 절편을 바로 구할 수 있다.", "평행이동은 넓이를 바꾸지 않으므로 중심형에서만 계산할 수 있다."],
            answer_check=lambda k=numerator:_hyperbola_tangent_triangle_area(k),
        ))
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v50 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(),*_tier2_specs(),*_tier3_specs(),*_tier4_specs(),*_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v50 전체 카탈로그다. 작동 원리는 독립 정답 검산 후 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog=build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v50 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(catalog,expected_count=50,batch_id=BATCH_ID,model_name=MODEL_NAME,codebase_base=CODEBASE_BASE,seed_base=SEED_BASE)


def seed_database(db_path: Path,*,validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v50 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(db_path,quests=validated_quests(),batch_id=BATCH_ID,validate_only=validate_only)


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v50 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
    parser=argparse.ArgumentParser()
    parser.add_argument("--db",type=Path,default=ROOT/"quests.db")
    parser.add_argument("--validate-only",action="store_true")
    args=parser.parse_args()
    print(json.dumps(seed_database(args.db,validate_only=args.validate_only),ensure_ascii=False,indent=2))


if __name__=="__main__":
    main()
