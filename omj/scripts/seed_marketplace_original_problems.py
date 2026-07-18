from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys
from collections import Counter
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


BATCH_ID = "marketplace-original-v1"
QUEST_ID_PREFIX = f"curated/{BATCH_ID}"


def _polynomial_specs() -> list[dict[str, Any]]:
    """필요 변수는 다항식 계수와 대입값이다. 작동 원리는 계산 결과를 코드로 검산해 티어 1 독립 문제 5개를 직접 구성하는 것이다."""
    rows = [(2, -3, 1, 3), (3, 2, -5, 2), (-1, 4, 7, -2), (4, -1, -6, 2), (2, 5, -3, -1)]
    specs = []
    for index, (a, b, c, x) in enumerate(rows, 1):
        answer = a * x * x + b * x + c
        specs.append(
            _problem(
                1,
                index,
                title=rf"다항식 $P(x)={a}x^2+({b})x+({c})$에 대하여 $P({x})$의 값을 구하시오.",
                answer=str(answer),
                tags=["#다항식의연산"],
                steps=[
                    (rf"다항식에 $x={x}$를 대입한다.", rf"$P({x})={a}\cdot({x})^2+({b})\cdot({x})+({c})$이다."),
                    ("거듭제곱과 곱셈을 먼저 계산한 뒤 더한다.", rf"식을 정리하면 ${answer}$이므로 구하는 값은 ${answer}$이다."),
                ],
            )
        )
    return specs


def _quadratic_specs() -> list[dict[str, Any]]:
    """필요 변수는 서로 다른 두 정수근이다. 작동 원리는 전개한 이차방정식에서 큰 근을 찾는 티어 1 문제를 구성하는 것이다."""
    roots = [(2, 5), (-3, 4), (1, 7), (-5, -2), (3, 8)]
    specs = []
    for index, (small, large) in enumerate(roots, 6):
        b = -(small + large)
        c = small * large
        specs.append(
            _problem(
                1,
                index,
                title=rf"이차방정식 $x^2+({b})x+({c})=0$의 두 근 중 큰 값을 구하시오.",
                answer=str(large),
                tags=["#이차방정식"],
                steps=[
                    ("두 정수근의 합과 곱을 이용해 좌변을 인수분해한다.", rf"$x^2+({b})x+({c})=(x-({small}))(x-({large}))$이다."),
                    ("각 인수를 영으로 놓고 두 근을 비교한다.", rf"두 근은 ${small}, {large}$이므로 큰 값은 ${large}$이다."),
                ],
            )
        )
    return specs


def _sequence_specs() -> list[dict[str, Any]]:
    """필요 변수는 첫째항·공차·항 번호다. 작동 원리는 일반항을 세 단계로 적용하는 티어 2 문제 5개를 구성하는 것이다."""
    rows = [(3, 4, 8), (-2, 5, 7), (10, -2, 9), (1, 6, 6), (7, 3, 10)]
    specs = []
    for index, (first, difference, n) in enumerate(rows, 1):
        answer = first + (n - 1) * difference
        specs.append(
            _problem(
                2,
                index,
                title=rf"첫째항이 ${first}$이고 공차가 ${difference}$인 등차수열 $\{{a_n\}}$에서 $a_{n}$을 구하시오.",
                answer=str(answer),
                tags=["#등차수열", "#등차수열의일반항"],
                steps=[
                    ("등차수열의 일반항 공식을 적는다.", r"$a_n=a_1+(n-1)d$이다."),
                    ("첫째항, 공차, 항 번호를 공식에 대입한다.", rf"$a_{n}={first}+({n}-1)\cdot({difference})$이다."),
                    ("곱셈과 덧셈을 계산한다.", rf"$a_{n}={answer}$이다."),
                ],
            )
        )
    return specs


def _exponential_specs() -> list[dict[str, Any]]:
    """필요 변수는 밑과 두 지수다. 작동 원리는 같은 밑 비교 원리를 쓰는 티어 2 지수방정식 5개를 구성하는 것이다."""
    rows = [(2, 3, 7), (3, -1, 4), (5, 2, 5), (4, -2, 3), (7, 1, 6)]
    specs = []
    for index, (base, shift, exponent) in enumerate(rows, 6):
        answer = exponent - shift
        specs.append(
            _problem(
                2,
                index,
                title=rf"방정식 ${base}^{{x+({shift})}}={base}^{exponent}$을 만족하는 실수 $x$를 구하시오.",
                answer=str(answer),
                tags=["#지수방정식", "#지수법칙"],
                steps=[
                    ("양변의 밑이 같고 밑이 1이 아닌 양수임을 확인한다.", rf"밑 ${base}$가 같으므로 지수를 비교할 수 있다."),
                    ("두 지수를 같게 놓는다.", rf"$x+({shift})={exponent}$이다."),
                    ("일차방정식을 풀어 값을 구한다.", rf"따라서 $x={answer}$이다."),
                ],
            )
        )
    return specs


def _circle_chord_specs() -> list[dict[str, Any]]:
    """필요 변수는 원의 반지름·중심에서 현까지 거리·반현 길이다. 작동 원리는 피타고라스 정리로 현 길이를 구하는 티어 3 문제를 구성하는 것이다."""
    rows = [(5, 3, 4), (10, 6, 8), (13, 5, 12), (17, 8, 15), (25, 7, 24)]
    specs = []
    for index, (radius, distance, half) in enumerate(rows, 1):
        answer = 2 * half
        specs.append(
            _problem(
                3,
                index,
                title=rf"반지름이 ${radius}$인 원에서 중심과 현 $AB$ 사이의 거리가 ${distance}$일 때, 현 $AB$의 길이를 구하시오.",
                answer=str(answer),
                tags=["#원의방정식", "#중심", "#반지름"],
                steps=[
                    ("원의 중심에서 현에 내린 수선의 발을 $H$라 한다.", r"중심에서 현에 내린 수선은 현을 이등분하므로 $AH=HB$이다."),
                    ("직각삼각형에서 반지름과 중심-현 거리를 확인한다.", rf"빗변은 ${radius}$, 한 변은 ${distance}$이다."),
                    ("피타고라스 정리로 반현 길이를 구한다.", rf"$AH=\sqrt{{{radius}^2-{distance}^2}}={half}$이다."),
                    ("반현 길이를 두 배 한다.", rf"$AB=2AH={answer}$이다."),
                ],
                alternatives=[rf"원의 중심을 원점, 현을 $y={distance}$로 두면 교점의 $x$좌표가 $\pm {half}$이므로 현 길이는 ${answer}$이다."],
            )
        )
    return specs


def _counting_specs() -> list[dict[str, Any]]:
    """필요 변수는 전체 학생 수다. 작동 원리는 특정 두 명을 함께 뽑지 않는 조합을 여사건으로 계산하는 티어 3 문제를 구성하는 것이다."""
    specs = []
    for index, total in enumerate(range(6, 11), 6):
        all_cases = total * (total - 1) * (total - 2) // 6
        forbidden = total - 2
        answer = all_cases - forbidden
        specs.append(
            _problem(
                3,
                index,
                title=rf"${total}$명의 학생 중 대표 $3$명을 뽑을 때, 학생 $A$와 $B$가 동시에 뽑히지 않는 경우의 수를 구하시오.",
                answer=str(answer),
                tags=["#경우의수", "#조합", "#조합의수"],
                steps=[
                    ("제한 없이 대표를 뽑는 전체 경우를 센다.", rf"전체 경우는 $\binom{{{total}}}3={all_cases}$이다."),
                    ("$A,B$가 동시에 포함되는 금지 경우를 정한다.", "두 명을 먼저 고정하고 나머지 한 명만 고르면 된다."),
                    ("남은 학생 중 한 명을 고르는 경우를 센다.", rf"금지 경우는 $\binom{{{total - 2}}}1={forbidden}$이다."),
                    ("전체에서 금지 경우를 뺀다.", rf"구하는 경우의 수는 ${all_cases}-{forbidden}={answer}$이다."),
                ],
                alternatives=["$A$가 빠지는 경우와 $A$는 포함되지만 $B$가 빠지는 경우로 나누어 계산해도 같은 값을 얻는다."],
            )
        )
    return specs


def _derivative_specs() -> list[dict[str, Any]]:
    """필요 변수는 양의 매개변수다. 작동 원리는 극댓값과 극솟값의 차로 매개변수를 복원하는 티어 4 문제를 구성하는 것이다."""
    specs = []
    for index, parameter in enumerate(range(1, 6), 1):
        difference = 4 * parameter**3
        specs.append(
            _problem(
                4,
                index,
                title=rf"$a>0$이고 함수 $f(x)=x^3-3ax^2+4$의 극댓값과 극솟값의 차가 ${difference}$일 때, $a$를 구하시오.",
                answer=str(parameter),
                tags=["#도함수", "#함수의극대와극소", "#도함수의부호", "#극값의판정"],
                steps=[
                    ("함수를 미분한다.", r"$f'(x)=3x^2-6ax=3x(x-2a)$이다."),
                    ("도함수가 영이 되는 점을 구한다.", r"임계점은 $x=0,\ 2a$이다."),
                    ("$a>0$에서 도함수의 부호 변화를 판정한다.", r"$x=0$에서 양수에서 음수로, $x=2a$에서 음수에서 양수로 바뀐다."),
                    ("극댓값과 극솟값을 계산한다.", r"극댓값은 $f(0)=4$, 극솟값은 $f(2a)=4-4a^3$이다."),
                    ("두 극값의 차 조건을 풀어 매개변수를 정한다.", rf"$4-(4-4a^3)=4a^3={difference}$이고 $a>0$이므로 $a={parameter}$이다."),
                ],
                alternatives=[rf"두 임계점의 함숫값 차를 직접 정리하면 항상 $4a^3$이므로 ${difference}=4a^3$에서 곧바로 $a={parameter}$을 얻는다."],
            )
        )
    return specs


def _integral_specs() -> list[dict[str, Any]]:
    """필요 변수는 양의 매개변수다. 작동 원리는 홀함수 그래프와 정적분 넓이로 매개변수를 찾는 티어 5 문제를 구성하는 것이다."""
    specs = []
    for index, parameter in enumerate(range(1, 6), 1):
        numerator = 9 * parameter**4
        area_latex = str(numerator // 2) if numerator % 2 == 0 else rf"\frac{{{numerator}}}2"
        specs.append(
            _problem(
                5,
                index,
                title=rf"$a>0$이고 곡선 $y=x^3-3a^2x$와 $x$축으로 둘러싸인 두 부분의 넓이의 합이 ${area_latex}$일 때, $a$를 구하시오.",
                answer=str(parameter),
                tags=["#정적분", "#정적분과넓이", "#곡선과x축사이의넓이", "#정적분의성질", "#정적분의계산"],
                steps=[
                    ("함수의 영점을 구한다.", r"$x(x^2-3a^2)=0$이므로 영점은 $-\sqrt3a,0,\sqrt3a$이다."),
                    ("함수의 대칭성을 확인한다.", r"$f(-x)=-f(x)$인 홀함수이므로 좌우 두 부분의 넓이는 같다."),
                    ("양의 구간에서 함수의 부호를 판정한다.", r"$0<x<\sqrt3a$에서 $x^2-3a^2<0$이므로 함수값은 음수이다."),
                    ("오른쪽 한 부분의 넓이를 정적분으로 나타낸다.", r"$A=-\int_0^{\sqrt3a}(x^3-3a^2x)\,dx$이다."),
                    ("한 부분의 넓이를 계산한다.", r"$A=\left[-\frac{x^4}{4}+\frac{3a^2x^2}{2}\right]_0^{\sqrt3a}=\frac94a^4$이다."),
                    ("두 부분의 합과 주어진 값을 비교한다.", rf"전체 넓이는 $2A=\frac92a^4={area_latex}$이고 $a>0$이므로 $a={parameter}$이다."),
                ],
                alternatives=[
                    r"홀함수의 대칭성으로 전체 넓이를 $2\int_0^{\sqrt3a}(3a^2x-x^3)\,dx$로 바로 계산할 수 있다.",
                    rf"치환 $x=at$를 사용하면 전체 넓이가 $a^4$에 비례하며 비례상수는 $\frac92$이므로 $a={parameter}$이다.",
                ],
            )
        )
    return specs


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수는 없음이다. 작동 원리는 8개 수학 영역에서 직접 출제한 신규 문제 40개의 원본 명세를 반환하는 것이다."""
    return [
        *_polynomial_specs(),
        *_quadratic_specs(),
        *_sequence_specs(),
        *_exponential_specs(),
        *_circle_chord_specs(),
        *_counting_specs(),
        *_derivative_specs(),
        *_integral_specs(),
    ]


def _build_market_quest(spec: dict[str, Any]) -> dict[str, Any]:
    """필요 변수는 직접 출제 명세다. 작동 원리는 기존 생산 조립 규격을 재사용하되 ID·메타·variant를 신규 마켓 배치로 교체하는 것이다."""
    quest = _build_quest(spec)
    tier = int(spec["tier"])
    index = int(spec["index"])
    quest["header"]["quest_id"] = f"{QUEST_ID_PREFIX}/t{tier}-{index:02d}"
    quest["header"]["quest_model"] = {"models": ["aiflow-direct-authoring-v1"]}
    variant_number = tier * 100 + index
    quest["data"]["codebase_id"] = -(20_260_718_000 + variant_number)
    quest["data"]["seed"] = 202_607_180_000 + variant_number
    quest["data"]["meta"] = {
        "batch_id": BATCH_ID,
        "origin": "aiflow_direct_original",
        "copyright_policy": "original_problem_and_solution",
        "authored_at": "2026-07-18",
        "marketplace_ready": True,
    }
    return quest


def validate_catalog(catalog: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """필요 변수는 신규 40문항 명세다. 작동 원리는 답·ID·제목·티어 구조와 학생 노출 계약을 DB 저장 전에 전수 검사하는 것이다."""
    if len(catalog) != 40:
        raise ValueError(f"신규 문제 수량 불일치: {len(catalog)}/40")
    quests = [_build_market_quest(spec) for spec in catalog]
    ids = [quest["header"]["quest_id"] for quest in quests]
    titles = [_content_text(quest["data"]["quest_title"]) for quest in quests]
    if len(ids) != len(set(ids)) or len(titles) != len(set(titles)):
        raise ValueError("신규 배치 내부에 중복 ID 또는 제목이 있습니다.")
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
    """필요 변수는 대상 DB와 검증 모드다. 작동 원리는 백업 후 신규 ID만 직접 저장하고 40문항을 전수 재조회해 승인 상태를 확인하는 것이다."""
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
    if len(loaded) != 40:
        raise RuntimeError(f"신규 문제 재조회 수량 불일치: {len(loaded)}/40")
    if any(quest["info"].get("quality_status") != "approved" for quest in loaded):
        raise RuntimeError("신규 문제 중 승인되지 않은 항목이 있습니다.")
    report["inserted"] = len(inserted_ids)
    report["readback"] = len(loaded)
    report["approved"] = sum(1 for quest in loaded if quest["info"].get("quality_status") == "approved")
    return report


def main() -> None:
    """필요 변수는 DB 경로와 검증 옵션이다. 작동 원리는 직접 출제 배치의 UTF-8 저장 보고서를 출력하는 것이다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(seed_database(args.db, validate_only=args.validate_only), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
