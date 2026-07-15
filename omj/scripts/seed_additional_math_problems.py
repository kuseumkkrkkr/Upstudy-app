from __future__ import annotations

import argparse
import json
import os
import re
import sqlite3
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from difficulty_contract import DIFFICULTY_CONTRACTS
from scripts.seed_initial_math_problems import (
    BATCH_ID as INITIAL_BATCH_ID,
    QUEST_ID_PREFIX as INITIAL_QUEST_ID_PREFIX,
    _build_quest as _build_base_quest,
    _content_text,
    _create_backup,
    _problem,
    _remove_inserted_batch,
    _walk_steps,
)
from student_problem_content_review import review_student_problem_contract


BATCH_ID = "additional-math-v2"
QUEST_ID_PREFIX = f"curated/{BATCH_ID}"
BACKUP_SUFFIX = "before_curated-only-v2"
ALLOWED_QUEST_PREFIXES = (INITIAL_QUEST_ID_PREFIX, QUEST_ID_PREFIX)
PLACEMENT_SUBJECT_KEYS = ("common_math_1", "common_math_2", "algebra", "calculus_1")


def _append_problem(
    catalog: list[dict[str, Any]],
    counters: Counter[int],
    tier: int,
    *,
    title: str,
    answer: int | str,
    tags: list[str],
    steps: list[tuple[str, str]],
    alternatives: list[str] | None = None,
) -> None:
    """필요 변수: 카탈로그·티어·문제 명세. 작동 원리: 티어별 순번을 자동 증가시켜 결정적 문제 ID의 원본 명세를 추가한다."""
    counters[tier] += 1
    catalog.append(
        _problem(
            tier,
            counters[tier],
            title=title,
            answer=str(answer),
            tags=tags,
            steps=steps,
            alternatives=alternatives,
        )
    )


def _quadratic_latex(a: int, b: int, c: int) -> str:
    """필요 변수: 이차식의 세 계수. 작동 원리: 음수 계수도 모호하지 않도록 괄호를 사용한 LaTeX 식을 만든다."""
    return rf"({a})x^2+({b})x+({c})"


def _cubic_latex(a: int, b: int, c: int, d: int) -> str:
    """필요 변수: 삼차식의 네 계수. 작동 원리: 생성 템플릿의 대입식과 해설이 같은 계수를 공유하도록 표준 문자열을 만든다."""
    return rf"({a})x^3+({b})x^2+({c})x+({d})"


def _predecessors(target: int, odd_increment: int) -> set[int]:
    """필요 변수: 다음 항과 홀수 항 증가량. 작동 원리: 짝수 절반 경로와 유효한 양의 홀수 증가 경로를 역산한다."""
    values = {2 * target}
    odd_candidate = target - odd_increment
    if odd_candidate > 0 and odd_candidate % 2 == 1:
        values.add(odd_candidate)
    return values


def _backward_layers(final_value: int, odd_increment: int, transitions: int) -> list[set[int]]:
    """필요 변수: 마지막 항·홀수 증가량·역산 횟수. 작동 원리: 각 단계의 가능한 직전 항 집합을 중복 없이 계산한다."""
    layers: list[set[int]] = []
    current = {final_value}
    for _ in range(transitions):
        previous: set[int] = set()
        for value in current:
            previous.update(_predecessors(value, odd_increment))
        layers.append(previous)
        current = previous
    return layers


def _forward_values(first_value: int, odd_increment: int, transitions: int) -> list[int]:
    """필요 변수: 첫째항·홀수 증가량·진행 횟수. 작동 원리: 역산 후보를 원래 점화식으로 다시 계산해 대안 검산 문구를 만든다."""
    values = [first_value]
    for _ in range(transitions):
        current = values[-1]
        values.append(current // 2 if current % 2 == 0 else current + odd_increment)
    return values


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수: 없음. 작동 원리: 25개 수능형 구조에 네 수치 변형을 적용해 난이도별 20개씩 총 100문항을 만든다."""
    catalog: list[dict[str, Any]] = []
    counters: Counter[int] = Counter()

    # 난이도 1: 한 개념과 두 풀이 단계로 끝나는 기본 계산형이다.
    for a, b, c, x in (
        (2, -1, 3, 2),
        (3, -2, -1, 3),
        (-1, 4, 5, -2),
        (4, 1, -6, -1),
    ):
        answer = a * x * x + b * x + c
        expression = _quadratic_latex(a, b, c)
        _append_problem(
            catalog,
            counters,
            1,
            title=rf"다항식 $P(x)={expression}$에 대하여 $P({x})$의 값을 구하시오.",
            answer=answer,
            tags=["#다항식의연산"],
            steps=[
                (rf"다항식에 $x={x}$를 대입한다.", rf"$P({x})=({a})({x})^2+({b})({x})+({c})$이다."),
                ("거듭제곱과 사칙연산을 순서대로 계산한다.", rf"식을 정리하면 $P({x})={answer}$이다."),
            ],
        )

    for first_root, second_root in ((1, 4), (-2, 3), (-4, -1), (2, 5)):
        root_sum = first_root + second_root
        root_product = first_root * second_root
        larger = max(first_root, second_root)
        _append_problem(
            catalog,
            counters,
            1,
            title=rf"이차방정식 $x^2-({root_sum})x+({root_product})=0$의 두 근 중 큰 값을 구하시오.",
            answer=larger,
            tags=["#이차방정식"],
            steps=[
                ("두 근을 이용해 좌변을 일차식의 곱으로 나타낸다.", rf"좌변은 $(x-({first_root}))(x-({second_root}))$로 인수분해된다."),
                ("두 근을 비교해 큰 값을 고른다.", rf"두 근은 ${first_root},{second_root}$이므로 큰 값은 ${larger}$이다."),
            ],
        )

    for first, difference, index in ((5, 2, 8), (-3, 4, 6), (10, -2, 7), (1, 5, 9)):
        answer = first + (index - 1) * difference
        _append_problem(
            catalog,
            counters,
            1,
            title=rf"첫째항이 ${first}$이고 공차가 ${difference}$인 등차수열 $\{{a_n\}}$에서 $a_{{{index}}}$을 구하시오.",
            answer=answer,
            tags=["#등차수열"],
            steps=[
                ("등차수열의 일반항에 첫째항과 공차를 대입한다.", rf"$a_n={first}+(n-1)({difference})$이다."),
                ("요구한 항의 번호를 대입한다.", rf"$a_{{{index}}}={first}+({index}-1)({difference})={answer}$이다."),
            ],
        )

    for base, shift, target_exponent in ((3, 2, 5), (2, -1, 6), (5, 3, 1), (4, -2, 4)):
        answer = target_exponent - shift
        _append_problem(
            catalog,
            counters,
            1,
            title=rf"방정식 ${base}^{{x+({shift})}}={base}^{{{target_exponent}}}$을 만족하는 실수 $x$를 구하시오.",
            answer=answer,
            tags=["#지수방정식"],
            steps=[
                ("양변의 밑이 같으므로 지수를 비교한다.", rf"$x+({shift})={target_exponent}$이다."),
                ("지수에 대한 일차방정식을 푼다.", rf"$x={target_exponent}-({shift})={answer}$이다."),
            ],
        )

    for cubic_coefficient, linear_coefficient, x in ((1, -4, 3), (2, 1, -1), (-1, 5, 2), (3, -2, 0)):
        answer = 3 * cubic_coefficient * x * x + linear_coefficient
        _append_problem(
            catalog,
            counters,
            1,
            title=rf"함수 $f(x)=({cubic_coefficient})x^3+({linear_coefficient})x$에 대하여 $f'({x})$의 값을 구하시오.",
            answer=answer,
            tags=["#도함수"],
            steps=[
                ("거듭제곱의 미분법으로 도함수를 구한다.", rf"$f'(x)=({3 * cubic_coefficient})x^2+({linear_coefficient})$이다."),
                ("도함수에 주어진 좌표를 대입한다.", rf"$f'({x})={answer}$이다."),
            ],
        )

    # 난이도 2: 두 개념과 세 풀이 단계가 필요한 표준 응용형이다.
    for root, square_coefficient, constant, coefficient, remainder in (
        (1, -1, 2, 5, 7),
        (2, 1, -3, 4, 17),
        (-1, 2, 5, -3, 9),
        (3, -2, 1, 2, 16),
    ):
        _append_problem(
            catalog,
            counters,
            2,
            title=rf"다항식 $P(x)=x^3+({square_coefficient})x^2+ax+({constant})$를 $x-({root})$로 나눈 나머지가 ${remainder}$일 때, $a$를 구하시오.",
            answer=coefficient,
            tags=["#나머지정리", "#미정계수법"],
            steps=[
                ("나머지정리로 나머지 조건을 함숫값으로 바꾼다.", rf"$P({root})={remainder}$이다."),
                ("주어진 수를 대입해 미정계수의 일차방정식을 만든다.", rf"$({root})^3+({square_coefficient})({root})^2+a({root})+({constant})={remainder}$이다."),
                ("일차방정식을 풀어 계수를 정한다.", rf"식을 정리하면 $a={coefficient}$이다."),
            ],
        )

    for alpha, beta in ((2, 5), (-1, 4), (-3, -2), (1, 6)):
        root_sum = alpha + beta
        root_product = alpha * beta
        answer = root_sum * root_sum - 2 * root_product
        _append_problem(
            catalog,
            counters,
            2,
            title=rf"이차방정식 $x^2-({root_sum})x+({root_product})=0$의 두 근을 $\alpha,\beta$라 할 때, $\alpha^2+\beta^2$을 구하시오.",
            answer=answer,
            tags=["#근과계수의관계", "#이차방정식"],
            steps=[
                ("근과 계수의 관계로 두 근의 합과 곱을 구한다.", rf"$\alpha+\beta={root_sum}$, $\alpha\beta={root_product}$이다."),
                ("두 제곱의 합을 합과 곱으로 바꾼다.", r"$\alpha^2+\beta^2=(\alpha+\beta)^2-2\alpha\beta$이다."),
                ("구한 값을 대입해 계산한다.", rf"$({root_sum})^2-2({root_product})={answer}$이다."),
            ],
        )

    for second, ratio in ((4, 2), (3, 3), (5, 2), (2, 4)):
        fifth = second * ratio**3
        fourth = second * ratio**2
        _append_problem(
            catalog,
            counters,
            2,
            title=rf"등비수열 $\{{a_n\}}$에서 $a_2={second}$, $a_5={fifth}$이고 공비가 양수일 때, $a_4$를 구하시오.",
            answer=fourth,
            tags=["#등비수열", "#등비수열의일반항"],
            steps=[
                ("두 항의 비로 공비의 세제곱을 구한다.", rf"$a_5/a_2=r^3={ratio**3}$이다."),
                ("양의 공비 조건으로 공비를 정한다.", rf"$r={ratio}$이다."),
                ("둘째 항에서 공비를 두 번 곱한다.", rf"$a_4=a_2r^2={second}\cdot({ratio})^2={fourth}$이다."),
            ],
        )

    for base, shift, exponent in ((2, 3, 4), (3, -2, 3), (5, 1, 2), (4, -3, 2)):
        answer = shift + base**exponent
        _append_problem(
            catalog,
            counters,
            2,
            title=rf"방정식 $\log_{{{base}}}(x-({shift}))={exponent}$을 만족하는 실수 $x$를 구하시오.",
            answer=answer,
            tags=["#로그방정식", "#진수조건"],
            steps=[
                ("로그의 진수 조건을 확인한다.", rf"$x-({shift})>0$이어야 한다."),
                ("로그의 정의로 지수식으로 바꾼다.", rf"$x-({shift})={base}^{exponent}={base**exponent}$이다."),
                ("해를 구하고 진수 조건을 확인한다.", rf"$x={answer}$이고 진수는 양수이므로 유효하다."),
            ],
        )

    for square_coefficient, constant, upper in ((3, 2, 2), (6, -1, 1), (3, 1, 3), (12, 2, 1)):
        answer = square_coefficient * upper**3 // 3 + constant * upper
        _append_problem(
            catalog,
            counters,
            2,
            title=rf"정적분 $\int_0^{{{upper}}}(({square_coefficient})x^2+({constant}))\,dx$의 값을 구하시오.",
            answer=answer,
            tags=["#정적분", "#정적분의계산"],
            steps=[
                ("피적분함수의 한 부정적분을 구한다.", rf"한 부정적분은 $({square_coefficient}/3)x^3+({constant})x$이다."),
                ("위끝과 아래끝을 대입한다.", rf"정적분은 $({square_coefficient}/3)({upper})^3+({constant})({upper})$이다."),
                ("식을 정리해 값을 구한다.", rf"계산 결과는 ${answer}$이다."),
            ],
        )

    # 난이도 3: 세 개념, 네 본 단계, 한 대안 분기를 갖는다.
    for first, second, third in ((1, 2, 4), (-1, 2, 3), (-3, 1, 2), (2, 3, 5)):
        coefficient_a = -(first + second + third)
        coefficient_b = first * second + second * third + third * first
        answer = coefficient_a + coefficient_b
        constant = -(first * second * third)
        _append_problem(
            catalog,
            counters,
            3,
            title=rf"최고차항의 계수가 $1$인 삼차다항식 $P(x)=x^3+ax^2+bx+({constant})$의 세 근이 ${first},{second},{third}$일 때, $a+b$를 구하시오.",
            answer=answer,
            tags=["#인수정리", "#근과계수의관계", "#고차식인수분해"],
            steps=[
                ("세 근으로 다항식의 인수 형태를 세운다.", rf"$P(x)=(x-({first}))(x-({second}))(x-({third}))$이다."),
                ("세 근의 합으로 이차항 계수를 구한다.", rf"$a=-(({first})+({second})+({third}))={coefficient_a}$이다."),
                ("두 근씩 곱한 합으로 일차항 계수를 구한다.", rf"$b=({first})({second})+({second})({third})+({third})({first})={coefficient_b}$이다."),
                ("두 계수를 더한다.", rf"$a+b={coefficient_a}+({coefficient_b})={answer}$이다."),
            ],
            alternatives=[rf"세 일차식을 직접 전개해도 $a={coefficient_a}$, $b={coefficient_b}$를 얻는다."],
        )

    for first, increment, last_index in ((2, 1, 4), (1, 3, 4), (-2, 2, 5), (3, 2, 4)):
        values = [first + increment * n * (n - 1) // 2 for n in range(1, last_index + 1)]
        answer = sum(values)
        value_text = ",".join(str(value) for value in values)
        _append_problem(
            catalog,
            counters,
            3,
            title=rf"수열 $\{{a_n\}}$이 $a_1={first}$, $a_{{n+1}}=a_n+({increment})n$을 만족할 때, $\sum_{{k=1}}^{{{last_index}}}a_k$를 구하시오.",
            answer=answer,
            tags=["#수열의표현", "#시그마공식", "#자연수의거듭제곱의합"],
            steps=[
                ("점화식의 차를 첫째항부터 누적한다.", rf"$a_n={first}+({increment})\sum_{{k=1}}^{{n-1}}k$이다."),
                ("자연수의 합 공식으로 일반항을 정리한다.", rf"$a_n={first}+({increment})n(n-1)/2$이다."),
                ("필요한 항을 차례로 계산한다.", rf"첫 ${last_index}$개 항은 ${value_text}$이다."),
                ("계산한 항을 모두 더한다.", rf"합은 ${answer}$이다."),
            ],
            alternatives=[rf"점화식을 ${last_index - 1}$번 직접 적용해도 ${value_text}$을 얻을 수 있다."],
        )

    for base, shift, multiplier, horizontal_shift in ((2, 0, 2, 1), (3, 1, 2, 0), (2, 2, 3, 0), (2, 1, 3, 1)):
        numerator = shift + multiplier * horizontal_shift
        x = numerator // (multiplier - 1)
        y = base ** (x + shift)
        answer = x + y
        _append_problem(
            catalog,
            counters,
            3,
            title=rf"두 그래프 $y={base}^{{x+({shift})}}$, $y={base}^{{{multiplier}(x-({horizontal_shift}))}}$의 교점을 $(p,q)$라 할 때, $p+q$를 구하시오.",
            answer=answer,
            tags=["#지수함수의그래프", "#지수방정식", "#지수법칙"],
            steps=[
                ("교점에서 두 지수함수의 값이 같다는 식을 세운다.", rf"${base}^{{p+({shift})}}={base}^{{{multiplier}(p-({horizontal_shift}))}}$이다."),
                ("밑이 같으므로 두 지수를 비교한다.", rf"$p+({shift})={multiplier}(p-({horizontal_shift}))$이다."),
                ("교점의 가로좌표와 세로좌표를 구한다.", rf"$p={x}$이고 $q={base}^{{{x}+({shift})}}={y}$이다."),
                ("두 좌표를 더한다.", rf"$p+q={x}+{y}={answer}$이다."),
            ],
            alternatives=["양변에 같은 밑의 로그를 취하면 지수끼리 같다는 일차방정식을 바로 얻는다."],
        )

    for slope, numerator_constant, vertical_asymptote in ((3, 1, 2), (-2, 5, 1), (4, -3, -1), (1, 2, 3)):
        answer = slope + vertical_asymptote
        remainder = numerator_constant + slope * vertical_asymptote
        _append_problem(
            catalog,
            counters,
            3,
            title=rf"유리함수 $f(x)=\dfrac{{({slope})x+({numerator_constant})}}{{x-({vertical_asymptote})}}$의 두 점근선의 교점을 $(a,b)$라 할 때, $a+b$를 구하시오.",
            answer=answer,
            tags=["#유리함수의그래프", "#점근선", "#유리함수의평행이동"],
            steps=[
                ("분자를 분모의 배수와 나머지로 나눈다.", rf"$({slope})x+({numerator_constant})=({slope})(x-({vertical_asymptote}))+({remainder})$이다."),
                ("함수식을 평행이동 표준형으로 바꾼다.", rf"$f(x)={slope}+\dfrac{{{remainder}}}{{x-({vertical_asymptote})}}$이다."),
                ("수직과 수평 점근선을 확인한다.", rf"두 점근선은 $x={vertical_asymptote}$, $y={slope}$이다."),
                ("교점의 좌표를 더한다.", rf"$(a,b)=({vertical_asymptote},{slope})$이므로 $a+b={answer}$이다."),
            ],
            alternatives=["분모가 영이 되는 값과 분자·분모 최고차항 계수의 비를 각각 사용해도 두 점근선을 얻는다."],
        )

    for leading, scale, constant in ((2, 1, 5), (1, 2, 0), (3, 1, -2), (1, 3, 4)):
        answer = 4 * abs(leading) * scale**3
        _append_problem(
            catalog,
            counters,
            3,
            title=rf"삼차함수 $f(x)=({leading})x^3-({3 * leading * scale})x^2+({constant})$의 극댓값과 극솟값의 차를 구하시오.",
            answer=answer,
            tags=["#도함수의부호", "#함수의극대와극소", "#극값의판정"],
            steps=[
                ("도함수를 구해 인수분해한다.", rf"$f'(x)=({3 * leading})x(x-({2 * scale}))$이다."),
                ("도함수가 영이 되는 두 좌표를 구한다.", rf"임계점은 $x=0,{2 * scale}$이다."),
                ("도함수의 부호 변화로 두 극값을 구분한다.", "두 임계점에서 극대와 극소가 한 번씩 나타난다."),
                ("두 임계점의 함숫값 차를 계산한다.", rf"차의 절댓값은 $4|{leading}|({scale})^3={answer}$이다."),
            ],
            alternatives=["상수항은 두 극값을 같은 만큼 평행이동하므로 극값의 차에는 영향을 주지 않는다."],
        )

    # 난이도 4: 네 개념, 다섯 본 단계, 한 분기를 사용한다.
    for join, right_slope, sample_x in ((1, 4, 2), (1, -1, 2), (2, 5, 3), (-1, 3, 1)):
        right_constant = -(join**2)
        left_linear = right_slope - 2 * join
        sample_value = right_slope * sample_x + right_constant
        answer = left_linear + right_slope
        _append_problem(
            catalog,
            counters,
            4,
            title=rf"함수 $f(x)=\begin{{cases}}x^2+ax&(x<{join})\\bx+({right_constant})&(x\ge {join})\end{{cases}}$가 $x={join}$에서 미분가능하고 $f({sample_x})={sample_value}$일 때, $a+b$를 구하시오.",
            answer=answer,
            tags=["#미분가능", "#함수의연속", "#도함수", "#이차함수"],
            steps=[
                ("접합점에서 연속일 조건을 세운다.", rf"$({join})^2+a({join})=b({join})+({right_constant})$이다."),
                ("좌우 미분계수가 같을 조건을 세운다.", rf"$2({join})+a=b$이다."),
                ("추가 함숫값 조건으로 오른쪽 기울기를 구한다.", rf"$b({sample_x})+({right_constant})={sample_value}$에서 $b={right_slope}$이다."),
                ("미분계수 조건으로 왼쪽 계수를 구한다.", rf"$a=b-2({join})={left_linear}$이다."),
                ("두 계수를 더한다.", rf"$a+b={left_linear}+({right_slope})={answer}$이다."),
            ],
            alternatives=["오른쪽 직선이 접합점에서 왼쪽 포물선의 접선이 되어야 한다고 보면 높이와 기울기 조건을 함께 해석할 수 있다."],
        )

    for first, numerator, index in ((2, 1, 8), (1, 3, 6), (-1, 2, 10), (3, 4, 5)):
        scaled_answer = index * first + numerator * (index - 1)
        _append_problem(
            catalog,
            counters,
            4,
            title=rf"수열 $\{{a_n\}}$이 $a_1={first}$, $a_{{n+1}}=a_n+\dfrac{{{numerator}}}{{n(n+1)}}$을 만족할 때, ${index}a_{{{index}}}$을 구하시오.",
            answer=scaled_answer,
            tags=["#수열의표현", "#부분분수", "#여러가지수열의합", "#시그마의성질"],
            steps=[
                ("점화식의 분수를 부분분수로 나눈다.", rf"$\dfrac{{{numerator}}}{{n(n+1)}}={numerator}(\dfrac1n-\dfrac1{{n+1}})$이다."),
                ("첫째항부터 증가량을 누적한다.", rf"$a_n={first}+{numerator}\sum_{{k=1}}^{{n-1}}(\dfrac1k-\dfrac1{{k+1}})$이다."),
                ("이웃한 항이 소거되는 합을 계산한다.", rf"$a_n={first}+{numerator}(1-\dfrac1n)$이다."),
                ("요구한 항을 대입한다.", rf"$a_{{{index}}}={first}+{numerator}(1-\dfrac1{{{index}}})$이다."),
                ("분모를 없앤 값을 계산한다.", rf"${index}a_{{{index}}}={scaled_answer}$이다."),
            ],
            alternatives=["각 증가량을 몇 항만 써 보면 중간 분수들이 모두 소거되는 망원합 구조를 확인할 수 있다."],
        )

    for lower, upper in ((0, 3), (1, 4), (-2, 1), (2, 5)):
        integer_values = list(range(lower, upper + 1))
        answer = sum(integer_values)
        lower_power = 2**lower
        upper_power = 2**upper
        lower_text = str(lower_power) if lower >= 0 else rf"2^{{{lower}}}"
        upper_text = str(upper_power)
        _append_problem(
            catalog,
            counters,
            4,
            title=rf"부등식 $(2^x-{lower_text})(2^x-{upper_text})\le0$을 만족하는 모든 정수 $x$의 합을 구하시오.",
            answer=answer,
            tags=["#지수부등식", "#지수함수의그래프", "#지수방정식", "#함수의증가와감소"],
            steps=[
                (r"$t=2^x>0$으로 치환한다.", rf"$(t-{lower_text})(t-{upper_text})\le0$이다."),
                ("이차부등식의 두 근 사이 구간을 구한다.", rf"${lower_text}\le t\le {upper_text}$이다."),
                ("증가하는 지수함수에 치환값을 되돌린다.", rf"${lower}\le x\le {upper}$이다."),
                ("범위 안의 정수를 나열한다.", rf"정수해는 ${','.join(str(value) for value in integer_values)}$이다."),
                ("모든 정수해를 더한다.", rf"합은 ${answer}$이다."),
            ],
            alternatives=["$y=2^x$가 증가함수이므로 양의 치환값 구간의 양 끝을 지수의 구간으로 바로 바꿀 수 있다."],
        )

    for base, first_log_root, second_log_root in ((2, 1, 4), (3, 1, 3), (2, 2, 5), (4, 1, 2)):
        first_root = base**first_log_root
        second_root = base**second_log_root
        answer = first_root + second_root
        _append_problem(
            catalog,
            counters,
            4,
            title=rf"방정식 $(\log_{{{base}}}x-({first_log_root}))(\log_{{{base}}}x-({second_log_root}))=0$의 두 실근의 합을 구하시오.",
            answer=answer,
            tags=["#로그방정식", "#진수조건", "#로그법칙", "#이차방정식"],
            steps=[
                ("로그의 진수 조건을 확인한다.", r"$x>0$이어야 한다."),
                (r"$t=\log_{{{}}}x$로 치환해 두 근을 읽는다.".format(base), rf"$t={first_log_root},{second_log_root}$이다."),
                ("각 로그방정식을 지수식으로 되돌린다.", rf"$x={base}^{{{first_log_root}}},{base}^{{{second_log_root}}}$이다."),
                ("두 양의 실근을 계산한다.", rf"두 근은 ${first_root},{second_root}$이다."),
                ("두 실근의 합을 계산한다.", rf"합은 ${answer}$이다."),
            ],
            alternatives=["치환한 두 로그값을 먼저 구한 뒤 같은 밑의 지수로 한 번에 복원할 수 있다."],
        )

    for radius, intercept in ((5, 3), (4, 2), (3, 1), (6, 4)):
        answer = 4 * radius * radius - 2 * intercept * intercept
        _append_problem(
            catalog,
            counters,
            4,
            title=rf"원 $x^2+y^2={radius**2}$과 직선 $y=x+({intercept})$의 두 교점을 $A,B$라 할 때, $AB^2$을 구하시오.",
            answer=answer,
            tags=["#원의방정식", "#직선의방정식", "#이차방정식", "#두점사이의거리"],
            steps=[
                ("직선의 식을 원의 방정식에 대입한다.", rf"$x^2+(x+({intercept}))^2={radius**2}$이다."),
                ("두 교점의 가로좌표를 갖는 이차방정식을 정리한다.", rf"$2x^2+({2 * intercept})x+({intercept**2 - radius**2})=0$이다."),
                ("두 가로좌표의 차의 제곱을 판별식으로 구한다.", rf"$(x_1-x_2)^2=({2 * radius**2 - intercept**2})$이다."),
                ("직선 위 두 점의 세로좌표 차도 같음을 이용한다.", r"$y_1-y_2=x_1-x_2$이다."),
                ("거리의 제곱을 계산한다.", rf"$AB^2=2(x_1-x_2)^2={answer}$이다."),
            ],
            alternatives=[rf"원점에서 직선까지의 거리가 $|{intercept}|/\sqrt2$이므로 현의 길이 공식으로도 $AB^2={answer}$을 얻는다."],
        )

    # 난이도 5: 다섯 개념, 여섯 본 단계, 두 검산 분기를 사용한다.
    for odd_increment, final_value, maximum in ((3, 5, 30), (3, 4, 20), (7, 6, 30), (5, 6, 25)):
        layers = _backward_layers(final_value, odd_increment, 3)
        candidates = sorted(value for value in layers[-1] if value <= maximum)
        answer = sum(candidates)
        first_check = _forward_values(candidates[0], odd_increment, 3)
        last_check = _forward_values(candidates[-1], odd_increment, 3)
        first_check_text = r"\to".join(str(value) for value in first_check)
        last_check_text = r"\to".join(str(value) for value in last_check)
        _append_problem(
            catalog,
            counters,
            5,
            title=rf"양의 정수 수열 $\{{a_n\}}$이 $a_{{n+1}}=\begin{{cases}}a_n/2&(a_n\text{{이 짝수}})\\a_n+{odd_increment}&(a_n\text{{이 홀수}})\end{{cases}}$를 만족한다. $a_1\le {maximum}$, $a_4={final_value}$일 때 가능한 모든 $a_1$의 합을 구하시오.",
            answer=answer,
            tags=["#수열", "#수열의표현", "#일반항", "#경우의수", "#함수"],
            steps=[
                ("점화식을 거꾸로 적용할 두 역경로를 정리한다.", rf"다음 항이 $t$이면 직전 짝수 후보는 $2t$, 직전 홀수 후보는 양의 홀수인 $t-{odd_increment}$이다."),
                ("마지막 항에서 셋째 항 후보를 구한다.", rf"가능한 $a_3$은 ${','.join(str(value) for value in sorted(layers[0]))}$이다."),
                ("셋째 항 후보에서 둘째 항 후보를 구한다.", rf"가능한 $a_2$는 ${','.join(str(value) for value in sorted(layers[1]))}$이다."),
                ("둘째 항 후보에서 첫째 항 후보를 모두 구한다.", rf"가능한 $a_1$ 후보는 ${','.join(str(value) for value in sorted(layers[2]))}$이다."),
                ("양수와 상한 조건에 맞는 후보만 고른다.", rf"$a_1\le {maximum}$을 만족하는 값은 ${','.join(str(value) for value in candidates)}$이다."),
                ("유효한 첫째 항을 모두 더한다.", rf"합은 ${answer}$이다."),
            ],
            alternatives=[
                rf"$a_1={candidates[0]}$을 대입하면 ${first_check_text}$로 조건을 만족한다.",
                rf"$a_1={candidates[-1]}$을 대입하면 ${last_check_text}$로 조건을 만족한다.",
            ],
        )

    for scale in (2, 3, 4, 5):
        square = scale * scale
        _append_problem(
            catalog,
            counters,
            5,
            title=rf"함수 $f(x)=x^3-({3 * square})x$에 대하여 $g(x)=\{{f(x)\}}^2$라 하자. 함수 $g$가 갖는 극대점과 극소점의 총개수를 구하시오.",
            answer=5,
            tags=["#합성함수", "#함수의극대와극소", "#미분계수", "#도함수의부호", "#최대최소문제"],
            steps=[
                ("제곱 합성함수의 도함수를 구한다.", r"$g'(x)=2f(x)f'(x)$이다."),
                ("원래 함수의 영점을 구한다.", rf"$f(x)=x(x^2-{3 * square})$이므로 영점은 $-\sqrt3({scale}),0,\sqrt3({scale})$이다."),
                ("원래 함수의 도함수가 영인 점을 구한다.", rf"$f'(x)=3(x^2-{square})$이므로 두 점은 $-{scale},{scale}$이다."),
                ("다섯 임계점이 서로 다름을 순서로 확인한다.", rf"$-\sqrt3({scale})<-{scale}<0<{scale}<\sqrt3({scale})$이다."),
                ("원래 함수의 세 영점에서 제곱 함수의 극소를 판정한다.", r"$g(x)\ge0$이고 각 영점에서 $g=0$이므로 세 점은 극소점이다."),
                ("나머지 두 점의 부호 변화를 확인해 총수를 센다.", r"$x=\pm{}$에서 극대점이 하나씩 생기므로 총 극점은 $3+2=5$개이다.".format(scale)),
            ],
            alternatives=[
                "삼차함수의 그래프에서 세 영점과 두 극점을 표시한 뒤 함숫값을 제곱하면 다섯 극점을 볼 수 있다.",
                r"다섯 임계점 사이에서 $2ff'$의 부호표를 작성하면 극소와 극대가 번갈아 나타난다.",
            ],
        )

    for removed_x, value_at_zero in ((2, 3), (-1, 2), (3, 1), (2, -1)):
        coefficient_a = value_at_zero - removed_x
        coefficient_b = -removed_x * value_at_zero
        filled_value = removed_x + value_at_zero
        answer = coefficient_a**2 + coefficient_b**2 + filled_value**2
        _append_problem(
            catalog,
            counters,
            5,
            title=rf"함수 $f(x)=\begin{{cases}}\dfrac{{x^2+ax+b}}{{x-({removed_x})}}&(x\ne {removed_x})\\c&(x={removed_x})\end{{cases}}$가 실수 전체에서 연속이고 $f(0)={value_at_zero}$일 때, $a^2+b^2+c^2$을 구하시오.",
            answer=answer,
            tags=["#함수의극한", "#극한의성질", "#인수분해를이용한극한", "#미정계수법", "#함수의연속"],
            steps=[
                ("영이 아닌 분모에 함숫값 조건을 대입해 상수항을 구한다.", rf"$f(0)=b/(-{removed_x})={value_at_zero}$이므로 $b={coefficient_b}$이다."),
                ("유한한 극한을 위해 분자도 같은 점에서 영이 될 조건을 세운다.", rf"$({removed_x})^2+a({removed_x})+b=0$이다."),
                ("이미 구한 상수항으로 일차항 계수를 구한다.", rf"식을 풀면 $a={coefficient_a}$이다."),
                ("분자와 분모를 약분해 빠진 직선을 구한다.", rf"$x\ne {removed_x}$에서 $f(x)=x+({value_at_zero})$이다."),
                ("연속 조건으로 빠진 함숫값을 채운다.", rf"$c={removed_x}+({value_at_zero})={filled_value}$이다."),
                ("세 상수의 제곱합을 계산한다.", rf"$a^2+b^2+c^2={answer}$이다."),
            ],
            alternatives=[
                "분자가 분모를 인수로 가져야 한다는 인수정리를 사용하면 두 계수를 빠르게 정할 수 있다.",
                rf"약분된 직선 $y=x+({value_at_zero})$의 빠진 점 높이가 곧 $c={filled_value}$이다.",
            ],
        )

    for scale in (2, 3, 4, 5):
        answer = scale**4
        _append_problem(
            catalog,
            counters,
            5,
            title=rf"함수 $f(x)=x^3-({3 * scale})x^2$의 극대점과 극소점을 잇는 직선과 함수의 그래프로 둘러싸인 넓이를 $S$라 할 때, $2S$를 구하시오.",
            answer=answer,
            tags=["#함수의극대와극소", "#도함수의부호", "#직선의방정식", "#두곡선사이의넓이", "#정적분"],
            steps=[
                ("도함수를 인수분해해 두 극점의 가로좌표를 구한다.", rf"$f'(x)=3x(x-({2 * scale}))$이므로 두 좌표는 $0,{2 * scale}$이다."),
                ("두 극점의 좌표를 구한다.", rf"두 점은 $(0,0)$, $({2 * scale},-{4 * scale**3})$이다."),
                ("두 극점을 잇는 직선의 방정식을 구한다.", rf"직선은 $y=-({2 * scale**2})x$이다."),
                ("곡선과 직선의 차를 인수분해한다.", rf"차는 $x(x-{scale})(x-{2 * scale})$이다."),
                ("중간 교점에서 적분을 나누어 절댓값 넓이를 구한다.", rf"$S=\dfrac{{{scale**4}}}{2}$이다."),
                ("문제에서 요구한 배수를 계산한다.", rf"$2S={answer}$이다."),
            ],
            alternatives=[
                rf"$x={scale}u$로 치환하면 기본 넓이 $1/2$가 ${scale}^4$배 되어 $S={scale**4}/2$이다.",
                "차이 함수의 원시함수를 세 교점에 대입하면 양쪽 부분의 넓이가 서로 같음을 확인할 수 있다.",
            ],
        )

    for denominator_constant, value_at_zero in ((1, 5), (2, 4), (-1, 0), (3, 1)):
        coefficient_a = -denominator_constant
        coefficient_b = value_at_zero * denominator_constant
        fixed_sum = -2 * denominator_constant
        answer = coefficient_a + coefficient_b + fixed_sum
        _append_problem(
            catalog,
            counters,
            5,
            title=rf"유리함수 $f(x)=\dfrac{{ax+b}}{{x+({denominator_constant})}}$가 $f(0)={value_at_zero}$이고 정의되는 모든 실수 $x$에 대하여 $f(f(x))=x$를 만족한다. 방정식 $f(x)=x$의 두 실근의 합을 $s$라 할 때, $a+b+s$를 구하시오.",
            answer=answer,
            tags=["#유리함수의그래프", "#역함수", "#합성함수", "#근과계수의관계", "#점근선"],
            steps=[
                ("주어진 함숫값으로 분자의 상수항을 정한다.", rf"$b/({denominator_constant})={value_at_zero}$이므로 $b={coefficient_b}$이다."),
                ("합성함수의 분자와 분모를 계수별로 정리한다.", rf"$f(f(x))=\dfrac{{(a^2+b)x+b(a+{denominator_constant})}}{{(a+{denominator_constant})x+b+{denominator_constant**2}}}$이다."),
                ("항등적으로 $x$와 같을 이차항 조건을 세운다.", rf"$a+({denominator_constant})=0$이어야 한다."),
                ("계수를 정하고 합성 조건을 확인한다.", rf"$a={coefficient_a}$일 때 나머지 계수도 일치한다."),
                ("고정점 방정식의 두 근의 합을 구한다.", rf"고정점 방정식의 $x$항 계수는 ${2 * denominator_constant}$이므로 $s={fixed_sum}$이다."),
                ("세 값을 모두 더한다.", rf"$a+b+s={coefficient_a}+({coefficient_b})+({fixed_sum})={answer}$이다."),
            ],
            alternatives=[
                "일차분수함수 행렬의 대각합이 영이면 제곱이 스칼라 행렬이 되어 자기 자신의 역함수가 된다.",
                rf"고정점 방정식은 $x^2+({2 * denominator_constant})x-({denominator_constant * value_at_zero})=0$이므로 근의 합을 바로 읽을 수 있다.",
            ],
        )

    return catalog


def _build_quest(spec: dict[str, Any]) -> dict[str, Any]:
    """필요 변수: 추가 배치 문제 명세. 작동 원리: 기존 앱 호환 조립기를 사용한 뒤 추가 배치 전용 ID·variant·메타데이터로 치환한다."""
    quest = _build_base_quest(spec)
    tier = int(spec["tier"])
    index = int(spec["index"])
    variant_number = tier * 100 + index
    quest["header"]["quest_id"] = f"{QUEST_ID_PREFIX}/t{tier}-{index:02d}"
    quest["header"]["quest_model"]["models"] = [
        "curated-original-v2",
        "ksat-structure-reference",
    ]
    quest["data"]["codebase_id"] = -(20_260_715_000 + variant_number)
    quest["data"]["seed"] = 202_607_150_000 + variant_number
    quest["data"]["meta"].update(
        {
            "batch_id": BATCH_ID,
            "origin": "curated_original_template_variant",
            "authored_at": "2026-07-14",
        }
    )
    return quest


def _count_branches(solves: Iterable[dict[str, Any]]) -> int:
    """필요 변수: 최상위 풀이 단계. 작동 원리: 전체 재귀 단계 수에서 본 단계 수를 빼 실제 분기 노드 수를 계산한다."""
    top_level = list(solves)
    return len(list(_walk_steps(top_level))) - len(top_level)


def validate_catalog(catalog: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """필요 변수: 추가 100문항 명세. 작동 원리: 티어 분포·고유성·단계·분기·태그·학생 노출 계약을 전수 검사한다."""
    if len(catalog) != 100:
        raise ValueError(f"catalog must contain 100 problems, got {len(catalog)}")
    tier_counts = Counter(int(spec["tier"]) for spec in catalog)
    if dict(tier_counts) != {tier: 20 for tier in range(1, 6)}:
        raise ValueError(f"tier distribution mismatch: {dict(tier_counts)}")
    quests = [_build_quest(spec) for spec in catalog]
    ids = [quest["header"]["quest_id"] for quest in quests]
    titles = [_content_text(quest["data"]["quest_title"]) for quest in quests]
    variants = [
        (quest["data"]["codebase_id"], quest["data"]["seed"])
        for quest in quests
    ]
    if len(set(ids)) != 100 or len(set(titles)) != 100 or len(set(variants)) != 100:
        raise ValueError("catalog ids, titles, and variants must all be unique")

    expected_tag_counts = {1: 1, 2: 2, 3: 3, 4: 4, 5: 5}
    for quest in quests:
        tier = int(quest["info"]["difficulty_tier"])
        contract = DIFFICULTY_CONTRACTS[tier]
        solves = quest["solves"]
        tags = quest["info"]["hash_tag"]
        if len(solves) != contract.solves_count:
            raise ValueError(f"solve count mismatch: {quest['header']['quest_id']}")
        if _count_branches(solves) != contract.branch_conditions:
            raise ValueError(f"branch count mismatch: {quest['header']['quest_id']}")
        if len(tags) != expected_tag_counts[tier] or len(set(tags)) != len(tags):
            raise ValueError(f"tag count mismatch: {quest['header']['quest_id']}")
        review = review_student_problem_contract(
            quest,
            expected_solve_count=contract.solves_count,
            expected_tags=tags,
        )
        if review["approved"] is not True:
            raise ValueError(
                f"student contract rejected: {quest['header']['quest_id']} {review['reasons']}"
            )
    return quests


def _is_allowed_quest_id(quest_id: str) -> bool:
    """필요 변수: 문제 ID. 작동 원리: 현재 두 수동 저작 배치의 접두사에 속하는 문제만 보존 대상으로 판정한다."""
    return any(quest_id.startswith(f"{prefix}/") for prefix in ALLOWED_QUEST_PREFIXES)


def _allowed_title_map(connection: sqlite3.Connection) -> dict[str, str]:
    """필요 변수: 문제 DB 연결. 작동 원리: 보존 대상 배치의 제목만 읽어 새 100문항과의 중복을 차단한다."""
    result: dict[str, str] = {}
    for quest_id, raw_title in connection.execute(
        "SELECT quest_id, quest_title FROM quest_data"
    ):
        if not _is_allowed_quest_id(str(quest_id)):
            continue
        title = _content_text(raw_title)
        if title:
            result[title] = str(quest_id)
    return result


def purge_non_curated_problems(db_path: Path) -> dict[str, int]:
    """필요 변수: 대상 문제 DB. 작동 원리: 운영 이력은 보존하고 원본 문제 은행·태그·풀이·런타임 큐에서 비저작 문제만 한 트랜잭션으로 제거한다."""
    allowed_clause = "(quest_id LIKE ? OR quest_id LIKE ?)"
    allowed_params = tuple(f"{prefix}/%" for prefix in ALLOWED_QUEST_PREFIXES)
    deleted: dict[str, int] = {}
    with sqlite3.connect(db_path) as connection:
        connection.execute("PRAGMA foreign_keys=ON")
        connection.execute("BEGIN IMMEDIATE")
        for table in (
            "user_problem_queue",
            "quest_variant_tray",
            "quest_tag_index",
            "solve_step",
            "quest_data",
            "quest_info",
            "quest_header",
        ):
            if table == "quest_variant_tray":
                cursor = connection.execute(
                    f"DELETE FROM {table} WHERE quest_id IS NULL OR NOT {allowed_clause}",
                    allowed_params,
                )
            else:
                cursor = connection.execute(
                    f"DELETE FROM {table} WHERE NOT {allowed_clause}",
                    allowed_params,
                )
            deleted[table] = max(0, int(cursor.rowcount))
        connection.commit()
    return deleted


def _placement_tier(item_index: int) -> int:
    """필요 변수: 1부터 50까지의 레벨테스트 문항 번호. 작동 원리: 앱의 20·20·10 단계별 난이도 배열을 그대로 적용한다."""
    if item_index <= 20:
        return (2, 2, 3, 3)[(item_index - 1) % 4]
    if item_index <= 40:
        return (3, 3, 4, 4)[(item_index - 21) % 4]
    return (4, 5)[(item_index - 41) % 2]


def refresh_unused_level_test_templates(db_path: Path) -> dict[str, int]:
    """필요 변수: 정리된 문제 DB. 작동 원리: 미배정 준비 템플릿의 끊어진 참조만 찾아 새 저작 문제 50개로 원자적으로 교체한다."""
    from rating_service import compute_barrier, compute_problem_rating

    with sqlite3.connect(db_path) as connection:
        connection.row_factory = sqlite3.Row
        existing_tables = {
            str(row[0])
            for row in connection.execute(
                "SELECT name FROM sqlite_master WHERE type='table'"
            )
        }
        required_tables = {
            "level_test_template",
            "level_test_template_item",
            "level_test_session",
        }
        if not required_tables.issubset(existing_tables):
            return {"refreshed_templates": 0, "refreshed_items": 0, "stale_ready_items": 0}

        stale_templates = [
            str(row[0])
            for row in connection.execute(
                """
                SELECT t.template_id
                FROM level_test_template t
                WHERE t.status = 'ready'
                  AND NOT EXISTS (
                      SELECT 1 FROM level_test_session s
                      WHERE s.template_id = t.template_id
                  )
                  AND (
                      (SELECT COUNT(*) FROM level_test_template_item i
                       WHERE i.template_id = t.template_id) != 50
                      OR EXISTS (
                          SELECT 1
                          FROM level_test_template_item i
                          LEFT JOIN quest_header q ON q.quest_id = i.quest_id
                          WHERE i.template_id = t.template_id AND q.quest_id IS NULL
                      )
                  )
                ORDER BY t.created_at, t.template_id
                """
            )
        ]
        quests_by_tier: dict[int, list[sqlite3.Row]] = {}
        for tier in range(2, 6):
            quests_by_tier[tier] = list(
                connection.execute(
                    """
                    SELECT qh.quest_id, qi.difficulty_tier, qi.difficulty,
                           qi.main_huddle, qd.hash_tag, qd.codebase_id, qd.seed
                    FROM quest_header qh
                    JOIN quest_info qi ON qi.quest_id = qh.quest_id
                    JOIN quest_data qd ON qd.quest_id = qh.quest_id
                    WHERE qi.difficulty_tier = ? AND qi.quality_status = 'approved'
                      AND (qh.quest_id LIKE ? OR qh.quest_id LIKE ?)
                    ORDER BY qh.quest_id
                    """,
                    (tier, *(f"{prefix}/%" for prefix in ALLOWED_QUEST_PREFIXES)),
                )
            )
            required_count = {2: 10, 3: 20, 4: 15, 5: 5}[tier]
            if len(quests_by_tier[tier]) < required_count:
                raise RuntimeError(
                    f"level-test tier {tier} needs {required_count} curated quests, "
                    f"got {len(quests_by_tier[tier])}"
                )

        now = datetime.now(timezone.utc).isoformat()
        connection.execute("PRAGMA foreign_keys=ON")
        connection.execute("BEGIN IMMEDIATE")
        refreshed_items = 0
        for template_offset, template_id in enumerate(stale_templates):
            tier_offsets: Counter[int] = Counter()
            rows: list[tuple[Any, ...]] = []
            for item_index in range(1, 51):
                tier = _placement_tier(item_index)
                candidates = quests_by_tier[tier]
                candidate_index = (template_offset * 5 + tier_offsets[tier]) % len(candidates)
                quest = candidates[candidate_index]
                tier_offsets[tier] += 1
                phase = 1 if item_index <= 20 else 2 if item_index <= 40 else 3
                barrier = compute_barrier([], float(quest["main_huddle"] or 0))
                problem_rating = compute_problem_rating(
                    float(quest["difficulty"] or 0), barrier
                )
                rows.append(
                    (
                        template_id,
                        item_index,
                        phase,
                        PLACEMENT_SUBJECT_KEYS[(item_index - 1) % len(PLACEMENT_SUBJECT_KEYS)],
                        str(quest["hash_tag"] or "[]"),
                        tier,
                        str(quest["quest_id"]),
                        quest["codebase_id"],
                        quest["seed"],
                        problem_rating,
                        now,
                    )
                )
            connection.execute(
                "DELETE FROM level_test_template_item WHERE template_id = ?",
                (template_id,),
            )
            connection.executemany(
                """
                INSERT INTO level_test_template_item (
                    template_id, item_index, phase, subject_key, hash_tags,
                    difficulty_tier, quest_id, codebase_id, seed,
                    problem_rating, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                rows,
            )
            connection.execute(
                "UPDATE level_test_template SET updated_at = ? WHERE template_id = ?",
                (now, template_id),
            )
            refreshed_items += len(rows)
        connection.commit()
        stale_ready_items = int(
            connection.execute(
                """
                SELECT COUNT(*)
                FROM level_test_template_item i
                JOIN level_test_template t ON t.template_id = i.template_id
                LEFT JOIN quest_header q ON q.quest_id = i.quest_id
                WHERE t.status = 'ready' AND q.quest_id IS NULL
                """
            ).fetchone()[0]
        )
    return {
        "refreshed_templates": len(stale_templates),
        "refreshed_items": refreshed_items,
        "stale_ready_items": stale_ready_items,
    }


def _verify_final_database(db_path: Path, expected_ids: list[str]) -> dict[str, Any]:
    """필요 변수: 정리된 DB와 예상 150개 ID. 작동 원리: 문제 수·티어·승인·태그·단계·UTF-8·무결성을 SQL과 앱 조회 함수로 교차 검증한다."""
    from storage import storage as quest_storage

    with sqlite3.connect(db_path) as connection:
        integrity = str(connection.execute("PRAGMA integrity_check").fetchone()[0])
        core_counts = {
            table: int(connection.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0])
            for table in ("quest_header", "quest_info", "quest_data")
        }
        non_curated = int(
            connection.execute(
                """
                SELECT COUNT(*) FROM quest_header
                WHERE NOT (quest_id LIKE ? OR quest_id LIKE ?)
                """,
                tuple(f"{prefix}/%" for prefix in ALLOWED_QUEST_PREFIXES),
            ).fetchone()[0]
        )
        tier_rows = connection.execute(
            """
            SELECT difficulty_tier, quality_status, COUNT(*)
            FROM quest_info GROUP BY difficulty_tier, quality_status
            ORDER BY difficulty_tier, quality_status
            """
        ).fetchall()
    if integrity != "ok" or non_curated != 0:
        raise RuntimeError(f"final database verification failed: integrity={integrity}, non_curated={non_curated}")
    if any(count != 150 for count in core_counts.values()):
        raise RuntimeError(f"final core counts mismatch: {core_counts}")

    loaded = quest_storage.get_quests_by_ids(expected_ids)
    if len(loaded) != 150:
        raise RuntimeError(f"final readback mismatch: {len(loaded)}/150")
    tier_counts: Counter[int] = Counter()
    korean_titles = 0
    for quest in loaded:
        tier = int(quest["info"]["difficulty_tier"])
        tier_counts[tier] += 1
        if quest["info"].get("quality_status") != "approved":
            raise RuntimeError(f"unapproved quest: {quest['header']['quest_id']}")
        if len(quest.get("solves") or []) != DIFFICULTY_CONTRACTS[tier].solves_count:
            raise RuntimeError(f"solve mismatch: {quest['header']['quest_id']}")
        if re.search(r"[가-힣]", _content_text(quest["data"]["quest_title"])):
            korean_titles += 1
    if dict(sorted(tier_counts.items())) != {tier: 30 for tier in range(1, 6)}:
        raise RuntimeError(f"final tier mismatch: {dict(tier_counts)}")
    return {
        "integrity_check": integrity,
        "core_counts": core_counts,
        "non_curated_quests": non_curated,
        "tier_rows": tier_rows,
        "readback": len(loaded),
        "tier_counts": dict(sorted(tier_counts.items())),
        "utf8_korean_titles": korean_titles,
    }


def seed_and_curate_database(
    db_path: Path,
    *,
    validate_only: bool,
    create_backup: bool,
) -> dict[str, Any]:
    """필요 변수: 대상 DB와 실행 옵션. 작동 원리: 100문항 사전검사·백업·멱등 저장이 성공한 뒤에만 과거 문제를 정리하고 최종 150문항을 검증한다."""
    db_path = db_path.resolve()
    quests = validate_catalog(build_catalog())
    report: dict[str, Any] = {
        "batch_id": BATCH_ID,
        "db_path": str(db_path),
        "validated": len(quests),
        "inserted": 0,
        "skipped": 0,
        "tier_counts": dict(sorted(Counter(q["info"]["difficulty_tier"] for q in quests).items())),
    }
    if validate_only:
        return report

    os.environ["QUEST_DB_PATH"] = str(db_path)
    from storage import storage as quest_storage

    quest_storage.DB_PATH = str(db_path)
    quest_storage.init_db()
    with sqlite3.connect(db_path) as connection:
        existing_ids = {
            str(row[0])
            for row in connection.execute(
                "SELECT quest_id FROM quest_header WHERE quest_id LIKE ?",
                (f"{QUEST_ID_PREFIX}/%",),
            )
        }
        allowed_titles = _allowed_title_map(connection)

    for quest in quests:
        quest_id = quest["header"]["quest_id"]
        if quest_id in existing_ids:
            loaded = quest_storage.get_quest(quest_id)
            batch_id = (((loaded or {}).get("data") or {}).get("meta") or {}).get("batch_id")
            if batch_id != BATCH_ID:
                raise RuntimeError(f"quest_id collision with another batch: {quest_id}")
            report["skipped"] += 1
            continue
        title = _content_text(quest["data"]["quest_title"])
        if title in allowed_titles:
            raise RuntimeError(
                f"duplicate title with curated quest {allowed_titles[title]}: {title}"
            )

    backup_path = db_path.with_name(f"{db_path.name}.bak_{BACKUP_SUFFIX}")
    if create_backup:
        report["backup_created"] = _create_backup(db_path, backup_path)
        report["backup_path"] = str(backup_path)

    inserted_ids: list[str] = []
    try:
        for quest in quests:
            quest_id = quest["header"]["quest_id"]
            if quest_id in existing_ids:
                continue
            if not quest_storage.store_data(quest):
                raise RuntimeError(
                    f"store failed: {quest_id}: {quest_storage.get_last_store_error()}"
                )
            inserted_ids.append(quest_id)
    except Exception:
        _remove_inserted_batch(db_path, inserted_ids)
        raise

    # 신규 100문항 저장이 전부 끝난 뒤에만 과거 문제 원본을 제거한다.
    report["purged"] = purge_non_curated_problems(db_path)
    report["level_test_templates"] = refresh_unused_level_test_templates(db_path)
    all_ids: list[str] = []
    with sqlite3.connect(db_path) as connection:
        all_ids = [
            str(row[0])
            for row in connection.execute(
                "SELECT quest_id FROM quest_header ORDER BY quest_id"
            )
        ]
    report["inserted"] = len(inserted_ids)
    report["final"] = _verify_final_database(db_path, all_ids)
    return report


def main() -> None:
    """필요 변수: 명령행 DB 경로와 검증 옵션. 작동 원리: 기본 실행은 백업 후 100문항을 저장하고 비저작 문제 원본을 정리한 UTF-8 JSON 보고서를 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    parser.add_argument("--no-backup", action="store_true")
    args = parser.parse_args()
    report = seed_and_curate_database(
        args.db,
        validate_only=args.validate_only,
        create_backup=not args.no_backup,
    )
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
