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

BATCH_ID = "marketplace-original-v12"
MODEL_NAME = "aiflow-direct-authoring-v12"
CODEBASE_BASE = 20_260_728_000
SEED_BASE = 202_607_280_000


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 집합의 원소 수와 조합의 전체 원소 수다. 작동 원리는 두 단계 계산형 난이도 1 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    set_rows = [(18, 25, 35), (27, 19, 39), (32, 24, 45), (21, 28, 40), (35, 17, 44)]
    for index, (left_count, right_count, union_count) in enumerate(set_rows, 1):
        answer = left_count + right_count - union_count
        specs.append(
            _problem(
                1,
                index,
                title=rf"유한집합 $A,B$에 대하여 $n(A)={left_count}$, $n(B)={right_count}$, $n(A\cup B)={union_count}$일 때, $n(A\cap B)$를 구하시오.",
                answer=str(answer),
                tags=["#집합의연산"],
                steps=[
                    ("두 집합의 합집합 원소 수 공식을 세운다.", r"$n(A\cup B)=n(A)+n(B)-n(A\cap B)$이다."),
                    ("알려진 원소 수를 대입해 교집합을 구한다.", rf"$n(A\cap B)={left_count}+{right_count}-{union_count}={answer}$이다."),
                ],
            )
        )
    for index, count in enumerate([18, 19, 20, 21, 22], 6):
        answer = count * (count - 1) // 2
        specs.append(
            _problem(
                1,
                index,
                title=rf"서로 다른 ${count}$명 중 순서를 고려하지 않고 대표 $2$명을 뽑는 경우의 수를 구하시오.",
                answer=str(answer),
                tags=["#조합의수"],
                steps=[
                    ("순서를 고려하지 않는 두 명의 선택을 조합으로 나타낸다.", rf"경우의 수는 ${count}C_2$이다."),
                    ("조합 공식을 계산한다.", rf"${count}C_2=\dfrac{{{count}({count - 1})}}2={answer}$이다."),
                ],
            )
        )
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 일차함수의 계수·원상과 원의 중심·반지름이다. 작동 원리는 세 단계 개념 적용형 난이도 2 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    inverse_rows = [(4, 3, 6), (5, -2, 7), (-3, 4, -2), (2, 9, -4), (-2, -5, 8)]
    for index, (coefficient, constant, answer) in enumerate(inverse_rows, 1):
        target = coefficient * answer + constant
        specs.append(
            _problem(
                2,
                index,
                title=rf"일차함수 $f(x)={coefficient}x+({constant})$의 역함수를 $g$라 할 때, $g({target})$의 값을 구하시오.",
                answer=str(answer),
                tags=["#역함수", "#일대일대응"],
                steps=[
                    ("역함숫값을 원래 함수의 방정식으로 바꾼다.", rf"$g({target})=x$라 하면 $f(x)={target}$이다."),
                    ("일차함수 식을 목표 함숫값과 같게 놓는다.", rf"${coefficient}x+({constant})={target}$이다."),
                    ("일차방정식을 풀어 원상을 구한다.", rf"따라서 $g({target})={answer}$이다."),
                ],
            )
        )
    circle_rows = [(3, -4, 6), (-5, 2, 4), (7, 3, 5), (-2, -6, 7), (4, 5, 3)]
    for index, (center_x, center_y, radius) in enumerate(circle_rows, 6):
        x_coefficient = -2 * center_x
        y_coefficient = -2 * center_y
        constant = center_x**2 + center_y**2 - radius**2
        specs.append(
            _problem(
                2,
                index,
                title=rf"원 $x^2+y^2+({x_coefficient})x+({y_coefficient})y+({constant})=0$의 반지름을 구하시오.",
                answer=str(radius),
                tags=["#원의일반형", "#일반형을표준형으로"],
                steps=[
                    ("x항과 y항을 각각 완전제곱할 준비를 한다.", rf"중심 후보는 $({center_x},{center_y})$이다."),
                    ("일반형을 원의 표준형으로 바꾼다.", rf"$(x-({center_x}))^2+(y-({center_y}))^2={radius**2}$이다."),
                    ("표준형의 우변에서 반지름을 읽는다.", rf"반지름의 제곱이 ${radius**2}$이므로 반지름은 ${radius}$이다."),
                ],
            )
        )
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 점화수열의 첫째항·증가계수와 유리함수 계수다. 작동 원리는 네 단계와 한 대안 풀이를 갖는 난이도 3 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    recurrence_rows = [(2, 3), (-1, 4), (5, 2), (3, -1), (-4, 5)]
    for index, (first, coefficient) in enumerate(recurrence_rows, 1):
        terms = [first]
        for n in range(1, 5):
            terms.append(terms[-1] + coefficient * n)
        answer = sum(terms)
        specs.append(
            _problem(
                3,
                index,
                title=rf"수열 $\{{a_n\}}$이 $a_1={first}$, $a_{{n+1}}=a_n+({coefficient})n$을 만족할 때, $\sum_{{k=1}}^5a_k$를 구하시오.",
                answer=str(answer),
                tags=["#수열의표현", "#시그마공식", "#일반항"],
                steps=[
                    ("점화식에서 연속한 두 항의 차를 확인한다.", rf"$a_{{n+1}}-a_n={coefficient}n$이다."),
                    ("첫째항부터 점화식을 차례로 적용한다.", rf"첫 다섯 항은 ${','.join(str(value) for value in terms)}$이다."),
                    ("구한 항을 시그마 합으로 나타낸다.", rf"$\sum_{{k=1}}^5a_k={' + '.join(str(value) for value in terms)}$이다."),
                    ("다섯 항을 모두 더한다.", rf"따라서 합은 ${answer}$이다."),
                ],
                alternatives=[rf"$a_n={first}+{coefficient}\sum_{{j=1}}^{{n-1}}j$로 일반항을 만든 뒤 첫 다섯 항을 합할 수 있다."],
            )
        )
    rational_rows = [(3, 5, 4), (-2, 7, 3), (5, -4, -2), (-3, 10, -4), (4, 9, 1)]
    for index, (horizontal, numerator_constant, vertical) in enumerate(rational_rows, 6):
        remainder = numerator_constant + horizontal * vertical
        answer = 2 * vertical - horizontal
        specs.append(
            _problem(
                3,
                index,
                title=rf"유리함수 $f(x)=\dfrac{{{horizontal}x+({numerator_constant})}}{{x-({vertical})}}$의 두 점근선 교점을 $(p,q)$라 할 때, $2p-q$를 구하시오.",
                answer=str(answer),
                tags=["#유리함수의그래프", "#점근선", "#유리함수의평행이동"],
                steps=[
                    ("분자를 분모의 배수와 나머지로 나눈다.", rf"${horizontal}x+({numerator_constant})={horizontal}(x-({vertical}))+({remainder})$이다."),
                    ("유리함수를 평행이동 표준형으로 바꾼다.", rf"$f(x)={horizontal}+\dfrac{{{remainder}}}{{x-({vertical})}}$이다."),
                    ("수직 점근선과 수평 점근선을 읽는다.", rf"$(p,q)=({vertical},{horizontal})$이다."),
                    ("교점 좌표를 요구한 식에 대입한다.", rf"$2p-q=2({vertical})-({horizontal})={answer}$이다."),
                ],
                alternatives=["분모의 영점과 분자·분모의 최고차항 계수비를 각각 이용해 두 점근선을 바로 구할 수 있다."],
            )
        )
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 원·직선의 수치와 정적분 함수의 계수다. 작동 원리는 다섯 단계와 한 대안 풀이를 갖는 난이도 4 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    chord_rows = [(9, 4), (11, 3), (12, 8), (13, 5), (15, 9)]
    for index, (radius, intercept) in enumerate(chord_rows, 1):
        x_difference_square = 2 * radius**2 - intercept**2
        answer = 2 * x_difference_square
        specs.append(
            _problem(
                4,
                index,
                title=rf"원 $x^2+y^2={radius**2}$과 직선 $y=x+{intercept}$의 두 교점을 $A,B$라 할 때, 현의 길이의 제곱 $AB^2$을 구하시오.",
                answer=str(answer),
                tags=["#원의방정식", "#직선의방정식", "#이차방정식", "#두점사이의거리"],
                steps=[
                    ("직선의 식을 원의 방정식에 대입한다.", rf"$x^2+(x+{intercept})^2={radius**2}$이다."),
                    ("교점의 가로좌표가 만족하는 이차방정식을 만든다.", rf"$2x^2+{2*intercept}x+({intercept**2-radius**2})=0$이다."),
                    ("두 가로좌표 차의 제곱을 근과 계수로 구한다.", rf"$(x_1-x_2)^2={x_difference_square}$이다."),
                    ("직선 위에서 두 세로좌표의 차를 확인한다.", r"$y_1-y_2=x_1-x_2$이다."),
                    ("두 좌표 차로 현의 길이 제곱을 계산한다.", rf"$AB^2=2(x_1-x_2)^2={answer}$이다."),
                ],
                alternatives=["원의 중심에서 직선까지의 거리로 반현의 길이를 구한 뒤 두 배하는 방법도 사용할 수 있다."],
            )
        )
    integral_rows = [(2, 4, 1), (3, -2, 2), (4, 3, -1), (2, -5, 3), (3, 6, -2)]
    for index, (upper, parameter, constant) in enumerate(integral_rows, 6):
        given = upper**3 + parameter * upper**2 // 2 + constant * upper
        answer = 2 + parameter + 2 * constant
        specs.append(
            _problem(
                4,
                index,
                title=rf"함수 $F(x)=\int_0^x(3t^2+at+({constant}))\,dt$가 $F({upper})={given}$을 만족할 때, $2F(1)$을 구하시오.",
                answer=str(answer),
                tags=["#정적분", "#미적분의기본정리", "#미정계수법", "#정적분의선형성"],
                steps=[
                    ("매개변수를 포함한 정적분을 계산한다.", rf"$F(x)=x^3+\dfrac{{a}}2x^2+({constant})x$이다."),
                    ("주어진 함숫값 조건을 대입한다.", rf"${upper**3}+({upper**2}/2)a+({constant*upper})={given}$이다."),
                    ("일차방정식을 풀어 매개변수를 정한다.", rf"계산하면 $a={parameter}$이다."),
                    ("정해진 값으로 $F(1)$을 나타낸다.", rf"$F(1)=1+\dfrac{{{parameter}}}2+({constant})$이다."),
                    ("문제에서 요구한 배수를 계산한다.", rf"$2F(1)=2+({parameter})+2({constant})={answer}$이다."),
                ],
                alternatives=["미적분의 기본정리와 $F(0)=0$을 이용해 원시함수를 먼저 세워도 같은 식을 얻는다."],
            )
        )
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 구간별 함수의 연속 상수와 삼차함수 도함수 수치다. 작동 원리는 여섯 단계와 두 대안 풀이를 갖는 난이도 5 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    composition_rows = [(3, 1), (4, 2), (5, -1), (6, 3), (7, 0)]
    for index, (constant, target) in enumerate(composition_rows, 1):
        answer = target - 2 * constant
        specs.append(
            _problem(
                5,
                index,
                title=rf"함수 $f(x)=\begin{{cases}}x+a&(x<0)\\x^2+{constant}&(x\ge0)\end{{cases}}$가 실수 전체에서 연속일 때, 방정식 $f(f(x))={target}$의 모든 실근의 합을 구하시오.",
                answer=str(answer),
                tags=["#합성함수", "#함수의연속", "#이차방정식", "#경우의수", "#정의역"],
                steps=[
                    ("원점에서의 연속 조건으로 매개변수를 정한다.", rf"좌극한과 함숫값이 같아야 하므로 $a={constant}$이다."),
                    ("목표값과 오른쪽 조각의 최솟값을 비교한다.", rf"${target}<{constant}$이므로 바깥 함수의 입력은 음수여야 한다."),
                    ("안쪽 함숫값이 음수가 되는 입력 구간을 찾는다.", rf"$f(x)<0$이려면 $x<-{constant}$이고 $f(x)=x+{constant}$이다."),
                    ("찾은 구간에서 합성함수를 계산한다.", rf"$f(f(x))=(x+{constant})+{constant}=x+{2*constant}$이다."),
                    ("일차방정식을 풀어 실근을 구한다.", rf"$x+{2*constant}={target}$이므로 $x={answer}$이다."),
                    ("구간 조건을 확인하고 모든 실근의 합을 정한다.", rf"${answer}<-{constant}$이고 다른 구간에는 해가 없으므로 합은 ${answer}$이다."),
                ],
                alternatives=[
                    "함수의 치역을 음수와 음이 아닌 부분으로 먼저 나누면 바깥 함수가 사용할 조각을 결정할 수 있다.",
                    "구간별 그래프를 이어 그려 목표 높이와 만나는 합성함수의 가지가 하나뿐임을 확인할 수 있다.",
                ],
            )
        )
    area_rows = [2, 3, 4, 5, 6]
    for index, scale in enumerate(area_rows, 6):
        right = 3 * scale
        function_value = 4 * scale**3
        answer = 27 * scale**4
        specs.append(
            _problem(
                5,
                index,
                title=rf"최고차항의 계수가 $1$인 삼차함수 $f$가 $f'(x)=3(x-{scale})(x-{right})$, $f({scale})={function_value}$을 만족한다. 곡선 $y=f(x)$와 $x$축 및 두 직선 $x=0$, $x={right}$로 둘러싸인 넓이를 $S$라 할 때, $4S$를 구하시오.",
                answer=str(answer),
                tags=["#도함수", "#부정적분", "#함수의극대와극소", "#인수분해", "#정적분과넓이"],
                steps=[
                    ("주어진 도함수를 전개한다.", rf"$f'(x)=3x^2-{12*scale}x+{9*scale**2}$이다."),
                    ("도함수를 적분해 삼차함수의 형태를 구한다.", rf"$f(x)=x^3-{6*scale}x^2+{9*scale**2}x+C$이다."),
                    ("함숫값 조건으로 적분상수를 정한다.", rf"$f({scale})={function_value}+C={function_value}$이므로 $C=0$이다."),
                    ("함수식을 인수분해해 구간의 부호를 확인한다.", rf"$f(x)=x(x-{right})^2$이므로 $0\le x\le{right}$에서 음이 아니다."),
                    ("곡선과 x축 사이 넓이를 정적분한다.", rf"$S=\int_0^{{{right}}}x(x-{right})^2dx=\dfrac{{27}}4{scale}^4$이다."),
                    ("문제에서 요구한 네 배를 계산한다.", rf"$4S=27\cdot{scale}^4={answer}$이다."),
                ],
                alternatives=[
                    rf"도함수의 두 영점과 함숫값 조건을 이용해 $f(x)=x(x-{right})^2$임을 미분으로 검산할 수 있다.",
                    "구간에서 두 인수가 모두 음이 아닌 구조이므로 절댓값 없이 정적분한 값이 곧 넓이이다.",
                ],
            )
        )
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v12 직접 출제 명세를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v12 전체 카탈로그다. 작동 원리는 50문항을 생산 형식으로 조립하고 전수 검사한다."""
    return validate_problem_batch(build_catalog(), expected_count=50, batch_id=BATCH_ID, model_name=MODEL_NAME, codebase_base=CODEBASE_BASE, seed_base=SEED_BASE)


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v12 전체 생산분을 멱등 저장하고 재조회한다."""
    return seed_problem_batch(db_path, quests=validated_quests(), batch_id=BATCH_ID, validate_only=validate_only)


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 v12 전체 생산 결과를 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
