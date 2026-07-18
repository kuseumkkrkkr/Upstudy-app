from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from domain.course.v2_models import CourseModule, CourseModuleType, CourseV2
from scripts.seed_initial_math_problems import _content_text


BATCH_ID = "marketplace-initial-v1"
LISTING_PREFIX = "market-v1"
SOURCE_QUEST_PREFIXES = (
    "curated/marketplace-original-v1",
    "curated/marketplace-original-v2",
    "curated/marketplace-original-v3",
    "curated/marketplace-original-v4",
    "curated/marketplace-original-v5",
    "curated/marketplace-original-v6",
    "curated/marketplace-original-v7",
    "curated/marketplace-original-v8",
    "curated/marketplace-original-v9",
    "curated/marketplace-original-v10",
    "curated/marketplace-original-v11",
    "curated/marketplace-original-v12",
    "curated/marketplace-original-v13",
    "curated/marketplace-original-v14",
    "curated/marketplace-original-v15",
    "curated/marketplace-original-v16",
    "curated/marketplace-original-v17",
)
V3_QUEST_PREFIX = "curated/marketplace-original-v3/"
V4_QUEST_PREFIX = "curated/marketplace-original-v4/"
V5_QUEST_PREFIX = "curated/marketplace-original-v5/"


@dataclass(frozen=True)
class ProblemRecord:
    """필요 변수는 문제 ID·티어·태그·제목이다. 작동 원리는 서로 다른 저장 형식의 문제를 마켓 편성용 불변 레코드로 정규화하는 것이다."""

    quest_id: str
    tier: int
    tags: tuple[str, ...]
    title: str


def _load_curated_problems(db_path: Path) -> list[ProblemRecord]:
    """필요 변수는 로컬 문제 DB다. 작동 원리는 승인된 독립 저작 문제만 한 번 읽어 초도 상품 편성의 원본으로 사용한다."""
    with sqlite3.connect(db_path) as connection:
        source_filter = " OR ".join("h.quest_id LIKE ?" for _ in SOURCE_QUEST_PREFIXES)
        rows = connection.execute(
            f"""
            SELECT h.quest_id, i.difficulty_tier, i.hash_tag, d.quest_title
            FROM quest_header h
            JOIN quest_info i ON i.quest_id = h.quest_id
            JOIN quest_data d ON d.quest_id = h.quest_id
            WHERE ({source_filter})
              AND i.quality_status = 'approved'
            ORDER BY i.difficulty_tier, h.quest_id
            """,
            tuple(f"{prefix}/%" for prefix in SOURCE_QUEST_PREFIXES),
        ).fetchall()
    problems: list[ProblemRecord] = []
    for quest_id, tier, raw_tags, raw_title in rows:
        try:
            tags = tuple(str(tag) for tag in json.loads(raw_tags or "[]"))
        except (TypeError, ValueError, json.JSONDecodeError):
            tags = ()
        problems.append(
            ProblemRecord(
                quest_id=str(quest_id),
                tier=int(tier),
                tags=tags,
                title=_content_text(raw_title),
            )
        )
    if len(problems) < 830:
        raise RuntimeError(f"마켓 신규 독립 저작 문제가 부족합니다: {len(problems)}/830")
    return problems


def _select_by_tag(
    problems: Iterable[ProblemRecord],
    keywords: tuple[str, ...],
    count: int,
) -> list[ProblemRecord]:
    """필요 변수는 문제 목록·태그 키워드·수량이다. 작동 원리는 태그에 키워드가 포함된 문제를 ID 순으로 골라 결정적인 문제세트를 만든다."""
    selected = [
        problem
        for problem in problems
        if any(keyword in tag for tag in problem.tags for keyword in keywords)
    ]
    if len(selected) < count:
        raise RuntimeError(f"태그 편성 수량 부족: {keywords} {len(selected)}/{count}")
    return selected[:count]


def _select_by_tier(
    problems: Iterable[ProblemRecord],
    minimum: int,
    maximum: int,
    count: int,
    offset: int = 0,
) -> list[ProblemRecord]:
    """필요 변수는 티어 범위·수량·오프셋이다. 작동 원리는 승인 문제를 난이도 순으로 순환 선택해 시험지별 구성을 안정적으로 만든다."""
    candidates = [problem for problem in problems if minimum <= problem.tier <= maximum]
    if len(candidates) < count:
        raise RuntimeError(f"난이도 편성 수량 부족: {minimum}-{maximum} {len(candidates)}/{count}")
    start = offset % len(candidates)
    rotated = candidates[start:] + candidates[:start]
    return rotated[:count]


def _select_v3_by_tag(
    problems: Iterable[ProblemRecord],
    keywords: tuple[str, ...],
    count: int,
) -> list[ProblemRecord]:
    """필요 변수는 전체 문제·v3 태그·수량이다. 작동 원리는 세 번째 직접 출제 배치 안에서만 태그가 맞는 문제를 골라 새 문제세트를 분리하는 것이다."""
    return _select_by_tag(
        (problem for problem in problems if problem.quest_id.startswith(V3_QUEST_PREFIX)),
        keywords,
        count,
    )


def _select_v3_by_tier(
    problems: Iterable[ProblemRecord],
    tier: int,
    count: int = 10,
) -> list[ProblemRecord]:
    """필요 변수는 전체 문제·단일 난이도·수량이다. 작동 원리는 v3 문제 중 정확히 한 난이도만 선택해 시험지와 코스의 난이도 혼입을 막는 것이다."""
    return _select_by_tier(
        (problem for problem in problems if problem.quest_id.startswith(V3_QUEST_PREFIX)),
        tier,
        tier,
        count,
    )


def _select_v4_by_tag(
    problems: Iterable[ProblemRecord],
    keywords: tuple[str, ...],
    count: int,
) -> list[ProblemRecord]:
    """필요 변수는 전체 문제·v4 태그·수량이다. 작동 원리는 네 번째 직접 출제 배치 안에서만 태그가 맞는 문제를 골라 새 문제세트를 분리하는 것이다."""
    return _select_by_tag(
        (problem for problem in problems if problem.quest_id.startswith(V4_QUEST_PREFIX)),
        keywords,
        count,
    )


def _select_v4_by_tier(
    problems: Iterable[ProblemRecord],
    tier: int,
    count: int = 10,
) -> list[ProblemRecord]:
    """필요 변수는 전체 문제·단일 난이도·수량이다. 작동 원리는 v4 문제 중 정확히 한 난이도만 선택해 시험지와 코스의 난이도 혼입을 막는 것이다."""
    return _select_by_tier(
        (problem for problem in problems if problem.quest_id.startswith(V4_QUEST_PREFIX)),
        tier,
        tier,
        count,
    )


def _select_v5_by_tag(
    problems: Iterable[ProblemRecord],
    keywords: tuple[str, ...],
    count: int,
) -> list[ProblemRecord]:
    """필요 변수는 전체 문제·v5 태그·수량이다. 작동 원리는 다섯 번째 직접 출제 배치 안에서만 태그가 맞는 문제를 골라 새 문제세트를 분리하는 것이다."""
    return _select_by_tag(
        (problem for problem in problems if problem.quest_id.startswith(V5_QUEST_PREFIX)),
        keywords,
        count,
    )


def _select_v5_by_tier(
    problems: Iterable[ProblemRecord],
    tier: int,
    count: int = 10,
) -> list[ProblemRecord]:
    """필요 변수는 전체 문제·단일 난이도·수량이다. 작동 원리는 v5 문제 중 정확히 한 난이도만 선택해 시험지와 코스의 난이도 혼입을 막는 것이다."""
    return _select_by_tier(
        (problem for problem in problems if problem.quest_id.startswith(V5_QUEST_PREFIX)),
        tier,
        tier,
        count,
    )


def _listing(
    *,
    listing_id: str,
    kind: str,
    title: str,
    description: str,
    problems: list[ProblemRecord],
    grade_band: str,
    difficulty: str,
    estimated_minutes: int,
    price_points: int,
    featured_rank: int,
    asset_id: str = "",
    payload: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """필요 변수는 상품 표시값과 문제 편성이다. 작동 원리는 마켓 저장소가 요구하는 공통 목록 구조와 검색 태그를 조립하는 것이다."""
    tags = sorted({tag for problem in problems for tag in problem.tags})
    return {
        "id": listing_id,
        "kind": kind,
        "title": title,
        "description": description,
        "subject": "수학",
        "grade_band": grade_band,
        "difficulty": difficulty,
        "item_count": len(problems),
        "estimated_minutes": estimated_minutes,
        "price_points": price_points,
        "asset_id": asset_id,
        "tags": tags,
        "problem_ids": [problem.quest_id for problem in problems],
        "payload": {"batch_id": BATCH_ID, **(payload or {})},
        "status": "published",
        "featured_rank": featured_rank,
    }


def _select_batch_by_tag(
    problems: Iterable[ProblemRecord],
    *,
    version: int,
    keywords: tuple[str, ...],
    count: int,
) -> list[ProblemRecord]:
    """필요 변수는 전체 문제·배치 버전·태그·수량이다. 작동 원리는 지정한 직접 출제 배치 내부에서만 태그 문제를 선택해 버전 간 혼입을 막는 것이다."""
    prefix = f"curated/marketplace-original-v{version}/"
    return _select_by_tag(
        (problem for problem in problems if problem.quest_id.startswith(prefix)),
        keywords,
        count,
    )


def _select_batch_by_tier(
    problems: Iterable[ProblemRecord],
    *,
    version: int,
    tier: int,
    count: int = 10,
) -> list[ProblemRecord]:
    """필요 변수는 전체 문제·배치 버전·단일 난이도·수량이다. 작동 원리는 지정 배치의 한 난이도만 골라 시험지와 코스를 정확히 분리하는 것이다."""
    prefix = f"curated/marketplace-original-v{version}/"
    return _select_by_tier(
        (problem for problem in problems if problem.quest_id.startswith(prefix)),
        tier,
        tier,
        count,
    )


def _append_difficulty_batch_inventory(
    *,
    listings: list[dict[str, Any]],
    courses: list[CourseV2],
    problems: list[ProblemRecord],
    version: int,
    set_specs: list[tuple[str, str, str, tuple[str, ...], str, str]],
    title_suffix: str,
    set_price: int,
    exam_price: int,
    course_price_base: int,
    target_ovr_base: int,
    set_rank_base: int,
    exam_rank_base: int,
    course_rank_base: int,
) -> None:
    """필요 변수는 배치 버전·10개 세트 규격·가격·노출 순위다. 작동 원리는 해당 배치의 문제세트 10개, 난이도별 시험지 5개와 코스 5개를 같은 계약으로 추가하는 것이다."""
    batch_id = f"marketplace-original-v{version}"
    if len(set_specs) != 10:
        raise ValueError(f"v{version} 문제세트 규격은 10개여야 합니다: {len(set_specs)}")
    for index, (slug, title, description, keywords, grade, difficulty) in enumerate(set_specs):
        selected = _select_batch_by_tag(
            problems,
            version=version,
            keywords=keywords,
            count=5,
        )
        listings.append(
            _listing(
                listing_id=f"{LISTING_PREFIX}-set-{slug}",
                kind="problem_set",
                title=title,
                description=description,
                problems=selected,
                grade_band=grade,
                difficulty=difficulty,
                estimated_minutes=20,
                price_points=set_price,
                featured_rank=set_rank_base - index,
                payload={"source_batch": batch_id},
            )
        )

    tier_labels = {
        1: ("기본기 진단", "고1"),
        2: ("개념 적용 진단", "고1-2"),
        3: ("유형 연결 진단", "고1-2"),
        4: ("응용 실전 모의", "고2-3"),
        5: ("심화 사고력 모의", "고2-3"),
    }
    for tier, (label, grade) in tier_labels.items():
        selected = _select_batch_by_tier(problems, version=version, tier=tier)
        listings.append(
            _listing(
                listing_id=f"{LISTING_PREFIX}-exam-tier-{tier}-v{version}",
                kind="exam",
                title=f"난이도 {tier} 전용 {label}{title_suffix}",
                description=f"v{version} 난이도 {tier} 직접 출제 문제 10문항",
                problems=selected,
                grade_band=grade,
                difficulty=f"난이도 {tier}",
                estimated_minutes=40 + tier * 5,
                price_points=exam_price,
                featured_rank=exam_rank_base - tier,
                payload={
                    "exam_type": "difficulty_diagnostic",
                    "time_limit_minutes": 40 + tier * 5,
                    "source_batch": batch_id,
                    "difficulty_tier": tier,
                },
            )
        )

        course_id = f"market-course-tier-{tier}-v{version}"
        course_title = f"난이도 {tier} · {label} 코스{title_suffix}"
        modules = [
            CourseModule(
                id=f"{course_id}-m{module_index + 1}",
                type=CourseModuleType.problem_solve,
                title=f"{module_index + 1}단계 · v{version} 난이도 {tier}",
                description=f"v{version} 난이도 {tier} 직접 출제 문제 5문항",
                position=module_index,
                estimated_minutes=25 + tier * 5,
                problem_ids=[problem.quest_id for problem in selected[module_index * 5 : module_index * 5 + 5]],
                question_count=5,
                pass_rate=80,
            )
            for module_index in range(2)
        ]
        course = CourseV2(
            id=course_id,
            title=course_title,
            description=f"v{version} 난이도 {tier} 문제만 단계별로 학습하는 전용 코스",
            difficulty=f"난이도 {tier}",
            duration="2일",
            tags=sorted({tag for problem in selected for tag in problem.tags}),
            focus_tags=sorted({tag for problem in selected for tag in problem.tags})[:8],
            target_ovr=target_ovr_base + tier * 400,
            is_demo=False,
            is_public=True,
            owner_user_id="aiflow-market",
            modules=modules,
        )
        courses.append(course)
        listings.append(
            _listing(
                listing_id=f"{LISTING_PREFIX}-course-tier-{tier}-v{version}",
                kind="course",
                title=course_title,
                description=course.description,
                problems=selected,
                grade_band=grade,
                difficulty=f"난이도 {tier}",
                estimated_minutes=(25 + tier * 5) * 2,
                price_points=course_price_base + tier * 200,
                featured_rank=course_rank_base - tier,
                asset_id=course_id,
                payload={
                    "module_count": 2,
                    "recommended_days": 2,
                    "source_batch": batch_id,
                    "difficulty_tier": tier,
                },
            )
        )


def build_inventory(problems: list[ProblemRecord]) -> tuple[list[dict[str, Any]], list[CourseV2]]:
    """필요 변수는 승인된 독립 저작 문제다. 작동 원리는 기존 상품과 v3·v4 난이도별 상품을 결정적으로 편성한다."""
    set_specs = [
        ("polynomial", "다항식 기본기 5", "다항식 계산부터 인수정리까지", ("다항식", "인수정리"), "고1", "입문"),
        ("quadratic", "이차방정식 집중 5", "근과 계수, 판별식 핵심 연습", ("이차방정식", "근과계수"), "고1", "기본"),
        ("sequence", "수열 패턴 훈련 5", "등차·등비수열과 합의 구조", ("수열",), "고2", "기본"),
        ("exponential", "지수·로그 스타터 5", "지수법칙과 방정식 첫 훈련", ("지수", "로그"), "고2", "기본"),
        ("function", "함수 그래프 해석 5", "합성함수와 그래프 이동 연습", ("함수", "그래프"), "고1-2", "중급"),
        ("counting", "경우의 수 핵심 5", "순열·조합과 조건 분류 연습", ("경우의수", "순열", "조합"), "고1", "중급"),
        ("derivative", "미분 개념 점검 5", "도함수와 극대·극소 판정", ("미분", "도함수"), "고2-3", "중급"),
        ("integral", "적분 계산 점검 5", "정적분 계산과 넓이 해석", ("적분", "넓이"), "고2-3", "중급"),
        ("complex", "복소수 계산 스타터 5", "허수 단위의 거듭제곱 4주기 훈련", ("허수단위",), "고1", "입문"),
        ("matrix", "행렬 연산 스타터 5", "대응 성분을 이용한 행렬 덧셈", ("행렬의덧셈",), "고1", "입문"),
        ("remainder", "나머지정리 기본기 5", "대입으로 나머지를 빠르게 계산하는 훈련", ("나머지정리",), "고1", "기본"),
        ("logarithm", "로그 정의 점검 5", "로그식을 지수식으로 바꾸는 핵심 연습", ("로그의정의",), "고2", "기본"),
        ("line", "직선의 방정식 점검 5", "두 점에서 기울기와 절편 복원", ("두점을지나는직선",), "고1", "중급"),
        ("permutation", "순열 사고 훈련 5", "선후 조건과 일대일 대응 연습", ("순열의수",), "고1", "중급"),
        ("tangent", "접선 기울기 실전 5", "도함수로 미정계수를 복원하는 문제", ("접선의기울기",), "고2-3", "중상"),
        ("parabola-area", "포물선 넓이 실전 5", "정적분 넓이에서 매개변수 찾기", ("이차함수", "정적분과넓이"), "고2-3", "심화"),
    ]
    listings: list[dict[str, Any]] = []
    for index, (slug, title, description, keywords, grade, difficulty) in enumerate(set_specs):
        selected = _select_by_tag(problems, keywords, 5)
        listings.append(
            _listing(
                listing_id=f"{LISTING_PREFIX}-set-{slug}",
                kind="problem_set",
                title=title,
                description=description,
                problems=selected,
                grade_band=grade,
                difficulty=difficulty,
                estimated_minutes=20,
                price_points=0 if index < 2 else 120,
                featured_rank=90 - index,
            )
        )

    v3_set_specs = [
        ("v3-complex", "난이도 1 · 복소수 연산 5", "복소수의 실수부와 허수부 계산", ("복소수의연산",), "고1", "난이도 1"),
        ("v3-factorial", "난이도 1 · 팩토리얼 5", "팩토리얼 전개와 약분 기본기", ("팩토리얼",), "고1", "난이도 1"),
        ("v3-discriminant", "난이도 2 · 판별식 5", "판별식으로 실근 개수 판정", ("이차방정식의판별식",), "고1", "난이도 2"),
        ("v3-geometric", "난이도 2 · 등비수열 5", "등비수열 일반항 계산", ("등비수열의일반항",), "고2", "난이도 2"),
        ("v3-set", "난이도 3 · 집합 연산 5", "교집합과 합집합 원소 수", ("집합의연산",), "고1", "난이도 3"),
        ("v3-arithmetic-sum", "난이도 3 · 등차수열의 합 5", "끝항과 합 공식을 연결하는 훈련", ("등차수열의합",), "고2", "난이도 3"),
        ("v3-integral-coefficient", "난이도 4 · 정적분 계수 5", "정적분 조건에서 미정계수 복원", ("정적분의선형성",), "고2-3", "난이도 4"),
        ("v3-quadratic-minimum", "난이도 4 · 이차함수 최솟값 5", "완전제곱과 최솟값 조건", ("이차함수의최대최소",), "고1", "난이도 4"),
        ("v3-parabola-area", "난이도 5 · 포물선 넓이 5", "직선과 포물선 사이 넓이", ("두곡선사이의넓이",), "고2-3", "난이도 5"),
        ("v3-cubic-extrema", "난이도 5 · 삼차함수 극값 5", "극댓값과 극솟값의 차로 계수 복원", ("함수의극대와극소",), "고2-3", "난이도 5"),
    ]
    for index, (slug, title, description, keywords, grade, difficulty) in enumerate(v3_set_specs):
        selected = _select_v3_by_tag(problems, keywords, 5)
        listings.append(
            _listing(
                listing_id=f"{LISTING_PREFIX}-set-{slug}",
                kind="problem_set",
                title=title,
                description=description,
                problems=selected,
                grade_band=grade,
                difficulty=difficulty,
                estimated_minutes=20,
                price_points=150,
                featured_rank=80 - index,
                payload={"source_batch": "marketplace-original-v3"},
            )
        )

    v4_set_specs = [
        ("v4-polynomial", "난이도 1 · 다항식 계산 5", "동류항 정리와 식의 값", ("다항식의연산",), "고1", "난이도 1"),
        ("v4-arithmetic-term", "난이도 1 · 등차수열 일반항 5", "공차를 이용한 특정 항 계산", ("등차수열",), "고1-2", "난이도 1"),
        ("v4-other-root", "난이도 2 · 다른 한 근 5", "근과 계수의 관계로 근 복원", ("근과계수의관계",), "고1", "난이도 2"),
        ("v4-log-definition", "난이도 2 · 로그와 지수 5", "로그 정의를 지수식으로 변환", ("로그의정의",), "고2", "난이도 2"),
        ("v4-square-sum", "난이도 3 · 자연수 제곱합 5", "시그마와 제곱합 공식 적용", ("자연수의거듭제곱의합",), "고2", "난이도 3"),
        ("v4-circle-radius", "난이도 3 · 원의 반지름 5", "원의 일반형을 표준형으로 변환", ("원의일반형",), "고1", "난이도 3"),
        ("v4-tangent-parameter", "난이도 4 · 접선 매개변수 5", "도함수와 접선 기울기 조건", ("접선의기울기",), "고2-3", "난이도 4"),
        ("v4-continuity", "난이도 4 · 함수의 연속 5", "빠진 점의 연속 조건과 극한", ("함수의연속",), "고2-3", "난이도 4"),
        ("v4-log-equation", "난이도 5 · 로그방정식 5", "두 근의 곱으로 매개변수 복원", ("로그방정식",), "고2-3", "난이도 5"),
        ("v4-circle-tangent", "난이도 5 · 원의 두 접선 5", "접선 거리 조건과 기울기 합", ("점과직선사이의거리",), "고1-2", "난이도 5"),
    ]
    for index, (slug, title, description, keywords, grade, difficulty) in enumerate(v4_set_specs):
        selected = _select_v4_by_tag(problems, keywords, 5)
        listings.append(
            _listing(
                listing_id=f"{LISTING_PREFIX}-set-{slug}",
                kind="problem_set",
                title=title,
                description=description,
                problems=selected,
                grade_band=grade,
                difficulty=difficulty,
                estimated_minutes=20,
                price_points=170,
                featured_rank=70 - index,
                payload={"source_batch": "marketplace-original-v4"},
            )
        )

    v5_set_specs = [
        ("v5-remainder", "난이도 1 · 나머지정리 5", "일차식의 근을 이용한 나머지 계산", ("나머지정리",), "고1", "난이도 1"),
        ("v5-composition", "난이도 1 · 합성함수 계산 5", "안쪽 함수부터 계산하는 기본 훈련", ("합성함수",), "고1", "난이도 1"),
        ("v5-distance", "난이도 2 · 두 점 사이 거리 5", "좌표 차와 거리 공식 적용", ("두점사이의거리",), "고1", "난이도 2"),
        ("v5-exponential", "난이도 2 · 지수방정식 5", "같은 밑의 지수 비교", ("지수방정식과지수부등식",), "고2", "난이도 2"),
        ("v5-factor-theorem", "난이도 3 · 인수정리 5", "삼차다항식의 미정계수 복원", ("고차식인수분해",), "고1", "난이도 3"),
        ("v5-rational-asymptote", "난이도 3 · 유리함수 점근선 5", "평행이동과 점근선 교점", ("유리함수의평행이동",), "고1-2", "난이도 3"),
        ("v5-geometric-log", "난이도 4 · 로그수열 5", "등비수열을 로그로 변환한 합", ("로그법칙",), "고2", "난이도 4"),
        ("v5-circle-chord", "난이도 4 · 원의 현 5", "원과 직선의 두 교점 거리", ("원의방정식",), "고1", "난이도 4"),
        ("v5-cubic-area", "난이도 5 · 삼차함수 넓이 5", "두 극점의 현과 곡선 사이 넓이", ("정적분",), "고2-3", "난이도 5"),
        ("v5-removable-continuity", "난이도 5 · 제거가능 불연속 5", "인수분해와 연속 조건으로 상수 복원", ("극한의성질",), "고2-3", "난이도 5"),
    ]
    for index, (slug, title, description, keywords, grade, difficulty) in enumerate(v5_set_specs):
        selected = _select_v5_by_tag(problems, keywords, 5)
        listings.append(
            _listing(
                listing_id=f"{LISTING_PREFIX}-set-{slug}",
                kind="problem_set",
                title=title,
                description=description,
                problems=selected,
                grade_band=grade,
                difficulty=difficulty,
                estimated_minutes=20,
                price_points=190,
                featured_rank=60 - index,
                payload={"source_batch": "marketplace-original-v5"},
            )
        )

    exam_specs = [
        ("foundation-a", "공통수학 기초 진단 A", "고1 핵심 개념 10문항 진단", 1, 2, 0, "고1", "입문"),
        ("foundation-b", "공통수학 기초 진단 B", "계산 정확도와 개념 연결 점검", 1, 2, 12, "고1", "기본"),
        ("algebra", "대수 실전 미니 모의", "수열·지수·로그 10문항", 2, 4, 24, "고2", "중급"),
        ("calculus", "미적분 I 실전 미니 모의", "극한·미분·적분 10문항", 3, 5, 36, "고2-3", "중상"),
        ("challenge", "상위권 사고력 모의", "복합 조건 중심 10문항", 4, 5, 48, "고2-3", "심화"),
        ("mixed", "전 범위 밸런스 모의", "난이도 1~5 혼합 10문항", 1, 5, 60, "고1-3", "혼합"),
        ("common-math-plus", "공통수학 종합 진단 C", "복소수·행렬·직선까지 확장한 10문항", 1, 3, 72, "고1", "중급"),
        ("algebra-plus", "대수 개념 진단 B", "나머지정리·로그·수열 혼합 10문항", 2, 4, 84, "고1-2", "중급"),
        ("calculus-plus", "미적분 I 실전 모의 B", "접선과 정적분 넓이 중심 10문항", 4, 5, 8, "고2-3", "중상"),
        ("mixed-plus", "전 범위 밸런스 모의 B", "두 직접 출제 배치를 섞은 10문항", 1, 5, 96, "고1-3", "혼합"),
    ]
    for index, (slug, title, description, low, high, offset, grade, difficulty) in enumerate(exam_specs):
        selected = _select_by_tier(problems, low, high, 10, offset)
        listings.append(
            _listing(
                listing_id=f"{LISTING_PREFIX}-exam-{slug}",
                kind="exam",
                title=title,
                description=description,
                problems=selected,
                grade_band=grade,
                difficulty=difficulty,
                estimated_minutes=45,
                price_points=0 if index == 0 else 250,
                featured_rank=110 - index,
                payload={"exam_type": "mock", "time_limit_minutes": 45},
            )
        )

    tier_labels = {
        1: ("기본기 진단", "고1"),
        2: ("개념 적용 진단", "고1-2"),
        3: ("유형 연결 진단", "고1-2"),
        4: ("응용 실전 모의", "고2-3"),
        5: ("심화 사고력 모의", "고2-3"),
    }
    for tier, (label, grade) in tier_labels.items():
        selected = _select_v3_by_tier(problems, tier)
        listings.append(
            _listing(
                listing_id=f"{LISTING_PREFIX}-exam-tier-{tier}-v3",
                kind="exam",
                title=f"난이도 {tier} 전용 {label}",
                description=f"난이도 {tier} 직접 출제 문제 10문항",
                problems=selected,
                grade_band=grade,
                difficulty=f"난이도 {tier}",
                estimated_minutes=40 + tier * 5,
                price_points=300,
                featured_rank=120 - tier,
                payload={
                    "exam_type": "difficulty_diagnostic",
                    "time_limit_minutes": 40 + tier * 5,
                    "source_batch": "marketplace-original-v3",
                    "difficulty_tier": tier,
                },
            )
        )

    for tier, (label, grade) in tier_labels.items():
        selected = _select_v4_by_tier(problems, tier)
        listings.append(
            _listing(
                listing_id=f"{LISTING_PREFIX}-exam-tier-{tier}-v4",
                kind="exam",
                title=f"난이도 {tier} 전용 {label} · 확장",
                description=f"v4 난이도 {tier} 직접 출제 문제 10문항",
                problems=selected,
                grade_band=grade,
                difficulty=f"난이도 {tier}",
                estimated_minutes=40 + tier * 5,
                price_points=320,
                featured_rank=114 - tier,
                payload={
                    "exam_type": "difficulty_diagnostic",
                    "time_limit_minutes": 40 + tier * 5,
                    "source_batch": "marketplace-original-v4",
                    "difficulty_tier": tier,
                },
            )
        )

    for tier, (label, grade) in tier_labels.items():
        selected = _select_v5_by_tier(problems, tier)
        listings.append(
            _listing(
                listing_id=f"{LISTING_PREFIX}-exam-tier-{tier}-v5",
                kind="exam",
                title=f"난이도 {tier} 전용 {label} · 유형 확장",
                description=f"v5 난이도 {tier} 직접 출제 문제 10문항",
                problems=selected,
                grade_band=grade,
                difficulty=f"난이도 {tier}",
                estimated_minutes=40 + tier * 5,
                price_points=340,
                featured_rank=108 - tier,
                payload={
                    "exam_type": "difficulty_diagnostic",
                    "time_limit_minutes": 40 + tier * 5,
                    "source_batch": "marketplace-original-v5",
                    "difficulty_tier": tier,
                },
            )
        )

    course_specs = [
        ("foundation", "공통수학 기초 완성", "다항식부터 지수까지 4단계 코스", "tier", (1, 2, 20, 0), "고1-2", "입문", 900),
        ("algebra", "대수 개념 연결", "방정식·수열·지수를 연결하는 3단계 코스", "tag", (("이차방정식", "수열", "지수"), 15), "고1-2", "중급", 1200),
        ("calculus", "미적분 I 실전 루트", "미분과 적분을 연결하는 2단계 코스", "tier", (4, 5, 10, 0), "고2-3", "중상", 1500),
        ("challenge", "상위권 복합 사고력", "티어 3~5 문제로 구성한 4단계 심화 코스", "tier", (3, 5, 20, 5), "고2-3", "심화", 1800),
        ("geometry", "좌표기하 연결 코스", "원과 직선을 연결하는 2단계 코스", "tag", (("원의방정식", "두점을지나는직선"), 10), "고1", "중급", 1100),
        ("mastery", "수학 전 범위 마스터 루트", "두 직접 출제 배치에서 고른 5단계 종합 코스", "tier", (1, 5, 25, 30), "고1-3", "혼합", 2200),
    ]
    courses: list[CourseV2] = []
    for index, (slug, title, description, selector, selector_args, grade, difficulty, points) in enumerate(course_specs):
        if selector == "tag":
            keywords, count = selector_args
            selected = _select_by_tag(problems, keywords, count)
        else:
            minimum, maximum, count, offset = selector_args
            selected = _select_by_tier(problems, minimum, maximum, count, offset)
        course_id = f"market-course-{slug}-v1"
        module_count = len(selected) // 5
        modules = [
            CourseModule(
                id=f"{course_id}-m{module_index + 1}",
                type=CourseModuleType.problem_solve,
                title=f"{module_index + 1}단계 · {title}",
                description="검수된 독립 저작 문제 5문항",
                position=module_index,
                estimated_minutes=25,
                problem_ids=[problem.quest_id for problem in selected[module_index * 5 : module_index * 5 + 5]],
                question_count=5,
                pass_rate=80,
            )
            for module_index in range(module_count)
        ]
        course = CourseV2(
            id=course_id,
            title=title,
            description=description,
            difficulty=difficulty,
            duration=f"{module_count}일",
            tags=sorted({tag for problem in selected for tag in problem.tags}),
            focus_tags=sorted({tag for problem in selected for tag in problem.tags})[:8],
            target_ovr=900 + index * 250,
            is_demo=False,
            is_public=True,
            owner_user_id="aiflow-market",
            modules=modules,
        )
        courses.append(course)
        listings.append(
            _listing(
                listing_id=f"{LISTING_PREFIX}-course-{slug}",
                kind="course",
                title=title,
                description=description,
                problems=selected,
                grade_band=grade,
                difficulty=difficulty,
                estimated_minutes=module_count * 25,
                price_points=points,
                featured_rank=100 - index,
                asset_id=course_id,
                payload={"module_count": module_count, "recommended_days": module_count},
            )
        )

    for tier, (label, grade) in tier_labels.items():
        selected = _select_v3_by_tier(problems, tier)
        course_id = f"market-course-tier-{tier}-v3"
        title = f"난이도 {tier} · {label} 코스"
        modules = [
            CourseModule(
                id=f"{course_id}-m{module_index + 1}",
                type=CourseModuleType.problem_solve,
                title=f"{module_index + 1}단계 · 난이도 {tier}",
                description=f"난이도 {tier} 직접 출제 문제 5문항",
                position=module_index,
                estimated_minutes=25 + tier * 5,
                problem_ids=[problem.quest_id for problem in selected[module_index * 5 : module_index * 5 + 5]],
                question_count=5,
                pass_rate=80,
            )
            for module_index in range(2)
        ]
        course = CourseV2(
            id=course_id,
            title=title,
            description=f"난이도 {tier} 문제만 단계별로 학습하는 전용 코스",
            difficulty=f"난이도 {tier}",
            duration="2일",
            tags=sorted({tag for problem in selected for tag in problem.tags}),
            focus_tags=sorted({tag for problem in selected for tag in problem.tags})[:8],
            target_ovr=800 + tier * 400,
            is_demo=False,
            is_public=True,
            owner_user_id="aiflow-market",
            modules=modules,
        )
        courses.append(course)
        listings.append(
            _listing(
                listing_id=f"{LISTING_PREFIX}-course-tier-{tier}-v3",
                kind="course",
                title=title,
                description=course.description,
                problems=selected,
                grade_band=grade,
                difficulty=f"난이도 {tier}",
                estimated_minutes=(25 + tier * 5) * 2,
                price_points=1000 + tier * 200,
                featured_rank=115 - tier,
                asset_id=course_id,
                payload={
                    "module_count": 2,
                    "recommended_days": 2,
                    "source_batch": "marketplace-original-v3",
                    "difficulty_tier": tier,
                },
            )
        )

    for tier, (label, grade) in tier_labels.items():
        selected = _select_v4_by_tier(problems, tier)
        course_id = f"market-course-tier-{tier}-v4"
        title = f"난이도 {tier} · {label} 코스 · 확장"
        modules = [
            CourseModule(
                id=f"{course_id}-m{module_index + 1}",
                type=CourseModuleType.problem_solve,
                title=f"{module_index + 1}단계 · v4 난이도 {tier}",
                description=f"v4 난이도 {tier} 직접 출제 문제 5문항",
                position=module_index,
                estimated_minutes=25 + tier * 5,
                problem_ids=[problem.quest_id for problem in selected[module_index * 5 : module_index * 5 + 5]],
                question_count=5,
                pass_rate=80,
            )
            for module_index in range(2)
        ]
        course = CourseV2(
            id=course_id,
            title=title,
            description=f"v4 난이도 {tier} 문제만 단계별로 학습하는 확장 코스",
            difficulty=f"난이도 {tier}",
            duration="2일",
            tags=sorted({tag for problem in selected for tag in problem.tags}),
            focus_tags=sorted({tag for problem in selected for tag in problem.tags})[:8],
            target_ovr=900 + tier * 400,
            is_demo=False,
            is_public=True,
            owner_user_id="aiflow-market",
            modules=modules,
        )
        courses.append(course)
        listings.append(
            _listing(
                listing_id=f"{LISTING_PREFIX}-course-tier-{tier}-v4",
                kind="course",
                title=title,
                description=course.description,
                problems=selected,
                grade_band=grade,
                difficulty=f"난이도 {tier}",
                estimated_minutes=(25 + tier * 5) * 2,
                price_points=1100 + tier * 200,
                featured_rank=109 - tier,
                asset_id=course_id,
                payload={
                    "module_count": 2,
                    "recommended_days": 2,
                    "source_batch": "marketplace-original-v4",
                    "difficulty_tier": tier,
                },
            )
        )

    for tier, (label, grade) in tier_labels.items():
        selected = _select_v5_by_tier(problems, tier)
        course_id = f"market-course-tier-{tier}-v5"
        title = f"난이도 {tier} · {label} 코스 · 유형 확장"
        modules = [
            CourseModule(
                id=f"{course_id}-m{module_index + 1}",
                type=CourseModuleType.problem_solve,
                title=f"{module_index + 1}단계 · v5 난이도 {tier}",
                description=f"v5 난이도 {tier} 직접 출제 문제 5문항",
                position=module_index,
                estimated_minutes=25 + tier * 5,
                problem_ids=[problem.quest_id for problem in selected[module_index * 5 : module_index * 5 + 5]],
                question_count=5,
                pass_rate=80,
            )
            for module_index in range(2)
        ]
        course = CourseV2(
            id=course_id,
            title=title,
            description=f"v5 난이도 {tier} 문제만 단계별로 학습하는 유형 확장 코스",
            difficulty=f"난이도 {tier}",
            duration="2일",
            tags=sorted({tag for problem in selected for tag in problem.tags}),
            focus_tags=sorted({tag for problem in selected for tag in problem.tags})[:8],
            target_ovr=1000 + tier * 400,
            is_demo=False,
            is_public=True,
            owner_user_id="aiflow-market",
            modules=modules,
        )
        courses.append(course)
        listings.append(
            _listing(
                listing_id=f"{LISTING_PREFIX}-course-tier-{tier}-v5",
                kind="course",
                title=title,
                description=course.description,
                problems=selected,
                grade_band=grade,
                difficulty=f"난이도 {tier}",
                estimated_minutes=(25 + tier * 5) * 2,
                price_points=1200 + tier * 200,
                featured_rank=103 - tier,
                asset_id=course_id,
                payload={
                    "module_count": 2,
                    "recommended_days": 2,
                    "source_batch": "marketplace-original-v5",
                    "difficulty_tier": tier,
                },
            )
        )

    v6_set_specs = [
        ("v6-exponent-law", "난이도 1 · 지수법칙 5", "같은 밑의 거듭제곱 곱셈", ("지수법칙",), "고1-2", "난이도 1"),
        ("v6-arithmetic-middle", "난이도 1 · 등차중항 5", "양옆 항의 평균으로 가운데 항 계산", ("등차수열",), "고1-2", "난이도 1"),
        ("v6-line-slope", "난이도 2 · 직선 기울기 5", "두 점의 좌표 변화량과 기울기", ("두점을지나는직선",), "고1", "난이도 2"),
        ("v6-double-root", "난이도 2 · 중근 판별식 5", "판별식 0으로 상수항 복원", ("판별식과근의개수",), "고1", "난이도 2"),
        ("v6-diameter-circle", "난이도 3 · 지름으로 정한 원 5", "지름의 양 끝점과 반지름 제곱", ("거리공식",), "고1", "난이도 3"),
        ("v6-arithmetic-count", "난이도 3 · 등차수열 항수 5", "수열의 합에서 자연수 항수 복원", ("등차수열의합",), "고1-2", "난이도 3"),
        ("v6-cubic-critical", "난이도 4 · 삼차함수 극점 5", "도함수 영점으로 매개변수 복원", ("도함수의부호",), "고2-3", "난이도 4"),
        ("v6-integral-interval", "난이도 4 · 정적분 구간 5", "정적분값에서 양의 상한 복원", ("정적분과넓이",), "고2-3", "난이도 4"),
        ("v6-exponential-distance", "난이도 5 · 지수그래프 거리 5", "그래프 위 두 점과 수직선 거리", ("지수함수의그래프",), "고2-3", "난이도 5"),
        ("v6-quadratic-composition", "난이도 5 · 합성함수 실근 5", "이차함수 합성방정식의 네 근", ("정의역",), "고1-2", "난이도 5"),
    ]
    _append_difficulty_batch_inventory(
        listings=listings,
        courses=courses,
        problems=problems,
        version=6,
        set_specs=v6_set_specs,
        title_suffix=" · 종합 확장",
        set_price=210,
        exam_price=360,
        course_price_base=1300,
        target_ovr_base=1100,
        set_rank_base=50,
        exam_rank_base=102,
        course_rank_base=97,
    )
    v7_set_specs = [
        ("v7-imaginary-unit", "난이도 1 · 허수 단위 5", "거듭제곱의 4주기 계산", ("허수단위",), "고1", "난이도 1"),
        ("v7-matrix-entry", "난이도 1 · 행렬 성분 5", "대응 성분의 덧셈", ("행렬의덧셈",), "고1", "난이도 1"),
        ("v7-line-intercept", "난이도 2 · 직선 절편 5", "기울기와 한 점으로 y절편 복원", ("직선의방정식",), "고1", "난이도 2"),
        ("v7-geometric-ratio", "난이도 2 · 등비수열 공비 5", "첫째항과 셋째항에서 양의 공비 계산", ("등비수열의일반항",), "고2", "난이도 2"),
        ("v7-circle-center", "난이도 3 · 원의 중심 5", "일반형 계수에서 중심 좌표 복원", ("일반형을표준형으로",), "고1", "난이도 3"),
        ("v7-derivative-slope", "난이도 3 · 접선 기울기 5", "이차함수의 도함수값 계산", ("미분계수",), "고2", "난이도 3"),
        ("v7-sigma-parameter", "난이도 4 · 시그마 계수 5", "합의 선형성으로 미정계수 복원", ("시그마의성질",), "고2", "난이도 4"),
        ("v7-quadratic-minimum", "난이도 4 · 최솟값 매개변수 5", "완전제곱과 양수 조건", ("완성제곱법",), "고1-2", "난이도 4"),
        ("v7-rational-inverse", "난이도 5 · 유리함수 역함수 5", "역함숫값을 원래 함수 방정식으로 변환", ("역함수",), "고1-2", "난이도 5"),
        ("v7-tangent-length", "난이도 5 · 원의 접선 길이 5", "외부점에서 그은 두 접선의 길이", ("점과직선사이의거리",), "고1-2", "난이도 5"),
    ]
    _append_difficulty_batch_inventory(
        listings=listings,
        courses=courses,
        problems=problems,
        version=7,
        set_specs=v7_set_specs,
        title_suffix=" · 역량 확장",
        set_price=230,
        exam_price=380,
        course_price_base=1400,
        target_ovr_base=1200,
        set_rank_base=40,
        exam_rank_base=96,
        course_rank_base=91,
    )
    v8_set_specs = [
        ("v8-exponent", "난이도 1 · 지수 병렬형 5", "새 수치의 지수법칙", ("지수법칙",), "고1-2", "난이도 1"),
        ("v8-arithmetic-middle", "난이도 1 · 등차중항 병렬형 5", "첫째항과 다섯째항의 가운데 항", ("등차수열",), "고1-2", "난이도 1"),
        ("v8-line-slope", "난이도 2 · 직선 기울기 병렬형 5", "새 좌표의 변화량", ("두점을지나는직선",), "고1", "난이도 2"),
        ("v8-double-root", "난이도 2 · 중근 병렬형 5", "하나의 실근과 판별식", ("판별식과근의개수",), "고1", "난이도 2"),
        ("v8-square-sum", "난이도 3 · 제곱합 병렬형 5", "자연수 제곱합 공식", ("자연수의거듭제곱의합",), "고2", "난이도 3"),
        ("v8-circle-center", "난이도 3 · 원의 중심 병렬형 5", "일반형 중심 좌표합", ("일반형을표준형으로",), "고1", "난이도 3"),
        ("v8-integral", "난이도 4 · 정적분 계수 병렬형 5", "정적분 조건의 미정계수", ("정적분의선형성",), "고2-3", "난이도 4"),
        ("v8-minimum", "난이도 4 · 최솟값 병렬형 5", "완전제곱과 양수 조건", ("완성제곱법",), "고1-2", "난이도 4"),
        ("v8-exponential-distance", "난이도 5 · 지수거리 병렬형 5", "지수그래프와 수직선 거리", ("지수함수의그래프",), "고2-3", "난이도 5"),
        ("v8-continuity", "난이도 5 · 연속성 병렬형 5", "제거가능 불연속의 상수 복원", ("극한의성질",), "고2-3", "난이도 5"),
    ]
    _append_difficulty_batch_inventory(listings=listings, courses=courses, problems=problems, version=8, set_specs=v8_set_specs, title_suffix=" · 병렬 확장", set_price=250, exam_price=400, course_price_base=1500, target_ovr_base=1300, set_rank_base=30, exam_rank_base=90, course_rank_base=85)
    v9_set_specs = [
        ("v9-polynomial-value", "난이도 1 · 일차다항식 대입 5", "새 계수와 대입값의 다항식 계산", ("다항식의연산",), "고1", "난이도 1"),
        ("v9-factorial-ratio", "난이도 1 · 팩토리얼 비 5", "연속한 세 자연수로 팩토리얼 약분", ("팩토리얼",), "고1", "난이도 1"),
        ("v9-root-square-sum", "난이도 2 · 두 근의 제곱합 5", "근의 합과 곱으로 제곱합 계산", ("근과계수의관계",), "고1", "난이도 2"),
        ("v9-log-equation", "난이도 2 · 로그방정식 적용 5", "진수 조건과 로그 정의로 해 계산", ("로그방정식",), "고2", "난이도 2"),
        ("v9-cubic-coefficients", "난이도 3 · 삼차식 계수 연결 5", "세 영점과 삼차다항식 계수의 관계", ("인수정리",), "고1", "난이도 3"),
        ("v9-rational-asymptotes", "난이도 3 · 유리함수 점근선 5", "일차분수함수의 두 점근선 교점", ("점근선",), "고1-2", "난이도 3"),
        ("v9-log-sequence", "난이도 4 · 로그 수열 변환 5", "등비수열을 로그로 바꾼 등차수열의 합", ("등비수열",), "고2", "난이도 4"),
        ("v9-circle-chord", "난이도 4 · 원과 직선의 현 5", "교점 좌표 차와 현의 길이", ("원의방정식",), "고1-2", "난이도 4"),
        ("v9-rational-involution", "난이도 5 · 일차분수 자기역함수 5", "합성 항등식과 고정점의 근의 합", ("역함수",), "고1-2", "난이도 5"),
        ("v9-circle-tangent", "난이도 5 · 원의 접선 기울기 5", "거리 조건으로 두 접선의 기울기 합 계산", ("점과직선사이의거리",), "고1-2", "난이도 5"),
    ]
    _append_difficulty_batch_inventory(listings=listings, courses=courses, problems=problems, version=9, set_specs=v9_set_specs, title_suffix=" · 원리 확장", set_price=270, exam_price=420, course_price_base=1600, target_ovr_base=1400, set_rank_base=20, exam_rank_base=84, course_rank_base=79)
    v10_set_specs = [
        ("v10-imaginary-power", "난이도 1 · 허수 거듭제곱 5", "4주기로 계산하는 새 허수 지수", ("허수단위",), "고1", "난이도 1"),
        ("v10-arithmetic-term", "난이도 1 · 등차수열 특정항 5", "첫째항과 공차로 일반항 계산", ("등차수열",), "고1-2", "난이도 1"),
        ("v10-remainder-parameter", "난이도 2 · 나머지정리 계수 5", "나머지 조건으로 미정계수 복원", ("나머지정리",), "고1", "난이도 2"),
        ("v10-geometric-term", "난이도 2 · 등비수열 항 연결 5", "둘째항과 다섯째항으로 넷째항 계산", ("등비수열의일반항",), "고2", "난이도 2"),
        ("v10-exponential-intersection", "난이도 3 · 지수그래프 교점 5", "밑을 통일해 교점 좌표 계산", ("지수함수의그래프",), "고2", "난이도 3"),
        ("v10-quadratic-shift", "난이도 3 · 이차함수 이동 5", "입력 변화와 꼭짓점 평행이동", ("이차함수의평행이동",), "고1-2", "난이도 3"),
        ("v10-integral-parameter", "난이도 4 · 정적분 함수 계수 5", "함숫값 조건과 정적분의 매개변수", ("미적분의기본정리",), "고2-3", "난이도 4"),
        ("v10-quadratic-intercepts", "난이도 4 · 최솟값과 절편 5", "최솟값 조건과 두 근의 합 연결", ("이차함수의최대최소",), "고1-2", "난이도 4"),
        ("v10-log-root-product", "난이도 5 · 로그 실근의 곱 5", "진수 구간과 이차방정식의 근의 곱", ("로그방정식",), "고2-3", "난이도 5"),
        ("v10-external-tangents", "난이도 5 · 외부점 접선 5", "외부점을 지나는 두 접선의 기울기 합", ("점과직선사이의거리",), "고1-2", "난이도 5"),
    ]
    _append_difficulty_batch_inventory(listings=listings, courses=courses, problems=problems, version=10, set_specs=v10_set_specs, title_suffix=" · 개념 연결", set_price=290, exam_price=440, course_price_base=1700, target_ovr_base=1500, set_rank_base=10, exam_rank_base=78, course_rank_base=73)
    v11_set_specs = [
        ("v11-log-value", "난이도 1 · 로그값 계산 5", "로그와 거듭제곱의 역관계", ("로그의정의",), "고2", "난이도 1"),
        ("v11-permutation", "난이도 1 · 순열 기본 5", "순서를 고려한 두 자리 나열", ("순열의수",), "고1", "난이도 1"),
        ("v11-line-intercept", "난이도 2 · 직선 y절편 5", "기울기와 한 점으로 절편 복원", ("기울기",), "고1", "난이도 2"),
        ("v11-arithmetic-sum", "난이도 2 · 등차수열 합 5", "마지막 항과 합 공식 계산", ("등차수열의합",), "고1-2", "난이도 2"),
        ("v11-circle-center", "난이도 3 · 원의 중심식 5", "일반형에서 중심 좌표식 계산", ("원의일반형",), "고1", "난이도 3"),
        ("v11-cubic-slope", "난이도 3 · 삼차함수 접선 5", "도함수로 삼차함수 접선 기울기 계산", ("도함수",), "고2-3", "난이도 3"),
        ("v11-sigma-parameter", "난이도 4 · 시그마 미정계수 5", "합의 선형성과 자연수 합", ("시그마의성질",), "고2", "난이도 4"),
        ("v11-continuity", "난이도 4 · 빠진 점의 연속 5", "인수분해와 연속 조건으로 세 상수 연결", ("함수의연속",), "고2-3", "난이도 4"),
        ("v11-rational-inverse", "난이도 5 · 역함수와 점근선 5", "일차분수함수의 원상과 점근선 교점", ("역함수",), "고1-2", "난이도 5"),
        ("v11-tangent-length", "난이도 5 · 이동된 원의 접선 5", "외부점에서 그은 두 접선 길이", ("두점사이의거리",), "고1-2", "난이도 5"),
    ]
    _append_difficulty_batch_inventory(listings=listings, courses=courses, problems=problems, version=11, set_specs=v11_set_specs, title_suffix=" · 유형 확장", set_price=310, exam_price=460, course_price_base=1800, target_ovr_base=1600, set_rank_base=0, exam_rank_base=72, course_rank_base=67)
    v12_set_specs = [
        ("v12-set-intersection", "난이도 1 · 집합 원소 수 5", "합집합과 교집합 원소 수 공식", ("집합의연산",), "고1", "난이도 1"),
        ("v12-combination", "난이도 1 · 두 명 조합 5", "순서 없는 대표 두 명 선택", ("조합의수",), "고1", "난이도 1"),
        ("v12-linear-inverse", "난이도 2 · 일차함수 역함숫값 5", "원래 함수 방정식으로 원상 계산", ("역함수",), "고1", "난이도 2"),
        ("v12-circle-radius", "난이도 2 · 원의 반지름 5", "일반형을 표준형으로 바꾸어 반지름 복원", ("원의일반형",), "고1", "난이도 2"),
        ("v12-recurrence-sum", "난이도 3 · 점화수열 합 5", "점화식으로 첫 다섯 항 계산", ("일반항",), "고1-2", "난이도 3"),
        ("v12-rational-asymptote", "난이도 3 · 유리함수 점근선식 5", "두 점근선 교점의 좌표식", ("점근선",), "고1-2", "난이도 3"),
        ("v12-circle-chord", "난이도 4 · 원의 현 제곱 5", "원과 직선 교점의 거리 계산", ("원의방정식",), "고1-2", "난이도 4"),
        ("v12-integral-function", "난이도 4 · 적분함수 매개변수 5", "정적분 함숫값으로 계수 복원", ("미적분의기본정리",), "고2-3", "난이도 4"),
        ("v12-piecewise-composition", "난이도 5 · 구간별 합성함수 5", "연속 조건과 합성방정식의 구간 분류", ("함수의연속",), "고2-3", "난이도 5"),
        ("v12-cubic-area", "난이도 5 · 삼차함수 넓이 5", "도함수 복원과 정적분 넓이", ("정적분과넓이",), "고2-3", "난이도 5"),
    ]
    _append_difficulty_batch_inventory(listings=listings, courses=courses, problems=problems, version=12, set_specs=v12_set_specs, title_suffix=" · 실전 연결", set_price=330, exam_price=480, course_price_base=1900, target_ovr_base=1700, set_rank_base=5, exam_rank_base=66, course_rank_base=61)
    v13_set_specs = [
        ("v13-monomial-product", "난이도 1 · 단항식 곱 5", "계수 곱과 지수법칙 계산", ("다항식의연산",), "고1", "난이도 1"),
        ("v13-factorial-ratio", "난이도 1 · 팩토리얼 두 항 비 5", "연속한 두 자연수로 팩토리얼 약분", ("팩토리얼",), "고1", "난이도 1"),
        ("v13-line-slope", "난이도 2 · 두 점의 기울기 5", "좌표 변화량으로 직선 기울기 계산", ("두점을지나는직선",), "고1", "난이도 2"),
        ("v13-double-root", "난이도 2 · 중근 상수항 5", "판별식 0으로 상수항 복원", ("판별식과근의개수",), "고1", "난이도 2"),
        ("v13-diameter-radius", "난이도 3 · 지름과 반지름 5", "두 끝점 거리에서 반지름 제곱 계산", ("거리공식",), "고1", "난이도 3"),
        ("v13-arithmetic-count", "난이도 3 · 등차수열 항수 5", "수열의 합을 이차방정식으로 변환", ("등차수열의합",), "고1-2", "난이도 3"),
        ("v13-tangent-parameter", "난이도 4 · 삼차함수 접선 계수 5", "접선 기울기로 미정계수 복원", ("접선의방정식",), "고2-3", "난이도 4"),
        ("v13-integral-upper", "난이도 4 · 정적분 양의 상한 5", "정적분값에서 양의 상한 선택", ("정적분의선형성",), "고2-3", "난이도 4"),
        ("v13-exponential-distance", "난이도 5 · 지수그래프 수직거리 5", "두 그래프점과 수직선 거리의 곱", ("지수함수의그래프",), "고2-3", "난이도 5"),
        ("v13-removable-continuity", "난이도 5 · 연속함수 제곱합 5", "빠진 점의 연속 조건과 세 상수", ("극한의성질",), "고2-3", "난이도 5"),
    ]
    _append_difficulty_batch_inventory(listings=listings, courses=courses, problems=problems, version=13, set_specs=v13_set_specs, title_suffix=" · 수리 확장", set_price=350, exam_price=500, course_price_base=2000, target_ovr_base=1800, set_rank_base=3, exam_rank_base=60, course_rank_base=55)
    v14_set_specs = [
        ("v14-remainder", "난이도 1 · 이차식 나머지 5", "나머지정리로 직접 함숫값 계산", ("나머지정리",), "고1", "난이도 1"),
        ("v14-matrix-trace", "난이도 1 · 행렬 대각합 5", "행렬 합의 두 대각 성분 계산", ("행렬의덧셈",), "고1", "난이도 1"),
        ("v14-exponent-equation", "난이도 2 · 같은 밑 지수방정식 5", "지수 일대일성으로 해 계산", ("지수방정식",), "고2", "난이도 2"),
        ("v14-other-root", "난이도 2 · 다른 한 근 5", "근의 합으로 남은 근 복원", ("이차방정식",), "고1", "난이도 2"),
        ("v14-cubic-coefficients", "난이도 3 · 삼차식 계수차 5", "세 영점으로 삼차다항식 계수 계산", ("고차식인수분해",), "고1", "난이도 3"),
        ("v14-removable-function", "난이도 3 · 연속함수 합성값 5", "빠진 점을 채우고 새 함숫값 계산", ("함수의극한",), "고2-3", "난이도 3"),
        ("v14-log-sequence", "난이도 4 · 로그 수열 다섯 항 5", "등비수열을 등차수열로 변환", ("등비수열",), "고2", "난이도 4"),
        ("v14-parabola-area", "난이도 4 · 포물선과 수평선 넓이 5", "대칭 정적분으로 둘러싸인 넓이 계산", ("두곡선사이의넓이",), "고2-3", "난이도 4"),
        ("v14-log-root-product", "난이도 5 · 로그방정식 근의 곱 5", "진수 구간과 이차방정식 연결", ("로그방정식",), "고2-3", "난이도 5"),
        ("v14-circle-tangent", "난이도 5 · 외부점 접선 기울기 5", "점과 직선 거리로 기울기 합 계산", ("점과직선사이의거리",), "고1-2", "난이도 5"),
    ]
    _append_difficulty_batch_inventory(listings=listings, courses=courses, problems=problems, version=14, set_specs=v14_set_specs, title_suffix=" · 심화 연결", set_price=370, exam_price=520, course_price_base=2100, target_ovr_base=1900, set_rank_base=2, exam_rank_base=54, course_rank_base=49)
    v15_set_specs = [
        ("v15-factorial-ratio", "난이도 1 · 팩토리얼 네 항 비 5", "연속한 네 자연수로 팩토리얼 약분", ("팩토리얼",), "고1", "난이도 1"),
        ("v15-arithmetic-middle", "난이도 1 · 등차수열 가운데 항 5", "두 항의 평균으로 가운데 항 계산", ("등차수열",), "고1-2", "난이도 1"),
        ("v15-cubic-remainder", "난이도 2 · 삼차식 나머지 계수 5", "나머지정리와 미정계수법 연결", ("나머지정리",), "고1", "난이도 2"),
        ("v15-log-equation", "난이도 2 · 로그방정식 해 5", "진수 조건과 로그 정의로 해 계산", ("로그방정식",), "고2", "난이도 2"),
        ("v15-cube-sum", "난이도 3 · 자연수 세제곱합 5", "세제곱합 공식으로 시그마 계산", ("자연수의거듭제곱의합",), "고2", "난이도 3"),
        ("v15-circle-center", "난이도 3 · 원의 중심 좌표식 5", "원의 일반형을 표준형으로 변환", ("원의일반형",), "고1", "난이도 3"),
        ("v15-sigma-coefficient", "난이도 4 · 시그마 계수 복원 5", "합의 선형성으로 미정계수 계산", ("시그마의성질",), "고2", "난이도 4"),
        ("v15-integral-coefficient", "난이도 4 · 정적분 계수 복원 5", "정적분의 선형성으로 미정계수 계산", ("정적분의선형성",), "고2-3", "난이도 4"),
        ("v15-rational-inverse", "난이도 5 · 유리함수 역함수 5", "합성 조건과 고정점의 근 관계 연결", ("역함수",), "고2-3", "난이도 5"),
        ("v15-circle-tangent", "난이도 5 · 원의 외부 접선 5", "중심과 외부점 거리로 접선 길이 계산", ("두점사이의거리",), "고1-2", "난이도 5"),
    ]
    _append_difficulty_batch_inventory(listings=listings, courses=courses, problems=problems, version=15, set_specs=v15_set_specs, title_suffix=" · 구조 통합", set_price=390, exam_price=540, course_price_base=2200, target_ovr_base=2000, set_rank_base=1, exam_rank_base=48, course_rank_base=43)
    v16_set_specs = [
        ("v16-matrix-scalar", "난이도 1 · 행렬 스칼라곱 5", "스칼라곱 뒤 대각 성분의 합 계산", ("스칼라곱",), "고1", "난이도 1"),
        ("v16-midpoint", "난이도 1 · 두 점의 중점 5", "중점 좌표와 좌표합 계산", ("중점",), "고1", "난이도 1"),
        ("v16-perpendicular-slope", "난이도 2 · 수직 직선 기울기 5", "기울기 곱으로 미정계수 계산", ("수직조건",), "고1", "난이도 2"),
        ("v16-geometric-mean", "난이도 2 · 양의 등비중항 5", "두 항의 곱에서 양의 중항 복원", ("등비중항",), "고2", "난이도 2"),
        ("v16-set-difference", "난이도 3 · 집합 차집합 원소 수 5", "합집합과 교집합으로 차집합 계산", ("집합의연산",), "고1", "난이도 3"),
        ("v16-linear-inverse", "난이도 3 · 일차함수 역함숫값 5", "역함수 식을 세워 함숫값 계산", ("역함수구하기",), "고1", "난이도 3"),
        ("v16-tangent-point", "난이도 4 · 외부점을 지나는 접선 5", "도함수와 외부점 조건으로 계수 복원", ("접선방정식구하기",), "고2-3", "난이도 4"),
        ("v16-integral-function", "난이도 4 · 적분함수 연립조건 5", "함숫값과 도함숫값으로 두 계수 복원", ("미적분의기본정리",), "고2-3", "난이도 4"),
        ("v16-parabola-tangents", "난이도 5 · 포물선의 두 접선 5", "판별식으로 두 접선 기울기 계산", ("이차방정식의판별식",), "고1-2", "난이도 5"),
        ("v16-cubic-extrema", "난이도 5 · 삼차함수 극값의 곱 5", "도함수와 차의 제곱으로 상수 복원", ("극댓값",), "고2-3", "난이도 5"),
    ]
    _append_difficulty_batch_inventory(listings=listings, courses=courses, problems=problems, version=16, set_specs=v16_set_specs, title_suffix=" · 응용 전개", set_price=410, exam_price=560, course_price_base=2300, target_ovr_base=2100, set_rank_base=0, exam_rank_base=42, course_rank_base=37)
    v17_set_specs = [
        ("v17-permutation-officers", "난이도 1 · 임원 순열 5", "서로 다른 두 역할을 순서 있게 선택", ("순열의수",), "고1", "난이도 1"),
        ("v17-complement", "난이도 1 · 여집합 원소 수 5", "전체집합에서 부분집합 원소 수 제외", ("여집합",), "고1", "난이도 1"),
        ("v17-parallel-slope", "난이도 2 · 평행 직선 기울기 5", "평행 조건으로 미정계수 계산", ("평행조건",), "고1", "난이도 2"),
        ("v17-exponent-equation", "난이도 2 · 밑 변환 지수방정식 5", "밑을 통일해 지수 일차방정식 풀이", ("지수방정식",), "고2", "난이도 2"),
        ("v17-arithmetic-sum", "난이도 3 · 양 끝항 등차수열 합 5", "첫째항과 끝항으로 수열의 합 계산", ("등차수열의합",), "고2", "난이도 3"),
        ("v17-tangent-circle", "난이도 3 · 접하는 원의 반지름 5", "중심과 접선 거리로 반지름 제곱 계산", ("반지름",), "고1", "난이도 3"),
        ("v17-recurrence-difference", "난이도 4 · 점화수열 공차 5", "점화식과 첫 n항의 합으로 공차 복원", ("공차",), "고2", "난이도 4"),
        ("v17-quadratic-maximum", "난이도 4 · 이차함수 최댓값 계수 5", "완전제곱과 양수 조건으로 계수 복원", ("이차함수의최대최소",), "고1-2", "난이도 4"),
        ("v17-parabola-line-area", "난이도 5 · 포물선과 직선 넓이 5", "교점과 정적분 넓이로 계수 복원", ("두곡선사이의넓이",), "고2-3", "난이도 5"),
        ("v17-telescoping-sum", "난이도 5 · 부분분수 망원합 5", "연속항 소거와 인수분해로 자연수 복원", ("부분분수",), "고2-3", "난이도 5"),
    ]
    _append_difficulty_batch_inventory(listings=listings, courses=courses, problems=problems, version=17, set_specs=v17_set_specs, title_suffix=" · 개념 융합", set_price=430, exam_price=580, course_price_base=2400, target_ovr_base=2200, set_rank_base=-1, exam_rank_base=36, course_rank_base=31)
    return listings, courses


def _backup_sqlite(db_path: Path) -> Path:
    """필요 변수는 대상 SQLite DB다. 작동 원리는 최초 마켓 시드 전에 WAL을 포함한 일관된 복구 사본을 한 번 만든다."""
    backup_path = db_path.with_name(f"{db_path.name}.bak_{BATCH_ID}")
    if backup_path.exists():
        return backup_path
    with sqlite3.connect(db_path) as source, sqlite3.connect(backup_path) as target:
        source.backup(target)
    return backup_path


def _upsert_sqlite_courses(db_path: Path, courses: list[CourseV2]) -> int:
    """필요 변수는 로컬 DB와 공개 CourseV2 목록이다. 작동 원리는 기존 테스트 데이터를 보존하며 마켓 소유 ID만 UPSERT하는 것이다."""
    now = int(time.time())
    with sqlite3.connect(db_path) as connection:
        for course in courses:
            payload = course.model_dump(mode="json")
            connection.execute(
                """
                INSERT INTO course_v2 (
                    id, owner_user_id, access_academy_id, access_group_id,
                    title, description, difficulty, duration, tags, focus_tags,
                    target_ovr, textbook_id, textbook_pages, is_demo, is_public,
                    modules_json, pass_policy_json, flow_policy_json,
                    challenge_policy_json, schedule_policy_json,
                    runtime_flags_json, curriculum_settings_json,
                    challenge_settings_json, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    title=excluded.title, description=excluded.description,
                    difficulty=excluded.difficulty, duration=excluded.duration,
                    tags=excluded.tags, focus_tags=excluded.focus_tags,
                    target_ovr=excluded.target_ovr, is_public=excluded.is_public,
                    modules_json=excluded.modules_json,
                    pass_policy_json=excluded.pass_policy_json,
                    flow_policy_json=excluded.flow_policy_json,
                    challenge_policy_json=excluded.challenge_policy_json,
                    schedule_policy_json=excluded.schedule_policy_json,
                    runtime_flags_json=excluded.runtime_flags_json,
                    updated_at=excluded.updated_at
                """,
                (
                    course.id,
                    course.owner_user_id,
                    course.access_academy_id,
                    course.access_group_id,
                    course.title,
                    course.description,
                    course.difficulty,
                    course.duration,
                    json.dumps(course.tags, ensure_ascii=False),
                    json.dumps(course.focus_tags, ensure_ascii=False),
                    course.target_ovr,
                    course.textbook_id,
                    course.textbook_pages,
                    0,
                    1,
                    json.dumps(payload["modules"], ensure_ascii=False),
                    json.dumps(payload["pass_policy"], ensure_ascii=False),
                    json.dumps(payload["flow_policy"], ensure_ascii=False),
                    json.dumps(payload["challenge_policy"], ensure_ascii=False),
                    json.dumps(payload["schedule_policy"], ensure_ascii=False),
                    json.dumps(payload["runtime_flags"], ensure_ascii=False),
                    json.dumps(payload["curriculum_settings"], ensure_ascii=False),
                    json.dumps(payload["challenge_settings"], ensure_ascii=False),
                    course.created_at or now,
                    now,
                ),
            )
        connection.commit()
    return len(courses)


def _upsert_postgres_courses(courses: list[CourseV2]) -> int:
    """필요 변수는 공개 CourseV2 목록이다. 작동 원리는 운영 공유 풀의 UPSERT 경로로 마켓 소유 코스만 갱신하는 것이다."""
    from domain.course import v2_repository

    for course in courses:
        v2_repository.update_course_v2(course)
    return len(courses)


def _upsert_postgres_problems(db_path: Path, problem_ids: list[str]) -> int:
    """필요 변수는 로컬 원본 DB와 신규 문제 ID다. 작동 원리는 생성 API 없이 검수된 전체 payload를 운영 문제 원장에 엄격 UPSERT하는 것이다."""
    os.environ["QUEST_DB_PATH"] = str(db_path)
    from storage import storage as quest_storage
    from storage.postgres_problem_store import postgres_problem_store

    quest_storage.DB_PATH = str(db_path)
    quests = quest_storage.get_quests_by_ids(problem_ids)
    if len(quests) != len(problem_ids):
        raise RuntimeError(f"PostgreSQL 동기화 원본 누락: {len(quests)}/{len(problem_ids)}")
    for quest in quests:
        postgres_problem_store.upsert_problem(quest, strict=True)
    return len(quests)


def seed_inventory(db_path: Path, *, backend: str, validate_only: bool) -> dict[str, Any]:
    """필요 변수는 문제 DB·마켓 백엔드·검증 모드다. 작동 원리는 초도 편성을 전수 검사하고 코스와 목록을 멱등 저장한 뒤 코너별 수량을 재조회한다."""
    db_path = db_path.resolve()
    problems = _load_curated_problems(db_path)
    listings, courses = build_inventory(problems)
    counts = {kind: sum(1 for item in listings if item["kind"] == kind) for kind in ("exam", "problem_set", "course")}
    if counts != {"exam": 85, "problem_set": 166, "course": 81}:
        raise RuntimeError(f"초도 목록 수량 불일치: {counts}")
    known_ids = {problem.quest_id for problem in problems}
    missing_ids = sorted({quest_id for item in listings for quest_id in item["problem_ids"] if quest_id not in known_ids})
    if missing_ids:
        raise RuntimeError(f"존재하지 않는 문제 참조: {missing_ids[:3]}")
    report: dict[str, Any] = {
        "batch_id": BATCH_ID,
        "backend": backend,
        "source_problems": len(problems),
        "validated_listings": len(listings),
        "corner_counts": counts,
        "validated_courses": len(courses),
    }
    if validate_only:
        return report

    os.environ["QUEST_DB_PATH"] = str(db_path)
    os.environ["MARKETPLACE_BACKEND"] = backend
    if backend == "sqlite":
        report["backup_path"] = str(_backup_sqlite(db_path))
        report["courses_upserted"] = _upsert_sqlite_courses(db_path, courses)
    else:
        report["problems_upserted"] = _upsert_postgres_problems(
            db_path,
            [problem.quest_id for problem in problems],
        )
        report["courses_upserted"] = _upsert_postgres_courses(courses)

    from domain.marketplace import repository

    report["listings_upserted"] = repository.upsert_listings(listings)
    readback = repository.list_all_published_for_audit()
    report["readback_total"] = len(readback)
    report["readback_corner_counts"] = {
        kind: sum(1 for item in readback if item.get("kind") == kind)
        for kind in ("exam", "problem_set", "course")
    }
    expected_ids = {item["id"] for item in listings}
    readback_ids = {str(item.get("id") or "") for item in readback}
    if not expected_ids.issubset(readback_ids):
        raise RuntimeError(f"마켓 재조회 누락: {sorted(expected_ids - readback_ids)}")
    return report


def main() -> None:
    """필요 변수는 DB 경로·백엔드·검증 옵션이다. 작동 원리는 UTF-8 JSON 보고서로 반복 생산 결과를 출력하는 것이다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--backend", choices=("sqlite", "postgres"), default="sqlite")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    report = seed_inventory(args.db, backend=args.backend, validate_only=args.validate_only)
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
