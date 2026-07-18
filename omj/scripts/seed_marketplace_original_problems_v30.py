from __future__ import annotations

import argparse
import itertools
import json
import sys
from fractions import Fraction
from pathlib import Path
from typing import Any, Callable

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.marketplace_problem_batch import seed_problem_batch, validate_problem_batch
from scripts.seed_initial_math_problems import _problem

BATCH_ID = "marketplace-original-v30"
MODEL_NAME = "aiflow-direct-authoring-v30"
CODEBASE_BASE = 20_260_991_000
SEED_BASE = 202_607_570_000


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


def _disjoint_proper_subset_count(universe_size: int, fixed_size: int) -> int:
    """필요 변수는 전체집합과 고정 부분집합의 원소 수다. 작동 원리는 모든 비트 부분집합을 순회해 고정 집합과 서로소인 진부분집합을 센다."""
    if not 0 < fixed_size <= universe_size:
        raise ValueError("고정 부분집합의 크기가 올바르지 않습니다.")
    full_mask = (1 << universe_size) - 1
    fixed_mask = (1 << fixed_size) - 1
    return sum(
        mask != full_mask and mask & fixed_mask == 0
        for mask in range(1 << universe_size)
    )


def _factor_parameter(cubic: int, quadratic: int, linear: int, root: int) -> int:
    """필요 변수는 삼차·이차·일차항 계수와 인수의 근이다. 작동 원리는 나머지정리 P(root)=0을 적용해 상수항을 구한다."""
    return -(cubic * root**3 + quadratic * root**2 + linear * root)


def _double_root_parameter(root: int) -> int:
    """필요 변수는 중근으로 만들 실수다. 작동 원리는 (x-root)²을 전개해 상수항 k를 구하고 k와 중근을 더한다."""
    parameter = root * root
    return parameter + root


def _parallel_line_parameter(first_x: int, first_y: int, second_x: int) -> Fraction:
    """필요 변수는 첫 직선의 x·y 계수와 둘째 직선의 x계수다. 작동 원리는 두 법선벡터가 비례하도록 둘째 y계수를 구한다."""
    if first_x == 0:
        raise ValueError("첫 직선의 x계수는 0이 아니어야 합니다.")
    return Fraction(second_x * first_y, first_x)


def _geometric_sum(first: int, ratio: Fraction, count: int) -> Fraction:
    """필요 변수는 첫째항·공비·항수다. 작동 원리는 실제 등비수열 항을 생성해 정확한 분수로 합한다."""
    if count <= 0:
        raise ValueError("항수는 양의 정수여야 합니다.")
    return sum((Fraction(first, 1) * ratio**index for index in range(count)), Fraction(0, 1))


def _repeated_selection_total(symbols: int, length: int) -> int:
    """필요 변수는 기호 수와 선택 길이다. 작동 원리는 중복순열과 지수합이 고정된 중복조합을 각각 전수 열거해 합한다."""
    if symbols <= 0 or length < 0:
        raise ValueError("중복 선택 조건이 올바르지 않습니다.")
    words = sum(1 for _ in itertools.product(range(symbols), repeat=length))
    multisets = sum(
        sum(counts) == length
        for counts in itertools.product(range(length + 1), repeat=symbols)
    )
    return words + multisets


def _composition_range_score(
    first_map: tuple[int, ...],
    second_map: tuple[int, ...],
    codomain_size: int,
) -> int:
    """필요 변수는 두 유한함수의 대응표와 합성함수 공역 크기다. 작동 원리는 합성값 집합을 구해 치역 크기와 미사용 공역 원소 수를 곱한다."""
    if codomain_size <= 0 or any(not 1 <= value <= len(second_map) for value in first_map):
        raise ValueError("첫 번째 함수의 대응값이 두 번째 함수 정의역을 벗어났습니다.")
    composed = {second_map[value - 1] for value in first_map}
    if any(not 1 <= value <= codomain_size for value in composed):
        raise ValueError("합성함수 값이 공역을 벗어났습니다.")
    return len(composed) * (codomain_size - len(composed))


def _discontinuity_coordinate_sum(denominator_roots: tuple[int, ...]) -> int:
    """필요 변수는 유리함수 분모의 일차인수 근들이다. 작동 원리는 약분 여부와 무관하게 원래 정의역에서 제외되는 서로 다른 근을 더한다."""
    if not denominator_roots:
        raise ValueError("분모의 근이 하나 이상 필요합니다.")
    return sum(set(denominator_roots))


def _exponential_integer_count(
    base: int,
    shift: int,
    vertical: int,
    threshold_exponent: int,
    relation: str,
    lower: int,
    upper: int,
) -> int:
    """필요 변수는 지수함수 이동량·기준 지수·부등호·정수 범위다. 작동 원리는 모든 정수에서 정확한 유리수 거듭제곱값을 비교한다."""
    comparisons: dict[str, Callable[[Fraction, Fraction], bool]] = {
        "<": lambda left, right: left < right,
        "<=": lambda left, right: left <= right,
        ">": lambda left, right: left > right,
        ">=": lambda left, right: left >= right,
    }
    if base <= 1 or relation not in comparisons or lower > upper:
        raise ValueError("지수부등식 조건이 올바르지 않습니다.")
    target = Fraction(base, 1) ** threshold_exponent + vertical
    return sum(
        comparisons[relation](Fraction(base, 1) ** (x - shift) + vertical, target)
        for x in range(lower, upper + 1)
    )


def _condition_relation_count(
    universe: tuple[int, ...],
    first_condition: Callable[[int], bool],
    second_condition: Callable[[int], bool],
) -> int:
    """필요 변수는 유한 전체집합과 두 조건이다. 작동 원리는 두 진리집합의 포함관계로 충분·필요·필요충분조건의 참 개수를 센다."""
    first_set = {value for value in universe if first_condition(value)}
    second_set = {value for value in universe if second_condition(value)}
    sufficient = first_set <= second_set
    necessary = second_set <= first_set
    equivalent = first_set == second_set
    return sum((sufficient, necessary, equivalent))


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 서로소 부분집합과 인수정리 매개변수다. 작동 원리는 집합 연산과 나머지정리 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    subset_rows = [(5, 2), (6, 3), (7, 2), (8, 4), (9, 5)]
    for index, (universe_size, fixed_size) in enumerate(subset_rows, 1):
        answer = _disjoint_proper_subset_count(universe_size, fixed_size)
        universe_text = ",".join(str(value) for value in range(1, universe_size + 1))
        fixed_text = ",".join(str(value) for value in range(1, fixed_size + 1))
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"전체집합 $U=\{{{universe_text}\}}$와 부분집합 $A=\{{{fixed_text}\}}$에 대하여 $A-B=A$를 만족하는 U의 진부분집합 B의 개수를 구하시오.",
                answer=str(answer),
                tags=["#진부분집합", "#차집합", "#여집합", "#집합"],
                steps=[
                    ("A-B=A가 뜻하는 포함 제한을 해석한다.", "B에는 A의 원소가 하나도 들어갈 수 없다."),
                    ("U-A의 각 원소 포함 여부를 독립 선택한다.", rf"선택 가능한 원소가 ${universe_size - fixed_size}$개이므로 B는 ${answer}$개이다."),
                ],
                answer_check=lambda whole=universe_size, fixed=fixed_size: _disjoint_proper_subset_count(whole, fixed),
            )
        )
    factor_rows = [
        (1, 2, -3, 2),
        (2, -1, 4, -2),
        (-1, 3, 2, 3),
        (3, 0, -5, 1),
        (2, 4, 1, -3),
    ]
    for index, (cubic, quadratic, linear, root) in enumerate(factor_rows, 6):
        answer = _factor_parameter(cubic, quadratic, linear, root)
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"다항식 $P(x)={cubic}x^3+({quadratic})x^2+({linear})x+k$가 $x-({root})$를 인수로 가질 때 상수 k를 구하시오.",
                answer=str(answer),
                tags=["#나머지정리증명", "#인수정리증명", "#인수정리활용", "#항등식"],
                steps=[
                    ("나머지정리에서 나머지가 0이면 인수임을 확인한다.", rf"$x-({root})$가 인수이므로 $P({root})=0$이다."),
                    ("P(root)=0에 계수를 대입해 k를 구한다.", rf"따라서 $k={answer}$이다."),
                ],
                answer_check=lambda a=cubic, b=quadratic, c=linear, r=root: _factor_parameter(a, b, c, r),
            )
        )
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 중근을 갖는 이차방정식과 두 직선 계수다. 작동 원리는 근과 계수 및 평행 조건 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    for index, root in enumerate([2, -3, 4, -4, 5], 1):
        parameter = root * root
        answer = _double_root_parameter(root)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"이차방정식 $x^2-({2 * root})x+k=0$이 중근을 가질 때, k와 그 중근의 합을 구하시오.",
                answer=str(answer),
                tags=["#두근의합", "#두근의곱", "#이차방정식의근과계수", "#중근조건", "#완전제곱식"],
                steps=[
                    ("중근을 가지려면 이차식이 완전제곱식임을 이용한다.", rf"$x^2-({2 * root})x+k=(x-({root}))^2$이어야 한다."),
                    ("완전제곱식의 상수항을 비교한다.", rf"$k={parameter}$이고 중근은 ${root}$이다."),
                    ("k와 중근을 더한다.", rf"따라서 합은 ${answer}$이다."),
                ],
                answer_check=lambda value=root: _double_root_parameter(value),
            )
        )
    line_rows = [
        (2, 3, 1, 4, -2),
        (3, -2, 4, 6, 5),
        (-2, 5, -3, 4, 7),
        (4, 1, 2, 8, -5),
        (5, -3, 6, 10, 1),
    ]
    for index, (first_x, first_y, first_c, second_x, second_c) in enumerate(line_rows, 6):
        answer = _parallel_line_parameter(first_x, first_y, second_x)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"두 직선 ${first_x}x+({first_y})y+({first_c})=0$과 ${second_x}x+ky+({second_c})=0$이 서로 평행할 때 k를 구하시오.",
                answer=str(answer),
                tags=["#두직선의위치관계", "#평행조건", "#직선의방정식"],
                steps=[
                    ("평행한 두 직선의 법선벡터가 비례함을 이용한다.", rf"$({first_x},{first_y})$와 $({second_x},k)$가 비례한다."),
                    ("x계수의 비와 y계수의 비를 같게 둔다.", rf"$\dfrac{{{second_x}}}{{{first_x}}}=\dfrac{{k}}{{{first_y}}}$이다."),
                    ("비례식을 풀어 k를 구한다.", rf"따라서 $k={answer}$이다."),
                ],
                answer_check=lambda a=first_x, b=first_y, p=second_x: _parallel_line_parameter(a, b, p),
            )
        )
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 등비수열과 중복 선택 조건이다. 작동 원리는 시그마 합과 중복순열·중복조합 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    geometric_rows = [
        (3, Fraction(2, 1), 5),
        (-2, Fraction(3, 1), 4),
        (16, Fraction(1, 2), 6),
        (5, Fraction(-2, 1), 5),
        (81, Fraction(1, 3), 5),
    ]
    for index, (first, ratio, count) in enumerate(geometric_rows, 1):
        answer = _geometric_sum(first, ratio, count)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"첫째항이 ${first}$이고 공비가 ${ratio}$인 등비수열의 첫 ${count}$개 항의 합을 시그마로 계산하시오.",
                answer=str(answer),
                tags=["#등비수열의합", "#합의기호시그마", "#항", "#수열"],
                steps=[
                    ("등비수열의 일반항을 쓴다.", rf"$a_n={first}({ratio})^{{n-1}}$이다."),
                    ("첫 count개 항의 합을 시그마로 나타낸다.", rf"$\sum_{{n=1}}^{{{count}}}{first}({ratio})^{{n-1}}$이다."),
                    ("유한 등비급수의 합 공식을 적용한다.", r"공비가 1이 아니므로 $S_n=a_1(1-r^n)/(1-r)$을 사용한다."),
                    ("거듭제곱과 분수를 정리한다.", rf"따라서 합은 ${answer}$이다."),
                ],
                alternatives=["각 항을 실제로 생성해 정확한 분수 연산으로 더할 수 있다."],
                answer_check=lambda start=first, r=ratio, n=count: _geometric_sum(start, r, n),
            )
        )
    for index, (symbols, length) in enumerate([(2, 4), (3, 3), (4, 2), (3, 5), (4, 4)], 6):
        word_count = symbols**length
        multiset_count = sum(
            sum(counts) == length
            for counts in itertools.product(range(length + 1), repeat=symbols)
        )
        answer = _repeated_selection_total(symbols, length)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"서로 다른 기호 {symbols}개로 만드는 길이 {length}의 중복순열 수와, 이 기호 중 중복을 허용해 {length}개를 고르는 중복조합 수의 합을 구하시오.",
                answer=str(answer),
                tags=["#중복순열", "#중복조합", "#조합의성질", "#순열"],
                steps=[
                    ("각 자리에 기호를 독립 선택해 중복순열을 센다.", rf"중복순열은 ${symbols}^{length}={word_count}$개이다."),
                    ("중복조합을 비음이 아닌 정수해 문제로 바꾼다.", rf"$x_1+\cdots+x_{symbols}={length}$의 해 수이다."),
                    ("중복조합 공식을 적용한다.", rf"중복조합은 ${multiset_count}$개이다."),
                    ("두 경우의 수를 더한다.", rf"따라서 합은 ${answer}$이다."),
                ],
                alternatives=["작은 기호 집합의 모든 문자열과 개수 벡터를 직접 열거해 두 공식을 검산할 수 있다."],
                answer_check=lambda kinds=symbols, size=length: _repeated_selection_total(kinds, size),
            )
        )
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 유한함수의 대응표와 유리함수 분모 근이다. 작동 원리는 합성함수 치역과 불연속점 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    composition_rows = [
        ((1, 2, 2, 3), (1, 1, 3), 4),
        ((1, 3, 4, 2, 4), (2, 3, 3, 5), 5),
        ((2, 2, 1, 3), (4, 2, 4), 6),
        ((1, 2, 3, 4, 5), (1, 2, 2, 3, 4), 5),
        ((3, 1, 4, 2), (2, 2, 5, 5), 6),
    ]
    for index, (first_map, second_map, codomain_size) in enumerate(composition_rows, 1):
        composed = {second_map[value - 1] for value in first_map}
        unused = codomain_size - len(composed)
        answer = _composition_range_score(first_map, second_map, codomain_size)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"함수 f의 대응값이 순서대로 $({','.join(map(str, first_map))})$이고 함수 g의 대응값이 $({','.join(map(str, second_map))})$이며 $g\circ f$의 공역이 $\{{1,\ldots,{codomain_size}\}}$이다. 합성함수의 치역 원소 수와 공역에서 사용되지 않은 원소 수의 곱을 구하시오.",
                answer=str(answer),
                tags=["#공역", "#치역", "#함수", "#함수의정의", "#합성함수의정의"],
                steps=[
                    ("f의 각 대응값을 g의 입력으로 넣는다.", "정의역의 모든 원소에서 g(f(x))를 계산한다."),
                    ("중복을 제거해 합성함수의 치역을 구한다.", rf"치역의 원소 수는 ${len(composed)}$개이다."),
                    ("공역 크기에서 치역 크기를 뺀다.", rf"사용되지 않은 공역 원소는 ${unused}$개이다."),
                    ("두 수의 의미가 서로 다름을 확인한다.", "치역은 실제 출력, 공역은 허용된 전체 출력 집합이다."),
                    ("두 원소 수를 곱한다.", rf"따라서 곱은 ${answer}$이다."),
                ],
                alternatives=["대응 관계를 화살표 그림으로 그려 합성함수의 실제 도착점을 표시할 수 있다."],
                answer_check=lambda first=first_map, second=second_map, size=codomain_size: _composition_range_score(first, second, size),
            )
        )
    discontinuity_rows = [
        ((1, 4), (1, -2, 3)),
        ((-1, 5), (-1, 2, 2)),
        ((3, -4), (3, 0, -5)),
        ((2, 6), (2, -3, -3)),
        ((-2, 1), (-2, 4, 7)),
    ]
    for index, (numerator_roots, denominator_roots) in enumerate(discontinuity_rows, 6):
        answer = _discontinuity_coordinate_sum(denominator_roots)
        numerator = "".join(rf"(x-({root}))" for root in numerator_roots)
        denominator = "".join(rf"(x-({root}))" for root in denominator_roots)
        unique_roots = sorted(set(denominator_roots))
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"유리함수 $f(x)=\dfrac{{{numerator}}}{{{denominator}}}$의 모든 불연속점의 x좌표의 합을 구하시오.",
                answer=str(answer),
                tags=["#불연속", "#함수", "#함수의정의", "#유리식"],
                steps=[
                    ("원래 분모가 0이 되는 값을 모두 찾는다.", rf"분모의 근은 ${unique_roots}$이다."),
                    ("분자와 공통인 인수가 있는지 확인한다.", "공통인수를 약분해도 원래 함수의 정의역 제외점은 복원되지 않는다."),
                    ("중복되는 분모 근은 한 불연속점으로 센다.", rf"서로 다른 불연속점은 ${len(unique_roots)}$개이다."),
                    ("각 제외점에서 제거 가능 또는 무한 불연속인지 구분한다.", "두 종류 모두 원래 함수에서는 불연속점이다."),
                    ("서로 다른 불연속점의 좌표를 더한다.", rf"따라서 x좌표의 합은 ${answer}$이다."),
                ],
                alternatives=["약분 전 함수의 정의역을 먼저 기록한 뒤 약분한 식의 극한과 비교할 수 있다."],
                answer_check=lambda roots=denominator_roots: _discontinuity_coordinate_sum(roots),
            )
        )
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 평행이동한 지수함수 부등식과 두 조건의 진리집합이다. 작동 원리는 정수해와 필요·충분조건 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    exponential_rows = [
        (2, 1, -3, 3, "<=", -2, 7),
        (3, -2, 1, 2, ">", -5, 6),
        (5, 0, 4, 1, ">=", -3, 5),
        (4, 3, -2, 2, "<", 0, 9),
        (10, -1, 5, 1, "<=", -4, 4),
    ]
    for index, (base, shift, vertical, target_power, relation, lower, upper) in enumerate(exponential_rows, 1):
        answer = _exponential_integer_count(base, shift, vertical, target_power, relation, lower, upper)
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"정수 범위 ${lower}\le x\le {upper}$에서 지수부등식 ${base}^{{x-({shift})}}+({vertical}){relation}{base}^{target_power}+({vertical})$을 만족하는 정수 x의 개수를 구하시오.",
                answer=str(answer),
                tags=["#지수방정식과지수부등식", "#지수법칙의성질", "#지수부등식", "#지수함수", "#지수함수의평행이동"],
                steps=[
                    ("양변에서 같은 세로 이동량을 뺀다.", rf"${base}^{{x-({shift})}}{relation}{base}^{target_power}$가 된다."),
                    ("밑이 1보다 큰 지수함수의 증가성을 확인한다.", rf"밑 ${base}$에서는 지수의 대소 방향이 유지된다."),
                    ("같은 밑의 지수를 비교한다.", rf"$x-({shift}){relation}{target_power}$이다."),
                    ("x에 대한 일차부등식으로 정리한다.", "가로 이동량을 반대편으로 옮긴다."),
                    ("주어진 정수 범위와 해집합을 교차한다.", rf"${lower}\le x\le {upper}$ 안의 정수만 남긴다."),
                    ("남은 정수의 개수를 센다.", rf"따라서 정수해는 ${answer}$개이다."),
                ],
                alternatives=[
                    "정수 범위의 각 값을 원래 지수부등식에 대입해 정확한 유리수로 비교할 수 있다.",
                    "평행이동 전 기본 지수함수 그래프의 단조성을 이용해 경계점을 읽을 수 있다.",
                ],
                answer_check=lambda a=base, h=shift, k=vertical, power=target_power, op=relation, low=lower, high=upper: _exponential_integer_count(a, h, k, power, op, low, high),
            )
        )
    universe = tuple(range(-6, 7))
    condition_rows: list[tuple[str, str, Callable[[int], bool], Callable[[int], bool]]] = [
        ("x는 4의 배수", "x는 짝수", lambda x: x % 4 == 0, lambda x: x % 2 == 0),
        ("x는 3의 배수", "x는 6의 배수", lambda x: x % 3 == 0, lambda x: x % 6 == 0),
        ("|x|<3", "x²<9", lambda x: abs(x) < 3, lambda x: x * x < 9),
        ("x>1", "x는 양의 짝수", lambda x: x > 1, lambda x: x > 0 and x % 2 == 0),
        ("x²=1", "|x|=1", lambda x: x * x == 1, lambda x: abs(x) == 1),
    ]
    for index, (first_text, second_text, first_condition, second_condition) in enumerate(condition_rows, 6):
        answer = _condition_relation_count(universe, first_condition, second_condition)
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"전체집합 $U=\{{x\in\mathbb Z\mid -6\le x\le6\}}$에서 조건 p는 ‘{first_text}’, q는 ‘{second_text}’이다. ‘p는 q의 충분조건’, ‘p는 q의 필요조건’, ‘p는 q의 필요충분조건’ 중 참인 명제의 개수를 구하시오.",
                answer=str(answer),
                tags=["#충분조건", "#필요조건", "#필요충분조건", "#충분조건과필요조건", "#명제"],
                steps=[
                    ("조건 p를 만족하는 진리집합 P를 구한다.", "전체집합의 각 정수에 p를 대입한다."),
                    ("조건 q를 만족하는 진리집합 Q를 구한다.", "같은 전체집합에서 q의 참인 원소를 모은다."),
                    ("P가 Q의 부분집합인지 확인한다.", "P⊆Q이면 p는 q의 충분조건이다."),
                    ("Q가 P의 부분집합인지 확인한다.", "Q⊆P이면 p는 q의 필요조건이다."),
                    ("두 진리집합이 같은지 확인한다.", "P=Q이면 p는 q의 필요충분조건이다."),
                    ("세 포함관계 중 참인 것을 센다.", rf"따라서 참인 명제는 ${answer}$개이다."),
                ],
                alternatives=[
                    "두 조건의 진리집합을 벤다이어그램에 표시해 포함 방향을 판단할 수 있다.",
                    "각 명제를 조건문으로 바꾸고 반례가 존재하는지 전체집합에서 직접 검사할 수 있다.",
                ],
                answer_check=lambda p=first_condition, q=second_condition: _condition_relation_count(universe, p, q),
            )
        )
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v30 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v30 전체 카탈로그다. 작동 원리는 독립 정답 검산 후 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog = build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v30 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(
        catalog,
        expected_count=50,
        batch_id=BATCH_ID,
        model_name=MODEL_NAME,
        codebase_base=CODEBASE_BASE,
        seed_base=SEED_BASE,
    )


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v30 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(
        db_path,
        quests=validated_quests(),
        batch_id=BATCH_ID,
        validate_only=validate_only,
    )


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v30 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(
        json.dumps(
            seed_database(args.db, validate_only=args.validate_only),
            ensure_ascii=False,
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
