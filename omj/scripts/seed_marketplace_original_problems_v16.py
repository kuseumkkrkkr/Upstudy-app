from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.marketplace_problem_batch import seed_problem_batch, validate_problem_batch
from scripts.seed_initial_math_problems import _problem

BATCH_ID = "marketplace-original-v16"
MODEL_NAME = "aiflow-direct-authoring-v16"
CODEBASE_BASE = 20_260_781_000
SEED_BASE = 202_607_360_000


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 행렬의 대각 성분·스칼라와 두 점의 좌표다. 작동 원리는 두 단계 계산형 난이도 1 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    matrix_rows = [
        (2, 1, -3, 4, 3),
        (-1, 5, 2, 6, -2),
        (4, -2, 7, -1, 5),
        (3, 8, -4, 2, -3),
        (-5, 1, 6, -2, 4),
    ]
    for index, (top_left, top_right, bottom_left, bottom_right, scalar) in enumerate(matrix_rows, 1):
        answer = scalar * (top_left + bottom_right)
        specs.append(
            _problem(
                1,
                index,
                title=rf"행렬 $A=\begin{{pmatrix}}{top_left}&{top_right}\\{bottom_left}&{bottom_right}\end{{pmatrix}}$에 대하여 행렬 ${scalar}A$의 두 대각 성분의 합을 구하시오.",
                answer=str(answer),
                tags=["#스칼라곱"],
                steps=[
                    ("스칼라를 두 대각 성분에 각각 곱한다.", rf"${scalar}A$의 대각 성분은 ${scalar * top_left}$와 ${scalar * bottom_right}$이다."),
                    ("두 대각 성분을 더한다.", rf"따라서 합은 ${scalar * top_left}+({scalar * bottom_right})={answer}$이다."),
                ],
            )
        )
    midpoint_rows = [
        (-6, 2, 4, 8),
        (3, -5, 9, 7),
        (-8, -4, 2, 6),
        (5, 1, -3, 9),
        (-7, 3, 11, -5),
    ]
    for index, (x1, y1, x2, y2) in enumerate(midpoint_rows, 6):
        midpoint_x = (x1 + x2) // 2
        midpoint_y = (y1 + y2) // 2
        answer = midpoint_x + midpoint_y
        specs.append(
            _problem(
                1,
                index,
                title=rf"두 점 $A({x1},{y1})$, $B({x2},{y2})$의 중점을 $(p,q)$라 할 때, $p+q$를 구하시오.",
                answer=str(answer),
                tags=["#중점"],
                steps=[
                    ("중점 공식으로 두 좌표를 계산한다.", rf"$(p,q)=\left(\dfrac{{{x1}+({x2})}}2,\dfrac{{{y1}+({y2})}}2\right)=({midpoint_x},{midpoint_y})$이다."),
                    ("중점의 두 좌표를 더한다.", rf"따라서 $p+q={midpoint_x}+({midpoint_y})={answer}$이다."),
                ],
            )
        )
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 서로 수직인 직선의 기울기와 등비수열의 양의 중항이다. 작동 원리는 세 단계 개념 적용형 난이도 2 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    perpendicular_rows = [(2, 3, -1), (3, -2, 4), (-2, 5, 1), (-4, -3, 6), (5, 2, -7)]
    for index, (denominator, first_intercept, second_intercept) in enumerate(perpendicular_rows, 1):
        answer = -denominator
        specs.append(
            _problem(
                2,
                index,
                title=rf"두 직선 $y=\dfrac{{1}}{{{denominator}}}x+({first_intercept})$와 $y=ax+({second_intercept})$가 서로 수직일 때, 상수 $a$를 구하시오.",
                answer=str(answer),
                tags=["#기울기", "#수직조건"],
                steps=[
                    ("두 직선의 기울기를 각각 확인한다.", rf"두 기울기는 $\dfrac{{1}}{{{denominator}}}$와 $a$이다."),
                    ("수직인 두 직선의 기울기 곱을 적용한다.", rf"$\dfrac{{1}}{{{denominator}}}\cdot a=-1$이다."),
                    ("방정식을 풀어 두 번째 기울기를 구한다.", rf"따라서 $a={answer}$이다."),
                ],
            )
        )
    geometric_rows = [(2, 18), (3, 27), (5, 45), (8, 50), (12, 75)]
    for index, (first, third) in enumerate(geometric_rows, 6):
        square = first * third
        answer = int(square**0.5)
        specs.append(
            _problem(
                2,
                index,
                title=rf"모든 항이 양수인 등비수열에서 첫째항이 ${first}$이고 셋째항이 ${third}$일 때, 둘째항을 구하시오.",
                answer=str(answer),
                tags=["#등비수열", "#등비중항"],
                steps=[
                    ("등비중항의 제곱 관계를 이용한다.", rf"둘째항을 $a_2$라 하면 $a_2^2={first}\cdot {third}$이다."),
                    ("첫째항과 셋째항의 곱을 계산한다.", rf"$a_2^2={square}={answer}^2$이다."),
                    ("모든 항이 양수라는 조건으로 양의 값을 택한다.", rf"따라서 $a_2={answer}$이다."),
                ],
            )
        )
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 집합의 원소 수와 일차함수의 계수다. 작동 원리는 네 단계와 한 대안 풀이를 갖는 난이도 3 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    set_rows = [(18, 13, 25), (22, 17, 31), (15, 20, 28), (27, 16, 35), (24, 19, 34)]
    for index, (count_a, count_b, count_union) in enumerate(set_rows, 1):
        intersection = count_a + count_b - count_union
        answer = count_a - intersection
        specs.append(
            _problem(
                3,
                index,
                title=rf"유한집합 $A,B$에 대하여 $n(A)={count_a}$, $n(B)={count_b}$, $n(A\cup B)={count_union}$이다. $n(A-B)$를 구하시오.",
                answer=str(answer),
                tags=["#집합의연산", "#합집합", "#교집합"],
                steps=[
                    ("두 집합의 합집합 원소 수 공식을 적는다.", r"$n(A\cup B)=n(A)+n(B)-n(A\cap B)$이다."),
                    ("공식에 주어진 원소 수를 대입한다.", rf"${count_union}={count_a}+{count_b}-n(A\cap B)$이다."),
                    ("교집합의 원소 수를 계산한다.", rf"$n(A\cap B)={intersection}$이다."),
                    ("집합 A에서 교집합을 제외한다.", rf"$n(A-B)={count_a}-{intersection}={answer}$이다."),
                ],
                alternatives=["벤다이어그램의 교집합부터 채운 뒤 A에만 속하는 영역의 원소 수를 읽을 수 있다."],
            )
        )
    inverse_rows = [(3, -4, 20), (-2, 5, -9), (4, 7, 35), (-5, -3, 22), (6, -8, 40)]
    for index, (coefficient, constant, target) in enumerate(inverse_rows, 6):
        answer = (target - constant) // coefficient
        specs.append(
            _problem(
                3,
                index,
                title=rf"일차함수 $f(x)=({coefficient})x+({constant})$의 역함수에 대하여 $f^{{-1}}({target})$의 값을 구하시오.",
                answer=str(answer),
                tags=["#역함수", "#역함수구하기", "#일대일대응"],
                steps=[
                    ("원래 함수의 식을 y에 관한 식으로 둔다.", rf"$y=({coefficient})x+({constant})$이다."),
                    ("x에 관하여 풀어 역함수 식을 만든다.", rf"$x=\dfrac{{y-({constant})}}{{{coefficient}}}$이므로 $f^{{-1}}(y)=\dfrac{{y-({constant})}}{{{coefficient}}}$이다."),
                    ("역함수의 입력에 주어진 값을 대입한다.", rf"$f^{{-1}}({target})=\dfrac{{{target}-({constant})}}{{{coefficient}}}$이다."),
                    ("나눗셈을 계산하고 원래 함수로 확인한다.", rf"값은 ${answer}$이고 $f({answer})={target}$이므로 맞다."),
                ],
                alternatives=[rf"$f^{{-1}}({target})=x$는 $f(x)={target}$와 같으므로 일차방정식을 직접 풀 수 있다."],
            )
        )
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 이차함수 접선의 외부점과 적분함수의 두 조건이다. 작동 원리는 다섯 단계와 한 대안 풀이를 갖는 난이도 4 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    tangent_rows = [(1, 3, 2, 4), (-2, 2, -1, -3), (3, -2, 4, 2), (-1, 4, 3, 5), (2, -3, -2, -4)]
    for index, (point, external_x, constant, answer) in enumerate(tangent_rows, 1):
        external_y = answer * external_x + 2 * point * external_x - point**2 + constant
        specs.append(
            _problem(
                4,
                index,
                title=rf"이차함수 $f(x)=x^2+ax+({constant})$의 그래프 위에서 $x={point}$인 점에서 그은 접선이 점 $P({external_x},{external_y})$를 지난다. 상수 $a$를 구하시오.",
                answer=str(answer),
                tags=["#도함수", "#접선의기울기", "#접선방정식구하기", "#미정계수법"],
                steps=[
                    ("이차함수를 미분해 도함수를 구한다.", r"$f'(x)=2x+a$이다."),
                    ("접점에서 접선의 기울기를 나타낸다.", rf"$x={point}$에서 기울기는 $f'({point})={2 * point}+a$이다."),
                    ("접점의 세로좌표를 계산한다.", rf"$f({point})={point**2}+({point})a+({constant})$이다."),
                    ("접선이 외부점을 지난다는 조건을 세운다.", rf"${external_y}-f({point})=({2 * point}+a)({external_x}-({point}))$이다."),
                    ("일차방정식을 풀어 계수를 구한다.", rf"식을 정리하면 $a={answer}$이다."),
                ],
                alternatives=["접선식을 $y=f(p)+f'(p)(x-p)$로 먼저 완성한 뒤 외부점 좌표를 한 번에 대입할 수 있다."],
            )
        )
    integral_rows = [(2, 3, -1), (4, -2, 5), (6, 1, 2), (2, -4, -3), (8, 2, -5)]
    for index, (upper, coefficient, constant) in enumerate(integral_rows, 6):
        function_value = coefficient * upper**2 // 2 + constant * upper
        derivative_value = coefficient * upper + constant
        answer = coefficient - constant
        specs.append(
            _problem(
                4,
                index,
                title=rf"함수 $F(x)=\int_0^x(at+b)\,dt$가 $F({upper})={function_value}$, $F'({upper})={derivative_value}$를 만족할 때, $a-b$를 구하시오.",
                answer=str(answer),
                tags=["#정적분", "#미적분의기본정리", "#도함수", "#미정계수법"],
                steps=[
                    ("미적분의 기본정리로 도함수를 구한다.", r"$F'(x)=ax+b$이다."),
                    ("도함숫값 조건을 일차방정식으로 나타낸다.", rf"${upper}a+b={derivative_value}$이다."),
                    ("적분을 계산해 F의 식을 구한다.", r"$F(x)=\dfrac{a}{2}x^2+bx$이다."),
                    ("함숫값 조건을 대입해 연립방정식을 푼다.", rf"$\dfrac{{{upper**2}}}2a+{upper}b={function_value}$와 앞 식에서 $a={coefficient}$, $b={constant}$이다."),
                    ("두 계수를 요구한 순서로 계산한다.", rf"따라서 $a-b={coefficient}-({constant})={answer}$이다."),
                ],
                alternatives=["도함숫값 식에서 b를 a에 관한 식으로 나타내어 적분값 식에 대입하면 미지수를 하나씩 제거할 수 있다."],
            )
        )
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 포물선과 한 점의 높이 차·삼차함수의 극값 상수다. 작동 원리는 여섯 단계와 두 대안 풀이를 갖는 난이도 5 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    parabola_rows = [(5, 1), (10, 1), (13, -3), (29, 4), (37, 1)]
    for index, (vertical_shift, point_y) in enumerate(parabola_rows, 1):
        difference = vertical_shift - point_y
        answer = 8 * difference
        specs.append(
            _problem(
                5,
                index,
                title=rf"점 $P(0,{point_y})$에서 포물선 $y=x^2+({vertical_shift})$에 그은 서로 다른 두 접선의 기울기를 $m_1,m_2$라 할 때, $m_1^2+m_2^2$을 구하시오.",
                answer=str(answer),
                tags=["#이차함수의그래프", "#접선의방정식", "#이차방정식의판별식", "#기울기", "#이차함수와이차방정식"],
                steps=[
                    ("점 P를 지나는 기울기 m인 직선의 식을 세운다.", rf"직선은 $y=mx+({point_y})$이다."),
                    ("직선과 포물선의 교점 방정식을 만든다.", rf"$x^2-mx+({difference})=0$이다."),
                    ("접할 조건으로 이차방정식의 판별식을 0으로 둔다.", rf"$m^2-4({difference})=0$이다."),
                    ("두 접선 기울기의 제곱을 각각 구한다.", rf"$m_1^2=m_2^2={4 * difference}$이다."),
                    ("두 기울기 제곱의 합을 나타낸다.", rf"$m_1^2+m_2^2={4 * difference}+{4 * difference}$이다."),
                    ("두 값을 더해 최종 결과를 계산한다.", rf"따라서 $m_1^2+m_2^2={answer}$이다."),
                ],
                alternatives=[
                    "교점 방정식을 완전제곱식으로 만들어 중근이 되는 기울기 조건을 찾을 수 있다.",
                    "포물선과 점이 y축에 대하여 대칭이므로 두 접선 기울기가 서로 반대임을 함께 이용할 수 있다.",
                ],
            )
        )
    extrema_rows = [(1, 5), (2, 9), (3, 20), (4, 35), (5, 60)]
    for index, (scale, constant) in enumerate(extrema_rows, 6):
        product = constant**2 - 4 * scale**6
        specs.append(
            _problem(
                5,
                index,
                title=rf"삼차함수 $f(x)=x^3-{3 * scale**2}x+c$의 극댓값과 극솟값의 곱이 ${product}$이다. $c>0$일 때, 상수 $c$를 구하시오.",
                answer=str(constant),
                tags=["#도함수", "#함수의극대와극소", "#도함수의부호", "#극댓값", "#극솟값"],
                steps=[
                    ("삼차함수를 미분해 도함수를 인수분해한다.", rf"$f'(x)=3x^2-{3 * scale**2}=3(x-{scale})(x+{scale})$이다."),
                    ("도함수가 0인 두 임계점을 구한다.", rf"임계점은 $x=-{scale},{scale}$이다."),
                    ("도함수의 부호 변화로 극대점과 극소점을 판정한다.", rf"$x=-{scale}$에서 극대이고 $x={scale}$에서 극소이다."),
                    ("두 극값을 상수 c로 나타낸다.", rf"극댓값은 $c+{2 * scale**3}$, 극솟값은 $c-{2 * scale**3}$이다."),
                    ("극값의 곱 조건으로 c의 방정식을 세운다.", rf"$(c+{2 * scale**3})(c-{2 * scale**3})={product}$이므로 $c^2={constant**2}$이다."),
                    ("상수의 부호 조건으로 양의 해를 선택한다.", rf"$c>0$이므로 $c={constant}$이다."),
                ],
                alternatives=[
                    "도함수 그래프의 부호를 수직선에 표시해 두 극점의 종류를 판정할 수 있다.",
                    "두 극값은 c를 중심으로 대칭이므로 곱을 차의 제곱 공식으로 바로 정리할 수 있다.",
                ],
            )
        )
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v16 직접 출제 명세를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v16 전체 카탈로그다. 작동 원리는 50문항을 생산 형식으로 조립하고 전수 검사한다."""
    return validate_problem_batch(build_catalog(), expected_count=50, batch_id=BATCH_ID, model_name=MODEL_NAME, codebase_base=CODEBASE_BASE, seed_base=SEED_BASE)


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v16 전체 생산분을 멱등 저장하고 재조회한다."""
    return seed_problem_batch(db_path, quests=validated_quests(), batch_id=BATCH_ID, validate_only=validate_only)


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 v16 전체 생산 결과를 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
