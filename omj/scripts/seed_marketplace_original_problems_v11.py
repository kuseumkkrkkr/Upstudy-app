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

BATCH_ID = "marketplace-original-v11"
MODEL_NAME = "aiflow-direct-authoring-v11"
CODEBASE_BASE = 20_260_727_000
SEED_BASE = 202_607_270_000


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 로그의 밑·지수와 순열의 원소 수다. 작동 원리는 두 단계 계산형 난이도 1 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    for index, (base, exponent) in enumerate([(2, 9), (3, 6), (5, 4), (7, 3), (10, 5)], 1):
        specs.append(
            _problem(
                1,
                index,
                title=rf"밑이 ${base}$인 로그 $\log_{base}({base}^{exponent})$의 값을 구하시오.",
                answer=str(exponent),
                tags=["#로그의정의"],
                steps=[
                    ("로그의 진수를 같은 밑의 거듭제곱으로 확인한다.", rf"진수는 ${base}^{exponent}$이다."),
                    ("로그와 지수의 역관계를 적용한다.", rf"따라서 $\log_{base}({base}^{exponent})={exponent}$이다."),
                ],
            )
        )
    for index, count in enumerate([13, 14, 15, 16, 17], 6):
        answer = count * (count - 1)
        specs.append(
            _problem(
                1,
                index,
                title=rf"서로 다른 ${count}$개 가운데 순서를 고려하여 $2$개를 골라 나열하는 경우의 수를 구하시오.",
                answer=str(answer),
                tags=["#순열의수"],
                steps=[
                    ("첫 자리와 둘째 자리의 선택 수를 확인한다.", rf"첫 자리는 ${count}$가지, 둘째 자리는 ${count - 1}$가지이다."),
                    ("곱의 법칙으로 두 선택 수를 곱한다.", rf"경우의 수는 ${count}P_2={count}({count - 1})={answer}$이다."),
                ],
            )
        )
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 직선의 기울기·한 점과 등차수열의 수치다. 작동 원리는 세 단계 개념 적용형 난이도 2 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    line_rows = [(5, 2, 17), (-3, 4, -5), (2, -4, 3), (-4, -2, 15), (6, 3, 10)]
    for index, (slope, point_x, point_y) in enumerate(line_rows, 1):
        answer = point_y - slope * point_x
        specs.append(
            _problem(
                2,
                index,
                title=rf"기울기가 ${slope}$인 직선이 점 $P({point_x},{point_y})$를 지날 때, 이 직선의 y절편을 구하시오.",
                answer=str(answer),
                tags=["#직선의방정식", "#기울기"],
                steps=[
                    ("직선을 기울기와 y절편으로 나타낸다.", rf"직선의 방정식을 $y={slope}x+b$로 둔다."),
                    ("주어진 점의 좌표를 방정식에 대입한다.", rf"${point_y}={slope}({point_x})+b$이다."),
                    ("일차방정식을 풀어 y절편을 구한다.", rf"따라서 $b={point_y}-{slope}({point_x})={answer}$이다."),
                ],
            )
        )
    sequence_rows = [(3, 4, 12), (-2, 5, 9), (10, -3, 8), (7, 2, 15), (-5, 6, 10)]
    for index, (first, difference, term_count) in enumerate(sequence_rows, 6):
        last = first + (term_count - 1) * difference
        answer = term_count * (first + last) // 2
        specs.append(
            _problem(
                2,
                index,
                title=rf"첫째항이 ${first}$이고 공차가 ${difference}$인 등차수열의 첫째항부터 제${term_count}항까지의 합을 구하시오.",
                answer=str(answer),
                tags=["#등차수열의합", "#일반항"],
                steps=[
                    ("등차수열의 마지막 항을 구한다.", rf"$a_{{{term_count}}}={first}+({term_count}-1)({difference})={last}$이다."),
                    ("첫째항과 마지막 항을 이용한 합 공식을 세운다.", rf"$S_{{{term_count}}}=\dfrac{{{term_count}({first}+({last}))}}2$이다."),
                    ("합 공식을 계산한다.", rf"따라서 $S_{{{term_count}}}={answer}$이다."),
                ],
            )
        )
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 원의 중심·반지름과 삼차함수 계수·접점이다. 작동 원리는 네 단계와 한 대안 풀이를 갖는 난이도 3 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    circle_rows = [(6, -3, 4), (-4, 2, 5), (3, 7, 2), (-5, -2, 3), (8, 1, 6)]
    for index, (center_x, center_y, radius) in enumerate(circle_rows, 1):
        x_coefficient = -2 * center_x
        y_coefficient = -2 * center_y
        constant = center_x**2 + center_y**2 - radius**2
        answer = 2 * center_x - center_y
        specs.append(
            _problem(
                3,
                index,
                title=rf"원 $x^2+y^2+({x_coefficient})x+({y_coefficient})y+({constant})=0$의 중심을 $(p,q)$라 할 때, $2p-q$를 구하시오.",
                answer=str(answer),
                tags=["#원의일반형", "#일반형을표준형으로", "#원의표준형"],
                steps=[
                    ("x항 계수에서 중심의 가로좌표를 구한다.", rf"$p=-({x_coefficient})/2={center_x}$이다."),
                    ("y항 계수에서 중심의 세로좌표를 구한다.", rf"$q=-({y_coefficient})/2={center_y}$이다."),
                    ("완전제곱으로 중심과 반지름을 확인한다.", rf"표준형은 $(x-({center_x}))^2+(y-({center_y}))^2={radius**2}$이다."),
                    ("중심 좌표를 요구한 식에 대입한다.", rf"$2p-q=2({center_x})-({center_y})={answer}$이다."),
                ],
                alternatives=["일반형의 일차항 계수를 각각 $-2$로 나누어 중심 좌표를 바로 읽을 수 있다."],
            )
        )
    derivative_rows = [(1, -2, 3, 2), (2, 1, -4, -1), (-1, 3, 2, 2), (3, -2, 1, 1), (1, 4, -5, -2)]
    for index, (cubic, quadratic, linear, point) in enumerate(derivative_rows, 6):
        answer = 3 * cubic * point**2 + 2 * quadratic * point + linear
        specs.append(
            _problem(
                3,
                index,
                title=rf"삼차함수 $f(x)={cubic}x^3+({quadratic})x^2+({linear})x+2$의 그래프 위에서 $x$좌표가 ${point}$인 점의 접선 기울기를 구하시오.",
                answer=str(answer),
                tags=["#도함수", "#접선의기울기", "#미분계수"],
                steps=[
                    ("각 항을 미분하여 도함수를 구한다.", rf"$f'(x)={3*cubic}x^2+({2*quadratic})x+({linear})$이다."),
                    ("접선 기울기를 접점에서의 도함수값으로 나타낸다.", rf"구하는 기울기는 $f'({point})$이다."),
                    ("접점의 가로좌표를 도함수에 대입한다.", rf"$f'({point})={3*cubic}({point})^2+({2*quadratic})({point})+({linear})$이다."),
                    ("제곱과 사칙연산을 계산한다.", rf"따라서 접선 기울기는 ${answer}$이다."),
                ],
                alternatives=["미분계수의 극한 정의로 접점 주변 할선 기울기의 극한을 계산해도 같은 값을 얻는다."],
            )
        )
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 시그마 합의 계수와 연속함수의 빠진 점이다. 작동 원리는 다섯 단계와 한 대안 풀이를 갖는 난이도 4 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    sigma_rows = [(9, -2, 5), (10, 4, -3), (11, 1, 2), (12, -3, 4), (13, 2, -2)]
    for index, (upper, constant, answer) in enumerate(sigma_rows, 1):
        natural_sum = upper * (upper + 1) // 2
        total = answer * natural_sum + constant * upper
        specs.append(
            _problem(
                4,
                index,
                title=rf"$\displaystyle\sum_{{k=1}}^{{{upper}}}(ak+({constant}))={total}$일 때, 상수 $a$를 구하시오.",
                answer=str(answer),
                tags=["#수열의표현", "#시그마공식", "#시그마의성질", "#미정계수법"],
                steps=[
                    ("시그마의 선형성으로 두 합을 분리한다.", rf"$a\sum_{{k=1}}^{{{upper}}}k+({constant})\sum_{{k=1}}^{{{upper}}}1={total}$이다."),
                    ("자연수의 합을 계산한다.", rf"$\sum_{{k=1}}^{{{upper}}}k={natural_sum}$이다."),
                    ("상수 1의 합을 항의 개수로 계산한다.", rf"$\sum_{{k=1}}^{{{upper}}}1={upper}$이다."),
                    ("두 합을 대입해 일차방정식을 만든다.", rf"${natural_sum}a+({constant*upper})={total}$이다."),
                    ("일차방정식을 풀어 계수를 구한다.", rf"따라서 $a={answer}$이다."),
                ],
                alternatives=[rf"합의 각 항을 전개하여 $k$의 계수 합 ${natural_sum}$과 상수항 합 ${constant*upper}$을 직접 모을 수 있다."],
            )
        )
    continuity_rows = [(2, 3), (3, 2), (-2, 4), (4, -1), (-3, 2)]
    for index, (missing_point, function_value) in enumerate(continuity_rows, 6):
        zero_denominator = -missing_point
        coefficient_b = -missing_point * function_value
        coefficient_a = function_value - missing_point
        point_value = missing_point + function_value
        answer = coefficient_a + coefficient_b + point_value
        specs.append(
            _problem(
                4,
                index,
                title=rf"함수 $f(x)=\begin{{cases}}\dfrac{{x^2+ax+b}}{{x-({missing_point})}}&(x\ne {missing_point})\\c&(x={missing_point})\end{{cases}}$가 실수 전체에서 연속이고 $f(0)={function_value}$일 때, $a+b+c$를 구하시오.",
                answer=str(answer),
                tags=["#함수의극한", "#함수의연속", "#인수분해를이용한극한", "#미정계수법"],
                steps=[
                    ("주어진 함숫값으로 분자의 상수항을 구한다.", rf"$f(0)=b/({zero_denominator})={function_value}$이므로 $b={coefficient_b}$이다."),
                    ("연속이려면 분자도 빠진 점에서 0이어야 함을 이용한다.", rf"${missing_point**2}+({missing_point})a+({coefficient_b})=0$이다."),
                    ("일차방정식을 풀어 나머지 계수를 구한다.", rf"따라서 $a={coefficient_a}$이다."),
                    ("분자를 인수분해하고 연속한 정의값을 정한다.", rf"분자는 $(x-({missing_point}))(x+({function_value}))$이므로 $c={point_value}$이다."),
                    ("세 상수를 모두 더한다.", rf"$a+b+c={coefficient_a}+({coefficient_b})+({point_value})={answer}$이다."),
                ],
                alternatives=["인수정리로 분모가 분자의 인수라는 조건을 먼저 적용한 뒤 약분된 직선의 빠진 점을 채울 수 있다."],
            )
        )
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 일차분수함수의 원상·점근선과 원의 외부점이다. 작동 원리는 여섯 단계와 두 대안 풀이를 갖는 난이도 5 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    inverse_rows = [(2, 3, 7, 4), (-1, 4, 5, 2), (3, -2, 8, 5), (4, 1, 9, -2), (-2, -3, 6, 4)]
    for index, (coefficient, denominator_constant, target, preimage) in enumerate(inverse_rows, 1):
        numerator_constant = target * (preimage + denominator_constant) - coefficient * preimage
        vertical = -denominator_constant
        horizontal = coefficient
        answer = preimage + vertical + horizontal
        specs.append(
            _problem(
                5,
                index,
                title=rf"일차분수함수 $f(x)=\dfrac{{{coefficient}x+({numerator_constant})}}{{x+({denominator_constant})}}$의 두 점근선 교점을 $(p,q)$라 할 때, $f^{{-1}}({target})+p+q$를 구하시오.",
                answer=str(answer),
                tags=["#유리함수의그래프", "#역함수", "#합성함수", "#근과계수의관계", "#점근선"],
                steps=[
                    ("역함숫값을 원래 함수의 방정식으로 바꾼다.", rf"$f^{{-1}}({target})=x$라 하면 $f(x)={target}$이다."),
                    ("유리함수 식을 목표값과 같게 놓는다.", rf"$\dfrac{{{coefficient}x+({numerator_constant})}}{{x+({denominator_constant})}}={target}$이다."),
                    ("분모 조건을 확인하고 일차방정식을 푼다.", rf"$x\ne{vertical}$이고 계산하면 $x={preimage}$이다."),
                    ("분모가 0이 되는 수직 점근선을 구한다.", rf"수직 점근선은 $x={vertical}$이므로 $p={vertical}$이다."),
                    ("최고차항 계수비로 수평 점근선을 구한다.", rf"수평 점근선은 $y={horizontal}$이므로 $q={horizontal}$이다."),
                    ("역함숫값과 점근선 교점 좌표를 더한다.", rf"$f^{{-1}}({target})+p+q={preimage}+({vertical})+({horizontal})={answer}$이다."),
                ],
                alternatives=[
                    "x와 y를 바꾸어 역함수 식을 먼저 구한 뒤 목표값을 대입할 수 있다.",
                    "일차분수함수를 상수와 분수항의 합으로 나누면 두 점근선을 동시에 읽을 수 있다.",
                ],
            )
        )
    tangent_rows = [(2, -1, 5, 13, 12), (-3, 2, 6, 10, 8), (4, 3, 7, 25, 24), (-2, -4, 9, 15, 12), (5, -2, 12, 20, 16)]
    for index, (center_x, center_y, radius, center_distance, tangent) in enumerate(tangent_rows, 6):
        point_x = center_x + center_distance
        answer = 2 * tangent
        specs.append(
            _problem(
                5,
                index,
                title=rf"원 $(x-({center_x}))^2+(y-({center_y}))^2={radius**2}$ 밖의 점 $P({point_x},{center_y})$에서 그은 두 접선의 접점을 $A,B$라 할 때, $PA+PB$를 구하시오.",
                answer=str(answer),
                tags=["#원의방정식", "#직선의방정식", "#점과직선사이의거리", "#두점사이의거리", "#기울기"],
                steps=[
                    ("원의 중심 O와 외부점 P 사이의 거리를 구한다.", rf"$OP={center_distance}$이고 반지름은 ${radius}$이다."),
                    ("반지름과 접선이 접점에서 수직임을 이용한다.", r"$OA\perp PA$이므로 삼각형 OAP는 직각삼각형이다."),
                    ("피타고라스 정리로 한 접선 길이의 제곱을 구한다.", rf"$PA^2={center_distance**2}-{radius**2}={tangent**2}$이다."),
                    ("길이의 양수 조건으로 한 접선 길이를 정한다.", rf"$PA={tangent}$이다."),
                    ("한 외부점에서 그은 두 접선 길이가 같음을 적용한다.", rf"$PB=PA={tangent}$이다."),
                    ("두 접선의 길이를 더한다.", rf"$PA+PB={tangent}+{tangent}={answer}$이다."),
                ],
                alternatives=[
                    "원의 중심을 원점으로 평행이동하면 외부점과 중심 사이 거리만 남아 같은 직각삼각형을 얻는다.",
                    "접선 길이 공식 $\sqrt{OP^2-r^2}$을 두 번 더해 바로 계산할 수 있다.",
                ],
            )
        )
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v11 직접 출제 명세를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v11 전체 카탈로그다. 작동 원리는 50문항을 생산 형식으로 조립하고 전수 검사한다."""
    return validate_problem_batch(
        build_catalog(),
        expected_count=50,
        batch_id=BATCH_ID,
        model_name=MODEL_NAME,
        codebase_base=CODEBASE_BASE,
        seed_base=SEED_BASE,
    )


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v11 전체 생산분을 멱등 저장하고 재조회한다."""
    return seed_problem_batch(db_path, quests=validated_quests(), batch_id=BATCH_ID, validate_only=validate_only)


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 v11 전체 생산 결과를 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
