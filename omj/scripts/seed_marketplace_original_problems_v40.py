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

BATCH_ID = "marketplace-original-v40"
MODEL_NAME = "aiflow-direct-authoring-v40"
CODEBASE_BASE = 20_261_001_000
SEED_BASE = 202_607_580_000


def _checked_problem(
    tier: int,
    index: int,
    *,
    answer_check: Callable[[], Any],
    **kwargs: Any,
) -> dict[str, Any]:
    """필요 변수는 문제 명세와 독립 계산 함수다. 작동 원리는 저장 답과 별도 계산 결과를 비교하도록 검산 함수를 부착한다."""
    spec = _problem(tier, index, **kwargs)
    spec["answer_check"] = answer_check
    return spec


def _translated_distance_squared(
    first: tuple[int, int],
    second: tuple[int, int],
    shift: tuple[int, int],
) -> int:
    """필요 변수는 두 점과 둘째 점의 평행이동 벡터다. 작동 원리는 이동 후 좌표 차의 제곱합으로 거리 제곱을 구한다."""
    moved = (second[0] + shift[0], second[1] + shift[1])
    return (moved[0] - first[0]) ** 2 + (moved[1] - first[1]) ** 2


def _difference_of_cubes_quotient_value(cube_root: int, value: int) -> int:
    """필요 변수는 세제곱 상수의 밑과 대입값이다. 작동 원리는 합차 인수분해로 몫 x²+ax+a²을 계산한다."""
    if value == cube_root:
        raise ValueError("원래 분모가 0이 아닌 대입값이 필요합니다.")
    return value**2 + cube_root * value + cube_root**2


def _difference_sequence_term(first: int, difference_linear: int, difference_constant: int, target: int) -> int:
    """필요 변수는 첫째항·계차 일차식 계수·목표 번호다. 작동 원리는 n=1부터 목표 직전까지 계차를 합한다."""
    if target < 1:
        raise ValueError("목표 항 번호는 1 이상이어야 합니다.")
    return first + sum(
        difference_linear * index + difference_constant
        for index in range(1, target)
    )


def _outside_union_count(total: int, first: int, second: int, intersection: int) -> int:
    """필요 변수는 전체 원소 수와 두 사건·교집합 크기다. 작동 원리는 포함배제로 합사건을 구해 전체에서 뺀다."""
    union = first + second - intersection
    if min(total, first, second, intersection) < 0 or union > total:
        raise ValueError("사건의 원소 수가 올바르지 않습니다.")
    return total - union


def _chained_log_result(base: int, first_power: int, second_power: int) -> int:
    """필요 변수는 로그 밑과 두 연쇄 로그값이다. 작동 원리는 x=b^p, y=x^q를 차례로 적용한다."""
    if base <= 1:
        raise ValueError("로그 밑은 1보다 커야 합니다.")
    return base ** (first_power * second_power)


def _telescoping_fraction_sum(offset: int, upper: int) -> Fraction:
    """필요 변수는 분모 이동량과 합의 상한이다. 작동 원리는 부분분수 1/(k+a)-1/(k+a+1)의 망원합을 계산한다."""
    if offset < 0 or upper < 1:
        raise ValueError("음이 아닌 이동량과 양의 상한이 필요합니다.")
    return Fraction(1, offset + 1) - Fraction(1, offset + upper + 1)


def _difference_quotient_limit(first_limit: int, second_limit: int) -> int:
    """필요 변수는 두 함수의 극한값이다. 작동 원리는 (f²-g²)/(f-g)=f+g로 약분해 극한값을 더한다."""
    if first_limit == second_limit:
        raise ValueError("극한 과정에서 분모가 항등적으로 0이 아닌 서로 다른 극한값을 사용합니다.")
    return first_limit + second_limit


def _inverse_linear_solution_product(
    matrix: tuple[int, int, int, int],
    target: tuple[int, int],
) -> Fraction:
    """필요 변수는 2×2 가역행렬과 상수열이다. 작동 원리는 역행렬 공식으로 AX=B의 두 해를 구해 곱한다."""
    a, b, c, d = matrix
    determinant = a * d - b * c
    if determinant == 0:
        raise ValueError("가역행렬이 필요합니다.")
    x_value = Fraction(d * target[0] - b * target[1], determinant)
    y_value = Fraction(a * target[1] - c * target[0], determinant)
    return x_value * y_value


def _double_root_nonleading_sum(first_root: int, second_root: int) -> int:
    """필요 변수는 최고차항 계수가 1인 사차식의 서로 다른 두 중근이다. 작동 원리는 계수합 P(1)에서 최고차항 계수 1을 뺀다."""
    if first_root == second_root:
        raise ValueError("서로 다른 두 중근이 필요합니다.")
    return (1 - first_root) ** 2 * (1 - second_root) ** 2 - 1


def _circle_chord_length_squared(radius: int, line_constant: int) -> int:
    """필요 변수는 원점 중심 원의 반지름과 직선 x+y=c다. 작동 원리는 중심-직선 거리와 피타고라스로 현 길이 제곱을 구한다."""
    if radius <= 0 or line_constant**2 >= 2 * radius**2:
        raise ValueError("직선이 원의 내부를 지나 두 교점을 가져야 합니다.")
    return 4 * radius**2 - 2 * line_constant**2


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 점의 이동과 세제곱 차다. 작동 원리는 거리 제곱과 인수분해 몫 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    distance_rows = [
        ((1, 2), (4, -1), (2, 3)),
        ((-3, 5), (2, 1), (-1, 4)),
        ((4, -2), (-1, 3), (5, -2)),
        ((-2, -4), (3, 6), (1, -5)),
        ((5, 1), (-4, -3), (2, 7)),
    ]
    for index, (first, second, shift) in enumerate(distance_rows, 1):
        moved = (second[0] + shift[0], second[1] + shift[1])
        answer = _translated_distance_squared(first, second, shift)
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"점 $B{second}$를 x방향으로 {shift[0]}, y방향으로 {shift[1]}만큼 평행이동한 점을 C라 하자. 점 $A{first}$에 대하여 선분 AC의 길이의 제곱을 구하시오.",
                answer=str(answer),
                tags=["#거리공식", "#두점사이의거리", "#x방향이동", "#y방향이동"],
                steps=[
                    ("점 B에 평행이동 벡터를 더해 C의 좌표를 구한다.", rf"$C={moved}$이다."),
                    ("A와 C의 좌표 차를 제곱해 더한다.", rf"따라서 $AC^2={answer}$이다."),
                ],
                answer_check=lambda a=first, b=second, move=shift: _translated_distance_squared(a, b, move),
            )
        )
    factor_rows = [(2, 5), (3, -1), (-2, 4), (4, 1), (-3, 2)]
    for index, (cube_root, value) in enumerate(factor_rows, 6):
        answer = _difference_of_cubes_quotient_value(cube_root, value)
        specs.append(
            _checked_problem(
                1,
                index,
                title=rf"유리식 $\dfrac{{x^3-({cube_root})^3}}{{x-({cube_root})}}$에 $x={value}$를 대입한 값을 구하시오.",
                answer=str(answer),
                tags=["#고차식인수분해", "#세제곱공식", "#인수분해", "#약분"],
                steps=[
                    ("세제곱의 차를 인수분해한다.", rf"$x^3-({cube_root})^3=(x-({cube_root}))(x^2+({cube_root})x+{cube_root**2})$이다."),
                    ("공통인수를 약분하고 x값을 대입한다.", rf"따라서 값은 ${answer}$이다."),
                ],
                answer_check=lambda a=cube_root, x=value: _difference_of_cubes_quotient_value(a, x),
            )
        )
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 일차 계차수열과 두 사건의 원소 수다. 작동 원리는 계차 합과 합사건 여집합 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    sequence_rows = [(2, 2, 1, 8), (-3, 3, -1, 7), (5, 1, 4, 10), (1, -1, 6, 9), (4, 4, -3, 6)]
    for index, (first, difference_linear, difference_constant, target) in enumerate(sequence_rows, 1):
        differences = [
            difference_linear * number + difference_constant
            for number in range(1, target)
        ]
        answer = _difference_sequence_term(first, difference_linear, difference_constant, target)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"수열 $\{{a_n\}}$이 $a_1={first}$, $a_{{n+1}}-a_n=({difference_linear})n+({difference_constant})$을 만족할 때 $a_{target}$의 값을 구하시오.",
                answer=str(answer),
                tags=["#계차수열", "#수열의정의", "#일반항", "#등차수열의합"],
                steps=[
                    ("첫째항부터 목표 항 직전까지의 계차를 구한다.", rf"계차는 $\{{{','.join(map(str, differences))}\}}$이다."),
                    ("a₁에 필요한 계차를 모두 더한다.", rf"$a_{target}=a_1+\sum_{{n=1}}^{{{target - 1}}}(a_{{n+1}}-a_n)$이다."),
                    ("계차합을 계산한다.", rf"따라서 $a_{target}={answer}$이다."),
                ],
                answer_check=lambda a=first, d=difference_linear, c=difference_constant, n=target: _difference_sequence_term(a, d, c, n),
            )
        )
    event_rows = [(100, 45, 38, 17), (80, 36, 29, 12), (120, 55, 47, 20), (90, 41, 33, 15), (150, 70, 62, 28)]
    for index, (total, first, second, intersection) in enumerate(event_rows, 6):
        union = first + second - intersection
        answer = _outside_union_count(total, first, second, intersection)
        specs.append(
            _checked_problem(
                2,
                index,
                title=rf"원소가 {total}개인 표본공간에서 $|A|={first}$, $|B|={second}$, $|A\cap B|={intersection}$일 때, A와 B 어느 것에도 속하지 않는 원소의 수를 구하시오.",
                answer=str(answer),
                tags=["#사건의합", "#사건의곱", "#여집합", "#합의법칙"],
                steps=[
                    ("포함배제로 합사건의 원소 수를 구한다.", rf"$|A\cup B|={first}+{second}-{intersection}={union}$이다."),
                    ("표본공간 전체에서 합사건을 뺀다.", rf"여집합의 원소 수는 ${total}-{union}$이다."),
                    ("차를 계산한다.", rf"따라서 어느 것에도 속하지 않는 원소는 ${answer}$개이다."),
                ],
                answer_check=lambda n=total, a=first, b=second, both=intersection: _outside_union_count(n, a, b, both),
            )
        )
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 연쇄 로그값과 부분분수 합이다. 작동 원리는 로그 정의와 망원합 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    log_rows = [(2, 3, 2), (3, 2, 3), (4, 2, 2), (5, 2, 3), (2, 4, 3)]
    for index, (base, first_power, second_power) in enumerate(log_rows, 1):
        intermediate = base**first_power
        answer = _chained_log_result(base, first_power, second_power)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"양수 x, y가 $\log_{{{base}}}x={first_power}$, $\log_x y={second_power}$를 만족할 때 y의 값을 구하시오.",
                answer=str(answer),
                tags=["#로그의정의", "#로그", "#밑", "#로그방정식과로그부등식"],
                steps=[
                    ("첫 로그식을 지수식으로 바꾼다.", rf"$x={base}^{first_power}={intermediate}$이다."),
                    ("둘째 로그식도 지수식으로 바꾼다.", rf"$y=x^{second_power}$이다."),
                    ("x의 값을 대입해 밑을 통일한다.", rf"$y={base}^{{{first_power * second_power}}}$이다."),
                    ("거듭제곱을 계산한다.", rf"따라서 $y={answer}$이다."),
                ],
                alternatives=["밑변환 공식으로 $\log_b y=(\log_b x)(\log_x y)$를 먼저 구할 수 있다."],
                answer_check=lambda b=base, p=first_power, q=second_power: _chained_log_result(b, p, q),
            )
        )
    fraction_rows = [(0, 8), (1, 10), (2, 12), (3, 15), (4, 20)]
    for index, (offset, upper) in enumerate(fraction_rows, 6):
        answer = _telescoping_fraction_sum(offset, upper)
        specs.append(
            _checked_problem(
                3,
                index,
                title=rf"합 $\sum_{{k=1}}^{{{upper}}}\dfrac1{{(k+{offset})(k+{offset + 1})}}$의 값을 구하시오.",
                answer=str(answer),
                tags=["#부분분수", "#수열의표현", "#시그마의성질", "#약분"],
                steps=[
                    ("일반항을 부분분수로 분해한다.", rf"$1/((k+{offset})(k+{offset + 1}))=1/(k+{offset})-1/(k+{offset + 1})$이다."),
                    ("첫 몇 항과 마지막 항을 써서 상쇄 구조를 확인한다.", "가운데 항들은 부호가 반대로 한 번씩 나타나 모두 없어진다."),
                    ("처음 양의 항과 마지막 음의 항만 남긴다.", rf"$1/{offset + 1}-1/{offset + upper + 1}$이다."),
                    ("두 분수를 통분해 기약분수로 정리한다.", rf"따라서 합은 ${answer}$이다."),
                ],
                alternatives=["각 항을 정확한 분수로 직접 더해 망원합 결과를 검산할 수 있다."],
                answer_check=lambda a=offset, n=upper: _telescoping_fraction_sum(a, n),
            )
        )
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 함수의 극한값과 2×2 역행렬 문제다. 작동 원리는 합차 약분 극한과 연립방정식 해의 곱 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    limit_rows = [(3, -2), (5, 1), (-4, 2), (7, -3), (-1, 6)]
    for index, (first_limit, second_limit) in enumerate(limit_rows, 1):
        answer = _difference_quotient_limit(first_limit, second_limit)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"$\lim_{{x\to a}}f(x)={first_limit}$, $\lim_{{x\to a}}g(x)={second_limit}$이고 a 근방에서 $f(x)\ne g(x)$일 때, $\lim_{{x\to a}}\dfrac{{f(x)^2-g(x)^2}}{{f(x)-g(x)}}$의 값을 구하시오.",
                answer=str(answer),
                tags=["#극한의성질", "#극한의사칙연산", "#극한의정의", "#합차공식"],
                steps=[
                    ("분자를 합차공식으로 인수분해한다.", r"$f(x)^2-g(x)^2=(f(x)-g(x))(f(x)+g(x))$이다."),
                    ("a 근방에서 분모가 0이 아니므로 공통인수를 약분한다.", "식은 f(x)+g(x)로 단순해진다."),
                    ("극한의 덧셈 법칙을 적용한다.", r"$\lim(f+g)=\lim f+\lim g$이다."),
                    ("주어진 두 극한값을 더한다.", rf"${first_limit}+({second_limit})={answer}$이다."),
                    ("원래 분수와 약분한 식이 뚫린 점을 제외하고 같음을 확인한다.", rf"따라서 극한값은 ${answer}$이다."),
                ],
                alternatives=["분자를 전개된 상태로 두고 분수의 극한법칙을 적용한 뒤 대수적으로 정리할 수 있다."],
                answer_check=lambda first=first_limit, second=second_limit: _difference_quotient_limit(first, second),
            )
        )
    matrix_rows = [
        ((2, 1, 1, 1), (5, 3)),
        ((3, -1, 2, 1), (7, 4)),
        ((1, 2, -1, 3), (6, 5)),
        ((4, 1, 2, 3), (9, 8)),
        ((2, -3, 1, 2), (4, 7)),
    ]
    for index, (matrix, target) in enumerate(matrix_rows, 6):
        determinant = matrix[0] * matrix[3] - matrix[1] * matrix[2]
        x_value = Fraction(matrix[3] * target[0] - matrix[1] * target[1], determinant)
        y_value = Fraction(matrix[0] * target[1] - matrix[2] * target[0], determinant)
        answer = _inverse_linear_solution_product(matrix, target)
        specs.append(
            _checked_problem(
                4,
                index,
                title=rf"행렬 $A=\begin{{pmatrix}}{matrix[0]}&{matrix[1]}\\{matrix[2]}&{matrix[3]}\end{{pmatrix}}$와 열벡터 $B=\begin{{pmatrix}}{target[0]}\\{target[1]}\end{{pmatrix}}$에 대하여 $AX=B$를 만족하는 $X=(x,y)^T$의 xy를 구하시오.",
                answer=str(answer),
                tags=["#역행렬", "#역행렬구하기", "#행렬을이용한연립방정식", "#연립일차방정식과행렬"],
                steps=[
                    ("행렬 A의 행렬식을 계산한다.", rf"$\det A={determinant}$이므로 역행렬이 존재한다."),
                    ("2×2 역행렬 공식을 적용한다.", rf"$A^{{-1}}=\dfrac1{{{determinant}}}\begin{{pmatrix}}{matrix[3]}&{-matrix[1]}\\{-matrix[2]}&{matrix[0]}\end{{pmatrix}}$이다."),
                    ("X=A^{-1}B를 계산한다.", rf"$x={x_value}$, $y={y_value}$이다."),
                    ("두 해를 원래 행렬방정식에 대입해 검산한다.", "두 행의 결과가 상수열 B와 일치한다."),
                    ("x와 y를 곱한다.", rf"따라서 $xy={answer}$이다."),
                ],
                alternatives=["두 행을 연립일차방정식으로 읽고 가감법으로 x와 y를 구할 수 있다."],
                answer_check=lambda a=matrix, b=target: _inverse_linear_solution_product(a, b),
            )
        )
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 중근을 가진 사차식과 원의 현이다. 작동 원리는 계수합과 중심-직선 거리 문제 10개를 만든다."""
    specs: list[dict[str, Any]] = []
    polynomial_rows = [(-1, 2), (-2, 3), (0, 4), (-3, 1), (2, 5)]
    for index, (first_root, second_root) in enumerate(polynomial_rows, 1):
        answer = _double_root_nonleading_sum(first_root, second_root)
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"최고차항의 계수가 1인 사차다항식 $P(x)=x^4+ax^3+bx^2+cx+d$가 서로 다른 두 중근 ${first_root}, {second_root}$만 가질 때 $a+b+c+d$를 구하시오.",
                answer=str(answer),
                tags=["#중근조건", "#고차식인수분해", "#인수분해", "#항등식", "#다항식"],
                steps=[
                    ("두 수가 각각 중근이므로 인수가 두 번씩 나타남을 이용한다.", rf"$P(x)=(x-({first_root}))^2(x-({second_root}))^2$이다."),
                    ("최고차항 계수가 1이라 추가 상수배가 없음을 확인한다.", "주어진 인수분해식이 P 전체이다."),
                    ("다항식의 모든 계수의 합을 x=1에서의 함수값으로 바꾼다.", r"$P(1)=1+a+b+c+d$이다."),
                    ("인수분해식에 x=1을 대입한다.", rf"$P(1)=(1-({first_root}))^2(1-({second_root}))^2$이다."),
                    ("최고차항 계수 1을 뺀다.", rf"$a+b+c+d=P(1)-1$이다."),
                    ("필요하면 전개해 중근과 계수합을 다시 검산한다.", rf"따라서 $a+b+c+d={answer}$이다."),
                ],
                alternatives=[
                    "두 완전제곱식을 각각 전개한 뒤 곱해 네 계수를 직접 구할 수 있다.",
                    "P'(x)도 두 중근에서 0이라는 조건으로 계수 연립방정식을 세울 수 있다.",
                ],
                answer_check=lambda a=first_root, b=second_root: _double_root_nonleading_sum(a, b),
            )
        )
    chord_rows = [(5, 3), (6, 4), (7, 5), (8, 6), (10, 8)]
    for index, (radius, line_constant) in enumerate(chord_rows, 6):
        distance_squared = Fraction(line_constant**2, 2)
        answer = _circle_chord_length_squared(radius, line_constant)
        specs.append(
            _checked_problem(
                5,
                index,
                title=rf"원 $x^2+y^2={radius**2}$와 직선 $x+y={line_constant}$가 만드는 현의 길이의 제곱을 구하시오.",
                answer=str(answer),
                tags=["#원의방정식", "#반지름", "#점과직선사이의거리", "#두점사이의거리", "#거리공식"],
                steps=[
                    ("원의 중심과 반지름을 확인한다.", rf"중심은 원점이고 반지름은 ${radius}$이다."),
                    ("원점에서 직선까지의 거리를 구한다.", rf"거리의 제곱은 ${line_constant}^2/(1^2+1^2)={distance_squared}$이다."),
                    ("원의 중심에서 현에 내린 수선이 현을 이등분함을 이용한다.", "반현·중심거리·반지름이 직각삼각형을 이룬다."),
                    ("피타고라스 정리로 반현 길이의 제곱을 구한다.", rf"반현 제곱은 ${radius**2}-{distance_squared}$이다."),
                    ("현은 반현의 두 배임을 반영한다.", "현 길이 제곱은 반현 길이 제곱의 4배이다."),
                    ("값을 정리한다.", rf"따라서 현 길이의 제곱은 ${answer}$이다."),
                ],
                alternatives=[
                    "직선식으로 y를 소거해 원과의 교점 이차방정식을 푼 뒤 두 점 사이 거리를 계산할 수 있다.",
                    "원의 현 길이 공식 $2\sqrt{r^2-d^2}$를 적용한 뒤 제곱할 수 있다.",
                ],
                answer_check=lambda r=radius, c=line_constant: _circle_chord_length_squared(r, c),
            )
        )
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v40 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v40 전체 카탈로그다. 작동 원리는 독립 정답 검산 후 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog = build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v40 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(
        catalog,
        expected_count=50,
        batch_id=BATCH_ID,
        model_name=MODEL_NAME,
        codebase_base=CODEBASE_BASE,
        seed_base=SEED_BASE,
    )


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v40 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(
        db_path,
        quests=validated_quests(),
        batch_id=BATCH_ID,
        validate_only=validate_only,
    )


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v40 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
