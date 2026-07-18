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


BATCH_ID = "marketplace-original-v5"
MODEL_NAME = "aiflow-direct-authoring-v5"
CODEBASE_BASE = 20_260_721_000
SEED_BASE = 202_607_210_000


def _remainder_specs() -> list[dict[str, Any]]:
    """필요 변수는 이차다항식 계수와 일차식의 근이다. 작동 원리는 나머지정리로 나머지를 구하는 난이도 1 문제 5개를 만든다."""
    rows = [(2, 3, -1), (-1, 4, 5), (3, -2, 1), (4, 1, -6), (-2, -3, 7)]
    specs = []
    for index, (root, linear, constant) in enumerate(rows, 1):
        answer = root**2 + linear * root + constant
        specs.append(
            _problem(
                1,
                index,
                title=rf"다항식 $P(x)=x^2+({linear})x+({constant})$를 $x-({root})$로 나누었을 때의 나머지를 구하시오.",
                answer=str(answer),
                tags=["#나머지정리"],
                steps=[
                    ("나머지정리에 따라 일차식의 근을 다항식에 대입한다.", rf"나머지는 $P({root})$이다."),
                    ("대입한 식을 계산한다.", rf"$P({root})=({root})^2+({linear})({root})+({constant})={answer}$이다."),
                ],
            )
        )
    return specs


def _composition_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 일차함수와 대입값이다. 작동 원리는 안쪽 함수부터 계산하는 난이도 1 합성함수 문제 5개를 만든다."""
    rows = [(2, 1, 3, -2, 1), (-1, 4, 2, 3, -2), (3, -5, -2, 1, 2), (4, 2, 1, -3, 3), (-2, -1, 5, 2, -1)]
    specs = []
    for index, (f_coefficient, f_constant, g_coefficient, g_constant, value) in enumerate(rows, 6):
        inner = g_coefficient * value + g_constant
        answer = f_coefficient * inner + f_constant
        specs.append(
            _problem(
                1,
                index,
                title=rf"함수 $f(x)={f_coefficient}x+({f_constant})$, $g(x)={g_coefficient}x+({g_constant})$에 대하여 $(f\circ g)({value})$의 값을 구하시오.",
                answer=str(answer),
                tags=["#합성함수"],
                steps=[
                    ("합성함수의 안쪽 함수값을 먼저 구한다.", rf"$g({value})={g_coefficient}({value})+({g_constant})={inner}$이다."),
                    ("구한 값을 바깥 함수에 대입한다.", rf"$f({inner})={f_coefficient}({inner})+({f_constant})={answer}$이다."),
                ],
            )
        )
    return specs


def _distance_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 점의 좌표다. 작동 원리는 좌표 차와 거리 공식으로 선분 길이를 구하는 난이도 2 문제 5개를 만든다."""
    rows = [(0, 0, 3, 4), (1, 2, 7, 10), (-2, 1, 3, 13), (4, -1, -4, 14), (-3, -2, 9, 3)]
    specs = []
    for index, (x1, y1, x2, y2) in enumerate(rows, 1):
        square = (x2 - x1) ** 2 + (y2 - y1) ** 2
        answer = int(square**0.5)
        specs.append(
            _problem(
                2,
                index,
                title=rf"두 점 $A({x1},{y1})$, $B({x2},{y2})$ 사이의 거리를 구하시오.",
                answer=str(answer),
                tags=["#두점사이의거리", "#거리공식"],
                steps=[
                    ("두 점의 x좌표와 y좌표의 차를 각각 구한다.", rf"좌표 차는 $({x2 - x1},{y2 - y1})$이다."),
                    ("두 점 사이의 거리 공식에 좌표 차를 대입한다.", rf"$AB=\sqrt{{({x2 - x1})^2+({y2 - y1})^2}}=\sqrt{{{square}}}$이다."),
                    ("양의 제곱근을 계산한다.", rf"따라서 $AB={answer}$이다."),
                ],
            )
        )
    return specs


def _exponential_specs() -> list[dict[str, Any]]:
    """필요 변수는 지수함수의 밑과 두 지수 상수다. 작동 원리는 같은 밑의 지수를 비교하는 난이도 2 문제 5개를 만든다."""
    rows = [(2, 3, 8), (3, -1, 4), (5, 2, 6), (4, -3, 2), (10, 1, 5)]
    specs = []
    for index, (base, offset, target) in enumerate(rows, 6):
        answer = target - offset
        specs.append(
            _problem(
                2,
                index,
                title=rf"방정식 ${base}^{{x+({offset})}}={base}^{{{target}}}$을 만족하는 실수 $x$를 구하시오.",
                answer=str(answer),
                tags=["#지수방정식", "#지수방정식과지수부등식"],
                steps=[
                    ("양변의 밑이 같고 1이 아님을 확인한다.", rf"밑 ${base}$는 양수이고 $1$이 아니므로 지수함수는 일대일이다."),
                    ("같은 밑의 지수끼리 같게 놓는다.", rf"$x+({offset})={target}$이다."),
                    ("일차방정식을 풀어 지수를 구한다.", rf"따라서 $x={target}-({offset})={answer}$이다."),
                ],
            )
        )
    return specs


def _factor_theorem_specs() -> list[dict[str, Any]]:
    """필요 변수는 삼차다항식의 알려진 인수와 계수다. 작동 원리는 인수정리로 미정계수를 찾는 난이도 3 문제 5개를 만든다."""
    rows = [(1, 2, -3), (2, -1, 3), (-1, 4, 2), (3, 1, -2), (-2, -3, 5)]
    specs = []
    for index, (root, answer, linear) in enumerate(rows, 1):
        constant = -(root**3 + answer * root**2 + linear * root)
        specs.append(
            _problem(
                3,
                index,
                title=rf"다항식 $P(x)=x^3+ax^2+({linear})x+({constant})$가 $x-({root})$를 인수로 가질 때, $a$를 구하시오.",
                answer=str(answer),
                tags=["#인수정리", "#근과계수의관계", "#고차식인수분해"],
                steps=[
                    ("인수정리를 이용해 다항식의 특정 함수값을 0으로 놓는다.", rf"$x-({root})$가 인수이므로 $P({root})=0$이다."),
                    ("알려진 근을 다항식에 대입한다.", rf"$({root})^3+a({root})^2+({linear})({root})+({constant})=0$이다."),
                    ("상수항을 정리해 a에 관한 일차방정식을 만든다.", rf"${root**2}a+({root**3 + linear * root + constant})=0$이다."),
                    ("방정식을 풀어 미정계수를 구한다.", rf"따라서 $a={answer}$이다."),
                ],
                alternatives=[rf"조립제법에서 나머지가 $0$이 되도록 마지막 열을 맞추어도 $a={answer}$을 얻는다."],
            )
        )
    return specs


def _rational_asymptote_specs() -> list[dict[str, Any]]:
    """필요 변수는 유리함수의 평행이동량과 분자 상수다. 작동 원리는 두 점근선의 교점에서 좌표합을 구하는 난이도 3 문제 5개를 만든다."""
    rows = [(2, 1, 3), (-3, 2, 4), (1, -2, 5), (4, 3, -2), (-2, -1, 6)]
    specs = []
    for index, (horizontal_shift, vertical_shift, numerator) in enumerate(rows, 6):
        answer = horizontal_shift + vertical_shift
        specs.append(
            _problem(
                3,
                index,
                title=rf"유리함수 $f(x)=\dfrac{{{numerator}}}{{x-({horizontal_shift})}}+({vertical_shift})$의 두 점근선의 교점을 $(p,q)$라 할 때, $p+q$를 구하시오.",
                answer=str(answer),
                tags=["#유리함수의그래프", "#점근선", "#유리함수의평행이동"],
                steps=[
                    ("분모가 0이 되는 값에서 수직점근선을 구한다.", rf"수직점근선은 $x={horizontal_shift}$이다."),
                    ("x의 절댓값이 커질 때의 함수값으로 수평점근선을 구한다.", rf"$\dfrac{{{numerator}}}{{x-({horizontal_shift})}}\to0$이므로 수평점근선은 $y={vertical_shift}$이다."),
                    ("두 점근선의 교점 좌표를 읽는다.", rf"따라서 $(p,q)=({horizontal_shift},{vertical_shift})$이다."),
                    ("교점의 두 좌표를 더한다.", rf"$p+q={horizontal_shift}+({vertical_shift})={answer}$이다."),
                ],
                alternatives=[rf"기본 그래프 $y={numerator}/x$를 x축으로 ${horizontal_shift}$, y축으로 ${vertical_shift}$만큼 평행이동했다고 보아도 된다."],
            )
        )
    return specs


def _geometric_log_specs() -> list[dict[str, Any]]:
    """필요 변수는 로그의 밑·첫 지수·지수 공차·항 수다. 작동 원리는 등비수열에 로그를 취해 등차수열의 합을 구하는 난이도 4 문제 5개를 만든다."""
    rows = [(2, 1, 1, 5), (3, 2, 1, 4), (2, 3, 2, 4), (5, 1, 1, 3), (3, 4, -1, 4)]
    specs = []
    for index, (base, first_exponent, exponent_difference, n) in enumerate(rows, 1):
        last_exponent = first_exponent + (n - 1) * exponent_difference
        answer = n * (first_exponent + last_exponent) // 2
        specs.append(
            _problem(
                4,
                index,
                title=rf"양의 등비수열 $\{{a_k\}}$에서 $a_1={base}^{{{first_exponent}}}$, $a_{n}={base}^{{{last_exponent}}}$이고 $b_k=\log_{base}a_k$일 때, $\sum_{{k=1}}^{{{n}}}b_k$를 구하시오.",
                answer=str(answer),
                tags=["#등비수열", "#로그법칙", "#등차수열", "#등차수열의합"],
                steps=[
                    ("등비수열의 첫 항과 마지막 항으로 공비를 구한다.", rf"$r^{{{n - 1}}}={base}^{{{last_exponent - first_exponent}}}$이고 모든 항이 양수이므로 $r={base}^{{{exponent_difference}}}$이다."),
                    ("등비수열의 일반항을 같은 밑의 거듭제곱으로 나타낸다.", rf"$a_k={base}^{{{first_exponent}+(k-1)({exponent_difference})}}$이다."),
                    ("로그를 취해 새 수열의 일반항을 구한다.", rf"$b_k={first_exponent}+(k-1)({exponent_difference})$이므로 등차수열이다."),
                    ("새 수열의 첫 항과 마지막 항을 확인한다.", rf"$b_1={first_exponent}$, $b_{n}={last_exponent}$이다."),
                    ("등차수열의 합 공식을 적용한다.", rf"$\sum_{{k=1}}^{{{n}}}b_k=\dfrac{{{n}({first_exponent}+({last_exponent}))}}2={answer}$이다."),
                ],
                alternatives=[rf"로그가 곱을 합으로 바꾸므로 공차가 $\log_{base}r={exponent_difference}$임을 바로 이용할 수 있다."],
            )
        )
    return specs


def _circle_chord_specs() -> list[dict[str, Any]]:
    """필요 변수는 원의 반지름과 수평선 높이다. 작동 원리는 원과 직선의 교점 좌표로 현의 길이를 구하는 난이도 4 문제 5개를 만든다."""
    rows = [(5, 3), (5, 4), (13, 5), (10, 6), (17, 8)]
    specs = []
    for index, (radius, height) in enumerate(rows, 6):
        half_square = radius**2 - height**2
        half_length = int(half_square**0.5)
        answer = 2 * half_length
        specs.append(
            _problem(
                4,
                index,
                title=rf"원 $x^2+y^2={radius**2}$과 직선 $y={height}$의 두 교점을 $A,B$라 할 때, 현 $AB$의 길이를 구하시오.",
                answer=str(answer),
                tags=["#원의방정식", "#직선의방정식", "#이차방정식", "#두점사이의거리"],
                steps=[
                    ("직선의 y좌표를 원의 방정식에 대입한다.", rf"$x^2+{height}^2={radius**2}$이다."),
                    ("교점의 x좌표 제곱을 구한다.", rf"$x^2={radius**2}-{height**2}={half_square}$이다."),
                    ("두 교점의 x좌표를 구한다.", rf"$x=\pm{half_length}$이므로 교점은 $(-{half_length},{height})$, $({half_length},{height})$이다."),
                    ("두 교점은 같은 수평선 위에 있음을 이용한다.", rf"현의 길이는 x좌표 차인 ${half_length}-(-{half_length})$이다."),
                    ("좌표 차를 계산해 길이를 구한다.", rf"따라서 $AB={answer}$이다."),
                ],
                alternatives=[rf"중심에서 현에 내린 수선의 길이가 ${height}$이므로 피타고라스 정리로 반현의 길이 ${half_length}$를 구할 수 있다."],
            )
        )
    return specs


def _cubic_area_specs() -> list[dict[str, Any]]:
    """필요 변수는 삼차함수 극점의 양의 위치다. 작동 원리는 두 극점을 잇는 직선과 곡선 사이 넓이를 구하는 난이도 5 문제 5개를 만든다."""
    specs = []
    for index, parameter in enumerate(range(1, 6), 1):
        coefficient = 3 * parameter**2
        answer = parameter**4
        specs.append(
            _problem(
                5,
                index,
                title=rf"함수 $f(x)=x^3-{coefficient}x$의 극대점과 극소점을 잇는 직선과 함수의 그래프로 둘러싸인 넓이를 $S$라 할 때, $2S$의 값을 구하시오.",
                answer=str(answer),
                tags=["#함수의극대와극소", "#도함수의부호", "#직선의방정식", "#두곡선사이의넓이", "#정적분"],
                steps=[
                    ("도함수로 두 극점의 x좌표를 구한다.", rf"$f'(x)=3(x^2-{parameter**2})$이므로 임계점은 $x=-{parameter},{parameter}$이다."),
                    ("두 극점의 좌표를 계산한다.", rf"극대점은 $(-{parameter},{2 * parameter**3})$, 극소점은 $({parameter},{-2 * parameter**3})$이다."),
                    ("두 극점을 잇는 직선의 방정식을 구한다.", rf"기울기는 $-{2 * parameter**2}$이고 원점을 지나므로 직선은 $y=-{2 * parameter**2}x$이다."),
                    ("두 그래프의 차와 대칭성을 확인한다.", rf"차는 $x(x^2-{parameter**2})$이고 교점은 $-{parameter},0,{parameter}$이며 넓이는 원점에 대해 대칭이다."),
                    ("한쪽 넓이를 두 배하여 전체 넓이를 적분한다.", rf"$S=2\int_0^{{{parameter}}}({parameter**2}x-x^3)\,dx=\dfrac{{{parameter**4}}}2$이다."),
                    ("문제에서 요구한 배수를 계산한다.", rf"따라서 $2S={answer}$이다."),
                ],
                alternatives=[
                    rf"차이 함수 $x(x^2-{parameter**2})$가 홀함수이므로 양쪽 넓이가 같음을 먼저 이용할 수 있다.",
                    rf"치환 $x={parameter}t$를 사용하면 넓이가 ${parameter**4}$에 비례하고 $S={parameter**4}/2$임을 얻는다.",
                ],
            )
        )
    return specs


def _removable_continuity_specs() -> list[dict[str, Any]]:
    """필요 변수는 빠진 점과 주어진 함숫값이다. 작동 원리는 연속 조건으로 세 상수를 복원해 제곱합을 구하는 난이도 5 문제 5개를 만든다."""
    rows = [(1, 3), (2, 1), (-3, 2), (3, 2), (-2, 3)]
    specs = []
    for index, (removed_point, value_at_zero) in enumerate(rows, 6):
        coefficient = value_at_zero - removed_point
        constant = -removed_point * value_at_zero
        filled_value = removed_point + value_at_zero
        answer = coefficient**2 + constant**2 + filled_value**2
        specs.append(
            _problem(
                5,
                index,
                title=rf"함수 $f(x)=\begin{{cases}}\dfrac{{x^2+ax+b}}{{x-({removed_point})}}&(x\ne {removed_point})\\c&(x={removed_point})\end{{cases}}$가 실수 전체에서 연속이고 $f(0)={value_at_zero}$일 때, $a^2+b^2+c^2$을 구하시오.",
                answer=str(answer),
                tags=["#함수의극한", "#극한의성질", "#인수분해를이용한극한", "#미정계수법", "#함수의연속"],
                steps=[
                    ("주어진 f(0)의 값으로 상수항 b를 구한다.", rf"$f(0)=\dfrac{{b}}{{-{removed_point}}}={value_at_zero}$이므로 $b={constant}$이다."),
                    ("빠진 점에서 유한한 극한이 존재할 분자 조건을 세운다.", rf"$({removed_point})^2+a({removed_point})+b=0$이어야 한다."),
                    ("이미 구한 b를 대입해 a를 구한다.", rf"${removed_point**2}+({removed_point})a+({constant})=0$에서 $a={coefficient}$이다."),
                    ("분자를 인수분해하고 공통 인수를 약분한다.", rf"$x^2+({coefficient})x+({constant})=(x-({removed_point}))(x+{value_at_zero})$이므로 $x\ne{removed_point}$에서 $f(x)=x+{value_at_zero}$이다."),
                    ("연속 조건으로 빠진 점의 함숫값 c를 정한다.", rf"$c=\lim_{{x\to {removed_point}}}f(x)={removed_point}+({value_at_zero})={filled_value}$이다."),
                    ("세 상수의 제곱합을 계산한다.", rf"$a^2+b^2+c^2=({coefficient})^2+({constant})^2+({filled_value})^2={answer}$이다."),
                ],
                alternatives=[
                    rf"분자가 $x-({removed_point})$를 인수로 가져야 한다는 인수정리로 $a={coefficient}$을 구할 수 있다.",
                    rf"약분 뒤 직선 $y=x+{value_at_zero}$의 구멍을 $({removed_point},{filled_value})$로 채운다고 보면 $c={filled_value}$이다.",
                ],
            )
        )
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도 1~5별 10문항씩 총 50개의 다섯 번째 직접 출제 명세를 반환하는 것이다."""
    return [
        *_remainder_specs(),
        *_composition_specs(),
        *_distance_specs(),
        *_exponential_specs(),
        *_factor_theorem_specs(),
        *_rational_asymptote_specs(),
        *_geometric_log_specs(),
        *_circle_chord_specs(),
        *_cubic_area_specs(),
        *_removable_continuity_specs(),
    ]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v5 카탈로그와 배치 기준값이다. 작동 원리는 50문항을 생산 형식으로 조립하고 전수 품질 검사를 수행하는 것이다."""
    return validate_problem_batch(
        build_catalog(),
        expected_count=50,
        batch_id=BATCH_ID,
        model_name=MODEL_NAME,
        codebase_base=CODEBASE_BASE,
        seed_base=SEED_BASE,
    )


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 대상 DB와 검증 모드다. 작동 원리는 검증된 v5 문제를 로컬 DB에 멱등 저장하고 재조회한다."""
    return seed_problem_batch(
        db_path,
        quests=validated_quests(),
        batch_id=BATCH_ID,
        validate_only=validate_only,
    )


def main() -> None:
    """필요 변수는 DB 경로와 검증 옵션이다. 작동 원리는 난이도별 v5 직접 출제 결과를 UTF-8 JSON으로 출력하는 것이다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
