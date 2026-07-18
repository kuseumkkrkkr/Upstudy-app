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

BATCH_ID = "marketplace-original-v46"
MODEL_NAME = "aiflow-direct-authoring-v46"
CODEBASE_BASE = 20_261_007_000
SEED_BASE = 202_607_586_000


def _checked_problem(tier: int, index: int, *, answer_check: Callable[[], Any], **kwargs: Any) -> dict[str, Any]:
    """필요 변수는 문제 명세와 독립 계산 함수다. 작동 원리는 저장 답과 별도 계산 결과를 비교하도록 검산 함수를 부착한다."""
    spec = _problem(tier, index, **kwargs)
    spec["answer_check"] = answer_check
    return spec


def _proper_superset_count(set_size: int, required_size: int) -> int:
    """필요 변수는 전체집합과 반드시 포함할 부분집합 크기다. 작동 원리는 나머지 원소 선택 수에서 전체집합 한 경우를 뺀다."""
    if not 0 <= required_size < set_size:
        raise ValueError("진부분집합이 가능하도록 크기를 정해야 합니다.")
    return 2 ** (set_size - required_size) - 1


def _missing_endpoint_sum(first: tuple[int, int], midpoint: tuple[int, int]) -> int:
    """필요 변수는 한 끝점과 중점 좌표다. 작동 원리는 B=2M-A로 다른 끝점을 복원해 좌표를 더한다."""
    second = (2 * midpoint[0] - first[0], 2 * midpoint[1] - first[1])
    return second[0] + second[1]


def _rational_exponent_value(base_root: int, root_degree: int, root_power: int, integer_power: int) -> int:
    """필요 변수는 완전거듭제곱의 밑과 유리·정수 지수다. 작동 원리는 a=(base_root)^m을 이용해 지수를 정수로 환원한다."""
    if base_root <= 0 or root_degree <= 0:
        raise ValueError("양의 밑과 양의 근 차수가 필요합니다.")
    base = base_root**root_degree
    return base_root**root_power * base**integer_power


def _translated_parabola_axis_minimum(
    linear: int,
    constant: int,
    horizontal: int,
    vertical: int,
) -> Fraction:
    """필요 변수는 원래 포물선 계수와 평행이동량이다. 작동 원리는 새 축과 최솟값을 각각 이동시켜 더한다."""
    original_axis = Fraction(-linear, 2)
    original_minimum = constant - Fraction(linear**2, 4)
    return original_axis + horizontal + original_minimum + vertical


def _translated_log_zero(base: int, horizontal: int, vertical: int) -> Fraction:
    """필요 변수는 로그 밑과 수평·수직 이동량이다. 작동 원리는 log_b(x-h)+k=0을 지수식으로 풀어 영점을 구한다."""
    if base <= 1:
        raise ValueError("1보다 큰 정수 밑이 필요합니다.")
    return horizontal + Fraction(1, base**vertical) if vertical >= 0 else horizontal + base ** (-vertical)


def _exponential_intercept_asymptote_sum(base: int, horizontal: int, vertical: int) -> Fraction:
    """필요 변수는 지수함수 밑과 평행이동량이다. 작동 원리는 y절편과 수평점근선 y좌표를 구해 더한다."""
    if base <= 1:
        raise ValueError("1보다 큰 밑이 필요합니다.")
    intercept = Fraction(base) ** (-horizontal) + vertical
    return intercept + vertical


def _quadratic_remainder_at_one(first_root: int, second_root: int, first_value: int, second_value: int) -> Fraction:
    """필요 변수는 이차 나눗셈식의 두 근과 다항식값이다. 작동 원리는 일차 나머지를 두 점으로 정해 R(1)을 계산한다."""
    if first_root == second_root:
        raise ValueError("서로 다른 두 근이 필요합니다.")
    slope = Fraction(second_value - first_value, second_root - first_root)
    intercept = first_value - slope * first_root
    return slope + intercept


def _difference_square_derivative(
    first_value: int,
    first_derivative: int,
    second_value: int,
    second_derivative: int,
) -> int:
    """필요 변수는 두 함수의 값과 미분계수다. 작동 원리는 f²-g²의 합차 미분으로 도함수값을 계산한다."""
    return 2 * first_value * first_derivative - 2 * second_value * second_derivative


def _matrix_power_trace(matrix: tuple[int, int, int, int], exponent: int) -> int:
    """필요 변수는 2×2 행렬과 음이 아닌 지수다. 작동 원리는 정수 행렬곱을 반복해 거듭제곱의 대각합을 구한다."""
    if exponent < 0:
        raise ValueError("음이 아닌 행렬 지수가 필요합니다.")
    result = (1, 0, 0, 1)

    def multiply(left: tuple[int, int, int, int], right: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
        """필요 변수는 두 2×2 행렬이다. 작동 원리는 행과 열의 스칼라곱으로 네 성분을 계산한다."""
        return (
            left[0] * right[0] + left[1] * right[2],
            left[0] * right[1] + left[1] * right[3],
            left[2] * right[0] + left[3] * right[2],
            left[2] * right[1] + left[3] * right[3],
        )

    for _ in range(exponent):
        result = multiply(result, matrix)
    return result[0] + result[3]


def _position_from_acceleration(
    acceleration_linear: int,
    acceleration_constant: int,
    initial_velocity: int,
    initial_position: int,
    target: int,
) -> Fraction:
    """필요 변수는 일차 가속도·초기 속도·초기 위치·시각이다. 작동 원리는 두 번 적분하고 초기조건을 적용해 위치를 계산한다."""
    return (
        Fraction(acceleration_linear * target**3, 6)
        + Fraction(acceleration_constant * target**2, 2)
        + initial_velocity * target
        + initial_position
    )


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 포함할 원소가 정해진 진부분집합과 선분 중점이다. 작동 원리는 부분집합 수와 누락 끝점 좌표합 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    subset_rows = [(6,2),(7,3),(8,2),(9,4),(10,5)]
    for index, (set_size, required_size) in enumerate(subset_rows, 1):
        required = ",".join(str(i) for i in range(1, required_size+1))
        answer = _proper_superset_count(set_size, required_size)
        specs.append(_checked_problem(
            1, index,
            title=rf"집합 $(U=\{{1,2,\ldots,{set_size}\}}$)의 진부분집합 중 $(\{{{required}\}}$)를 포함하는 집합의 개수를 구하시오.",
            answer=str(answer), tags=["#진부분집합", "#집합의포함관계", "#공통수학1", "#집합"],
            steps=[("반드시 포함할 원소를 먼저 고정한다.", rf"나머지 $({set_size-required_size}$)개 원소는 각각 포함 여부를 선택할 수 있다."), ("전체집합이 되는 한 경우를 제외한다.", rf"따라서 개수는 $({answer}$)이다.")],
            answer_check=lambda n=set_size,r=required_size: _proper_superset_count(n,r),
        ))
    midpoint_rows = [((1,3),(4,5)), ((-2,6),(1,2)), ((5,-1),(-1,4)), ((0,-3),(3,1)), ((-4,-2),(2,-1))]
    for index, (first, midpoint) in enumerate(midpoint_rows, 6):
        answer = _missing_endpoint_sum(first, midpoint)
        specs.append(_checked_problem(
            1, index,
            title=rf"선분 AB의 한 끝점이 $(A{first}$)이고 중점이 $(M{midpoint}$)일 때, 점 B의 x좌표와 y좌표의 합을 구하시오.",
            answer=str(answer), tags=["#중점", "#좌표평면", "#선분의내분점", "#내분점공식"],
            steps=[("중점 좌표가 두 끝점 좌표의 평균임을 이용한다.", "각 좌표에 대해 $(B=2M-A$)로 정리한다."), ("B의 두 좌표를 구해 더한다.", rf"따라서 좌표의 합은 $({answer}$)이다.")],
            answer_check=lambda a=first,m=midpoint: _missing_endpoint_sum(a,m),
        ))
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 유리수 지수식과 평행이동한 포물선이다. 작동 원리는 지수 환원값과 새 축·최솟값 합 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    exponent_rows = [(2,3,2,1),(3,2,1,2),(2,4,3,0),(5,2,3,1),(3,3,2,0)]
    for index, row in enumerate(exponent_rows, 1):
        root,degree,power,integer=row
        base=root**degree
        answer = _rational_exponent_value(*row)
        specs.append(_checked_problem(
            2, index,
            title=rf"양수 $(a={base}$)에 대하여 $(a^{{{power}/{degree}}}\cdot a^{{{integer}}}$)의 값을 구하시오.",
            answer=str(answer), tags=["#유리수지수", "#정수지수", "#실수지수", "#지수의확장"],
            steps=[("a를 완전거듭제곱으로 나타낸다.", rf"$(a={root}^{degree}$)이다."), ("유리수 지수를 적용해 근호를 없앤다.", rf"$(a^{{{power}/{degree}}}={root}^{power}$)이다."), ("정수 지수 항과 곱해 계산한다.", rf"따라서 값은 $({answer}$)이다.")],
            answer_check=lambda values=row: _rational_exponent_value(*values),
        ))
    parabola_rows = [(2,3,1,-2), (-4,5,-2,3), (6,1,3,4), (-2,-3,4,-1), (8,7,-1,2)]
    for index, row in enumerate(parabola_rows, 6):
        linear,constant,horizontal,vertical=row
        answer = _translated_parabola_axis_minimum(*row)
        specs.append(_checked_problem(
            2, index,
            title=rf"포물선 $(y=x^2+({linear})x+({constant})$)을 x방향으로 {horizontal}, y방향으로 {vertical}만큼 평행이동하였다. 이동한 포물선의 축의 x좌표와 최솟값의 합을 구하시오.",
            answer=str(answer), tags=["#이차함수의그래프", "#이차함수의평행이동", "#축", "#x방향이동", "#y방향이동"],
            steps=[("원래 포물선의 축과 최솟값을 완전제곱으로 구한다.", rf"원래 축은 $(x={Fraction(-linear,2)}$)이다."), ("수평이동량은 축에, 수직이동량은 최솟값에 각각 더한다.", "평행이동 방향에 따라 두 기준값을 옮긴다."), ("이동한 축 좌표와 최솟값을 더한다.", rf"따라서 합은 $({answer}$)이다.")],
            answer_check=lambda values=row: _translated_parabola_axis_minimum(*values),
        ))
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 이동된 로그·지수함수다. 작동 원리는 로그 영점과 지수함수 y절편·점근선 합 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    log_rows = [(2,3,-2),(3,-1,-1),(4,2,-2),(5,-3,-1),(2,6,-3)]
    for index, (base,horizontal,vertical) in enumerate(log_rows, 1):
        answer = _translated_log_zero(base,horizontal,vertical)
        specs.append(_checked_problem(
            3, index,
            title=rf"로그함수 $(f(x)=\log_{{{base}}}(x-({horizontal}))+({vertical})$)의 그래프가 x축과 만나는 점의 x좌표를 구하시오.",
            answer=str(answer), tags=["#로그함수의그래프", "#로그함수의평행이동", "#진수조건", "#x방향이동"],
            steps=[("x축과 만나는 점에서는 f(x)=0이다.", rf"$(\log_{{{base}}}(x-({horizontal}))={-vertical}$)이다."), ("로그식을 지수식으로 바꾼다.", rf"$(x-({horizontal})={base}^{{{-vertical}}}$)이다."), ("x를 구하고 진수조건을 확인한다.", rf"따라서 x좌표는 $({answer}$)이다."), ("구한 값에서 진수가 양수임을 검산한다.", rf"답은 $({answer}$)이다.")],
            alternatives=["기본 로그그래프의 x절편을 평행이동하는 관점으로 구할 수 있다."],
            answer_check=lambda b=base,h=horizontal,k=vertical: _translated_log_zero(b,h,k),
        ))
    exponential_rows = [(2,-2,3),(3,-1,-2),(4,-2,1),(5,-1,4),(2,-3,-1)]
    for index, (base,horizontal,vertical) in enumerate(exponential_rows, 6):
        answer = _exponential_intercept_asymptote_sum(base,horizontal,vertical)
        specs.append(_checked_problem(
            3, index,
            title=rf"지수함수 $(f(x)={base}^{{x-({horizontal})}}+({vertical})$)의 y절편과 수평점근선의 y좌표를 더한 값을 구하시오.",
            answer=str(answer), tags=["#지수함수", "#지수함수의평행이동", "#지수함수의그래프", "#y절편"],
            steps=[("y절편을 구하기 위해 x=0을 대입한다.", rf"y절편은 $({base}^{{{-horizontal}}}+({vertical})$)이다."), ("지수함수의 수평점근선을 평행이동량에서 읽는다.", rf"점근선은 $(y={vertical}$)이다."), ("두 y좌표를 더한다.", rf"합은 $({answer}$)이다."), ("그래프의 수직이동과 점근선이 일치함을 확인한다.", rf"따라서 답은 $({answer}$)이다.")],
            alternatives=["기본 그래프 $(y=b^x$)를 수평·수직 이동해 두 값을 읽을 수 있다."],
            answer_check=lambda b=base,h=horizontal,k=vertical: _exponential_intercept_asymptote_sum(b,h,k),
        ))
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 이차식 나눗셈의 나머지와 두 함수의 값·미분계수다. 작동 원리는 R(1)과 합차 제곱 미분 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    remainder_rows = [(-2,3,5,-1), (0,4,2,10), (-3,1,-4,8), (2,5,7,1), (-1,6,3,17)]
    for index, row in enumerate(remainder_rows, 1):
        first,second,u,v=row
        answer = _quadratic_remainder_at_one(*row)
        specs.append(_checked_problem(
            4, index,
            title=rf"다항식 P(x)가 $(P({first})={u}$), $(P({second})={v}$)를 만족한다. P(x)를 $((x-({first}))(x-({second}))$)로 나눈 나머지를 R(x)라 할 때 $(R(1)$)을 구하시오.",
            answer=str(answer), tags=["#인수정리증명", "#인수정리활용", "#나머지정리활용", "#항등식의성질"],
            steps=[("나머지는 차수가 2보다 낮으므로 $(R(x)=mx+n$)으로 놓는다.", "나눗셈식의 두 근에서는 P와 R의 값이 같다."), ("두 근을 대입해 m,n의 연립방정식을 만든다.", rf"$(R({first})={u},\ R({second})={v}$)이다."), ("두 점을 지나는 일차식 R을 구한다.", "기울기와 절편을 정확한 분수로 계산한다."), ("R에 x=1을 대입한다.", rf"$(R(1)={answer}$)이다."), ("나눗셈 항등식에서 같은 결과가 나오는지 확인한다.", rf"따라서 답은 $({answer}$)이다.")],
            alternatives=["두 점 사이 선형보간 공식으로 R(1)을 직접 계산할 수 있다."],
            answer_check=lambda values=row: _quadratic_remainder_at_one(*values),
        ))
    derivative_rows = [(2,3,1,-2), (-1,4,3,2), (5,-1,-2,3), (3,2,4,-1), (-4,-2,1,5)]
    for index, row in enumerate(derivative_rows, 6):
        f,fp,g,gp=row
        answer = _difference_square_derivative(*row)
        specs.append(_checked_problem(
            4, index,
            title=rf"미분가능한 함수 f, g가 $(f(a)={f}$), $(f'(a)={fp}$), $(g(a)={g}$), $(g'(a)={gp}$)를 만족한다. $(H(x)=f(x)^2-g(x)^2$)일 때 $(H'(a)$)를 구하시오.",
            answer=str(answer), tags=["#합차의미분", "#거듭제곱의미분", "#도함수공식", "#미분계수"],
            steps=[("H를 두 제곱 함수의 차로 본다.", "합차 미분법으로 각 항을 따로 미분한다."), ("연쇄법칙을 적용한다.", "$(H'=2ff'-2gg'$)이다."), ("x=a에서 주어진 네 값을 대입한다.", rf"$(H'(a)=2({f})({fp})-2({g})({gp})$)이다."), ("곱셈과 뺄셈을 계산한다.", rf"값은 $({answer}$)이다."), ("합차 인수분해 뒤 곱의 미분을 적용해도 같음을 확인한다.", rf"따라서 답은 $({answer}$)이다.")],
            alternatives=["$(H=(f-g)(f+g)$)로 인수분해한 뒤 곱의 미분법을 적용할 수 있다."],
            answer_check=lambda values=row: _difference_square_derivative(*values),
        ))
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 2×2 행렬 거듭제곱과 일차 가속도 운동이다. 작동 원리는 대각합과 두 번 적분한 위치 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    matrix_rows = [((1,1,0,1),5), ((2,0,1,1),4), ((1,2,1,1),3), ((0,1,-1,2),4), ((3,1,0,2),3)]
    for index, (matrix,exponent) in enumerate(matrix_rows, 1):
        answer = _matrix_power_trace(matrix,exponent)
        specs.append(_checked_problem(
            5, index,
            title=rf"행렬 $(A=\begin{{pmatrix}}{matrix[0]}&{matrix[1]}\\{matrix[2]}&{matrix[3]}\end{{pmatrix}}$)에 대하여 $(A^{exponent}$)의 대각성분의 합을 구하시오.",
            answer=str(answer), tags=["#행렬의정의", "#행렬의곱셈", "#성분", "#스칼라곱"],
            steps=[("A의 크기가 2×2이므로 자기 자신과 곱할 수 있음을 확인한다.", "행렬 거듭제곱은 반복된 행렬곱이다."), ("A²을 행과 열의 스칼라곱으로 계산한다.", "네 성분을 정확히 구한다."), ("필요한 지수까지 이전 결과에 A를 곱한다.", rf"$(A^{exponent}$)을 얻는다."), ("곱셈 순서가 같은 행렬 A의 반복이므로 결합법칙을 적용한다.", "중간 행렬의 크기는 계속 2×2이다."), ("최종 행렬의 두 대각성분을 찾는다.", "왼쪽 위와 오른쪽 아래 성분이다."), ("두 성분을 더한다.", rf"따라서 대각합은 $({answer}$)이다.")],
            alternatives=["빠른 거듭제곱으로 행렬곱 횟수를 줄일 수 있다.", "특성다항식 관계를 이용해 높은 거듭제곱을 낮출 수 있다."],
            answer_check=lambda a=matrix,n=exponent: _matrix_power_trace(a,n),
        ))
    motion_rows = [(2,1,3,4,5), (3,-2,1,-1,4), (-1,4,2,5,6), (4,0,-3,2,3), (1,-3,5,-2,7)]
    for index, row in enumerate(motion_rows, 6):
        a,b,v0,s0,target=row
        answer = _position_from_acceleration(*row)
        specs.append(_checked_problem(
            5, index,
            title=rf"수직선 위 점의 가속도가 $(a(t)={a}t+({b})$)이고 $(v(0)={v0}$), $(s(0)={s0}$)이다. $(t={target}$)에서 위치 $(s(t)$)를 구하시오.",
            answer=str(answer), tags=["#가속도", "#위치함수", "#속도와가속도", "#부정적분공식"],
            steps=[("가속도를 적분해 속도의 일반식을 구한다.", rf"$(v(t)={a}t^2/2+({b})t+C_1$)이다."), ("초기 속도 조건으로 첫 적분상수를 정한다.", rf"$(C_1={v0}$)이다."), ("속도를 다시 적분해 위치함수를 구한다.", rf"$(s(t)={a}t^3/6+({b})t^2/2+({v0})t+C_2$)이다."), ("초기 위치 조건으로 둘째 적분상수를 정한다.", rf"$(C_2={s0}$)이다."), ("목표 시각을 위치함수에 대입한다.", rf"$(t={target}$)를 대입한다."), ("정확한 분수로 계산한다.", rf"따라서 위치는 $({answer}$)이다.")],
            alternatives=["초기 위치에 속도의 정적분을 더해 목표 위치를 구할 수 있다.", "가속도 그래프의 넓이로 속도 변화를 먼저 구할 수 있다."],
            answer_check=lambda values=row: _position_from_acceleration(*values),
        ))
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v46 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v46 전체 카탈로그다. 작동 원리는 독립 정답 검산 후 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog = build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v46 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(catalog, expected_count=50, batch_id=BATCH_ID, model_name=MODEL_NAME, codebase_base=CODEBASE_BASE, seed_base=SEED_BASE)


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v46 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(db_path, quests=validated_quests(), batch_id=BATCH_ID, validate_only=validate_only)


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v46 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
