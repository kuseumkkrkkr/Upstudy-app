from __future__ import annotations

import argparse
import json
import math
import sys
from fractions import Fraction
from pathlib import Path
from typing import Any, Callable

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.marketplace_problem_batch import seed_problem_batch, validate_problem_batch
from scripts.seed_initial_math_problems import _problem

BATCH_ID = "marketplace-original-v21"
MODEL_NAME = "aiflow-direct-authoring-v21"
CODEBASE_BASE = 20_260_982_000
SEED_BASE = 202_607_561_000


def _checked_problem(
    tier: int,
    index: int,
    *,
    answer_check: Callable[[], Any],
    **kwargs: Any,
) -> dict[str, Any]:
    """필요 변수는 문제 명세와 독립 계산 함수다. 작동 원리는 공통 검증기가 저장 답과 별도 계산 결과를 비교하도록 검산 함수를 부착한다."""
    spec = _problem(tier, index, **kwargs)
    spec["answer_check"] = answer_check
    return spec


def _polynomial_difference_constant(left: tuple[int, int, int], right: tuple[int, int, int]) -> int:
    """필요 변수는 두 이차다항식의 내림차순 계수다. 작동 원리는 오른쪽 다항식의 상수항을 왼쪽 상수항에서 빼 차의 상수항을 구한다."""
    return left[2] - right[2]


def _perfect_square_linear(shift: int) -> int:
    """필요 변수는 일차식의 상수항이다. 작동 원리는 이항정리로 완전제곱식의 일차항 계수 2k를 계산한다."""
    return 2 * shift


def _complex_component_sum(first: tuple[int, int], second: tuple[int, int]) -> int:
    """필요 변수는 두 복소수의 실수부·허수부다. 작동 원리는 복소수 곱을 전개해 결과의 실수부와 허수부를 더한다."""
    a, b = first
    c, d = second
    real = a * c - b * d
    imaginary = a * d + b * c
    return real + imaginary


def _divisibility_statement_count(multiple: int, divisor: int) -> int:
    """필요 변수는 두 양의 정수다. 작동 원리는 원명제·역·대우의 보편적 참 조건을 나눗셈 관계로 각각 판정한다."""
    original = multiple % divisor == 0
    converse = divisor % multiple == 0
    contrapositive = original
    return sum((original, converse, contrapositive))


def _geometric_sum(first: int, ratio: int, count: int) -> int:
    """필요 변수는 첫째항·공비·항수다. 작동 원리는 실제 항을 순회해 등비수열의 유한합을 독립 계산한다."""
    return sum(first * ratio**index for index in range(count))


def _rational_power(base: int, numerator: int, denominator: int) -> int:
    """필요 변수는 양의 정수 밑과 유리수 지수다. 작동 원리는 정수 후보를 탐색해 거듭제곱 등식 result^q=base^p를 정확히 확인한다."""
    target = base**numerator
    for candidate in range(1, target + 1):
        powered = candidate**denominator
        if powered == target:
            return candidate
        if powered > target:
            break
    raise ValueError("유리수 지수의 값이 정수가 아닙니다.")


def _circular_permutations(people: int) -> int:
    """필요 변수는 서로 다른 사람 수다. 작동 원리는 회전 중복을 제거하기 위해 한 사람을 고정하고 나머지를 순열로 센다."""
    if people < 2:
        raise ValueError("원순열은 두 명 이상이어야 합니다.")
    return math.factorial(people - 1)


def _rationalized_infinite_limit(linear_coefficient: int) -> Fraction:
    """필요 변수는 제곱근 안의 일차항 계수다. 작동 원리는 켤레식 곱셈 뒤 최고차항으로 나누어 무한대 극한을 정확히 구한다."""
    return Fraction(linear_coefficient, 2)


def _log_inequality_integer_sum(base: int, exponent: int, shift: int) -> int:
    """필요 변수는 로그의 밑·상한 지수·진수 이동량이다. 작동 원리는 정의역과 단조성을 적용한 정수 구간을 순회해 합한다."""
    lower = shift + 1
    upper = shift + base**exponent
    return sum(range(lower, upper + 1))


def _velocity_displacement(a: int, b: int, c: int, end_time: int) -> Fraction:
    """필요 변수는 이차 속도함수 계수와 종료 시각이다. 작동 원리는 각 항의 원시함수 값을 0과 종료 시각에서 빼 정확한 변위를 구한다."""
    return Fraction(a * end_time**3, 3) + Fraction(b * end_time**2, 2) + c * end_time


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 다항식 계수와 완전제곱식 이동량이다. 작동 원리는 미사용 태그를 다루는 난이도 1 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    polynomial_rows = [
        ((3, 2, 7), (1, -4, 2)),
        ((-2, 5, -3), (4, 1, 6)),
        ((6, -1, 8), (-3, 2, -5)),
        ((1, 7, -9), (5, -2, 4)),
        ((-4, 3, 12), (2, 6, 7)),
    ]
    for index, (left, right) in enumerate(polynomial_rows, 1):
        answer = _polynomial_difference_constant(left, right)
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"다항식 $P(x)=({left[0]})x^2+({left[1]})x+({left[2]})$, $Q(x)=({right[0]})x^2+({right[1]})x+({right[2]})$에 대하여 $P(x)-Q(x)$의 상수항을 구하시오.",
                answer=str(answer),
                tags=["#다항식의뺄셈", "#다항식"],
                steps=[
                    ("상수항끼리 대응시킨다.", rf"$P(x)$와 $Q(x)$의 상수항은 각각 ${left[2]}$, ${right[2]}$이다."),
                    ("뺄셈 순서에 맞춰 상수항을 계산한다.", rf"따라서 상수항은 ${left[2]}-({right[2]})={answer}$이다."),
                ],
                answer_check=lambda first=left, second=right: _polynomial_difference_constant(first, second),
            )
        )
    for index, shift in enumerate([3, -4, 5, -6, 7], 6):
        answer = _perfect_square_linear(shift)
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"항등식 $(x+({shift}))^2=x^2+ax+({shift**2})$가 성립할 때, 상수 $a$를 구하시오.",
                answer=str(answer),
                tags=["#완전제곱식", "#인수분해공식"],
                steps=[
                    ("완전제곱식을 전개한다.", rf"$(x+({shift}))^2=x^2+2({shift})x+({shift**2})$이다."),
                    ("일차항의 계수를 비교한다.", rf"따라서 $a=2({shift})={answer}$이다."),
                ],
                answer_check=lambda value=shift: _perfect_square_linear(value),
            )
        )
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 복소수 성분과 나눗셈 관계다. 작동 원리는 미사용 태그를 다루는 난이도 2 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    complex_rows = [
        ((1, 2), (3, -1)),
        ((2, -1), (-3, 4)),
        ((-1, 3), (2, 2)),
        ((3, 1), (1, -2)),
        ((4, -1), (2, 3)),
    ]
    for index, (first, second) in enumerate(complex_rows, 1):
        real = first[0] * second[0] - first[1] * second[1]
        imaginary = first[0] * second[1] + first[1] * second[0]
        answer = real + imaginary
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"복소수 $({first[0]}+({first[1]})i)({second[0]}+({second[1]})i)=p+qi$일 때, $p+q$를 구하시오.",
                answer=str(answer),
                tags=["#복소수", "#실수와허수"],
                steps=[
                    ("두 복소수의 곱을 분배법칙으로 전개한다.", rf"실수끼리의 곱과 $i^2=-1$인 항을 함께 정리한다."),
                    ("실수부와 허수부를 각각 계산한다.", rf"$p={real}$, $q={imaginary}$이다."),
                    ("두 성분을 더한다.", rf"따라서 $p+q={real}+({imaginary})={answer}$이다."),
                ],
                answer_check=lambda left=first, right=second: _complex_component_sum(left, right),
            )
        )
    for index, (multiple, divisor) in enumerate([(15, 3), (35, 5), (21, 7), (45, 9), (77, 11)], 6):
        answer = _divisibility_statement_count(multiple, divisor)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"정수 $n$에 대한 명제 $P$: '$n$이 {multiple}의 배수이면 $n$은 {divisor}의 배수이다'와 그 역, 대우 중 참인 명제의 개수를 구하시오.",
                answer=str(answer),
                tags=["#명제", "#대우", "#명제의역과대우", "#명제의참거짓"],
                steps=[
                    ("원명제의 참·거짓을 판정한다.", rf"${multiple}={divisor}\cdot {multiple // divisor}$이므로 원명제는 참이다."),
                    ("원명제의 역을 반례로 판정한다.", rf"$n={divisor}$이면 {divisor}의 배수지만 {multiple}의 배수는 아니므로 역은 거짓이다."),
                    ("대우의 진리값을 원명제와 연결한다.", rf"대우는 원명제와 동치이므로 참이고, 세 명제 중 참인 것은 모두 ${answer}$개이다."),
                ],
                answer_check=lambda m=multiple, d=divisor: _divisibility_statement_count(m, d),
            )
        )
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 등비수열 조건과 유리수 지수다. 작동 원리는 미사용 태그를 다루는 난이도 3 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    for index, (first, ratio, count) in enumerate([(2, 3, 4), (3, 2, 5), (1, 4, 4), (5, 3, 3), (2, 5, 4)], 1):
        answer = _geometric_sum(first, ratio, count)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"첫째항이 ${first}$, 공비가 ${ratio}$인 등비수열의 첫 ${count}$개 항의 합을 구하시오.",
                answer=str(answer),
                tags=["#등비수열의합"],
                steps=[
                    ("등비수열의 일반항 구조를 확인한다.", rf"$k$번째 항은 ${first}\cdot {ratio}^{{k-1}}$이다."),
                    ("유한 등비수열의 합 공식을 선택한다.", rf"$S_{count}={first}\dfrac{{{ratio}^{count}-1}}{{{ratio}-1}}$이다."),
                    ("거듭제곱과 분자를 계산한다.", rf"${ratio}^{count}={ratio**count}$이므로 분자는 ${ratio**count - 1}$이다."),
                    ("공식의 값을 끝까지 계산한다.", rf"따라서 첫 ${count}$개 항의 합은 ${answer}$이다."),
                ],
                alternatives=["첫째항부터 각 항에 공비를 반복해 곱한 뒤 직접 더해 같은 합을 확인할 수 있다."],
                answer_check=lambda a=first, r=ratio, n=count: _geometric_sum(a, r, n),
            )
        )
    for index, (base, numerator, denominator) in enumerate([(16, 3, 4), (27, 4, 3), (32, 4, 5), (64, 5, 6), (125, 4, 3)], 6):
        answer = _rational_power(base, numerator, denominator)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"유리수 지수로 나타낸 값 ${base}^{{{numerator}/{denominator}}}$을 계산하시오.",
                answer=str(answer),
                tags=["#유리수지수", "#지수의확장", "#지수법칙의성질"],
                steps=[
                    ("밑을 완전 거듭제곱으로 나타낸다.", rf"${base}$를 양의 정수의 ${denominator}$제곱으로 해석한다."),
                    ("유리수 지수의 분모를 근호와 연결한다.", rf"${base}^{{1/{denominator}}}$은 ${base}$의 양의 ${denominator}$제곱근이다."),
                    ("분자의 지수를 적용한다.", rf"${base}^{{{numerator}/{denominator}}}=({base}^{{1/{denominator}}})^{numerator}$이다."),
                    ("정수 거듭제곱을 계산한다.", rf"따라서 주어진 값은 ${answer}$이다."),
                ],
                alternatives=["양변을 양의 수 범위에서 분모만큼 거듭제곱해 후보 값이 원래 식을 만족하는지 확인할 수 있다."],
                answer_check=lambda b=base, p=numerator, q=denominator: _rational_power(b, p, q),
            )
        )
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 원탁 인원과 무한대 극한 계수다. 작동 원리는 미사용 태그를 다루는 난이도 4 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    for index, people in enumerate([5, 6, 7, 8, 9], 1):
        answer = _circular_permutations(people)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"서로 다른 ${people}$명이 원형 탁자에 둘러앉을 때, 회전하여 같은 배치를 하나로 보는 자리 배치의 수를 구하시오.",
                answer=str(answer),
                tags=["#원순열"],
                steps=[
                    ("일렬 순열과 원형 배치의 차이를 확인한다.", rf"일렬 배치는 ${people}!$가지이지만 원에서는 회전한 배치가 겹친다."),
                    ("회전 기준을 없애기 위해 한 사람의 자리를 고정한다.", "특정 한 사람을 기준 자리에 고정해도 서로 다른 원형 배치를 하나씩 대표한다."),
                    ("나머지 사람 수를 계산한다.", rf"배치할 사람은 ${people - 1}$명이다."),
                    ("고정된 기준 주위에 나머지를 순서대로 놓는다.", rf"가능한 순서는 $({people}-1)!={people - 1}!$가지이다."),
                    ("팩토리얼 값을 계산한다.", rf"따라서 원순열의 수는 ${answer}$가지이다."),
                ],
                alternatives=["전체 일렬 순열 수를 한 원형 배치마다 가능한 회전 수로 나누어 계산할 수 있다."],
                answer_check=lambda count=people: _circular_permutations(count),
            )
        )
    for index, (linear, constant) in enumerate([(6, 5), (10, 7), (14, 9), (18, 11), (22, 15)], 6):
        answer = _rationalized_infinite_limit(linear)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"극한 $\lim_{{x\to\infty}}\left(\sqrt{{x^2+{linear}x+{constant}}}-x\right)$의 값을 구하시오.",
                answer=str(answer),
                tags=["#유리화를이용한극한", "#무한대의극한"],
                steps=[
                    ("무한대에서 두 큰 항의 차가 부정형임을 확인한다.", r"$\sqrt{x^2+ax+b}$와 $x$가 모두 무한대로 가므로 직접 대입하지 않는다."),
                    ("켤레식을 분자와 분모에 곱한다.", rf"분자는 $(x^2+{linear}x+{constant})-x^2={linear}x+{constant}$가 된다."),
                    ("유리화된 식을 쓴다.", rf"$\dfrac{{{linear}x+{constant}}}{{\sqrt{{x^2+{linear}x+{constant}}}+x}}$이다."),
                    ("분자와 분모를 $x$로 나눈다.", rf"$\dfrac{{{linear}+{constant}/x}}{{\sqrt{{1+{linear}/x+{constant}/x^2}}+1}}$이다."),
                    ("각 작은 항의 극한을 적용한다.", rf"$x\to\infty$이면 분자는 ${linear}$, 분모는 $2$로 가므로 극한은 ${answer}$이다."),
                ],
                alternatives=["제곱근에서 x를 묶고 일차 근사를 적용해 같은 값을 얻을 수 있다."],
                answer_check=lambda coefficient=linear: _rationalized_infinite_limit(coefficient),
            )
        )
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 로그부등식 조건과 속도함수 계수다. 작동 원리는 미사용 태그를 다루는 난이도 5 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    for index, (base, exponent, shift) in enumerate([(3, 2, 1), (2, 4, -1), (5, 2, 2), (3, 3, -2), (2, 5, 3)], 1):
        lower = shift + 1
        upper = shift + base**exponent
        answer = _log_inequality_integer_sum(base, exponent, shift)
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"로그부등식 $\log_{{{base}}}(x-({shift}))\le {exponent}$을 만족하는 모든 정수 $x$의 합을 구하시오.",
                answer=str(answer),
                tags=["#로그방정식과로그부등식", "#진수", "#로그함수의그래프"],
                steps=[
                    ("로그의 진수가 양수라는 정의 조건을 세운다.", rf"$x-({shift})>0$, 즉 $x>{shift}$이다."),
                    ("밑의 범위로 로그함수의 단조성을 확인한다.", rf"${base}>1$이므로 로그함수는 증가한다."),
                    ("로그부등식을 진수의 부등식으로 바꾼다.", rf"$x-({shift})\le {base}^{exponent}={base**exponent}$이다."),
                    ("정의 조건과 상한을 결합한다.", rf"${shift}<x\le {upper}$이다."),
                    ("해당 구간의 정수 해를 나열 범위로 정리한다.", rf"정수 해는 ${lower}$부터 ${upper}$까지이다."),
                    ("등차수열의 합으로 모든 정수 해를 더한다.", rf"따라서 모든 정수 해의 합은 ${answer}$이다."),
                ],
                alternatives=[
                    "로그함수 그래프와 수평선의 위치를 비교해 진수 구간을 읽을 수 있다.",
                    "각 정수 후보의 진수를 밑의 거듭제곱과 비교해 해 집합을 직접 검산할 수 있다.",
                ],
                answer_check=lambda b=base, k=exponent, s=shift: _log_inequality_integer_sum(b, k, s),
            )
        )
    for index, (a, b, c, end_time) in enumerate([(3, 0, 0, 2), (0, 4, 1, 3), (6, 0, 2, 2), (3, 2, 1, 3), (0, 6, -1, 4)], 6):
        answer = _velocity_displacement(a, b, c, end_time)
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"직선 위를 움직이는 점의 시각 $t$에서의 속도가 $v(t)=({a})t^2+({b})t+({c})$이다. $t=0$부터 $t={end_time}$까지의 위치변화량을 구하시오.",
                answer=str(answer),
                tags=["#정적분과속도", "#위치변화량", "#부정적분공식", "#부정적분의정의"],
                steps=[
                    ("위치변화량과 속도의 관계를 세운다.", rf"위치변화량은 $\int_0^{{{end_time}}}v(t)\,dt$이다."),
                    ("속도함수를 항별로 적분한다.", rf"$\int v(t)\,dt=({a})\dfrac{{t^3}}3+({b})\dfrac{{t^2}}2+({c})t+C$이다."),
                    ("정적분에서는 원시함수의 상수항이 소거됨을 확인한다.", "위끝 값에서 아래끝 값을 빼므로 적분상수는 결과에 영향을 주지 않는다."),
                    ("위끝 시각을 원시함수에 대입한다.", rf"$t={end_time}$에서의 값은 $({a})\dfrac{{{end_time}^3}}3+({b})\dfrac{{{end_time}^2}}2+({c})({end_time})$이다."),
                    ("아래끝 시각의 값을 계산한다.", r"$t=0$에서 원시함수의 값은 $0$이다."),
                    ("두 끝값의 차를 정확히 계산한다.", rf"따라서 위치변화량은 ${answer}$이다."),
                ],
                alternatives=[
                    "속도 그래프와 시간축 사이의 부호 있는 넓이를 계산해 위치변화량을 구할 수 있다.",
                    "위치함수의 일반형을 먼저 구한 뒤 두 시각의 함수값 차를 계산할 수 있다.",
                ],
                answer_check=lambda first=a, second=b, third=c, end=end_time: _velocity_displacement(first, second, third, end),
            )
        )
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v21 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v21 전체 카탈로그다. 작동 원리는 모든 정답 검산 함수를 실행한 뒤 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog = build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v21 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(catalog, expected_count=50, batch_id=BATCH_ID, model_name=MODEL_NAME, codebase_base=CODEBASE_BASE, seed_base=SEED_BASE)


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v21 전체 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(db_path, quests=validated_quests(), batch_id=BATCH_ID, validate_only=validate_only)


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v21 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
