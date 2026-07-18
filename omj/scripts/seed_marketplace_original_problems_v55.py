from __future__ import annotations

import argparse
import itertools
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

BATCH_ID = "marketplace-original-v55"
MODEL_NAME = "aiflow-direct-authoring-v55"
CODEBASE_BASE = 20_261_016_000
SEED_BASE = 202_607_595_000


def _checked_problem(tier: int, index: int, *, answer_check: Callable[[], Any], **kwargs: Any) -> dict[str, Any]:
    """필요 변수는 문제 명세와 독립 계산 함수다. 작동 원리는 저장 답과 별도 계산 결과를 비교하도록 검산 함수를 부착한다."""
    spec = _problem(tier, index, **kwargs)
    spec["answer_check"] = answer_check
    return spec


def _injection_with_required_images(domain_size: int, codomain_size: int, required_count: int) -> int:
    """필요 변수는 정의역·공역 크기와 반드시 치역에 포함할 원소 수다. 작동 원리는 모든 일대일대응 순서쌍을 순회해 필수 상을 포함한 함수를 센다."""
    if not 0 <= required_count <= domain_size <= codomain_size:
        raise ValueError("정의역·공역·필수 상의 크기 관계가 올바르지 않습니다.")
    required = set(range(required_count))
    return sum(required <= set(images) for images in itertools.permutations(range(codomain_size), domain_size))


def _synthetic_quotient_remainder_sum(coefficients: tuple[int, int, int, int], root: int) -> int:
    """필요 변수는 삼차다항식 계수와 일차식의 근이다. 작동 원리는 조립제법으로 몫 계수와 나머지를 구해 모두 더한다."""
    first, second, third, fourth = coefficients
    quotient_second = second + root * first
    quotient_first = third + root * quotient_second
    remainder = fourth + root * quotient_first
    return first + quotient_second + quotient_first + remainder


def _quadratic_integer_square_sum(first_root: int, second_root: int, lower: int, upper: int) -> int:
    """필요 변수는 이차식의 두 근과 정수 범위다. 작동 원리는 이차식이 0 이하인 정수해를 골라 제곱합을 계산한다."""
    if first_root > second_root:
        first_root, second_root = second_root, first_root
    return sum(
        value**2
        for value in range(lower, upper + 1)
        if (value - first_root) * (value - second_root) <= 0
    )


def _reflected_hyperbola_coordinate_sum(numerator: int, horizontal: int, vertical: int) -> Fraction:
    """필요 변수는 평행이동한 유리함수 세 계수다. 작동 원리는 원점대칭 후 중심과 두 축 절편 좌표를 복원해 합한다."""
    if horizontal == 0 or vertical == 0:
        raise ValueError("두 축 절편이 모두 유한하게 존재하는 자료가 필요합니다.")
    center_sum = -horizontal - vertical
    x_intercept = Fraction(numerator, vertical) - horizontal
    y_intercept = Fraction(numerator, horizontal) - vertical
    return center_sum + x_intercept + y_intercept


def _radical_intersection_start_sum(horizontal: int, vertical: int, level: int) -> int:
    """필요 변수는 무리함수 시작점과 수평선 높이다. 작동 원리는 교점의 x좌표와 정의역 시작점의 좌표합을 계산한다."""
    if level < vertical:
        raise ValueError("무리함수와 만나는 수평선이 필요합니다.")
    intersection_x = horizontal + (level - vertical) ** 2
    return intersection_x + horizontal + vertical


def _piecewise_differentiability_parameter(left_linear: int, left_constant: int, boundary: int) -> int:
    """필요 변수는 공통 기울기·왼쪽 상수항·경계점이다. 작동 원리는 좌우 기울기가 같은 조각함수의 연속조건으로 오른쪽 상수항과 공통 극한의 합을 구한다."""
    common_limit = left_linear * boundary + left_constant
    right_constant = left_constant
    return right_constant + common_limit


def _tangent_slope_intercept_sum(coefficients: tuple[int, int, int, int], point: int) -> int:
    """필요 변수는 삼차함수 계수와 접점 x좌표다. 작동 원리는 미분계수 정의와 같은 도함숫값으로 접선의 기울기와 y절편 합을 구한다."""
    cubic, quadratic, linear, constant = coefficients
    function_value = cubic * point**3 + quadratic * point**2 + linear * point + constant
    slope = 3 * cubic * point**2 + 2 * quadratic * point + linear
    y_intercept = function_value - slope * point
    return slope + y_intercept


def _antiderivative_target_value(
    quadratic: int,
    linear: int,
    constant: int,
    known_point: int,
    known_value: int,
    target: int,
) -> Fraction:
    """필요 변수는 도함수 계수·한 함숫값·목표점이다. 작동 원리는 미적분의 기본정리로 두 점 사이 정적분을 알려진 원시함숫값에 더한다."""
    def primitive(value: int) -> Fraction:
        """필요 변수는 대입점이다. 작동 원리는 주어진 이차 도함수의 상수 없는 원시함수 값을 계산한다."""
        return Fraction(quadratic * value**3, 3) + Fraction(linear * value**2, 2) + constant * value

    return known_value + primitive(target) - primitive(known_point)


def _quartic_range_width(parameter: int, vertical: int, bound: int) -> int:
    """필요 변수는 짝수 사차함수의 극점 계수·상수항·대칭 구간이다. 작동 원리는 도함수의 임계점과 양 끝점 값을 비교해 최댓값과 최솟값 차를 구한다."""
    if parameter <= 0 or bound <= 0:
        raise ValueError("양의 극점 계수와 구간 반지름이 필요합니다.")
    candidates = [vertical, bound**4 - 2 * parameter * bound**2 + vertical]
    root = math.isqrt(parameter)
    if root**2 == parameter and root <= bound:
        candidates.append(vertical - parameter**2)
    return max(candidates) - min(candidates)


def _circular_nonadjacent_count(people: int) -> int:
    """필요 변수는 서로 다른 사람 수다. 작동 원리는 전체 원순열에서 지정한 두 사람이 붙은 블록 원순열을 뺀다."""
    if people < 4:
        raise ValueError("네 명 이상의 원순열이 필요합니다.")
    return math.factorial(people - 1) - 2 * math.factorial(people - 2)


def _poly_text(coefficients: tuple[int, int, int, int]) -> str:
    """필요 변수는 삼차다항식의 내림차순 계수다. 작동 원리는 문제 본문용 LaTeX 문자열로 변환한다."""
    return rf"({coefficients[0]})x^3+({coefficients[1]})x^2+({coefficients[2]})x+({coefficients[3]})"


def _tier1_specs() -> list[dict[str, Any]]:
    """필요 변수는 유한집합 함수와 삼차다항식이다. 작동 원리는 필수 상을 갖는 일대일함수와 조립제법 문제를 각 5개 만든다."""
    specs: list[dict[str, Any]] = []
    mapping_rows = [(2, 4, 1), (3, 5, 1), (3, 5, 2), (3, 6, 2), (4, 6, 2)]
    for index, row in enumerate(mapping_rows, 1):
        domain_size, codomain_size, required_count = row
        answer = _injection_with_required_images(*row)
        required_text = ",".join(chr(97 + value) for value in range(required_count))
        specs.append(_checked_problem(
            1,
            index,
            title=rf"정의역 $X=\{{1,2,\ldots,{domain_size}\}}$, 공역 $Y=\{{a,b,\ldots\}}$의 원소 수가 {codomain_size}일 때, 치역이 $\{{{required_text}\}}$를 포함하는 일대일함수 $f:X\to Y$의 개수를 구하시오.",
            answer=str(answer),
            tags=["#공역", "#일대일대응", "#정의역", "#부분집합", "#조건제시법"],
            steps=[
                ("일대일함수는 정의역 원소의 상을 공역에서 중복 없이 순서 있게 고르는 것과 같다.", "공역 원소의 순열 중 정의역 크기만큼을 사용한다."),
                ("선택한 상의 집합이 지정한 필수 원소를 모두 포함하는 경우만 센다.", rf"조건을 만족하는 일대일함수는 ${answer}$개이다."),
            ],
            answer_check=lambda values=row: _injection_with_required_images(*values),
        ))

    division_rows = [((1, -2, 3, 4), 2), ((2, 1, -4, 5), -1), ((-1, 3, 2, -6), 3), ((3, -2, 0, 7), 1), ((2, -5, 4, -3), -2)]
    for index, (coefficients, root) in enumerate(division_rows, 6):
        answer = _synthetic_quotient_remainder_sum(coefficients, root)
        specs.append(_checked_problem(
            1,
            index,
            title=rf"다항식 $P(x)={_poly_text(coefficients)}$를 $x-({root})$로 나눈 몫의 모든 계수의 합과 나머지의 합을 구하시오.",
            answer=str(answer),
            tags=["#조립제법", "#나머지정리", "#나머지정리증명", "#몫과나머지", "#인수정리활용"],
            steps=[
                ("나누는 일차식의 근을 조립제법 표 왼쪽에 적고 계수를 차례로 내린다.", "곱하고 더하는 과정을 상수항까지 반복한다."),
                ("마지막 수는 나머지이고 앞의 세 수는 몫의 계수다.", rf"이 네 값을 모두 더하면 ${answer}$이다."),
            ],
            answer_check=lambda values=coefficients, value=root: _synthetic_quotient_remainder_sum(values, value),
        ))
    return specs


def _tier2_specs() -> list[dict[str, Any]]:
    """필요 변수는 이차부등식의 두 근과 평행이동한 유리함수다. 작동 원리는 정수해 제곱합과 대칭 쌍곡선 좌표 문제를 각 5개 만든다."""
    specs: list[dict[str, Any]] = []
    inequality_rows = [(-3, 4, -7, 8), (1, 6, -2, 10), (-5, 2, -9, 6), (2, 8, 0, 12), (-4, 5, -10, 9)]
    for index, row in enumerate(inequality_rows, 1):
        first_root, second_root, lower, upper = row
        answer = _quadratic_integer_square_sum(*row)
        specs.append(_checked_problem(
            2,
            index,
            title=rf"정수 ${lower}\le x\le {upper}$ 중 이차부등식 $(x-({first_root}))(x-({second_root}))\le0$을 만족하는 모든 x의 제곱의 합을 구하시오.",
            answer=str(answer),
            tags=["#이차부등식", "#이차부등식의풀이", "#이차부등식의해", "#이차함수와이차부등식", "#근의공식"],
            steps=[
                ("인수에서 이차식의 두 근을 확인한다.", "최고차항 계수가 양수이므로 두 근 사이에서 0 이하이다."),
                ("주어진 정수 범위와 해 구간의 교집합을 구한다.", "등호가 있으므로 두 근도 포함한다."),
                ("남은 모든 정수를 제곱해 더한다.", rf"따라서 제곱합은 ${answer}$이다."),
            ],
            answer_check=lambda values=row: _quadratic_integer_square_sum(*values),
        ))

    hyperbola_rows = [(6, 2, 3), (-8, -2, 4), (10, 5, -2), (12, -3, -4), (-15, 3, 5)]
    for index, row in enumerate(hyperbola_rows, 6):
        numerator, horizontal, vertical = row
        answer = _reflected_hyperbola_coordinate_sum(*row)
        specs.append(_checked_problem(
            2,
            index,
            title=rf"유리함수 $y=\dfrac{{{numerator}}}{{x-({horizontal})}}+({vertical})$의 그래프를 원점대칭하였다. 새 그래프의 중심 좌표합, x절편, y절편을 모두 더한 값을 구하시오.",
            answer=str(answer),
            tags=["#유리함수의평행이동", "#쌍곡선", "#원점대칭", "#절편", "#유리식과유리함수"],
            steps=[
                ("원래 쌍곡선의 중심을 분모와 상수항에서 읽는다.", "원점대칭하면 중심의 두 좌표 부호가 바뀐다."),
                ("대칭된 함수식을 $g(x)=-f(-x)$로 구한다.", "분모와 상수항의 부호를 정확히 정리한다."),
                ("g(x)=0과 x=0을 각각 대입해 두 절편을 구하고 중심 좌표합과 더한다.", rf"따라서 요구한 값은 ${answer}$이다."),
            ],
            answer_check=lambda values=row: _reflected_hyperbola_coordinate_sum(*values),
        ))
    return specs


def _tier3_specs() -> list[dict[str, Any]]:
    """필요 변수는 평행이동한 무리함수와 조각함수의 연속조건이다. 작동 원리는 그래프 좌표와 좌·우극한 계수 문제를 각 5개 만든다."""
    specs: list[dict[str, Any]] = []
    radical_rows = [(2, -1, 4), (-3, 2, 7), (4, 1, 6), (-1, -2, 3), (5, 3, 8)]
    for index, row in enumerate(radical_rows, 1):
        horizontal, vertical, level = row
        answer = _radical_intersection_start_sum(*row)
        specs.append(_checked_problem(
            3,
            index,
            title=rf"무리함수 $y=\sqrt{{x-({horizontal})}}+({vertical})$의 그래프와 수평선 $y={level}$의 교점을 P라 한다. P의 x좌표와 무리함수 그래프 시작점의 두 좌표를 모두 더하시오.",
            answer=str(answer),
            tags=["#무리식과무리함수", "#무리함수의그래프", "#무리함수의평행이동", "#정의역", "#무리식의계산"],
            steps=[
                ("근호 안이 0이 되는 정의역 시작점의 좌표를 구한다.", "가로·세로 이동량이 시작점 좌표다."),
                ("수평선의 높이를 함수값에 대입해 근호를 고립시킨다.", "우변이 음이 아닌지 확인한다."),
                ("양변을 제곱해 교점의 x좌표를 구한다.", "구한 값은 원래 근호식에 대입해 검산한다."),
                ("교점 x좌표와 시작점의 두 좌표를 더한다.", rf"따라서 합은 ${answer}$이다."),
            ],
            alternatives=["기본 그래프 $y=\sqrt{x}$의 점을 평행이동해 교점과 시작점을 동시에 추적할 수 있다."],
            answer_check=lambda values=row: _radical_intersection_start_sum(*values),
        ))

    continuity_rows = [(2, 1, 3), (-1, 4, 2), (3, -2, -2), (4, 1, 2), (-2, -1, 4)]
    for index, row in enumerate(continuity_rows, 6):
        left_linear, left_constant, boundary = row
        answer = _piecewise_differentiability_parameter(*row)
        specs.append(_checked_problem(
            3,
            index,
            title=rf"함수 $f(x)=\begin{{cases}}({left_linear})x+({left_constant})&(x<{boundary})\\({left_linear})x+a&(x\ge {boundary})\end{{cases}}$가 $x={boundary}$에서 미분가능할 때, a와 $\lim_{{x\to {boundary}}}f(x)$의 합을 구하시오.",
            answer=str(answer),
            tags=["#좌극한", "#우극한", "#미분가능", "#함수의연속", "#일치조건"],
            steps=[
                ("경계점으로 왼쪽에서 접근할 때의 좌극한을 계산한다.", "왼쪽 일차식에 경계값을 대입한다."),
                ("오른쪽 식에서 우극한과 경계 함숫값을 나타낸다.", "두 일차식의 기울기는 이미 같으므로 연속이면 미분가능하다."),
                ("미분가능성에 필요한 연속 조건으로 좌극한과 우극한을 같게 놓는다.", "a에 관한 일차방정식을 얻는다."),
                ("a를 구한 뒤 공통 극한과 더한다.", rf"따라서 요구한 합은 ${answer}$이다."),
            ],
            alternatives=["두 일차 그래프가 경계점에서 같은 점을 지나도록 좌표를 일치시켜 a를 구할 수 있다."],
            answer_check=lambda values=row: _piecewise_differentiability_parameter(*values),
        ))
    return specs


def _tier4_specs() -> list[dict[str, Any]]:
    """필요 변수는 삼차함수 접점과 원시함수 조건이다. 작동 원리는 미분계수·접선 및 부정적분 함수값 문제를 각 5개 만든다."""
    specs: list[dict[str, Any]] = []
    tangent_rows = [((1, -2, 3, 1), 2), ((-1, 3, 2, -4), -1), ((2, 1, -5, 11), 1), ((1, 4, -2, 5), -2), ((-2, -1, 6, 2), 2)]
    for index, (coefficients, point) in enumerate(tangent_rows, 1):
        answer = _tangent_slope_intercept_sum(coefficients, point)
        specs.append(_checked_problem(
            4,
            index,
            title=rf"함수 $f(x)={_poly_text(coefficients)}$에서 $x={point}$인 점의 접선 기울기를 미분계수의 정의로 구하라. 이어서 그 접선의 기울기와 y절편의 합을 구하시오.",
            answer=str(answer),
            tags=["#도함수의정의", "#미분계수", "#미분계수의정의", "#미분계수의기하적의미", "#거듭제곱의미분"],
            steps=[
                ("차분몫 $[f(a+h)-f(a)]/h$를 세운다.", "각 거듭제곱 차를 전개해 h를 인수로 묶는다."),
                ("h를 약분한 뒤 h가 0으로 갈 때의 극한을 구한다.", "이 값이 접선의 기울기다."),
                ("접점의 함수값을 계산한다.", "접점 좌표는 $(a,f(a))$이다."),
                ("점기울기식으로 접선 방정식을 세워 y절편을 구한다.", "x=0을 대입해도 된다."),
                ("기울기와 y절편을 더한다.", rf"따라서 요구한 합은 ${answer}$이다."),
            ],
            alternatives=["거듭제곱 미분 공식을 적용한 도함수에 접점 x좌표를 대입해 기울기를 검산할 수 있다."],
            answer_check=lambda values=coefficients, value=point: _tangent_slope_intercept_sum(values, value),
        ))

    antiderivative_rows = [(2, -3, 4, 1, 5, 4), (1, 2, -1, -2, 3, 3), (-2, 5, 3, 0, -4, 2), (3, -1, 2, 2, 7, 5), (1, -4, 6, -1, 2, 4)]
    for index, row in enumerate(antiderivative_rows, 6):
        quadratic, linear, constant, known_point, known_value, target = row
        answer = _antiderivative_target_value(*row)
        specs.append(_checked_problem(
            4,
            index,
            title=rf"미분가능한 함수 F가 $F'(x)=({quadratic})x^2+({linear})x+({constant})$, $F({known_point})={known_value}$를 만족할 때 $F({target})$의 값을 구하시오.",
            answer=str(answer),
            tags=["#부정적분", "#부정적분공식", "#부정적분의성질", "#부정적분의정의", "#미적분의기본정리"],
            steps=[
                ("미적분의 기본정리로 두 함숫값의 차를 도함수의 정적분으로 나타낸다.", "$F(b)-F(a)=\int_a^b F'(x)dx$이다."),
                ("도함수의 각 항을 거듭제곱 부정적분 공식으로 적분한다.", "상수배와 합차는 항별로 처리한다."),
                ("정적분의 위·아래 끝점을 원시함수에 대입한다.", "방향이 반대면 부호도 함께 바뀐다."),
                ("알려진 F의 함숫값을 더한다.", "적분상수를 따로 구하지 않아도 된다."),
                ("정확한 분수로 정리한다.", rf"따라서 $F({target})={answer}$이다."),
            ],
            alternatives=["F의 일반 부정적분에 적분상수 C를 붙이고 알려진 함숫값으로 C를 먼저 정할 수 있다."],
            answer_check=lambda values=row: _antiderivative_target_value(*values),
        ))
    return specs


def _tier5_specs() -> list[dict[str, Any]]:
    """필요 변수는 짝수 사차함수와 원탁 사람 수다. 작동 원리는 닫힌구간 극값과 인접 금지 원순열 문제를 각 5개 만든다."""
    specs: list[dict[str, Any]] = []
    extrema_rows = [(1, 3, 3), (4, -2, 4), (9, 5, 5), (4, 7, 3), (1, -4, 5)]
    for index, row in enumerate(extrema_rows, 1):
        parameter, vertical, bound = row
        answer = _quartic_range_width(*row)
        specs.append(_checked_problem(
            5,
            index,
            title=rf"닫힌구간 $[-{bound},{bound}]$에서 함수 $f(x)=x^4-({2*parameter})x^2+({vertical})$의 최댓값과 최솟값의 차를 구하시오.",
            answer=str(answer),
            tags=["#극값의판정", "#극댓값", "#극솟값", "#미분과최대최소", "#정의역에서의최대최소"],
            steps=[
                ("사차함수를 미분해 도함수를 인수분해한다.", "$f'(x)=4x(x^2-a)$ 꼴로 정리된다."),
                ("도함수가 0인 임계점을 모두 구한다.", "0과 대칭인 두 점이 후보가 된다."),
                ("임계점이 주어진 닫힌구간 안에 있는지 확인한다.", "범위 밖 임계점은 제외한다."),
                ("구간의 양 끝점과 남은 임계점에서 함수값을 계산한다.", "짝함수 대칭으로 같은 값은 한 번만 계산할 수 있다."),
                ("후보값 중 최댓값과 최솟값을 고른다.", "국소 극값과 구간 전체 극값을 구분한다."),
                ("최댓값에서 최솟값을 뺀다.", rf"따라서 차는 ${answer}$이다."),
            ],
            alternatives=[
                "$t=x^2$로 치환해 제한된 t구간에서 이차함수의 최대·최소를 구할 수 있다.",
                "도함수 부호표를 작성해 증가·감소 구간으로 전체 극값 후보를 찾을 수 있다.",
            ],
            answer_check=lambda values=row: _quartic_range_width(*values),
        ))

    circle_rows = [5, 6, 7, 8, 9]
    for index, people in enumerate(circle_rows, 6):
        answer = _circular_nonadjacent_count(people)
        specs.append(_checked_problem(
            5,
            index,
            title=rf"서로 다른 {people}명이 원탁에 앉을 때, 지정된 두 사람 A와 B가 서로 이웃하지 않도록 앉는 원순열의 수를 구하시오.",
            answer=str(answer),
            tags=["#원순열", "#조합", "#순열", "#경우의수", "#곱의법칙"],
            steps=[
                ("회전에 의한 같은 배치를 하나로 보는 전체 원순열 수를 구한다.", rf"전체는 $({people}-1)!$가지다."),
                ("A와 B가 이웃하는 경우를 하나의 블록으로 묶는다.", "블록과 나머지 사람을 원탁에 배치한다."),
                ("블록 내부에서 A,B의 순서를 정한다.", "AB와 BA의 두 가지가 있다."),
                ("블록 원순열 수에 내부 순서 수를 곱한다.", "이 값이 이웃하는 경우의 수다."),
                ("전체 원순열에서 이웃하는 경우를 뺀다.", "여사건을 이용하면 중복 없이 계산된다."),
                ("팩토리얼 값을 정리한다.", rf"따라서 이웃하지 않는 원순열은 ${answer}$가지다."),
            ],
            alternatives=[
                "A의 자리를 고정하고 B가 앉을 수 없는 양옆 두 자리를 제외해 나머지를 배열할 수 있다.",
                "작은 인원에서는 한 사람을 고정한 뒤 나머지 순열을 생성해 A,B 인접 여부를 직접 검사할 수 있다.",
            ],
            answer_check=lambda value=people: _circular_nonadjacent_count(value),
        ))
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 난이도별 10문항씩 총 50개의 v55 직접 출제 명세와 검산 함수를 반환한다."""
    return [*_tier1_specs(), *_tier2_specs(), *_tier3_specs(), *_tier4_specs(), *_tier5_specs()]


def validated_quests() -> list[dict[str, Any]]:
    """필요 변수는 v55 전체 카탈로그다. 작동 원리는 독립 정답 검산 후 생산 형식과 학생 풀이 계약을 전수 검사한다."""
    catalog = build_catalog()
    if any(not callable(spec.get("answer_check")) for spec in catalog):
        raise ValueError("v55 모든 문제에는 실행 가능한 정답 검산 함수가 필요합니다.")
    return validate_problem_batch(
        catalog,
        expected_count=50,
        batch_id=BATCH_ID,
        model_name=MODEL_NAME,
        codebase_base=CODEBASE_BASE,
        seed_base=SEED_BASE,
    )


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 DB 경로와 검증 모드다. 작동 원리는 v55 생산분을 멱등 저장하고 승인 상태로 재조회한다."""
    return seed_problem_batch(db_path, quests=validated_quests(), batch_id=BATCH_ID, validate_only=validate_only)


def main() -> None:
    """필요 변수는 명령행 옵션이다. 작동 원리는 상품을 변경하지 않고 v55 문제 생산 결과만 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
