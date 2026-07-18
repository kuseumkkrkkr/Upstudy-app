from __future__ import annotations

import argparse
import json
import sys
from fractions import Fraction
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.marketplace_problem_batch import seed_problem_batch, validate_problem_batch
from scripts.seed_initial_math_problems import _problem


BATCH_ID = "marketplace-original-v4"
MODEL_NAME = "aiflow-direct-authoring-v4"
CODEBASE_BASE = 20_260_720_000
SEED_BASE = 202_607_200_000


def _polynomial_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 일차식의 계수와 대입값이다. 작동 원리는 동류항을 정리한 뒤 값을 구하는 난이도 1 문제 5개를 만든다."""
    rows = [
        (2, 3, 4, -1, 2),
        (-3, 5, 7, 2, -1),
        (5, -4, -2, 6, 3),
        (1, 8, 3, -5, 4),
        (-2, -3, -4, 7, -2),
    ]
    specs = []
    for index, (a, b, c, d, value) in enumerate(rows, 1):
        coefficient = a + c
        constant = b + d
        answer = coefficient * value + constant
        specs.append(
            _problem(
                1,
                index,
                title=rf"다항식 $({a}x+({b}))+({c}x+({d}))$에서 $x={value}$일 때의 값을 구하시오.",
                answer=str(answer),
                tags=["#다항식의연산"],
                steps=[
                    ("동류항끼리 모아 다항식을 정리한다.", rf"$({a}+({c}))x+({b}+({d}))={coefficient}x+({constant})$이다."),
                    ("주어진 x의 값을 대입해 계산한다.", rf"${coefficient}({value})+({constant})={answer}$이다."),
                ],
            )
        )
    return specs


def _arithmetic_term_specs() -> list[dict[str, Any]]:
    """필요 변수는 첫째항·공차·항 번호다. 작동 원리는 등차수열 일반항으로 특정 항을 구하는 난이도 1 문제 5개를 만든다."""
    rows = [(3, 2, 6), (-2, 3, 5), (7, -1, 4), (1, 4, 5), (5, 5, 4)]
    specs = []
    for index, (first, difference, n) in enumerate(rows, 6):
        answer = first + (n - 1) * difference
        specs.append(
            _problem(
                1,
                index,
                title=rf"첫째항이 ${first}$이고 공차가 ${difference}$인 등차수열의 제${n}$항을 구하시오.",
                answer=str(answer),
                tags=["#등차수열"],
                steps=[
                    ("등차수열의 일반항에 주어진 값을 대입한다.", rf"$a_{n}=a_1+({n}-1)d={first}+({n}-1)({difference})$이다."),
                    ("곱셈과 덧셈을 계산한다.", rf"따라서 $a_{n}={answer}$이다."),
                ],
            )
        )
    return specs


def _other_root_specs() -> list[dict[str, Any]]:
    """필요 변수는 이차방정식의 두 정수근이다. 작동 원리는 근과 계수의 관계로 다른 한 근을 찾는 난이도 2 문제 5개를 만든다."""
    rows = [(2, 5), (-3, 4), (1, -6), (3, 7), (-2, -5)]
    specs = []
    for index, (known_root, other_root) in enumerate(rows, 1):
        root_sum = known_root + other_root
        root_product = known_root * other_root
        specs.append(
            _problem(
                2,
                index,
                title=rf"이차방정식 $x^2-({root_sum})x+({root_product})=0$의 한 근이 ${known_root}$일 때, 다른 한 근을 구하시오.",
                answer=str(other_root),
                tags=["#근과계수의관계", "#이차방정식"],
                steps=[
                    ("두 근의 합을 근과 계수의 관계로 나타낸다.", rf"두 근의 합은 ${root_sum}$이다."),
                    ("다른 근을 beta라 두고 합의 식을 세운다.", rf"${known_root}+\beta={root_sum}$이다."),
                    ("일차방정식을 풀어 다른 근을 구한다.", rf"따라서 $\beta={root_sum}-({known_root})={other_root}$이다."),
                ],
            )
        )
    return specs


def _log_definition_specs() -> list[dict[str, Any]]:
    """필요 변수는 로그의 밑과 지수다. 작동 원리는 로그식을 지수식으로 바꾸어 진수를 구하는 난이도 2 문제 5개를 만든다."""
    rows = [(2, 5), (3, 4), (5, 3), (4, 3), (10, 2)]
    specs = []
    for index, (base, exponent) in enumerate(rows, 6):
        answer = base**exponent
        specs.append(
            _problem(
                2,
                index,
                title=rf"$\log_{base}x={exponent}$일 때, 양수 $x$의 값을 구하시오.",
                answer=str(answer),
                tags=["#로그의정의", "#지수법칙"],
                steps=[
                    ("로그의 정의를 이용해 지수식으로 바꾼다.", rf"$\log_{base}x={exponent}$은 $x={base}^{{{exponent}}}$와 같다."),
                    ("거듭제곱을 계산한다.", rf"${base}^{{{exponent}}}={answer}$이다."),
                    ("진수 조건과 함께 값을 확정한다.", rf"${answer}>0$이므로 진수 조건을 만족하며 $x={answer}$이다."),
                ],
            )
        )
    return specs


def _square_sum_specs() -> list[dict[str, Any]]:
    """필요 변수는 합의 마지막 자연수다. 작동 원리는 제곱합 공식을 적용하는 난이도 3 문제 5개를 만든다."""
    specs = []
    for index, n in enumerate(range(3, 8), 1):
        answer = n * (n + 1) * (2 * n + 1) // 6
        specs.append(
            _problem(
                3,
                index,
                title=rf"$\displaystyle\sum_{{k=1}}^{{{n}}}k^2$의 값을 구하시오.",
                answer=str(answer),
                tags=["#수열의표현", "#시그마공식", "#자연수의거듭제곱의합"],
                steps=[
                    ("자연수 제곱의 합 공식을 적는다.", r"$\sum_{k=1}^{n}k^2=\dfrac{n(n+1)(2n+1)}6$이다."),
                    ("합의 마지막 수를 공식에 대입한다.", rf"$\sum_{{k=1}}^{{{n}}}k^2=\dfrac{{{n}({n + 1})({2 * n + 1})}}6$이다."),
                    ("분자의 곱을 계산한다.", rf"분자는 ${n * (n + 1) * (2 * n + 1)}$이다."),
                    ("6으로 나누어 합을 구한다.", rf"따라서 합은 ${answer}$이다."),
                ],
                alternatives=[rf"$1^2$부터 ${n}^2$까지 직접 더해도 ${answer}$을 확인할 수 있다."],
            )
        )
    return specs


def _circle_radius_specs() -> list[dict[str, Any]]:
    """필요 변수는 원의 중심과 반지름이다. 작동 원리는 일반형을 완전제곱해 반지름을 구하는 난이도 3 문제 5개를 만든다."""
    rows = [(2, -1, 3), (-3, 2, 4), (1, 3, 2), (-2, -2, 5), (4, 1, 3)]
    specs = []
    for index, (center_x, center_y, radius) in enumerate(rows, 6):
        x_coefficient = -2 * center_x
        y_coefficient = -2 * center_y
        constant = center_x**2 + center_y**2 - radius**2
        specs.append(
            _problem(
                3,
                index,
                title=rf"원 $x^2+y^2+({x_coefficient})x+({y_coefficient})y+({constant})=0$의 반지름을 구하시오.",
                answer=str(radius),
                tags=["#원의일반형", "#일반형을표준형으로", "#원의표준형"],
                steps=[
                    ("x항과 y항을 각각 모으고 상수항을 이항한다.", rf"$x^2+({x_coefficient})x+y^2+({y_coefficient})y={-constant}$이다."),
                    ("두 이차식을 완전제곱한다.", rf"$(x-({center_x}))^2-{center_x**2}+(y-({center_y}))^2-{center_y**2}={-constant}$이다."),
                    ("상수항을 정리해 원의 표준형을 만든다.", rf"$(x-({center_x}))^2+(y-({center_y}))^2={radius**2}$이다."),
                    ("표준형의 우변에서 반지름을 읽는다.", rf"반지름은 $\sqrt{{{radius**2}}}={radius}$이다."),
                ],
                alternatives=[rf"일반형에서 중심 $({center_x},{center_y})$를 먼저 구한 뒤 중심을 대입해도 반지름 ${radius}$을 얻는다."],
            )
        )
    return specs


def _tangent_parameter_specs() -> list[dict[str, Any]]:
    """필요 변수는 접점의 x좌표·접선 기울기·상수항이다. 작동 원리는 도함수 조건으로 매개변수를 복원하는 난이도 4 문제 5개를 만든다."""
    rows = [(1, 5, 2), (2, 1, -3), (-1, 4, 5), (3, 10, 0), (-2, -1, 7)]
    specs = []
    for index, (point_x, slope, constant) in enumerate(rows, 1):
        answer = slope - 2 * point_x
        specs.append(
            _problem(
                4,
                index,
                title=rf"함수 $f(x)=x^2+ax+({constant})$의 그래프 위에서 $x={point_x}$인 점의 접선 기울기가 ${slope}$일 때, $a$를 구하시오.",
                answer=str(answer),
                tags=["#도함수", "#접선의기울기", "#접선의방정식", "#미정계수법"],
                steps=[
                    ("함수를 x에 관해 미분한다.", r"$f'(x)=2x+a$이다."),
                    ("접점의 x좌표를 도함수에 대입한다.", rf"$f'({point_x})=2({point_x})+a$이다."),
                    ("주어진 접선 기울기와 같게 놓는다.", rf"$2({point_x})+a={slope}$이다."),
                    ("일차방정식을 풀어 매개변수를 구한다.", rf"$a={slope}-2({point_x})={answer}$이다."),
                    ("도함수에 다시 대입해 기울기를 검산한다.", rf"$f'({point_x})=2({point_x})+({answer})={slope}$이므로 조건을 만족한다."),
                ],
                alternatives=[rf"이차함수의 두 점을 이용한 할선 기울기의 극한을 계산해도 $a={answer}$을 얻을 수 있다."],
            )
        )
    return specs


def _continuity_parameter_specs() -> list[dict[str, Any]]:
    """필요 변수는 양의 매개변수와 빠진 점의 함숫값이다. 작동 원리는 인수분해와 연속 조건으로 매개변수를 찾는 난이도 4 문제 5개를 만든다."""
    specs = []
    for index, answer in enumerate(range(1, 6), 6):
        point_value = 2 * answer
        specs.append(
            _problem(
                4,
                index,
                title=rf"상수 $a>0$에 대하여 함수 $f(x)=\begin{{cases}}\dfrac{{x^2-a^2}}{{x-a}}&(x\ne a)\\{point_value}&(x=a)\end{{cases}}$가 실수 전체에서 연속일 때, $a$를 구하시오.",
                answer=str(answer),
                tags=["#함수의극한", "#함수의연속", "#미정계수법", "#인수분해를이용한극한"],
                steps=[
                    ("분자를 합차 공식으로 인수분해한다.", r"$x^2-a^2=(x-a)(x+a)$이다."),
                    ("x가 a가 아닐 때 공통 인수를 약분한다.", r"$f(x)=x+a$이다."),
                    ("x가 a로 갈 때의 극한을 계산한다.", r"$\lim_{x\to a}f(x)=a+a=2a$이다."),
                    ("연속 조건으로 극한과 함숫값을 같게 놓는다.", rf"$2a=f(a)={point_value}$이다."),
                    ("양수 조건 아래 매개변수를 결정한다.", rf"따라서 $a={answer}$이다."),
                ],
                alternatives=[rf"약분 후 직선 $y=x+a$의 빠진 점을 $({answer},{point_value})$로 채우는 관점에서도 $a={answer}$이다."],
            )
        )
    return specs


def _log_equation_specs() -> list[dict[str, Any]]:
    """필요 변수는 로그의 밑·고정근·매개변수근이다. 작동 원리는 치환한 이차방정식과 원래 두 근의 곱으로 매개변수를 찾는 난이도 5 문제 5개를 만든다."""
    rows = [(2, 1, 3), (2, 2, 5), (3, 1, 3), (3, 2, 4), (5, 1, 2)]
    specs = []
    for index, (base, fixed_root, answer) in enumerate(rows, 1):
        product = base ** (fixed_root + answer)
        specs.append(
            _problem(
                5,
                index,
                title=rf"실수 $m>{fixed_root}$에 대하여 방정식 $(\log_{base}x)^2-(m+{fixed_root})\log_{base}x+{fixed_root}m=0$의 서로 다른 두 양의 실근을 $\alpha,\beta$라 하자. $\alpha\beta={product}$일 때, $m$을 구하시오.",
                answer=str(answer),
                tags=["#로그방정식", "#진수조건", "#로그법칙", "#근과계수의관계", "#지수방정식"],
                steps=[
                    ("로그방정식의 진수 조건을 확인한다.", r"로그의 진수이므로 모든 해는 $x>0$이어야 한다."),
                    (r"$t=\log_bx$ 꼴로 치환한다.", rf"$t=\log_{base}x$로 두면 $t^2-(m+{fixed_root})t+{fixed_root}m=0$이다."),
                    ("치환 방정식을 인수분해해 두 로그값을 구한다.", rf"$(t-{fixed_root})(t-m)=0$이므로 $t={fixed_root},m$이다."),
                    ("원래 두 양의 근의 곱을 지수로 나타낸다.", rf"$\alpha\beta={base}^{{{fixed_root}}}\cdot{base}^m={base}^{{m+{fixed_root}}}$이다."),
                    ("주어진 곱과 밑이 같은 지수끼리 비교한다.", rf"${base}^{{m+{fixed_root}}}={product}={base}^{{{fixed_root + answer}}}$이므로 $m+{fixed_root}={fixed_root + answer}$이다."),
                    ("매개변수를 구하고 두 근의 구별 조건을 확인한다.", rf"$m={answer}>{fixed_root}$이므로 두 로그값과 두 양의 근은 서로 다르다."),
                ],
                alternatives=[
                    rf"치환 방정식의 두 근의 합이 $m+{fixed_root}$이므로 원래 두 근의 곱은 바로 ${base}^{{m+{fixed_root}}}$이다.",
                    rf"$t={fixed_root}$을 대입해 한 근임을 확인한 뒤 근과 계수의 관계로 다른 근 $m$을 구할 수 있다.",
                ],
            )
        )
    return specs


def _circle_tangent_specs() -> list[dict[str, Any]]:
    """필요 변수는 원의 중심·반지름·요구 배수다. 작동 원리는 원점에서 그은 두 접선의 기울기 합을 거리 조건으로 구하는 난이도 5 문제 5개를 만든다."""
    rows = [(3, 1, 1, 4), (2, 2, 1, 3), (4, -1, 1, -15), (3, -2, 2, -5), (5, 2, 2, 21)]
    specs = []
    for index, (center_x, center_y, radius, multiplier) in enumerate(rows, 6):
        denominator = center_x**2 - radius**2
        slope_sum = Fraction(2 * center_x * center_y, denominator)
        answer = int(multiplier * slope_sum)
        slope_sum_text = (
            str(slope_sum.numerator)
            if slope_sum.denominator == 1
            else rf"\frac{{{slope_sum.numerator}}}{{{slope_sum.denominator}}}"
        )
        specs.append(
            _problem(
                5,
                index,
                title=rf"원 $(x-({center_x}))^2+(y-({center_y}))^2={radius**2}$에 접하고 원점을 지나는 두 직선의 기울기를 $m_1,m_2$라 할 때, $({multiplier})(m_1+m_2)$의 값을 구하시오.",
                answer=str(answer),
                tags=["#원의방정식", "#직선의방정식", "#점과직선사이의거리", "#이차방정식", "#기울기"],
                steps=[
                    ("원점을 지나는 직선을 기울기로 나타낸다.", r"직선은 $y=mx$, 즉 $mx-y=0$이다."),
                    ("원의 중심과 반지름을 확인한다.", rf"중심은 $({center_x},{center_y})$이고 반지름은 ${radius}$이다."),
                    ("중심에서 직선까지의 거리를 접선 조건과 같게 놓는다.", rf"$\dfrac{{|{center_x}m-({center_y})|}}{{\sqrt{{m^2+1}}}}={radius}$이다."),
                    ("양변을 제곱하고 기울기에 대한 이차방정식을 만든다.", rf"$({denominator})m^2+({-2 * center_x * center_y})m+({center_y**2 - radius**2})=0$이다."),
                    ("근과 계수의 관계로 두 기울기의 합을 구한다.", rf"$m_1+m_2=\dfrac{{2({center_x})({center_y})}}{{{denominator}}}={slope_sum_text}$이다."),
                    ("문제에서 요구한 배수를 계산한다.", rf"$({multiplier})(m_1+m_2)=({multiplier})\left({slope_sum_text}\right)={answer}$이다."),
                ],
                alternatives=[
                    "원점과 원의 중심을 이은 선분으로 이루어진 두 직각삼각형을 이용해 접선의 방향을 구할 수 있다.",
                    rf"기울기 이차방정식에서 두 근을 직접 구하지 않고 합만 사용하면 요구값 ${answer}$을 빠르게 얻는다.",
                ],
            )
        )
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도 1~5별 10문항씩 총 50개의 네 번째 직접 출제 명세를 반환하는 것이다."""
    return [
        *_polynomial_specs(),
        *_arithmetic_term_specs(),
        *_other_root_specs(),
        *_log_definition_specs(),
        *_square_sum_specs(),
        *_circle_radius_specs(),
        *_tangent_parameter_specs(),
        *_continuity_parameter_specs(),
        *_log_equation_specs(),
        *_circle_tangent_specs(),
    ]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v4 카탈로그와 배치 기준값이다. 작동 원리는 50문항을 생산 형식으로 조립하고 전수 품질 검사를 수행하는 것이다."""
    return validate_problem_batch(
        build_catalog(),
        expected_count=50,
        batch_id=BATCH_ID,
        model_name=MODEL_NAME,
        codebase_base=CODEBASE_BASE,
        seed_base=SEED_BASE,
    )


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 대상 DB와 검증 모드다. 작동 원리는 검증된 v4 문제를 로컬 DB에 멱등 저장하고 재조회한다."""
    return seed_problem_batch(
        db_path,
        quests=validated_quests(),
        batch_id=BATCH_ID,
        validate_only=validate_only,
    )


def main() -> None:
    """필요 변수는 DB 경로와 검증 옵션이다. 작동 원리는 난이도별 v4 직접 출제 결과를 UTF-8 JSON으로 출력하는 것이다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
