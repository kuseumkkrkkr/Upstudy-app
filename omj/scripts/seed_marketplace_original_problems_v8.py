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

BATCH_ID = "marketplace-original-v8"
MODEL_NAME = "aiflow-direct-authoring-v8"
CODEBASE_BASE = 20_260_724_000
SEED_BASE = 202_607_240_000


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 지수 곱과 등차중항 수치다. 작동 원리는 두 단계 계산형 난이도 1 문제 10개를 만든다."""
    specs = []
    for index, (base, p, q) in enumerate([(2, 3, 4), (3, 2, 3), (5, 1, 3), (4, 2, 2), (10, 2, 1)], 1):
        answer = base ** (p + q)
        specs.append(_problem(1, index, title=rf"같은 밑의 거듭제곱 ${base}^{p}\cdot{base}^{q}$의 값을 구하시오.", answer=str(answer), tags=["#지수법칙"], steps=[("곱의 지수법칙을 적용한다.", rf"${base}^{p}\cdot{base}^{q}={base}^{{{p + q}}}$이다."), ("거듭제곱을 계산한다.", rf"따라서 값은 ${answer}$이다.")]))
    for index, (first, fifth) in enumerate([(1, 17), (-4, 12), (3, 23), (10, -2), (-7, 21)], 6):
        answer = (first + fifth) // 2
        specs.append(_problem(1, index, title=rf"등차수열에서 첫째항이 ${first}$, 다섯째항이 ${fifth}$일 때, 셋째항을 구하시오.", answer=str(answer), tags=["#등차수열"], steps=[("등차수열의 대칭인 두 항의 평균을 이용한다.", rf"$2a_3=a_1+a_5={first}+({fifth})$이다."), ("양변을 2로 나눈다.", rf"따라서 $a_3={answer}$이다.")]))
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 점과 이차방정식 계수다. 작동 원리는 세 단계 적용형 난이도 2 문제 10개를 만든다."""
    specs = []
    for index, (x1, y1, x2, y2) in enumerate([(0, 2, 2, 10), (-1, 3, 3, -5), (2, -4, 7, 11), (-3, 8, 1, 20), (4, 1, -2, 13)], 1):
        answer = (y2 - y1) // (x2 - x1)
        specs.append(_problem(2, index, title=rf"점 $A({x1},{y1})$, $B({x2},{y2})$를 지나는 직선의 기울기를 구하시오.", answer=str(answer), tags=["#두점을지나는직선", "#기울기"], steps=[("y좌표 변화량을 구한다.", rf"$\Delta y={y2 - y1}$이다."), ("x좌표 변화량을 구한다.", rf"$\Delta x={x2 - x1}$이다."), ("두 변화량의 비를 계산한다.", rf"기울기는 $\Delta y/\Delta x={answer}$이다.")]))
    for index, coefficient in enumerate([12, -14, 16, -18, 20], 6):
        answer = coefficient * coefficient // 4
        specs.append(_problem(2, index, title=rf"방정식 $x^2+({coefficient})x+k=0$이 하나의 실근만 가질 때, $k$를 구하시오.", answer=str(answer), tags=["#이차방정식의판별식", "#판별식과근의개수"], steps=[("하나의 실근을 갖는 판별식 조건을 확인한다.", r"중근이므로 $D=0$이다."), ("계수를 판별식에 대입한다.", rf"$({coefficient})^2-4k=0$이다."), ("방정식을 풀어 상수를 구한다.", rf"따라서 $k={answer}$이다.")]))
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 제곱합 상한과 원의 중심·반지름이다. 작동 원리는 네 단계와 한 분기를 갖는 난이도 3 문제 10개를 만든다."""
    specs = []
    for index, n in enumerate(range(8, 13), 1):
        answer = n * (n + 1) * (2 * n + 1) // 6
        specs.append(_problem(3, index, title=rf"자연수 제곱의 합 $1^2+2^2+\cdots+{n}^2$의 값을 구하시오.", answer=str(answer), tags=["#수열의표현", "#시그마공식", "#자연수의거듭제곱의합"], steps=[("제곱합 공식을 적는다.", r"$\sum_{k=1}^n k^2=n(n+1)(2n+1)/6$이다."), ("상한을 대입한다.", rf"$\sum_{{k=1}}^{n}k^2={n}({n + 1})({2 * n + 1})/6$이다."), ("분자의 곱을 계산한다.", rf"분자는 ${n * (n + 1) * (2 * n + 1)}$이다."), ("6으로 나눈다.", rf"따라서 합은 ${answer}$이다.")], alternatives=["각 제곱수를 직접 더해 결과를 검산할 수 있다."]))
    for index, (h, k, radius) in enumerate([(6, -1, 2), (-4, 5, 3), (2, -6, 4), (-5, -3, 2), (7, 1, 5)], 6):
        d, e, f = -2 * h, -2 * k, h * h + k * k - radius * radius
        answer = h + k
        specs.append(_problem(3, index, title=rf"원 $x^2+y^2+({d})x+({e})y+({f})=0$의 중심 좌표의 합을 구하시오.", answer=str(answer), tags=["#원의일반형", "#일반형을표준형으로", "#원의표준형"], steps=[("x항으로 중심의 x좌표를 구한다.", rf"중심의 x좌표는 $-({d})/2={h}$이다."), ("y항으로 중심의 y좌표를 구한다.", rf"중심의 y좌표는 $-({e})/2={k}$이다."), ("완전제곱으로 중심을 확인한다.", rf"표준형의 중심은 $({h},{k})$이다."), ("두 좌표를 더한다.", rf"따라서 좌표합은 ${answer}$이다.")], alternatives=["일반형의 일차항 계수를 절반으로 나누고 부호를 바꾸어 바로 구할 수 있다."]))
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 정적분 계수와 이차함수 매개변수다. 작동 원리는 다섯 단계와 한 분기를 갖는 난이도 4 문제 10개를 만든다."""
    specs = []
    for index, (upper, answer) in enumerate([(2, 5), (3, -2), (4, 3), (5, 1), (6, -1)], 1):
        value = upper * upper + answer * upper
        specs.append(_problem(4, index, title=rf"$\int_0^{upper}(2x+a)\,dx={value}$일 때, 상수 $a$를 구하시오.", answer=str(answer), tags=["#정적분", "#정적분의계산", "#정적분의선형성", "#미정계수법"], steps=[("부정적분을 구한다.", r"$\int(2x+a)dx=x^2+ax$이다."), ("적분 구간을 대입한다.", rf"정적분은 ${upper * upper}+{upper}a$이다."), ("주어진 값과 같게 놓는다.", rf"${upper * upper}+{upper}a={value}$이다."), ("일차방정식을 정리한다.", rf"${upper}a={value - upper * upper}$이다."), ("상수를 계산한다.", rf"따라서 $a={answer}$이다.")], alternatives=["직선의 구간 평균값과 구간 길이의 곱으로도 정적분을 계산할 수 있다."]))
    for index, (answer, constant) in enumerate([(7, 55), (8, 70), (9, 90), (10, 115), (11, 130)], 6):
        minimum = constant - answer * answer
        specs.append(_problem(4, index, title=rf"$a>0$이고 $f(x)=x^2-2ax+{constant}$의 최솟값이 ${minimum}$일 때, $a$를 구하시오.", answer=str(answer), tags=["#이차함수의최대최소", "#완성제곱법", "#꼭짓점", "#미정계수법"], steps=[("완전제곱한다.", rf"$f(x)=(x-a)^2+{constant}-a^2$이다."), ("제곱항의 최솟값을 확인한다.", r"$(x-a)^2$의 최솟값은 0이다."), ("함수의 최솟값을 나타낸다.", rf"최솟값은 ${constant}-a^2$이다."), ("주어진 조건과 같게 놓는다.", rf"$a^2={answer * answer}$이다."), ("양수 조건을 적용한다.", rf"따라서 $a={answer}$이다.")], alternatives=["꼭짓점의 함숫값을 바로 대입해도 같은 방정식을 얻는다."]))
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 지수그래프 밑과 제거가능 불연속 상수다. 작동 원리는 여섯 단계와 두 분기를 갖는 난이도 5 문제 10개를 만든다."""
    specs = []
    for index, base in enumerate(range(7, 12), 1):
        rise, square = base - 1, 1 + (base - 1) ** 2
        specs.append(_problem(5, index, title=rf"$y={base}^x$ 위의 $A(0,1)$, $B(1,{base})$에 대하여 A를 지나고 AB에 수직인 직선과 원점 사이 거리를 $d$라 할 때, $ABd$를 구하시오.", answer=str(rise), tags=["#지수함수의그래프", "#두점사이의거리", "#점과직선사이의거리", "#직선의방정식", "#기울기"], steps=[("AB의 길이를 구한다.", rf"$AB=\sqrt{{{square}}}$이다."), ("AB의 방향벡터를 구한다.", rf"방향벡터는 $(1,{rise})$이다."), ("수직선의 방정식을 구한다.", rf"$x+{rise}y-{rise}=0$이다."), ("원점과 직선 사이 거리를 구한다.", rf"$d={rise}/\sqrt{{{square}}}$이다."), ("길이와 거리를 곱한다.", rf"$ABd=\sqrt{{{square}}}\cdot {rise}/\sqrt{{{square}}}$이다."), ("공통인수를 약분한다.", rf"따라서 $ABd={rise}$이다.")], alternatives=["삼각형 넓이를 밑변과 높이로 나타내어 구할 수 있다.", "두 벡터의 행렬식 절댓값으로 같은 곱을 구할 수 있다."]))
    for index, (r, d) in enumerate([(4, 3), (-4, 2), (5, 1), (-5, 3), (6, 2)], 6):
        a, b, c = d - r, -r * d, r + d
        answer = a * a + b * b + c * c
        specs.append(_problem(5, index, title=rf"$f(x)=\begin{{cases}}\dfrac{{x^2+ax+b}}{{x-({r})}}&(x\ne {r})\\c&(x={r})\end{{cases}}$가 연속이고 $f(0)={d}$일 때, $a^2+b^2+c^2$을 구하시오.", answer=str(answer), tags=["#함수의극한", "#극한의성질", "#인수분해를이용한극한", "#미정계수법", "#함수의연속"], steps=[("f(0)으로 b를 구한다.", rf"$b={b}$이다."), ("분자가 빠진 점에서 0이 되게 한다.", rf"${r * r}+{r}a+({b})=0$이다."), ("a를 계산한다.", rf"$a={a}$이다."), ("분자를 인수분해한다.", rf"분자는 $(x-({r}))(x+{d})$이다."), ("연속 조건으로 c를 구한다.", rf"$c={r}+({d})={c}$이다."), ("세 상수의 제곱합을 구한다.", rf"$a^2+b^2+c^2={answer}$이다.")], alternatives=["인수정리로 분자가 분모를 인수로 갖게 할 수 있다.", "약분 뒤 직선의 빠진 점을 채우는 관점으로 c를 구할 수 있다."]))
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v8 직접 출제 명세를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v8 카탈로그다. 작동 원리는 생산 형식 조립과 전수 품질 검사를 수행한다."""
    return validate_problem_batch(build_catalog(), expected_count=50, batch_id=BATCH_ID, model_name=MODEL_NAME, codebase_base=CODEBASE_BASE, seed_base=SEED_BASE)


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v8 문제를 멱등 저장하고 재조회한다."""
    return seed_problem_batch(db_path, quests=validated_quests(), batch_id=BATCH_ID, validate_only=validate_only)


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 v8 생산 결과를 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser(); parser.add_argument("--db", type=Path, default=ROOT / "quests.db"); parser.add_argument("--validate-only", action="store_true"); args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
