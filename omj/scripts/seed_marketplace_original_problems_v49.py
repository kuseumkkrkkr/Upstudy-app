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

BATCH_ID = "marketplace-original-v49"
MODEL_NAME = "aiflow-direct-authoring-v49"
CODEBASE_BASE = 20_261_010_000
SEED_BASE = 202_607_589_000


def _checked_problem(tier: int, index: int, *, answer_check: Callable[[], Any], **kwargs: Any) -> dict[str, Any]:
    """필요 변수는 문제 명세와 독립 계산 함수다. 작동 원리는 저장 답과 별도 계산 결과를 비교하도록 검산 함수를 부착한다."""
    spec = _problem(tier, index, **kwargs)
    spec["answer_check"] = answer_check
    return spec


def _polynomial_sum_difference_value(
    first: tuple[int, int, int],
    second: tuple[int, int, int],
    value: int,
) -> int:
    """필요 변수는 두 이차다항식 계수와 대입값이다. 작동 원리는 (P+Q)(t)-(P-Q)(-t)를 직접 계산한다."""
    def evaluate(coefficients: tuple[int, int, int], x: int) -> int:
        """필요 변수는 이차다항식 계수와 입력값이다. 작동 원리는 호너 방식으로 함수값을 계산한다."""
        return (coefficients[0] * x + coefficients[1]) * x + coefficients[2]
    return evaluate(first, value) + evaluate(second, value) - evaluate(first, -value) + evaluate(second, -value)


def _constrained_subset_count(set_size: int, included_size: int, excluded_size: int) -> int:
    """필요 변수는 전체집합·필수 포함·필수 제외 원소 수다. 작동 원리는 자유 원소마다 포함 여부 두 가지를 곱한다."""
    if included_size + excluded_size > set_size:
        raise ValueError("포함·제외 원소가 서로 겹치지 않아야 합니다.")
    return 2 ** (set_size - included_size - excluded_size)


def _arithmetic_sum_from_terms(
    first_index: int,
    first_value: int,
    second_index: int,
    second_value: int,
    count: int,
) -> Fraction:
    """필요 변수는 서로 다른 두 항과 합의 항 수다. 작동 원리는 공차·첫째항을 연립해 등차수열 합을 계산한다."""
    if first_index == second_index:
        raise ValueError("서로 다른 항 번호가 필요합니다.")
    difference = Fraction(second_value - first_value, second_index - first_index)
    first_term = first_value - (first_index - 1) * difference
    return Fraction(count, 2) * (2 * first_term + (count - 1) * difference)


def _positive_geometric_middle(product: int) -> int:
    """필요 변수는 대칭인 두 양의 항의 곱이다. 작동 원리는 양의 등비중항을 곱의 양의 제곱근으로 구한다."""
    root = math.isqrt(product)
    if root**2 != product:
        raise ValueError("완전제곱인 곱이 필요합니다.")
    return root


def _bounded_log_solution_sum(base: int, shift: int, exponent: int, lower: int, upper: int) -> int:
    """필요 변수는 증가 로그부등식과 정수 범위다. 작동 원리는 진수조건·지수 비교를 모두 만족하는 정수를 합한다."""
    if base <= 1:
        raise ValueError("1보다 큰 로그 밑이 필요합니다.")
    return sum(
        x
        for x in range(lower, upper + 1)
        if x + shift > 0 and x + shift > base**exponent
    )


def _radical_horizontal_intersection(horizontal: int, vertical: int, line_height: int) -> int:
    """필요 변수는 무리함수 이동량과 수평선 높이다. 작동 원리는 sqrt(x-h)+k=m을 제곱해 교점 x좌표를 구한다."""
    if line_height < vertical:
        raise ValueError("수평선이 무리함수 시작점 이상이어야 합니다.")
    return horizontal + (line_height - vertical) ** 2


def _same_degree_infinity_limit(numerator_leading: int, denominator_leading: int) -> Fraction:
    """필요 변수는 같은 차수 분자·분모의 최고차항 계수다. 작동 원리는 x의 최고차항으로 나눠 계수비를 구한다."""
    if denominator_leading == 0:
        raise ValueError("분모 최고차항 계수는 0이 아니어야 합니다.")
    return Fraction(numerator_leading, denominator_leading)


def _one_sided_limit_sum(
    left_linear: int,
    left_constant: int,
    right_linear: int,
    right_constant: int,
    junction: int,
) -> int:
    """필요 변수는 접합점 좌우 일차식이다. 작동 원리는 좌극한과 우극한에 접합점을 각각 대입해 더한다."""
    return left_linear * junction + left_constant + right_linear * junction + right_constant


def _riemann_cubic_limit(scale: int, shift: int) -> Fraction:
    """필요 변수는 리만합 속 일차식 계수다. 작동 원리는 0부터 1까지 세제곱식의 정적분을 계산한다."""
    return (
        Fraction(scale**3, 4)
        + scale**2 * shift
        + Fraction(3 * scale * shift**2, 2)
        + shift**3
    )


def _inductive_product_sum(upper: int) -> int:
    """필요 변수는 합의 자연수 상한이다. 작동 원리는 k(k+1)을 직접 더해 귀납 공식 결과를 독립 검산한다."""
    if upper < 1:
        raise ValueError("양의 상한이 필요합니다.")
    return sum(k * (k + 1) for k in range(1, upper + 1))


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 다항식과 포함·제외 조건 부분집합이다. 작동 원리는 합차 함수값과 제한 부분집합 수 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    polynomial_rows = [
        ((1,2,3),(2,-1,4),2),
        ((-1,4,5),(3,2,-2),1),
        ((2,-3,1),(-2,5,6),3),
        ((4,1,-5),(1,-4,2),-2),
        ((3,-2,7),(-1,6,-3),2),
    ]
    for index,(first,second,value) in enumerate(polynomial_rows,1):
        answer=_polynomial_sum_difference_value(first,second,value)
        specs.append(_checked_problem(
            1,index,
            title=rf"$P(x)={first[0]}x^2+({first[1]})x+({first[2]})$, $Q(x)={second[0]}x^2+({second[1]})x+({second[2]})$일 때 $(P+Q)({value})-(P-Q)({-value})$의 값을 구하시오.",
            answer=str(answer), tags=["#다항식의덧셈","#다항식의뺄셈","#항","#대수"],
            steps=[("P+Q와 P-Q에 필요한 두 입력값을 각각 대입한다.", "같은 차수끼리 더하고 빼는 것과 함수값 계산은 같은 결과를 준다."), ("두 함수값의 차를 계산한다.", rf"따라서 값은 ${answer}$이다.")],
            answer_check=lambda a=first,b=second,t=value:_polynomial_sum_difference_value(a,b,t),
        ))
    subset_rows=[(7,2,1),(8,3,2),(9,1,4),(10,4,1),(11,3,3)]
    for index,(size,included,excluded) in enumerate(subset_rows,6):
        answer=_constrained_subset_count(size,included,excluded)
        specs.append(_checked_problem(
            1,index,
            title=rf"원소가 {size}개인 집합 U에서 서로 겹치지 않는 부분집합 A, B의 원소 수가 각각 {included}, {excluded}이다. $A\subseteq X$이고 $X\cap B=\varnothing$인 부분집합 X의 개수를 구하시오.",
            answer=str(answer), tags=["#부분집합","#교집합","#집합의포함관계","#집합"],
            steps=[("A의 원소는 모두 포함하고 B의 원소는 모두 제외한다.", "나머지 원소만 자유롭게 선택할 수 있다."), ("자유 원소 각각의 포함·제외 두 선택을 곱한다.", rf"따라서 개수는 ${answer}$이다.")],
            answer_check=lambda n=size,a=included,b=excluded:_constrained_subset_count(n,a,b),
        ))
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 등차수열의 두 항과 양의 등비중항이다. 작동 원리는 부분합과 대칭항 중항 문제 10개를 만든다."""
    specs:list[dict[str,Any]]=[]
    arithmetic_rows=[(2,5,6,17,10),(3,-1,8,14,12),(1,4,5,-8,9),(4,10,9,25,15),(2,-3,7,12,11)]
    for index,row in enumerate(arithmetic_rows,1):
        p,u,q,v,count=row
        answer=_arithmetic_sum_from_terms(*row)
        specs.append(_checked_problem(
            2,index,
            title=rf"등차수열 $\{{a_n\}}$에서 $a_{p}={u}$, $a_{q}={v}$일 때 첫 {count}개 항의 합을 구하시오.",
            answer=str(answer), tags=["#등차수열의일반항","#등차중항","#등차수열의합","#공차"],
            steps=[("두 항의 차를 번호 차로 나누어 공차를 구한다.", "$d=(a_q-a_p)/(q-p)$이다."), ("한 항과 공차로 첫째항을 구한다.", "$a_1=a_p-(p-1)d$이다."), ("등차수열의 합 공식에 대입한다.", rf"따라서 합은 ${answer}$이다.")],
            answer_check=lambda values=row:_arithmetic_sum_from_terms(*values),
        ))
    geometric_rows=[(81,2,8),(16,1,7),(100,3,9),(36,4,10),(64,5,11)]
    for index,(product,first_index,second_index) in enumerate(geometric_rows,6):
        middle=(first_index+second_index)//2
        answer=_positive_geometric_middle(product)
        specs.append(_checked_problem(
            2,index,
            title=rf"모든 항이 양수인 등비수열 $\{{a_n\}}$에서 $a_{first_index}a_{second_index}={product}$이다. 두 번호의 평균에 해당하는 $a_{middle}$의 값을 구하시오.",
            answer=str(answer), tags=["#등비중항","#등비수열","#수열의정의","#공비"],
            steps=[("등비수열의 대칭인 두 항 곱은 가운데 항의 제곱과 같다.", rf"$a_{middle}^2={product}$이다."), ("모든 항이 양수이므로 양의 제곱근을 선택한다.", rf"$a_{middle}={answer}$이다."), ("번호 평균이 정수인지 확인한다.", rf"따라서 답은 ${answer}$이다.")],
            answer_check=lambda p=product:_positive_geometric_middle(p),
        ))
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 제한된 로그부등식과 이동된 무리함수다. 작동 원리는 정수해 합과 수평선 교점 문제 10개를 만든다."""
    specs:list[dict[str,Any]]=[]
    log_rows=[(2,3,2,-4,12),(3,5,1,-6,15),(2,1,3,-3,20),(4,7,2,-5,18),(5,2,1,-8,14)]
    for index,row in enumerate(log_rows,1):
        base,shift,exponent,lower,upper=row
        answer=_bounded_log_solution_sum(*row)
        specs.append(_checked_problem(
            3,index,
            title=rf"정수 범위 ${lower}\le x\le {upper}$에서 부등식 $\log_{base}(x+({shift}))>{exponent}$을 만족하는 모든 x의 합을 구하시오.",
            answer=str(answer), tags=["#로그부등식","#로그함수","#로그함수의성질","#진수조건"],
            steps=[("진수조건 $x+shift>0$을 세운다.", "로그가 정의되는 범위를 먼저 제한한다."), ("밑이 1보다 크므로 지수식의 대소관계를 그대로 적용한다.", rf"$x+({shift})>{base**exponent}$이다."), ("주어진 정수 범위와 공통인 해를 나열한다.", "끝점의 엄격한 부등호를 확인한다."), ("정수해를 모두 더한다.", rf"따라서 합은 ${answer}$이다.")],
            alternatives=["로그함수 그래프와 수평선의 위치를 비교해 해 구간을 찾을 수 있다."],
            answer_check=lambda values=row:_bounded_log_solution_sum(*values),
        ))
    radical_rows=[(2,-1,4),(-3,2,5),(5,-2,3),(0,1,6),(-4,-3,2)]
    for index,(horizontal,vertical,height) in enumerate(radical_rows,6):
        answer=_radical_horizontal_intersection(horizontal,vertical,height)
        specs.append(_checked_problem(
            3,index,
            title=rf"무리함수 $y=\sqrt{{x-({horizontal})}}+({vertical})$의 그래프와 수평선 $y={height}$의 교점 x좌표를 구하시오.",
            answer=str(answer), tags=["#무리식과무리함수","#무리함수의그래프","#무리함수의평행이동","#무리식의계산"],
            steps=[("두 함수의 y값을 같게 놓는다.", rf"$\sqrt{{x-({horizontal})}}={height-vertical}$이다."), ("오른쪽이 0 이상임을 확인하고 양변을 제곱한다.", "제곱 후 생길 수 있는 무연근을 원래 식으로 확인한다."), ("x에 관한 일차방정식을 푼다.", rf"교점의 x좌표는 ${answer}$이다."), ("정의역과 원래 근호식에 대입해 검산한다.", rf"따라서 답은 ${answer}$이다.")],
            alternatives=["기본 무리함수 그래프의 높이에 따른 x좌표를 평행이동으로 읽을 수 있다."],
            answer_check=lambda h=horizontal,k=vertical,m=height:_radical_horizontal_intersection(h,k,m),
        ))
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 같은 차수 유리함수와 접합점 좌우 일차식이다. 작동 원리는 무한대 극한과 좌우극한 합 문제 10개를 만든다."""
    specs:list[dict[str,Any]]=[]
    infinity_rows=[(2,3,5,-1,4,7),(3,-2,1,2,5,-3),(-4,1,6,3,-2,5),(5,0,-7,-2,3,4),(7,-3,2,4,1,-6)]
    for index,(a,b,c,d,e,f) in enumerate(infinity_rows,1):
        answer=_same_degree_infinity_limit(a,d)
        specs.append(_checked_problem(
            4,index,
            title=rf"극한 $\lim_{{x\to\infty}}\dfrac{{{a}x^2+({b})x+({c})}}{{{d}x^2+({e})x+({f})}}$의 값을 구하시오.",
            answer=str(answer), tags=["#무한대의극한","#극한의사칙연산","#극한의성질","#극한의정의"],
            steps=[("분자와 분모의 최고차수가 같음을 확인한다.", "둘 다 이차식이다."), ("분자와 분모를 x²으로 나눈다.", "일차항은 1/x, 상수항은 1/x²이 곱해진다."), ("x가 무한대로 갈 때 1/x과 1/x²이 0으로 감을 적용한다.", "최고차항 계수만 남는다."), ("남은 계수비를 계산한다.", rf"극한값은 ${answer}$이다."), ("분모 최고차항 계수가 0이 아님을 확인한다.", rf"따라서 답은 ${answer}$이다.")],
            alternatives=["같은 차수 다항식 비의 무한대 극한 공식을 바로 적용할 수 있다."],
            answer_check=lambda p=a,q=d:_same_degree_infinity_limit(p,q),
        ))
    limit_rows=[(2,3,-1,5,1),(-3,4,2,-1,-2),(1,-5,4,2,3),(5,1,-2,6,0),(-1,7,3,-4,2)]
    for index,row in enumerate(limit_rows,6):
        left,left_constant,right,right_constant,junction=row
        answer=_one_sided_limit_sum(*row)
        specs.append(_checked_problem(
            4,index,
            title=rf"함수 $f(x)=\begin{{cases}}{left}x+({left_constant})&(x<{junction})\\0&(x={junction})\\{right}x+({right_constant})&(x>{junction})\end{{cases}}$에 대하여 $\lim_{{x\to {junction}-}}f(x)+\lim_{{x\to {junction}+}}f(x)$의 값을 구하시오.",
            answer=str(answer), tags=["#우극한","#좌극한","#불연속","#함수의극한"],
            steps=[("좌극한은 왼쪽 일차식에 접합점을 대입해 구한다.", "접합점에서 함수값 0은 좌극한에 영향을 주지 않는다."), ("우극한은 오른쪽 일차식에 접합점을 대입해 구한다.", "역시 접합점 자체 값과 독립이다."), ("두 일차식의 극한값을 각각 계산한다.", "좌우 값이 같을 필요는 없다."), ("두 극한값을 더한다.", rf"합은 ${answer}$이다."), ("문제는 양쪽 극한의 합만 요구함을 확인한다.", rf"따라서 답은 ${answer}$이다.")],
            alternatives=["그래프에서 접합점 왼쪽과 오른쪽이 접근하는 y좌표를 각각 읽을 수 있다."],
            answer_check=lambda values=row:_one_sided_limit_sum(*values),
        ))
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 세제곱 리만합과 연속된 자연수 곱의 합이다. 작동 원리는 정적분 극한과 귀납 공식 문제 10개를 만든다."""
    specs:list[dict[str,Any]]=[]
    riemann_rows=[(1,1),(2,-1),(3,2),(-2,3),(4,-2)]
    for index,(scale,shift) in enumerate(riemann_rows,1):
        answer=_riemann_cubic_limit(scale,shift)
        specs.append(_checked_problem(
            5,index,
            title=rf"극한 $\lim_{{n\to\infty}}\dfrac1n\sum_{{k=1}}^n\left({scale}\dfrac kn+({shift})\right)^3$의 값을 구하시오.",
            answer=str(answer), tags=["#구분구적법","#구간의분할","#정적분의정의","#미적분Ⅰ"],
            steps=[("$\Delta x=1/n$, $x_k=k/n$인 [0,1]의 오른쪽 끝점 리만합으로 본다.", "합 앞의 1/n이 구간 폭이다."), ("대응하는 함수 $f(x)=(ax+b)^3$을 정한다.", "극한을 0부터 1까지 정적분으로 바꾼다."), ("세제곱식을 전개한다.", "$a^3x^3+3a^2bx^2+3ab^2x+b^3$이다."), ("각 항을 0부터 1까지 적분한다.", "x³,x²,x,상수항 적분값을 적용한다."), ("분수들을 통분해 정리한다.", rf"계산 결과는 ${answer}$이다."), ("원래 리만합의 구간과 표본점이 일치함을 확인한다.", rf"따라서 극한값은 ${answer}$이다.")],
            alternatives=["치환 $u=ax+b$로 정적분을 계산할 수 있다.", "자연수 세제곱합까지 전개해 n의 최고차항으로 직접 극한을 구할 수 있다."],
            answer_check=lambda a=scale,b=shift:_riemann_cubic_limit(a,b),
        ))
    induction_rows=[8,10,12,15,20]
    for index,upper in enumerate(induction_rows,6):
        answer=_inductive_product_sum(upper)
        specs.append(_checked_problem(
            5,index,
            title=rf"항등식 $\sum_{{k=1}}^n k(k+1)=\dfrac{{n(n+1)(n+2)}}3$을 수학적 귀납법으로 확인한 뒤 $n={upper}$일 때 합의 값을 구하시오.",
            answer=str(answer), tags=["#수학적귀납법","#귀납법의원리","#귀납법증명","#자연수의거듭제곱의합"],
            steps=[("n=1에서 좌변과 우변이 모두 2인지 확인한다.", "귀납법의 기초 단계가 성립한다."), ("n=m에서 항등식이 성립한다고 가정한다.", "좌변을 주어진 닫힌식으로 바꿀 수 있다."), ("n=m+1의 좌변에 새 항 (m+1)(m+2)를 더한다.", "귀납 가정을 대입한다."), ("공통인수를 묶어 (m+1)(m+2)(m+3)/3으로 정리한다.", "이는 우변에서 n=m+1인 식이다."), ("모든 자연수 n에서 항등식이 성립함을 결론낸다.", rf"이제 $n={upper}$을 대입한다."), ("곱셈과 나눗셈을 계산한다.", rf"따라서 합은 ${answer}$이다.")],
            alternatives=["$k(k+1)=k^2+k$로 나누어 자연수합과 제곱합 공식을 적용할 수 있다.", "각 항을 직접 더해 귀납 공식 결과를 검산할 수 있다."],
            answer_check=lambda n=upper:_inductive_product_sum(n),
        ))
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v49 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(),*_tier2_specs(),*_tier3_specs(),*_tier4_specs(),*_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v49 전체 카탈로그다. 작동 원리는 독립 정답 검산 후 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog=build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v49 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(catalog,expected_count=50,batch_id=BATCH_ID,model_name=MODEL_NAME,codebase_base=CODEBASE_BASE,seed_base=SEED_BASE)


def seed_database(db_path: Path,*,validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v49 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(db_path,quests=validated_quests(),batch_id=BATCH_ID,validate_only=validate_only)


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v49 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
    parser=argparse.ArgumentParser()
    parser.add_argument("--db",type=Path,default=ROOT/"quests.db")
    parser.add_argument("--validate-only",action="store_true")
    args=parser.parse_args()
    print(json.dumps(seed_database(args.db,validate_only=args.validate_only),ensure_ascii=False,indent=2))


if __name__=="__main__":
    main()
