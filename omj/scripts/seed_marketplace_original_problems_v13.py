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

BATCH_ID = "marketplace-original-v13"
MODEL_NAME = "aiflow-direct-authoring-v13"
CODEBASE_BASE = 20_260_729_000
SEED_BASE = 202_607_290_000


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 단항식의 계수·지수와 팩토리얼의 자연수다. 작동 원리는 두 단계 계산형 난이도 1 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    monomial_rows = [(4, 3, 2, 5), (-5, 2, 3, 4), (6, -2, 4, 3), (-3, -7, 5, 2), (8, 5, 1, 6)]
    for index, (left, right, left_power, right_power) in enumerate(monomial_rows, 1):
        answer = left * right
        total_power = left_power + right_power
        specs.append(
            _problem(
                1,
                index,
                title=rf"두 단항식 $({left}x^{left_power})$와 $({right}x^{right_power})$의 곱에서 $x^{total_power}$의 계수를 구하시오.",
                answer=str(answer),
                tags=["#다항식의연산"],
                steps=[
                    ("두 단항식의 계수끼리 곱한다.", rf"계수의 곱은 $({left})({right})={answer}$이다."),
                    ("같은 문자의 지수를 더해 곱을 완성한다.", rf"곱은 ${answer}x^{{{left_power}+{right_power}}}={answer}x^{total_power}$이므로 계수는 ${answer}$이다."),
                ],
            )
        )
    for index, number in enumerate(range(14, 19), 6):
        answer = number * (number - 1)
        specs.append(
            _problem(
                1,
                index,
                title=rf"팩토리얼의 비 $\dfrac{{{number}!}}{{({number}-2)!}}$의 값을 구하시오.",
                answer=str(answer),
                tags=["#팩토리얼"],
                steps=[
                    ("분자의 팩토리얼을 분모가 나타나도록 전개한다.", rf"${number}!={number}({number-1})({number}-2)!$이다."),
                    ("공통 팩토리얼을 약분하고 계산한다.", rf"값은 ${number}({number-1})={answer}$이다."),
                ],
            )
        )
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 직선 위 두 점과 이차방정식의 일차항 계수다. 작동 원리는 세 단계 개념 적용형 난이도 2 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    line_rows = [(1, 4, 5, 20), (-2, 7, 3, -8), (4, -5, 10, 13), (-5, -4, 1, 8), (2, 15, 9, -6)]
    for index, (x1, y1, x2, y2) in enumerate(line_rows, 1):
        answer = (y2 - y1) // (x2 - x1)
        specs.append(
            _problem(
                2,
                index,
                title=rf"서로 다른 두 점 $A({x1},{y1})$, $B({x2},{y2})$를 지나는 직선의 기울기를 구하시오.",
                answer=str(answer),
                tags=["#두점을지나는직선", "#기울기"],
                steps=[
                    ("두 점의 y좌표 변화량을 구한다.", rf"$\Delta y={y2}-({y1})={y2-y1}$이다."),
                    ("두 점의 x좌표 변화량을 구한다.", rf"$\Delta x={x2}-({x1})={x2-x1}$이다."),
                    ("두 변화량의 비로 기울기를 계산한다.", rf"기울기는 $\Delta y/\Delta x={answer}$이다."),
                ],
            )
        )
    for index, coefficient in enumerate([22, -24, 26, -28, 30], 6):
        answer = coefficient**2 // 4
        specs.append(
            _problem(
                2,
                index,
                title=rf"이차방정식 $x^2+({coefficient})x+k=0$이 중근을 가질 때, 상수 $k$를 구하시오.",
                answer=str(answer),
                tags=["#이차방정식의판별식", "#판별식과근의개수"],
                steps=[
                    ("중근을 갖는 판별식 조건을 확인한다.", r"중근을 가지므로 판별식 $D=0$이다."),
                    ("주어진 계수를 판별식에 대입한다.", rf"$D=({coefficient})^2-4k=0$이다."),
                    ("일차방정식을 풀어 상수항을 구한다.", rf"따라서 $k={answer}$이다."),
                ],
            )
        )
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 지름의 두 끝점과 등차수열의 첫째항·공차·항수다. 작동 원리는 네 단계와 한 대안 풀이를 갖는 난이도 3 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    diameter_rows = [(0, 0, 6, 8), (-2, 1, 4, 9), (3, -5, 9, 3), (-6, -2, 2, 4), (1, 7, 11, 1)]
    for index, (x1, y1, x2, y2) in enumerate(diameter_rows, 1):
        distance_square = (x2 - x1) ** 2 + (y2 - y1) ** 2
        answer = distance_square // 4
        specs.append(
            _problem(
                3,
                index,
                title=rf"두 점 $A({x1},{y1})$, $B({x2},{y2})$를 지름의 양 끝점으로 하는 원의 반지름의 제곱을 구하시오.",
                answer=str(answer),
                tags=["#원의표준형", "#두점사이의거리", "#거리공식"],
                steps=[
                    ("지름의 두 끝점 사이 가로 차를 구한다.", rf"$\Delta x={x2-x1}$이다."),
                    ("지름의 두 끝점 사이 세로 차를 구한다.", rf"$\Delta y={y2-y1}$이다."),
                    ("거리 공식으로 지름의 제곱을 계산한다.", rf"$AB^2=({x2-x1})^2+({y2-y1})^2={distance_square}$이다."),
                    ("반지름이 지름의 절반임을 적용한다.", rf"$r^2=AB^2/4={answer}$이다."),
                ],
                alternatives=["두 점의 중점을 원의 중심으로 구한 뒤 중심에서 한 끝점까지의 거리 제곱을 계산할 수 있다."],
            )
        )
    sequence_rows = [(3, 2, 12), (4, 2, 15), (-2, 4, 10), (5, 5, 8), (6, 3, 7)]
    for index, (first, difference, answer) in enumerate(sequence_rows, 6):
        total = answer * (2 * first + (answer - 1) * difference) // 2
        other_root = 1 - 2 * first // difference - answer
        specs.append(
            _problem(
                3,
                index,
                title=rf"첫째항이 ${first}$이고 공차가 ${difference}$인 등차수열에서 첫째항부터 제$n$항까지의 합이 ${total}$일 때, 자연수 $n$을 구하시오.",
                answer=str(answer),
                tags=["#등차수열", "#등차수열의합", "#이차방정식"],
                steps=[
                    ("등차수열의 합 공식을 세운다.", rf"$S_n=\dfrac{{n}}{{2}}(2({first})+(n-1)({difference}))$이다."),
                    ("주어진 합과 같게 놓아 이차방정식을 만든다.", rf"$\dfrac{{n}}{{2}}(2({first})+(n-1)({difference}))={total}$이다."),
                    ("이차방정식의 두 해를 구한다.", rf"방정식의 두 해는 $n={answer},{other_root}$이다."),
                    ("자연수 조건에 맞는 항수를 선택한다.", rf"${other_root}$은 자연수가 아니므로 $n={answer}$이다."),
                ],
                alternatives=[rf"일반항 $a_n={first}+(n-1)({difference})$을 먼저 구해 $S_n=n({first}+a_n)/2$에 대입할 수 있다."],
            )
        )
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 삼차함수 접선 조건과 정적분의 양의 상한이다. 작동 원리는 다섯 단계와 한 대안 풀이를 갖는 난이도 4 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    tangent_rows = [(2, 1, 3), (-1, 4, -2), (3, -5, 1), (-2, 2, 4), (1, -3, -5)]
    for index, (point, linear, answer) in enumerate(tangent_rows, 1):
        slope = 3 * point**2 + 2 * answer * point + linear
        specs.append(
            _problem(
                4,
                index,
                title=rf"삼차함수 $f(x)=x^3+ax^2+({linear})x+1$의 그래프에서 $x$좌표가 ${point}$인 점의 접선 기울기가 ${slope}$일 때, 상수 $a$를 구하시오.",
                answer=str(answer),
                tags=["#도함수", "#접선의기울기", "#접선의방정식", "#미정계수법"],
                steps=[
                    ("삼차함수를 미분해 도함수를 구한다.", rf"$f'(x)=3x^2+2ax+({linear})$이다."),
                    ("접선 기울기를 접점의 도함수값으로 나타낸다.", rf"$f'({point})={slope}$이다."),
                    ("접점 좌표를 도함수에 대입한다.", rf"${3*point**2}+({2*point})a+({linear})={slope}$이다."),
                    ("매개변수에 관한 일차방정식을 정리한다.", rf"$({2*point})a={slope-3*point**2-linear}$이다."),
                    ("일차방정식을 풀어 계수를 구한다.", rf"따라서 $a={answer}$이다."),
                ],
                alternatives=["접선 방정식의 x계수를 비교해도 접점에서의 미분계수 조건과 같은 식을 얻는다."],
            )
        )
    integral_rows = [(7, 2), (8, -3), (9, 4), (10, -5), (11, 1)]
    for index, (answer, constant) in enumerate(integral_rows, 6):
        value = answer**2 + constant * answer
        other_root = -constant - answer
        specs.append(
            _problem(
                4,
                index,
                title=rf"$a>0$이고 $\int_0^a(2x+({constant}))\,dx={value}$일 때, 상수 $a$를 구하시오.",
                answer=str(answer),
                tags=["#정적분", "#정적분의계산", "#정적분의선형성", "#미정계수법"],
                steps=[
                    ("피적분함수의 한 부정적분을 구한다.", rf"$\int(2x+({constant}))dx=x^2+({constant})x$이다."),
                    ("적분 구간의 양 끝값을 대입한다.", rf"정적분은 $a^2+({constant})a$이다."),
                    ("주어진 값과 같게 놓아 이차방정식을 만든다.", rf"$a^2+({constant})a={value}$이다."),
                    ("이차방정식의 두 해를 구한다.", rf"두 해는 $a={answer},{other_root}$이다."),
                    ("양수 조건에 맞는 해를 선택한다.", rf"$a>0$이므로 $a={answer}$이다."),
                ],
                alternatives=["직선형 피적분함수의 구간 평균값과 구간 길이의 곱으로 정적분을 계산할 수 있다."],
            )
        )
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 지수그래프의 밑과 연속 일차분수함수의 빠진 점·함숫값이다. 작동 원리는 여섯 단계와 두 대안 풀이를 갖는 난이도 5 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    for index, base in enumerate(range(2, 7), 1):
        rise = base**2 - 1
        length_square = 4 + rise**2
        specs.append(
            _problem(
                5,
                index,
                title=rf"지수함수 $y={base}^x$ 위의 두 점 $A(0,1)$, $B(2,{base**2})$에 대하여 A를 지나고 AB에 수직인 직선과 원점 사이 거리를 $d$라 할 때, $ABd$를 구하시오.",
                answer=str(rise),
                tags=["#지수함수의그래프", "#두점사이의거리", "#점과직선사이의거리", "#직선의방정식", "#기울기"],
                steps=[
                    ("두 점 사이 거리 AB를 구한다.", rf"$AB=\sqrt{{2^2+({rise})^2}}=\sqrt{{{length_square}}}$이다."),
                    ("선분 AB의 방향벡터를 구한다.", rf"AB의 방향벡터는 $(2,{rise})$이다."),
                    ("A를 지나고 AB에 수직인 직선의 방정식을 구한다.", rf"직선은 $2x+{rise}y-{rise}=0$이다."),
                    ("원점과 직선 사이 거리를 계산한다.", rf"$d={rise}/\sqrt{{{length_square}}}$이다."),
                    ("길이와 거리를 곱한다.", rf"$ABd=\sqrt{{{length_square}}}\cdot {rise}/\sqrt{{{length_square}}}$이다."),
                    ("공통 제곱근을 약분한다.", rf"따라서 $ABd={rise}$이다."),
                ],
                alternatives=[
                    "삼각형 OAB의 넓이를 밑변 AB와 높이 d의 곱으로 나타내어 계산할 수 있다.",
                    "두 벡터의 행렬식 절댓값을 이용하면 거리의 분모가 길이와 바로 약분된다.",
                ],
            )
        )
    continuity_rows = [(2, 5), (-2, 5), (3, -1), (-3, 4), (4, 2)]
    for index, (missing_point, function_value) in enumerate(continuity_rows, 6):
        coefficient_a = function_value - missing_point
        coefficient_b = -missing_point * function_value
        point_value = missing_point + function_value
        answer = coefficient_a**2 + coefficient_b**2 + point_value**2
        specs.append(
            _problem(
                5,
                index,
                title=rf"함수 $f(x)=\begin{{cases}}\dfrac{{x^2+ax+b}}{{x-({missing_point})}}&(x\ne {missing_point})\\c&(x={missing_point})\end{{cases}}$가 실수 전체에서 연속이고 $f(0)={function_value}$일 때, $a^2+b^2+c^2$을 구하시오.",
                answer=str(answer),
                tags=["#함수의극한", "#극한의성질", "#인수분해를이용한극한", "#미정계수법", "#함수의연속"],
                steps=[
                    ("주어진 함숫값으로 분자의 상수항을 구한다.", rf"$b={coefficient_b}$이다."),
                    ("분자가 빠진 점에서 0이 되는 조건을 세운다.", rf"${missing_point**2}+({missing_point})a+({coefficient_b})=0$이다."),
                    ("일차방정식을 풀어 나머지 계수를 구한다.", rf"$a={coefficient_a}$이다."),
                    ("분자를 분모가 포함되도록 인수분해한다.", rf"$x^2+({coefficient_a})x+({coefficient_b})=(x-({missing_point}))(x+({function_value}))$이다."),
                    ("연속 조건으로 빠진 점의 정의값을 구한다.", rf"$c={missing_point}+({function_value})={point_value}$이다."),
                    ("세 상수의 제곱합을 계산한다.", rf"$a^2+b^2+c^2={answer}$이다."),
                ],
                alternatives=[
                    "인수정리로 분자가 분모를 인수로 갖게 한 뒤 계수를 비교할 수 있다.",
                    "약분된 직선의 빠진 점을 채우는 그래프 관점으로 c를 구할 수 있다.",
                ],
            )
        )
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v13 직접 출제 명세를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v13 전체 카탈로그다. 작동 원리는 50문항을 생산 형식으로 조립하고 전수 검사한다."""
    return validate_problem_batch(build_catalog(), expected_count=50, batch_id=BATCH_ID, model_name=MODEL_NAME, codebase_base=CODEBASE_BASE, seed_base=SEED_BASE)


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v13 전체 생산분을 멱등 저장하고 재조회한다."""
    return seed_problem_batch(db_path, quests=validated_quests(), batch_id=BATCH_ID, validate_only=validate_only)


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 v13 전체 생산 결과를 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
