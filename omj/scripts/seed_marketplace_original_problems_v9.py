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

BATCH_ID = "marketplace-original-v9"
MODEL_NAME = "aiflow-direct-authoring-v9"
CODEBASE_BASE = 20_260_725_000
SEED_BASE = 202_607_250_000


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 일차다항식의 계수·대입값과 팩토리얼 지수다. 작동 원리는 새 수치의 난이도 1 직접 출제 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    rows = [(3, 7, 4), (-2, 9, -3), (5, -6, 2), (-4, -1, 5), (7, 3, -2)]
    for index, (coefficient, constant, value) in enumerate(rows, 1):
        answer = coefficient * value + constant
        specs.append(
            _problem(
                1,
                index,
                title=rf"일차다항식 $P(x)={coefficient}x+({constant})$에 대하여 $P({value})$의 값을 구하시오.",
                answer=str(answer),
                tags=["#다항식의연산"],
                steps=[
                    ("주어진 값을 다항식에 대입한다.", rf"$P({value})={coefficient}({value})+({constant})$이다."),
                    ("곱셈과 덧셈을 계산한다.", rf"따라서 $P({value})={answer}$이다."),
                ],
            )
        )
    for index, n in enumerate(range(9, 14), 6):
        answer = n * (n - 1) * (n - 2)
        specs.append(
            _problem(
                1,
                index,
                title=rf"$\dfrac{{{n}!}}{{({n}-3)!}}$의 값을 구하시오.",
                answer=str(answer),
                tags=["#팩토리얼"],
                steps=[
                    ("분자의 팩토리얼을 분모가 나타나도록 전개한다.", rf"${n}!={n}({n - 1})({n - 2})({n}-3)!$이다."),
                    ("공통 팩토리얼을 약분하고 계산한다.", rf"값은 ${n}({n - 1})({n - 2})={answer}$이다."),
                ],
            )
        )
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 이차방정식의 근의 합·곱과 로그의 밑·진수 이동량이다. 작동 원리는 세 단계 개념 적용형 난이도 2 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    root_rows = [(7, 10), (8, 12), (9, 14), (10, 21), (11, 24)]
    for index, (root_sum, root_product) in enumerate(root_rows, 1):
        answer = root_sum * root_sum - 2 * root_product
        specs.append(
            _problem(
                2,
                index,
                title=rf"이차방정식 $x^2-{root_sum}x+{root_product}=0$의 두 근을 $\alpha,\beta$라 할 때, $\alpha^2+\beta^2$의 값을 구하시오.",
                answer=str(answer),
                tags=["#근과계수의관계", "#이차방정식"],
                steps=[
                    ("근과 계수의 관계를 적용한다.", rf"$\alpha+\beta={root_sum}$, $\alpha\beta={root_product}$이다."),
                    ("두 근의 제곱합을 합과 곱으로 바꾼다.", r"$\alpha^2+\beta^2=(\alpha+\beta)^2-2\alpha\beta$이다."),
                    ("알려진 값을 대입해 계산한다.", rf"$\alpha^2+\beta^2={root_sum}^2-2\cdot{root_product}={answer}$이다."),
                ],
            )
        )
    log_rows = [(2, 3, 4), (3, 2, 3), (5, 4, 2), (2, 7, 5), (4, 1, 3)]
    for index, (base, shift, exponent) in enumerate(log_rows, 6):
        answer = shift + base**exponent
        specs.append(
            _problem(
                2,
                index,
                title=rf"로그방정식 $\log_{base}(x-{shift})={exponent}$을 만족하는 실수 $x$를 구하시오.",
                answer=str(answer),
                tags=["#로그방정식", "#진수조건"],
                steps=[
                    ("로그의 진수 조건을 확인한다.", rf"$x-{shift}>0$이므로 $x>{shift}$이어야 한다."),
                    ("로그의 정의를 이용해 지수식으로 바꾼다.", rf"$x-{shift}={base}^{exponent}={base**exponent}$이다."),
                    ("일차방정식을 풀고 조건을 확인한다.", rf"$x={answer}$이고 이 값은 $x>{shift}$를 만족한다."),
                ],
            )
        )
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 삼차다항식의 세 근과 일차분수함수의 계수다. 작동 원리는 네 단계와 한 대안 풀이를 갖는 난이도 3 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    root_rows = [(1, 2, 4), (1, 3, 5), (2, 3, 5), (1, 4, 6), (2, 4, 7)]
    for index, (r1, r2, r3) in enumerate(root_rows, 1):
        coefficient_a = -(r1 + r2 + r3)
        coefficient_b = r1 * r2 + r2 * r3 + r3 * r1
        constant = -(r1 * r2 * r3)
        answer = coefficient_a + coefficient_b
        specs.append(
            _problem(
                3,
                index,
                title=rf"최고차항의 계수가 $1$인 삼차다항식 $P(x)=x^3+ax^2+bx+({constant})$의 세 영점이 ${r1},{r2},{r3}$일 때, $a+b$를 구하시오.",
                answer=str(answer),
                tags=["#인수정리", "#근과계수의관계", "#고차식인수분해"],
                steps=[
                    ("세 영점으로 다항식의 인수 형태를 만든다.", rf"$P(x)=(x-{r1})(x-{r2})(x-{r3})$이다."),
                    ("세 근의 합으로 이차항의 계수를 구한다.", rf"$a=-({r1}+{r2}+{r3})={coefficient_a}$이다."),
                    ("두 근씩 곱한 합으로 일차항의 계수를 구한다.", rf"$b={r1}\cdot{r2}+{r2}\cdot{r3}+{r3}\cdot{r1}={coefficient_b}$이다."),
                    ("두 계수를 더한다.", rf"따라서 $a+b={coefficient_a}+{coefficient_b}={answer}$이다."),
                ],
                alternatives=[rf"세 일차인수의 곱을 직접 전개하여 $x^2$항과 $x$항의 계수를 비교해도 같은 값을 얻는다."],
            )
        )
    rational_rows = [(2, 5, 3), (-3, 4, 2), (4, -1, -2), (5, 7, 1), (-2, 9, -3)]
    for index, (slope, constant, shift) in enumerate(rational_rows, 6):
        remainder = constant + slope * shift
        answer = shift + slope
        specs.append(
            _problem(
                3,
                index,
                title=rf"유리함수 $f(x)=\dfrac{{{slope}x+({constant})}}{{x-({shift})}}$의 두 점근선의 교점을 $(p,q)$라 할 때, $p+q$를 구하시오.",
                answer=str(answer),
                tags=["#유리함수의그래프", "#점근선", "#유리함수의평행이동"],
                steps=[
                    ("분자를 분모의 배수와 나머지로 나눈다.", rf"${slope}x+({constant})={slope}(x-({shift}))+({remainder})$이다."),
                    ("함수식을 평행이동 표준형으로 고친다.", rf"$f(x)={slope}+\dfrac{{{remainder}}}{{x-({shift})}}$이다."),
                    ("수직 점근선과 수평 점근선을 읽는다.", rf"두 점근선은 $x={shift}$, $y={slope}$이다."),
                    ("점근선 교점의 좌표를 더한다.", rf"$(p,q)=({shift},{slope})$이므로 $p+q={answer}$이다."),
                ],
                alternatives=["분모가 0이 되는 값과 분자·분모의 최고차항 계수비를 각각 이용해 두 점근선을 바로 구할 수 있다."],
            )
        )
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 등비수열의 지수와 원·직선의 수치다. 작동 원리는 다섯 단계와 한 대안 풀이를 갖는 난이도 4 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    sequence_rows = [(2, 1, 7), (3, 2, 8), (5, 1, 4), (2, 3, 9), (7, 2, 5)]
    for index, (base, first_exponent, fourth_exponent) in enumerate(sequence_rows, 1):
        ratio_exponent = (fourth_exponent - first_exponent) // 3
        answer = 2 * (first_exponent + fourth_exponent)
        specs.append(
            _problem(
                4,
                index,
                title=rf"양의 등비수열 $\{{a_n\}}$에서 $a_1={base}^{first_exponent}$, $a_4={base}^{fourth_exponent}$이고 $b_n=\log_{base}a_n$일 때, $\sum_{{k=1}}^4 b_k$를 구하시오.",
                answer=str(answer),
                tags=["#등비수열", "#로그법칙", "#등차수열", "#등차수열의합"],
                steps=[
                    ("첫째항과 넷째항의 비로 공비를 구한다.", rf"$r^3={base}^{{{fourth_exponent-first_exponent}}}$이므로 $r={base}^{ratio_exponent}$이다."),
                    ("등비수열의 일반항을 밑이 같은 거듭제곱으로 쓴다.", rf"$a_n={base}^{{{first_exponent}+{ratio_exponent}(n-1)}}$이다."),
                    ("로그를 취해 새 수열의 일반항을 구한다.", rf"$b_n={first_exponent}+{ratio_exponent}(n-1)$이다."),
                    ("새 수열의 첫째항과 넷째항을 확인한다.", rf"$b_1={first_exponent}$, $b_4={fourth_exponent}$이다."),
                    ("등차수열의 합 공식을 적용한다.", rf"$\sum_{{k=1}}^4b_k=\dfrac{{4({first_exponent}+{fourth_exponent})}}{{2}}={answer}$이다."),
                ],
                alternatives=["로그가 곱을 합으로 바꾸므로 처음부터 새 수열이 등차수열임을 확인하고 양 끝항의 평균을 이용할 수 있다."],
            )
        )
    chord_rows = [(5, 2), (6, 4), (7, 1), (8, 6), (10, 8)]
    for index, (radius, intercept) in enumerate(chord_rows, 6):
        x_difference_square = 2 * radius * radius - intercept * intercept
        answer = 2 * x_difference_square
        specs.append(
            _problem(
                4,
                index,
                title=rf"원 $x^2+y^2={radius**2}$과 직선 $y=x+{intercept}$의 두 교점을 $A,B$라 할 때, $AB^2$을 구하시오.",
                answer=str(answer),
                tags=["#원의방정식", "#직선의방정식", "#이차방정식", "#두점사이의거리"],
                steps=[
                    ("직선의 식을 원의 방정식에 대입한다.", rf"$x^2+(x+{intercept})^2={radius**2}$이다."),
                    ("교점의 가로좌표가 만족하는 이차방정식을 만든다.", rf"$2x^2+{2*intercept}x+({intercept**2-radius**2})=0$이다."),
                    ("두 가로좌표 차의 제곱을 근과 계수로 구한다.", rf"$(x_1-x_2)^2=(x_1+x_2)^2-4x_1x_2={x_difference_square}$이다."),
                    ("직선 위 두 점의 세로좌표 차를 확인한다.", r"$y_1-y_2=x_1-x_2$이다."),
                    ("두 좌표 차로 거리의 제곱을 계산한다.", rf"$AB^2=2(x_1-x_2)^2={answer}$이다."),
                ],
                alternatives=[rf"원의 중심에서 직선까지의 거리와 반지름으로 반현의 길이를 구한 뒤 두 배해도 같은 현의 길이를 얻는다."],
            )
        )
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 일차분수함수의 상수와 원의 중심·반지름이다. 작동 원리는 여섯 단계와 두 대안 풀이를 갖는 난이도 5 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    inverse_rows = [(2, 5), (-2, 4), (3, 6), (-3, 5), (4, 1)]
    for index, (denominator_constant, function_value) in enumerate(inverse_rows, 1):
        coefficient_a = -denominator_constant
        coefficient_b = denominator_constant * function_value
        fixed_sum = -2 * denominator_constant
        answer = coefficient_a + coefficient_b + fixed_sum
        specs.append(
            _problem(
                5,
                index,
                title=rf"일차분수함수 $f(x)=\dfrac{{ax+b}}{{x+({denominator_constant})}}$가 $f(0)={function_value}$이고 정의되는 모든 실수에서 $f(f(x))=x$를 만족한다. 방정식 $f(x)=x$의 두 근의 합을 $s$라 할 때, $a+b+s$를 구하시오.",
                answer=str(answer),
                tags=["#유리함수의그래프", "#역함수", "#합성함수", "#근과계수의관계", "#점근선"],
                steps=[
                    ("주어진 함숫값으로 분자의 상수항을 구한다.", rf"$f(0)=b/{denominator_constant}={function_value}$이므로 $b={coefficient_b}$이다."),
                    ("합성함수의 분자와 분모를 정리한다.", rf"$f(f(x))=\dfrac{{(a^2+b)x+b(a+{denominator_constant})}}{{(a+{denominator_constant})x+b+{denominator_constant**2}}}$이다."),
                    ("항등식의 이차항 계수 조건을 적용한다.", rf"$f(f(x))=x$이므로 $a+{denominator_constant}=0$이다."),
                    ("일차분수함수의 계수를 확정한다.", rf"따라서 $a={coefficient_a}$, $b={coefficient_b}$이고 합성 조건도 만족한다."),
                    ("고정점 방정식의 두 근의 합을 구한다.", rf"$f(x)=x$를 정리하면 $x^2+{2*denominator_constant}x-({coefficient_b})=0$이므로 $s={fixed_sum}$이다."),
                    ("세 값을 더해 요구한 값을 계산한다.", rf"$a+b+s={coefficient_a}+({coefficient_b})+({fixed_sum})={answer}$이다."),
                ],
                alternatives=[
                    "일차분수함수를 나타내는 이차 정사각행렬의 대각합이 0이어야 자기 역함수가 된다는 성질을 사용할 수 있다.",
                    "고정점 방정식은 두 근을 직접 구하지 않고 근과 계수의 관계로 합만 계산할 수 있다.",
                ],
            )
        )
    tangent_rows = [(3, 2, 1), (4, -2, 1), (-3, 4, 2), (5, 3, 2), (-4, -3, 2)]
    for index, (center_x, center_y, radius) in enumerate(tangent_rows, 6):
        slope_coefficient = center_x * center_x - radius * radius
        answer = 2 * center_x * center_y
        specs.append(
            _problem(
                5,
                index,
                title=rf"원 $(x-({center_x}))^2+(y-({center_y}))^2={radius**2}$에 접하고 원점을 지나는 두 직선의 기울기를 $m_1,m_2$라 할 때, ${slope_coefficient}(m_1+m_2)$를 구하시오.",
                answer=str(answer),
                tags=["#원의방정식", "#직선의방정식", "#점과직선사이의거리", "#이차방정식", "#기울기"],
                steps=[
                    ("원점을 지나는 직선을 기울기로 나타낸다.", r"직선은 $y=mx$, 즉 $mx-y=0$이다."),
                    ("원의 중심과 반지름을 확인한다.", rf"중심은 $({center_x},{center_y})$이고 반지름은 ${radius}$이다."),
                    ("중심에서 직선까지의 거리를 식으로 나타낸다.", rf"거리는 $\dfrac{{|{center_x}m-({center_y})|}}{{\sqrt{{m^2+1}}}}$이다."),
                    ("접선 조건으로 기울기의 이차방정식을 만든다.", rf"${slope_coefficient}m^2+({-2*center_x*center_y})m+({center_y**2-radius**2})=0$이다."),
                    ("근과 계수의 관계로 두 기울기의 합을 구한다.", rf"$m_1+m_2=\dfrac{{{answer}}}{{{slope_coefficient}}}$이다."),
                    ("문제에서 요구한 계수를 곱한다.", rf"${slope_coefficient}(m_1+m_2)={answer}$이다."),
                ],
                alternatives=[
                    "중심과 접점을 잇는 반지름이 접선에 수직이라는 조건으로 연립해 두 기울기의 합을 구할 수 있다.",
                    "기울기 방정식의 두 해를 각각 계산하지 않고 일차항 계수와 이차항 계수의 비만 사용해도 된다.",
                ],
            )
        )
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v9 직접 출제 명세를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v9 전체 카탈로그다. 작동 원리는 50문항을 생산 형식으로 조립하고 전수 검사한다."""
    return validate_problem_batch(build_catalog(), expected_count=50, batch_id=BATCH_ID, model_name=MODEL_NAME, codebase_base=CODEBASE_BASE, seed_base=SEED_BASE)


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v9 전체 생산분을 멱등 저장하고 재조회한다."""
    return seed_problem_batch(db_path, quests=validated_quests(), batch_id=BATCH_ID, validate_only=validate_only)


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 v9 전체 생산 결과를 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
