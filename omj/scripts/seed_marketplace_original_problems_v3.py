from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.marketplace_problem_batch import (
    seed_problem_batch,
    validate_problem_batch,
)
from scripts.seed_initial_math_problems import _problem


BATCH_ID = "marketplace-original-v3"
MODEL_NAME = "aiflow-direct-authoring-v3"
CODEBASE_BASE = 20_260_719_000
SEED_BASE = 202_607_190_000


def _complex_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 복소수의 실수부·허수부다. 작동 원리는 복소수 덧셈 후 실수부를 찾는 난이도 1 문제 5개를 만든다."""
    rows = [(2, 3, 4, -1), (-3, 5, 7, 2), (1, -4, -6, 3), (8, 1, -5, -2), (-2, -3, -4, 6)]
    specs = []
    for index, (a, b, c, d) in enumerate(rows, 1):
        real, imaginary = a + c, b + d
        specs.append(
            _problem(
                1,
                index,
                title=rf"복소수 $({a}+({b})i)+({c}+({d})i)$의 실수부를 구하시오.",
                answer=str(real),
                tags=["#복소수의연산"],
                steps=[
                    ("실수부와 허수부끼리 각각 더한다.", rf"합은 $({a}+({c}))+(({b})+({d}))i={real}+({imaginary})i$이다."),
                    ("정리된 복소수에서 실수부를 읽는다.", rf"실수부는 ${real}$이다."),
                ],
            )
        )
    return specs


def _factorial_specs() -> list[dict[str, Any]]:
    """필요 변수는 4 이상 정수 n이다. 작동 원리는 팩토리얼 약분으로 값을 구하는 난이도 1 문제 5개를 만든다."""
    specs = []
    for index, n in enumerate(range(4, 9), 6):
        answer = n * (n - 1)
        specs.append(
            _problem(
                1,
                index,
                title=rf"$\dfrac{{{n}!}}{{({n}-2)!}}$의 값을 구하시오.",
                answer=str(answer),
                tags=["#팩토리얼"],
                steps=[
                    ("분자의 팩토리얼을 분모가 보이도록 전개한다.", rf"${n}!={n}\cdot({n}-1)\cdot({n}-2)!$이다."),
                    ("공통 팩토리얼을 약분하고 계산한다.", rf"$\dfrac{{{n}!}}{{({n}-2)!}}={n}\cdot({n}-1)={answer}$이다."),
                ],
            )
        )
    return specs


def _discriminant_specs() -> list[dict[str, Any]]:
    """필요 변수는 이차방정식 계수다. 작동 원리는 판별식 부호로 서로 다른 실근 개수를 정하는 난이도 2 문제 5개를 만든다."""
    rows = [(5, 6), (4, 4), (2, 5), (-6, 8), (10, 25)]
    specs = []
    for index, (b, c) in enumerate(rows, 1):
        discriminant = b * b - 4 * c
        answer = 2 if discriminant > 0 else 1 if discriminant == 0 else 0
        specs.append(
            _problem(
                2,
                index,
                title=rf"이차방정식 $x^2+({b})x+({c})=0$의 서로 다른 실근의 개수를 구하시오.",
                answer=str(answer),
                tags=["#이차방정식의판별식", "#판별식과근의개수"],
                steps=[
                    ("이차방정식의 판별식을 적는다.", r"계수가 $1,b,c$일 때 판별식은 $D=b^2-4c$이다."),
                    ("주어진 계수로 판별식을 계산한다.", rf"$D=({b})^2-4({c})={discriminant}$이다."),
                    ("판별식의 부호에 따라 실근 개수를 판정한다.", rf"따라서 서로 다른 실근의 개수는 ${answer}$개이다."),
                ],
            )
        )
    return specs


def _geometric_specs() -> list[dict[str, Any]]:
    """필요 변수는 첫째항·공비·항 번호다. 작동 원리는 일반항 공식을 적용하는 난이도 2 문제 5개를 만든다."""
    rows = [(2, 3, 5), (5, 2, 6), (3, -2, 5), (1, 4, 4), (-2, 3, 4)]
    specs = []
    for index, (first, ratio, n) in enumerate(rows, 6):
        answer = first * ratio ** (n - 1)
        specs.append(
            _problem(
                2,
                index,
                title=rf"첫째항이 ${first}$이고 공비가 ${ratio}$인 등비수열 $\{{a_n\}}$에서 $a_{n}$을 구하시오.",
                answer=str(answer),
                tags=["#등비수열", "#등비수열의일반항"],
                steps=[
                    ("등비수열의 일반항 공식을 적는다.", r"$a_n=a_1r^{n-1}$이다."),
                    ("첫째항, 공비, 항 번호를 대입한다.", rf"$a_{n}={first}\cdot({ratio})^{{{n - 1}}}$이다."),
                    ("거듭제곱과 곱셈을 계산한다.", rf"따라서 $a_{n}={answer}$이다."),
                ],
            )
        )
    return specs


def _set_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 유한집합이다. 작동 원리는 교집합과 포함배제 원리로 합집합 원소 수를 구하는 난이도 3 문제 5개를 만든다."""
    rows = [
        ({1, 2, 3, 4}, {3, 4, 5}),
        ({2, 4, 6, 8}, {1, 2, 3, 4}),
        ({1, 3, 5, 7, 9}, {3, 6, 9}),
        ({-2, -1, 0, 1}, {0, 1, 2, 3}),
        ({1, 2, 4, 8}, {2, 4, 6, 8, 10}),
    ]
    specs = []
    for index, (left, right) in enumerate(rows, 1):
        intersection = left & right
        answer = len(left | right)
        left_text = ",".join(map(str, sorted(left)))
        right_text = ",".join(map(str, sorted(right)))
        intersection_text = ",".join(map(str, sorted(intersection)))
        specs.append(
            _problem(
                3,
                index,
                title=rf"집합 $A=\{{{left_text}\}}$, $B=\{{{right_text}\}}$일 때, $n(A\cup B)$를 구하시오.",
                answer=str(answer),
                tags=["#집합의연산", "#합집합", "#교집합"],
                steps=[
                    ("두 집합에 공통으로 들어 있는 원소를 찾는다.", rf"$A\cap B=\{{{intersection_text}\}}$이므로 $n(A\cap B)={len(intersection)}$이다."),
                    ("각 집합의 원소 수를 센다.", rf"$n(A)={len(left)}$, $n(B)={len(right)}$이다."),
                    ("합집합 원소 수 공식을 적용한다.", r"$n(A\cup B)=n(A)+n(B)-n(A\cap B)$이다."),
                    ("세 원소 수를 대입해 계산한다.", rf"$n(A\cup B)={len(left)}+{len(right)}-{len(intersection)}={answer}$이다."),
                ],
                alternatives=[rf"두 집합의 원소를 한 번씩만 직접 나열해도 합집합의 원소가 ${answer}$개임을 확인할 수 있다."],
            )
        )
    return specs


def _arithmetic_sum_specs() -> list[dict[str, Any]]:
    """필요 변수는 첫째항·공차·항 수다. 작동 원리는 끝항과 합 공식을 연결하는 난이도 3 문제 5개를 만든다."""
    rows = [(2, 3, 8), (5, 2, 10), (-1, 4, 7), (10, -1, 6), (3, 5, 9)]
    specs = []
    for index, (first, difference, n) in enumerate(rows, 6):
        last = first + (n - 1) * difference
        answer = n * (first + last) // 2
        specs.append(
            _problem(
                3,
                index,
                title=rf"첫째항이 ${first}$이고 공차가 ${difference}$인 등차수열의 첫 ${n}$개 항의 합을 구하시오.",
                answer=str(answer),
                tags=["#등차수열", "#등차수열의합", "#합의기호시그마"],
                steps=[
                    ("마지막 항을 일반항으로 계산한다.", rf"$a_{n}={first}+({n}-1)({difference})={last}$이다."),
                    ("등차수열의 합 공식을 적는다.", r"$S_n=\dfrac{n(a_1+a_n)}2$이다."),
                    ("항 수와 양 끝항을 공식에 대입한다.", rf"$S_{n}=\dfrac{{{n}({first}+({last}))}}2$이다."),
                    ("식을 계산한다.", rf"따라서 합은 ${answer}$이다."),
                ],
                alternatives=["첫째 항과 마지막 항, 둘째 항과 끝에서 둘째 항을 짝지으면 각 쌍의 합이 일정하다는 방법으로도 구할 수 있다."],
            )
        )
    return specs


def _integral_coefficient_specs() -> list[dict[str, Any]]:
    """필요 변수는 적분 상한·미정계수·적분값이다. 작동 원리는 정적분 조건에서 계수를 복원하는 난이도 4 문제 5개를 만든다."""
    rows = [(1, 2), (2, -1), (3, 3), (4, 4), (5, -2)]
    specs = []
    for index, (upper, parameter) in enumerate(rows, 1):
        value = upper * upper + parameter * upper
        specs.append(
            _problem(
                4,
                index,
                title=rf"상수 $a$에 대하여 $\int_0^{upper}(2x+a)\,dx={value}$일 때, $a$를 구하시오.",
                answer=str(parameter),
                tags=["#정적분", "#정적분의계산", "#정적분의선형성", "#미정계수법"],
                steps=[
                    ("피적분함수의 부정적분을 구한다.", r"$\int(2x+a)dx=x^2+ax$이다."),
                    ("정적분의 위끝과 아래끝을 대입한다.", rf"$\int_0^{upper}(2x+a)dx={upper}^2+{upper}a$이다."),
                    ("주어진 적분값과 같게 놓는다.", rf"${upper * upper}+{upper}a={value}$이다."),
                    ("일차방정식을 정리한다.", rf"${upper}a={value - upper * upper}$이다."),
                    ("계수를 계산한다.", rf"따라서 $a={parameter}$이다."),
                ],
                alternatives=[rf"함수 $2x+a$의 구간 평균값은 ${upper}+a$이므로 적분값 ${upper}({upper}+a)={value}$에서 같은 답을 얻는다."],
            )
        )
    return specs


def _quadratic_minimum_specs() -> list[dict[str, Any]]:
    """필요 변수는 양의 매개변수·상수항·최솟값이다. 작동 원리는 완전제곱으로 매개변수를 복원하는 난이도 4 문제 5개를 만든다."""
    rows = [(1, 6), (2, 10), (3, 20), (4, 30), (5, 40)]
    specs = []
    for index, (parameter, constant) in enumerate(rows, 6):
        minimum = constant - parameter * parameter
        specs.append(
            _problem(
                4,
                index,
                title=rf"$a>0$이고 이차함수 $f(x)=x^2-2ax+{constant}$의 최솟값이 ${minimum}$일 때, $a$를 구하시오.",
                answer=str(parameter),
                tags=["#이차함수", "#완성제곱법", "#꼭짓점", "#이차함수의최대최소"],
                steps=[
                    ("x에 관한 식을 완전제곱한다.", rf"$f(x)=(x-a)^2+{constant}-a^2$이다."),
                    ("제곱항의 최소 가능 값을 확인한다.", r"$(x-a)^2\ge0$이므로 $x=a$에서 최소가 된다."),
                    ("함수의 최솟값을 매개변수로 나타낸다.", rf"최솟값은 ${constant}-a^2$이다."),
                    ("주어진 최솟값과 같게 놓는다.", rf"${constant}-a^2={minimum}$이므로 $a^2={parameter * parameter}$이다."),
                    ("양수 조건으로 값을 결정한다.", rf"$a>0$이므로 $a={parameter}$이다."),
                ],
                alternatives=[rf"꼭짓점의 x좌표가 $a$이고 함숫값이 ${constant}-a^2$임을 바로 사용해도 $a={parameter}$이다."],
            )
        )
    return specs


def _line_parabola_area_specs() -> list[dict[str, Any]]:
    """필요 변수는 양의 직선 기울기다. 작동 원리는 직선과 포물선 사이 넓이에서 매개변수를 찾는 난이도 5 문제 5개를 만든다."""
    specs = []
    for index, parameter in enumerate(range(1, 6), 1):
        numerator = parameter**3
        area_latex = str(numerator // 6) if numerator % 6 == 0 else rf"\frac{{{numerator}}}6"
        specs.append(
            _problem(
                5,
                index,
                title=rf"$a>0$이고 곡선 $y=x^2$과 직선 $y=ax$로 둘러싸인 부분의 넓이가 ${area_latex}$일 때, $a$를 구하시오.",
                answer=str(parameter),
                tags=["#정적분", "#두곡선사이의넓이", "#이차함수", "#이차함수의그래프", "#정적분의계산"],
                steps=[
                    ("두 그래프의 교점 x좌표를 구한다.", r"$x^2=ax$에서 $x(x-a)=0$이므로 $x=0,a$이다."),
                    ("두 교점 사이에서 위쪽 그래프를 판단한다.", r"$0<x<a$에서 $ax-x^2=x(a-x)>0$이므로 직선이 위에 있다."),
                    ("두 함수의 차를 정적분해 넓이를 나타낸다.", r"$S=\int_0^a(ax-x^2)\,dx$이다."),
                    ("부정적분을 계산한다.", r"$\int(ax-x^2)dx=\frac{ax^2}{2}-\frac{x^3}{3}$이다."),
                    ("적분 구간을 대입해 넓이식을 얻는다.", r"$S=\frac{a^3}{2}-\frac{a^3}{3}=\frac{a^3}{6}$이다."),
                    ("주어진 넓이와 양수 조건으로 값을 결정한다.", rf"$\frac{{a^3}}6={area_latex}$이고 $a>0$이므로 $a={parameter}$이다."),
                ],
                alternatives=[
                    r"$x=at$로 치환하면 넓이는 $a^3\int_0^1(t-t^2)dt=\frac{a^3}{6}$이다.",
                    rf"두 그래프 사이의 세로 높이가 $x(a-x)$임을 이용해 대칭 구간 적분을 계산해도 $a={parameter}$이다.",
                ],
            )
        )
    return specs


def _cubic_extrema_specs() -> list[dict[str, Any]]:
    """필요 변수는 양의 완전제곱 매개변수다. 작동 원리는 삼차함수 두 극값 차로 매개변수를 복원하는 난이도 5 문제 5개를 만든다."""
    specs = []
    for index, root in enumerate(range(1, 6), 6):
        parameter = root * root
        difference = 4 * root**3
        specs.append(
            _problem(
                5,
                index,
                title=rf"$a>0$이고 함수 $f(x)=x^3-3ax$의 극댓값과 극솟값의 차가 ${difference}$일 때, $a$를 구하시오.",
                answer=str(parameter),
                tags=["#도함수", "#함수의극대와극소", "#도함수의부호", "#극값의판정", "#미정계수법"],
                steps=[
                    ("함수를 미분한다.", r"$f'(x)=3x^2-3a=3(x^2-a)$이다."),
                    ("도함수가 0이 되는 임계점을 구한다.", r"$a>0$이므로 임계점은 $x=-\sqrt a,\sqrt a$이다."),
                    ("도함수 부호로 극대와 극소를 판정한다.", r"$x=-\sqrt a$에서 극대, $x=\sqrt a$에서 극소이다."),
                    ("두 임계점의 함숫값을 계산한다.", r"극댓값은 $2a\sqrt a$, 극솟값은 $-2a\sqrt a$이다."),
                    ("두 극값의 차를 조건과 비교한다.", rf"$4a\sqrt a={difference}$이다."),
                    ("양수 조건 아래 매개변수를 결정한다.", rf"$a=({root})^2={parameter}$이면 $4a\sqrt a={difference}$이므로 $a={parameter}$이다."),
                ],
                alternatives=[
                    r"함수가 홀함수이므로 극댓값과 극솟값은 절댓값이 같고 부호만 반대임을 이용할 수 있다.",
                    rf"$u=\sqrt a>0$로 두면 $4u^3={difference}$에서 $u={root}$, 따라서 $a={parameter}$이다.",
                ],
            )
        )
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도 1~5별 10문항씩 총 50개의 세 번째 직접 출제 명세를 반환하는 것이다."""
    return [
        *_complex_specs(),
        *_factorial_specs(),
        *_discriminant_specs(),
        *_geometric_specs(),
        *_set_specs(),
        *_arithmetic_sum_specs(),
        *_integral_coefficient_specs(),
        *_quadratic_minimum_specs(),
        *_line_parabola_area_specs(),
        *_cubic_extrema_specs(),
    ]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v3 카탈로그와 배치 기준값이다. 작동 원리는 50문항을 생산 형식으로 조립하고 전수 품질 검사를 수행하는 것이다."""
    return validate_problem_batch(
        build_catalog(),
        expected_count=50,
        batch_id=BATCH_ID,
        model_name=MODEL_NAME,
        codebase_base=CODEBASE_BASE,
        seed_base=SEED_BASE,
    )


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 대상 DB와 검증 모드다. 작동 원리는 검증된 v3 문제를 로컬 DB에 멱등 저장하고 재조회한다."""
    return seed_problem_batch(
        db_path,
        quests=validated_quests(),
        batch_id=BATCH_ID,
        validate_only=validate_only,
    )


def main() -> None:
    """필요 변수는 DB 경로와 검증 옵션이다. 작동 원리는 난이도별 v3 직접 출제 결과를 UTF-8 JSON으로 출력하는 것이다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()

