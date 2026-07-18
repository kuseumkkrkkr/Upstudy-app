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

BATCH_ID = "marketplace-original-v51"
MODEL_NAME = "aiflow-direct-authoring-v51"
CODEBASE_BASE = 20_261_012_000
SEED_BASE = 202_607_591_000


def _checked_problem(tier: int, index: int, *, answer_check: Callable[[], Any], **kwargs: Any) -> dict[str, Any]:
    """필요 변수는 문제 명세와 독립 계산 함수다. 작동 원리는 저장 답과 별도 계산 결과를 비교하도록 검산 함수를 부착한다."""
    spec = _problem(tier, index, **kwargs)
    spec["answer_check"] = answer_check
    return spec


def _symmetric_difference_sum(upper: int, divisor: int, modulus: int, remainder: int) -> int:
    """필요 변수는 전체집합 상한과 두 조건이다. 작동 원리는 두 집합 중 정확히 하나에 속하는 원소만 합한다."""
    return sum(
        x for x in range(1, upper + 1)
        if (x % divisor == 0) != (x % modulus == remainder)
    )


def _reciprocal_complex_real_part(real: int, imaginary: int) -> Fraction:
    """필요 변수는 0이 아닌 복소수의 실수부·허수부다. 작동 원리는 켤레복소수로 역수를 유리화해 z+1/z의 실수부를 계산한다."""
    denominator = real**2 + imaginary**2
    if denominator == 0:
        raise ValueError("0이 아닌 복소수가 필요합니다.")
    return real + Fraction(real, denominator)


def _quadratic_integer_count(first_root: int, second_root: int, lower: int, upper: int) -> int:
    """필요 변수는 이차식 두 근과 정수 범위다. 작동 원리는 곱이 양수인 두 근 바깥 정수해를 센다."""
    if first_root > second_root:
        first_root, second_root = second_root, first_root
    return sum(
        (x - first_root) * (x - second_root) > 0
        for x in range(lower, upper + 1)
    )


def _external_point_origin_distance_squared(
    first: tuple[int, int],
    second: tuple[int, int],
    first_weight: int,
    second_weight: int,
) -> Fraction:
    """필요 변수는 두 점과 외분비다. 작동 원리는 외분점 좌표를 구해 원점 거리 제곱을 계산한다."""
    if first_weight == second_weight:
        raise ValueError("서로 다른 외분비 수가 필요합니다.")
    denominator = first_weight - second_weight
    x_value = Fraction(first_weight * second[0] - second_weight * first[0], denominator)
    y_value = Fraction(first_weight * second[1] - second_weight * first[1], denominator)
    return x_value**2 + y_value**2


def _bounded_exponential_solution_sum(
    base_numerator: int,
    base_denominator: int,
    linear: int,
    constant: int,
    boundary: int,
    lower: int,
    upper: int,
) -> int:
    """필요 변수는 지수부등식 밑·지수식·정수 범위다. 작동 원리는 증가·감소에 맞춰 지수를 비교하고 해를 합한다."""
    base = Fraction(base_numerator, base_denominator)
    if base <= 0 or base == 1:
        raise ValueError("양수이면서 1이 아닌 밑이 필요합니다.")
    return sum(
        x for x in range(lower, upper + 1)
        if ((linear * x + constant) < boundary) == (base > 1)
    )


def _radical_derivative_limit(linear: int, constant: int, point: int, root_value: int) -> Fraction:
    """필요 변수는 근호 안 일차식·접근점·근호값이다. 작동 원리는 켤레식으로 유리화해 미분계수형 극한을 계산한다."""
    if linear * point + constant != root_value**2 or root_value <= 0:
        raise ValueError("접근점의 근호값과 상수가 일치해야 합니다.")
    return Fraction(linear, 2 * root_value)


def _sign_change_left_endpoint_sum(values: tuple[int, ...]) -> int:
    """필요 변수는 연속함수의 연속한 정수점 함수값이다. 작동 원리는 부호가 바뀌는 구간의 왼쪽 끝점을 합한다."""
    if any(value == 0 for value in values):
        raise ValueError("표본점 자체가 근이 아닌 값이 필요합니다.")
    return sum(index for index, (first, second) in enumerate(zip(values, values[1:])) if first * second < 0)


def _quadratic_range_width(leading: int, axis: int, vertical: int, lower: int, upper: int) -> int:
    """필요 변수는 꼭짓점형 이차함수와 닫힌 정의역이다. 작동 원리는 꼭짓점·끝점 함수값의 최대와 최소 차를 구한다."""
    if leading == 0 or lower > upper:
        raise ValueError("이차함수와 올바른 닫힌구간이 필요합니다.")
    candidates = [leading * (x - axis) ** 2 + vertical for x in (lower, upper)]
    if lower <= axis <= upper:
        candidates.append(vertical)
    return max(candidates) - min(candidates)


def _distance_minus_displacement(first_zero: int, second_zero: int, end_time: int) -> Fraction:
    """필요 변수는 이차 속도의 두 영점과 종료 시각이다. 작동 원리는 음의 속도 구간 이동량 절댓값의 두 배를 계산한다."""
    if not 0 < first_zero < second_zero < end_time:
        raise ValueError("두 방향 전환 시각이 측정 구간 안에 있어야 합니다.")
    pair_sum = first_zero + second_zero
    product = first_zero * second_zero

    def primitive(time: int) -> Fraction:
        """필요 변수는 시각이다. 작동 원리는 전개한 이차 속도의 원시함수 값을 계산한다."""
        return Fraction(time**3, 3) - Fraction(pair_sum * time**2, 2) + product * time

    negative_displacement = primitive(second_zero) - primitive(first_zero)
    return -2 * negative_displacement


def _three_system_solution_product(rows: tuple[tuple[int, int, int, int], ...]) -> Fraction:
    """필요 변수는 3×4 확대행렬이다. 작동 원리는 정확한 분수 가우스 소거로 세 해를 구해 곱한다."""
    matrix = [[Fraction(value) for value in row] for row in rows]
    for column in range(3):
        pivot = next((index for index in range(column, 3) if matrix[index][column]), None)
        if pivot is None:
            raise ValueError("유일해를 갖는 연립방정식이 필요합니다.")
        matrix[column], matrix[pivot] = matrix[pivot], matrix[column]
        pivot_value = matrix[column][column]
        matrix[column] = [value / pivot_value for value in matrix[column]]
        for index in range(3):
            if index == column:
                continue
            factor = matrix[index][column]
            matrix[index] = [value - factor * pivot_item for value, pivot_item in zip(matrix[index], matrix[column])]
    return matrix[0][3] * matrix[1][3] * matrix[2][3]


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 조건집합과 복소수 역수다. 작동 원리는 대칭차집합 합과 유리화한 실수부 문제 10개를 만든다."""
    specs: list[dict[str, Any]]=[]
    set_rows=[(24,3,4,1),(30,5,3,2),(36,4,5,2),(40,6,4,3),(50,7,5,1)]
    for index,row in enumerate(set_rows,1):
        upper,divisor,modulus,remainder=row
        answer=_symmetric_difference_sum(*row)
        specs.append(_checked_problem(
            1,index,
            title=rf"$U=\{{1,2,\ldots,{upper}\}}$에서 A는 {divisor}의 배수 집합, B는 {modulus}로 나눈 나머지가 {remainder}인 수의 집합이다. $(A-B)\cup(B-A)$의 원소 합을 구하시오.",
            answer=str(answer), tags=["#집합의연산","#차집합","#합집합","#공통수학1"],
            steps=[("두 집합 중 정확히 하나에만 속하는 원소를 찾는다.", "교집합 원소는 두 차집합에서 모두 제외된다."), ("찾은 원소를 중복 없이 더한다.", rf"따라서 합은 ${answer}$이다.")],
            answer_check=lambda values=row:_symmetric_difference_sum(*values),
        ))
    complex_rows=[(2,1),(3,-2),(-1,4),(5,2),(-3,-1)]
    for index,(real,imaginary) in enumerate(complex_rows,6):
        answer=_reciprocal_complex_real_part(real,imaginary)
        specs.append(_checked_problem(
            1,index,
            title=rf"복소수 $z=({real})+({imaginary})i$에 대하여 $z+\dfrac1z$의 실수부를 구하시오.",
            answer=str(answer), tags=["#켤레복소수","#복소수의연산","#유리화","#실수와허수"],
            steps=[("1/z의 분모와 분자에 z의 켤레복소수를 곱한다.", "분모는 실수 $a^2+b^2$이 된다."), ("z의 실수부와 역수의 실수부를 더한다.", rf"따라서 실수부는 ${answer}$이다.")],
            answer_check=lambda a=real,b=imaginary:_reciprocal_complex_real_part(a,b),
        ))
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 이차부등식의 두 근과 외분점이다. 작동 원리는 제한 정수해 개수와 원점 거리 제곱 문제 10개를 만든다."""
    specs:list[dict[str,Any]]=[]
    inequality_rows=[(-2,4,-6,8),(1,6,-3,10),(-5,2,-8,6),(3,9,0,12),(-4,5,-10,9)]
    for index,row in enumerate(inequality_rows,1):
        first,second,lower,upper=row
        answer=_quadratic_integer_count(*row)
        specs.append(_checked_problem(
            2,index,
            title=rf"정수 범위 ${lower}\le x\le {upper}$에서 이차부등식 $(x-({first}))(x-({second}))>0$을 만족하는 x의 개수를 구하시오.",
            answer=str(answer), tags=["#이차부등식","#이차부등식의풀이","#이차부등식의해","#이차함수와이차부등식"],
            steps=[("두 근을 경계로 이차식의 부호를 조사한다.", "최고차항 계수가 양수이므로 두 근 바깥에서 양수이다."), ("엄격한 부등호이므로 두 근은 제외한다.", "주어진 정수 범위와 공통인 해만 남긴다."), ("정수해의 개수를 센다.", rf"따라서 개수는 ${answer}$이다.")],
            answer_check=lambda values=row:_quadratic_integer_count(*values),
        ))
    point_rows=[((1,2),(5,6),3,1),((-2,4),(4,-2),2,1),((3,-1),(-1,7),5,2),((0,5),(6,1),4,1),((-3,-4),(5,2),3,2)]
    for index,(first,second,m,n) in enumerate(point_rows,6):
        answer=_external_point_origin_distance_squared(first,second,m,n)
        specs.append(_checked_problem(
            2,index,
            title=rf"점 $A{first}$, $B{second}$를 잇는 선분을 ${m}:{n}$으로 외분하는 점 P에 대하여 원점 O와의 거리 제곱 $OP^2$을 구하시오.",
            answer=str(answer), tags=["#외분점","#공통수학2","#거리공식","#좌표평면"],
            steps=[("외분점 공식으로 P의 좌표를 구한다.", rf"$P=({m}B-{n}A)/({m}-{n})$이다."), ("원점에서 P까지의 거리 제곱은 두 좌표 제곱합이다.", "제곱근을 취할 필요가 없다."), ("두 좌표의 제곱을 더해 정리한다.", rf"따라서 $OP^2={answer}$이다.")],
            answer_check=lambda a=first,b=second,p=m,q=n:_external_point_origin_distance_squared(a,b,p,q),
        ))
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 지수부등식과 근호 미분계수형 극한이다. 작동 원리는 제한 정수해 합과 유리화 극한 문제 10개를 만든다."""
    specs:list[dict[str,Any]]=[]
    exponent_rows=[(2,1,2,-1,7,-4,8),(1,2,3,2,5,-5,7),(3,1,-1,4,0,-6,9),(1,3,2,5,9,-3,10),(5,1,3,-4,8,-7,6)]
    for index,row in enumerate(exponent_rows,1):
        numerator,denominator,linear,constant,boundary,lower,upper=row
        answer=_bounded_exponential_solution_sum(*row)
        specs.append(_checked_problem(
            3,index,
            title=rf"정수 범위 ${lower}\le x\le {upper}$에서 $(\dfrac{{{numerator}}}{{{denominator}}})^{{{linear}x+({constant})}}<(\dfrac{{{numerator}}}{{{denominator}}})^{boundary}$을 만족하는 모든 x의 합을 구하시오.",
            answer=str(answer), tags=["#지수부등식","#지수방정식과지수부등식","#지수함수의성질","#지수"],
            steps=[("밑이 1보다 큰지 작은지 확인한다.", "감소함수인 경우 지수 부등호 방향을 반대로 바꾼다."), ("두 지수를 비교해 일차부등식을 푼다.", "경계의 엄격한 부등호를 유지한다."), ("주어진 정수 범위와 공통인 해를 나열한다.", "범위 밖 해를 제거한다."), ("정수해를 모두 더한다.", rf"따라서 합은 ${answer}$이다.")],
            alternatives=["지수함수 그래프의 증가·감소를 이용해 해의 범위를 판정할 수 있다."],
            answer_check=lambda values=row:_bounded_exponential_solution_sum(*values),
        ))
    limit_rows=[(2,7,1,3),(3,7,3,4),(4,9,4,5),(5,11,5,6),(6,13,6,7)]
    for index,row in enumerate(limit_rows,6):
        linear,constant,point,root=row
        answer=_radical_derivative_limit(*row)
        specs.append(_checked_problem(
            3,index,
            title=rf"극한 $\lim_{{x\to {point}}}\dfrac{{\sqrt{{{linear}x+({constant})}}-{root}}}{{x-{point}}}$의 값을 구하시오.",
            answer=str(answer), tags=["#유리화를이용한극한","#유리화","#극한값계산","#무리식의계산"],
            steps=[("분자의 켤레식을 곱하고 나눈다.", "근호 차를 두 제곱의 차로 바꾼다."), ("분자에서 $linear(x-point)$가 나타나도록 정리한다.", "분모의 x-point와 약분한다."), ("약분한 식에 x=point를 대입한다.", rf"분모의 켤레합은 ${2*root}$이다."), ("계수비를 기약분수로 만든다.", rf"따라서 극한값은 ${answer}$이다.")],
            alternatives=["함수 $\sqrt{linear*x+constant}$의 미분계수로 해석할 수 있다."],
            answer_check=lambda values=row:_radical_derivative_limit(*values),
        ))
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 연속함수 부호표와 닫힌구간 이차함수다. 작동 원리는 근 보장 구간 왼쪽 끝 합과 치역 폭 문제 10개를 만든다."""
    specs:list[dict[str,Any]]=[]
    sign_rows=[(-2,3,-1,4,2),(5,2,-3,-1,6),(-1,4,3,-2,-5),(2,-4,5,-6,7),(-3,-2,1,4,-1)]
    for index,values in enumerate(sign_rows,1):
        answer=_sign_change_left_endpoint_sum(values)
        samples=", ".join(rf"f({i})={value}" for i,value in enumerate(values))
        specs.append(_checked_problem(
            4,index,
            title=rf"연속함수 f가 ${samples}$를 만족한다. 중간값정리로 $f(x)=0$인 해의 존재가 보장되는 단위 열린구간들의 왼쪽 끝점을 모두 더하시오.",
            answer=str(answer), tags=["#중간값정리","#연속함수의성질","#불연속","#함수의정의"],
            steps=[("연속한 두 정수점 함수값의 부호를 비교한다.", "부호가 다르면 중간값정리로 그 사이에 근이 존재한다."), ("각 인접 함수값의 곱이 음수인지 확인한다.", "끝점 값은 0이 아니므로 열린구간 안에 근이 있다."), ("부호가 바뀌는 단위구간을 모두 찾는다.", "한 구간에 여러 근이 있을 가능성은 개수에 영향을 주지 않는다."), ("찾은 구간의 왼쪽 끝점을 기록한다.", "정수점 번호가 바로 왼쪽 끝점이다."), ("왼쪽 끝점을 모두 더한다.", rf"따라서 합은 ${answer}$이다.")],
            alternatives=["함수값 부호를 수직선 위에 표시해 0을 가로지르는 구간을 찾을 수 있다."],
            answer_check=lambda row=values:_sign_change_left_endpoint_sum(row),
        ))
    range_rows=[(1,2,3,-1,6),(-2,1,4,-3,5),(3,-1,-2,-2,4),(2,3,1,0,7),(-1,-2,5,-5,2)]
    for index,row in enumerate(range_rows,6):
        leading,axis,vertical,lower,upper=row
        answer=_quadratic_range_width(*row)
        specs.append(_checked_problem(
            4,index,
            title=rf"닫힌구간 $[{lower},{upper}]$에서 이차함수 $f(x)={leading}(x-({axis}))^2+({vertical})$의 최댓값과 최솟값의 차를 구하시오.",
            answer=str(answer), tags=["#정의역에서의최대최소","#최댓값","#최솟값","#완성제곱법","#완전제곱식"],
            steps=[("꼭짓점형에서 축과 꼭짓점의 함수값을 읽는다.", rf"축은 $x={axis}$이다."), ("축이 닫힌구간 안에 있는지 확인한다.", "안에 있으면 꼭짓점 함수값을 후보에 포함한다."), ("구간의 두 끝점 함수값을 계산한다.", "닫힌구간 최대·최소는 꼭짓점 또는 끝점에서 생긴다."), ("후보값 중 최댓값과 최솟값을 고른다.", "이차항 부호도 함께 확인한다."), ("두 값을 뺀다.", rf"따라서 차는 ${answer}$이다.")],
            alternatives=["도함수 부호로 구간 내 증가·감소를 조사해 최대와 최소를 찾을 수 있다."],
            answer_check=lambda values=row:_quadratic_range_width(*values),
        ))
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 이차 속도의 방향 전환과 3원 연립방정식이다. 작동 원리는 거리-변위 차와 해의 곱 문제 10개를 만든다."""
    specs:list[dict[str,Any]]=[]
    motion_rows=[(1,3,5),(1,4,6),(2,5,7),(2,4,8),(3,6,9)]
    for index,row in enumerate(motion_rows,1):
        first,second,end=row
        answer=_distance_minus_displacement(*row)
        specs.append(_checked_problem(
            5,index,
            title=rf"수직선 위 점의 속도가 $v(t)=(t-{first})(t-{second})$일 때 $t=0$부터 $t={end}$까지 이동한 거리에서 변위를 뺀 값을 구하시오.",
            answer=str(answer), tags=["#속도","#위치변화량","#위치함수","#정적분과속도"],
            steps=[("속도가 0인 두 시각으로 구간을 나눈다.", rf"방향 전환은 $t={first},{second}$에서 일어난다."), ("각 구간의 속도 부호를 확인한다.", "가운데 구간에서만 속도가 음수이다."), ("변위는 속도의 전체 정적분이고 거리는 절댓값의 정적분이다.", "양의 속도 구간은 두 값에서 서로 상쇄된다."), ("거리-변위는 음의 속도 구간 변위 절댓값의 두 배이다.", rf"$-2\int_{{{first}}}^{{{second}}}v(t)dt$를 계산한다."), ("이차식을 전개해 원시함수를 구한다.", "두 끝점에 대입한다."), ("정확한 분수로 정리한다.", rf"따라서 값은 ${answer}$이다.")],
            alternatives=["위치함수의 극댓값과 극솟값 차를 두 배하여 구할 수 있다.", "전체 거리와 전체 변위를 각각 계산한 뒤 뺄 수 있다."],
            answer_check=lambda values=row:_distance_minus_displacement(*values),
        ))
    system_rows=[
        ((1,1,1,6),(2,-1,1,3),(1,2,-1,2)),
        ((2,1,-1,4),(1,-1,2,1),(3,2,1,9)),
        ((1,2,3,14),(2,-1,1,3),(3,1,-1,2)),
        ((3,1,2,10),(1,2,-1,1),(2,-1,1,4)),
        ((2,3,1,11),(1,-2,2,1),(3,1,-1,4)),
    ]
    for index,rows in enumerate(system_rows,6):
        answer=_three_system_solution_product(rows)
        specs.append(_checked_problem(
            5,index,
            title=rf"확대행렬 $\begin{{pmatrix}}{rows[0][0]}&{rows[0][1]}&{rows[0][2]}&|&{rows[0][3]}\\{rows[1][0]}&{rows[1][1]}&{rows[1][2]}&|&{rows[1][3]}\\{rows[2][0]}&{rows[2][1]}&{rows[2][2]}&|&{rows[2][3]}\end{{pmatrix}}$로 나타낸 연립방정식의 해를 $(x,y,z)$라 할 때 xyz를 구하시오.",
            answer=str(answer), tags=["#행렬","#행렬을이용한연립방정식","#가우스소거법","#행렬의연산"],
            steps=[("첫 열 피벗으로 아래 두 성분을 0으로 만든다.", "해를 보존하는 기본행 연산을 사용한다."), ("둘째 열 피벗으로 마지막 행의 둘째 성분을 0으로 만든다.", "행 사다리꼴을 얻는다."), ("마지막 행에서 z를 구한다.", "피벗이 0이 아니므로 유일하게 결정된다."), ("후진대입으로 y와 x를 차례로 구한다.", "세 해를 원래 식에 대입해 검산한다."), ("세 해를 모두 곱한다.", rf"$xyz={answer}$이다."), ("분수 해가 있으면 기약분수로 정리한다.", rf"따라서 답은 ${answer}$이다.")],
            alternatives=["크래머 공식으로 각 해를 행렬식의 비로 구할 수 있다.", "역행렬을 구해 상수 열벡터에 곱할 수 있다."],
            answer_check=lambda matrix=rows:_three_system_solution_product(matrix),
        ))
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v51 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(),*_tier2_specs(),*_tier3_specs(),*_tier4_specs(),*_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v51 전체 카탈로그다. 작동 원리는 독립 정답 검산 후 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog=build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v51 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(catalog,expected_count=50,batch_id=BATCH_ID,model_name=MODEL_NAME,codebase_base=CODEBASE_BASE,seed_base=SEED_BASE)


def seed_database(db_path: Path,*,validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v51 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(db_path,quests=validated_quests(),batch_id=BATCH_ID,validate_only=validate_only)


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v51 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
    parser=argparse.ArgumentParser()
    parser.add_argument("--db",type=Path,default=ROOT/"quests.db")
    parser.add_argument("--validate-only",action="store_true")
    args=parser.parse_args()
    print(json.dumps(seed_database(args.db,validate_only=args.validate_only),ensure_ascii=False,indent=2))


if __name__=="__main__":
    main()
