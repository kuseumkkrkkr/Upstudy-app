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

BATCH_ID = "marketplace-original-v28"
MODEL_NAME = "aiflow-direct-authoring-v28"
CODEBASE_BASE = 20_260_989_000
SEED_BASE = 202_607_568_000


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


def _condition_set_sum(lower: int, upper: int, modulus: int, residue: int) -> int:
    """필요 변수는 정수 구간·법·나머지다. 작동 원리는 조건을 만족하는 원소를 직접 나열해 합한다."""
    if lower > upper or modulus <= 0:
        raise ValueError("집합 조건의 범위가 올바르지 않습니다.")
    return sum(
        value
        for value in range(lower, upper + 1)
        if value % modulus == residue % modulus
    )


def _dividend_from_quotient(
    quotient: tuple[int, int, int],
    root: int,
    remainder: int,
) -> tuple[int, int, int, int]:
    """필요 변수는 이차 몫의 계수·일차식의 근·나머지다. 작동 원리는 (x-root)와 몫을 곱한 뒤 나머지를 더해 피제수를 만든다."""
    a, b, c = quotient
    return (a, b - root * a, c - root * b, remainder - root * c)


def _synthetic_quotient_sum(
    dividend: tuple[int, int, int, int],
    root: int,
) -> int:
    """필요 변수는 삼차다항식 계수와 나누는 식 x-root다. 작동 원리는 조립제법을 직접 실행해 몫의 세 계수 합을 구한다."""
    coefficients = [dividend[0]]
    for value in dividend[1:-1]:
        coefficients.append(value + root * coefficients[-1])
    return sum(coefficients)


def _proposition_truth_count(
    domain: tuple[int, ...],
    antecedent: Callable[[int], bool],
    consequent: Callable[[int], bool],
) -> int:
    """필요 변수는 유한 정수 정의역과 두 조건이다. 작동 원리는 원명제·역·대우를 전 원소에 대입해 참인 명제 수를 센다."""
    original = all(not antecedent(value) or consequent(value) for value in domain)
    converse = all(not consequent(value) or antecedent(value) for value in domain)
    contrapositive = all(consequent(value) or not antecedent(value) for value in domain)
    return sum((original, converse, contrapositive))


def _quadratic_integer_count(
    first_root: int,
    second_root: int,
    relation: str,
    lower: int,
    upper: int,
) -> int:
    """필요 변수는 두 근·부등호·정수 탐색 구간이다. 작동 원리는 모든 정수에서 이차식의 부호를 직접 검사해 해의 개수를 센다."""
    comparisons: dict[str, Callable[[int], bool]] = {
        "<": lambda value: value < 0,
        "<=": lambda value: value <= 0,
        ">": lambda value: value > 0,
        ">=": lambda value: value >= 0,
    }
    if relation not in comparisons or lower > upper:
        raise ValueError("이차부등식 조건이 올바르지 않습니다.")
    return sum(
        comparisons[relation]((x - first_root) * (x - second_root))
        for x in range(lower, upper + 1)
    )


def _difference_sequence_term(
    first_term: int,
    slope: int,
    intercept: int,
    target_index: int,
) -> int:
    """필요 변수는 첫째항·계차의 일차식 계수·목표 항 번호다. 작동 원리는 목표 직전까지의 계차를 직접 더한다."""
    if target_index < 1:
        raise ValueError("목표 항 번호는 양의 정수여야 합니다.")
    return first_term + sum(
        slope * index + intercept
        for index in range(1, target_index)
    )


def _nonadjacent_circular_arrangements(people_count: int) -> int:
    """필요 변수는 서로 다른 사람 수다. 작동 원리는 한 사람을 고정하고 나머지 순열을 전수 생성해 지정된 두 사람이 이웃하지 않는 배치를 센다."""
    if people_count < 4:
        raise ValueError("원순열 비인접 조건에는 네 명 이상이 필요합니다.")
    return sum(
        permutation[0] != 1 and permutation[-1] != 1
        for permutation in itertools.permutations(range(1, people_count))
    )


def _rational_infinity_limit(
    numerator: tuple[int, int, int],
    denominator: tuple[int, int, int],
) -> Fraction:
    """필요 변수는 분자·분모 이차다항식 계수다. 작동 원리는 최고차항 계수의 비로 무한대 극한을 구한다."""
    if denominator[0] == 0:
        raise ValueError("분모는 이차다항식이어야 합니다.")
    return Fraction(numerator[0], denominator[0])


def _differentiable_slope(
    point: int,
    quadratic: tuple[int, int, int],
    line_intercept: int,
) -> int:
    """필요 변수는 경계점·왼쪽 이차식 계수·오른쪽 직선 절편이다. 작동 원리는 연속성과 좌우 미분계수 일치를 모두 확인해 직선 기울기를 구한다."""
    a, b, c = quadratic
    slope = 2 * a * point + b
    left_value = a * point**2 + b * point + c
    right_value = slope * point + line_intercept
    if left_value != right_value:
        raise ValueError("구성된 조각함수가 경계점에서 연속이 아닙니다.")
    return slope


def _transformed_velocity_displacement(
    first_integral: int,
    second_integral: int,
    scale: int,
    constant: int,
    end_time: int,
) -> int:
    """필요 변수는 두 구간의 속도 적분값·새 속도의 선형결합 계수·종료 시각이다. 작동 원리는 정적분 선형성으로 전체 위치변화량을 계산한다."""
    return scale * (first_integral + second_integral) + constant * end_time


def _rational_center_sum(a: int, b: int, c: int, d: int) -> Fraction:
    """필요 변수는 일차식 분자·분모의 네 계수다. 작동 원리는 두 점근선의 교점인 유리함수 중심 좌표를 더한다."""
    if c == 0 or a * d - b * c == 0:
        raise ValueError("상수함수가 아닌 일차분수함수여야 합니다.")
    center_x = Fraction(-d, c)
    center_y = Fraction(a, c)
    return center_x + center_y


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 조건제시 집합과 다항식 나눗셈 자료다. 작동 원리는 집합 표현과 조립제법 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    set_rows = [
        (-5, 8, 3, 1),
        (0, 20, 4, 2),
        (-10, 10, 5, 0),
        (1, 30, 6, 3),
        (-8, 12, 4, 1),
    ]
    for index, (lower, upper, modulus, residue) in enumerate(set_rows, 1):
        elements = [
            value
            for value in range(lower, upper + 1)
            if value % modulus == residue % modulus
        ]
        answer = _condition_set_sum(lower, upper, modulus, residue)
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"집합 $A=\{{x\mid x$는 정수, ${lower}\le x\le {upper},\ x\equiv {residue}\pmod{{{modulus}}}\}}$를 원소나열법으로 나타낼 때 모든 원소의 합을 구하시오.",
                answer=str(answer),
                tags=["#원소나열법", "#조건제시법", "#집합", "#집합의표현"],
                steps=[
                    ("주어진 구간에서 나머지 조건을 만족하는 정수를 찾는다.", rf"집합의 원소는 $\{{{','.join(str(value) for value in elements)}\}}$이다."),
                    ("나열한 원소를 모두 더한다.", rf"따라서 원소의 합은 ${answer}$이다."),
                ],
                answer_check=lambda low=lower, high=upper, mod=modulus, rem=residue: _condition_set_sum(low, high, mod, rem),
            )
        )
    division_rows = [
        ((2, -3, 4), 1, 5),
        ((-1, 4, 2), -2, 3),
        ((3, 0, -5), 2, -1),
        ((1, 5, -2), -3, 4),
        ((-2, -1, 6), 4, 2),
    ]
    for index, (quotient, root, remainder) in enumerate(division_rows, 6):
        dividend = _dividend_from_quotient(quotient, root, remainder)
        answer = _synthetic_quotient_sum(dividend, root)
        polynomial = rf"{dividend[0]}x^3+({dividend[1]})x^2+({dividend[2]})x+({dividend[3]})"
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"다항식 $P(x)={polynomial}$를 $x-({root})$로 나눈 몫의 모든 계수의 합을 조립제법으로 구하시오.",
                answer=str(answer),
                tags=["#다항식의나눗셈", "#조립제법", "#나머지정리활용", "#대수"],
                steps=[
                    ("나누는 식의 근을 조립제법 표에 쓴다.", rf"사용할 값은 ${root}$이다."),
                    ("피제수의 계수를 차례로 내려 곱하고 더한 뒤 몫의 계수를 합한다.", rf"몫의 계수는 ${quotient[0]}, {quotient[1]}, {quotient[2]}$이므로 합은 ${answer}$이다."),
                ],
                answer_check=lambda coefficients=dividend, value=root: _synthetic_quotient_sum(coefficients, value),
            )
        )
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 유한 정의역 명제와 이차부등식 조건이다. 작동 원리는 명제의 역·대우와 부등식 해 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    domain = tuple(range(-12, 13))
    proposition_rows: list[tuple[str, str, Callable[[int], bool], Callable[[int], bool]]] = [
        ("n이 4의 배수이다", "n이 짝수이다", lambda n: n % 4 == 0, lambda n: n % 2 == 0),
        ("n이 짝수이다", "n²이 4의 배수이다", lambda n: n % 2 == 0, lambda n: n * n % 4 == 0),
        ("n이 6의 배수이다", "n이 3의 배수이다", lambda n: n % 6 == 0, lambda n: n % 3 == 0),
        ("|n|<3이다", "n²<9이다", lambda n: abs(n) < 3, lambda n: n * n < 9),
        ("n>0이다", "n²>0이다", lambda n: n > 0, lambda n: n * n > 0),
    ]
    for index, (antecedent_text, consequent_text, antecedent, consequent) in enumerate(proposition_rows, 1):
        answer = _proposition_truth_count(domain, antecedent, consequent)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"정의역 $U=\{{n\in\mathbb Z\mid -12\le n\le12\}}$에서 명제 ‘{antecedent_text}이면 {consequent_text}이다’와 그 역, 대우 중 참인 명제의 개수를 구하시오.",
                answer=str(answer),
                tags=["#명제", "#역", "#대우", "#명제의역과대우", "#명제의참거짓"],
                steps=[
                    ("원명제의 모든 반례 후보를 정의역에서 확인한다.", "전제가 참이고 결론이 거짓인 원소가 있는지 조사한다."),
                    ("전제와 결론을 바꾼 역의 참거짓을 확인한다.", "역도 같은 정의역의 모든 정수에서 검사한다."),
                    ("부정한 두 조건의 순서를 바꾼 대우를 확인해 참인 수를 센다.", rf"세 명제 중 참인 것은 ${answer}$개이다."),
                ],
                answer_check=lambda p=antecedent, q=consequent: _proposition_truth_count(domain, p, q),
            )
        )
    inequality_rows = [
        (-2, 4, "<=", -5, 7),
        (1, 6, ">=", -3, 9),
        (-5, -1, "<", -8, 3),
        (2, 7, ">", 0, 10),
        (-3, 5, "<=", -6, 8),
    ]
    for index, (first_root, second_root, relation, lower, upper) in enumerate(inequality_rows, 6):
        answer = _quadratic_integer_count(first_root, second_root, relation, lower, upper)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"정수 범위 ${lower}\le x\le {upper}$에서 이차부등식 $(x-({first_root}))(x-({second_root})){relation}0$을 만족하는 정수 x의 개수를 구하시오.",
                answer=str(answer),
                tags=["#이차부등식", "#이차부등식의풀이", "#이차부등식의해", "#이차함수와이차부등식"],
                steps=[
                    ("이차식이 0이 되는 두 경계점을 찾는다.", rf"경계점은 $x={first_root}, {second_root}$이다."),
                    ("최고차항의 계수가 양수인 부호 구간을 판정한다.", "두 근 사이와 바깥 구간의 부호가 번갈아 바뀐다."),
                    ("부등호와 주어진 정수 범위를 함께 적용한다.", rf"조건을 만족하는 정수는 ${answer}$개이다."),
                ],
                answer_check=lambda left_root=first_root, right_root=second_root, op=relation, low=lower, high=upper: _quadratic_integer_count(left_root, right_root, op, low, high),
            )
        )
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 계차수열과 원순열 인접 조건이다. 작동 원리는 누적 계차와 원탁 배치 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    sequence_rows = [
        (2, 2, 1, 6),
        (-3, 3, -1, 5),
        (5, -1, 6, 7),
        (1, 4, -2, 4),
        (-2, 2, 3, 8),
    ]
    for index, (first_term, slope, intercept, target_index) in enumerate(sequence_rows, 1):
        answer = _difference_sequence_term(first_term, slope, intercept, target_index)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"수열 $\{{a_n\}}$의 첫째항이 $a_1={first_term}$이고 계차가 $a_{{n+1}}-a_n={slope}n+({intercept})$일 때 $a_{target_index}$를 구하시오.",
                answer=str(answer),
                tags=["#계차수열", "#수열", "#수열의정의", "#여러가지수열의합"],
                steps=[
                    ("목표 항까지 필요한 계차의 범위를 정한다.", rf"$n=1$부터 $n={target_index - 1}$까지의 계차를 더한다."),
                    ("계차의 합으로 목표 항을 나타낸다.", rf"$a_{target_index}=a_1+\sum_{{n=1}}^{{{target_index - 1}}}({slope}n+({intercept}))$이다."),
                    ("자연수의 합 공식을 적용한다.", r"$\sum n=\dfrac{m(m+1)}2$를 사용한다."),
                    ("첫째항과 계차 합을 더한다.", rf"따라서 $a_{target_index}={answer}$이다."),
                ],
                alternatives=["계차를 한 항씩 계산해 수열의 항을 순서대로 복원할 수 있다."],
                answer_check=lambda start=first_term, p=slope, q=intercept, target=target_index: _difference_sequence_term(start, p, q, target),
            )
        )
    for index, people_count in enumerate([5, 6, 7, 8, 9], 6):
        total = 1
        for factor in range(2, people_count):
            total *= factor
        adjacent = 2
        for factor in range(2, people_count - 1):
            adjacent *= factor
        answer = _nonadjacent_circular_arrangements(people_count)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"서로 다른 {people_count}명이 원탁에 앉을 때, 특정한 두 사람 A와 B가 서로 이웃하지 않게 앉는 원순열의 수를 구하시오.",
                answer=str(answer),
                tags=["#원순열", "#순열", "#조합"],
                steps=[
                    ("회전이 같은 배치를 하나로 보는 전체 원순열을 센다.", rf"전체 배치는 $({people_count}-1)!={total}$가지이다."),
                    ("A와 B를 한 묶음으로 보는 이웃한 배치를 센다.", rf"두 사람의 순서를 고려하면 $2({people_count}-2)!={adjacent}$가지이다."),
                    ("전체에서 이웃한 배치를 뺀다.", rf"${total}-{adjacent}={answer}$이다."),
                    ("한 사람을 고정한 원탁 자리에서 비인접 위치 수로 검산한다.", rf"따라서 구하는 원순열은 ${answer}$가지이다."),
                ],
                alternatives=["A를 한 자리에 고정하고 B가 양옆 두 자리를 피하도록 나머지 사람을 배열할 수 있다."],
                answer_check=lambda count=people_count: _nonadjacent_circular_arrangements(count),
            )
        )
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 이차식 분수함수와 미분가능한 조각함수다. 작동 원리는 무한대 극한과 좌우 미분계수 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    limit_rows = [
        ((2, -3, 1), (5, 4, -2)),
        ((-3, 2, 7), (4, -1, 5)),
        ((5, 0, -6), (-2, 3, 1)),
        ((1, 8, 4), (3, -5, 2)),
        ((-4, 1, 9), (-6, 2, -3)),
    ]
    for index, (numerator, denominator) in enumerate(limit_rows, 1):
        answer = _rational_infinity_limit(numerator, denominator)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"무한대 극한 $\lim_{{x\to\infty}}\dfrac{{{numerator[0]}x^2+({numerator[1]})x+({numerator[2]})}}{{{denominator[0]}x^2+({denominator[1]})x+({denominator[2]})}}$의 값을 구하시오.",
                answer=str(answer),
                tags=["#무한대의극한", "#극한값계산", "#대수"],
                steps=[
                    ("분자와 분모의 최고차수를 비교한다.", "두 다항식은 모두 이차식이다."),
                    ("분자와 분모를 x²으로 나눈다.", "일차항은 1/x, 상수항은 1/x²을 곱한 꼴이 된다."),
                    ("x가 무한대로 갈 때 역수 항의 극한을 확인한다.", "1/x와 1/x²의 극한은 모두 0이다."),
                    ("남는 최고차항 계수의 비를 쓴다.", rf"극한은 $\dfrac{{{numerator[0]}}}{{{denominator[0]}}}$이다."),
                    ("분수를 기약분수로 정리한다.", rf"따라서 극한값은 ${answer}$이다."),
                ],
                alternatives=["같은 차수의 다항식 비의 무한대 극한은 최고차항 계수의 비라는 성질을 바로 적용할 수 있다."],
                answer_check=lambda top=numerator, bottom=denominator: _rational_infinity_limit(top, bottom),
            )
        )
    differentiable_rows = [
        (1, (1, 2, 0)),
        (2, (2, -1, 3)),
        (-1, (-1, 4, 1)),
        (1, (3, 0, -2)),
        (2, (-2, 5, 4)),
    ]
    for index, (point, quadratic) in enumerate(differentiable_rows, 6):
        a, b, c = quadratic
        slope = 2 * a * point + b
        left_value = a * point**2 + b * point + c
        line_intercept = left_value - slope * point
        answer = _differentiable_slope(point, quadratic, line_intercept)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"함수 $f(x)=\begin{{cases}}{a}x^2+({b})x+({c})&(x\le {point})\\kx+({line_intercept})&(x>{point})\end{{cases}}$가 $x={point}$에서 미분가능할 때 k를 구하시오.",
                answer=str(answer),
                tags=["#미분가능", "#미분계수의기하적의미", "#일치조건", "#상수배의미분", "#접선방정식구하기"],
                steps=[
                    ("왼쪽 이차식의 경계점 함수값을 구한다.", rf"$f({point})={left_value}$이다."),
                    ("오른쪽 직선의 경계점 극한과 함수값이 일치하는지 확인한다.", rf"연속 조건은 ${point}k+({line_intercept})={left_value}$이다."),
                    ("왼쪽 식을 미분한다.", rf"왼쪽 도함수는 ${2 * a}x+({b})$이다."),
                    ("경계점의 왼쪽 미분계수를 계산한다.", rf"왼쪽 미분계수는 ${answer}$이다."),
                    ("오른쪽 직선의 기울기와 같게 둔다.", rf"따라서 $k={answer}$이다."),
                ],
                alternatives=["오른쪽 직선이 경계점에서 왼쪽 포물선의 접선이라는 기하적 의미로 기울기를 구할 수 있다."],
                answer_check=lambda boundary=point, curve=quadratic, intercept=line_intercept: _differentiable_slope(boundary, curve, intercept),
            )
        )
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 속도 적분 구간값과 일차분수함수 계수다. 작동 원리는 정적분 선형성과 쌍곡선 중심 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    displacement_rows = [
        (2, 5, 3, -1, 2, 1),
        (3, 7, -2, 5, 3, -1),
        (1, 4, 4, 2, -1, 2),
        (4, 9, 1, -3, 2, -2),
        (2, 6, -5, 7, 4, 1),
    ]
    for index, (split_time, end_time, first_integral, second_integral, scale, constant) in enumerate(displacement_rows, 1):
        answer = _transformed_velocity_displacement(
            first_integral,
            second_integral,
            scale,
            constant,
            end_time,
        )
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"점 P의 속도 $v(t)$가 $\int_0^{{{split_time}}}v(t)dt={first_integral}$, $\int_{{{split_time}}}^{{{end_time}}}v(t)dt={second_integral}$을 만족한다. 속도가 $w(t)={scale}v(t)+({constant})$인 점 Q의 $0\le t\le {end_time}$ 위치변화량을 구하시오.",
                answer=str(answer),
                tags=["#정적분과속도", "#위치변화량", "#정적분의성질", "#정적분의정의"],
                steps=[
                    ("두 구간의 v(t) 적분값을 더한다.", rf"$\int_0^{{{end_time}}}v(t)dt={first_integral}+({second_integral})={first_integral + second_integral}$이다."),
                    ("Q의 위치변화량을 속도 w(t)의 정적분으로 나타낸다.", rf"$\int_0^{{{end_time}}}w(t)dt$이다."),
                    ("w(t)의 식을 적분에 대입한다.", rf"$\int_0^{{{end_time}}}({scale}v(t)+({constant}))dt$이다."),
                    ("정적분의 선형성을 적용한다.", rf"${scale}\int_0^{{{end_time}}}v(t)dt+({constant})\int_0^{{{end_time}}}1dt$이다."),
                    ("상수함수의 정적분을 계산한다.", rf"$\int_0^{{{end_time}}}1dt={end_time}$이다."),
                    ("두 항을 계산해 더한다.", rf"따라서 위치변화량은 ${answer}$이다."),
                ],
                alternatives=[
                    "각 구간에서 Q의 변위를 따로 계산한 뒤 더할 수 있다.",
                    "속도 그래프를 세로로 배율 변환하고 평행이동했을 때 부호 있는 넓이의 변화를 이용할 수 있다.",
                ],
                answer_check=lambda first=first_integral, second=second_integral, m=scale, c=constant, end=end_time: _transformed_velocity_displacement(first, second, m, c, end),
            )
        )
    rational_rows = [
        (2, 3, 1, -4),
        (3, -1, 2, 4),
        (-1, 5, 1, 2),
        (4, 1, -2, 6),
        (5, -3, 3, -6),
    ]
    for index, (a, b, c, d) in enumerate(rational_rows, 6):
        center_x = Fraction(-d, c)
        center_y = Fraction(a, c)
        answer = _rational_center_sum(a, b, c, d)
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"유리함수 $y=\dfrac{{{a}x+({b})}}{{{c}x+({d})}}$의 그래프인 쌍곡선의 중심 좌표를 구한 뒤 두 좌표의 합을 구하시오.",
                answer=str(answer),
                tags=["#유리식", "#유리식과유리함수", "#유리식의계산", "#쌍곡선", "#중심"],
                steps=[
                    ("분모가 0이 되는 x값을 구한다.", rf"수직점근선은 $x={center_x}$이다."),
                    ("분자와 분모의 최고차항 계수 비를 구한다.", rf"수평점근선은 $y={center_y}$이다."),
                    ("두 점근선이 서로 수직으로 만남을 확인한다.", "쌍곡선의 중심은 두 점근선의 교점이다."),
                    ("중심 좌표를 순서쌍으로 쓴다.", rf"중심은 $({center_x},{center_y})$이다."),
                    ("두 좌표를 같은 분모로 통분한다.", rf"${center_x}+({center_y})$를 계산한다."),
                    ("기약분수로 정리한다.", rf"따라서 두 좌표의 합은 ${answer}$이다."),
                ],
                alternatives=[
                    "일차분수함수를 상수항과 1/(cx+d) 꼴로 나누어 평행이동량을 읽을 수 있다.",
                    "그래프를 중심에 대해 180도 회전했을 때 식이 보존되는지 대수적으로 검산할 수 있다.",
                ],
                answer_check=lambda top_x=a, top_c=b, bottom_x=c, bottom_c=d: _rational_center_sum(top_x, top_c, bottom_x, bottom_c),
            )
        )
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v28 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v28 전체 카탈로그다. 작동 원리는 독립 정답 검산 후 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog = build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v28 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(
        catalog,
        expected_count=50,
        batch_id=BATCH_ID,
        model_name=MODEL_NAME,
        codebase_base=CODEBASE_BASE,
        seed_base=SEED_BASE,
    )


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v28 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(
        db_path,
        quests=validated_quests(),
        batch_id=BATCH_ID,
        validate_only=validate_only,
    )


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v28 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
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
