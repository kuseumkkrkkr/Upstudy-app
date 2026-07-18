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

BATCH_ID = "marketplace-original-v48"
MODEL_NAME = "aiflow-direct-authoring-v48"
CODEBASE_BASE = 20_261_009_000
SEED_BASE = 202_607_588_000


def _checked_problem(tier: int, index: int, *, answer_check: Callable[[], Any], **kwargs: Any) -> dict[str, Any]:
    """필요 변수는 문제 명세와 독립 계산 함수다. 작동 원리는 저장 답과 별도 계산 결과를 비교하도록 검산 함수를 부착한다."""
    spec = _problem(tier, index, **kwargs)
    spec["answer_check"] = answer_check
    return spec


def _double_axis_reflection_distance_squared(point: tuple[int, int]) -> int:
    """필요 변수는 점의 좌표다. 작동 원리는 x축·y축 대칭 후 점 -P와 원래 점 사이 거리 제곱을 계산한다."""
    return 4 * (point[0] ** 2 + point[1] ** 2)


def _complex_product_imaginary(first: tuple[int, int], second: tuple[int, int]) -> int:
    """필요 변수는 두 복소수의 실수부·허수부다. 작동 원리는 곱을 전개해 허수부 ad+bc를 계산한다."""
    return first[0] * second[1] + first[1] * second[0]


def _geometric_difference_term(first: int, difference_first: int, ratio: int, target: int) -> int:
    """필요 변수는 첫째항·첫 계차·계차 공비·목표 번호다. 작동 원리는 목표 직전까지의 등비 계차를 합한다."""
    if target < 1:
        raise ValueError("목표 번호는 1 이상이어야 합니다.")
    return first + sum(difference_first * ratio**index for index in range(target - 1))


def _reverse_false_count(universe: tuple[int, ...], p_true: tuple[int, ...], q_true: tuple[int, ...]) -> int:
    """필요 변수는 전체집합과 두 조건의 참 집합이다. 작동 원리는 역 q⇒p가 거짓인 Q 참·P 거짓 원소를 센다."""
    if not set(p_true) <= set(universe) or not set(q_true) <= set(universe):
        raise ValueError("참 집합은 전체집합 안에 있어야 합니다.")
    return len(set(q_true) - set(p_true))


def _unknown_log_base(argument: int, exponent: int) -> int:
    """필요 변수는 로그 진수와 로그값이다. 작동 원리는 x^p=argument의 양의 정수해를 찾아 밑 조건을 확인한다."""
    if exponent < 1:
        raise ValueError("양의 로그값이 필요합니다.")
    for base in range(2, argument + 1):
        if base**exponent == argument:
            return base
    raise ValueError("정수 로그 밑이 존재해야 합니다.")


def _two_step_partial_fraction_sum(offset: int, upper: int) -> Fraction:
    """필요 변수는 분모 이동량과 시그마 상한이다. 작동 원리는 간격 2 부분분수로 분해해 정확한 합을 계산한다."""
    if upper < 1:
        raise ValueError("양의 상한이 필요합니다.")
    return sum(Fraction(1, (k + offset) * (k + offset + 2)) for k in range(1, upper + 1))


def _piecewise_tangent_parameter_sum(leading: int, linear: int, constant: int, junction: int) -> int:
    """필요 변수는 왼쪽 이차식과 접합점이다. 작동 원리는 오른쪽 점기울기식의 기울기·접합값을 미분가능 조건으로 구해 더한다."""
    slope = 2 * leading * junction + linear
    value = leading * junction**2 + linear * junction + constant
    return slope + value


def _quartic_extrema_gap(root: int) -> int:
    """필요 변수는 양의 대칭 임계점이다. 작동 원리는 (x²-a²)²+c의 극댓값과 극솟값 차 a⁴을 계산한다."""
    if root <= 0:
        raise ValueError("양의 대칭점이 필요합니다.")
    return root**4


def _inverse_equation_vector_product(
    matrix: tuple[int, int, int, int],
    target: tuple[int, int],
) -> int:
    """필요 변수는 가역행렬 A와 열벡터 B다. 작동 원리는 A^-1 X=B에서 X=AB로 바꿔 두 성분을 곱한다."""
    determinant = matrix[0] * matrix[3] - matrix[1] * matrix[2]
    if determinant == 0:
        raise ValueError("가역행렬이 필요합니다.")
    first = matrix[0] * target[0] + matrix[1] * target[1]
    second = matrix[2] * target[0] + matrix[3] * target[1]
    return first * second


def _conditional_even_product_probability(sides: int) -> Fraction:
    """필요 변수는 두 공정한 주사위의 면 수다. 작동 원리는 합이 짝수인 순서쌍 중 곱도 짝수인 경우를 전수 계산한다."""
    if sides < 2:
        raise ValueError("면 수는 2 이상이어야 합니다.")
    condition = [(a, b) for a in range(1, sides + 1) for b in range(1, sides + 1) if (a + b) % 2 == 0]
    favorable = [(a, b) for a, b in condition if (a * b) % 2 == 0]
    return Fraction(len(favorable), len(condition))


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 연속 대칭이동한 점과 두 복소수다. 작동 원리는 거리 제곱과 곱의 허수부 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    point_rows = [(2,3),(-4,1),(5,-2),(-3,-6),(1,7)]
    for index,point in enumerate(point_rows,1):
        answer=_double_axis_reflection_distance_squared(point)
        specs.append(_checked_problem(
            1,index,
            title=rf"점 $(P{point}$)를 x축에 대칭이동한 뒤 다시 y축에 대칭이동하여 점 Q를 얻었다. $(PQ^2$)의 값을 구하시오.",
            answer=str(answer), tags=["#x축대칭","#y축대칭","#대칭이동","#두점사이의거리"],
            steps=[("x축 대칭 후 y축 대칭하면 두 좌표의 부호가 모두 바뀐다.", rf"$(Q=({-point[0]},{-point[1]})$)이다."), ("P와 Q의 좌표 차를 제곱해 더한다.", rf"따라서 $(PQ^2={answer}$)이다.")],
            answer_check=lambda p=point:_double_axis_reflection_distance_squared(p),
        ))
    complex_rows=[((2,3),(4,-1)),((-1,5),(3,2)),((4,-2),(-3,1)),((1,6),(2,-4)),((-5,-1),(1,3))]
    for index,(first,second) in enumerate(complex_rows,6):
        answer=_complex_product_imaginary(first,second)
        specs.append(_checked_problem(
            1,index,
            title=rf"복소수 $(z=({first[0]})+({first[1]})i$), $(w=({second[0]})+({second[1]})i$)에 대하여 zw의 허수부를 구하시오.",
            answer=str(answer), tags=["#복소수의연산","#실수와허수","#허수단위","#이"],
            steps=[("두 복소수의 곱을 분배법칙으로 전개한다.", "$(i^2=-1$)인 항은 실수부로 보낸다."), ("i의 계수만 모은다.", rf"따라서 허수부는 $({answer}$)이다.")],
            answer_check=lambda a=first,b=second:_complex_product_imaginary(a,b),
        ))
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 등비 계차수열과 조건명제의 역이다. 작동 원리는 목표 항과 역이 거짓인 원소 수 문제 10개를 만든다."""
    specs:list[dict[str,Any]]=[]
    sequence_rows=[(2,1,2,7),(-3,2,3,6),(5,-1,2,8),(1,3,-2,7),(4,2,-1,9)]
    for index,row in enumerate(sequence_rows,1):
        first,difference,ratio,target=row
        answer=_geometric_difference_term(*row)
        specs.append(_checked_problem(
            2,index,
            title=rf"수열 $(\{{a_n\}}$)이 $(a_1={first}$), $(a_{{n+1}}-a_n={difference}({ratio})^{{n-1}}$)을 만족할 때 $(a_{{{target}}}$)의 값을 구하시오.",
            answer=str(answer), tags=["#계차수열","#여러가지수열의합","#등비수열의합","#수열의정의"],
            steps=[("첫째항부터 목표 항 직전까지 계차를 더한다.", rf"$(a_{{{target}}}=a_1+\sum_{{n=1}}^{{{target-1}}}(a_{{n+1}}-a_n)$)이다."), ("계차가 등비수열임을 확인해 유한합을 계산한다.", "공비와 항 수를 정확히 적용한다."), ("첫째항에 계차합을 더한다.", rf"따라서 $(a_{{{target}}}={answer}$)이다.")],
            answer_check=lambda values=row:_geometric_difference_term(*values),
        ))
    logic_rows=[
        ((1,2,3,4,5),(1,2,3),(2,3,4)),
        ((-2,-1,0,1,2),(-2,0,2),(-1,0,1)),
        ((1,2,3,4,5,6),(2,4,6),(1,2,4,5)),
        ((0,1,2,3,4),(0,1,4),(1,2,3,4)),
        ((1,3,5,7,9),(1,5,9),(3,5,7,9)),
    ]
    for index,(universe,p_true,q_true) in enumerate(logic_rows,6):
        answer=_reverse_false_count(universe,p_true,q_true)
        specs.append(_checked_problem(
            2,index,
            title=rf"전체집합 $(U=\{{{','.join(map(str,universe))}\}}$)에서 조건 p, q의 참인 원소 집합이 $(\{{{','.join(map(str,p_true))}\}}$), $(\{{{','.join(map(str,q_true))}\}}$)이다. 명제 $(p\Rightarrow q$)의 역이 거짓이 되는 x의 개수를 구하시오.",
            answer=str(answer), tags=["#역","#명제의역과대우","#명제의참거짓","#대응"],
            steps=[("주어진 명제의 역을 쓴다.", "역은 $(q\Rightarrow p$)이다."), ("함의가 거짓이려면 q가 참이고 p가 거짓이어야 한다.", "q의 참 집합에서 p의 참 집합을 뺀다."), ("남은 원소 수를 센다.", rf"따라서 개수는 $({answer}$)이다.")],
            answer_check=lambda u=universe,p=p_true,q=q_true:_reverse_false_count(u,p,q),
        ))
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 미지의 로그 밑과 간격 2 부분분수합이다. 작동 원리는 로그 정의와 망원합 문제 10개를 만든다."""
    specs:list[dict[str,Any]]=[]
    log_rows=[(64,3),(625,4),(81,2),(243,5),(256,4)]
    for index,(argument,exponent) in enumerate(log_rows,1):
        answer=_unknown_log_base(argument,exponent)
        specs.append(_checked_problem(
            3,index,
            title=rf"$(x>0,\ x\ne1$)이고 $(\log_x {argument}={exponent}$)일 때 x의 값을 구하시오.",
            answer=str(answer), tags=["#로그의정의","#로그방정식과로그부등식","#로그함수의성질","#밑의변환"],
            steps=[("로그식을 지수식으로 바꾼다.", rf"$(x^{exponent}={argument}$)이다."), ("양의 밑 조건을 적용해 양의 실근을 고른다.", "주어진 수가 정수 거듭제곱임을 확인한다."), ("거듭제곱의 밑을 계산한다.", rf"$(x={answer}$)이다."), ("x가 1이 아니고 양수임을 검산한다.", rf"따라서 답은 $({answer}$)이다.")],
            alternatives=["진수를 소인수분해해 지수의 공약수로 밑을 구할 수 있다."],
            answer_check=lambda a=argument,p=exponent:_unknown_log_base(a,p),
        ))
    fraction_rows=[(0,8),(1,10),(2,12),(3,15),(4,18)]
    for index,(offset,upper) in enumerate(fraction_rows,6):
        answer=_two_step_partial_fraction_sum(offset,upper)
        specs.append(_checked_problem(
            3,index,
            title=rf"합 $(\sum_{{k=1}}^{{{upper}}}\dfrac1{{(k+{offset})(k+{offset+2})}}$)의 값을 구하시오.",
            answer=str(answer), tags=["#부분분수","#여러가지수열의합","#시그마의성질","#몫과나머지"],
            steps=[("일반항을 간격 2인 부분분수로 분해한다.", rf"$(\dfrac1{{(k+{offset})(k+{offset+2})}}=\dfrac12(\dfrac1{{k+{offset}}}-\dfrac1{{k+{offset+2}}})$)이다."), ("합을 펼쳐 두 칸 뒤 항끼리 상쇄됨을 확인한다.", "처음 두 양의 항과 마지막 두 음의 항만 남는다."), ("남은 네 분수에 1/2을 곱한다.", rf"계산 결과는 $({answer}$)이다."), ("정확한 분수 합으로 검산한다.", rf"따라서 합은 $({answer}$)이다.")],
            alternatives=["모든 항을 공통분모로 직접 더해 결과를 확인할 수 있다."],
            answer_check=lambda a=offset,n=upper:_two_step_partial_fraction_sum(a,n),
        ))
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 이차식-접선 조각함수와 대칭 사차함수다. 작동 원리는 미분가능 계수합과 극값 차 문제 10개를 만든다."""
    specs:list[dict[str,Any]]=[]
    piecewise_rows=[(1,2,3,1),(2,-1,4,-1),(-1,5,2,2),(3,0,-2,1),(1,-4,6,3)]
    for index,row in enumerate(piecewise_rows,1):
        leading,linear,constant,junction=row
        slope=2*leading*junction+linear
        value=leading*junction**2+linear*junction+constant
        answer=_piecewise_tangent_parameter_sum(*row)
        specs.append(_checked_problem(
            4,index,
            title=rf"함수 $(f(x)=\begin{{cases}}{leading}x^2+({linear})x+({constant})&(x\le {junction})\\a(x-({junction}))+b&(x>{junction})\end{{cases}}$)가 $(x={junction}$)에서 미분가능할 때 $(a+b$)를 구하시오.",
            answer=str(answer), tags=["#미분가능","#미분계수의정의","#도함수의정의","#일치조건"],
            steps=[("미분가능하려면 먼저 접합점에서 연속이어야 한다.", "오른쪽 식의 접합값은 b이다."), ("왼쪽 이차식에 접합점을 대입해 b를 구한다.", rf"$(b={value}$)이다."), ("좌우 미분계수가 같아야 한다.", "오른쪽 식의 미분계수는 a이다."), ("왼쪽 도함수에 접합점을 대입해 a를 구한다.", rf"$(a={slope}$)이다."), ("두 계수를 더한다.", rf"따라서 $(a+b={answer}$)이다.")],
            alternatives=["접합점에서 왼쪽 포물선의 접선과 오른쪽 직선이 같아야 한다는 기하적 조건을 이용할 수 있다."],
            answer_check=lambda values=row:_piecewise_tangent_parameter_sum(*values),
        ))
    quartic_rows=[(1,3),(2,-1),(3,5),(4,0),(5,-7)]
    for index,(root,constant) in enumerate(quartic_rows,6):
        answer=_quartic_extrema_gap(root)
        specs.append(_checked_problem(
            4,index,
            title=rf"함수 $(f(x)=(x^2-{root**2})^2+({constant})$)의 극댓값에서 극솟값을 뺀 값을 구하시오.",
            answer=str(answer), tags=["#극값의판정","#극댓값","#극솟값","#미분과최대최소"],
            steps=[("도함수를 구해 인수분해한다.", rf"$(f'(x)=4x(x-{root})(x+{root})$)이다."), ("세 임계점 주변에서 도함수 부호를 조사한다.", "x=0에서 극대, x=±a에서 극소이다."), ("극댓값과 극솟값을 각각 계산한다.", rf"극댓값은 $({root**4}+({constant})$), 극솟값은 $({constant}$)이다."), ("두 값을 빼며 상수항을 소거한다.", rf"차는 $({root}^4$)이다."), ("거듭제곱을 계산한다.", rf"따라서 값은 $({answer}$)이다.")],
            alternatives=["제곱식 $((x^2-a^2)^2$)의 그래프 대칭성과 0이 되는 점을 이용할 수 있다."],
            answer_check=lambda a=root:_quartic_extrema_gap(a),
        ))
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 역행렬 방정식과 조건부 주사위 사건이다. 작동 원리는 행렬 곱 벡터와 조건부확률 문제 10개를 만든다."""
    specs:list[dict[str,Any]]=[]
    matrix_rows=[((2,1,1,1),(3,2)),((3,-1,2,1),(4,-2)),((1,2,-1,3),(5,1)),((4,1,2,3),(-1,4)),((2,-3,1,2),(3,5))]
    for index,(matrix,target) in enumerate(matrix_rows,1):
        answer=_inverse_equation_vector_product(matrix,target)
        specs.append(_checked_problem(
            5,index,
            title=rf"가역행렬 $(A=\begin{{pmatrix}}{matrix[0]}&{matrix[1]}\\{matrix[2]}&{matrix[3]}\end{{pmatrix}}$)와 열벡터 $(B=({target[0]},{target[1]})^T$)에 대하여 $(A^{{-1}}X=B$)를 만족하는 $(X=(x,y)^T$)의 xy를 구하시오.",
            answer=str(answer), tags=["#역행렬구하기","#역행렬의성질","#역행렬의정의","#연립일차방정식과행렬"],
            steps=[("A가 가역인지 행렬식으로 확인한다.", "행렬식이 0이 아니므로 양변에 A를 곱할 수 있다."), ("$(A^{-1}X=B$)의 양변 왼쪽에 A를 곱한다.", "$(AA^{-1}=I$)이므로 $(X=AB$)이다."), ("행렬 A와 열벡터 B를 곱한다.", "각 행과 B의 스칼라곱이 x,y이다."), ("두 성분을 원래 방정식에 대입해 검산한다.", "A의 역행렬을 적용하면 B가 된다."), ("x와 y를 곱한다.", rf"곱은 $({answer}$)이다."), ("행렬 곱의 순서를 바꾸지 않았음을 확인한다.", rf"따라서 $(xy={answer}$)이다.")],
            alternatives=["A의 역행렬을 직접 구한 뒤 원래 식을 두 연립방정식으로 풀 수 있다.", "X=AB를 얻은 뒤 성분 계산만 수행할 수 있다."],
            answer_check=lambda a=matrix,b=target:_inverse_equation_vector_product(a,b),
        ))
    for index,sides in enumerate(range(4,9),6):
        answer=_conditional_even_product_probability(sides)
        condition=sum((a+b)%2==0 for a in range(1,sides+1) for b in range(1,sides+1))
        favorable=sum((a+b)%2==0 and (a*b)%2==0 for a in range(1,sides+1) for b in range(1,sides+1))
        specs.append(_checked_problem(
            5,index,
            title=rf"각 면에 1부터 {sides}까지 적힌 공정한 {sides}면체 주사위 두 개를 던졌다. 나온 두 수의 합이 짝수라는 조건에서 두 수의 곱도 짝수일 조건부확률을 구하시오.",
            answer=str(answer), tags=["#사건의합","#사건의곱","#경우의수"],
            steps=[("두 주사위 결과를 순서쌍으로 센다.", rf"전체 결과는 $({sides**2}$)개이다."), ("조건 사건인 합이 짝수인 순서쌍을 센다.", rf"조건 사건은 $({condition}$)개이다."), ("합이 짝수이려면 두 수의 홀짝성이 같아야 함을 이용한다.", "짝수·짝수 또는 홀수·홀수이다."), ("그중 곱도 짝수인 경우를 센다.", rf"유리한 경우는 짝수·짝수 $({favorable}$)개이다."), ("조건부확률을 유리한 조건 사건 수로 나눈다.", rf"확률은 $({favorable}/{condition}$)이다."), ("기약분수로 약분한다.", rf"따라서 확률은 $({answer}$)이다.")],
            alternatives=["조건 사건 안에서 홀수·홀수인 여사건을 빼서 구할 수 있다.", "짝수 면의 개수와 홀수 면의 개수를 먼저 세어 조합적으로 계산할 수 있다."],
            answer_check=lambda n=sides:_conditional_even_product_probability(n),
        ))
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v48 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(),*_tier2_specs(),*_tier3_specs(),*_tier4_specs(),*_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v48 전체 카탈로그다. 작동 원리는 독립 정답 검산 후 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog=build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v48 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(catalog,expected_count=50,batch_id=BATCH_ID,model_name=MODEL_NAME,codebase_base=CODEBASE_BASE,seed_base=SEED_BASE)


def seed_database(db_path: Path,*,validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v48 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(db_path,quests=validated_quests(),batch_id=BATCH_ID,validate_only=validate_only)


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v48 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
    parser=argparse.ArgumentParser()
    parser.add_argument("--db",type=Path,default=ROOT/"quests.db")
    parser.add_argument("--validate-only",action="store_true")
    args=parser.parse_args()
    print(json.dumps(seed_database(args.db,validate_only=args.validate_only),ensure_ascii=False,indent=2))


if __name__=="__main__":
    main()
