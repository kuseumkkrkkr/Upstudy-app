from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys
from collections import Counter
from math import factorial
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from difficulty_contract import DIFFICULTY_CONTRACTS
from scripts.seed_initial_math_problems import (
    _build_quest,
    _content_text,
    _count_branches,
    _create_backup,
    _problem,
    _remove_inserted_batch,
)
from student_problem_content_review import review_student_problem_contract


BATCH_ID = "marketplace-original-v2"
QUEST_ID_PREFIX = f"curated/{BATCH_ID}"


def _complex_specs() -> list[dict[str, Any]]:
    """필요 변수는 허수 단위의 지수다. 작동 원리는 4주기 성질을 직접 적용하는 티어 1 신규 문제 5개를 만든다."""
    answers = {2: "-1", 3: "-i", 4: "1", 5: "i", 6: "-1"}
    return [
        _problem(
            1,
            index,
            title=rf"허수 단위 $i$에 대하여 $i^{power}$의 값을 구하시오.",
            answer=answers[power],
            tags=["#허수단위"],
            steps=[
                ("허수 단위의 거듭제곱이 4를 주기로 반복됨을 사용한다.", r"$i^1=i,\ i^2=-1,\ i^3=-i,\ i^4=1$이다."),
                ("지수를 4로 나눈 나머지에 해당하는 값을 고른다.", rf"따라서 $i^{power}={answers[power]}$이다."),
            ],
        )
        for index, power in enumerate((2, 3, 4, 5, 6), 1)
    ]


def _matrix_specs() -> list[dict[str, Any]]:
    """필요 변수는 두 행렬의 대응 성분이다. 작동 원리는 행렬 덧셈의 정의를 확인하는 티어 1 신규 문제 5개를 만든다."""
    rows = [(2, 5), (-3, 7), (4, -6), (8, 1), (-5, -2)]
    specs = []
    for index, (left, right) in enumerate(rows, 6):
        answer = left + right
        specs.append(
            _problem(
                1,
                index,
                title=rf"행렬 $A=\begin{{pmatrix}}1&{left}\\0&3\end{{pmatrix}}$, $B=\begin{{pmatrix}}2&{right}\\4&-1\end{{pmatrix}}$일 때, $A+B$의 $(1,2)$ 성분을 구하시오.",
                answer=str(answer),
                tags=["#행렬의덧셈"],
                steps=[
                    ("행렬의 덧셈은 같은 위치의 성분끼리 더한다.", rf"$(1,2)$ 위치의 두 성분은 ${left}$와 ${right}$이다."),
                    ("두 대응 성분을 더한다.", rf"${left}+({right})={answer}$이므로 구하는 성분은 ${answer}$이다."),
                ],
            )
        )
    return specs


def _remainder_specs() -> list[dict[str, Any]]:
    """필요 변수는 이차다항식과 일차식의 근이다. 작동 원리는 나머지정리로 값을 계산하는 티어 2 신규 문제 5개를 만든다."""
    rows = [(2, -3, 1), (-1, 5, 2), (3, 4, -1), (2, 7, 3), (-2, 6, -2)]
    specs = []
    for index, (p, q, k) in enumerate(rows, 1):
        answer = k * k + p * k + q
        specs.append(
            _problem(
                2,
                index,
                title=rf"다항식 $P(x)=x^2+({p})x+({q})$를 $x-({k})$로 나눈 나머지를 구하시오.",
                answer=str(answer),
                tags=["#나머지정리", "#다항식의연산"],
                steps=[
                    ("나머지정리를 적용할 대입값을 정한다.", rf"나누는 식 $x-({k})$가 0이 되는 값은 $x={k}$이다."),
                    ("나머지는 $P(k)$임을 이용해 식에 대입한다.", rf"나머지는 $P({k})=({k})^2+({p})({k})+({q})$이다."),
                    ("계산을 정리한다.", rf"$P({k})={answer}$이므로 나머지는 ${answer}$이다."),
                ],
            )
        )
    return specs


def _log_specs() -> list[dict[str, Any]]:
    """필요 변수는 로그의 밑과 값이다. 작동 원리는 지수형으로 바꾸어 진수를 구하는 티어 2 신규 문제 5개를 만든다."""
    rows = [(2, 5), (3, 3), (5, 2), (4, 3), (10, 2)]
    specs = []
    for index, (base, exponent) in enumerate(rows, 6):
        answer = base**exponent
        specs.append(
            _problem(
                2,
                index,
                title=rf"양수 $x$가 $\log_{base}x={exponent}$을 만족할 때, $x$를 구하시오.",
                answer=str(answer),
                tags=["#로그의정의", "#로그방정식"],
                steps=[
                    ("로그의 정의를 이용해 지수형으로 바꾼다.", rf"$\log_{base}x={exponent}$은 $x={base}^{exponent}$과 같다."),
                    ("거듭제곱을 계산한다.", rf"${base}^{exponent}={answer}$이다."),
                    ("진수 조건을 확인한다.", rf"${answer}>0$이므로 조건을 만족하고 $x={answer}$이다."),
                ],
            )
        )
    return specs


def _line_specs() -> list[dict[str, Any]]:
    """필요 변수는 정수 기울기·절편·두 x좌표다. 작동 원리는 두 점에서 직선의 y절편을 복원하는 티어 3 신규 문제 5개를 만든다."""
    rows = [(2, 3, -1, 2), (-1, 5, 0, 3), (3, -4, 1, 4), (-2, -1, -2, 1), (4, 2, -1, 1)]
    specs = []
    for index, (slope, intercept, x1, x2) in enumerate(rows, 1):
        y1, y2 = slope * x1 + intercept, slope * x2 + intercept
        specs.append(
            _problem(
                3,
                index,
                title=rf"두 점 $({x1},{y1})$, $({x2},{y2})$를 지나는 직선의 $y$절편을 구하시오.",
                answer=str(intercept),
                tags=["#직선의방정식", "#두점을지나는직선", "#기울기"],
                steps=[
                    ("두 점을 이용해 기울기를 구한다.", rf"기울기는 $\dfrac{{{y2}-({y1})}}{{{x2}-({x1})}}={slope}$이다."),
                    ("직선의 식을 $y=mx+b$로 둔다.", rf"직선은 $y={slope}x+b$로 나타낼 수 있다."),
                    ("한 점을 대입해 절편을 정한다.", rf"$({x1},{y1})$을 대입하면 ${y1}={slope}({x1})+b$이다."),
                    ("일차방정식을 풀어 절편을 구한다.", rf"따라서 $b={intercept}$이고 $y$절편은 ${intercept}$이다."),
                ],
                alternatives=[rf"점기울기형 $y-({y1})={slope}(x-({x1}))$을 전개해도 상수항 ${intercept}$을 얻는다."],
            )
        )
    return specs


def _permutation_specs() -> list[dict[str, Any]]:
    """필요 변수는 서로 다른 물건 수다. 작동 원리는 두 특정 대상의 선후 대칭을 이용하는 티어 3 신규 문제 5개를 만든다."""
    specs = []
    for index, total in enumerate(range(4, 9), 6):
        answer = factorial(total) // 2
        specs.append(
            _problem(
                3,
                index,
                title=rf"서로 다른 ${total}$개의 책을 한 줄로 놓을 때, 책 $A$가 책 $B$보다 왼쪽에 놓이는 경우의 수를 구하시오.",
                answer=str(answer),
                tags=["#순열", "#순열의수", "#곱의법칙"],
                steps=[
                    ("제한 없이 서로 다른 책을 배열하는 경우를 센다.", rf"전체 배열은 ${total}!={factorial(total)}$가지이다."),
                    ("각 배열에서 $A,B$의 위치만 맞바꾸는 대응을 생각한다.", "$A$가 왼쪽인 배열과 $B$가 왼쪽인 배열이 일대일 대응한다."),
                    ("두 경우의 수가 전체를 정확히 반으로 나눔을 이용한다.", rf"구하는 경우는 전체의 절반인 $\dfrac{{{total}!}}2$이다."),
                    ("값을 계산한다.", rf"$\dfrac{{{factorial(total)}}}2={answer}$가지이다."),
                ],
                alternatives=["먼저 두 책의 자리를 고른 뒤 작은 자리에는 $A$, 큰 자리에는 $B$를 놓고 나머지 책을 배열해도 같은 값을 얻는다."],
            )
        )
    return specs


def _tangent_specs() -> list[dict[str, Any]]:
    """필요 변수는 접점·미정계수·접선 기울기다. 작동 원리는 도함수 값으로 계수를 복원하는 티어 4 신규 문제 5개를 만든다."""
    rows = [(1, 2), (2, -3), (-1, 5), (3, 4), (-2, -1)]
    specs = []
    for index, (point, parameter) in enumerate(rows, 1):
        slope = 3 * point * point + parameter
        specs.append(
            _problem(
                4,
                index,
                title=rf"함수 $f(x)=x^3+ax$의 그래프 위에서 $x={point}$인 점에서의 접선 기울기가 ${slope}$일 때, 상수 $a$를 구하시오.",
                answer=str(parameter),
                tags=["#도함수", "#접선의방정식", "#접선의기울기", "#미정계수법"],
                steps=[
                    ("함수를 미분해 도함수를 구한다.", r"$f'(x)=3x^2+a$이다."),
                    ("접선 기울기는 접점에서의 미분계수임을 사용한다.", rf"$x={point}$에서의 기울기는 $f'({point})$이다."),
                    ("접점의 x좌표를 도함수에 대입한다.", rf"$f'({point})=3({point})^2+a={3 * point * point}+a$이다."),
                    ("주어진 기울기와 같게 놓는다.", rf"${3 * point * point}+a={slope}$이다."),
                    ("일차방정식을 풀어 계수를 구한다.", rf"따라서 $a={parameter}$이다."),
                ],
                alternatives=[rf"접선의 기울기 정의에서 $\lim_{{h\to0}}\dfrac{{f({point}+h)-f({point})}}h={3 * point * point}+a$를 계산해도 $a={parameter}$이다."],
            )
        )
    return specs


def _parabola_area_specs() -> list[dict[str, Any]]:
    """필요 변수는 양의 매개변수다. 작동 원리는 포물선과 x축 사이 넓이로 매개변수를 복원하는 티어 5 신규 문제 5개를 만든다."""
    specs = []
    for index, parameter in enumerate(range(1, 6), 1):
        numerator = 4 * parameter**3
        area_latex = str(numerator // 3) if numerator % 3 == 0 else rf"\frac{{{numerator}}}3"
        specs.append(
            _problem(
                5,
                index,
                title=rf"$a>0$이고 곡선 $y=x^2-2ax$와 $x$축으로 둘러싸인 부분의 넓이가 ${area_latex}$일 때, $a$를 구하시오.",
                answer=str(parameter),
                tags=["#정적분", "#정적분과넓이", "#곡선과x축사이의넓이", "#이차함수", "#정적분의계산"],
                steps=[
                    ("곡선과 x축의 교점을 구한다.", r"$x^2-2ax=x(x-2a)=0$이므로 교점의 x좌표는 $0,2a$이다."),
                    ("두 교점 사이에서 함수의 부호를 확인한다.", r"$a>0$이고 $0<x<2a$이면 $x(x-2a)<0$이다."),
                    ("넓이를 함수의 음수로 정적분한다.", r"$S=\int_0^{2a}(2ax-x^2)\,dx$이다."),
                    ("부정적분을 계산한다.", r"$\int(2ax-x^2)\,dx=ax^2-\frac{x^3}{3}$이다."),
                    ("적분 구간의 끝값을 대입한다.", r"$S=4a^3-\frac{8a^3}{3}=\frac{4a^3}{3}$이다."),
                    ("주어진 넓이와 비교해 양의 매개변수를 정한다.", rf"$\frac{{4a^3}}3={area_latex}$이고 $a>0$이므로 $a={parameter}$이다."),
                ],
                alternatives=[
                    r"$x=a+u$로 평행이동하면 포물선이 $u^2-a^2$이 되어 대칭성을 이용해 넓이를 계산할 수 있다.",
                    rf"치환 $x=at$를 쓰면 넓이는 $a^3\int_0^2(2t-t^2)dt=\frac43a^3$이므로 $a={parameter}$이다.",
                ],
            )
        )
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 8개 추가 영역에서 직접 출제한 두 번째 신규 문제 40개를 반환하는 것이다."""
    return [
        *_complex_specs(),
        *_matrix_specs(),
        *_remainder_specs(),
        *_log_specs(),
        *_line_specs(),
        *_permutation_specs(),
        *_tangent_specs(),
        *_parabola_area_specs(),
    ]


def _build_market_quest(spec: dict[str, Any]) -> dict[str, Any]:
    """필요 변수는 두 번째 직접 출제 명세다. 작동 원리는 생산 조립 규격에 신규 배치 ID와 충돌 없는 variant 메타를 부여하는 것이다."""
    quest = _build_quest(spec)
    tier = int(spec["tier"])
    index = int(spec["index"])
    variant_number = tier * 100 + index
    quest["header"]["quest_id"] = f"{QUEST_ID_PREFIX}/t{tier}-{index:02d}"
    quest["header"]["quest_model"] = {"models": ["aiflow-direct-authoring-v2"]}
    quest["data"]["codebase_id"] = -(20_260_718_500 + variant_number)
    quest["data"]["seed"] = 202_607_180_500 + variant_number
    quest["data"]["meta"] = {
        "batch_id": BATCH_ID,
        "origin": "aiflow_direct_original",
        "copyright_policy": "original_problem_and_solution",
        "authored_at": "2026-07-18",
        "marketplace_ready": True,
    }
    return quest


def validate_catalog(catalog: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """필요 변수는 두 번째 신규 40문항이다. 작동 원리는 ID·제목·난이도 구조와 학생 노출 품질 계약을 전수 검사하는 것이다."""
    if len(catalog) != 40:
        raise ValueError(f"신규 문제 수량 불일치: {len(catalog)}/40")
    quests = [_build_market_quest(spec) for spec in catalog]
    ids = [quest["header"]["quest_id"] for quest in quests]
    titles = [_content_text(quest["data"]["quest_title"]) for quest in quests]
    if len(ids) != len(set(ids)) or len(titles) != len(set(titles)):
        raise ValueError("두 번째 배치 내부에 중복 ID 또는 제목이 있습니다.")
    for quest in quests:
        tier = int(quest["info"]["difficulty_tier"])
        contract = DIFFICULTY_CONTRACTS[tier]
        if len(quest["solves"]) != contract.solves_count:
            raise ValueError(f"풀이 단계 계약 불일치: {quest['header']['quest_id']}")
        if _count_branches(quest["solves"]) != contract.branch_conditions:
            raise ValueError(f"분기 계약 불일치: {quest['header']['quest_id']}")
        review = review_student_problem_contract(
            quest,
            expected_solve_count=contract.solves_count,
            expected_tags=quest["info"]["hash_tag"],
        )
        if review["approved"] is not True:
            raise ValueError(f"학생 문제 품질 거절: {quest['header']['quest_id']} {review['reasons']}")
    return quests


def seed_database(db_path: Path, *, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 대상 DB와 검증 모드다. 작동 원리는 백업 후 두 번째 신규 ID만 저장하고 승인 상태를 전수 재조회하는 것이다."""
    db_path = db_path.resolve()
    quests = validate_catalog(build_catalog())
    report: dict[str, Any] = {
        "batch_id": BATCH_ID,
        "db_path": str(db_path),
        "validated": len(quests),
        "tier_counts": dict(sorted(Counter(int(q["info"]["difficulty_tier"]) for q in quests).items())),
        "inserted": 0,
        "skipped": 0,
    }
    if validate_only:
        return report
    os.environ["QUEST_DB_PATH"] = str(db_path)
    os.environ["PROBLEM_DUAL_WRITE_ENABLED"] = "false"
    from storage import storage as quest_storage

    quest_storage.DB_PATH = str(db_path)
    quest_storage.init_db()
    with sqlite3.connect(db_path) as connection:
        existing_ids = {str(row[0]) for row in connection.execute("SELECT quest_id FROM quest_header WHERE quest_id LIKE ?", (f"{QUEST_ID_PREFIX}/%",))}
        existing_titles = {_content_text(row[1]): str(row[0]) for row in connection.execute("SELECT quest_id, quest_title FROM quest_data")}
    for quest in quests:
        quest_id = quest["header"]["quest_id"]
        if quest_id in existing_ids:
            report["skipped"] += 1
            continue
        title = _content_text(quest["data"]["quest_title"])
        if title in existing_titles:
            raise RuntimeError(f"기존 문제와 제목 중복: {existing_titles[title]} / {title}")
    backup_path = db_path.with_name(f"{db_path.name}.bak_{BATCH_ID}")
    report["backup_created"] = _create_backup(db_path, backup_path)
    report["backup_path"] = str(backup_path)
    inserted_ids: list[str] = []
    try:
        for quest in quests:
            quest_id = quest["header"]["quest_id"]
            if quest_id in existing_ids:
                continue
            if not quest_storage.store_data(quest):
                raise RuntimeError(f"문제 저장 실패: {quest_id} {quest_storage.get_last_store_error()}")
            inserted_ids.append(quest_id)
    except Exception:
        _remove_inserted_batch(db_path, inserted_ids)
        raise
    loaded = quest_storage.get_quests_by_ids([quest["header"]["quest_id"] for quest in quests])
    if len(loaded) != 40 or any(quest["info"].get("quality_status") != "approved" for quest in loaded):
        raise RuntimeError("두 번째 신규 배치 재조회 또는 승인 검증에 실패했습니다.")
    report["inserted"] = len(inserted_ids)
    report["readback"] = len(loaded)
    report["approved"] = sum(1 for quest in loaded if quest["info"].get("quality_status") == "approved")
    return report


def main() -> None:
    """필요 변수는 DB 경로와 검증 옵션이다. 작동 원리는 두 번째 직접 출제 배치의 UTF-8 저장 보고서를 출력하는 것이다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
