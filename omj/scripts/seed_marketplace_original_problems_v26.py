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

BATCH_ID = "marketplace-original-v26"
MODEL_NAME = "aiflow-direct-authoring-v26"
CODEBASE_BASE = 20_260_987_000
SEED_BASE = 202_607_566_000


def _checked_problem(
    tier: int,
    index: int,
    *,
    answer_check: Callable[[], Any],
    **kwargs: Any,
) -> dict[str, Any]:
    """필요 변수는 문제 명세와 독립 계산 함수다. 작동 원리는 저장 답과 별도 계산 결과를 공통 검증기가 비교하도록 검산 함수를 부착한다."""
    spec = _problem(tier, index, **kwargs)
    spec["answer_check"] = answer_check
    return spec


def _product_linear_coefficient(first: tuple[int, int], second: tuple[int, int]) -> int:
    """필요 변수는 두 일차식의 계수와 상수항이다. 작동 원리는 곱셈공식을 전개해 일차항 계수를 계산한다."""
    a, b = first
    c, d = second
    return a * d + b * c


def _sandwiched_subset_count(universe: tuple[int, ...], required: tuple[int, ...]) -> int:
    """필요 변수는 전체집합과 반드시 포함할 부분집합이다. 작동 원리는 나머지 원소의 포함 여부를 독립 선택해 중간 부분집합 수를 센다."""
    if not set(required).issubset(universe):
        raise ValueError("필수 집합이 전체집합의 부분집합이 아닙니다.")
    return 2 ** (len(universe) - len(set(required)))


def _geometric_target(first_index: int, first_value: int, ratio: int, target_index: int) -> int:
    """필요 변수는 등비수열의 기준 항·공비·목표 항 번호다. 작동 원리는 항 번호 차만큼 공비를 거듭제곱해 목표 항을 구한다."""
    return first_value * ratio ** (target_index - first_index)


def _integer_quotient_remainder_sum(dividend: int, divisor: int) -> int:
    """필요 변수는 양의 피제수와 제수다. 작동 원리는 정수 나눗셈으로 몫과 나머지를 각각 구해 더한다."""
    quotient, remainder = divmod(dividend, divisor)
    return quotient + remainder


def _odd_sum_by_induction(count: int) -> int:
    """필요 변수는 더할 홀수의 개수다. 작동 원리는 실제 홀수 항을 순회해 귀납 명제의 n제곱 결과를 독립 검산한다."""
    return sum(2 * index - 1 for index in range(1, count + 1))


def _log_chain_value(base: int, middle: int, target: int) -> int:
    """필요 변수는 로그 연쇄의 밑·중간수·목표수다. 작동 원리는 목표수가 밑의 몇 제곱인지 정수 반복으로 계산한다."""
    if base <= 1 or middle <= 0 or middle == 1 or target <= 0:
        raise ValueError("로그의 정의 조건을 만족하지 않습니다.")
    value = target
    exponent = 0
    while value > 1 and value % base == 0:
        value //= base
        exponent += 1
    if value != 1:
        raise ValueError("목표수가 밑의 정수 거듭제곱이 아닙니다.")
    return exponent


def _riemann_linear_integral(slope: int, intercept: int, upper: int) -> Fraction:
    """필요 변수는 일차함수 계수와 적분구간 위끝이다. 작동 원리는 구분구적 극한과 같은 정적분 값을 정확히 계산한다."""
    return Fraction(slope * upper**2, 2) + intercept * upper


def _cubic_difference_limit(point: int) -> int:
    """필요 변수는 인수분해 기준점이다. 작동 원리는 세제곱 차를 약분한 뒤 점에 대입해 극한을 계산한다."""
    return 3 * point**2


def _telescoping_fraction_sum(lower: int, upper: int) -> Fraction:
    """필요 변수는 유한합의 시작·끝 정수다. 작동 원리는 각 항을 부분분수로 분해해 직접 더한다."""
    return sum((Fraction(1, index * (index + 1)) for index in range(lower, upper + 1)), Fraction(0, 1))


def _cubic_extrema_gap(scale: int, vertical: int) -> int:
    """필요 변수는 두 임계점의 절댓값과 세로 이동량이다. 작동 원리는 두 임계점의 함수값 차를 계산해 극댓값과 극솟값의 간격을 구한다."""
    left_value = (-scale) ** 3 - 3 * scale**2 * (-scale) + vertical
    right_value = scale**3 - 3 * scale**2 * scale + vertical
    return left_value - right_value


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 일차식과 포함관계가 주어진 집합이다. 작동 원리는 저사용 대수·집합 태그를 보강하는 난이도 1 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    product_rows = [((2, 3), (4, 5)), ((-1, 4), (3, -2)), ((5, -3), (2, 6)), ((3, 7), (-2, 5)), ((-4, 2), (5, -1))]
    for index, (first, second) in enumerate(product_rows, 1):
        a, b = first
        c, d = second
        answer = _product_linear_coefficient(first, second)
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"다항식 $({a}x+({b}))({c}x+({d}))$을 전개했을 때 x의 계수를 구하시오.",
                answer=str(answer),
                tags=["#곱셈공식", "#다항식의곱셈", "#공통수학1"],
                steps=[
                    ("곱셈공식에서 일차항이 생기는 두 곱을 찾는다.", rf"일차항은 $({a}x)({d})+({b})({c}x)$이다."),
                    ("두 일차항의 계수를 더한다.", rf"따라서 x의 계수는 ${a * d}+({b * c})={answer}$이다."),
                ],
                answer_check=lambda left=first, right=second: _product_linear_coefficient(left, right),
            )
        )
    subset_rows = [
        ((1, 2, 3, 4, 5), (1, 3)),
        ((2, 4, 6, 8, 10, 12), (4, 8, 12)),
        ((-3, -2, -1, 0, 1, 2, 3), (-3, 3)),
        ((1, 3, 5, 7, 9, 11, 13, 15), (3, 7, 11, 15)),
        ((2, 3, 5, 7, 11, 13, 17, 19, 23), (2, 5, 11, 17, 23)),
    ]
    for index, (universe, required) in enumerate(subset_rows, 6):
        answer = _sandwiched_subset_count(universe, required)
        universe_text = ",".join(str(value) for value in universe)
        required_text = ",".join(str(value) for value in required)
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"집합 $U=\{{{universe_text}\}}$, $S=\{{{required_text}\}}$에 대하여 $S\subseteq A\subseteq U$를 만족하는 집합 $A$의 개수를 구하시오.",
                answer=str(answer),
                tags=["#부분집합", "#집합의포함관계", "#공통수학1"],
                steps=[
                    ("S의 원소는 A에 반드시 포함됨을 확인한다.", rf"고정되는 원소는 ${len(required)}$개이다."),
                    ("U에서 S를 뺀 원소의 포함 여부를 각각 선택한다.", rf"자유로운 원소가 ${len(universe) - len(required)}$개이므로 개수는 ${answer}$개이다."),
                ],
                answer_check=lambda whole=universe, fixed=required: _sandwiched_subset_count(whole, fixed),
            )
        )
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 등비수열 조건과 정수 나눗셈 조건이다. 작동 원리는 저사용 수열·나머지 태그를 보강하는 난이도 2 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    geometric_rows = [(2, 3, 2, 6), (3, -2, -2, 7), (1, 5, 3, 4), (4, 16, Fraction(1, 2), 7), (5, -3, 2, 9)]
    for index, (first_index, first_value, ratio, target_index) in enumerate(geometric_rows, 1):
        answer_value = first_value * ratio ** (target_index - first_index)
        if isinstance(answer_value, Fraction):
            answer: Any = answer_value
        else:
            answer = int(answer_value)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"등비수열 $\{{a_n\}}$에서 $a_{first_index}={first_value}$, 공비가 ${ratio}$일 때, $a_{target_index}$의 값을 구하시오.",
                answer=str(answer),
                tags=["#공비", "#등비중항", "#수열", "#수열의정의"],
                steps=[
                    ("기준 항과 목표 항의 번호 차를 구한다.", rf"공비를 곱할 횟수는 ${target_index}-{first_index}={target_index - first_index}$회이다."),
                    ("등비수열의 항 관계를 세운다.", rf"$a_{target_index}=a_{first_index}\cdot({ratio})^{{{target_index - first_index}}}$이다."),
                    ("거듭제곱과 곱을 계산한다.", rf"따라서 $a_{target_index}={answer}$이다."),
                ],
                answer_check=lambda i=first_index, value=first_value, r=ratio, n=target_index: _geometric_target(i, value, r, n),
            )
        )
    division_rows = [(137, 12), (245, 17), (389, 23), (512, 29), (731, 31)]
    for index, (dividend, divisor) in enumerate(division_rows, 6):
        quotient, remainder = divmod(dividend, divisor)
        answer = _integer_quotient_remainder_sum(dividend, divisor)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"양의 정수 ${dividend}$을 ${divisor}$로 나누었을 때의 몫과 나머지의 합을 구하시오.",
                answer=str(answer),
                tags=["#몫과나머지"],
                steps=[
                    ("제수의 배수 중 피제수를 넘지 않는 가장 큰 값을 찾는다.", rf"${divisor}\cdot {quotient}={divisor * quotient}$이다."),
                    ("피제수에서 해당 배수를 빼 나머지를 구한다.", rf"나머지는 ${dividend}-{divisor * quotient}={remainder}$이다."),
                    ("몫과 나머지를 더한다.", rf"따라서 합은 ${quotient}+{remainder}={answer}$이다."),
                ],
                answer_check=lambda n=dividend, d=divisor: _integer_quotient_remainder_sum(n, d),
            )
        )
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 홀수 합의 항수와 로그 연쇄의 세 양수다. 작동 원리는 저사용 귀납·로그 태그를 보강하는 난이도 3 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    for index, count in enumerate([8, 11, 14, 17, 20], 1):
        answer = _odd_sum_by_induction(count)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"명제 $P(n):1+3+\cdots+(2n-1)=n^2$을 수학적 귀납법으로 확인한 뒤, $n={count}$일 때 왼쪽 합의 값을 구하시오.",
                answer=str(answer),
                tags=["#수학적귀납법", "#귀납법의원리", "#귀납법증명", "#여러가지수열의합"],
                steps=[
                    ("n=1에서 명제가 참임을 확인한다.", r"$1=1^2$이므로 귀납의 시작이 성립한다."),
                    ("P(k)가 참이라고 가정한다.", r"$1+3+\cdots+(2k-1)=k^2$이라 둔다."),
                    ("다음 홀수 2k+1을 더해 P(k+1)을 확인한다.", r"$k^2+(2k+1)=(k+1)^2$이다."),
                    ("귀납 명제에 주어진 n을 대입한다.", rf"따라서 합은 ${count}^2={answer}$이다."),
                ],
                alternatives=["처음 n개 홀수를 직접 생성해 더한 값이 n제곱과 같은지 계산으로 검산할 수 있다."],
                answer_check=lambda n=count: _odd_sum_by_induction(n),
            )
        )
    log_rows = [(2, 8, 32), (3, 9, 81), (4, 2, 64), (5, 25, 125), (10, 100, 10000)]
    for index, (base, middle, target) in enumerate(log_rows, 6):
        answer = _log_chain_value(base, middle, target)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"로그의 밑 변환을 이용하여 $\log_{{{base}}}{middle}\cdot\log_{{{middle}}}{target}$의 값을 구하시오.",
                answer=str(answer),
                tags=["#밑", "#밑의변환", "#로그", "#로그의성질"],
                steps=[
                    ("두 번째 로그를 첫 번째 밑으로 변환한다.", rf"$\log_{{{middle}}}{target}=\dfrac{{\log_{{{base}}}{target}}}{{\log_{{{base}}}{middle}}}$이다."),
                    ("공통인 로그 인수를 약분한다.", rf"곱은 $\log_{{{base}}}{target}$로 정리된다."),
                    ("목표수를 밑의 거듭제곱으로 나타낸다.", rf"${target}={base}^{answer}$이다."),
                    ("로그 정의로 지수를 읽는다.", rf"따라서 값은 ${answer}$이다."),
                ],
                alternatives=["연쇄법칙 $\log_a b\log_b c=\log_a c$를 바로 적용할 수 있다."],
                answer_check=lambda a=base, b=middle, c=target: _log_chain_value(a, b, c),
            )
        )
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 일차함수 적분 조건과 세제곱 차의 극한점이다. 작동 원리는 저사용 구분구적·극한 태그를 보강하는 난이도 4 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    riemann_rows = [(2, 1, 4), (3, -2, 6), (-1, 5, 8), (4, 3, 5), (-2, 7, 10)]
    for index, (slope, intercept, upper) in enumerate(riemann_rows, 1):
        answer = _riemann_linear_integral(slope, intercept, upper)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"구간 $[0,{upper}]$을 n등분하여 만든 오른쪽 끝점 구분구적합의 극한으로 함수 $f(x)={slope}x+({intercept})$와 x축 사이의 부호 있는 넓이를 구하시오.",
                answer=str(answer),
                tags=["#구간의분할", "#구분구적법"],
                steps=[
                    ("구간의 폭과 오른쪽 끝점을 나타낸다.", rf"$\Delta x={upper}/n$, $x_k={upper}k/n$이다."),
                    ("구분구적합을 세운다.", rf"$\sum_{{k=1}}^n f(x_k)\Delta x$이다."),
                    ("일차항과 상수항의 합을 분리한다.", r"$\sum k=n(n+1)/2$와 $\sum1=n$을 사용한다."),
                    ("n으로 정리한 식에서 무한대 극한을 취한다.", rf"극한은 정적분 $\int_0^{{{upper}}}({slope}x+({intercept}))dx$와 같다."),
                    ("원시함수의 끝값을 계산한다.", rf"따라서 부호 있는 넓이는 ${answer}$이다."),
                ],
                alternatives=["구분구적합이 정의하는 정적분을 바로 계산해 같은 값을 얻을 수 있다."],
                answer_check=lambda m=slope, b=intercept, t=upper: _riemann_linear_integral(m, b, t),
            )
        )
    for index, point in enumerate([2, -3, 4, -5, 6], 6):
        answer = _cubic_difference_limit(point)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"극한 $\lim_{{x\to {point}}}\dfrac{{x^3-{point**3}}}{{x-({point})}}$의 값을 구하시오.",
                answer=str(answer),
                tags=["#극한값계산", "#극한의사칙연산", "#극한의정의"],
                steps=[
                    ("직접 대입하면 0/0 꼴임을 확인한다.", rf"분자와 분모가 모두 $0$이므로 약분 전에는 값을 정할 수 없다."),
                    ("세제곱의 차를 인수분해한다.", rf"$x^3-{point}^3=(x-{point})(x^2+{point}x+{point**2})$이다."),
                    ("x가 극한점과 다른 주변에서 공통인수를 약분한다.", rf"식은 $x^2+{point}x+{point**2}$로 정리된다."),
                    ("다항함수의 극한 사칙연산을 적용한다.", "정리된 다항식에는 극한점을 직접 대입할 수 있다."),
                    ("세 항을 계산해 더한다.", rf"따라서 극한값은 ${point**2}+({point**2})+({point**2})={answer}$이다."),
                ],
                alternatives=["주어진 식을 x^3의 미분계수 정의로 보고 $3a^2$를 적용할 수 있다."],
                answer_check=lambda value=point: _cubic_difference_limit(value),
            )
        )
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 망원합 구간과 삼차함수 임계점이다. 작동 원리는 저사용 부분분수·극대극소 태그를 보강하는 난이도 5 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    fraction_rows = [(2, 8), (3, 10), (4, 12), (5, 15), (6, 18)]
    for index, (lower, upper) in enumerate(fraction_rows, 1):
        answer = _telescoping_fraction_sum(lower, upper)
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"유한합 $\sum_{{k={lower}}}^{{{upper}}}\dfrac1{{k(k+1)}}$의 값을 부분분수 분해로 구하시오.",
                answer=str(answer),
                tags=["#부분분수", "#약분"],
                steps=[
                    ("일반항을 두 단위분수의 차로 분해한다.", r"$\dfrac1{k(k+1)}=\dfrac1k-\dfrac1{k+1}$이다."),
                    ("분해한 일반항을 합에 대입한다.", rf"$\sum_{{k={lower}}}^{{{upper}}}(\dfrac1k-\dfrac1{{k+1}})$이다."),
                    ("연속한 항에서 같은 분수가 반대 부호로 나타남을 확인한다.", "첫 항과 마지막 항을 제외한 중간 분수는 모두 소거된다."),
                    ("망원합의 남는 두 항을 쓴다.", rf"합은 $\dfrac1{{{lower}}}-\dfrac1{{{upper + 1}}}$이다."),
                    ("두 분수를 통분한다.", rf"공통분모는 ${lower * (upper + 1)}$이다."),
                    ("기약분수로 정리한다.", rf"따라서 합은 ${answer}$이다."),
                ],
                alternatives=[
                    "각 항을 실제로 나열해 중간 항의 연쇄 소거를 확인할 수 있다.",
                    "합 공식 결과와 원래 유한합을 정확한 분수 연산으로 직접 비교할 수 있다.",
                ],
                answer_check=lambda first=lower, last=upper: _telescoping_fraction_sum(first, last),
            )
        )
    extrema_rows = [(2, 1), (3, -4), (4, 5), (5, 2), (6, -7)]
    for index, (scale, vertical) in enumerate(extrema_rows, 6):
        left_value = 2 * scale**3 + vertical
        right_value = -2 * scale**3 + vertical
        answer = _cubic_extrema_gap(scale, vertical)
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"삼차함수 $f(x)=x^3-{3 * scale**2}x+({vertical})$의 극댓값과 극솟값의 차를 구하시오.",
                answer=str(answer),
                tags=["#극댓값", "#극솟값", "#미분과최대최소"],
                steps=[
                    ("도함수를 구한다.", rf"$f'(x)=3x^2-{3 * scale**2}=3(x-{scale})(x+{scale})$이다."),
                    ("도함수가 0이 되는 임계점을 찾는다.", rf"임계점은 $x=-{scale},{scale}$이다."),
                    ("도함수 부호 변화로 극대·극소를 판정한다.", rf"$x=-{scale}$에서 극대, $x={scale}$에서 극소이다."),
                    ("두 임계점의 함수값을 계산한다.", rf"극댓값은 ${left_value}$, 극솟값은 ${right_value}$이다."),
                    ("세로 이동량이 차에서 소거됨을 확인한다.", rf"두 함수값에 공통으로 들어간 ${vertical}$은 뺄셈에서 없어진다."),
                    ("극댓값에서 극솟값을 뺀다.", rf"따라서 두 값의 차는 ${answer}$이다."),
                ],
                alternatives=[
                    "함수를 세로로 평행이동해도 극댓값과 극솟값의 간격은 변하지 않는다는 점을 이용할 수 있다.",
                    "도함수 부호표를 그려 두 임계점의 역할을 시각적으로 검산할 수 있다.",
                ],
                answer_check=lambda a=scale, c=vertical: _cubic_extrema_gap(a, c),
            )
        )
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v26 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v26 전체 카탈로그다. 작동 원리는 모든 정답 검산 함수를 실행한 뒤 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog = build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v26 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(catalog, expected_count=50, batch_id=BATCH_ID, model_name=MODEL_NAME, codebase_base=CODEBASE_BASE, seed_base=SEED_BASE)


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v26 전체 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(db_path, quests=validated_quests(), batch_id=BATCH_ID, validate_only=validate_only)


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v26 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
