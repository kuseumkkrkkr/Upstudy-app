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

BATCH_ID = "marketplace-original-v10"
MODEL_NAME = "aiflow-direct-authoring-v10"
CODEBASE_BASE = 20_260_726_000
SEED_BASE = 202_607_260_000


def _latex_fraction(value: Fraction) -> str:
    """필요 변수는 유리수 값이다. 작동 원리는 정수 또는 LaTeX 분수로 UTF-8 문제 본문에 표시한다."""
    if value.denominator == 1:
        return str(value.numerator)
    return rf"\dfrac{{{value.numerator}}}{{{value.denominator}}}"


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 허수 단위의 지수와 등차수열 수치다. 작동 원리는 두 단계 계산형 난이도 1 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    power_answers = {0: "1", 1: "i", 2: "-1", 3: "-i"}
    for index, exponent in enumerate([46, 49, 54, 59, 66], 1):
        remainder = exponent % 4
        answer = power_answers[remainder]
        specs.append(
            _problem(
                1,
                index,
                title=rf"허수 단위 $i$에 대하여 $i^{{{exponent}}}$의 값을 구하시오.",
                answer=answer,
                tags=["#허수단위"],
                steps=[
                    ("지수를 4로 나눈 나머지를 구한다.", rf"${exponent}=4\cdot{exponent // 4}+{remainder}$이다."),
                    ("허수 단위의 거듭제곱 주기를 적용한다.", rf"$i^{{{exponent}}}=i^{remainder}={answer}$이다."),
                ],
            )
        )
    sequence_rows = [(4, 3, 12), (-5, 4, 9), (10, -2, 8), (3, 5, 11), (-7, 6, 7)]
    for index, (first, difference, term) in enumerate(sequence_rows, 6):
        answer = first + (term - 1) * difference
        specs.append(
            _problem(
                1,
                index,
                title=rf"첫째항이 ${first}$이고 공차가 ${difference}$인 등차수열의 제${term}항을 구하시오.",
                answer=str(answer),
                tags=["#등차수열"],
                steps=[
                    ("등차수열의 일반항 공식을 세운다.", rf"$a_{{{term}}}={first}+({term}-1)\cdot({difference})$이다."),
                    ("곱셈과 덧셈을 계산한다.", rf"따라서 $a_{{{term}}}={answer}$이다."),
                ],
            )
        )
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 다항식의 계수·나머지와 등비수열 항이다. 작동 원리는 세 단계 개념 적용형 난이도 2 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    remainder_rows = [(2, -1, 3, 4), (-1, 2, 5, -3), (3, -2, -4, 2), (-2, 1, 7, 5), (4, -3, 2, -2)]
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
                    ("나머지정리를 적용해 함숫값 조건을 만든다.", rf"$P({root})={remainder}$이다."),
                    ("주어진 값을 다항식에 대입한다.", rf"$P({root})={fixed_part}+({root})a={remainder}$이다."),
                    ("일차방정식을 풀어 계수를 구한다.", rf"따라서 $a={answer}$이다."),
                ],
            )
        )
    geometric_rows = [(2, 3), (5, 2), (3, 4), (7, 2), (4, 3)]
    for index, (second, ratio) in enumerate(geometric_rows, 6):
        fifth = second * ratio**3
        answer = second * ratio**2
        specs.append(
            _problem(
                2,
                index,
                title=rf"모든 항이 양수인 등비수열 $\{{a_n\}}$에서 $a_2={second}$, $a_5={fifth}$일 때, $a_4$를 구하시오.",
                answer=str(answer),
                tags=["#등비수열", "#등비수열의일반항"],
                steps=[
                    ("두 항의 비로 공비의 세제곱을 구한다.", rf"$a_5/a_2=r^3={ratio**3}$이다."),
                    ("모든 항이 양수라는 조건으로 공비를 정한다.", rf"양의 공비는 $r={ratio}$이다."),
                    ("둘째항에서 공비를 두 번 곱한다.", rf"$a_4=a_2r^2={second}\cdot{ratio**2}={answer}$이다."),
                ],
            )
        )
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 지수함수 교점과 이차함수 이동 수치다. 작동 원리는 네 단계와 한 대안 풀이를 갖는 난이도 3 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    intersection_rows = [(2, 0, 2, 2), (3, 1, 2, 1), (2, -1, 3, 1), (5, 2, 2, 0), (3, 0, 3, 2)]
    for index, (base, offset, multiplier, shift) in enumerate(intersection_rows, 1):
        point_x = (offset + multiplier * shift) // (multiplier - 1)
        log_y = point_x + offset
        answer = point_x + log_y
        specs.append(
            _problem(
                3,
                index,
                title=rf"두 그래프 $y={base}^{{x+({offset})}}$, $y=({base}^{multiplier})^{{x-({shift})}}$의 교점을 $(p,q)$라 할 때, $p+\log_{base}q$를 구하시오.",
                answer=str(answer),
                tags=["#지수함수의그래프", "#지수방정식", "#지수법칙"],
                steps=[
                    ("교점에서 두 지수함수의 값이 같다는 식을 세운다.", rf"${base}^{{p+({offset})}}=({base}^{multiplier})^{{p-({shift})}}$이다."),
                    ("양변의 밑을 같게 바꾸어 지수를 비교한다.", rf"$p+({offset})={multiplier}(p-({shift}))$이다."),
                    ("교점의 가로좌표와 세로좌표의 로그를 구한다.", rf"$p={point_x}$이고 $\log_{base}q=p+({offset})={log_y}$이다."),
                    ("문제에서 요구한 두 값을 더한다.", rf"$p+\log_{base}q={point_x}+({log_y})={answer}$이다."),
                ],
                alternatives=["양변에 같은 밑의 로그를 취하면 지수 비교식과 동일한 일차방정식을 바로 얻을 수 있다."],
            )
        )
    vertex_rows = [(3, 2, 1), (-2, 3, 2), (5, -1, -2), (4, 5, 3), (-3, 2, -1)]
    for index, (vertex_x, vertex_y, input_shift) in enumerate(vertex_rows, 6):
        constant = vertex_x**2 + vertex_y
        moved_x = vertex_x - input_shift
        answer = moved_x + vertex_y
        specs.append(
            _problem(
                3,
                index,
                title=rf"함수 $f(x)=x^2+({-2*vertex_x})x+({constant})$와 $g(x)=f(x+({input_shift}))$에 대하여, $g$의 꼭짓점을 $(a,b)$라 할 때 $a+b$를 구하시오.",
                answer=str(answer),
                tags=["#합성함수", "#이차함수의평행이동", "#최솟값"],
                steps=[
                    ("원래 이차함수를 완전제곱식으로 바꾼다.", rf"$f(x)=(x-({vertex_x}))^2+({vertex_y})$이다."),
                    ("입력값을 바꾸어 새 함수식을 구한다.", rf"$g(x)=(x+({input_shift})-({vertex_x}))^2+({vertex_y})$이다."),
                    ("표준형에서 이동한 꼭짓점을 읽는다.", rf"$(a,b)=({moved_x},{vertex_y})$이다."),
                    ("꼭짓점의 두 좌표를 더한다.", rf"따라서 $a+b={moved_x}+({vertex_y})={answer}$이다."),
                ],
                alternatives=[rf"$f(x+({input_shift}))$는 원래 그래프를 가로로 ${-input_shift}$만큼 평행이동한 것으로 해석할 수 있다."],
            )
        )
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 정적분의 매개변수와 이차함수 최솟값 조건이다. 작동 원리는 다섯 단계와 한 대안 풀이를 갖는 난이도 4 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    integral_rows = [(2, 2, 1), (3, -1, 2), (4, 3, -1), (2, -2, 3), (3, 2, -2)]
    for index, (upper, parameter, constant) in enumerate(integral_rows, 1):
        given = Fraction(upper**3, 3) + Fraction(parameter * upper**2, 2) + constant * upper
        answer = 2 + 3 * parameter + 6 * constant
        specs.append(
            _problem(
                4,
                index,
                title=rf"함수 $F(x)=\int_0^x(t^2+at+({constant}))\,dt$가 $F({upper})={_latex_fraction(given)}$을 만족할 때, $6F(1)$을 구하시오.",
                answer=str(answer),
                tags=["#정적분", "#미적분의기본정리", "#미정계수법", "#정적분의선형성"],
                steps=[
                    ("매개변수를 포함한 정적분을 계산한다.", r"$F(x)=\dfrac{x^3}{3}+\dfrac{ax^2}{2}+cx$ 꼴이고 여기서 $c$는 주어진 상수항이다."),
                    ("주어진 함숫값 조건을 대입한다.", rf"$F({upper})={Fraction(upper**3, 3)}+({Fraction(upper**2, 2)})a+({constant*upper})={_latex_fraction(given)}$이다."),
                    ("일차방정식을 풀어 매개변수를 정한다.", rf"계산하면 $a={parameter}$이다."),
                    ("정해진 매개변수로 첫 구간의 적분값을 구한다.", rf"$F(1)=\dfrac13+\dfrac{{{parameter}}}2+({constant})$이다."),
                    ("요구한 배수를 계산한다.", rf"$6F(1)=2+3({parameter})+6({constant})={answer}$이다."),
                ],
                alternatives=["미적분의 기본정리로 도함수를 먼저 확인한 뒤 원시함수와 $F(0)=0$을 이용해도 같은 식을 얻는다."],
            )
        )
    minimum_rows = [(4, 1, 2), (5, -1, 4), (3, 2, -1), (6, 1, 5), (7, -2, 3)]
    for index, (parameter, linear, constant) in enumerate(minimum_rows, 6):
        minimum = -parameter**2 + linear * parameter + constant
        answer = 3 * parameter
        other_parameter = linear - parameter
        specs.append(
            _problem(
                4,
                index,
                title=rf"$a>0$이고 이차함수 $f(x)=x^2-2ax+({linear})a+({constant})$의 최솟값이 ${minimum}$이다. 그래프의 두 $x$절편의 합과 $a$의 합을 구하시오.",
                answer=str(answer),
                tags=["#이차함수의최대최소", "#꼭짓점", "#근과계수의관계", "#이차방정식"],
                steps=[
                    ("완전제곱으로 함수의 최솟값을 나타낸다.", rf"$f(x)=(x-a)^2-a^2+({linear})a+({constant})$이다."),
                    ("주어진 최솟값과 같게 놓아 매개변수 방정식을 만든다.", rf"$-a^2+({linear})a+({constant})={minimum}$이다."),
                    ("양수 조건에 맞는 매개변수를 고른다.", rf"두 후보는 ${parameter}$와 ${other_parameter}$이고 $a>0$이므로 $a={parameter}$이다."),
                    ("두 절편의 합을 근과 계수의 관계로 구한다.", rf"$x^2-2({parameter})x+\cdots=0$이므로 두 근의 합은 ${2*parameter}$이다."),
                    ("두 근의 합과 매개변수를 더한다.", rf"${2*parameter}+{parameter}={answer}$이다."),
                ],
                alternatives=["꼭짓점의 가로좌표가 $a$라는 사실을 이용해 최솟값을 $f(a)$로 바로 계산할 수 있다."],
            )
        )
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 로그방정식의 구간과 원의 중심·외부점이다. 작동 원리는 여섯 단계와 두 대안 풀이를 갖는 난이도 5 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    logarithm_rows = [(2, 2, 1, 8), (3, 1, -2, 6), (2, 3, 0, 10), (5, 1, 2, 12), (3, 2, -1, 12)]
    for index, (base, exponent, left, right) in enumerate(logarithm_rows, 1):
        power = base**exponent
        root_sum = left + right
        answer = left * right + power
        discriminant = (right - left) ** 2 - 4 * power
        specs.append(
            _problem(
                5,
                index,
                title=rf"로그방정식 $\log_{base}(x-({left}))+\log_{base}({right}-x)={exponent}$의 모든 실근의 곱을 구하시오.",
                answer=str(answer),
                tags=["#로그방정식", "#진수조건", "#로그법칙", "#근과계수의관계", "#지수방정식"],
                steps=[
                    ("두 로그의 진수 조건을 함께 구한다.", rf"${left}<x<{right}$이어야 한다."),
                    ("로그의 합을 곱의 로그로 합친다.", rf"$\log_{base}((x-({left}))({right}-x))={exponent}$이다."),
                    ("로그의 정의로 대수방정식을 만든다.", rf"$(x-({left}))({right}-x)={base}^{exponent}={power}$이다."),
                    ("식을 이차방정식의 표준형으로 정리한다.", rf"$x^2-({root_sum})x+({answer})=0$이다."),
                    ("판별식과 진수 조건으로 두 실근을 확인한다.", rf"판별식은 ${discriminant}>0$이고 두 근은 모두 ${left}<x<{right}$에 있다."),
                    ("근과 계수의 관계로 모든 실근의 곱을 구한다.", rf"따라서 두 실근의 곱은 ${answer}$이다."),
                ],
                alternatives=[
                    "두 진수의 곱을 구간 중점에 관해 완전제곱하면 두 실근의 존재와 대칭성을 함께 확인할 수 있다.",
                    "이차방정식의 두 근을 직접 계산하지 않고 상수항과 최고차항 계수의 비로 곱만 구할 수 있다.",
                ],
            )
        )
    tangent_rows = [(1, 4, 3, 1), (-1, 3, -2, 1), (2, -2, 3, 2), (-2, 3, 4, 2), (3, -2, -3, 2)]
    for index, (point_x, center_x, center_y, radius) in enumerate(tangent_rows, 6):
        relative_x = center_x - point_x
        slope_coefficient = relative_x**2 - radius**2
        answer = 2 * relative_x * center_y
        specs.append(
            _problem(
                5,
                index,
                title=rf"점 $P({point_x},0)$을 지나고 원 $(x-({center_x}))^2+(y-({center_y}))^2={radius**2}$에 접하는 두 직선의 기울기를 $m_1,m_2$라 할 때, ${slope_coefficient}(m_1+m_2)$를 구하시오.",
                answer=str(answer),
                tags=["#원의방정식", "#직선의방정식", "#점과직선사이의거리", "#이차방정식", "#기울기"],
                steps=[
                    ("점 P를 지나는 직선을 기울기로 나타낸다.", rf"직선은 $y=m(x-({point_x}))$이다."),
                    ("직선의 일반형과 원의 중심을 확인한다.", rf"일반형은 $mx-y-({point_x})m=0$이고 중심은 $({center_x},{center_y})$이다."),
                    ("중심에서 직선까지의 거리를 나타낸다.", rf"거리는 $\dfrac{{|{relative_x}m-({center_y})|}}{{\sqrt{{m^2+1}}}}$이다."),
                    ("접선 조건으로 기울기의 이차방정식을 만든다.", rf"${slope_coefficient}m^2+({-2*relative_x*center_y})m+({center_y**2-radius**2})=0$이다."),
                    ("근과 계수의 관계로 두 기울기의 합을 구한다.", rf"$m_1+m_2=\dfrac{{{answer}}}{{{slope_coefficient}}}$이다."),
                    ("문제에서 요구한 계수를 곱한다.", rf"${slope_coefficient}(m_1+m_2)={answer}$이다."),
                ],
                alternatives=[
                    "점을 원점으로 옮기는 평행이동을 하면 원의 중심 가로좌표만 상대좌표로 바뀌어 같은 거리식을 얻는다.",
                    "기울기 이차방정식의 두 해를 구하지 않고 이차항과 일차항 계수만으로 합을 계산할 수 있다.",
                ],
            )
        )
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v10 직접 출제 명세를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v10 전체 카탈로그다. 작동 원리는 50문항을 생산 형식으로 조립하고 전수 검사한다."""
    return validate_problem_batch(
        build_catalog(),
        expected_count=50,
        batch_id=BATCH_ID,
        model_name=MODEL_NAME,
        codebase_base=CODEBASE_BASE,
        seed_base=SEED_BASE,
    )


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v10 전체 생산분을 멱등 저장하고 재조회한다."""
    return seed_problem_batch(
        db_path,
        quests=validated_quests(),
        batch_id=BATCH_ID,
        validate_only=validate_only,
    )


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 v10 전체 생산 결과를 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
