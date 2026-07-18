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


BATCH_ID = "marketplace-original-v7"
MODEL_NAME = "aiflow-direct-authoring-v7"
CODEBASE_BASE = 20_260_723_000
SEED_BASE = 202_607_230_000


def _imaginary_unit_specs() -> list[dict[str, Any]]:
    """필요 변수는 허수 단위의 지수다. 작동 원리는 4주기로 거듭제곱 값을 구하는 난이도 1 문제 5개를 만든다."""
    exponents = [22, 27, 32, 37, 43]
    values = ["-1", "-i", "1", "i", "-i"]
    specs = []
    for index, (exponent, answer) in enumerate(zip(exponents, values), 1):
        remainder = exponent % 4
        specs.append(
            _problem(
                1,
                index,
                title=rf"허수 단위 $i$에 대하여 $i^{{{exponent}}}$의 값을 구하시오.",
                answer=answer,
                tags=["#허수단위"],
                steps=[
                    ("허수 단위 거듭제곱의 주기가 4임을 이용한다.", rf"${exponent}=4\times{exponent // 4}+{remainder}$이므로 $i^{{{exponent}}}=i^{remainder}$이다."),
                    ("나머지 지수에 해당하는 값을 구한다.", rf"따라서 $i^{{{exponent}}}={answer}$이다."),
                ],
            )
        )
    return specs


def _matrix_entry_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 2행 2열 행렬의 우하단 성분이다. 작동 원리는 대응 성분을 더하는 난이도 1 문제 5개를 만든다."""
    rows = [(2, 5), (-3, 7), (4, -1), (6, 8), (-5, -2)]
    specs = []
    for index, (left, right) in enumerate(rows, 6):
        answer = left + right
        specs.append(
            _problem(
                1,
                index,
                title=rf"행렬 $A=\begin{{pmatrix}}1&0\\2&{left}\end{{pmatrix}}$, $B=\begin{{pmatrix}}0&3\\-1&{right}\end{{pmatrix}}$에 대하여 $A+B$의 $(2,2)$ 성분을 구하시오.",
                answer=str(answer),
                tags=["#행렬의덧셈"],
                steps=[
                    ("행렬의 덧셈은 같은 위치의 성분끼리 더한다.", rf"$(2,2)$ 성분은 ${left}+({right})$이다."),
                    ("두 대응 성분의 합을 계산한다.", rf"따라서 $(2,2)$ 성분은 ${answer}$이다."),
                ],
            )
        )
    return specs


def _line_intercept_specs() -> list[dict[str, Any]]:
    """필요 변수는 직선의 기울기와 한 점이다. 작동 원리는 점을 대입해 y절편을 찾는 난이도 2 문제 5개를 만든다."""
    rows = [(2, 3, 9), (-1, 4, 1), (3, -2, -1), (-2, 5, -7), (4, 1, 10)]
    specs = []
    for index, (slope, point_x, point_y) in enumerate(rows, 1):
        answer = point_y - slope * point_x
        specs.append(
            _problem(
                2,
                index,
                title=rf"기울기가 ${slope}$이고 점 $({point_x},{point_y})$를 지나는 직선의 y절편을 구하시오.",
                answer=str(answer),
                tags=["#두점을지나는직선", "#직선의방정식"],
                steps=[
                    ("직선을 기울기와 y절편으로 나타낸다.", rf"직선의 식을 $y={slope}x+b$로 둔다."),
                    ("주어진 점의 좌표를 직선의 식에 대입한다.", rf"${point_y}={slope}({point_x})+b$이다."),
                    ("일차방정식을 풀어 y절편을 구한다.", rf"따라서 $b={point_y}-{slope}({point_x})={answer}$이다."),
                ],
            )
        )
    return specs


def _geometric_ratio_specs() -> list[dict[str, Any]]:
    """필요 변수는 양의 등비수열 첫째항과 셋째항이다. 작동 원리는 공비의 제곱에서 양의 공비를 구하는 난이도 2 문제 5개를 만든다."""
    rows = [(2, 18, 3), (3, 48, 4), (5, 125, 5), (4, 36, 3), (7, 112, 4)]
    specs = []
    for index, (first, third, answer) in enumerate(rows, 6):
        specs.append(
            _problem(
                2,
                index,
                title=rf"모든 항이 양수인 등비수열에서 첫째항이 ${first}$, 셋째항이 ${third}$일 때, 공비를 구하시오.",
                answer=str(answer),
                tags=["#등비수열", "#등비수열의일반항"],
                steps=[
                    ("셋째항을 첫째항과 공비로 나타낸다.", r"$a_3=a_1r^2$이다."),
                    ("주어진 두 항을 대입해 공비의 제곱을 구한다.", rf"${third}={first}r^2$이므로 $r^2={answer**2}$이다."),
                    ("모든 항이 양수라는 조건으로 공비를 선택한다.", rf"$r>0$이므로 $r={answer}$이다."),
                ],
            )
        )
    return specs


def _circle_center_specs() -> list[dict[str, Any]]:
    """필요 변수는 원의 중심과 반지름이다. 작동 원리는 일반형 계수에서 중심을 복원해 좌표합을 구하는 난이도 3 문제 5개를 만든다."""
    rows = [(2, 3, 4), (-3, 1, 2), (4, -2, 3), (-1, -4, 5), (5, 2, 4)]
    specs = []
    for index, (center_x, center_y, radius) in enumerate(rows, 1):
        x_coefficient = -2 * center_x
        y_coefficient = -2 * center_y
        constant = center_x**2 + center_y**2 - radius**2
        answer = center_x + center_y
        specs.append(
            _problem(
                3,
                index,
                title=rf"원 $x^2+y^2+({x_coefficient})x+({y_coefficient})y+({constant})=0$의 중심을 $(p,q)$라 할 때, $p+q$를 구하시오.",
                answer=str(answer),
                tags=["#원의일반형", "#일반형을표준형으로", "#원의표준형"],
                steps=[
                    ("x항 계수의 절반에 부호를 바꾸어 중심의 x좌표를 구한다.", rf"$p=-({x_coefficient})/2={center_x}$이다."),
                    ("y항 계수의 절반에 부호를 바꾸어 중심의 y좌표를 구한다.", rf"$q=-({y_coefficient})/2={center_y}$이다."),
                    ("완전제곱으로 중심 좌표를 확인한다.", rf"원의 표준형은 $(x-({center_x}))^2+(y-({center_y}))^2={radius**2}$이다."),
                    ("중심의 두 좌표를 더한다.", rf"따라서 $p+q={center_x}+({center_y})={answer}$이다."),
                ],
                alternatives=[rf"일반형 $x^2+y^2+Dx+Ey+F=0$의 중심 $(-D/2,-E/2)$를 바로 사용해도 된다."],
            )
        )
    return specs


def _derivative_slope_specs() -> list[dict[str, Any]]:
    """필요 변수는 이차함수 계수와 접점이다. 작동 원리는 도함수값으로 접선 기울기를 구하는 난이도 3 문제 5개를 만든다."""
    rows = [(2, 3, 1), (3, -2, 2), (-1, 4, -2), (4, 1, 3), (5, -3, -1)]
    specs = []
    for index, (quadratic, linear, point) in enumerate(rows, 6):
        answer = 2 * quadratic * point + linear
        specs.append(
            _problem(
                3,
                index,
                title=rf"함수 $f(x)={quadratic}x^2+({linear})x+1$의 그래프 위에서 $x={point}$인 점의 접선 기울기를 구하시오.",
                answer=str(answer),
                tags=["#도함수", "#접선의기울기", "#미분계수"],
                steps=[
                    ("이차함수를 x에 관해 미분한다.", rf"$f'(x)={2 * quadratic}x+({linear})$이다."),
                    ("접선 기울기는 접점에서의 도함수값임을 이용한다.", rf"기울기는 $f'({point})$이다."),
                    ("접점의 x좌표를 도함수에 대입한다.", rf"$f'({point})={2 * quadratic}({point})+({linear})$이다."),
                    ("곱셈과 덧셈을 계산한다.", rf"따라서 접선 기울기는 ${answer}$이다."),
                ],
                alternatives=["접점 주변의 할선 기울기 극한을 계산해도 같은 미분계수를 얻는다."],
            )
        )
    return specs


def _sigma_parameter_specs() -> list[dict[str, Any]]:
    """필요 변수는 합의 상한·상수항·목표 계수다. 작동 원리는 시그마 선형성으로 미정계수를 찾는 난이도 4 문제 5개를 만든다."""
    rows = [(4, 1, 2), (5, -1, 3), (6, 2, -1), (7, 0, 2), (8, 3, 4)]
    specs = []
    for index, (n, constant, answer) in enumerate(rows, 1):
        k_sum = n * (n + 1) // 2
        total = answer * k_sum + constant * n
        specs.append(
            _problem(
                4,
                index,
                title=rf"$\displaystyle\sum_{{k=1}}^{{{n}}}(ak+({constant}))={total}$일 때, 상수 $a$를 구하시오.",
                answer=str(answer),
                tags=["#수열의표현", "#시그마공식", "#시그마의성질", "#미정계수법"],
                steps=[
                    ("시그마의 선형성으로 두 합을 분리한다.", rf"$a\sum_{{k=1}}^{{{n}}}k+{constant}\sum_{{k=1}}^{{{n}}}1={total}$이다."),
                    ("자연수의 합을 계산한다.", rf"$\sum_{{k=1}}^{{{n}}}k=\dfrac{{{n}({n + 1})}}2={k_sum}$이다."),
                    ("상수 1의 합을 항의 개수로 계산한다.", rf"$\sum_{{k=1}}^{{{n}}}1={n}$이다."),
                    ("두 합을 대입해 a에 관한 일차방정식을 만든다.", rf"${k_sum}a+({constant * n})={total}$이다."),
                    ("일차방정식을 풀어 상수를 구한다.", rf"따라서 $a={answer}$이다."),
                ],
                alternatives=[rf"각 항을 직접 더해 k의 계수 합 ${k_sum}$과 상수항 합 ${constant * n}$을 구할 수 있다."],
            )
        )
    return specs


def _quadratic_minimum_specs() -> list[dict[str, Any]]:
    """필요 변수는 양의 매개변수와 상수항이다. 작동 원리는 완전제곱한 최솟값에서 매개변수를 복원하는 난이도 4 문제 5개를 만든다."""
    rows = [(2, 9), (3, 15), (4, 25), (5, 34), (6, 45)]
    specs = []
    for index, (answer, constant) in enumerate(rows, 6):
        minimum = constant - answer**2
        specs.append(
            _problem(
                4,
                index,
                title=rf"$a>0$이고 이차함수 $f(x)=x^2-2ax+{constant}$의 최솟값이 ${minimum}$일 때, $a$를 구하시오.",
                answer=str(answer),
                tags=["#이차함수의최대최소", "#완성제곱법", "#꼭짓점", "#미정계수법"],
                steps=[
                    ("x에 관한 식을 완전제곱한다.", rf"$f(x)=(x-a)^2+{constant}-a^2$이다."),
                    ("제곱항의 최소 가능 값을 확인한다.", r"$(x-a)^2\ge0$이므로 $x=a$에서 최소가 된다."),
                    ("최솟값을 매개변수로 나타낸다.", rf"함수의 최솟값은 ${constant}-a^2$이다."),
                    ("주어진 최솟값과 같게 놓는다.", rf"${constant}-a^2={minimum}$이므로 $a^2={answer**2}$이다."),
                    ("양수 조건에 맞는 값을 선택한다.", rf"$a>0$이므로 $a={answer}$이다."),
                ],
                alternatives=[rf"꼭짓점 $x=a$의 함숫값을 바로 계산해도 $a={answer}$을 얻는다."],
            )
        )
    return specs


def _rational_inverse_specs() -> list[dict[str, Any]]:
    """필요 변수는 유리함수 계수·목표 함숫값·원상이다. 작동 원리는 역함숫값을 일차방정식으로 구하는 난이도 5 문제 5개를 만든다."""
    rows = [(2, 1, 5, 4), (3, 2, 6, 5), (1, 3, 7, 4), (-1, 2, 8, 3), (4, -1, 9, 6)]
    specs = []
    for index, (coefficient, denominator_constant, answer, target) in enumerate(rows, 1):
        numerator_constant = target * (answer + denominator_constant) - coefficient * answer
        specs.append(
            _problem(
                5,
                index,
                title=rf"함수 $f(x)=\dfrac{{{coefficient}x+({numerator_constant})}}{{x+({denominator_constant})}}$에 대하여 $f^{{-1}}({target})$의 값을 구하시오.",
                answer=str(answer),
                tags=["#유리함수의그래프", "#역함수", "#합성함수", "#근과계수의관계", "#점근선"],
                steps=[
                    ("역함숫값의 정의를 원래 함수의 방정식으로 바꾼다.", rf"$f^{{-1}}({target})=x$이면 $f(x)={target}$이다."),
                    ("유리함수 식을 목표 함숫값과 같게 놓는다.", rf"$\dfrac{{{coefficient}x+({numerator_constant})}}{{x+({denominator_constant})}}={target}$이다."),
                    ("분모가 0이 아닌 조건을 확인하고 양변을 곱한다.", rf"$x\ne{-denominator_constant}$이고 ${coefficient}x+({numerator_constant})={target}(x+({denominator_constant}))$이다."),
                    ("x에 관한 일차방정식을 정리한다.", rf"$({coefficient - target})x={target * denominator_constant - numerator_constant}$이다."),
                    ("방정식을 풀어 원상을 구한다.", rf"따라서 $x={answer}$이다."),
                    ("정의역과 함수값을 대입해 검산한다.", rf"${answer}\ne{-denominator_constant}$이고 $f({answer})={target}$이므로 $f^{{-1}}({target})={answer}$이다."),
                ],
                alternatives=[
                    "x와 y를 바꾼 뒤 y에 대하여 정리해 역함수 식을 먼저 구할 수 있다.",
                    rf"그래프 $y=f(x)$와 $y=x$를 대칭이동한 점의 좌표 관계로도 원상 ${answer}$을 확인할 수 있다.",
                ],
            )
        )
    return specs


def _circle_tangent_length_specs() -> list[dict[str, Any]]:
    """필요 변수는 원의 반지름과 외부점 거리다. 작동 원리는 두 접선 길이의 합을 구하는 난이도 5 문제 5개를 만든다."""
    rows = [(3, 5, 4), (5, 13, 12), (8, 17, 15), (7, 25, 24), (9, 41, 40)]
    specs = []
    for index, (radius, distance, tangent) in enumerate(rows, 6):
        answer = 2 * tangent
        specs.append(
            _problem(
                5,
                index,
                title=rf"중심이 원점이고 반지름이 ${radius}$인 원 밖의 점 $P({distance},0)$에서 원에 그은 두 접선의 접점을 $A,B$라 할 때, $PA+PB$를 구하시오.",
                answer=str(answer),
                tags=["#원의방정식", "#직선의방정식", "#점과직선사이의거리", "#두점사이의거리", "#기울기"],
                steps=[
                    ("원의 중심 O와 외부점 P 사이의 거리를 확인한다.", rf"$OP={distance}$이고 원의 반지름은 ${radius}$이다."),
                    ("반지름과 접선이 접점에서 수직임을 이용한다.", r"$OA\perp PA$이므로 삼각형 OAP는 직각삼각형이다."),
                    ("피타고라스 정리로 한 접선의 길이를 나타낸다.", rf"$PA^2=OP^2-OA^2={distance**2}-{radius**2}={tangent**2}$이다."),
                    ("양의 길이를 선택한다.", rf"따라서 $PA={tangent}$이다."),
                    ("한 외부점에서 그은 두 접선의 길이가 같음을 이용한다.", rf"$PB=PA={tangent}$이다."),
                    ("두 접선 길이를 더한다.", rf"$PA+PB={tangent}+{tangent}={answer}$이다."),
                ],
                alternatives=[
                    rf"점 P의 원에 대한 멱이 ${distance**2}-{radius**2}={tangent**2}$임을 사용하면 접선 길이는 ${tangent}$이다.",
                    "두 접점이 x축에 대해 대칭이므로 두 접선 길이가 같다는 사실을 좌표로 확인할 수 있다.",
                ],
            )
        )
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도 1~5별 10문항씩 총 50개의 일곱 번째 직접 출제 명세를 반환하는 것이다."""
    return [*_imaginary_unit_specs(), *_matrix_entry_specs(), *_line_intercept_specs(), *_geometric_ratio_specs(), *_circle_center_specs(), *_derivative_slope_specs(), *_sigma_parameter_specs(), *_quadratic_minimum_specs(), *_rational_inverse_specs(), *_circle_tangent_length_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v7 카탈로그와 배치 기준값이다. 작동 원리는 50문항을 생산 형식으로 조립하고 전수 품질 검사를 수행하는 것이다."""
    return validate_problem_batch(build_catalog(), expected_count=50, batch_id=BATCH_ID, model_name=MODEL_NAME, codebase_base=CODEBASE_BASE, seed_base=SEED_BASE)


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 대상 DB와 검증 모드다. 작동 원리는 검증된 v7 문제를 로컬 DB에 멱등 저장하고 재조회한다."""
    return seed_problem_batch(db_path, quests=validated_quests(), batch_id=BATCH_ID, validate_only=validate_only)


def main() -> None:
    """필요 변수는 DB 경로와 검증 옵션이다. 작동 원리는 난이도별 v7 직접 출제 결과를 UTF-8 JSON으로 출력하는 것이다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
