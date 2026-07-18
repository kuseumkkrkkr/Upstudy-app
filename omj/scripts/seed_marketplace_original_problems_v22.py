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

BATCH_ID = "marketplace-original-v22"
MODEL_NAME = "aiflow-direct-authoring-v22"
CODEBASE_BASE = 20_260_983_000
SEED_BASE = 202_607_562_000


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


def _difference_element_sum(left: tuple[int, ...], right: tuple[int, ...]) -> int:
    """필요 변수는 두 유한집합의 원소다. 작동 원리는 왼쪽 집합에만 속하는 원소를 골라 합한다."""
    return sum(value for value in left if value not in set(right))


def _identity_constant(coefficient: int, shift: int, extra: int) -> int:
    """필요 변수는 일차식의 계수·이동량·추가 상수다. 작동 원리는 항등식을 전개해 오른쪽 상수항을 계산한다."""
    return coefficient * shift + extra


def _conjugate_product(real: int, imaginary: int) -> int:
    """필요 변수는 복소수의 실수부와 허수부다. 작동 원리는 켤레복소수 곱의 합차공식으로 제곱합을 구한다."""
    return real**2 + imaginary**2


def _pascal_sum(total: int, chosen: int) -> int:
    """필요 변수는 조합의 전체 수와 선택 수다. 작동 원리는 파스칼 항등식의 왼쪽 두 조합을 별도로 계산해 더한다."""
    return math.comb(total, chosen) + math.comb(total, chosen + 1)


def _polynomial_remainder(coefficients: tuple[int, int, int, int], divisor_root: int) -> int:
    """필요 변수는 삼차다항식 계수와 일차식의 근이다. 작동 원리는 호너법으로 다항식 값을 계산해 나머지를 구한다."""
    value = 0
    for coefficient in coefficients:
        value = value * divisor_root + coefficient
    return value


def _injective_mapping_count(domain_size: int, codomain_size: int) -> int:
    """필요 변수는 정의역과 공역의 원소 수다. 작동 원리는 서로 다른 치역값을 순서 있게 배정하는 경우를 곱한다."""
    if domain_size > codomain_size:
        return 0
    result = 1
    for offset in range(domain_size):
        result *= codomain_size - offset
    return result


def _exponential_integer_boundary(
    base_kind: str,
    exponent_offset: int,
    right_exponent: int,
) -> int:
    """필요 변수는 밑의 증가·감소 유형과 양쪽 지수다. 작동 원리는 단조성에 따라 부등호 방향을 정한 뒤 정수 경계값을 구한다."""
    numerator = right_exponent - exponent_offset
    if base_kind == "increasing":
        return math.floor(Fraction(numerator, 2))
    if base_kind == "decreasing":
        return math.ceil(Fraction(numerator, 2))
    raise ValueError("지원하지 않는 지수함수 유형입니다.")


def _quadratic_interval_max(vertex: int, height: int, left: int, right: int) -> int:
    """필요 변수는 아래로 열린 포물선의 꼭짓점과 닫힌구간이다. 작동 원리는 꼭짓점에 더 가까운 끝점에서 함수값을 비교해 최댓값을 구한다."""
    values = [-(point - vertex) ** 2 + height for point in (left, right)]
    return max(values)


def _necessary_sufficient_sum(radius: int) -> int:
    """필요 변수는 절댓값 조건의 양의 반지름이다. 작동 원리는 두 해집합이 같아지는 제곱 조건을 구해 반지름과 매개변수를 더한다."""
    parameter = radius**2
    return radius + parameter


def _inverse_affine_coefficient_sum(coefficient: int, constant: int) -> Fraction:
    """필요 변수는 일차함수 g의 계수와 상수항이다. 작동 원리는 f와 g의 합성이 항등함수라는 두 계수 조건을 풀어 f의 계수합을 구한다."""
    if coefficient == 0:
        raise ValueError("역함수를 만들 수 없는 상수함수입니다.")
    a = Fraction(1, coefficient)
    b = Fraction(-constant, coefficient)
    return a + b


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 집합과 일차 항등식 계수다. 작동 원리는 미사용 태그를 다루는 난이도 1 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    difference_rows = [
        ((1, 4, 7, 10), (1, 7)),
        ((2, 5, 8, 11, 14), (5, 11)),
        ((-4, 1, 6, 10), (-4, 10)),
        ((3, 8, 13, 18), (8, 18)),
        ((5, 9, 12, 17, 21), (5, 12, 21)),
    ]
    for index, (left, right) in enumerate(difference_rows, 1):
        answer = _difference_element_sum(left, right)
        left_text = ",".join(str(value) for value in left)
        right_text = ",".join(str(value) for value in right)
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"집합 $A=\{{{left_text}\}}$, $B=\{{{right_text}\}}$일 때, 차집합 $A-B$의 모든 원소의 합을 구하시오.",
                answer=str(answer),
                tags=["#집합", "#집합의표현", "#차집합"],
                steps=[
                    ("A에는 속하고 B에는 속하지 않는 원소를 고른다.", rf"차집합은 $A-B=\{{{','.join(str(value) for value in left if value not in set(right))}\}}$이다."),
                    ("차집합의 원소를 모두 더한다.", rf"따라서 모든 원소의 합은 ${answer}$이다."),
                ],
                answer_check=lambda first=left, second=right: _difference_element_sum(first, second),
            )
        )
    identity_rows = [(2, 3, 1), (3, 4, -2), (-2, 5, 3), (4, -3, 2), (-3, -2, 5)]
    for index, (coefficient, shift, extra) in enumerate(identity_rows, 6):
        answer = _identity_constant(coefficient, shift, extra)
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"$x$에 대한 항등식 ${coefficient}(x+({shift}))+({extra})={coefficient}x+k$가 성립할 때, 상수 $k$를 구하시오.",
                answer=str(answer),
                tags=["#항등식", "#항등식의성질", "#항"],
                steps=[
                    ("왼쪽 식을 분배법칙으로 전개한다.", rf"왼쪽은 ${coefficient}x+({coefficient * shift})+({extra})$이다."),
                    ("양변의 상수항이 같아야 함을 이용한다.", rf"따라서 $k={coefficient * shift}+({extra})={answer}$이다."),
                ],
                answer_check=lambda a=coefficient, p=shift, q=extra: _identity_constant(a, p, q),
            )
        )
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 복소수 성분과 조합의 두 이웃 항이다. 작동 원리는 미사용 태그를 다루는 난이도 2 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    for index, (real, imaginary) in enumerate([(2, 3), (4, 1), (-3, 5), (6, -2), (-4, -5)], 1):
        answer = _conjugate_product(real, imaginary)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"복소수 $z={real}+({imaginary})i$와 그 켤레복소수 $\overline z$에 대하여 $z\overline z$의 값을 구하시오.",
                answer=str(answer),
                tags=["#켤레복소수", "#합차공식"],
                steps=[
                    ("주어진 복소수의 켤레복소수를 쓴다.", rf"$\overline z={real}-({imaginary})i$이다."),
                    ("두 식의 곱에 합차공식을 적용한다.", rf"$z\overline z={real}^2-(({imaginary})i)^2={real}^2+({imaginary})^2$이다."),
                    ("두 제곱을 더한다.", rf"따라서 $z\overline z={answer}$이다."),
                ],
                answer_check=lambda a=real, b=imaginary: _conjugate_product(a, b),
            )
        )
    for index, (total, chosen) in enumerate([(5, 1), (6, 2), (7, 3), (8, 2), (9, 4)], 6):
        left = math.comb(total, chosen)
        right = math.comb(total, chosen + 1)
        answer = _pascal_sum(total, chosen)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"조합의 값 $\binom{{{total}}}{{{chosen}}}+\binom{{{total}}}{{{chosen + 1}}}$을 계산하시오.",
                answer=str(answer),
                tags=["#조합의성질", "#합의법칙"],
                steps=[
                    ("첫 번째 조합을 계산한다.", rf"$\binom{{{total}}}{{{chosen}}}={left}$이다."),
                    ("두 번째 조합을 계산한다.", rf"$\binom{{{total}}}{{{chosen + 1}}}={right}$이다."),
                    ("합의법칙으로 두 경우를 더한다.", rf"따라서 주어진 값은 ${left}+{right}={answer}$이다."),
                ],
                answer_check=lambda n=total, r=chosen: _pascal_sum(n, r),
            )
        )
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 삼차다항식과 두 유한집합의 크기다. 작동 원리는 미사용 태그를 다루는 난이도 3 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    remainder_rows = [
        ((1, 2, -5, 4), 2),
        ((2, -1, 3, -7), -1),
        ((-1, 4, 2, 5), 3),
        ((3, -2, 1, 6), 2),
        ((2, 5, -4, -3), -2),
    ]
    for index, (coefficients, root) in enumerate(remainder_rows, 1):
        a, b, c, d = coefficients
        answer = _polynomial_remainder(coefficients, root)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"다항식 $P(x)=({a})x^3+({b})x^2+({c})x+({d})$를 $x-({root})$로 나눌 때의 나머지를 구하시오.",
                answer=str(answer),
                tags=["#조립제법", "#나머지정리활용", "#인수정리활용"],
                steps=[
                    ("나머지정리를 적용할 대입값을 찾는다.", rf"나누는 식 $x-({root})$가 0이 되는 값은 $x={root}$이다."),
                    ("나머지가 다항식의 대입값과 같음을 이용한다.", rf"나머지는 $P({root})$이다."),
                    ("조립제법과 같은 순서로 계수를 누적 계산한다.", rf"계수 ${a},{b},{c},{d}$에 ${root}$를 차례로 곱하고 더한다."),
                    ("마지막 누적값을 나머지로 읽는다.", rf"따라서 나머지는 $P({root})={answer}$이다."),
                ],
                alternatives=["다항식에 x값을 직접 대입해 각 항을 계산한 뒤 더해도 같은 나머지를 얻는다."],
                answer_check=lambda values=coefficients, value=root: _polynomial_remainder(values, value),
            )
        )
    for index, (domain_size, codomain_size) in enumerate([(2, 5), (3, 5), (3, 6), (4, 6), (4, 7)], 6):
        answer = _injective_mapping_count(domain_size, codomain_size)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"원소가 ${domain_size}$개인 정의역 $A$에서 원소가 ${codomain_size}$개인 공역 $B$로 가는 일대일함수의 개수를 구하시오.",
                answer=str(answer),
                tags=["#일대일함수", "#함수", "#함수의정의", "#공역", "#치역", "#대응"],
                steps=[
                    ("일대일함수의 대응 조건을 확인한다.", "정의역의 서로 다른 원소는 공역의 서로 다른 원소에 대응해야 한다."),
                    ("첫 정의역 원소의 함숫값을 고른다.", rf"첫 원소에는 ${codomain_size}$가지 선택이 있다."),
                    ("이미 쓴 공역 원소를 제외하며 선택 수를 곱한다.", rf"선택 수는 ${codomain_size}\cdot({codomain_size}-1)\cdots({codomain_size}-{domain_size - 1})$이다."),
                    ("순서 있는 선택의 곱을 계산한다.", rf"따라서 일대일함수의 개수는 ${answer}$개이다."),
                ],
                alternatives=["공역 원소 중 정의역 크기만큼을 고른 뒤 정의역 원소와 일대일로 순열 배치할 수 있다."],
                answer_check=lambda m=domain_size, n=codomain_size: _injective_mapping_count(m, n),
            )
        )
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 지수함수의 단조 유형과 포물선의 제한 구간이다. 작동 원리는 미사용 태그를 다루는 난이도 4 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    exponential_rows = [
        ("increasing", 2, 1, 8),
        ("increasing", 3, -2, 7),
        ("increasing", 5, 3, 12),
        ("decreasing", 2, 1, 8),
        ("decreasing", 3, -2, 7),
    ]
    for index, (kind, base, offset, right) in enumerate(exponential_rows, 1):
        answer = _exponential_integer_boundary(kind, offset, right)
        if kind == "increasing":
            base_text = str(base)
            boundary_word = "가장 큰"
            monotonic_step = rf"${base}>1$이므로 지수함수는 증가하고 지수의 부등호 방향이 유지된다."
            exponent_relation = rf"$2x+({offset})\le {right}$이다."
            tag = "#증가함수"
        else:
            base_text = rf"\dfrac1{{{base}}}"
            boundary_word = "가장 작은"
            monotonic_step = rf"$0<\dfrac1{{{base}}}<1$이므로 지수함수는 감소하고 지수의 부등호 방향이 뒤집힌다."
            exponent_relation = rf"$2x+({offset})\ge {right}$이다."
            tag = "#감소함수"
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"지수부등식 $({base_text})^{{2x+({offset})}}\le({base_text})^{{{right}}}$을 만족하는 정수 $x$ 중 {boundary_word} 값을 구하시오.",
                answer=str(answer),
                tags=["#지수부등식", "#지수함수", "#지수함수의성질", tag],
                steps=[
                    ("양변의 밑이 같고 양수임을 확인한다.", rf"공통 밑은 ${base_text}$이다."),
                    ("밑의 범위로 증가·감소를 판정한다.", monotonic_step),
                    ("지수끼리 비교하는 일차부등식을 세운다.", exponent_relation),
                    ("일차부등식을 풀어 실수 해의 경계를 구한다.", rf"정수 해의 경계는 $({right}-({offset}))/2$에서 결정된다."),
                    ("문제에서 요구한 정수 경계값을 선택한다.", rf"따라서 {boundary_word} 정수 $x$는 ${answer}$이다."),
                ],
                alternatives=["두 지수함수 그래프의 단조 방향을 이용해 어느 쪽 지수가 더 커야 하는지 시각적으로 판정할 수 있다."],
                answer_check=lambda mode=kind, p=offset, q=right: _exponential_integer_boundary(mode, p, q),
            )
        )
    quadratic_rows = [(5, 20, 0, 2), (-3, 15, 0, 4), (2, 18, 4, 7), (0, 25, 3, 6), (7, 30, 1, 4)]
    for index, (vertex, height, left, right) in enumerate(quadratic_rows, 6):
        answer = _quadratic_interval_max(vertex, height, left, right)
        left_value = -(left - vertex) ** 2 + height
        right_value = -(right - vertex) ** 2 + height
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"함수 $f(x)=-(x-({vertex}))^2+({height})$의 정의역이 ${left}\le x\le {right}$일 때 최댓값을 구하시오.",
                answer=str(answer),
                tags=["#정의역에서의최대최소", "#최대최소문제", "#최댓값", "#축"],
                steps=[
                    ("포물선의 방향과 축을 확인한다.", rf"아래로 열린 포물선이고 축은 $x={vertex}$이다."),
                    ("꼭짓점이 주어진 정의역에 포함되는지 판정한다.", rf"$x={vertex}$는 구간 $[{left},{right}]$ 밖에 있다."),
                    ("구간에서 꼭짓점에 가장 가까운 끝점을 찾는다.", "축과의 거리가 작은 끝점에서 함수값이 더 크다."),
                    ("두 끝점의 함수값을 계산해 비교한다.", rf"$f({left})={left_value}$, $f({right})={right_value}$이다."),
                    ("더 큰 함수값을 최댓값으로 선택한다.", rf"따라서 주어진 정의역에서 최댓값은 ${answer}$이다."),
                ],
                alternatives=["함수의 증가·감소 방향을 구간에 제한한 뒤 최댓값이 생기는 끝점을 바로 선택할 수 있다."],
                answer_check=lambda h=vertex, k=height, a=left, b=right: _quadratic_interval_max(h, k, a, b),
            )
        )
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 절댓값 명제의 반지름과 서로 역인 일차함수 계수다. 작동 원리는 미사용 태그를 다루는 난이도 5 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    for index, radius in enumerate([3, 4, 5, 6, 7], 1):
        parameter = radius**2
        answer = _necessary_sufficient_sum(radius)
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"실수 $x$에 대한 두 조건 $p:|x|<{radius}$, $q:x^2<b$가 서로 필요충분조건이 되도록 하는 양수 $b$에 대하여 ${radius}+b$를 구하시오.",
                answer=str(answer),
                tags=["#필요조건", "#충분조건", "#필요충분조건", "#충분조건과필요조건"],
                steps=[
                    ("조건 p의 해집합을 구간으로 나타낸다.", rf"$p$의 해집합은 $(-{radius},{radius})$이다."),
                    ("조건 q가 해를 갖기 위한 매개변수 범위를 확인한다.", "양수 b에 대하여 q는 절댓값 부등식으로 바꿀 수 있다."),
                    ("조건 q의 해집합을 나타낸다.", r"$x^2<b$는 $|x|<\sqrt b$와 같으므로 해집합은 $(-\sqrt b,\sqrt b)$이다."),
                    ("p가 q의 충분조건이 되는 포함관계를 적용한다.", rf"$p\Rightarrow q$이려면 $b\ge {radius**2}$이어야 한다."),
                    ("p가 q의 필요조건이 되는 반대 포함관계를 적용한다.", rf"$q\Rightarrow p$이려면 $b\le {radius**2}$이어야 하므로 $b={parameter}$이다."),
                    ("주어진 합을 계산한다.", rf"따라서 ${radius}+b={radius}+{parameter}={answer}$이다."),
                ],
                alternatives=[
                    "두 열린구간의 양 끝점이 일치해야 한다고 보고 제곱근 경계를 직접 비교할 수 있다.",
                    "각 함의의 반례가 생기지 않는 b의 범위를 따로 구한 뒤 교집합을 취할 수 있다.",
                ],
                answer_check=lambda value=radius: _necessary_sufficient_sum(value),
            )
        )
    affine_rows = [(2, 3), (3, -2), (-2, 7), (4, 1), (-3, -4)]
    for index, (coefficient, constant) in enumerate(affine_rows, 6):
        answer = _inverse_affine_coefficient_sum(coefficient, constant)
        a = Fraction(1, coefficient)
        b = Fraction(-constant, coefficient)
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"일차함수 $f(x)=ax+b$, $g(x)=({coefficient})x+({constant})$가 모든 실수 $x$에 대하여 $(f\circ g)(x)=x$를 만족할 때, $a+b$를 구하시오.",
                answer=str(answer),
                tags=["#합성함수의정의", "#합성함수의성질", "#역", "#역함수의그래프", "#일치조건"],
                steps=[
                    ("합성함수의 정의에 따라 g의 식을 f에 대입한다.", rf"$(f\circ g)(x)=a(({coefficient})x+({constant}))+b$이다."),
                    ("합성식을 일차식으로 정리한다.", rf"$(f\circ g)(x)=({coefficient})ax+({constant})a+b$이다."),
                    ("항등함수 x와 일차항 계수를 비교한다.", rf"$({coefficient})a=1$이므로 $a={a}$이다."),
                    ("상수항이 0이어야 하는 조건을 세운다.", rf"$({constant})a+b=0$이다."),
                    ("구한 a를 대입해 b를 결정한다.", rf"$b=-({constant})a={b}$이다."),
                    ("두 계수를 더해 요구한 값을 계산한다.", rf"따라서 $a+b={a}+({b})={answer}$이다."),
                ],
                alternatives=[
                    "f가 g의 역함수라는 점에서 g의 식을 x와 y로 바꾼 뒤 y에 대해 풀 수 있다.",
                    "반대 합성 g∘f도 항등함수가 되는지 두 계수를 대입해 검산할 수 있다.",
                ],
                answer_check=lambda c=coefficient, d=constant: _inverse_affine_coefficient_sum(c, d),
            )
        )
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v22 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v22 전체 카탈로그다. 작동 원리는 모든 정답 검산 함수를 실행한 뒤 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog = build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v22 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(catalog, expected_count=50, batch_id=BATCH_ID, model_name=MODEL_NAME, codebase_base=CODEBASE_BASE, seed_base=SEED_BASE)


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v22 전체 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(db_path, quests=validated_quests(), batch_id=BATCH_ID, validate_only=validate_only)


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v22 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
