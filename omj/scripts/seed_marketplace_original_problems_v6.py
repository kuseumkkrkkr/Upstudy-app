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


BATCH_ID = "marketplace-original-v6"
MODEL_NAME = "aiflow-direct-authoring-v6"
CODEBASE_BASE = 20_260_722_000
SEED_BASE = 202_607_220_000


def _exponent_law_specs() -> list[dict[str, Any]]:
    """필요 변수는 밑과 두 지수다. 작동 원리는 같은 밑의 곱에서 지수를 더하는 난이도 1 문제 5개를 만든다."""
    rows = [(2, 2, 3), (3, 1, 3), (5, 2, 1), (4, 1, 2), (10, 1, 2)]
    specs = []
    for index, (base, left_exponent, right_exponent) in enumerate(rows, 1):
        total_exponent = left_exponent + right_exponent
        answer = base**total_exponent
        specs.append(
            _problem(
                1,
                index,
                title=rf"${base}^{{{left_exponent}}}\times {base}^{{{right_exponent}}}$의 값을 구하시오.",
                answer=str(answer),
                tags=["#지수법칙"],
                steps=[
                    ("밑이 같은 거듭제곱의 곱에서 지수를 더한다.", rf"${base}^{{{left_exponent}}}\times {base}^{{{right_exponent}}}={base}^{{{total_exponent}}}$이다."),
                    ("거듭제곱의 값을 계산한다.", rf"${base}^{{{total_exponent}}}={answer}$이다."),
                ],
            )
        )
    return specs


def _arithmetic_middle_specs() -> list[dict[str, Any]]:
    """필요 변수는 등차수열의 첫째항과 셋째항이다. 작동 원리는 등차중항 성질로 둘째항을 구하는 난이도 1 문제 5개를 만든다."""
    rows = [(2, 10), (-3, 7), (5, 17), (8, 2), (-4, 12)]
    specs = []
    for index, (first, third) in enumerate(rows, 6):
        answer = (first + third) // 2
        specs.append(
            _problem(
                1,
                index,
                title=rf"등차수열 $\{{a_n\}}$에서 $a_1={first}$, $a_3={third}$일 때, $a_2$를 구하시오.",
                answer=str(answer),
                tags=["#등차수열"],
                steps=[
                    ("등차수열의 가운데 항은 양옆 두 항의 평균임을 이용한다.", rf"$2a_2=a_1+a_3={first}+({third})$이다."),
                    ("양변을 2로 나누어 둘째항을 구한다.", rf"따라서 $a_2=\dfrac{{{first}+({third})}}2={answer}$이다."),
                ],
            )
        )
    return specs


def _line_slope_specs() -> list[dict[str, Any]]:
    """필요 변수는 기울기가 정수인 두 점이다. 작동 원리는 좌표 변화량의 비로 직선 기울기를 구하는 난이도 2 문제 5개를 만든다."""
    rows = [(1, 2, 4, 8), (-2, 5, 2, -3), (0, -1, 5, 14), (3, 7, -1, 15), (-4, -2, 2, 10)]
    specs = []
    for index, (x1, y1, x2, y2) in enumerate(rows, 1):
        answer = (y2 - y1) // (x2 - x1)
        specs.append(
            _problem(
                2,
                index,
                title=rf"두 점 $({x1},{y1})$, $({x2},{y2})$를 지나는 직선의 기울기를 구하시오.",
                answer=str(answer),
                tags=["#두점을지나는직선", "#기울기"],
                steps=[
                    ("두 점의 y좌표 변화량을 구한다.", rf"$\Delta y={y2}-({y1})={y2 - y1}$이다."),
                    ("두 점의 x좌표 변화량을 구한다.", rf"$\Delta x={x2}-({x1})={x2 - x1}$이다."),
                    ("y좌표 변화량을 x좌표 변화량으로 나눈다.", rf"기울기는 $\dfrac{{{y2 - y1}}}{{{x2 - x1}}}={answer}$이다."),
                ],
            )
        )
    return specs


def _double_root_specs() -> list[dict[str, Any]]:
    """필요 변수는 이차방정식의 일차항 계수다. 작동 원리는 중근 조건인 판별식 0으로 상수항을 구하는 난이도 2 문제 5개를 만든다."""
    coefficients = [2, -4, 6, -8, 10]
    specs = []
    for index, coefficient in enumerate(coefficients, 6):
        answer = coefficient**2 // 4
        specs.append(
            _problem(
                2,
                index,
                title=rf"이차방정식 $x^2+({coefficient})x+m=0$이 중근을 가질 때, 상수 $m$을 구하시오.",
                answer=str(answer),
                tags=["#이차방정식의판별식", "#판별식과근의개수"],
                steps=[
                    ("중근을 갖기 위한 판별식 조건을 세운다.", r"이차방정식이 중근을 가지므로 $D=0$이다."),
                    ("주어진 계수로 판별식을 나타낸다.", rf"$D=({coefficient})^2-4m=0$이다."),
                    ("일차방정식을 풀어 상수항을 구한다.", rf"$4m={coefficient**2}$이므로 $m={answer}$이다."),
                ],
            )
        )
    return specs


def _diameter_circle_specs() -> list[dict[str, Any]]:
    """필요 변수는 지름의 양 끝점이다. 작동 원리는 중점과 거리로 원의 반지름 제곱을 구하는 난이도 3 문제 5개를 만든다."""
    rows = [((-3, 0), (3, 0)), ((0, -4), (0, 4)), ((-2, -1), (4, 7)), ((1, 2), (7, 10)), ((-5, 3), (5, -3))]
    specs = []
    for index, ((x1, y1), (x2, y2)) in enumerate(rows, 1):
        center_x = (x1 + x2) // 2
        center_y = (y1 + y2) // 2
        diameter_square = (x2 - x1) ** 2 + (y2 - y1) ** 2
        radius_square = diameter_square // 4
        specs.append(
            _problem(
                3,
                index,
                title=rf"두 점 $A({x1},{y1})$, $B({x2},{y2})$를 지름의 양 끝점으로 하는 원의 반지름의 제곱을 구하시오.",
                answer=str(radius_square),
                tags=["#원의표준형", "#두점사이의거리", "#거리공식"],
                steps=[
                    ("지름의 중점에서 원의 중심을 구한다.", rf"원의 중심은 $({center_x},{center_y})$이다."),
                    ("두 끝점 사이 거리의 제곱을 구한다.", rf"$AB^2=({x2 - x1})^2+({y2 - y1})^2={diameter_square}$이다."),
                    ("반지름은 지름의 절반임을 이용한다.", r"$r=AB/2$이므로 $r^2=AB^2/4$이다."),
                    ("지름 제곱을 4로 나눈다.", rf"따라서 $r^2={diameter_square}/4={radius_square}$이다."),
                ],
                alternatives=[rf"중심 $({center_x},{center_y})$에서 점 A까지의 거리 제곱을 직접 계산해도 ${radius_square}$이다."],
            )
        )
    return specs


def _arithmetic_count_specs() -> list[dict[str, Any]]:
    """필요 변수는 자연수 항 수와 삼각수다. 작동 원리는 등차수열 합에서 양의 항 수를 복원하는 난이도 3 문제 5개를 만든다."""
    specs = []
    for index, answer in enumerate(range(5, 10), 6):
        total = answer * (answer + 1) // 2
        specs.append(
            _problem(
                3,
                index,
                title=rf"첫째항이 $1$, 공차가 $1$인 등차수열의 첫 $n$개 항의 합이 ${total}$일 때, 자연수 $n$을 구하시오.",
                answer=str(answer),
                tags=["#등차수열", "#등차수열의합", "#이차방정식"],
                steps=[
                    ("등차수열의 첫 n개 항의 합을 식으로 나타낸다.", r"$S_n=1+2+\cdots+n=\dfrac{n(n+1)}2$이다."),
                    ("주어진 합과 같게 놓는다.", rf"$\dfrac{{n(n+1)}}2={total}$이다."),
                    ("이차방정식으로 정리하고 인수분해한다.", rf"$n^2+n-{2 * total}=0$, 즉 $(n-{answer})(n+{answer + 1})=0$이다."),
                    ("자연수 조건에 맞는 해를 선택한다.", rf"$n={answer}$ 또는 $n=-{answer + 1}$이고 자연수이므로 $n={answer}$이다."),
                ],
                alternatives=[rf"삼각수 ${total}$을 만드는 마지막 자연수를 직접 나열해 $n={answer}$을 확인할 수 있다."],
            )
        )
    return specs


def _cubic_critical_parameter_specs() -> list[dict[str, Any]]:
    """필요 변수는 양의 임계점 위치다. 작동 원리는 삼차함수 도함수의 영점 조건으로 매개변수를 복원하는 난이도 4 문제 5개를 만든다."""
    specs = []
    for index, critical_point in enumerate(range(2, 7), 1):
        answer = critical_point**2
        specs.append(
            _problem(
                4,
                index,
                title=rf"상수 $a>0$에 대하여 함수 $f(x)=x^3-3ax$가 $x={critical_point}$에서 극값을 가질 때, $a$를 구하시오.",
                answer=str(answer),
                tags=["#도함수", "#도함수의부호", "#함수의극대와극소", "#미정계수법"],
                steps=[
                    ("삼차함수를 미분한다.", r"$f'(x)=3x^2-3a$이다."),
                    ("극값을 갖는 점에서 도함수가 0임을 이용한다.", rf"$f'({critical_point})=0$이다."),
                    ("임계점의 x좌표를 도함수에 대입한다.", rf"$3({critical_point})^2-3a=0$이다."),
                    ("방정식을 풀어 매개변수를 구한다.", rf"$a={critical_point**2}={answer}$이다."),
                    ("도함수 부호 변화로 실제 극값임을 확인한다.", rf"$a={answer}>0$이면 임계점은 $\pm{critical_point}$이고 두 점에서 도함수 부호가 바뀐다."),
                ],
                alternatives=[rf"$f'(x)=3(x-{critical_point})(x+{critical_point})$이 되어야 한다고 놓아도 $a={answer}$이다."],
            )
        )
    return specs


def _integral_interval_specs() -> list[dict[str, Any]]:
    """필요 변수는 양의 적분 상한과 피적분함수 상수다. 작동 원리는 정적분값에서 양의 상한을 복원하는 난이도 4 문제 5개를 만든다."""
    rows = [(1, 1), (2, 3), (3, 2), (4, 1), (5, 4)]
    specs = []
    for index, (answer, constant) in enumerate(rows, 6):
        value = answer**2 + constant * answer
        specs.append(
            _problem(
                4,
                index,
                title=rf"상수 $a>0$에 대하여 $\int_0^a(2x+{constant})\,dx={value}$일 때, $a$를 구하시오.",
                answer=str(answer),
                tags=["#정적분", "#정적분의계산", "#정적분과넓이", "#미정계수법"],
                steps=[
                    ("피적분함수의 부정적분을 구한다.", rf"$\int(2x+{constant})dx=x^2+{constant}x$이다."),
                    ("정적분의 양 끝을 대입한다.", rf"$\int_0^a(2x+{constant})dx=a^2+{constant}a$이다."),
                    ("주어진 적분값과 같게 놓아 이차방정식을 만든다.", rf"$a^2+{constant}a-{value}=0$이다."),
                    ("이차식을 인수분해해 두 해를 구한다.", rf"$(a-{answer})(a+{answer + constant})=0$이므로 $a={answer}$ 또는 $a=-{answer + constant}$이다."),
                    ("양수 조건에 맞는 해를 선택한다.", rf"$a>0$이므로 $a={answer}$이다."),
                ],
                alternatives=[rf"구간 $[0,a]$에서 직선 $y=2x+{constant}$ 아래 사다리꼴 넓이를 이용해도 $a^2+{constant}a={value}$이다."],
            )
        )
    return specs


def _exponential_distance_specs() -> list[dict[str, Any]]:
    """필요 변수는 지수함수의 정수 밑이다. 작동 원리는 두 그래프점과 수직선의 거리 곱을 구하는 난이도 5 문제 5개를 만든다."""
    specs = []
    for index, base in enumerate(range(2, 7), 1):
        rise = base - 1
        square = 1 + rise**2
        root_latex = rf"\sqrt{{{square}}}"
        specs.append(
            _problem(
                5,
                index,
                title=rf"지수함수 $y={base}^x$ 위의 두 점 $A(0,1)$, $B(1,{base})$가 있다. 점 $A$를 지나고 직선 $AB$에 수직인 직선을 $l$이라 하고, 원점과 $l$ 사이의 거리를 $d$라 할 때 $AB\cdot d$를 구하시오.",
                answer=str(rise),
                tags=["#지수함수의그래프", "#두점사이의거리", "#점과직선사이의거리", "#직선의방정식", "#기울기"],
                steps=[
                    ("두 점의 좌표 차로 선분 AB의 길이를 구한다.", rf"$AB=\sqrt{{1^2+({rise})^2}}=\sqrt{{{square}}}$이다."),
                    ("직선 AB의 방향벡터를 확인한다.", rf"A에서 B로 향하는 방향벡터는 $(1,{rise})$이다."),
                    ("수직선 l의 법선벡터와 방정식을 구한다.", rf"$(1,{rise})$이 l의 법선벡터이므로 $l:x+{rise}y-{rise}=0$이다."),
                    ("원점에서 직선 l까지의 거리를 계산한다.", rf"$d=\dfrac{{{rise}}}{{\sqrt{{1+{rise**2}}}}}=\dfrac{{{rise}}}{{\sqrt{{{square}}}}}$이다."),
                    ("선분 길이와 직선까지 거리를 곱한다.", rf"$AB\cdot d={root_latex}\cdot\dfrac{{{rise}}}{{{root_latex}}}$이다."),
                    ("공통 제곱근을 약분해 값을 구한다.", rf"따라서 $AB\cdot d={rise}$이다."),
                ],
                alternatives=[
                    rf"삼각형 OAB의 넓이를 밑변 AB와 높이 d로 나타내면 $AB\cdot d={rise}$을 바로 얻는다.",
                    rf"벡터의 외적 넓이 $|(0,1)\times(1,{base})|={rise}$을 이용해도 같은 값이다.",
                ],
            )
        )
    return specs


def _quadratic_composition_specs() -> list[dict[str, Any]]:
    """필요 변수는 양의 정수 s다. 작동 원리는 이차함수 합성방정식의 네 실근 곱을 구하는 난이도 5 문제 5개를 만든다."""
    specs = []
    for index, parameter in enumerate(range(2, 7), 6):
        constant = parameter**2
        answer = constant * (constant - 1)
        specs.append(
            _problem(
                5,
                index,
                title=rf"함수 $f(x)=x^2-{constant}$에 대하여 방정식 $f(f(x))=0$의 모든 서로 다른 실근의 곱을 구하시오.",
                answer=str(answer),
                tags=["#합성함수", "#이차함수의그래프", "#이차방정식", "#경우의수", "#정의역"],
                steps=[
                    ("합성함수 방정식을 식으로 전개한다.", rf"$f(f(x))=(x^2-{constant})^2-{constant}=0$이다."),
                    ("안쪽 이차식을 하나의 문자처럼 보아 두 경우로 나눈다.", rf"$(x^2-{constant})^2={parameter}^2$이므로 $x^2-{constant}=\pm{parameter}$이다."),
                    ("두 경우에서 x의 제곱값을 구한다.", rf"$x^2={constant + parameter}$ 또는 $x^2={constant - parameter}$이다."),
                    ("두 제곱값이 모두 양수인지 확인한다.", rf"${constant + parameter}>0$, ${constant - parameter}>0$이므로 각 경우에 실근이 두 개씩 있다."),
                    ("네 실근을 부호쌍으로 나타낸다.", rf"실근은 $\pm\sqrt{{{constant + parameter}}}$, $\pm\sqrt{{{constant - parameter}}}$이다."),
                    ("두 부호쌍의 곱을 묶어 전체 곱을 계산한다.", rf"근의 곱은 $({constant + parameter})({constant - parameter})={constant}({constant}-1)={answer}$이다."),
                ],
                alternatives=[
                    rf"전개한 사차방정식의 상수항이 ${answer}$이고 최고차항 계수가 1이므로 네 근의 곱은 ${answer}$이다.",
                    rf"$u=x^2$로 치환해 $(u-{constant})^2={constant}$의 두 양의 해를 먼저 구할 수 있다.",
                ],
            )
        )
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도 1~5별 10문항씩 총 50개의 여섯 번째 직접 출제 명세를 반환하는 것이다."""
    return [
        *_exponent_law_specs(),
        *_arithmetic_middle_specs(),
        *_line_slope_specs(),
        *_double_root_specs(),
        *_diameter_circle_specs(),
        *_arithmetic_count_specs(),
        *_cubic_critical_parameter_specs(),
        *_integral_interval_specs(),
        *_exponential_distance_specs(),
        *_quadratic_composition_specs(),
    ]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v6 카탈로그와 배치 기준값이다. 작동 원리는 50문항을 생산 형식으로 조립하고 전수 품질 검사를 수행하는 것이다."""
    return validate_problem_batch(
        build_catalog(),
        expected_count=50,
        batch_id=BATCH_ID,
        model_name=MODEL_NAME,
        codebase_base=CODEBASE_BASE,
        seed_base=SEED_BASE,
    )


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 대상 DB와 검증 모드다. 작동 원리는 검증된 v6 문제를 로컬 DB에 멱등 저장하고 재조회한다."""
    return seed_problem_batch(
        db_path,
        quests=validated_quests(),
        batch_id=BATCH_ID,
        validate_only=validate_only,
    )


def main() -> None:
    """필요 변수는 DB 경로와 검증 옵션이다. 작동 원리는 난이도별 v6 직접 출제 결과를 UTF-8 JSON으로 출력하는 것이다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
