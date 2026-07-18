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

BATCH_ID = "marketplace-original-v14"
MODEL_NAME = "aiflow-direct-authoring-v14"
CODEBASE_BASE = 20_260_730_000
SEED_BASE = 202_607_300_000


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 이차다항식의 계수·나눗셈 근과 두 행렬의 대각 성분이다. 작동 원리는 두 단계 계산형 난이도 1 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    remainder_rows = [(3, 4, -2), (-2, 5, 7), (4, -3, 6), (-3, -2, 8), (5, 1, -9)]
    for index, (root, coefficient, constant) in enumerate(remainder_rows, 1):
        answer = root**2 + coefficient * root + constant
        specs.append(
            _problem(
                1,
                index,
                title=rf"다항식 $P(x)=x^2+({coefficient})x+({constant})$을 $x-({root})$로 나눈 나머지를 구하시오.",
                answer=str(answer),
                tags=["#나머지정리"],
                steps=[
                    ("나머지정리로 나머지를 함숫값으로 바꾼다.", rf"구하는 나머지는 $P({root})$이다."),
                    ("다항식에 근을 대입해 계산한다.", rf"$P({root})=({root})^2+({coefficient})({root})+({constant})={answer}$이다."),
                ],
            )
        )
    matrix_rows = [(2, 5, 3, -1), (-4, 7, 6, 2), (8, -3, -5, 4), (1, 9, 7, -6), (-2, -8, 5, 10)]
    for index, (a11, a22, b11, b22) in enumerate(matrix_rows, 6):
        first_diagonal = a11 + b11
        second_diagonal = a22 + b22
        answer = first_diagonal + second_diagonal
        specs.append(
            _problem(
                1,
                index,
                title=rf"행렬 $A=\begin{{pmatrix}}{a11}&1\\2&{a22}\end{{pmatrix}}$, $B=\begin{{pmatrix}}{b11}&-1\\3&{b22}\end{{pmatrix}}$에 대하여 행렬 $A+B$의 대각합을 구하시오.",
                answer=str(answer),
                tags=["#행렬의덧셈"],
                steps=[
                    ("두 대각 위치의 대응 성분끼리 더한다.", rf"대각 성분은 ${a11}+({b11})={first_diagonal}$, ${a22}+({b22})={second_diagonal}$이다."),
                    ("구한 두 대각 성분을 더한다.", rf"대각합은 ${first_diagonal}+({second_diagonal})={answer}$이다."),
                ],
            )
        )
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 지수방정식의 밑·지수 이동량과 이차방정식의 두 근이다. 작동 원리는 세 단계 개념 적용형 난이도 2 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    exponent_rows = [(2, -3, 8), (3, 4, 10), (5, -2, 5), (4, 3, 9), (7, -1, 4)]
    for index, (base, shift, exponent) in enumerate(exponent_rows, 1):
        answer = exponent - shift
        specs.append(
            _problem(
                2,
                index,
                title=rf"두 지수의 밑이 같은 방정식 ${base}^{{x+({shift})}}={base}^{exponent}$을 만족하는 실수 $x$를 구하시오.",
                answer=str(answer),
                tags=["#지수방정식", "#지수법칙"],
                steps=[
                    ("양변이 같은 밑의 거듭제곱임을 확인한다.", rf"밑 ${base}$는 양수이고 $1$이 아니다."),
                    ("지수함수의 일대일성을 이용해 지수를 같게 놓는다.", rf"$x+({shift})={exponent}$이다."),
                    ("일차방정식을 풀어 지수를 구한다.", rf"따라서 $x={answer}$이다."),
                ],
            )
        )
    root_rows = [(13, 5), (15, -2), (-7, 3), (18, 7), (-9, -4)]
    for index, (root_sum, known_root) in enumerate(root_rows, 6):
        answer = root_sum - known_root
        product = known_root * answer
        specs.append(
            _problem(
                2,
                index,
                title=rf"이차방정식 $x^2-({root_sum})x+({product})=0$의 한 근이 ${known_root}$일 때, 다른 한 근을 구하시오.",
                answer=str(answer),
                tags=["#근과계수의관계", "#이차방정식"],
                steps=[
                    ("두 근의 합을 근과 계수의 관계로 구한다.", rf"두 근의 합은 ${root_sum}$이다."),
                    ("알려진 한 근과 다른 근의 합을 세운다.", rf"${known_root}+\beta={root_sum}$이다."),
                    ("일차방정식을 풀어 다른 근을 구한다.", rf"따라서 다른 근은 ${answer}$이다."),
                ],
            )
        )
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 삼차다항식의 세 근과 제거가능 불연속 함수의 빠진 점이다. 작동 원리는 네 단계와 한 대안 풀이를 갖는 난이도 3 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    cubic_rows = [(1, 2, 5), (2, 3, 6), (-1, 2, 4), (-2, 3, 5), (1, 4, 7)]
    for index, (r1, r2, r3) in enumerate(cubic_rows, 1):
        coefficient_a = -(r1 + r2 + r3)
        coefficient_b = r1 * r2 + r2 * r3 + r3 * r1
        constant = -(r1 * r2 * r3)
        answer = coefficient_a - coefficient_b
        specs.append(
            _problem(
                3,
                index,
                title=rf"최고차항의 계수가 $1$인 삼차다항식 $P(x)=x^3+ax^2+bx+({constant})$의 세 영점이 ${r1},{r2},{r3}$일 때, $a-b$를 구하시오.",
                answer=str(answer),
                tags=["#인수정리", "#근과계수의관계", "#고차식인수분해"],
                steps=[
                    ("세 영점으로 다항식의 인수 형태를 만든다.", rf"$P(x)=(x-({r1}))(x-({r2}))(x-({r3}))$이다."),
                    ("세 근의 합으로 이차항의 계수를 구한다.", rf"$a=-({r1}+({r2})+({r3}))={coefficient_a}$이다."),
                    ("두 근씩 곱한 합으로 일차항의 계수를 구한다.", rf"$b={r1}({r2})+{r2}({r3})+{r3}({r1})={coefficient_b}$이다."),
                    ("두 계수의 차를 계산한다.", rf"$a-b={coefficient_a}-({coefficient_b})={answer}$이다."),
                ],
                alternatives=["세 일차인수의 곱을 직접 전개한 뒤 이차항과 일차항의 계수를 비교할 수 있다."],
            )
        )
    continuity_rows = [(2, 4), (-2, 5), (3, -1), (-3, 2), (4, 3)]
    for index, (missing_point, shift) in enumerate(continuity_rows, 6):
        linear = shift - missing_point
        constant = -missing_point * shift
        point_value = missing_point + shift
        answer = 2 * missing_point + shift
        specs.append(
            _problem(
                3,
                index,
                title=rf"함수 $f(x)=\begin{{cases}}\dfrac{{x^2+({linear})x+({constant})}}{{x-({missing_point})}}&(x\ne {missing_point})\\c&(x={missing_point})\end{{cases}}$가 실수 전체에서 연속이고 $g(x)=f(x)+x$일 때, $g({missing_point})$를 구하시오.",
                answer=str(answer),
                tags=["#함수의극한", "#함수의연속", "#인수분해를이용한극한"],
                steps=[
                    ("분자를 분모가 포함되도록 인수분해한다.", rf"분자는 $(x-({missing_point}))(x+({shift}))$이다."),
                    ("분모를 약분해 빠진 점 근처의 함수식을 구한다.", rf"$x\ne{missing_point}$에서 $f(x)=x+({shift})$이다."),
                    ("연속 조건으로 빠진 점의 정의값을 정한다.", rf"$c={missing_point}+({shift})={point_value}$이다."),
                    ("새 함수의 빠진 점 함숫값을 계산한다.", rf"$g({missing_point})=f({missing_point})+({missing_point})={answer}$이다."),
                ],
                alternatives=["약분된 직선의 그래프에서 빠진 점을 채운 뒤 $y=x$의 함숫값을 더해도 같은 값을 얻는다."],
            )
        )
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 등비수열의 지수 양 끝값과 포물선·수평선의 교점 수치다. 작동 원리는 다섯 단계와 한 대안 풀이를 갖는 난이도 4 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    sequence_rows = [(2, 1, 9), (3, 2, 10), (5, 3, 7), (7, 0, 8), (2, 4, 12)]
    for index, (base, first_exponent, fifth_exponent) in enumerate(sequence_rows, 1):
        difference = (fifth_exponent - first_exponent) // 4
        answer = 5 * (first_exponent + fifth_exponent) // 2
        specs.append(
            _problem(
                4,
                index,
                title=rf"양의 등비수열 $\{{a_n\}}$에서 $a_1={base}^{first_exponent}$, $a_5={base}^{fifth_exponent}$이고 $b_n=\log_{base}a_n$일 때, $\sum_{{k=1}}^5b_k$를 구하시오.",
                answer=str(answer),
                tags=["#등비수열", "#로그법칙", "#등차수열", "#등차수열의합"],
                steps=[
                    ("첫째항과 다섯째항의 비로 공비를 구한다.", rf"$r^4={base}^{{{fifth_exponent-first_exponent}}}$이므로 $r={base}^{difference}$이다."),
                    ("등비수열의 일반항을 같은 밑의 거듭제곱으로 쓴다.", rf"$a_n={base}^{{{first_exponent}+{difference}(n-1)}}$이다."),
                    ("로그를 취해 새 수열의 일반항을 구한다.", rf"$b_n={first_exponent}+{difference}(n-1)$이다."),
                    ("새 등차수열의 양 끝항을 확인한다.", rf"$b_1={first_exponent}$, $b_5={fifth_exponent}$이다."),
                    ("등차수열의 합 공식을 계산한다.", rf"$\sum_{{k=1}}^5b_k=\dfrac{{5({first_exponent}+{fifth_exponent})}}2={answer}$이다."),
                ],
                alternatives=["로그가 곱을 합으로 바꾸므로 새 수열의 공차가 공비의 로그임을 바로 이용할 수 있다."],
            )
        )
    for index, scale in enumerate(range(4, 9), 6):
        answer = scale**3
        specs.append(
            _problem(
                4,
                index,
                title=rf"포물선 $y=x^2$과 직선 $y={scale**2}$로 둘러싸인 넓이를 $S$라 할 때, $\dfrac{{3S}}4$의 값을 구하시오.",
                answer=str(answer),
                tags=["#정적분", "#두곡선사이의넓이", "#이차함수", "#정적분의계산"],
                steps=[
                    ("두 그래프의 교점 방정식을 푼다.", rf"$x^2={scale**2}$이므로 교점의 x좌표는 $-{scale},{scale}$이다."),
                    ("두 교점 사이에서 위아래 함수를 확인한다.", rf"구간 $[-{scale},{scale}]$에서 직선이 포물선보다 위에 있다."),
                    ("두 함수의 차를 정적분으로 나타낸다.", rf"$S=\int_{{-{scale}}}^{{{scale}}}({scale**2}-x^2)dx$이다."),
                    ("짝함수의 대칭성을 이용해 넓이를 계산한다.", rf"$S=2[{scale**2}x-x^3/3]_0^{{{scale}}}=\dfrac43{scale}^3$이다."),
                    ("문제에서 요구한 배수를 계산한다.", rf"$\dfrac{{3S}}4={scale}^3={answer}$이다."),
                ],
                alternatives=["정사각형 넓이에서 양쪽 포물선 아래 넓이를 빼는 대칭 구조로도 같은 값을 얻을 수 있다."],
            )
        )
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 로그방정식의 진수 구간과 원의 중심·외부점이다. 작동 원리는 여섯 단계와 두 대안 풀이를 갖는 난이도 5 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    logarithm_rows = [(2, 4, 0, 12), (3, 2, 2, 15), (5, 1, -3, 9), (2, 3, 4, 18), (3, 3, -2, 16)]
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
                    ("로그의 정의로 대수방정식을 만든다.", rf"$(x-({left}))({right}-x)={power}$이다."),
                    ("식을 이차방정식의 표준형으로 정리한다.", rf"$x^2-({root_sum})x+({answer})=0$이다."),
                    ("판별식과 진수 조건으로 두 실근을 확인한다.", rf"판별식은 ${discriminant}>0$이고 두 해는 진수 구간 안에 있다."),
                    ("근과 계수의 관계로 실근의 곱을 구한다.", rf"따라서 모든 실근의 곱은 ${answer}$이다."),
                ],
                alternatives=[
                    "두 진수 곱을 구간 중점에 관한 완전제곱으로 바꾸면 두 근의 대칭성과 존재를 확인할 수 있다.",
                    "이차방정식의 해를 직접 구하지 않고 상수항과 최고차항의 비로 곱만 계산할 수 있다.",
                ],
            )
        )
    tangent_rows = [(2, 7, 2, 1), (-2, 4, 3, 2), (1, -4, -2, 2), (3, 9, -3, 2), (-3, -8, 4, 3)]
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
                    "점 P를 원점으로 옮기는 평행이동을 하면 중심의 상대좌표로 같은 거리식을 얻는다.",
                    "기울기 이차방정식의 두 해를 구하지 않고 일차항과 이차항 계수의 비만 사용할 수 있다.",
                ],
            )
        )
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v14 직접 출제 명세를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v14 전체 카탈로그다. 작동 원리는 50문항을 생산 형식으로 조립하고 전수 검사한다."""
    return validate_problem_batch(build_catalog(), expected_count=50, batch_id=BATCH_ID, model_name=MODEL_NAME, codebase_base=CODEBASE_BASE, seed_base=SEED_BASE)


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v14 전체 생산분을 멱등 저장하고 재조회한다."""
    return seed_problem_batch(db_path, quests=validated_quests(), batch_id=BATCH_ID, validate_only=validate_only)


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 v14 전체 생산 결과를 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
