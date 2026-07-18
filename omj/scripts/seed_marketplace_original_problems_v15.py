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

BATCH_ID = "marketplace-original-v15"
MODEL_NAME = "aiflow-direct-authoring-v15"
CODEBASE_BASE = 20_260_731_000
SEED_BASE = 202_607_310_000


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 팩토리얼의 자연수와 등차수열의 대칭항이다. 작동 원리는 두 단계 계산형 난이도 1 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    for index, number in enumerate(range(8, 13), 1):
        answer = number * (number - 1) * (number - 2) * (number - 3)
        specs.append(
            _problem(
                1,
                index,
                title=rf"팩토리얼의 비 $\dfrac{{{number}!}}{{({number}-4)!}}$의 값을 구하시오.",
                answer=str(answer),
                tags=["#팩토리얼"],
                steps=[
                    ("분자의 팩토리얼을 분모가 나타나도록 전개한다.", rf"${number}!={number}({number-1})({number-2})({number-3})({number}-4)!$이다."),
                    ("공통 팩토리얼을 약분하고 곱을 계산한다.", rf"값은 ${number}({number-1})({number-2})({number-3})={answer}$이다."),
                ],
            )
        )
    sequence_rows = [(2, 26), (-5, 19), (8, -4), (-10, 20), (7, 31)]
    for index, (first, seventh) in enumerate(sequence_rows, 6):
        answer = (first + seventh) // 2
        specs.append(
            _problem(
                1,
                index,
                title=rf"등차수열에서 첫째항이 ${first}$이고 일곱째항이 ${seventh}$일 때, 넷째항을 구하시오.",
                answer=str(answer),
                tags=["#등차수열"],
                steps=[
                    ("대칭인 첫째항과 일곱째항의 평균을 이용한다.", rf"$2a_4=a_1+a_7={first}+({seventh})$이다."),
                    ("양변을 2로 나누어 가운데 항을 구한다.", rf"따라서 $a_4={answer}$이다."),
                ],
            )
        )
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 삼차다항식의 나머지 조건과 로그방정식의 진수 이동량이다. 작동 원리는 세 단계 개념 적용형 난이도 2 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    remainder_rows = [(1, 3, -2, 6), (-2, -1, 4, 3), (3, 2, 1, -2), (-1, 4, -5, 7), (2, -3, 6, -4)]
    for index, (root, quadratic, constant, answer) in enumerate(remainder_rows, 1):
        remainder = root**3 + quadratic * root**2 + answer * root + constant
        fixed_part = root**3 + quadratic * root**2 + constant
        specs.append(
            _problem(
                2,
                index,
                title=rf"다항식 $P(x)=x^3+({quadratic})x^2+ax+({constant})$을 $x-({root})$로 나눈 나머지가 ${remainder}$일 때, 상수 $a$를 구하시오.",
                answer=str(answer),
                tags=["#나머지정리", "#미정계수법"],
                steps=[
                    ("나머지정리로 함숫값 조건을 만든다.", rf"$P({root})={remainder}$이다."),
                    ("주어진 값을 다항식에 대입한다.", rf"${fixed_part}+({root})a={remainder}$이다."),
                    ("일차방정식을 풀어 미정계수를 구한다.", rf"따라서 $a={answer}$이다."),
                ],
            )
        )
    logarithm_rows = [(2, 5, 6), (3, -4, 4), (5, 2, 3), (4, -3, 3), (7, 1, 2)]
    for index, (base, shift, exponent) in enumerate(logarithm_rows, 6):
        answer = base**exponent - shift
        specs.append(
            _problem(
                2,
                index,
                title=rf"로그방정식 $\log_{base}(x+({shift}))={exponent}$을 만족하는 실수 $x$를 구하시오.",
                answer=str(answer),
                tags=["#로그방정식", "#진수조건"],
                steps=[
                    ("로그의 진수 조건을 확인한다.", rf"$x+({shift})>0$이어야 한다."),
                    ("로그의 정의로 지수식으로 바꾼다.", rf"$x+({shift})={base}^{exponent}={base**exponent}$이다."),
                    ("일차방정식을 풀고 진수 조건을 확인한다.", rf"$x={answer}$이고 진수는 양수이므로 조건을 만족한다."),
                ],
            )
        )
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 자연수 세제곱합의 상한과 원의 중심·반지름이다. 작동 원리는 네 단계와 한 대안 풀이를 갖는 난이도 3 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    for index, upper in enumerate(range(6, 11), 1):
        natural_sum = upper * (upper + 1) // 2
        answer = natural_sum**2
        specs.append(
            _problem(
                3,
                index,
                title=rf"자연수 세제곱의 합 $1^3+2^3+\cdots+{upper}^3$의 값을 구하시오.",
                answer=str(answer),
                tags=["#수열의표현", "#시그마공식", "#자연수의거듭제곱의합"],
                steps=[
                    ("자연수 세제곱합 공식을 적는다.", r"$\sum_{k=1}^n k^3=\left(\dfrac{n(n+1)}2\right)^2$이다."),
                    ("합의 상한을 공식에 대입한다.", rf"$\sum_{{k=1}}^{{{upper}}}k^3=\left(\dfrac{{{upper}({upper+1})}}2\right)^2$이다."),
                    ("괄호 안의 자연수 합을 계산한다.", rf"$\dfrac{{{upper}({upper+1})}}2={natural_sum}$이다."),
                    ("자연수 합을 제곱해 결과를 구한다.", rf"따라서 세제곱합은 ${natural_sum}^2={answer}$이다."),
                ],
                alternatives=["세제곱합이 같은 상한의 자연수 합의 제곱이라는 항등식을 작은 항부터 귀납적으로 확인할 수 있다."],
            )
        )
    circle_rows = [(2, -5, 3), (-6, 1, 4), (4, 6, 5), (-3, -7, 2), (7, -2, 6)]
    for index, (center_x, center_y, radius) in enumerate(circle_rows, 6):
        x_coefficient = -2 * center_x
        y_coefficient = -2 * center_y
        constant = center_x**2 + center_y**2 - radius**2
        answer = center_x - 2 * center_y
        specs.append(
            _problem(
                3,
                index,
                title=rf"원 $x^2+y^2+({x_coefficient})x+({y_coefficient})y+({constant})=0$의 중심을 $(p,q)$라 할 때, $p-2q$를 구하시오.",
                answer=str(answer),
                tags=["#원의일반형", "#일반형을표준형으로", "#원의표준형"],
                steps=[
                    ("x항 계수로 중심의 가로좌표를 구한다.", rf"$p=-({x_coefficient})/2={center_x}$이다."),
                    ("y항 계수로 중심의 세로좌표를 구한다.", rf"$q=-({y_coefficient})/2={center_y}$이다."),
                    ("완전제곱으로 중심과 반지름을 확인한다.", rf"표준형은 $(x-({center_x}))^2+(y-({center_y}))^2={radius**2}$이다."),
                    ("중심 좌표를 요구한 식에 대입한다.", rf"$p-2q={center_x}-2({center_y})={answer}$이다."),
                ],
                alternatives=["일반형의 두 일차항 계수를 각각 $-2$로 나누어 중심 좌표를 바로 읽을 수 있다."],
            )
        )
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 제곱합 시그마의 미정계수와 정적분의 이차항 계수다. 작동 원리는 다섯 단계와 한 대안 풀이를 갖는 난이도 4 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    sigma_rows = [(5, 2, 3), (6, -1, 2), (7, 3, -2), (8, -2, 4), (9, 1, -3)]
    for index, (upper, constant, answer) in enumerate(sigma_rows, 1):
        square_sum = upper * (upper + 1) * (2 * upper + 1) // 6
        total = answer * square_sum + constant * upper
        specs.append(
            _problem(
                4,
                index,
                title=rf"$\displaystyle\sum_{{k=1}}^{{{upper}}}(ak^2+({constant}))={total}$일 때, 상수 $a$를 구하시오.",
                answer=str(answer),
                tags=["#수열의표현", "#시그마공식", "#시그마의성질", "#미정계수법"],
                steps=[
                    ("시그마의 선형성으로 두 합을 분리한다.", rf"$a\sum_{{k=1}}^{{{upper}}}k^2+({constant})\sum_{{k=1}}^{{{upper}}}1={total}$이다."),
                    ("자연수 제곱의 합을 계산한다.", rf"$\sum_{{k=1}}^{{{upper}}}k^2={square_sum}$이다."),
                    ("상수 1의 합을 항의 개수로 계산한다.", rf"$\sum_{{k=1}}^{{{upper}}}1={upper}$이다."),
                    ("두 합을 대입해 일차방정식을 만든다.", rf"${square_sum}a+({constant*upper})={total}$이다."),
                    ("일차방정식을 풀어 계수를 구한다.", rf"따라서 $a={answer}$이다."),
                ],
                alternatives=["각 항을 전개해 제곱항 계수의 합과 상수항의 합을 따로 모아도 같은 방정식을 얻는다."],
            )
        )
    integral_rows = [(3, 2, 4), (6, -1, 2), (3, -2, -3), (9, 1, 1), (6, 3, -2)]
    for index, (upper, constant, answer) in enumerate(integral_rows, 6):
        cubic_factor = upper**3 // 3
        value = answer * cubic_factor + constant * upper
        specs.append(
            _problem(
                4,
                index,
                title=rf"$\int_0^{{{upper}}}(ax^2+({constant}))\,dx={value}$일 때, 상수 $a$를 구하시오.",
                answer=str(answer),
                tags=["#정적분", "#정적분의계산", "#정적분의선형성", "#미정계수법"],
                steps=[
                    ("매개변수를 포함한 부정적분을 구한다.", rf"$\int(ax^2+({constant}))dx=\dfrac{{a}}3x^3+({constant})x$이다."),
                    ("적분 구간의 양 끝값을 대입한다.", rf"정적분은 $({cubic_factor})a+({constant*upper})$이다."),
                    ("주어진 값과 같게 놓는다.", rf"${cubic_factor}a+({constant*upper})={value}$이다."),
                    ("상수항을 이항해 계수항을 정리한다.", rf"${cubic_factor}a={value-constant*upper}$이다."),
                    ("일차방정식을 풀어 계수를 구한다.", rf"따라서 $a={answer}$이다."),
                ],
                alternatives=["정적분의 선형성으로 이차항 적분과 상수항 적분을 처음부터 따로 계산할 수 있다."],
            )
        )
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 자기역 일차분수함수의 상수와 원의 중심·외부점 거리다. 작동 원리는 여섯 단계와 두 대안 풀이를 갖는 난이도 5 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    inverse_rows = [(5, 2), (-4, 3), (2, 7), (-5, 1), (3, -2)]
    for index, (denominator_constant, function_value) in enumerate(inverse_rows, 1):
        coefficient_a = -denominator_constant
        coefficient_b = denominator_constant * function_value
        fixed_sum = -2 * denominator_constant
        answer = coefficient_a - coefficient_b + fixed_sum
        specs.append(
            _problem(
                5,
                index,
                title=rf"일차분수함수 $f(x)=\dfrac{{ax+b}}{{x+({denominator_constant})}}$가 $f(0)={function_value}$이고 정의되는 모든 실수에서 $f(f(x))=x$를 만족한다. 방정식 $f(x)=x$의 두 근의 합을 $s$라 할 때, $a-b+s$를 구하시오.",
                answer=str(answer),
                tags=["#유리함수의그래프", "#역함수", "#합성함수", "#근과계수의관계", "#점근선"],
                steps=[
                    ("주어진 함숫값으로 분자의 상수항을 구한다.", rf"$b/{denominator_constant}={function_value}$이므로 $b={coefficient_b}$이다."),
                    ("합성함수의 분자와 분모를 정리한다.", rf"$f(f(x))=\dfrac{{(a^2+b)x+b(a+{denominator_constant})}}{{(a+{denominator_constant})x+b+{denominator_constant**2}}}$이다."),
                    ("항등식의 이차항 계수 조건을 적용한다.", rf"$f(f(x))=x$이므로 $a+{denominator_constant}=0$이다."),
                    ("일차분수함수의 두 계수를 확정한다.", rf"따라서 $a={coefficient_a}$, $b={coefficient_b}$이다."),
                    ("고정점 방정식의 두 근의 합을 구한다.", rf"$f(x)=x$를 정리하면 $x^2+{2*denominator_constant}x-({coefficient_b})=0$이므로 $s={fixed_sum}$이다."),
                    ("세 값을 요구한 부호로 계산한다.", rf"$a-b+s={coefficient_a}-({coefficient_b})+({fixed_sum})={answer}$이다."),
                ],
                alternatives=[
                    "일차분수함수를 나타내는 행렬의 대각합이 0이면 자기 역함수가 된다는 성질을 사용할 수 있다.",
                    "고정점 방정식의 두 근은 직접 구하지 않고 근과 계수의 관계로 합만 계산할 수 있다.",
                ],
            )
        )
    tangent_rows = [(3, 4, 8, 17, 15), (-4, 1, 9, 41, 40), (6, -3, 12, 37, 35), (-5, -2, 20, 29, 21), (2, -6, 16, 34, 30)]
    for index, (center_x, center_y, radius, center_distance, tangent) in enumerate(tangent_rows, 6):
        point_x = center_x + center_distance
        answer = 2 * tangent**2
        specs.append(
            _problem(
                5,
                index,
                title=rf"원 $(x-({center_x}))^2+(y-({center_y}))^2={radius**2}$ 밖의 점 $P({point_x},{center_y})$에서 그은 두 접선의 접점을 $A,B$라 할 때, $PA^2+PB^2$을 구하시오.",
                answer=str(answer),
                tags=["#원의방정식", "#직선의방정식", "#점과직선사이의거리", "#두점사이의거리", "#기울기"],
                steps=[
                    ("원의 중심 O와 외부점 P 사이 거리를 구한다.", rf"$OP={center_distance}$이고 반지름은 ${radius}$이다."),
                    ("반지름과 접선이 접점에서 수직임을 이용한다.", r"$OA\perp PA$이므로 삼각형 OAP는 직각삼각형이다."),
                    ("피타고라스 정리로 한 접선 길이의 제곱을 구한다.", rf"$PA^2={center_distance**2}-{radius**2}={tangent**2}$이다."),
                    ("한 외부점에서 그은 두 접선 길이가 같음을 적용한다.", rf"$PB^2=PA^2={tangent**2}$이다."),
                    ("두 접선 길이의 제곱합을 나타낸다.", rf"$PA^2+PB^2={tangent**2}+{tangent**2}$이다."),
                    ("두 제곱을 더해 결과를 계산한다.", rf"따라서 $PA^2+PB^2={answer}$이다."),
                ],
                alternatives=[
                    "원의 중심을 원점으로 평행이동해도 중심과 외부점 사이 거리와 접선 길이는 변하지 않는다.",
                    "접선 길이 공식의 제곱 $OP^2-r^2$을 두 배해 바로 계산할 수 있다.",
                ],
            )
        )
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v15 직접 출제 명세를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v15 전체 카탈로그다. 작동 원리는 50문항을 생산 형식으로 조립하고 전수 검사한다."""
    return validate_problem_batch(build_catalog(), expected_count=50, batch_id=BATCH_ID, model_name=MODEL_NAME, codebase_base=CODEBASE_BASE, seed_base=SEED_BASE)


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v15 전체 생산분을 멱등 저장하고 재조회한다."""
    return seed_problem_batch(db_path, quests=validated_quests(), batch_id=BATCH_ID, validate_only=validate_only)


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 v15 전체 생산 결과를 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
