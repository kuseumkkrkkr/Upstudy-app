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

BATCH_ID = "marketplace-original-v17"
MODEL_NAME = "aiflow-direct-authoring-v17"
CODEBASE_BASE = 20_260_831_000
SEED_BASE = 202_607_410_000


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 학생 수와 전체집합·부분집합 원소 수다. 작동 원리는 두 단계 계산형 난이도 1 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    for index, student_count in enumerate((7, 8, 9, 11, 12), 1):
        answer = student_count * (student_count - 1)
        specs.append(
            _problem(
                1,
                index,
                title=rf"서로 다른 학생 {student_count}명 중에서 회장과 부회장을 한 명씩 뽑는 경우의 수를 구하시오.",
                answer=str(answer),
                tags=["#순열의수"],
                steps=[
                    ("회장을 먼저 뽑는 경우의 수를 센다.", rf"회장은 {student_count}명 중 한 명이므로 ${student_count}$가지이다."),
                    ("남은 학생 중 부회장을 뽑아 곱한다.", rf"경우의 수는 ${student_count}\cdot {student_count - 1}={answer}$이다."),
                ],
            )
        )
    complement_rows = [(40, 17), (55, 23), (68, 31), (72, 29), (90, 44)]
    for index, (universal_count, subset_count) in enumerate(complement_rows, 6):
        answer = universal_count - subset_count
        specs.append(
            _problem(
                1,
                index,
                title=rf"전체집합 $U$의 원소 수가 ${universal_count}$이고 부분집합 $A$의 원소 수가 ${subset_count}$일 때, $A$의 여집합의 원소 수를 구하시오.",
                answer=str(answer),
                tags=["#여집합"],
                steps=[
                    ("여집합의 원소 수 관계를 이용한다.", r"$n(A^c)=n(U)-n(A)$이다."),
                    ("두 원소 수를 대입해 뺄셈한다.", rf"따라서 $n(A^c)={universal_count}-{subset_count}={answer}$이다."),
                ],
            )
        )
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 평행한 두 직선의 기울기와 지수방정식의 지수 이동량이다. 작동 원리는 세 단계 개념 적용형 난이도 2 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    parallel_rows = [(2, 3, 1, -4), (-3, 2, 5, 2), (4, -2, -3, 7), (-2, 5, 4, -1), (5, -3, -2, 6)]
    for index, (slope, divisor, first_intercept, second_intercept) in enumerate(parallel_rows, 1):
        answer = slope * divisor
        specs.append(
            _problem(
                2,
                index,
                title=rf"두 직선 $y=({slope})x+({first_intercept})$와 $y=\dfrac{{a}}{{{divisor}}}x+({second_intercept})$가 서로 평행할 때, 상수 $a$를 구하시오.",
                answer=str(answer),
                tags=["#기울기", "#평행조건"],
                steps=[
                    ("두 직선의 기울기를 각각 확인한다.", rf"두 기울기는 ${slope}$와 $\dfrac{{a}}{{{divisor}}}$이다."),
                    ("평행한 두 직선의 기울기가 같다는 조건을 적용한다.", rf"$\dfrac{{a}}{{{divisor}}}={slope}$이다."),
                    ("양변에 분모를 곱해 상수를 구한다.", rf"따라서 $a={answer}$이다."),
                ],
            )
        )
    exponent_rows = [(3, 2), (-1, 4), (5, -1), (-4, 3), (2, 5)]
    for index, (left_shift, right_shift) in enumerate(exponent_rows, 6):
        answer = left_shift + 2 * right_shift
        specs.append(
            _problem(
                2,
                index,
                title=rf"지수방정식 $2^{{x+({left_shift})}}=4^{{x-({right_shift})}}$을 만족하는 실수 $x$를 구하시오.",
                answer=str(answer),
                tags=["#지수방정식", "#지수법칙"],
                steps=[
                    ("오른쪽의 밑 4를 밑 2의 거듭제곱으로 바꾼다.", rf"$4^{{x-({right_shift})}}=2^{{2x-{2 * right_shift}}}$이다."),
                    ("같은 밑의 지수가 같다는 조건을 적용한다.", rf"$x+({left_shift})=2x-{2 * right_shift}$이다."),
                    ("일차방정식을 풀어 지수를 구한다.", rf"따라서 $x={answer}$이다."),
                ],
            )
        )
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 등차수열의 양 끝항·항수와 원의 중심·접선이다. 작동 원리는 네 단계와 한 대안 풀이를 갖는 난이도 3 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    sequence_rows = [(4, 28, 9), (-3, 21, 7), (8, 38, 11), (-10, 14, 13), (5, 45, 6)]
    for index, (first, last, count) in enumerate(sequence_rows, 1):
        answer = count * (first + last) // 2
        specs.append(
            _problem(
                3,
                index,
                title=rf"첫째항이 ${first}$이고 제{count}항이 ${last}$인 등차수열의 첫째항부터 제{count}항까지의 합을 구하시오.",
                answer=str(answer),
                tags=["#등차수열", "#등차수열의합", "#일반항"],
                steps=[
                    ("등차수열의 항수와 양 끝항을 확인한다.", rf"항수는 ${count}$이고 첫째항과 끝항은 ${first},{last}$이다."),
                    ("등차수열의 합 공식을 적는다.", r"$S_n=\dfrac{n(a_1+a_n)}2$이다."),
                    ("주어진 세 값을 합 공식에 대입한다.", rf"$S_{count}=\dfrac{{{count}({first}+{last})}}2$이다."),
                    ("괄호와 곱을 계산해 합을 구한다.", rf"따라서 $S_{count}={answer}$이다."),
                ],
                alternatives=["첫 항과 끝 항, 둘째 항과 끝에서 둘째 항을 짝지으면 모든 쌍의 합이 같음을 이용할 수 있다."],
            )
        )
    circle_rows = [(3, -2, -2), (-4, 5, 2), (7, 1, -1), (-6, -3, 3), (2, 8, -9)]
    for index, (center_x, center_y, tangent_x) in enumerate(circle_rows, 6):
        radius = abs(center_x - tangent_x)
        answer = radius**2
        specs.append(
            _problem(
                3,
                index,
                title=rf"중심이 $({center_x},{center_y})$이고 직선 $x={tangent_x}$에 접하는 원의 반지름의 제곱을 구하시오.",
                answer=str(answer),
                tags=["#원의방정식", "#점과직선사이의거리", "#반지름"],
                steps=[
                    ("원의 중심과 접선 사이의 거리를 나타낸다.", rf"중심에서 직선 $x={tangent_x}$까지의 거리는 $|{center_x}-({tangent_x})|$이다."),
                    ("절댓값을 계산해 중심과 직선 사이 거리를 구한다.", rf"거리는 ${radius}$이다."),
                    ("접하는 원의 반지름이 이 거리와 같음을 이용한다.", rf"따라서 반지름은 $r={radius}$이다."),
                    ("반지름을 제곱해 요구한 값을 구한다.", rf"$r^2={radius}^2={answer}$이다."),
                ],
                alternatives=["중심에서 접선에 내린 수선이 수평선분이므로 두 x좌표의 차만 계산할 수 있다."],
            )
        )
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 등차 점화식의 공차와 이차함수의 양의 일차항 계수다. 작동 원리는 다섯 단계와 한 대안 풀이를 갖는 난이도 4 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    recurrence_rows = [(3, 8, 4), (-2, 7, 5), (6, 10, -1), (-5, 6, 3), (4, 9, 2)]
    for index, (first, count, answer) in enumerate(recurrence_rows, 1):
        total = count * (2 * first + (count - 1) * answer) // 2
        specs.append(
            _problem(
                4,
                index,
                title=rf"수열 $\{{a_n\}}$이 $a_1={first}$, $a_{{n+1}}=a_n+d$를 만족하고 $\displaystyle\sum_{{k=1}}^{{{count}}}a_k={total}$일 때, 상수 $d$를 구하시오.",
                answer=str(answer),
                tags=["#수열의표현", "#등차수열", "#등차수열의합", "#공차"],
                steps=[
                    ("점화식에서 수열이 공차 d인 등차수열임을 확인한다.", r"$a_{n+1}-a_n=d$이므로 공차는 $d$이다."),
                    ("등차수열의 첫 n항의 합 공식을 적는다.", r"$S_n=\dfrac{n}{2}\{2a_1+(n-1)d\}$이다."),
                    ("첫째항과 항수를 합 공식에 대입한다.", rf"$S_{count}=\dfrac{{{count}}}{2}\{{{2 * first}+{count - 1}d\}}$이다."),
                    ("주어진 합과 같게 놓아 일차방정식을 만든다.", rf"$\dfrac{{{count}}}{2}\{{{2 * first}+{count - 1}d\}}={total}$이다."),
                    ("일차방정식을 풀어 공차를 구한다.", rf"따라서 $d={answer}$이다."),
                ],
                alternatives=["점화식으로 끝항을 $a_n=a_1+(n-1)d$로 나타낸 뒤 양 끝항을 이용한 합 공식을 적용할 수 있다."],
            )
        )
    quadratic_rows = [(4, 3), (6, -2), (8, 5), (10, -4), (12, 1)]
    for index, (answer, constant) in enumerate(quadratic_rows, 6):
        maximum = answer**2 // 4 + constant
        specs.append(
            _problem(
                4,
                index,
                title=rf"이차함수 $f(x)=-x^2+ax+({constant})$의 최댓값이 ${maximum}$이다. $a>0$일 때, 상수 $a$를 구하시오.",
                answer=str(answer),
                tags=["#이차함수", "#이차함수의최대최소", "#꼭짓점", "#미정계수법"],
                steps=[
                    ("이차함수를 완전제곱식으로 정리한다.", rf"$f(x)=-\left(x-\dfrac a2\right)^2+\dfrac{{a^2}}4+({constant})$이다."),
                    ("아래로 열린 포물선의 꼭짓점에서 최댓값을 읽는다.", rf"최댓값은 $\dfrac{{a^2}}4+({constant})$이다."),
                    ("주어진 최댓값과 같게 놓는다.", rf"$\dfrac{{a^2}}4+({constant})={maximum}$이다."),
                    ("방정식을 정리해 계수의 제곱을 구한다.", rf"$a^2={answer**2}$이다."),
                    ("양수 조건으로 알맞은 해를 선택한다.", rf"$a>0$이므로 $a={answer}$이다."),
                ],
                alternatives=["포물선의 축 $x=a/2$를 구해 해당 x좌표에서의 함숫값을 최댓값과 비교할 수 있다."],
            )
        )
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 직선의 양의 계수와 부분분수 합의 자연수 매개변수다. 작동 원리는 여섯 단계와 두 대안 풀이를 갖는 난이도 5 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    for index, answer in enumerate((3, 6, 9, 12, 15), 1):
        area = 4 * answer**3 // 3
        specs.append(
            _problem(
                5,
                index,
                title=rf"$a>0$일 때, 포물선 $y=x^2$과 직선 $y=2ax$로 둘러싸인 부분의 넓이가 ${area}$이다. 상수 $a$를 구하시오.",
                answer=str(answer),
                tags=["#직선의방정식", "#이차함수", "#두곡선사이의넓이", "#정적분", "#미정계수법"],
                steps=[
                    ("두 그래프의 교점 방정식을 세운다.", r"$x^2=2ax$이므로 $x(x-2a)=0$이다."),
                    ("두 교점의 x좌표를 구한다.", r"교점의 x좌표는 $0,2a$이다."),
                    ("두 그래프의 위아래 관계로 넓이 적분을 세운다.", r"$0<x<2a$에서 직선이 위에 있으므로 넓이는 $\int_0^{2a}(2ax-x^2)dx$이다."),
                    ("정적분의 원시함수를 구한다.", r"$\int(2ax-x^2)dx=ax^2-\dfrac{x^3}{3}$이다."),
                    ("양 끝값을 대입해 넓이를 a로 나타낸다.", rf"넓이는 $\dfrac43a^3={area}$이다."),
                    ("양수 조건을 이용해 삼차방정식의 해를 구한다.", rf"$a^3={answer**3}$이고 $a>0$이므로 $a={answer}$이다."),
                ],
                alternatives=[
                    "포물선과 직선 사이 넓이의 표준 적분 공식을 교점 간격 $2a$에 적용할 수 있다.",
                    "적분에서 $x=2au$로 치환하면 넓이가 $a^3$에 비례함을 먼저 확인할 수 있다.",
                ],
            )
        )
    telescoping_rows = [(4, 2), (5, 3), (6, 4), (7, 5), (8, 6)]
    for index, (upper, answer) in enumerate(telescoping_rows, 6):
        denominator = (answer + 1) * (answer + upper + 1)
        negative_root_magnitude = upper + 2 + answer
        specs.append(
            _problem(
                5,
                index,
                title=rf"양의 정수 $a$에 대하여 $\displaystyle\sum_{{k=1}}^{{{upper}}}\dfrac1{{(k+a)(k+a+1)}}=\dfrac{{{upper}}}{{{denominator}}}$일 때, $a$를 구하시오.",
                answer=str(answer),
                tags=["#수열의표현", "#부분분수", "#여러가지수열의합", "#시그마의성질", "#미정계수법"],
                steps=[
                    ("일반항을 부분분수로 분해한다.", r"$\dfrac1{(k+a)(k+a+1)}=\dfrac1{k+a}-\dfrac1{k+a+1}$이다."),
                    ("연속한 항의 소거를 이용해 합을 정리한다.", rf"합은 $\dfrac1{{a+1}}-\dfrac1{{a+{upper + 1}}}$이다."),
                    ("두 분수를 통분해 하나의 분수로 만든다.", rf"합은 $\dfrac{{{upper}}}{{(a+1)(a+{upper + 1})}}$이다."),
                    ("주어진 합과 비교해 분모의 방정식을 세운다.", rf"$(a+1)(a+{upper + 1})={denominator}$이다."),
                    ("이차방정식을 인수분해해 두 근을 구한다.", rf"$(a-{answer})(a+{negative_root_magnitude})=0$이다."),
                    ("양의 정수 조건에 맞는 근을 선택한다.", rf"따라서 $a={answer}$이다."),
                ],
                alternatives=[
                    "합의 첫 항과 마지막 항만 남는 망원합 구조를 표로 써서 확인할 수 있다.",
                    "분모의 두 인수 차가 일정하다는 점을 이용해 양의 정수 인수쌍을 직접 찾을 수 있다.",
                ],
            )
        )
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v17 직접 출제 명세를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v17 전체 카탈로그다. 작동 원리는 50문항을 생산 형식으로 조립하고 전수 검사한다."""
    return validate_problem_batch(build_catalog(), expected_count=50, batch_id=BATCH_ID, model_name=MODEL_NAME, codebase_base=CODEBASE_BASE, seed_base=SEED_BASE)


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v17 전체 생산분을 멱등 저장하고 재조회한다."""
    return seed_problem_batch(db_path, quests=validated_quests(), batch_id=BATCH_ID, validate_only=validate_only)


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 v17 전체 생산 결과를 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
