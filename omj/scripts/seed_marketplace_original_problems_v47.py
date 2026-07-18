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

BATCH_ID = "marketplace-original-v47"
MODEL_NAME = "aiflow-direct-authoring-v47"
CODEBASE_BASE = 20_261_008_000
SEED_BASE = 202_607_587_000


def _checked_problem(tier: int, index: int, *, answer_check: Callable[[], Any], **kwargs: Any) -> dict[str, Any]:
    """필요 변수는 문제 명세와 독립 계산 함수다. 작동 원리는 저장 답과 별도 계산 결과를 비교하도록 검산 함수를 부착한다."""
    spec = _problem(tier, index, **kwargs)
    spec["answer_check"] = answer_check
    return spec


def _reciprocal_radical_difference(first_root: int, second_root: int) -> Fraction:
    """필요 변수는 두 양의 정수 제곱근이다. 작동 원리는 켤레식을 곱해 근호 차의 역수를 정확히 계산한다."""
    if first_root <= second_root:
        raise ValueError("첫 제곱근이 더 커야 합니다.")
    return Fraction(first_root + second_root, first_root**2 - second_root**2)


def _symmetric_product_value(first: int, second: int) -> int:
    """필요 변수는 두 수다. 작동 원리는 (a+b)^2-(a-b)^2=4ab 곱셈공식으로 값을 계산한다."""
    return 4 * first * second


def _double_reflection_sum(point: tuple[int, int]) -> int:
    """필요 변수는 한 점의 좌표다. 작동 원리는 원점대칭 뒤 직선 y=x 대칭을 차례로 적용해 최종 좌표를 더한다."""
    after_origin = (-point[0], -point[1])
    after_line = (after_origin[1], after_origin[0])
    return after_line[0] + after_line[1]


def _parallel_line_intercept(point: tuple[int, int], normal: tuple[int, int]) -> Fraction:
    """필요 변수는 직선 위 점과 평행선 법선벡터다. 작동 원리는 ax+by=k에 점을 대입하고 x=0으로 y절편을 구한다."""
    if normal[1] == 0:
        raise ValueError("유한한 y절편이 필요합니다.")
    constant = normal[0] * point[0] + normal[1] * point[1]
    return Fraction(constant, normal[1])


def _excluded_rational_range(matrix: tuple[int, int, int, int]) -> Fraction:
    """필요 변수는 일차분수함수 계수다. 작동 원리는 수평점근선이자 치역에서 빠지는 값 a/c를 구한다."""
    a, b, c, d = matrix
    if c == 0 or a * d - b * c == 0:
        raise ValueError("상수함수가 아닌 일차분수함수가 필요합니다.")
    return Fraction(a, c)


def _root_reciprocal_sum(root_sum: int, root_product: int) -> Fraction:
    """필요 변수는 이차방정식 두 근의 합과 곱이다. 작동 원리는 1/α+1/β=(α+β)/(αβ)를 계산한다."""
    if root_product == 0:
        raise ValueError("두 근이 0이 아니어야 합니다.")
    return Fraction(root_sum, root_product)


def _solve_three_by_three(matrix: tuple[tuple[int, int, int, int], ...]) -> Fraction:
    """필요 변수는 3×4 확대행렬이다. 작동 원리는 정확한 분수 가우스 소거법으로 세 해를 구해 더한다."""
    rows = [[Fraction(value) for value in row] for row in matrix]
    for column in range(3):
        pivot = next((row for row in range(column, 3) if rows[row][column] != 0), None)
        if pivot is None:
            raise ValueError("유일해를 갖는 연립방정식이 필요합니다.")
        rows[column], rows[pivot] = rows[pivot], rows[column]
        pivot_value = rows[column][column]
        rows[column] = [value / pivot_value for value in rows[column]]
        for row in range(3):
            if row == column:
                continue
            factor = rows[row][column]
            rows[row] = [value - factor * pivot_item for value, pivot_item in zip(rows[row], rows[column])]
    return sum(rows[row][3] for row in range(3))


def _decreasing_interval_length(first_critical: int, second_critical: int, leading_sign: int) -> int:
    """필요 변수는 도함수의 두 근과 최고차항 부호다. 작동 원리는 위로 열린 도함수가 음수인 두 근 사이 길이를 구한다."""
    if leading_sign <= 0 or first_critical >= second_critical:
        raise ValueError("양의 최고차항과 오름차순 임계점이 필요합니다.")
    return second_critical - first_critical


def _diameter_circle_coefficient_sum(first: tuple[int, int], second: tuple[int, int]) -> Fraction:
    """필요 변수는 지름의 두 끝점이다. 작동 원리는 중심과 반지름을 구해 x²+y²+Dx+Ey+F의 계수합을 계산한다."""
    center_x = Fraction(first[0] + second[0], 2)
    center_y = Fraction(first[1] + second[1], 2)
    radius_squared = Fraction((first[0] - second[0]) ** 2 + (first[1] - second[1]) ** 2, 4)
    d_coefficient = -2 * center_x
    e_coefficient = -2 * center_y
    f_coefficient = center_x**2 + center_y**2 - radius_squared
    return d_coefficient + e_coefficient + f_coefficient


def _variable_integral_derivative(
    quadratic: tuple[int, int, int],
    lower_linear: tuple[int, int],
    upper_linear: tuple[int, int],
    point: int,
) -> int:
    """필요 변수는 적분함수·상하한 일차식·평가점이다. 작동 원리는 미적분 기본정리와 연쇄법칙으로 도함수값을 구한다."""
    def integrand(value: int) -> int:
        """필요 변수는 적분함수 입력값이다. 작동 원리는 이차다항식에 정수를 대입한다."""
        return quadratic[0] * value**2 + quadratic[1] * value + quadratic[2]
    lower = lower_linear[0] * point + lower_linear[1]
    upper = upper_linear[0] * point + upper_linear[1]
    return integrand(upper) * upper_linear[0] - integrand(lower) * lower_linear[0]


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 근호 차의 역수와 합차 제곱식이다. 작동 원리는 유리화와 곱셈공식 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    radical_rows = [(5,3),(7,5),(4,1),(9,7),(6,2)]
    for index, (first,second) in enumerate(radical_rows, 1):
        answer = _reciprocal_radical_difference(first,second)
        specs.append(_checked_problem(
            1,index,
            title=rf"값 $(\dfrac1{{\sqrt{{{first**2}}}-\sqrt{{{second**2}}}}}$)을 유리화하여 구하시오.",
            answer=str(answer), tags=["#무리식의계산","#유리화","#무리식","#대수"],
            steps=[("분모의 켤레식을 분자와 분모에 곱한다.", rf"켤레식은 $(\sqrt{{{first**2}}}+\sqrt{{{second**2}}}$)이다."), ("분모를 두 제곱의 차로 계산하고 약분한다.", rf"따라서 값은 $({answer}$)이다.")],
            answer_check=lambda a=first,b=second: _reciprocal_radical_difference(a,b),
        ))
    product_rows = [(3,5),(-2,7),(4,-3),(-5,-2),(6,1)]
    for index,(first,second) in enumerate(product_rows,6):
        answer=_symmetric_product_value(first,second)
        specs.append(_checked_problem(
            1,index,
            title=rf"$((({first})+({second}))^2-((({first})-({second}))^2$)의 값을 곱셈공식을 이용하여 구하시오.",
            answer=str(answer), tags=["#곱셈공식","#인수분해법","#합차공식","#공통수학1"],
            steps=[("두 제곱의 차를 인수분해한다.", "$((a+b)^2-(a-b)^2=((a+b)+(a-b))((a+b)-(a-b))$)이다."), ("두 인수를 정리해 곱한다.", rf"따라서 값은 $({answer}$)이다.")],
            answer_check=lambda a=first,b=second: _symmetric_product_value(a,b),
        ))
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 연속 대칭이동한 점과 평행선의 한 점이다. 작동 원리는 최종 좌표합과 y절편 문제 10개를 만든다."""
    specs: list[dict[str, Any]]=[]
    point_rows=[(2,5),(-3,4),(6,-1),(-2,-7),(5,3)]
    for index,point in enumerate(point_rows,1):
        answer=_double_reflection_sum(point)
        specs.append(_checked_problem(
            2,index,
            title=rf"점 $(P{point}$)를 원점에 대칭이동한 뒤, 얻은 점을 다시 직선 $(y=x$)에 대칭이동하였다. 최종 점의 두 좌표의 합을 구하시오.",
            answer=str(answer), tags=["#원점대칭","#직선대칭","#대칭이동","#좌표평면"],
            steps=[("원점대칭으로 두 좌표의 부호를 모두 바꾼다.", rf"첫 이동 결과는 $(({-point[0]},{-point[1]})$)이다."), ("직선 y=x 대칭으로 두 좌표의 순서를 바꾼다.", "최종 좌표를 얻는다."), ("최종 두 좌표를 더한다.", rf"따라서 합은 $({answer}$)이다.")],
            answer_check=lambda p=point:_double_reflection_sum(p),
        ))
    line_rows=[((2,3),(1,-2)),((-1,4),(3,1)),((5,-2),(2,-1)),((-2,5),(1,3)),((4,5),(2,3))]
    for index,(point,normal) in enumerate(line_rows,6):
        answer=_parallel_line_intercept(point,normal)
        specs.append(_checked_problem(
            2,index,
            title=rf"점 $(P{point}$)를 지나고 직선 $({normal[0]}x+({normal[1]})y=0$)에 평행한 직선의 y절편을 구하시오.",
            answer=str(answer), tags=["#점기울기형","#두직선의위치관계","#평행조건","#y절편"],
            steps=[("평행한 직선은 같은 법선벡터를 가지므로 식을 세운다.", rf"$({normal[0]}x+({normal[1]})y=k$)이다."), ("점 P를 대입해 k를 구한다.", "주어진 점이 직선 위에 있어야 한다."), ("x=0을 대입해 y절편을 구한다.", rf"따라서 y절편은 $({answer}$)이다.")],
            answer_check=lambda p=point,n=normal:_parallel_line_intercept(p,n),
        ))
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 일차분수함수 계수와 이차방정식 근의 대칭식이다. 작동 원리는 치역 제외값과 역수합 문제 10개를 만든다."""
    specs:list[dict[str,Any]]=[]
    range_rows=[(2,3,1,4),(3,-1,2,5),(-2,4,3,1),(5,2,-1,3),(4,-3,2,-2)]
    for index,matrix in enumerate(range_rows,1):
        answer=_excluded_rational_range(matrix)
        specs.append(_checked_problem(
            3,index,
            title=rf"일차분수함수 $(f(x)=\dfrac{{{matrix[0]}x+({matrix[1]})}}{{{matrix[2]}x+({matrix[3]})}}$)의 치역에서 제외되는 유일한 실수 값을 구하시오.",
            answer=str(answer), tags=["#치역","#공역","#유리함수의그래프","#역함수"],
            steps=[("$(y=f(x)$)로 놓고 x에 관한 일차방정식으로 정리한다.", "x의 계수가 0이 되는 y에서는 해가 존재하지 않을 수 있다."), ("x의 계수가 0이 되는 조건을 구한다.", rf"$({matrix[2]}y-{matrix[0]}=0$)이다."), ("행렬식이 0이 아니므로 그 값에서 상수항은 0이 아니다.", "따라서 그 y값만 치역에서 빠진다."), ("값을 계산한다.", rf"제외되는 값은 $({answer}$)이다.")],
            alternatives=["수평점근선 $(y=a/c$)와 일차분수함수의 치역 관계를 이용할 수 있다."],
            answer_check=lambda m=matrix:_excluded_rational_range(m),
        ))
    root_rows=[(7,10),(9,14),(-3,-4),(5,6),(11,24)]
    for index,(root_sum,root_product) in enumerate(root_rows,6):
        answer=_root_reciprocal_sum(root_sum,root_product)
        specs.append(_checked_problem(
            3,index,
            title=rf"이차방정식 $(x^2-({root_sum})x+({root_product})=0$)의 두 근을 $(\alpha,\beta$)라 할 때 $(\dfrac1\alpha+\dfrac1\beta$)의 값을 구하시오.",
            answer=str(answer), tags=["#이차방정식의풀이","#근의공식","#두근의합","#두근의곱"],
            steps=[("근과 계수의 관계로 합과 곱을 읽는다.", rf"$(\alpha+\beta={root_sum},\alpha\beta={root_product}$)이다."), ("두 역수의 합을 통분한다.", "$(1/\alpha+1/\beta=(\alpha+\beta)/(\alpha\beta)$)이다."), ("합과 곱을 대입한다.", rf"값은 $({answer}$)이다."), ("근의 곱이 0이 아니어서 식이 정의됨을 확인한다.", rf"따라서 답은 $({answer}$)이다.")],
            alternatives=["근의 공식을 적용해 두 근을 직접 구한 뒤 역수를 더할 수 있다."],
            answer_check=lambda s=root_sum,p=root_product:_root_reciprocal_sum(s,p),
        ))
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 3원 연립방정식과 도함수의 두 근이다. 작동 원리는 가우스 소거 해의 합과 감소구간 길이 문제 10개를 만든다."""
    specs:list[dict[str,Any]]=[]
    system_rows=[
        ((1,1,1,6),(2,-1,1,3),(1,2,-1,2)),
        ((2,1,-1,4),(1,-1,2,1),(3,2,1,9)),
        ((1,2,3,14),(2,-1,1,3),(3,1,-1,2)),
        ((3,1,2,10),(1,2,-1,1),(2,-1,1,4)),
        ((2,3,1,11),(1,-2,2,1),(3,1,-1,4)),
    ]
    for index,matrix in enumerate(system_rows,1):
        answer=_solve_three_by_three(matrix)
        specs.append(_checked_problem(
            4,index,
            title=rf"확대행렬 $(\begin{{pmatrix}}{matrix[0][0]}&{matrix[0][1]}&{matrix[0][2]}&|&{matrix[0][3]}\\{matrix[1][0]}&{matrix[1][1]}&{matrix[1][2]}&|&{matrix[1][3]}\\{matrix[2][0]}&{matrix[2][1]}&{matrix[2][2]}&|&{matrix[2][3]}\end{{pmatrix}}$)로 주어진 연립방정식의 해 $((x,y,z)$)에 대하여 $(x+y+z$)를 구하시오.",
            answer=str(answer), tags=["#가우스소거법","#연립일차방정식과행렬","#행렬의연산","#행렬의정의"],
            steps=[("첫 열의 피벗을 정하고 아래 성분을 행 연산으로 0으로 만든다.", "해집합을 바꾸지 않는 기본행 연산을 사용한다."), ("둘째 열에서도 피벗 아래 성분을 0으로 만든다.", "행 사다리꼴을 얻는다."), ("마지막 방정식부터 z를 구한다.", "후진대입을 시작한다."), ("z를 위 식에 대입해 y와 x를 차례로 구한다.", "세 해가 유일하게 결정된다."), ("세 해를 원래 세 식에 대입해 검산한 뒤 더한다.", rf"따라서 $(x+y+z={answer}$)이다.")],
            alternatives=["크래머 공식으로 각 해를 행렬식의 비로 구할 수 있다."],
            answer_check=lambda m=matrix:_solve_three_by_three(m),
        ))
    interval_rows=[(-2,3,1),(1,7,2),(-5,-1,3),(0,6,1),(-3,5,4)]
    for index,(first,second,leading) in enumerate(interval_rows,6):
        answer=_decreasing_interval_length(first,second,leading)
        specs.append(_checked_problem(
            4,index,
            title=rf"미분가능한 함수 f의 도함수가 $(f'(x)={leading}(x-({first}))(x-({second}))$)일 때, f가 감소하는 열린구간의 길이를 구하시오.",
            answer=str(answer), tags=["#감소함수","#증가함수","#함수의증가와감소","#도함수의부호"],
            steps=[("도함수의 두 영점을 찾는다.", rf"임계점은 $(x={first},{second}$)이다."), ("도함수 최고차항 계수가 양수임을 확인한다.", "도함수는 두 근 바깥에서 양수, 사이에서 음수이다."), ("f는 도함수가 음수인 구간에서 감소한다.", rf"감소구간은 $(({first},{second})$)이다."), ("구간의 길이를 두 끝점의 차로 계산한다.", rf"길이는 $({answer}$)이다."), ("끝점 포함 여부가 길이에 영향을 주지 않음을 확인한다.", rf"따라서 답은 $({answer}$)이다.")],
            alternatives=["도함수 부호표를 그려 증가·감소 구간을 한눈에 판정할 수 있다."],
            answer_check=lambda a=first,b=second,c=leading:_decreasing_interval_length(a,b,c),
        ))
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 원의 지름 끝점과 가변 상하한 정적분이다. 작동 원리는 원 방정식 계수합과 미적분 기본정리 문제 10개를 만든다."""
    specs:list[dict[str,Any]]=[]
    circle_rows=[((1,2),(5,6)),((-3,1),(1,5)),((0,-2),(6,4)),((-4,-1),(2,3)),((3,-5),(7,1))]
    for index,(first,second) in enumerate(circle_rows,1):
        answer=_diameter_circle_coefficient_sum(first,second)
        specs.append(_checked_problem(
            5,index,
            title=rf"두 점 $(A{first}$), $(B{second}$)를 지름의 양 끝점으로 하는 원의 방정식을 $(x^2+y^2+Dx+Ey+F=0$)이라 할 때 $(D+E+F$)를 구하시오.",
            answer=str(answer), tags=["#중심","#반지름","#원의방정식","#중점","#두점사이의거리"],
            steps=[("지름의 중점으로 원의 중심을 구한다.", "중심은 A와 B 좌표의 평균이다."), ("AB 길이의 절반을 반지름으로 정한다.", "반지름 제곱은 AB 거리 제곱의 1/4이다."), ("중심-반지름형 원의 방정식을 세운다.", "$((x-h)^2+(y-k)^2=r^2$)이다."), ("두 제곱을 전개해 일반형으로 바꾼다.", "x와 y의 일차항 및 상수항을 모은다."), ("D,E,F를 각각 읽어 더한다.", rf"$(D+E+F={answer}$)이다."), ("두 끝점을 원의 방정식에 대입해 검산한다.", rf"따라서 답은 $({answer}$)이다.")],
            alternatives=["지름을 보는 원주각이 직각이라는 조건 $((X-A)\cdot(X-B)=0$)을 전개할 수 있다.", "중심과 한 끝점의 거리로 반지름을 구할 수 있다."],
            answer_check=lambda a=first,b=second:_diameter_circle_coefficient_sum(a,b),
        ))
    integral_rows=[
        ((1,0,1),(1,0),(2,1),1),
        ((2,-1,3),(1,-1),(1,2),2),
        ((1,2,0),(2,0),(1,1),1),
        ((3,0,-2),(1,1),(2,-1),2),
        ((1,-3,4),(1,-2),(3,0),1),
    ]
    for index,(quadratic,lower,upper,point) in enumerate(integral_rows,6):
        answer=_variable_integral_derivative(quadratic,lower,upper,point)
        specs.append(_checked_problem(
            5,index,
            title=rf"$(F(x)=\int_{{{lower[0]}x+({lower[1]})}}^{{{upper[0]}x+({upper[1]})}}\left({quadratic[0]}t^2+({quadratic[1]})t+({quadratic[2]})\right)dt$)일 때 $(F'({point})$)를 구하시오.",
            answer=str(answer), tags=["#미적분의기본정리","#정적분의성질","#합성함수의성질","#도함수공식"],
            steps=[("적분함수를 $(p(t)$), 하한과 상한을 각각 $(u(x),v(x)$)로 둔다.", "상하한이 모두 x의 함수임을 확인한다."), ("가변 상하한 미분 공식을 적용한다.", "$(F'=p(v)v'-p(u)u'$)이다."), ("상한과 하한의 도함수를 구한다.", rf"각각 $({upper[0]},{lower[0]}$)이다."), ("x에 주어진 값을 대입해 두 끝점 값을 계산한다.", "그 값을 이차식 p에 대입한다."), ("상한 항에서 하한 항을 뺀다.", rf"계산 결과는 $({answer}$)이다."), ("직접 원시함수를 구해 합성함수로 미분하여 검산한다.", rf"따라서 $(F'({point})={answer}$)이다.")],
            alternatives=["적분함수의 원시함수 P를 이용해 $(F=P(v)-P(u)$)로 쓴 뒤 미분할 수 있다.", "상한과 하한 적분을 기준점에서 둘로 나누어 각각 미분할 수 있다."],
            answer_check=lambda q=quadratic,l=lower,u=upper,x=point:_variable_integral_derivative(q,l,u,x),
        ))
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v47 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(),*_tier2_specs(),*_tier3_specs(),*_tier4_specs(),*_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v47 전체 카탈로그다. 작동 원리는 독립 정답 검산 후 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog=build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v47 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(catalog,expected_count=50,batch_id=BATCH_ID,model_name=MODEL_NAME,codebase_base=CODEBASE_BASE,seed_base=SEED_BASE)


def seed_database(db_path: Path,*,validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v47 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(db_path,quests=validated_quests(),batch_id=BATCH_ID,validate_only=validate_only)


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v47 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
    parser=argparse.ArgumentParser()
    parser.add_argument("--db",type=Path,default=ROOT/"quests.db")
    parser.add_argument("--validate-only",action="store_true")
    args=parser.parse_args()
    print(json.dumps(seed_database(args.db,validate_only=args.validate_only),ensure_ascii=False,indent=2))


if __name__=="__main__":
    main()
