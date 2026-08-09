"""Vercel에서 Supabase OCR 작업 큐만 제공하는 경량 FastAPI 진입점."""
from __future__ import annotations

import copy
import ast
import json
import hashlib
import hmac
import math
import os
import re
import secrets
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from datetime import date, datetime, timedelta, timezone
from typing import Any

import jwt
from fastapi import Depends, FastAPI, Header, HTTPException, Request, status
from fastapi.concurrency import run_in_threadpool
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field

MAX_JOB_BYTES = int(os.getenv("OCR_QUEUE_MAX_JOB_BYTES", "4000000"))
VISIBLE_COLUMNS = "id,status,result,error,created_at,updated_at,expires_at"
USER_COLUMNS = "user_id,username,name,grade,track,subject,school,profile_image,email,role,created_at"
USERNAME_RE = re.compile(r"^[A-Za-z0-9]{4,16}$")
PASSWORD_RE = re.compile(r"^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{8,20}$")
EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
NAME_RE = re.compile(r"^[가-힣A-Za-z0-9 ]{1,20}$")


def _build_marketplace_catalog() -> tuple[dict[str, Any], ...]:
    """필요 변수: 시험지 85개·문제세트 166개·코스 81개 규칙. 작동 원리: Vercel 시작 시 전체 332개 재고를 한 번만 생성해 검색 요청마다 DB를 조회하지 않는다."""
    items: list[dict[str, Any]] = []
    grade_by_tier = {
        1: "고1",
        2: "고1-2",
        3: "고1-2",
        4: "고2-3",
        5: "고2-3",
    }
    tier_labels = {
        1: "기본기",
        2: "개념 적용",
        3: "유형 연결",
        4: "응용 실전",
        5: "심화 사고력",
    }
    version_labels = {
        3: "기본",
        4: "확장",
        5: "유형 확장",
        6: "종합 확장",
        7: "역량 확장",
        8: "병렬 확장",
        9: "원리 확장",
        10: "개념 연결",
        11: "유형 확장",
        12: "실전 연결",
        13: "수리 확장",
        14: "심화 연결",
        15: "구조 통합",
        16: "응용 전개",
        17: "개념 융합",
    }

    exam_specs = (
        ("foundation-a", "공통수학 기초 진단 A", "고1 핵심 개념 10문항 진단", "고1", "입문"),
        ("foundation-b", "공통수학 기초 진단 B", "계산 정확도와 개념 연결 점검", "고1", "기본"),
        ("algebra", "대수 실전 미니 모의", "수열·지수·로그 10문항", "고2", "중급"),
        ("calculus", "미적분 I 실전 미니 모의", "극한·미분·적분 10문항", "고2-3", "중상"),
        ("challenge", "상위권 사고력 모의", "복합 조건 중심 10문항", "고2-3", "심화"),
        ("mixed", "전 범위 밸런스 모의", "난이도 1~5 혼합 10문항", "고1-3", "혼합"),
        ("common-plus", "공통수학 종합 진단 C", "복소수·행렬·직선 10문항", "고1", "중급"),
        ("algebra-plus", "대수 개념 진단 B", "나머지정리·로그·수열 10문항", "고1-2", "중급"),
        ("calculus-plus", "미적분 I 실전 모의 B", "접선과 정적분 중심 10문항", "고2-3", "중상"),
        ("mixed-plus", "전 범위 밸런스 모의 B", "전 범위 혼합 10문항", "고1-3", "혼합"),
    )
    for rank, (slug, title, description, grade, difficulty) in enumerate(exam_specs):
        items.append(
            {
                "id": f"market-v2-exam-{slug}",
                "kind": "exam",
                "title": title,
                "description": description,
                "grade_band": grade,
                "difficulty": difficulty,
                "item_count": 10,
                "price_points": 0,
                "problem_ids": [],
                "owned": False,
                "featured_rank": 199 - rank,
                "asset_id": "",
            }
        )
    for version, suffix in version_labels.items():
        for tier, label in tier_labels.items():
            items.append(
                {
                    "id": f"market-v2-exam-tier-{tier}-v{version}",
                    "kind": "exam",
                    "title": f"난이도 {tier} · {label} 진단 · {suffix}",
                    "description": f"난이도 {tier} 직접 출제 문제 10문항",
                    "grade_band": grade_by_tier[tier],
                    "difficulty": f"난이도 {tier}",
                    "item_count": 10,
                    "price_points": 0,
                    "problem_ids": [],
                    "owned": False,
                    "featured_rank": 185 - version * 3 - tier,
                    "asset_id": "",
                }
            )

    set_specs = (
        ("polynomial", "다항식 기본기 5", "다항식 계산부터 인수정리까지", "고1", "입문"),
        ("quadratic", "이차방정식 집중 5", "근과 계수, 판별식 핵심 연습", "고1", "기본"),
        ("sequence", "수열 패턴 훈련 5", "등차·등비수열과 합의 구조", "고2", "기본"),
        ("exponential", "지수·로그 스타터 5", "지수법칙과 방정식 첫 훈련", "고2", "기본"),
        ("function", "함수 그래프 해석 5", "합성함수와 그래프 이동 연습", "고1-2", "중급"),
        ("counting", "경우의 수 핵심 5", "순열·조합과 조건 분류", "고1", "중급"),
        ("derivative", "미분 개념 점검 5", "도함수와 극대·극소 판정", "고2-3", "중급"),
        ("integral", "적분 계산 점검 5", "정적분 계산과 넓이 해석", "고2-3", "중급"),
        ("complex", "복소수 계산 스타터 5", "허수 단위 거듭제곱 훈련", "고1", "입문"),
        ("matrix", "행렬 연산 스타터 5", "행렬 덧셈과 성분 계산", "고1", "입문"),
        ("remainder", "나머지정리 기본기 5", "대입으로 나머지 계산", "고1", "기본"),
        ("logarithm", "로그 정의 점검 5", "로그식을 지수식으로 변환", "고2", "기본"),
        ("line", "직선의 방정식 점검 5", "기울기와 절편 복원", "고1", "중급"),
        ("permutation", "순열 사고 훈련 5", "선후 조건과 대응 연습", "고1", "중급"),
        ("tangent", "접선 기울기 실전 5", "도함수로 미정계수 복원", "고2-3", "중상"),
        ("parabola-area", "포물선 넓이 실전 5", "정적분 넓이와 매개변수", "고2-3", "심화"),
    )
    for rank, (slug, title, description, grade, difficulty) in enumerate(set_specs):
        items.append(
            {
                "id": f"market-v2-set-{slug}",
                "kind": "problem_set",
                "title": title,
                "description": description,
                "grade_band": grade,
                "difficulty": difficulty,
                "item_count": 5,
                "price_points": 0,
                "problem_ids": [],
                "owned": False,
                "featured_rank": 198 - rank,
                "asset_id": "",
            }
        )
    set_topics = (
        ("다항식", 1),
        ("수열 기초", 1),
        ("방정식", 2),
        ("지수·로그", 2),
        ("함수", 3),
        ("좌표기하", 3),
        ("미분", 4),
        ("적분", 4),
        ("고난도 함수", 5),
        ("복합 사고력", 5),
    )
    for version, suffix in version_labels.items():
        for index, (topic, tier) in enumerate(set_topics):
            items.append(
                {
                    "id": f"market-v2-set-{version}-{index + 1}",
                    "kind": "problem_set",
                    "title": f"난이도 {tier} · {topic} 5 · {suffix}",
                    "description": f"{topic} 핵심 유형 5문항",
                    "grade_band": grade_by_tier[tier],
                    "difficulty": f"난이도 {tier}",
                    "item_count": 5,
                    "price_points": 0,
                    "problem_ids": [],
                    "owned": False,
                    "featured_rank": 180 - version * 3 - index,
                    "asset_id": "",
                }
            )

    base_courses = (
        ("foundation", "공통수학 기초 완성", "다항식부터 지수까지 4단계 코스", "고1-2", "입문", 20, 900),
        ("algebra", "대수 개념 연결", "방정식·수열·지수를 연결하는 3단계 코스", "고1-2", "중급", 15, 1200),
        ("calculus", "미적분 I 실전 루트", "미분과 적분을 연결하는 2단계 코스", "고2-3", "중상", 10, 1500),
        ("challenge", "상위권 복합 사고력", "복합 사고력을 단계별로 훈련하는 심화 코스", "고2-3", "심화", 20, 1800),
        ("geometry", "좌표기하 연결 코스", "원과 직선을 연결하는 2단계 코스", "고1", "중급", 10, 1100),
        ("mastery", "수학 전 범위 마스터 루트", "검수 문제로 구성한 5단계 종합 코스", "고1-3", "혼합", 25, 2200),
    )
    for rank, (slug, title, description, grade, difficulty, count, _price) in enumerate(base_courses):
        items.append(
            {
                "id": f"market-v2-course-{slug}",
                "kind": "course",
                "title": title,
                "description": description,
                "grade_band": grade,
                "difficulty": difficulty,
                "item_count": count,
                "price_points": 0,
                "problem_ids": [],
                "owned": False,
                "featured_rank": 200 - rank,
                "asset_id": f"market-course-{slug}-v1",
            }
        )

    course_tier_labels = {
        1: ("개념 시작", "고1"),
        2: ("기본 완성", "고1"),
        3: ("유형 훈련", "고1-2"),
        4: ("실전 심화", "고2-3"),
        5: ("최상위 도전", "고2-3"),
    }
    course_version_labels = {
        3: "",
        4: "확장",
        5: "유형 확장",
        6: "실전",
        7: "집중 훈련",
        8: "응용",
        9: "고난도",
        10: "실전 완성",
        11: "약점 보완",
        12: "속도 훈련",
        13: "정확도 훈련",
        14: "내신 대비",
        15: "모의 평가",
        16: "파이널",
        17: "마스터",
    }
    for version, suffix in course_version_labels.items():
        for tier, (label, grade) in course_tier_labels.items():
            title = f"난이도 {tier} · {label} 코스"
            if suffix:
                title = f"{title} · {suffix}"
            items.append(
                {
                    "id": f"market-v2-course-tier-{tier}-v{version}",
                    "kind": "course",
                    "title": title,
                    "description": f"난이도 {tier} 문제를 단계별로 학습하는 {suffix or '전용'} 코스",
                    "grade_band": grade,
                    "difficulty": f"난이도 {tier}",
                    "item_count": 10,
                    "price_points": 0,
                    "problem_ids": [],
                    "owned": False,
                    "featured_rank": 180 - version * 5 - tier,
                    "asset_id": f"market-course-tier-{tier}-v{version}",
                }
            )
    # 필요한 변수는 완성된 마켓 상품과 각 상품의 문항 수다.
    # 작동 원리: 시험지·문제세트에 결정적 문제 ID를 한 번 할당해 목록·상세·채점이
    # 같은 원장을 사용하게 하고, 시험지 asset ID도 실제 조회 가능한 ID로 맞춘다.
    for item in items:
        if item["kind"] not in {"exam", "problem_set"}:
            continue
        item_count = min(max(int(item.get("item_count") or 1), 1), 50)
        item["problem_ids"] = [
            f"{item['id']}-q{index + 1}" for index in range(item_count)
        ]
        if item["kind"] == "exam" and not str(item.get("asset_id") or "").strip():
            item["asset_id"] = item["id"]
    return tuple(items)


MARKETPLACE_CATALOG = _build_marketplace_catalog()


def _marketplace_topic_pool(listing: dict[str, Any]) -> tuple[str, ...]:
    """상품 제목·설명·ID에서 출제 단원을 결정해 선택 자료와 문제 내용을 일치시킨다."""
    text = " ".join(
        str(listing.get(key) or "") for key in ("id", "title", "description")
    ).lower()
    if "전 범위" in text or "mixed" in text or "복합" in text or "상위권" in text:
        return ("polynomial", "quadratic", "sequence", "function", "derivative", "integral")
    if "미적분" in text or "calculus" in text:
        return ("derivative", "tangent", "integral", "parabola_area")
    if "대수" in text or "algebra" in text:
        return ("sequence", "exponential", "logarithm", "remainder")
    if "지수·로그" in text:
        return ("exponential", "logarithm")
    rules = (
        (("다항식", "polynomial"), "polynomial"),
        (("이차방정식", "quadratic"), "quadratic"),
        (("수열", "sequence"), "sequence"),
        (("지수", "exponential"), "exponential"),
        (("로그", "logarithm"), "logarithm"),
        (("나머지", "remainder"), "remainder"),
        (("접선", "tangent"), "tangent"),
        (("미분", "derivative"), "derivative"),
        (("포물선", "parabola"), "parabola_area"),
        (("적분", "integral"), "integral"),
        (("합성함수", "함수", "function"), "function"),
        (("좌표기하", "coordinate"), "coordinate"),
        (("경우의 수", "counting"), "counting"),
        (("순열", "permutation"), "permutation"),
        (("복소수", "complex"), "complex"),
        (("행렬", "matrix"), "matrix"),
        (("직선", "line"), "line"),
        (("방정식",), "linear"),
    )
    for needles, topic in rules:
        if any(needle in text for needle in needles):
            return (topic,)
    return ("polynomial", "quadratic", "function", "sequence", "linear")


def _marketplace_topic_question(topic: str, variant: int) -> tuple[str, int]:
    """단원별 작은 수치 문제를 결정적으로 만들고 정수 정답을 반환한다."""
    a = 2 + variant % 5
    b = 1 + (variant // 3) % 6
    c = 2 + (variant // 7) % 5
    n = 3 + variant % 4
    if topic == "polynomial":
        return (f"({a}x + {b}) + ({c}x - {b})를 간단히 할 때 x의 계수를 구하세요.", a + c)
    if topic == "quadratic":
        other = 1 + (variant // 5) % 5
        return (f"방정식 x² - {n + other}x + {n * other} = 0의 두 근의 합을 구하세요.", n + other)
    if topic == "sequence":
        term = b + (n - 1) * a
        return (f"첫째항이 {b}, 공차가 {a}인 등차수열의 제{n}항을 구하세요.", term)
    if topic == "exponential":
        exponent = 2 + variant % 5
        return (f"2ˣ = {2 ** exponent}일 때 x의 값을 구하세요.", exponent)
    if topic == "logarithm":
        exponent = 2 + variant % 5
        return (f"log₂({2 ** exponent})의 값을 구하세요.", exponent)
    if topic == "remainder":
        return (f"P(x) = {a}x + {b}를 x - {n}으로 나눌 때의 나머지를 구하세요.", a * n + b)
    if topic == "function":
        return (f"함수 f(x) = {a}x + {b}일 때 f({n})의 값을 구하세요.", a * n + b)
    if topic == "coordinate":
        return (f"두 점 ({b}, {c})와 ({b + n}, {c}) 사이의 거리를 구하세요.", n)
    if topic == "counting":
        people = 4 + variant % 4
        return (f"{people}명 중에서 대표 2명을 순서 없이 뽑는 경우의 수를 구하세요.", people * (people - 1) // 2)
    if topic == "permutation":
        people = 4 + variant % 4
        return (f"{people}명 중 회장과 부회장을 한 명씩 뽑는 경우의 수를 구하세요.", people * (people - 1))
    if topic in {"derivative", "tangent"}:
        x = 1 + variant % 3
        label = "접선의 기울기" if topic == "tangent" else "미분계수"
        return (f"f(x) = {a}x² + {b}x일 때 x = {x}에서의 {label}를 구하세요.", 2 * a * x + b)
    if topic == "integral":
        return (f"정적분 ∫₀^{n} 2x dx의 값을 구하세요.", n * n)
    if topic == "parabola_area":
        return (f"0 ≤ x ≤ {n}에서 y = {2 * n} - 2x와 x축이 이루는 넓이를 구하세요.", n * n)
    if topic == "complex":
        return (f"i가 허수단위일 때 i^{4 * n} + {b}의 값을 구하세요.", b + 1)
    if topic == "matrix":
        return (f"행렬 A의 (1,1)성분이 {a}, B의 (1,1)성분이 {b}일 때 A+B의 (1,1)성분을 구하세요.", a + b)
    if topic == "line":
        return (f"직선 y = {a}x + {b} 위에서 x = {n}일 때 y의 값을 구하세요.", a * n + b)
    answer = 1 + variant % 8
    return (f"방정식 {a}x + {b} = {a * answer + b}를 풀어 x의 값을 구하세요.", answer)


def _marketplace_flow_steps(topic: str) -> list[dict[str, str]]:
    """단원별 풀이에 필요한 핵심 동작을 정답값 노출 없이 3개 Flow 노드로 제공한다."""
    flows = {
        "polynomial": ("동류항을 찾는다.", "같은 차수의 항끼리 계산한다.", "계수를 정리해 검산한다."),
        "quadratic": ("식을 표준형으로 정리한다.", "인수분해 또는 근의 공식을 적용한다.", "구한 근을 원래 식에 대입한다."),
        "sequence": ("수열의 규칙과 공차를 확인한다.", "일반항에 주어진 항 번호를 대입한다.", "계산 결과를 수열의 규칙과 비교한다."),
        "exponential": ("밑을 같은 형태로 정리한다.", "지수 법칙을 적용한다.", "지수의 값을 계산해 검산한다."),
        "remainder": ("나누는 식의 근을 구한다.", "나머지정리를 적용한다.", "함숫값을 계산해 나머지를 확인한다."),
        "function": ("합성할 안쪽 함수부터 확인한다.", "안쪽 함숫값을 바깥 함수에 대입한다.", "계산 결과를 정리한다."),
        "coordinate": ("두 점의 좌표 차를 구한다.", "거리 공식에 대입한다.", "제곱근을 계산해 거리를 확인한다."),
        "counting": ("선택 순서와 중복 가능 여부를 확인한다.", "곱의 법칙으로 경우의 수를 계산한다.", "빠진 경우가 없는지 검산한다."),
        "derivative": ("주어진 함수를 미분한다.", "도함수에 주어진 x값을 대입한다.", "미분계수를 계산해 정리한다."),
        "tangent": ("함수를 미분해 접선의 기울기를 구한다.", "접점 좌표를 확인한다.", "점-기울기식으로 접선 방정식을 정리한다."),
        "integral": ("함수의 부정적분을 구한다.", "적분 구간의 양 끝값을 대입한다.", "두 함숫값의 차를 계산한다."),
        "parabola_area": ("곡선과 축이 만드는 구간을 확인한다.", "넓이에 해당하는 정적분을 세운다.", "정적분 값을 계산해 넓이를 확인한다."),
    }
    selected = flows.get(
        topic,
        ("문제의 조건을 식으로 정리한다.", "필요한 연산을 순서대로 적용한다.", "계산 결과를 원래 조건으로 검산한다."),
    )
    return [{"flow": flow} for flow in selected]


def _build_marketplace_questions(listing: dict[str, Any]) -> list[dict[str, Any]]:
    """필요 변수: 시험지·문제세트 카탈로그의 ID·제목·난이도·문항 수. 작동 원리:
    상품 ID 해시를 시드로 사용해 같은 상품에는 항상 같은 고유 문항을 할당하고,
    목록의 problem_ids·개별 조회·시험지 상세·채점이 동일한 문항 원장을 공유한다."""
    item_count = min(max(int(listing.get("item_count") or 5), 1), 50)
    seed = int(hashlib.sha256(str(listing["id"]).encode("utf-8")).hexdigest()[:8], 16)
    topics = _marketplace_topic_pool(listing)
    answer_offset = seed % 5
    questions: list[dict[str, Any]] = []
    for index in range(item_count):
        topic = topics[index % len(topics)]
        prompt, answer = _marketplace_topic_question(topic, seed + index * 7919)
        correct_index = (answer_offset + index * 2) % 5
        distractors = [answer - 2, answer - 1, answer + 1, answer + 2]
        choices = distractors[:correct_index] + [answer] + distractors[correct_index:]
        questions.append(
            {
                "header": {
                    "quest_id": f"{listing['id']}-q{index + 1}",
                    "quest_type": "multiple_choice",
                },
                "data": {
                    "quest_title": prompt,
                    "quest_options": [str(choice) for choice in choices],
                    "correct_choice_index": correct_index,
                    "marketplace_listing_id": listing["id"],
                    "hash_tags": [
                        topic,
                        str(listing.get("difficulty") or ""),
                        str(listing.get("grade_band") or ""),
                    ],
                },
                "solves": _marketplace_flow_steps(topic),
            }
        )
    return questions


def _build_course_runtime_state(course_id: str, owned_state: dict[str, Any]) -> dict[str, Any]:
    """필요 변수: 코스 asset ID와 KV 보유 상태. 작동 원리: main 런타임의 student_state 계약을
    작은 상태 객체로 재현해 수강 시작·이어하기가 추가 DB 조회 없이 같은 상태를 사용하게 한다."""
    progress_index = max(0, int(owned_state.get("progress_index") or 0))
    completed = bool(owned_state.get("completed"))
    module_id = f"{course_id}-module-{progress_index + 1}"
    return {
        "status": "completed" if completed else "in_progress",
        "current_module_id": None if completed else module_id,
        "completed_modules": [module_id] if completed else [],
        "progress_index": progress_index,
    }


def _find_marketplace_question(quest_id: str) -> dict[str, Any] | None:
    """필요 변수: 시험지·문제세트가 할당한 quest ID. 작동 원리: 접미사 앞의 상품 ID를
    분리한 뒤 같은 결정적 문항 원장에서 한 번만 찾아 조회와 채점 계약을 일치시킨다."""
    listing_id, marker, _suffix = quest_id.rpartition("-q")
    if not marker:
        return None
    listing = _find_catalog_listing(listing_id)
    if listing is None or listing.get("kind") not in {"problem_set", "exam"}:
        return None
    return next(
        (
            question
            for question in _build_marketplace_questions(listing)
            if str(question.get("header", {}).get("quest_id")) == quest_id
        ),
        None,
    )


def _build_generated_questions(payload: QuestGenerateRequest) -> list[dict[str, Any]]:
    """필요 변수: 태그·난이도·문항 수·선택 시드다. 작동 원리: 요청 해시로 작은
    일차방정식 세트를 결정적으로 만들어 외부 생성 서버가 없을 때도 같은 입력에
    같은 문제를 반환하며 DB 조회와 동시 생성 작업을 만들지 않는다."""
    tags = [tag.strip() for tag in payload.hash_tags if tag.strip()]
    normalized_tags = tags or ["수학"]
    min_tier = min(payload.min_difficulty_tier, payload.max_difficulty_tier)
    max_tier = max(payload.min_difficulty_tier, payload.max_difficulty_tier)
    fingerprint = json.dumps(
        {
            "hash_tags": normalized_tags,
            "question_count": payload.question_count,
            "min_difficulty_tier": min_tier,
            "max_difficulty_tier": max_tier,
            "seed": payload.seed,
            "request_id": payload.request_id,
        },
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    base_digest = hashlib.sha256(fingerprint.encode("utf-8")).hexdigest()
    base_seed = int(base_digest[:12], 16)
    questions: list[dict[str, Any]] = []
    tier_span = max_tier - min_tier + 1

    for index in range(payload.question_count):
        item_seed = base_seed + index * 7919
        tier = min_tier + (item_seed % tier_span)
        answer = 1 + (item_seed % (6 + tier * 2))
        coefficient = 2 + ((item_seed // 7) % (4 + tier))
        constant = 1 + ((item_seed // 31) % (8 + tier * 2))
        result = coefficient * answer + constant
        candidates = [answer, answer + 1, max(0, answer - 1), answer + 2]
        unique_candidates = list(dict.fromkeys(candidates))
        while len(unique_candidates) < 4:
            unique_candidates.append(answer + len(unique_candidates))
        rotation = (item_seed // 101) % 4
        rotated = unique_candidates[rotation:] + unique_candidates[:rotation]
        correct_index = rotated.index(answer)
        quest_id = f"canary-generated-{base_digest[:12]}-q{index + 1}"
        questions.append(
            {
                "header": {
                    "quest_id": quest_id,
                    "quest_type": "multiple_choice",
                },
                "data": {
                    "quest_title": (
                        "다음 방정식을 풀어 x의 값을 구하세요.\n"
                        f"{coefficient}x + {constant} = {result}"
                    ),
                    "quest_options": [str(choice) for choice in rotated],
                    "correct_choice_index": correct_index,
                    "hash_tags": normalized_tags,
                    "difficulty_tier": tier,
                },
                "solves": [
                    {"flow": "양변에서 상수항을 뺀다."},
                    {"flow": "양변을 x의 계수로 나눈다."},
                    {"flow": "구한 값을 원래 방정식에 대입해 검산한다."},
                ],
            }
        )
    return questions


def _build_marketplace_exam_status(listing: dict[str, Any]) -> dict[str, Any]:
    """필요 변수: 시험지 상품과 공유 문항 원장이다. 작동 원리: ExamPaperPage가 요구하는
    완료 상태·문항 메타데이터로 변환해 시험지 목록과 실제 풀이 화면의 문항 수를 일치시킨다."""
    difficulty_match = re.search(r"(\d+)", str(listing.get("difficulty") or ""))
    difficulty_tier = int(difficulty_match.group(1)) if difficulty_match else 1
    questions = _build_marketplace_questions(listing)
    items = []
    for index, question in enumerate(questions):
        header = question["header"]
        data = question["data"]
        items.append(
            {
                "exam_id": listing["id"],
                "title": listing["title"],
                "item_count": len(questions),
                "item_index": index + 1,
                "status": "done",
                "subject_key": str(listing.get("grade_band") or "수학"),
                "hash_tags": data.get("hash_tags", []),
                "difficulty_tier": difficulty_tier,
                "question_type": header["quest_type"],
                "quest_id": header["quest_id"],
                "quest_title": data["quest_title"],
                "quest_options": data["quest_options"],
                "solves_count": 0,
                "strategy_level": 0,
                "branch_conditions": 0,
                "flow_count": 0,
                "codebase_id": 0,
                "seed": index,
            }
        )
    return {"exam_id": listing["id"], "status": "done", "items": items}


class OcrJobRequest(BaseModel):
    """필요 변수: 처리 모드와 기존 분석 payload. 작동 원리: 추론 입력을 큐 행 하나로 제한한다."""

    mode: str = Field(default="solve", pattern="^(solve|ocr)$")
    payload: dict[str, Any]


class RegisterRequest(BaseModel):
    """필요 변수: 학생 가입 필드. 작동 원리: 기존 FastAPI 가입 계약과 같은 JSON을 검증한다."""

    username: str
    password: str
    name: str
    grade: str
    track: str | None = None
    subject: str | None = None
    school: str | None = None
    profile_image: str | None = None
    email: str | None = None


class LoginRequest(BaseModel):
    """필요 변수: 아이디와 비밀번호. 작동 원리: Supabase 저장 해시와 비교할 입력을 제한한다."""

    username: str
    password: str


class ServerChatMessageRequest(BaseModel):
    user_message: str = Field(min_length=1, max_length=250)
    character: str | None = Field(default=None, max_length=40)
    mode: str = Field(default="chat", pattern="^(chat|problem)$")
    ephemeral: bool = False
    include_user_data: bool = False
    quest_title: str | None = Field(default=None, max_length=500)
    flow: str | None = Field(default=None, max_length=4000)
    ocr: str | None = Field(default=None, max_length=4000)


class UsernameRequest(BaseModel):
    """필요 변수: 검사할 아이디. 작동 원리: 가입 전 형식과 중복 여부를 한 번에 확인한다."""

    username: str


class FieldValidationRequest(BaseModel):
    """필요 변수: 필드 이름과 값. 작동 원리: 기존 앱의 단계별 가입 검증 계약을 유지한다."""

    field: str
    value: str = ""


class ProfileUpdateRequest(BaseModel):
    """필요 변수: 변경할 프로필 필드. 작동 원리: 전달된 값만 기존 사용자 행에 반영한다."""

    username: str | None = None
    password: str | None = None
    name: str | None = None
    grade: str | None = None
    track: str | None = None
    subject: str | None = None
    school: str | None = None
    email: str | None = None


class ProfileDeleteRequest(BaseModel):
    """필요 변수: 현재 비밀번호. 작동 원리: 계정 삭제 전 소유자를 재검증한다."""

    password: str


class UserStorageRequest(BaseModel):
    """필요 변수: UTF-8 JSON 문자열. 작동 원리: 기존 앱의 사용자별 KV 계약을 유지한다."""

    value: str


class SolveHistoryCreateRequest(BaseModel):
    """필요 변수: 문제 ID와 정오답. 작동 원리: 오답 노트에 필요한 최소 풀이 결과만 검증한다."""

    quest_id: str = Field(min_length=1, max_length=200)
    is_correct: bool
    codebase_id: int | None = None
    seed: int | None = None
    tags: list[str] = Field(default_factory=list, max_length=20)


class StudentScheduleSyncRequest(BaseModel):
    """필요 변수: 날짜별 개인 일정 제목. 작동 원리: 전체 일정 스냅샷을 사용자 단위로 교체한다."""

    tasks_by_date: dict[str, list[str]]


class MarketplaceProgressRequest(BaseModel):
    """필요 변수: 문제 위치와 완료 여부. 작동 원리: 무료 마켓 코스의 사용자별 학습 위치를 제한된 형식으로 받는다."""

    progress_index: int = Field(default=0, ge=0)
    completed: bool = False


class FriendSearchRequest(BaseModel):
    """필요 변수: 사용자명 일부와 결과 제한. 작동 원리: 공개 사용자 열만 제한 검색한다."""

    query: str = Field(min_length=1, max_length=16)
    limit: int = Field(default=20, ge=1, le=50)


class FriendRequestCreateRequest(BaseModel):
    """필요 변수: 대상 사용자명과 선택 메시지. 작동 원리: 인증 사용자의 대기 요청만 생성한다."""

    username: str = Field(min_length=1, max_length=16)
    message: str | None = Field(default=None, max_length=200)


class FriendTargetRequest(BaseModel):
    """필요 변수: 관계를 해제할 사용자명. 작동 원리: 양쪽 친구 표식을 함께 제거한다."""

    username: str = Field(min_length=1, max_length=16)


class DirectMessageCreateRequest(BaseModel):
    """필요 변수: 친구 사용자명과 쪽지 본문. 작동 원리: 직접 메시지 입력 크기를 API 경계에서 제한한다."""

    peer: str = Field(min_length=1, max_length=16)
    text: str = Field(min_length=1, max_length=2000)


class StudyGroupCreateRequest(BaseModel):
    """필요 변수: 그룹명·소개·정원과 선택 잠금 정보. 작동 원리: 웹 입력 경계에서 그룹 생성 계약을 제한한다."""

    name: str = Field(min_length=1, max_length=80)
    description: str | None = Field(default=None, max_length=500)
    password: str | None = Field(default=None, max_length=10)
    max_members: int = Field(default=12, ge=2, le=100)
    is_public: bool = True
    logo_index: int | None = Field(default=None, ge=0, le=100)
    lock_enabled: bool = False
    invite_code: str | None = Field(default=None, max_length=20)


class StudyGroupJoinRequest(BaseModel):
    password: str | None = Field(default=None, max_length=10)


class StudyGroupJoinByCodeRequest(StudyGroupJoinRequest):
    invite_code: str = Field(min_length=4, max_length=20)


class StudyGroupMessageCreateRequest(BaseModel):
    text: str = Field(min_length=1, max_length=2000)


class StudyGroupFriendInviteRequest(BaseModel):
    username: str = Field(min_length=4, max_length=16)


class QuestGenerateRequest(BaseModel):
    """필요 변수: 문제 태그·문항 수·난이도 범위와 선택 생성 메타데이터다."""

    hash_tags: list[str] = Field(default_factory=list)
    question_count: int = Field(default=1, ge=1, le=30)
    min_difficulty_tier: int = Field(default=1, ge=1, le=5)
    max_difficulty_tier: int = Field(default=3, ge=1, le=5)
    solves_count: int = Field(default=3, ge=0, le=20)
    strategy_level: int = Field(default=0, ge=0, le=20)
    branch_conditions: int = Field(default=0, ge=0, le=20)
    seed: int | None = None
    request_id: str | None = None


class GraphExpressionRequest(BaseModel):
    id: str = Field(min_length=1, max_length=60)
    label: str = Field(default="", max_length=80)
    color_hex: str = Field(default="#2F7CF6", pattern=r"^#[0-9A-Fa-f]{6}$")
    expression: str = Field(min_length=1, max_length=120)


class GraphSampleRequest(BaseModel):
    expressions: list[GraphExpressionRequest] = Field(min_length=1, max_length=6)
    parameters: dict[str, float] = Field(default_factory=dict)
    left: float = Field(default=-12, ge=-100, le=100)
    right: float = Field(default=12, ge=-100, le=100)
    samples: int = Field(default=241, ge=41, le=401)
    degree_mode: bool = False


class SupabaseDataApi:
    """필요 변수: Supabase URL·service role key. 작동 원리: HTTPS PostgREST로만 큐를 읽고 쓴다."""

    def __init__(self) -> None:
        base_url = os.getenv("SUPABASE_URL", "").strip().rstrip("/")
        service_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "").strip()
        if not base_url or not service_key:
            raise RuntimeError("SUPABASE_URL과 SUPABASE_SERVICE_ROLE_KEY가 필요합니다")
        self.base_url = f"{base_url}/rest/v1"
        self.headers = {
            "apikey": service_key,
            "Authorization": f"Bearer {service_key}",
            "Content-Type": "application/json; charset=utf-8",
        }

    def request(
        self,
        method: str,
        path: str,
        *,
        query: dict[str, str] | None = None,
        body: dict[str, Any] | None = None,
        prefer: str | None = None,
    ) -> Any:
        """필요 변수: 메서드·경로·필터·JSON. 작동 원리: 10초 제한 Data API 호출 결과를 UTF-8 JSON으로 반환한다."""
        url = f"{self.base_url}/{path.lstrip('/')}"
        if query:
            url = f"{url}?{urllib.parse.urlencode(query)}"
        headers = dict(self.headers)
        if prefer:
            headers["Prefer"] = prefer
        encoded = None if body is None else json.dumps(body, ensure_ascii=False).encode("utf-8")
        request = urllib.request.Request(url, data=encoded, headers=headers, method=method)
        try:
            with urllib.request.urlopen(request, timeout=10) as response:
                raw = response.read()
        except urllib.error.HTTPError as error:
            detail = error.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"Supabase Data API {error.code}: {detail}") from error
        return json.loads(raw.decode("utf-8")) if raw else None


app = FastAPI(title="AIFlow OCR Queue", version="1.0.0")
origins = [value.strip() for value in os.getenv("CORS_ALLOW_ORIGINS", "").split(",") if value.strip()]
if origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=origins,
        # Flutter Web의 프로필·사용자 저장소 갱신과 삭제도 교차 출처에서 동작해야 한다.
        allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type", "X-Idempotency-Key"],
    )


def _current_user(authorization: str | None = Header(default=None)) -> str:
    """필요 변수: 기존 AIFlow JWT와 OMJ_JWT_SECRET. 작동 원리: 동일 HS256 서명으로 큐 소유자를 확정한다."""
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Bearer token required")
    secret = os.getenv("OMJ_JWT_SECRET", "").strip()
    if not secret:
        raise HTTPException(status_code=503, detail="OMJ_JWT_SECRET is not configured")
    try:
        claims = jwt.decode(authorization[7:].strip(), secret, algorithms=["HS256"])
    except jwt.PyJWTError as error:
        raise HTTPException(status_code=401, detail="Invalid token") from error
    user_id = str(claims.get("sub") or "").strip()
    if not user_id:
        raise HTTPException(status_code=401, detail="Token subject required")
    return user_id


def _jwt_secret() -> str:
    """필요 변수: OMJ_JWT_SECRET. 작동 원리: 모든 카나리 인증 토큰에 동일한 운영 Secret을 강제한다."""
    secret = os.getenv("OMJ_JWT_SECRET", "").strip()
    if not secret:
        raise HTTPException(status_code=503, detail="OMJ_JWT_SECRET is not configured")
    return secret


def _create_token(user_id: str) -> str:
    """필요 변수: 사용자 UUID. 작동 원리: 기존 서버와 같은 HS256·7일 만료 토큰을 발급한다."""
    now = int(time.time())
    return jwt.encode(
        {"sub": user_id, "role": "student", "iat": now, "exp": now + 60 * 60 * 24 * 7},
        _jwt_secret(),
        algorithm="HS256",
    )


def _hash_password(password: str, salt: str) -> str:
    """필요 변수: 평문 비밀번호와 무작위 salt. 작동 원리: 기존 서버와 동일한 PBKDF2-SHA256 12만 회 해시를 만든다."""
    return hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt.encode("utf-8"), 120_000).hex()


def _validate_registration(payload: RegisterRequest) -> None:
    """필요 변수: 가입 payload. 작동 원리: DB 요청 전에 기존 학생 가입 형식을 동일하게 검사한다."""
    if not USERNAME_RE.fullmatch(payload.username.strip()):
        raise HTTPException(status_code=400, detail="아이디 형식이 다릅니다")
    if not PASSWORD_RE.fullmatch(payload.password):
        raise HTTPException(status_code=400, detail="비밀번호 형식이 다릅니다")
    if not NAME_RE.fullmatch(payload.name.strip()):
        raise HTTPException(status_code=400, detail="이름 형식이 다릅니다")
    if not payload.grade.strip():
        raise HTTPException(status_code=400, detail="학년을 입력해주세요")
    if payload.email and not EMAIL_RE.fullmatch(payload.email.strip()):
        raise HTTPException(status_code=400, detail="이메일 형식이 다릅니다")


def _get_private_user(user_id: str) -> dict[str, Any]:
    """필요 변수: 사용자 UUID. 작동 원리: 비밀번호 검증이 필요한 내부 열을 단건 조회한다."""
    try:
        rows = _data_api().request(
            "GET",
            "canary_users",
            query={"select": "user_id,password_hash,salt", "user_id": f"eq.{user_id}", "limit": "1"},
        ) or []
    except RuntimeError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error
    if not rows:
        raise HTTPException(status_code=404, detail="User not found")
    return dict(rows[0])


def _password_matches(row: dict[str, Any], password: str) -> bool:
    """필요 변수: 비밀번호 해시 행과 평문 입력. 작동 원리: PBKDF2 결과를 상수시간으로 비교한다."""
    computed = _hash_password(password, str(row["salt"]))
    return hmac.compare_digest(computed, str(row["password_hash"]))


def _data_api() -> SupabaseDataApi:
    """필요 변수: 배포 Secret. 작동 원리: serverless 요청마다 무상태 Data API 클라이언트를 만든다."""
    try:
        return SupabaseDataApi()
    except RuntimeError as error:
        raise HTTPException(status_code=503, detail=str(error)) from error


def _wake_lightning(job_id: str) -> None:
    """필요 변수: Lightning 공개 URL·공유 Secret. 작동 원리: Studio 시작 요청 후 wake를 보내 대기 큐를 소비시킨다."""
    wake_url = os.getenv("LIGHTNING_WAKE_URL", "").strip()
    wake_secret = os.getenv("LIGHTNING_WAKE_SECRET", "").strip()
    if not wake_url or not wake_secret:
        return
    try:
        _start_lightning_studio()
    except (urllib.error.HTTPError, OSError):
        # 큐 행은 이미 Supabase에 저장됐다. 관리 API의 일시 인증·네트워크 오류가
        # 학생의 OCR 접수 자체를 500으로 바꾸지 않게 하고, 실행 중 worker의 다음 poll을 기다린다.
        pass
    # Lightning는 너무 빨리 끊긴 요청을 Auto start 신호로 확정하지 않을 수 있다.
    wake_timeout = max(5.0, min(float(os.getenv("LIGHTNING_WAKE_TIMEOUT_SECONDS", "20")), 24.0))
    request = urllib.request.Request(
        wake_url,
        data=json.dumps({"job_id": job_id}).encode("utf-8"),
        headers={"Content-Type": "application/json", "X-Worker-Secret": wake_secret},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=wake_timeout) as response:
            response.read(128)
    except OSError:
        # 콜드 스타트 timeout이어도 최초 요청이 Studio 시작 신호로 사용된다.
        pass


def _start_lightning_studio() -> None:
    """필요 변수: Lightning Basic 인증·팀스페이스/Studio ID. 작동 원리: 기존 무료 CPU-4 Studio만 명시적으로 재개한다."""
    authorization = os.getenv("LIGHTNING_API_AUTH", "").strip()
    teamspace_id = os.getenv("LIGHTNING_TEAMSPACE_ID", "").strip()
    studio_id = os.getenv("LIGHTNING_STUDIO_ID", "").strip()
    if not authorization or not teamspace_id or not studio_id:
        return
    url = f"https://lightning.ai/v1/projects/{teamspace_id}/cloudspaces/{studio_id}/start"
    request = urllib.request.Request(
        url,
        data=json.dumps({"computeConfig": {"name": "cpu-4", "spot": False}}).encode("utf-8"),
        headers={"Authorization": authorization, "Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            response.read(128)
    except urllib.error.HTTPError as error:
        # 이미 Running/Pending인 Studio의 충돌 응답은 이어지는 wake 호출로 처리한다.
        if error.code not in {400, 409}:
            raise
    except OSError:
        # 관리 API 일시 실패는 공개 URL Auto start 경로로 한 번 더 시도한다.
        return


def _lightning_app_base_url() -> str:
    """필요 변수: Lightning 공개 wake URL. 작동 원리: 비밀 환경값에서 `/wake`만 제거해 전체 앱 API 기준 주소를 만든다."""
    wake_url = os.getenv("LIGHTNING_WAKE_URL", "").strip()
    if not wake_url:
        raise HTTPException(status_code=503, detail="Lightning app URL is not configured")
    parsed = urllib.parse.urlsplit(wake_url)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise HTTPException(status_code=503, detail="Lightning app URL is invalid")
    path = parsed.path.rstrip("/")
    if path.endswith("/wake"):
        path = path[: -len("/wake")]
    return urllib.parse.urlunsplit((parsed.scheme, parsed.netloc, path, "", "")).rstrip("/")


def _forward_lightning_request(
    method: str,
    path: str,
    query: str,
    body: bytes,
    headers: dict[str, str],
) -> Response:
    """필요 변수: HTTP 메서드·상대 경로·쿼리·본문·허용 헤더. 작동 원리: 24초 제한으로 전체 앱 서버 응답을 상태 코드와 함께 그대로 전달한다."""
    normalized_path = "/" + path.lstrip("/")
    target = f"{_lightning_app_base_url()}{normalized_path}"
    if query:
        target = f"{target}?{query}"
    request = urllib.request.Request(
        target,
        data=body or None,
        headers=headers,
        method=method,
    )
    try:
        with urllib.request.urlopen(request, timeout=24) as upstream:
            payload = upstream.read()
            content_type = upstream.headers.get("Content-Type", "application/json")
            return Response(
                content=payload,
                status_code=upstream.status,
                media_type=content_type.split(";", 1)[0],
            )
    except urllib.error.HTTPError as error:
        payload = error.read()
        content_type = error.headers.get("Content-Type", "application/json")
        return Response(
            content=payload,
            status_code=error.code,
            media_type=content_type.split(";", 1)[0],
        )
    except OSError as error:
        raise HTTPException(status_code=502, detail="Lightning app is unavailable") from error


@app.api_route(
    "/api/app/{path:path}",
    methods=["GET", "POST", "PUT", "PATCH", "DELETE"],
)
async def proxy_lightning_app(path: str, request: Request) -> Response:
    """필요 변수: Flutter 앱의 상대 API 경로와 요청 문맥. 작동 원리: 인증·본문 헤더만 선별해 Lightning 전체 서버로 전달하고 이벤트 루프 차단을 피한다."""
    try:
        await run_in_threadpool(_start_lightning_studio)
    except (urllib.error.HTTPError, OSError):
        pass
    forwarded_headers = {
        name: value
        for name in ("Authorization", "Content-Type", "X-Idempotency-Key")
        if (value := request.headers.get(name))
    }
    body = await request.body()
    return await run_in_threadpool(
        _forward_lightning_request,
        request.method,
        path,
        request.url.query,
        body,
        forwarded_headers,
    )


LEVEL_TEST_QUESTION_COUNT = 25
LEVEL_TEST_TIME_LIMIT_SECONDS = 60 * 60


class LevelTestPlacementAnswerRequest(BaseModel):
    item_index: int = Field(ge=1, le=LEVEL_TEST_QUESTION_COUNT)
    quest_id: str = Field(min_length=1, max_length=200)
    is_correct: bool
    answer_time: float | None = Field(default=None, ge=0, le=LEVEL_TEST_TIME_LIMIT_SECONDS)
    step_correctness: list[dict[str, Any]] = Field(default_factory=list)
    tags: list[str] = Field(default_factory=list)


def _level_test_storage_error(error: RuntimeError) -> HTTPException:
    del error
    return HTTPException(status_code=503, detail="Level test storage is unavailable")


def _level_test_kv_key(session_id: str | None = None) -> str:
    return f"level_test.result::{session_id}" if session_id else "level_test.latest_result"


def _load_level_test_kv(user_id: str, *, session_id: str | None = None) -> dict[str, Any] | None:
    try:
        rows = _data_api().request(
            "GET",
            "canary_user_kv",
            query={
                "select": "value",
                "user_id": f"eq.{user_id}",
                "key": f"eq.{_level_test_kv_key(session_id)}",
                "limit": "1",
            },
        ) or []
    except RuntimeError as error:
        raise _level_test_storage_error(error) from error
    if not rows:
        return None
    try:
        decoded = json.loads(str(rows[0].get("value") or "{}"))
    except json.JSONDecodeError:
        return None
    return decoded if isinstance(decoded, dict) else None


def _save_level_test_kv(user_id: str, result: dict[str, Any], *, session_id: str | None = None) -> None:
    try:
        _data_api().request(
            "POST",
            "canary_user_kv",
            query={"on_conflict": "user_id,key"},
            body={
                "user_id": user_id,
                "key": _level_test_kv_key(session_id),
                "value": json.dumps(result, ensure_ascii=False, separators=(",", ":")),
            },
            prefer="resolution=merge-duplicates,return=minimal",
        )
    except RuntimeError as error:
        raise _level_test_storage_error(error) from error


def _get_level_test_session(session_id: str, user_id: str) -> dict[str, Any]:
    try:
        rows = _data_api().request(
            "GET",
            "level_test_session",
            query={
                "select": "session_id,user_id,template_id,status,estimated_rating,estimated_ovr,confidence",
                "session_id": f"eq.{session_id}",
                "limit": "1",
            },
        ) or []
    except RuntimeError as error:
        raise _level_test_storage_error(error) from error
    if not rows or str(rows[0].get("user_id") or "") != user_id:
        raise HTTPException(status_code=404, detail="Placement session not found")
    return dict(rows[0])


def _level_test_template_items(template_id: str) -> list[dict[str, Any]]:
    try:
        items = _data_api().request(
            "GET",
            "level_test_template_item",
            query={
                "select": "item_index,phase,subject_key,hash_tags,difficulty_tier,quest_id,problem_rating",
                "template_id": f"eq.{template_id}",
                "item_index": f"lte.{LEVEL_TEST_QUESTION_COUNT}",
                "order": "item_index.asc",
                "limit": str(LEVEL_TEST_QUESTION_COUNT),
            },
        ) or []
    except RuntimeError as error:
        raise _level_test_storage_error(error) from error
    return [dict(item) for item in items]


def _level_test_problem_payloads(quest_ids: list[str]) -> dict[str, dict[str, Any]]:
    unique_ids = list(dict.fromkeys(value for value in quest_ids if value))
    if not unique_ids:
        return {}
    quoted_ids = ",".join(f'"{value.replace(chr(34), "")}"' for value in unique_ids)
    try:
        rows = _data_api().request(
            "GET",
            "problem_payload",
            query={
                "select": "quest_id,payload",
                "quest_id": f"in.({quoted_ids})",
                "limit": str(LEVEL_TEST_QUESTION_COUNT),
            },
        ) or []
    except RuntimeError as error:
        raise _level_test_storage_error(error) from error
    return {
        str(row.get("quest_id") or ""): dict(row.get("payload") or {})
        for row in rows
        if isinstance(row.get("payload"), dict)
    }


def _estimate_level_test_rating(samples: list[dict[str, Any]]) -> float:
    best_rating = 1200.0
    best_score = float("-inf")
    for rating in range(800, 2201, 5):
        score = 0.0
        for sample in samples:
            problem_rating = float(sample.get("problem_rating") or 1200.0)
            expected = 1.0 / (1.0 + 10 ** ((problem_rating - rating) / 400.0))
            expected = max(0.001, min(0.999, expected))
            score += math.log(expected if sample.get("is_correct") else 1.0 - expected)
        if score > best_score:
            best_score = score
            best_rating = float(rating)
    return best_rating


def _level_test_tag_results(samples: list[dict[str, Any]], global_rating: float) -> dict[str, float]:
    grouped: dict[str, list[dict[str, Any]]] = {}
    for sample in samples:
        for raw_tag in sample.get("tags") or []:
            tag = str(raw_tag).strip().lstrip("#").strip().lower()
            if tag:
                grouped.setdefault(tag, []).append(sample)
    results: dict[str, float] = {}
    for tag, tag_samples in grouped.items():
        local_rating = _estimate_level_test_rating(tag_samples)
        shrink = len(tag_samples) / (len(tag_samples) + 5.0)
        results[tag] = shrink * local_rating + (1.0 - shrink) * global_rating
    return results


@app.post("/level-tests/placement/start")
def start_level_test_placement(user_id: str = Depends(_current_user)) -> dict[str, Any]:
    try:
        templates = _data_api().request(
            "GET",
            "level_test_template",
            query={
                "select": "template_id,version,form_index",
                "active": "eq.true",
                "order": "form_index.asc",
                "limit": "50",
            },
        ) or []
    except RuntimeError as error:
        raise _level_test_storage_error(error) from error
    if not templates:
        raise HTTPException(status_code=503, detail="No placement template available")
    template_index = int(hashlib.sha256(user_id.encode("utf-8")).hexdigest()[:8], 16) % len(templates)
    template_id = str(templates[template_index].get("template_id") or "")
    items = _level_test_template_items(template_id)
    if len(items) != LEVEL_TEST_QUESTION_COUNT:
        raise HTTPException(status_code=503, detail="Placement template is incomplete")
    payloads = _level_test_problem_payloads([str(item.get("quest_id") or "") for item in items])
    questions = []
    for item in items:
        quest_id = str(item.get("quest_id") or "")
        quest = payloads.get(quest_id)
        if quest is None:
            raise HTTPException(status_code=503, detail="Placement problem payload is incomplete")
        questions.append({**item, "quest": quest})
    session_id = str(uuid.uuid4())
    try:
        _data_api().request(
            "POST",
            "level_test_session",
            body={
                "session_id": session_id,
                "user_id": user_id,
                "template_id": template_id,
                "status": "started",
            },
            prefer="return=minimal",
        )
    except RuntimeError as error:
        raise _level_test_storage_error(error) from error
    return {
        "success": True,
        "data": {
            "session_id": session_id,
            "template_id": template_id,
            "question_count": len(questions),
            "time_limit_seconds": LEVEL_TEST_TIME_LIMIT_SECONDS,
            "questions": questions,
        },
        "message": "Placement test started",
    }


@app.post("/level-tests/placement/{session_id}/answer")
def save_level_test_placement_answer(
    session_id: str,
    payload: LevelTestPlacementAnswerRequest,
    user_id: str = Depends(_current_user),
) -> dict[str, Any]:
    session = _get_level_test_session(session_id, user_id)
    if str(session.get("status") or "") == "graded":
        raise HTTPException(status_code=409, detail="Placement session already submitted")
    try:
        assigned = _data_api().request(
            "GET",
            "level_test_template_item",
            query={
                "select": "quest_id,hash_tags",
                "template_id": f"eq.{session['template_id']}",
                "item_index": f"eq.{payload.item_index}",
                "limit": "1",
            },
        ) or []
    except RuntimeError as error:
        raise _level_test_storage_error(error) from error
    if not assigned or str(assigned[0].get("quest_id") or "") != payload.quest_id:
        raise HTTPException(status_code=400, detail="Answer does not match the assigned placement problem")
    try:
        _data_api().request(
            "POST",
            "level_test_answer",
            query={"on_conflict": "session_id,item_index"},
            body={
                "session_id": session_id,
                "item_index": payload.item_index,
                "quest_id": payload.quest_id,
                "is_correct": payload.is_correct,
                "answer_time": payload.answer_time,
                "step_correctness": payload.step_correctness,
                "tags": assigned[0].get("hash_tags") or [],
            },
            prefer="resolution=merge-duplicates,return=minimal",
        )
    except RuntimeError as error:
        raise _level_test_storage_error(error) from error
    return {"success": True, "data": {"ok": True}, "message": "Placement answer saved"}


@app.post("/level-tests/placement/{session_id}/submit")
def submit_level_test_placement(
    session_id: str,
    user_id: str = Depends(_current_user),
) -> dict[str, Any]:
    replay = _load_level_test_kv(user_id, session_id=session_id)
    if replay is not None:
        return {"success": True, "data": replay, "message": "Placement rating applied"}
    session = _get_level_test_session(session_id, user_id)
    try:
        answers = _data_api().request(
            "GET",
            "level_test_answer",
            query={
                "select": "item_index,quest_id,is_correct,answer_time,tags",
                "session_id": f"eq.{session_id}",
                "order": "item_index.asc",
                "limit": str(LEVEL_TEST_QUESTION_COUNT),
            },
        ) or []
    except RuntimeError as error:
        raise _level_test_storage_error(error) from error
    if len(answers) != LEVEL_TEST_QUESTION_COUNT:
        raise HTTPException(status_code=400, detail="Placement test is not complete")
    item_by_index = {
        int(item.get("item_index") or 0): item
        for item in _level_test_template_items(str(session.get("template_id") or ""))
    }
    samples = []
    for answer in answers:
        index = int(answer.get("item_index") or 0)
        item = item_by_index.get(index)
        if item is None or str(item.get("quest_id") or "") != str(answer.get("quest_id") or ""):
            raise HTTPException(status_code=409, detail="Placement answer set is inconsistent")
        samples.append(
            {
                "is_correct": bool(answer.get("is_correct")),
                "problem_rating": float(item.get("problem_rating") or 1200.0),
                "tags": item.get("hash_tags") or [],
            }
        )
    rating = _estimate_level_test_rating(samples)
    tag_ratings = _level_test_tag_results(samples, rating)
    ordered_strong = sorted(tag_ratings.items(), key=lambda pair: pair[1], reverse=True)[:5]
    ordered_weak = sorted(tag_ratings.items(), key=lambda pair: pair[1])[:5]
    previous = _load_level_test_kv(user_id) or {}
    previous_ovr = float(previous.get("ovr") or 1200.0)
    correct_count = sum(1 for sample in samples if sample["is_correct"])
    result = {
        "session_id": session_id,
        "rating": rating,
        "ovr": rating,
        "ovr_delta": rating - previous_ovr,
        "recent_accuracy": correct_count / LEVEL_TEST_QUESTION_COUNT,
        "lose_streak": 0 if samples[-1]["is_correct"] else 1,
        "confidence": len(samples) / LEVEL_TEST_QUESTION_COUNT,
        "strong_tags": [{"tag": tag, "rating": round(value, 2)} for tag, value in ordered_strong],
        "weak_tags": [{"tag": tag, "rating": round(value, 2)} for tag, value in ordered_weak],
    }
    try:
        _data_api().request(
            "PATCH",
            "level_test_session",
            query={"session_id": f"eq.{session_id}", "user_id": f"eq.{user_id}"},
            body={
                "status": "graded",
                "estimated_rating": rating,
                "estimated_ovr": rating,
                "confidence": result["confidence"],
                "strong_tags": result["strong_tags"],
                "weak_tags": result["weak_tags"],
            },
            prefer="return=minimal",
        )
    except RuntimeError as error:
        raise _level_test_storage_error(error) from error
    try:
        _save_level_test_kv(user_id, result, session_id=session_id)
        _save_level_test_kv(user_id, result)
    except HTTPException as error:
        if error.status_code != 503:
            raise
        # The canonical result is already committed on level_test_session.
        # Anonymous canary users intentionally have no canary_users FK row,
        # and a transient profile-cache failure must not lose the test result.
        print("level_test_result_cache_unavailable")
    return {"success": True, "data": result, "message": "Placement rating applied"}


@app.api_route(
    "/level-tests/{path:path}",
    methods=["GET", "POST", "PUT", "PATCH", "DELETE"],
)
async def proxy_level_tests(path: str, request: Request) -> Response:
    """기존 웹 번들의 레벨테스트 경로를 Lightning API로 전달한다."""
    return await proxy_lightning_app(f"level-tests/{path}", request)


@app.get("/health")
def health() -> dict[str, str]:
    """필요 변수: 없음. 작동 원리: DB나 모델 없이 Vercel 함수 생존만 확인한다."""
    return {"status": "ok", "service": "aiflow-ocr-queue"}


@app.get("/health/level-test")
def level_test_health() -> dict[str, Any]:
    """Report whether the Supabase placement tables are available without exposing data."""
    checks: dict[str, bool] = {}
    for table, column in (
        ("level_test_template", "template_id"),
        ("level_test_template_item", "template_id"),
        ("problem_payload", "quest_id"),
        ("level_test_session", "session_id"),
        ("level_test_answer", "session_id"),
    ):
        try:
            _data_api().request(
                "GET",
                table,
                query={"select": column, "limit": "1"},
            )
            checks[table] = True
        except RuntimeError:
            checks[table] = False
    ready = all(checks.values())
    return {"status": "ok" if ready else "unavailable", "checks": checks}


@app.post("/auth/register", status_code=status.HTTP_201_CREATED)
def register_user(payload: RegisterRequest) -> dict[str, str]:
    """필요 변수: 검증된 가입 정보. 작동 원리: 고유 아이디를 Supabase에 저장하고 즉시 기존 호환 JWT를 발급한다."""
    _validate_registration(payload)
    user_id = str(uuid.uuid4())
    salt = secrets.token_hex(16)
    row = {
        "user_id": user_id,
        "username": payload.username.strip(),
        "name": payload.name.strip(),
        "grade": payload.grade.strip(),
        "track": (payload.track or "").strip() or None,
        "subject": (payload.subject or "").strip() or None,
        "school": (payload.school or "").strip() or None,
        "profile_image": (payload.profile_image or "").strip() or None,
        "email": (payload.email or "").strip() or None,
        "password_hash": _hash_password(payload.password, salt),
        "salt": salt,
    }
    try:
        rows = _data_api().request("POST", "canary_users", body=row, prefer="return=representation") or []
    except RuntimeError as error:
        if "23505" in str(error):
            raise HTTPException(status_code=409, detail="username already exists") from error
        raise HTTPException(status_code=502, detail=str(error)) from error
    if not rows:
        raise HTTPException(status_code=502, detail="User was not created")
    return {"token": _create_token(user_id), "user_id": user_id}


@app.post("/auth/login")
def login_user(payload: LoginRequest) -> dict[str, str]:
    """필요 변수: 아이디·비밀번호. 작동 원리: 인덱스 단건 조회 후 상수시간 해시 비교로 로그인한다."""
    username = payload.username.strip()
    try:
        rows = _data_api().request(
            "GET",
            "canary_users",
            query={"select": "user_id,password_hash,salt", "username": f"eq.{username}", "limit": "1"},
        ) or []
    except RuntimeError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error
    if not rows:
        raise HTTPException(status_code=401, detail="Invalid credentials")
    row = rows[0]
    computed = _hash_password(payload.password, str(row["salt"]))
    if not hmac.compare_digest(computed, str(row["password_hash"])):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    user_id = str(row["user_id"])
    return {"token": _create_token(user_id), "user_id": user_id}


@app.get("/auth/me")
def get_current_profile(user_id: str = Depends(_current_user)) -> dict[str, Any]:
    """필요 변수: 인증된 사용자 UUID. 작동 원리: 토큰 소유자의 공개 프로필 열만 단건 조회한다."""
    try:
        rows = _data_api().request(
            "GET", "canary_users", query={"select": USER_COLUMNS, "user_id": f"eq.{user_id}", "limit": "1"}
        ) or []
    except RuntimeError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error
    if not rows:
        raise HTTPException(status_code=404, detail="User not found")
    return dict(rows[0])


@app.put("/auth/me")
def update_current_profile(payload: ProfileUpdateRequest, user_id: str = Depends(_current_user)) -> dict[str, Any]:
    """필요 변수: 인증 사용자·변경 필드. 작동 원리: 허용 필드만 검증해 Supabase 단일 행을 갱신한다."""
    changes = payload.model_dump(exclude_none=True)
    password = changes.pop("password", None)
    if "username" in changes and not USERNAME_RE.fullmatch(str(changes["username"]).strip()):
        raise HTTPException(status_code=400, detail="아이디 형식이 다릅니다")
    if "name" in changes and not NAME_RE.fullmatch(str(changes["name"]).strip()):
        raise HTTPException(status_code=400, detail="이름 형식이 다릅니다")
    if "email" in changes and changes["email"] and not EMAIL_RE.fullmatch(str(changes["email"]).strip()):
        raise HTTPException(status_code=400, detail="이메일 형식이 다릅니다")
    changes = {key: value.strip() if isinstance(value, str) else value for key, value in changes.items()}
    if password is not None:
        if not PASSWORD_RE.fullmatch(password):
            raise HTTPException(status_code=400, detail="비밀번호 형식이 다릅니다")
        salt = secrets.token_hex(16)
        changes.update({"salt": salt, "password_hash": _hash_password(password, salt)})
    if changes:
        try:
            _data_api().request(
                "PATCH",
                "canary_users",
                query={"user_id": f"eq.{user_id}"},
                body=changes,
                prefer="return=minimal",
            )
        except RuntimeError as error:
            if "23505" in str(error):
                raise HTTPException(status_code=409, detail="username already exists") from error
            raise HTTPException(status_code=502, detail=str(error)) from error
    return get_current_profile(user_id)


@app.delete("/auth/me")
def delete_current_profile(payload: ProfileDeleteRequest, user_id: str = Depends(_current_user)) -> dict[str, str]:
    """필요 변수: 인증 사용자·현재 비밀번호. 작동 원리: 비밀번호 확인 후 연관 KV와 사용자 행을 cascade 삭제한다."""
    if not _password_matches(_get_private_user(user_id), payload.password):
        raise HTTPException(status_code=400, detail="Invalid credentials")
    try:
        _data_api().request("DELETE", "canary_users", query={"user_id": f"eq.{user_id}"}, prefer="return=minimal")
    except RuntimeError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error
    return {"status": "deleted"}


@app.post("/auth/anonymous")
def create_anonymous_token() -> dict[str, str]:
    """필요 변수: 없음. 작동 원리: 저장 행 없이 7일짜리 익명 사용자 토큰을 발급한다."""
    user_id = str(uuid.uuid4())
    return {"token": _create_token(user_id), "user_id": user_id}


@app.post("/auth/username/check")
def check_username(payload: UsernameRequest) -> dict[str, Any]:
    """필요 변수: 후보 아이디. 작동 원리: 형식 확인 후 고유 인덱스로 존재 여부만 조회한다."""
    username = payload.username.strip()
    if not USERNAME_RE.fullmatch(username):
        return {"available": False, "reason": "형식이 다릅니다"}
    try:
        rows = _data_api().request(
            "GET", "canary_users", query={"select": "user_id", "username": f"eq.{username}", "limit": "1"}
        ) or []
    except RuntimeError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error
    return {"available": not rows, "reason": None if not rows else "이미 사용 중인 아이디입니다"}


@app.post("/auth/validate")
def validate_auth_field(payload: FieldValidationRequest) -> dict[str, Any]:
    """필요 변수: 필드명·값. 작동 원리: 네트워크 DB 조회 없이 가입 입력 형식을 빠르게 검증한다."""
    field = payload.field.strip().lower()
    value = payload.value
    valid = True
    if field == "username":
        valid = bool(USERNAME_RE.fullmatch(value.strip()))
    elif field == "password":
        valid = bool(PASSWORD_RE.fullmatch(value))
    elif field == "name":
        valid = bool(NAME_RE.fullmatch(value.strip()))
    elif field == "email":
        valid = not value.strip() or bool(EMAIL_RE.fullmatch(value.strip()))
    elif field == "school":
        valid = bool(value.strip())
    else:
        raise HTTPException(status_code=400, detail="unsupported field")
    return {"valid": valid, "reason": None if valid else "형식이 다릅니다"}


@app.get("/user/storage/{key}")
def get_user_storage(key: str, user_id: str = Depends(_current_user)) -> dict[str, str | None]:
    """필요 변수: 인증 사용자·저장 키. 작동 원리: 복합 기본키로 사용자 JSON 문자열을 단건 조회한다."""
    try:
        rows = _data_api().request(
            "GET",
            "canary_user_kv",
            query={"select": "value", "user_id": f"eq.{user_id}", "key": f"eq.{key}", "limit": "1"},
        ) or []
    except RuntimeError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error
    return {"value": str(rows[0]["value"]) if rows else None}


@app.put("/user/storage/{key}")
def put_user_storage(key: str, payload: UserStorageRequest, user_id: str = Depends(_current_user)) -> dict[str, str]:
    """필요 변수: 인증 사용자·키·값. 작동 원리: 복합키 upsert로 재시작 가능한 사용자 상태를 저장한다."""
    try:
        _data_api().request(
            "POST",
            "canary_user_kv",
            query={"on_conflict": "user_id,key"},
            body={"user_id": user_id, "key": key, "value": payload.value},
            prefer="resolution=merge-duplicates,return=minimal",
        )
    except RuntimeError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error
    return {"status": "ok"}


_GRAPH_FUNCTION_NAMES = {"sin", "cos", "tan", "sqrt", "abs", "log", "ln", "exp"}
_GRAPH_AST_NODES = (
    ast.Expression, ast.BinOp, ast.UnaryOp, ast.Call, ast.Name, ast.Load,
    ast.Constant, ast.Add, ast.Sub, ast.Mult, ast.Div, ast.Pow, ast.Mod,
    ast.UAdd, ast.USub,
)


def _compile_graph_expression(source: str, parameter_names: set[str]) -> Any:
    """제한된 수학 AST만 컴파일해 사용자 입력이 Python 기능에 접근하지 못하게 한다."""
    normalized = re.sub(r"^y\s*=\s*", "", source.strip(), flags=re.IGNORECASE)
    normalized = normalized.replace("^", "**")
    try:
        tree = ast.parse(normalized, mode="eval")
    except SyntaxError as error:
        raise HTTPException(status_code=422, detail="지원되는 함수식을 입력해 주세요") from error
    nodes = list(ast.walk(tree))
    if len(nodes) > 64 or any(not isinstance(node, _GRAPH_AST_NODES) for node in nodes):
        raise HTTPException(status_code=422, detail="지원되지 않는 함수식입니다")
    allowed_names = {"x", "pi", "e", *parameter_names, *_GRAPH_FUNCTION_NAMES}
    for node in nodes:
        if isinstance(node, ast.Name) and node.id not in allowed_names:
            raise HTTPException(status_code=422, detail=f"지원되지 않는 변수: {node.id}")
        if isinstance(node, ast.Call):
            if not isinstance(node.func, ast.Name) or node.func.id not in _GRAPH_FUNCTION_NAMES or len(node.args) != 1:
                raise HTTPException(status_code=422, detail="지원되지 않는 함수 호출입니다")
        if isinstance(node, ast.Constant) and not isinstance(node.value, (int, float)):
            raise HTTPException(status_code=422, detail="숫자 상수만 사용할 수 있습니다")
        if isinstance(node, ast.BinOp) and isinstance(node.op, ast.Pow):
            if isinstance(node.right, ast.BinOp) and isinstance(node.right.op, ast.Pow):
                raise HTTPException(status_code=422, detail="중첩 거듭제곱은 사용할 수 없습니다")
            if isinstance(node.right, ast.Constant) and abs(float(node.right.value)) > 1000:
                raise HTTPException(status_code=422, detail="지수가 너무 큽니다")
    return compile(tree, "<graph-expression>", "eval")


@app.post("/graphs/sample")
def sample_graphs(payload: GraphSampleRequest) -> dict[str, Any]:
    """함수식을 서버에서 안전하게 샘플링해 렌더러가 사용할 실제 좌표 구간을 반환한다."""
    if payload.left >= payload.right:
        raise HTTPException(status_code=422, detail="left는 right보다 작아야 합니다")
    if len(payload.parameters) > 12 or any(not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]{0,15}", key) for key in payload.parameters):
        raise HTTPException(status_code=422, detail="매개변수 형식이 올바르지 않습니다")

    trig = {
        "sin": lambda value: math.sin(math.radians(value)) if payload.degree_mode else math.sin(value),
        "cos": lambda value: math.cos(math.radians(value)) if payload.degree_mode else math.cos(value),
        "tan": lambda value: math.tan(math.radians(value)) if payload.degree_mode else math.tan(value),
        "sqrt": math.sqrt,
        "abs": abs,
        "log": math.log10,
        "ln": math.log,
        "exp": math.exp,
    }
    scope = {"pi": math.pi, "e": math.e, **trig, **payload.parameters}
    step = (payload.right - payload.left) / (payload.samples - 1)
    series: list[dict[str, Any]] = []
    for expression in payload.expressions:
        compiled = _compile_graph_expression(expression.expression, set(payload.parameters))
        segments: list[dict[str, list[float]]] = []
        x_values: list[float] = []
        y_values: list[float] = []
        for index in range(payload.samples):
            x_value = payload.left + (step * index)
            try:
                y_value = float(eval(compiled, {"__builtins__": {}}, {**scope, "x": x_value}))
                valid = math.isfinite(y_value) and abs(y_value) <= 1_000_000
            except (ArithmeticError, ValueError, TypeError, OverflowError):
                valid = False
            if valid:
                x_values.append(round(x_value, 10))
                y_values.append(round(y_value, 10))
            elif x_values:
                segments.append({"x_values": x_values, "y_values": y_values})
                x_values, y_values = [], []
        if x_values:
            segments.append({"x_values": x_values, "y_values": y_values})
        if not segments:
            raise HTTPException(status_code=422, detail=f"표시 가능한 좌표가 없습니다: {expression.label or expression.id}")
        series.append({
            "id": expression.id,
            "label": expression.label,
            "color_hex": expression.color_hex,
            "expression": expression.expression,
            "segments": segments,
            "point_count": sum(len(segment["x_values"]) for segment in segments),
        })
    return {"series": series}


@app.delete("/user/storage/{key}")
def delete_user_storage(key: str, user_id: str = Depends(_current_user)) -> dict[str, str]:
    """필요 변수: 인증 사용자·키. 작동 원리: 본인 복합키 행만 삭제한다."""
    try:
        _data_api().request(
            "DELETE", "canary_user_kv", query={"user_id": f"eq.{user_id}", "key": f"eq.{key}"}, prefer="return=minimal"
        )
    except RuntimeError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error
    return {"status": "ok"}


def _empty_account_summary() -> dict[str, Any]:
    """필요 변수: 없음. 작동 원리: 신규 카나리 계정의 포인트·활동 기본값을 앱 계약대로 반환한다."""
    return {
        "total_points": 0,
        "activity_score": 0,
        "level": 1,
        "current_level_score": 0,
        "next_level_score": 100,
        "level_progress": 0.0,
        "daily_points": 0,
        "daily_point_limit": 100,
        "daily_points_remaining": 100,
        "activity_display_daily_cap": 2000,
    }


@app.get("/account/summary")
def get_account_summary(_user_id: str = Depends(_current_user)) -> dict[str, Any]:
    """필요 변수: 인증 사용자. 작동 원리: 신규 계정이 홈 화면을 열 수 있는 기본 계정 요약을 반환한다."""
    return _empty_account_summary()


@app.get("/rating/user")
def get_user_rating(_user_id: str = Depends(_current_user)) -> dict[str, Any]:
    """필요 변수: 인증 사용자. 작동 원리: 풀이 이력이 없는 신규 사용자의 초기 레이팅을 반환한다."""
    latest = _load_level_test_kv(_user_id)
    if latest is None:
        return {"rating": 0.0, "ovr": 0.0, "ovr_delta": 0.0, "recent_accuracy": 0.0, "lose_streak": 0}
    return {
        "rating": float(latest.get("rating") or 0.0),
        "ovr": float(latest.get("ovr") or 0.0),
        "ovr_delta": float(latest.get("ovr_delta") or 0.0),
        "recent_accuracy": float(latest.get("recent_accuracy") or 0.0),
        "lose_streak": int(latest.get("lose_streak") or 0),
    }


def _empty_arena_queue(queue_type: str) -> dict[str, Any]:
    """필요 변수: 대결 방식 ID. 작동 원리: 실시간 매칭 서버가 없는 Vercel 카나리에서 404 대신 초기 전적과 준비 상태를 반환한다."""
    return {
        "queue_type": queue_type,
        "rating": 1500,
        "tier": "C",
        "wins": 0,
        "losses": 0,
        "draws": 0,
        "recent_results": [],
        "coming_soon": queue_type != "duel_exam",
        "estimated_wait_seconds": 0,
    }


@app.get("/arena/summary")
def get_arena_summary(_user_id: str = Depends(_current_user)) -> dict[str, Any]:
    """필요 변수: 인증 사용자. 작동 원리: Vercel 화면이 대결장 구조를 렌더링하도록 두 공개 큐의 명시적 준비 상태를 반환한다."""
    active = _arena_load(_user_id)
    return {
        "queues": [
            _empty_arena_queue("duel_exam"),
            _empty_arena_queue("team_exam"),
        ],
        "active_match_id": active.get("id") if active and not active.get("finished") else None,
        "active_practice_match_id": None,
    }


class ArenaJoinRequest(BaseModel):
    """필요 변수: 큐 유형과 멱등 키. 작동 원리: Vercel에서도 main의 1v1 봇전 진입 계약을 유지한다."""
    queue_type: str
    idempotency_key: str = Field(min_length=8, max_length=128)


class ArenaAnswerRequest(BaseModel):
    """필요 변수: 문항·답안·멱등 키. 작동 원리: 사용자별 Supabase KV 경기 상태에 한 번만 답안을 반영한다."""
    question_id: str
    answer: str
    idempotency_key: str = Field(min_length=8, max_length=128)


def _arena_key() -> str:
    """필요 변수 없음. 작동 원리: 다른 카나리 사용자 데이터와 충돌하지 않는 경기 저장 키를 반환한다."""
    return "arena.active_match"


def _arena_load(user_id: str) -> dict[str, Any] | None:
    """필요 변수: 사용자 ID. 작동 원리: Supabase KV의 UTF-8 JSON 경기 한 건을 안전하게 복원한다."""
    rows = _data_api().request("GET", "canary_user_kv", query={"select": "value", "user_id": f"eq.{user_id}", "key": f"eq.{_arena_key()}", "limit": "1"}) or []
    if not rows:
        return None
    try:
        value = json.loads(str(rows[0].get("value") or "{}"))
    except json.JSONDecodeError:
        return None
    return value if isinstance(value, dict) else None


def _arena_save(user_id: str, match: dict[str, Any]) -> None:
    """필요 변수: 사용자 ID와 경기 상태. 작동 원리: 복합키 UPSERT로 serverless 인스턴스 교체 후에도 경기를 보존한다."""
    _data_api().request("POST", "canary_user_kv", query={"on_conflict": "user_id,key"}, body={"user_id": user_id, "key": _arena_key(), "value": json.dumps(match, ensure_ascii=False)}, prefer="resolution=merge-duplicates,return=minimal")


def _arena_questions() -> list[dict[str, Any]]:
    """필요 변수 없음. 작동 원리: main의 fallback 문항 계약처럼 객관식·숫자 단답형 10개를 고정 순서로 제공한다."""
    values = ((2, 3), (4, 5), (6, 7), (8, 2), (9, 3), (7, 4), (12, 5), (15, 3), (11, 8), (14, 6))
    items: list[dict[str, Any]] = []
    for index, (left, right) in enumerate(values):
        answer = left + right
        item = {"id": f"canary-arena-{index}", "prompt": f"{left} + {right}의 값은?", "answer": str(answer), "tags": "기본 연산"}
        if index % 2 == 0:
            labels = [answer - 1, answer, answer + 1, answer + 2]
            item["choices"] = [{"id": str(position), "label": str(label)} for position, label in enumerate(labels)]
            item["answer"] = "1"
        items.append(item)
    return items


def _arena_public_state(match: dict[str, Any]) -> dict[str, Any]:
    """필요 변수: 영속 경기. 작동 원리: 정답을 제외한 Flutter 경기 화면 계약으로 변환한다."""
    now = int(time.time())
    remaining = max(0, 1200 - (now - int(match["started_at"])))
    questions = [{key: value for key, value in question.items() if key != "answer"} for question in match["questions"]]
    return {"id": match["id"], "queue_type": "duel_exam", "practice": True, "team": 0, "bot_tier": "C", "bot_win_rating_reward": 20, "finished": bool(match.get("finished")), "remaining_seconds": remaining, "questions": questions, "submitted_question_ids": match.get("submitted", []), "scores": {"0": {"correct": match.get("correct", 0)}, "1": {"correct": 0}}, "participants": [{"user_id": "bot", "team": 1, "is_bot": True}]}


@app.post("/arena/queue/join")
def join_arena_queue(payload: ArenaJoinRequest, user_id: str = Depends(_current_user)) -> dict[str, Any]:
    """필요 변수: 인증 사용자와 1v1 큐. 작동 원리: main의 실사용자 대기 전 봇전 경로를 Supabase에 즉시 생성한다."""
    if payload.queue_type != "duel_exam":
        raise HTTPException(status_code=403, detail="현재 사용할 수 없는 대결 방식입니다.")
    current = _arena_load(user_id)
    if current and not current.get("finished"):
        return {"practice_match_id": current["id"]}
    match = {"id": str(uuid.uuid4()), "started_at": int(time.time()), "questions": _arena_questions(), "submitted": [], "correct": 0, "finished": False}
    _arena_save(user_id, match)
    return {"practice_match_id": match["id"]}


@app.post("/arena/queue/cancel")
def cancel_arena_queue(user_id: str = Depends(_current_user)) -> dict[str, Any]:
    """필요 변수: 인증 사용자. 작동 원리: 활성 경기 키를 삭제해 main 취소 응답과 같은 cancelled 상태를 반환한다."""
    _data_api().request("DELETE", "canary_user_kv", query={"user_id": f"eq.{user_id}", "key": f"eq.{_arena_key()}"}, prefer="return=minimal")
    return {"cancelled": True}


@app.get("/arena/matches/{match_id}")
def get_arena_match(match_id: str, user_id: str = Depends(_current_user)) -> dict[str, Any]:
    """필요 변수: 경기·사용자 ID. 작동 원리: 본인 KV 경기만 읽어 재접속과 REST 폴링을 지원한다."""
    match = _arena_load(user_id)
    if not match or match.get("id") != match_id:
        raise HTTPException(status_code=404, detail="경기를 찾을 수 없습니다.")
    return _arena_public_state(match)


@app.post("/arena/matches/{match_id}/answers")
def submit_arena_answer(match_id: str, payload: ArenaAnswerRequest, user_id: str = Depends(_current_user)) -> dict[str, Any]:
    """필요 변수: 경기·문항·답안. 작동 원리: 중복 제출을 차단하고 마지막 문항에서 종료 결과를 영속화한다."""
    match = _arena_load(user_id)
    if not match or match.get("id") != match_id or match.get("finished"):
        raise HTTPException(status_code=409, detail="제출할 수 없는 경기입니다.")
    if payload.question_id in match["submitted"]:
        raise HTTPException(status_code=409, detail="이미 제출한 문항입니다.")
    question = next((item for item in match["questions"] if item["id"] == payload.question_id), None)
    if question is None:
        raise HTTPException(status_code=404, detail="문항을 찾을 수 없습니다.")
    correct = str(question["answer"]) == payload.answer.strip()
    match["submitted"].append(payload.question_id)
    match["correct"] += int(correct)
    match["answers"] = {**match.get("answers", {}), payload.question_id: {"answer": payload.answer, "correct": correct}}
    if len(match["submitted"]) == len(match["questions"]):
        match["finished"] = True
    _arena_save(user_id, match)
    return {"correct": correct, "finished": match["finished"]}


@app.get("/arena/matches/{match_id}/result")
def get_arena_result(match_id: str, user_id: str = Depends(_current_user)) -> dict[str, Any]:
    """필요 변수: 종료 경기. 작동 원리: main 결과 페이지가 요구하는 참가자·점수·문항 분석 계약을 반환한다."""
    match = _arena_load(user_id)
    if not match or match.get("id") != match_id:
        raise HTTPException(status_code=404, detail="경기를 찾을 수 없습니다.")
    analysis = [{"question_id": item["id"], "prompt": item["prompt"], "correct_answer": item["answer"], "team_answers": {"0": match.get("answers", {}).get(item["id"], {})}} for item in match["questions"]]
    return {"practice": True, "viewer_user_id": user_id, "viewer_team": 0, "finish_reason": "all_answered", "scores": {"0": {"correct": match.get("correct", 0)}, "1": {"correct": 0}}, "participants": [{"user_id": user_id, "team": 0, "record": "win", "rating_before": 1500, "rating_after": 1520, "rating_delta": 20}, {"user_id": "bot", "team": 1, "is_bot": True, "record": "loss"}], "analysis": analysis}


@app.get("/arena/rankings")
def get_arena_rankings(
    queue_type: str = "duel_exam",
    _user_id: str = Depends(_current_user),
) -> dict[str, Any]:
    """필요 변수: 인증 사용자·대결 방식. 작동 원리: 카나리 랭킹 원장이 준비되기 전 파싱 가능한 빈 순위를 반환한다."""
    if queue_type not in {"duel_exam", "team_exam"}:
        raise HTTPException(status_code=403, detail="현재 사용할 수 없는 대결 방식입니다.")
    return {"queue_type": queue_type, "items": []}


@app.get("/rating/tags")
def get_tag_ratings(_user_id: str = Depends(_current_user)) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자. 작동 원리: 태그 풀이 이력이 없으면 빈 목록을 반환한다."""
    latest = _load_level_test_kv(_user_id)
    if latest is None:
        return {"tags": []}
    tags: dict[str, dict[str, Any]] = {}
    for item in list(latest.get("strong_tags") or []) + list(latest.get("weak_tags") or []):
        if not isinstance(item, dict):
            continue
        tag = str(item.get("tag") or "").strip()
        if tag:
            tags[tag] = {
                "tag": tag,
                "attempts": LEVEL_TEST_QUESTION_COUNT,
                "rating": float(item.get("rating") or 0.0),
                "delta": 0.0,
            }
    return {"tags": list(tags.values())}


@app.get("/weakness/tags")
def get_weakness_tags(_user_id: str = Depends(_current_user)) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자. 작동 원리: 약점 이력이 없는 신규 사용자의 빈 목록을 반환한다."""
    return {"tags": []}


def _catalog_course(item: dict[str, Any]) -> dict[str, Any]:
    """필요 변수: 마켓 코스 상품. 작동 원리: 같은 ID·제목을 코스 목록과 상세 화면이 파싱할 수 있는 V2 코스 계약으로 변환한다."""
    count = int(item["item_count"])
    return {
        "id": item["asset_id"],
        "title": item["title"],
        "description": item["description"],
        "difficulty": item["difficulty"],
        "duration": f"{max(1, (count + 4) // 5)}일",
        "lessons": max(1, (count + 4) // 5),
        "focus_tags": [item["grade_band"], item["difficulty"]],
        "target_ovr": 800,
        "is_demo": False,
        "is_public": True,
        "benefits": ["핵심 개념 정리", "단계별 문제 훈련"],
        "outline": ["개념 확인", "유형 훈련", "학습 마무리"],
        "modules": [],
    }


def _find_catalog_listing(identifier: str) -> dict[str, Any] | None:
    """필요 변수: 상품 ID 또는 코스 asset ID. 작동 원리: 81개 메모리 카탈로그를 단순 순회해 상세 요청 하나를 찾는다."""
    return next(
        (
            item
            for item in MARKETPLACE_CATALOG
            if item["id"] == identifier or item["asset_id"] == identifier
        ),
        None,
    )


def _load_owned_marketplace(user_id: str) -> dict[str, dict[str, Any]]:
    """필요 변수: 인증 사용자 ID. 작동 원리: 복합 인덱스 KV 한 행에서 무료 코스 보유·진도 상태를 읽어 DB 요청 수를 고정한다."""
    try:
        rows = _data_api().request(
            "GET",
            "canary_user_kv",
            query={
                "select": "value",
                "user_id": f"eq.{user_id}",
                "key": "eq.marketplace_owned",
                "limit": "1",
            },
        ) or []
        raw = json.loads(str(rows[0]["value"])) if rows else {}
    except (RuntimeError, ValueError, TypeError, KeyError, json.JSONDecodeError):
        return {}
    return {
        str(key): dict(value)
        for key, value in raw.items()
        if isinstance(value, dict)
    }


def _save_owned_marketplace(user_id: str, owned: dict[str, dict[str, Any]]) -> None:
    """필요 변수: 인증 사용자 ID와 보유 코스 상태. 작동 원리: 한 개 UTF-8 JSON 값으로 upsert해 상품별 DB 행 증가를 피한다."""
    try:
        _data_api().request(
            "POST",
            "canary_user_kv",
            query={"on_conflict": "user_id,key"},
            body={
                "user_id": user_id,
                "key": "marketplace_owned",
                "value": json.dumps(owned, ensure_ascii=False, separators=(",", ":")),
            },
            prefer="resolution=merge-duplicates,return=minimal",
        )
    except RuntimeError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error


def _filtered_catalog_courses(
    query: str | None,
    offset: int,
    limit: int,
) -> list[dict[str, Any]]:
    """필요 변수: 코스 검색어와 페이지 범위. 작동 원리: 마켓과 동일한 메모리 원장에서 제목·설명을 검색해 코스 화면의 빈 목록을 제거한다."""
    normalized = (query or "").strip().casefold()
    courses = [
        _catalog_course(item)
        for item in MARKETPLACE_CATALOG
        if item["kind"] == "course"
        and (
            not normalized
            or normalized
            in f"{item['title']} {item['description']} {item['difficulty']}".casefold()
        )
    ]
    safe_offset = max(0, offset)
    safe_limit = min(max(1, limit), 200)
    return courses[safe_offset : safe_offset + safe_limit]


@app.get("/courses/v2")
def list_courses_v2(
    query: str | None = None,
    offset: int = 0,
    limit: int = 50,
    _user_id: str = Depends(_current_user),
) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자·검색어·페이지 범위. 작동 원리: 무료 마켓 코스와 같은 81개 코스를 V2 목록 계약으로 반환한다."""
    return {"data": _filtered_catalog_courses(query, offset, limit)}


@app.get("/courses")
def list_courses(
    query: str | None = None,
    offset: int = 0,
    limit: int = 50,
    _user_id: str = Depends(_current_user),
) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자·검색어·페이지 범위. 작동 원리: 레거시 화면에도 V2와 동일한 무료 코스 목록을 제공한다."""
    return {"courses": _filtered_catalog_courses(query, offset, limit)}


@app.get("/courses/enrolled")
def list_enrolled_courses(user_id: str = Depends(_current_user)) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자와 무료 마켓 보유 상태. 작동 원리: 구매한 코스 asset ID를 내 코스 화면의 등록 계약으로 변환한다."""
    owned = _load_owned_marketplace(user_id)
    items = []
    for listing_id, state in owned.items():
        listing = _find_catalog_listing(listing_id)
        if listing is None or listing["kind"] != "course":
            continue
        items.append(
            {
                "course_id": listing["asset_id"],
                "percent": 1.0 if state.get("completed") else 0.0,
                "status": "completed" if state.get("completed") else "in_progress",
                "progress": {
                    "progress_index": int(state.get("progress_index") or 0),
                    "completed_modules": [],
                },
            }
        )
    return {"items": items}


@app.get("/courses/v2/{course_id}")
def get_course_v2(course_id: str, _user_id: str = Depends(_current_user)) -> dict[str, Any]:
    """필요 변수: 코스 asset ID. 작동 원리: 마켓 원장에서 같은 코스를 찾아 상세 화면이 404 없이 조회할 V2 계약을 반환한다."""
    listing = _find_catalog_listing(course_id)
    if listing is None:
        raise HTTPException(status_code=404, detail="course_not_found")
    return {"data": _catalog_course(listing)}


@app.get("/courses/{course_id}")
def get_legacy_course(course_id: str, _user_id: str = Depends(_current_user)) -> dict[str, Any]:
    """필요 변수: 코스 asset ID. 작동 원리: 레거시 상세 화면에도 같은 정규화 코스를 반환한다."""
    listing = _find_catalog_listing(course_id)
    if listing is None:
        raise HTTPException(status_code=404, detail="course_not_found")
    return _catalog_course(listing)


@app.post("/courses/v2/runtime/next")
async def start_course_runtime(request: Request, user_id: str = Depends(_current_user)) -> dict[str, Any]:
    """필요 변수: main 클라이언트가 전송한 course_id와 로그인 사용자. 작동 원리: 공개 코스를
    보유 목록에 멱등 등록하고 main의 data.student_state 응답을 반환해 수강 시작을 즉시 완료한다."""
    try:
        payload = await request.json()
    except (ValueError, json.JSONDecodeError):
        raise HTTPException(status_code=400, detail="invalid_json") from None
    course_id = str(payload.get("course_id") or "").strip() if isinstance(payload, dict) else ""
    listing = _find_catalog_listing(course_id)
    if not course_id or listing is None or listing.get("kind") != "course":
        raise HTTPException(status_code=404, detail="course_not_found")
    owned = _load_owned_marketplace(user_id)
    state = owned.setdefault(
        str(listing["id"]),
        {"progress_index": 0, "status": "in_progress", "completed": False},
    )
    _save_owned_marketplace(user_id, owned)
    student_state = _build_course_runtime_state(str(listing["asset_id"]), state)
    return {
        "data": {
            "status": student_state["status"],
            "next_module_id": student_state["current_module_id"],
            "student_state": student_state,
        }
    }


@app.get("/courses/v2/runtime/state/{course_id}")
def get_course_runtime_state(course_id: str, user_id: str = Depends(_current_user)) -> dict[str, Any]:
    """필요 변수: 코스 asset ID와 보유 KV 상태. 작동 원리: main의 state 경로처럼 마지막
    모듈 위치를 반환해 앱 재진입 때 등록 상태가 초기화되지 않게 한다."""
    listing = _find_catalog_listing(course_id)
    if listing is None or listing.get("kind") != "course":
        raise HTTPException(status_code=404, detail="course_not_found")
    owned = _load_owned_marketplace(user_id)
    state = owned.get(str(listing["id"]))
    if state is None:
        raise HTTPException(status_code=404, detail="course_not_enrolled")
    student_state = _build_course_runtime_state(str(listing["asset_id"]), state)
    return {"data": student_state}


@app.post("/courses/v2/runtime/submit")
async def submit_course_runtime(request: Request, user_id: str = Depends(_current_user)) -> dict[str, Any]:
    """필요 변수: 코스·모듈 ID와 정오답 수. 작동 원리: main의 런타임 제출 형식을 받아
    모듈 완료 여부만 KV 한 행에 갱신하고 다음 모듈 상태를 반환한다."""
    try:
        payload = await request.json()
    except (ValueError, json.JSONDecodeError):
        raise HTTPException(status_code=400, detail="invalid_json") from None
    if not isinstance(payload, dict):
        raise HTTPException(status_code=400, detail="invalid_payload")
    course_id = str(payload.get("course_id") or "").strip()
    listing = _find_catalog_listing(course_id)
    if not course_id or listing is None or listing.get("kind") != "course":
        raise HTTPException(status_code=404, detail="course_not_found")
    total_count = max(1, int(payload.get("total_count") or 0))
    correct_count = max(0, int(payload.get("correct_count") or 0))
    owned = _load_owned_marketplace(user_id)
    state = owned.setdefault(
        str(listing["id"]),
        {"progress_index": 0, "status": "in_progress", "completed": False},
    )
    if correct_count >= total_count:
        state["progress_index"] = int(state.get("progress_index") or 0) + 1
    state["completed"] = int(state.get("progress_index") or 0) >= int(listing["item_count"])
    state["status"] = "completed" if state["completed"] else "in_progress"
    _save_owned_marketplace(user_id, owned)
    student_state = _build_course_runtime_state(str(listing["asset_id"]), state)
    return {"data": {"status": student_state["status"], "student_state": student_state}}


@app.get("/academy/assignments/my")
def list_empty_student_tasks(_user_id: str = Depends(_current_user)) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자. 작동 원리: 배정 과제가 없는 초기 홈 계약을 유지한다."""
    return {"items": []}


_STUDENT_SCHEDULE_STORAGE_KEY = "student.schedule.v1"


def _normalize_student_schedule(tasks_by_date: dict[str, list[str]]) -> dict[str, list[str]]:
    """필요 변수: 날짜별 제목 목록. 작동 원리: 크기·날짜·제목을 제한하고 중복을 제거한다."""
    if len(tasks_by_date) > 366:
        raise HTTPException(status_code=400, detail="Too many schedule dates")
    normalized: dict[str, list[str]] = {}
    task_count = 0
    for date_key, raw_titles in tasks_by_date.items():
        if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", date_key):
            raise HTTPException(status_code=400, detail="Schedule date must be YYYY-MM-DD")
        try:
            date.fromisoformat(date_key)
        except ValueError as error:
            raise HTTPException(status_code=400, detail="Invalid schedule date") from error
        titles: list[str] = []
        for raw_title in raw_titles:
            title = raw_title.strip()
            if not title or len(title) > 60:
                raise HTTPException(status_code=400, detail="Schedule title must be 1-60 characters")
            if title not in titles:
                titles.append(title)
                task_count += 1
                if task_count > 500:
                    raise HTTPException(status_code=400, detail="Too many schedule tasks")
        if titles:
            normalized[date_key] = titles
    return dict(sorted(normalized.items()))


def _student_schedule_items(user_id: str, tasks_by_date: dict[str, list[str]]) -> list[dict[str, str]]:
    """필요 변수: 사용자 ID와 정규화 일정. 작동 원리: 재조회에도 안정적인 일정 ID를 생성한다."""
    return [
        {
            "task_id": hashlib.sha256(f"{user_id}:{date_key}:{index}:{title}".encode()).hexdigest()[:24],
            "date": date_key,
            "title": title,
        }
        for date_key, titles in tasks_by_date.items()
        for index, title in enumerate(titles)
    ]


@app.get("/academy/students/me/schedule")
def get_student_schedule(user_id: str = Depends(_current_user)) -> dict[str, list[dict[str, str]]]:
    """필요 변수: 인증 사용자. 작동 원리: 사용자 KV의 개인 일정 스냅샷을 화면 항목으로 복원한다."""
    raw = get_user_storage(_STUDENT_SCHEDULE_STORAGE_KEY, user_id)["value"]
    if not raw:
        return {"items": []}
    try:
        decoded = json.loads(raw)
        if not isinstance(decoded, dict):
            raise ValueError("schedule snapshot must be an object")
        normalized = _normalize_student_schedule(decoded)
    except (TypeError, ValueError, HTTPException) as error:
        raise HTTPException(status_code=502, detail="Stored schedule is invalid") from error
    return {"items": _student_schedule_items(user_id, normalized)}


@app.put("/academy/students/me/schedule")
def put_student_schedule(
    payload: StudentScheduleSyncRequest,
    user_id: str = Depends(_current_user),
) -> dict[str, bool]:
    """필요 변수: 인증 사용자와 전체 일정. 작동 원리: 검증한 스냅샷을 사용자 복합키에 멱등 upsert한다."""
    normalized = _normalize_student_schedule(payload.tasks_by_date)
    put_user_storage(
        _STUDENT_SCHEDULE_STORAGE_KEY,
        UserStorageRequest(value=json.dumps(normalized, ensure_ascii=False, separators=(",", ":"))),
        user_id,
    )
    return {"success": True}


@app.get("/challenges/daily-quests")
def get_daily_quests(_user_id: str = Depends(_current_user)) -> dict[str, Any]:
    """필요 변수: 인증 사용자. 작동 원리: 코스 미선택 상태의 일일 퀘스트와 계정 기본값을 반환한다."""
    return {"items": [], "account": _empty_account_summary(), "revision": 1}


@app.get("/marketplace/listings")
def list_marketplace_items(
    query: str | None = None,
    kind: str | None = None,
    grade_band: str | None = None,
    price: str | None = None,
    offset: int = 0,
    limit: int = 20,
    _user_id: str = Depends(_current_user),
) -> dict[str, Any]:
    """필요 변수: 검색어·자료 유형·학년·가격·페이지 범위. 작동 원리: 메모리 상주 카탈로그를 필터링하고 최대 50개만 반환해 Vercel DB 부하를 만들지 않는다."""
    normalized_query = (query or "").strip().casefold()
    normalized_grade = (grade_band or "").replace(" ", "")
    safe_offset = max(0, offset)
    safe_limit = min(max(1, limit), 50)

    def matches(item: dict[str, Any]) -> bool:
        """필요 변수: 카탈로그 항목과 정규화된 검색 조건. 작동 원리: 제목·설명·학년·난이도를 한 번씩 비교해 일치 여부를 결정한다."""
        if kind and item["kind"] != kind:
            return False
        if normalized_grade and normalized_grade not in str(item["grade_band"]).replace(" ", ""):
            return False
        if price == "free" and int(item["price_points"]) != 0:
            return False
        if price == "paid" and int(item["price_points"]) <= 0:
            return False
        searchable = " ".join(
            str(item[field]) for field in ("title", "description", "grade_band", "difficulty")
        ).casefold()
        return not normalized_query or normalized_query in searchable

    filtered = sorted(
        (item for item in MARKETPLACE_CATALOG if matches(item)),
        key=lambda item: (-int(item["featured_rank"]), str(item["title"])),
    )
    page = filtered[safe_offset : safe_offset + safe_limit]
    next_offset = safe_offset + len(page)
    return {
        "items": page,
        "total": len(filtered),
        "next_offset": next_offset if next_offset < len(filtered) else None,
    }


@app.get("/marketplace/my-items")
def list_owned_marketplace_items(user_id: str = Depends(_current_user)) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자와 보유 상태. 작동 원리: KV의 상품 ID를 공개 카탈로그와 합쳐 내 학습 목록을 반환한다."""
    owned = _load_owned_marketplace(user_id)
    items = []
    for listing_id, state in owned.items():
        listing = _find_catalog_listing(listing_id)
        if listing is not None:
            items.append({**listing, **state, "owned": True})
    return {"items": items}


@app.get("/marketplace/my-items/{listing_id}/questions")
def get_owned_problem_set_questions(
    listing_id: str,
    user_id: str = Depends(_current_user),
) -> dict[str, list[dict[str, Any]]]:
    """필요 변수: 인증 사용자와 보유 문제세트 ID. 작동 원리: 보유 여부를 한 번 확인한 뒤
    세트 전체 문항을 한 응답으로 반환해 클라이언트의 문항별 직렬 API 요청을 제거한다."""
    listing = _find_catalog_listing(listing_id)
    if listing is None or listing["kind"] != "problem_set":
        raise HTTPException(status_code=404, detail="problem_set_not_found")
    if listing_id not in _load_owned_marketplace(user_id):
        raise HTTPException(status_code=403, detail="purchase_required")
    return {"items": _build_marketplace_questions(listing)}


@app.post("/marketplace/listings/{listing_id}/purchase")
def purchase_marketplace_item(
    listing_id: str,
    user_id: str = Depends(_current_user),
) -> dict[str, Any]:
    """필요 변수: 무료 상품 ID와 인증 사용자. 작동 원리: 가격 차감 없이 KV 보유 목록에 멱등 등록하고 즉시 코스 조회가 가능하게 한다."""
    listing = _find_catalog_listing(listing_id)
    if listing is None:
        raise HTTPException(status_code=404, detail="listing_not_found")
    owned = _load_owned_marketplace(user_id)
    state = owned.setdefault(
        listing["id"],
        {"progress_index": 0, "status": "in_progress", "completed": False},
    )
    _save_owned_marketplace(user_id, owned)
    return {**listing, **state, "owned": True}


@app.post("/marketplace/my-items/{listing_id}/progress")
def update_owned_marketplace_progress(
    listing_id: str,
    payload: MarketplaceProgressRequest,
    user_id: str = Depends(_current_user),
) -> dict[str, Any]:
    """필요 변수: 보유 상품 ID·문제 위치·완료 여부. 작동 원리: 기존 KV 상태 하나만 갱신해 중단 위치와 완료 상태를 저장한다."""
    owned = _load_owned_marketplace(user_id)
    if listing_id not in owned:
        raise HTTPException(status_code=404, detail="purchase_not_found")
    owned[listing_id] = {
        "progress_index": payload.progress_index,
        "status": "completed" if payload.completed else "in_progress",
        "completed": payload.completed,
    }
    _save_owned_marketplace(user_id, owned)
    return owned[listing_id]


def _plain_content_text(value: Any) -> str:
    """콘텐츠 블록·문자열에서 숫자 답과 Flow 문구 검증에 필요한 평문을 추출한다."""
    if value is None:
        return ""
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        return str(value)
    if isinstance(value, str):
        return value.strip()
    if isinstance(value, list):
        return " ".join(filter(None, (_plain_content_text(item) for item in value))).strip()
    if isinstance(value, dict):
        if isinstance(value.get("blocks"), list):
            return _plain_content_text(value["blocks"])
        for key in ("content", "text", "latex"):
            text = _plain_content_text(value.get(key))
            if text:
                return text
    return ""


def _normalize_numeric_answer(value: Any) -> str | None:
    """부호가 있는 정수·소수를 문자열 기준으로 정규화해 부동소수 오차 없이 비교한다."""
    text = _plain_content_text(value).strip().strip("$").strip()
    if not re.fullmatch(r"[+-]?(?:\d+(?:\.\d*)?|\.\d+)", text):
        return None
    negative = text.startswith("-")
    unsigned = text.lstrip("+-")
    whole, _, fraction = unsigned.partition(".")
    whole = whole.lstrip("0") or "0"
    fraction = fraction.rstrip("0")
    normalized = whole if not fraction else f"{whole}.{fraction}"
    if normalized == "0":
        return "0"
    return f"-{normalized}" if negative else normalized


def _flow_step_count(value: Any) -> int:
    """solves 트리의 실제 Flow 문구가 있는 노드 수를 깊이 우선 기준으로 센다."""
    if isinstance(value, list):
        return sum(_flow_step_count(item) for item in value)
    if not isinstance(value, dict):
        return 0
    own = 1 if _plain_content_text(value.get("flow")) else 0
    return own + _flow_step_count(value.get("branches"))


@app.post("/analysis/solve/variant-grade")
async def grade_variant_solve(request: Request, _user_id: str = Depends(_current_user)) -> dict[str, Any]:
    """선택 답 또는 숫자 답과 사용자가 조립한 Flow 순서를 서버 원장에 함께 대조한다."""
    try:
        payload = await request.json()
    except (ValueError, json.JSONDecodeError):
        raise HTTPException(status_code=400, detail="invalid_json") from None
    if not isinstance(payload, dict):
        raise HTTPException(status_code=400, detail="invalid_payload")
    quest_id = str(payload.get("quest_id") or "").strip()
    question = _find_marketplace_question(quest_id)
    if question is None:
        raise HTTPException(status_code=404, detail="Quest not found")
    data = question.get("data", {})
    options = data.get("quest_options")
    is_multiple_choice = isinstance(options, list) and bool(options)
    if is_multiple_choice:
        expected_index = int(data.get("correct_choice_index") or 0)
        selected = payload.get("selected_index")
        answer_correct = (
            isinstance(selected, int)
            and not isinstance(selected, bool)
            and selected == expected_index
        )
        answer_reason = "normal" if answer_correct else "incorrect_choice"
    else:
        expected_answer = _normalize_numeric_answer(data.get("quest_answer"))
        submitted_answer = _normalize_numeric_answer(payload.get("user_answer"))
        answer_correct = expected_answer is not None and submitted_answer == expected_answer
        answer_reason = "normal" if answer_correct else "incorrect_numeric_answer"

    flow_count = _flow_step_count(question.get("solves"))
    submitted_flow = payload.get("flow_order")
    flow_correct = flow_count == 0 or (
        isinstance(submitted_flow, list)
        and all(isinstance(item, int) and not isinstance(item, bool) for item in submitted_flow)
        and submitted_flow == list(range(flow_count))
    )
    raw_correct = answer_correct and flow_correct
    return {
        "quest_id": quest_id,
        "question_type": "multiple_choice" if is_multiple_choice else "short_answer",
        "raw_correct": raw_correct,
        "pass": raw_correct,
        "answer_correct": answer_correct,
        "flow_correct": flow_correct,
        "hints_forbidden": True,
        "reason": "normal" if raw_correct else ("incorrect_flow" if not flow_correct else answer_reason),
    }


@app.post("/analysis/solve")
async def analyze_solve(request: Request, _user_id: str = Depends(_current_user)) -> dict[str, Any]:
    """필요 변수: main 풀이 분석 JSON의 solves 목록. 작동 원리: 카나리에서 무거운 OCR 모델을
    동기 실행하지 않고 제출된 객관식 정답 정보만 즉시 판정해 기존 분석 응답 필드를 유지한다."""
    try:
        payload = await request.json()
    except (ValueError, json.JSONDecodeError):
        raise HTTPException(status_code=400, detail="invalid_json") from None
    if not isinstance(payload, dict):
        raise HTTPException(status_code=400, detail="invalid_payload")
    solves = payload.get("solves") if isinstance(payload.get("solves"), list) else []
    status_items: list[dict[str, Any]] = []
    for solve in solves:
        if not isinstance(solve, dict):
            continue
        quest_id = str(solve.get("quest_id") or solve.get("id") or "").strip()
        question = _find_marketplace_question(quest_id)
        selected = solve.get("selected_index")
        correct = bool(
            question is not None
            and isinstance(selected, int)
            and selected == int(question.get("data", {}).get("correct_choice_index") or 0)
        )
        status_items.append({"quest_id": quest_id, "status": "O" if correct else "X"})
    total = len(status_items)
    correct_count = sum(item["status"] == "O" for item in status_items)
    return {
        "status": status_items,
        "step_correctness": status_items,
        "is_correct": total > 0 and correct_count == total,
        "correct_rate": correct_count / total if total else 0.0,
        "total_solved": total,
        "total_correct": correct_count,
        "weak_tags": [],
        "ai_opinion": "객관식 답안을 기준으로 즉시 채점했습니다.",
        "warnings": ["이미지 OCR 채점은 카나리 큐에서 별도로 처리됩니다."] if not solves else [],
    }


_SOLVE_HISTORY_PREFIX = "solve_history."


@app.post("/history/solve")
def save_solve_history(
    payload: SolveHistoryCreateRequest,
    user_id: str = Depends(_current_user),
) -> dict[str, Any]:
    """필요 변수: 인증 사용자와 정오답. 작동 원리: 시도마다 별도 KV 행을 추가해 동시 제출도 잃지 않는다."""
    item = {
        "created_at": datetime.now(timezone.utc).isoformat(),
        "kind": "problem",
        "quest_id": payload.quest_id.strip(),
        "codebase_id": payload.codebase_id,
        "seed": payload.seed,
        "data": {
            "is_correct": payload.is_correct,
            "tags": [tag.strip()[:100] for tag in payload.tags if tag.strip()],
        },
    }
    try:
        _data_api().request(
            "POST",
            "canary_user_kv",
            query={"on_conflict": "user_id,key"},
            body={
                "user_id": user_id,
                "key": f"{_SOLVE_HISTORY_PREFIX}{time.time_ns()}.{uuid.uuid4().hex}",
                "value": json.dumps(item, ensure_ascii=False, separators=(",", ":")),
            },
            prefer="resolution=merge-duplicates,return=minimal",
        )
    except RuntimeError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error
    return {"item": item}


@app.get("/history/solve")
def list_solve_history(
    days: int = 30,
    kind: str | None = None,
    limit: int = 100,
    user_id: str = Depends(_current_user),
) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자와 조회 범위. 작동 원리: 사용자 KV의 최근 풀이만 역순으로 반환한다."""
    bounded_days = min(max(days, 1), 365)
    bounded_limit = min(max(limit, 1), 200)
    try:
        rows = _data_api().request(
            "GET",
            "canary_user_kv",
            query={
                "select": "key,value",
                "user_id": f"eq.{user_id}",
                "key": f"like.{_SOLVE_HISTORY_PREFIX}*",
                "limit": "200",
            },
        ) or []
    except RuntimeError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error
    cutoff = datetime.now(timezone.utc) - timedelta(days=bounded_days)
    items: list[dict[str, Any]] = []
    for row in rows:
        try:
            item = json.loads(str(row.get("value") or ""))
            created_at = datetime.fromisoformat(str(item.get("created_at") or ""))
            if created_at.tzinfo is None:
                created_at = created_at.replace(tzinfo=timezone.utc)
        except (AttributeError, TypeError, ValueError, json.JSONDecodeError):
            continue
        if not isinstance(item, dict) or created_at < cutoff:
            continue
        if kind and item.get("kind") != kind:
            continue
        items.append(item)
    seen_quest_ids = {str(item.get("quest_id") or "") for item in items}
    try:
        sessions = _data_api().request(
            "GET",
            "level_test_session",
            query={
                "select": "session_id,started_at",
                "user_id": f"eq.{user_id}",
                "started_at": f"gte.{cutoff.isoformat()}",
                "order": "started_at.desc",
                "limit": "20",
            },
        ) or []
        session_ids = [str(row.get("session_id") or "") for row in sessions if row.get("session_id")]
        legacy_answers = (
            _data_api().request(
                "GET",
                "level_test_answer",
                query={
                    "select": "quest_id,is_correct,tags,submitted_at",
                    "session_id": f"in.({','.join(session_ids)})",
                    "order": "submitted_at.desc",
                    "limit": "200",
                },
            ) or []
            if session_ids
            else []
        )
    except RuntimeError:
        legacy_answers = []
    for answer in legacy_answers:
        quest_id = str(answer.get("quest_id") or "").strip()
        if not quest_id or quest_id in seen_quest_ids:
            continue
        tags = answer.get("tags") if isinstance(answer.get("tags"), list) else []
        items.append(
            {
                "created_at": str(answer.get("submitted_at") or datetime.now(timezone.utc).isoformat()),
                "kind": "problem",
                "quest_id": quest_id,
                "codebase_id": None,
                "seed": None,
                "data": {"is_correct": bool(answer.get("is_correct")), "tags": tags},
            }
        )
        seen_quest_ids.add(quest_id)
    items.sort(key=lambda item: str(item.get("created_at") or ""), reverse=True)
    return {"items": items[:bounded_limit]}


_SOCIAL_FRIEND_PREFIX = "social.friend."
_SOCIAL_REQUEST_IN_PREFIX = "social.friend_request.in."
_SOCIAL_REQUEST_OUT_PREFIX = "social.friend_request.out."
_SOCIAL_GROUP_PREFIX = "social.study_group."
_SOCIAL_GROUP_MEMBER_PREFIX = "social.study_member."
_SOCIAL_GROUP_MESSAGE_PREFIX = "social.study_group_message."
_SOCIAL_MESSAGE_PREFIX = "social.message."
_SOCIAL_CONVERSATION_PREFIX = "social.conversation."
_SOCIAL_MESSAGE_LIMIT = 200
_SOCIAL_GROUP_MESSAGE_LIMIT = 500


def _social_data_request(method: str, path: str, **kwargs: Any) -> Any:
    """필요 변수: 제한된 Data API 요청. 작동 원리: 내부 저장 오류를 공개 정보 없는 502로 변환한다."""
    try:
        return _data_api().request(method, path, **kwargs)
    except RuntimeError as error:
        raise HTTPException(status_code=502, detail="Social storage unavailable") from error


def _social_public_profile(row: dict[str, Any]) -> dict[str, Any]:
    """필요 변수: canary_users 행. 작동 원리: 친구 화면에 필요한 공개 열만 반환한다."""
    return {
        "user_id": str(row.get("user_id") or ""),
        "username": str(row.get("username") or ""),
        "name": row.get("name"),
        "profile_image": row.get("profile_image"),
        "ovr": 0,
        "status": "",
    }


def _social_user_by_username(username: str) -> dict[str, Any] | None:
    rows = _social_data_request(
        "GET",
        "canary_users",
        query={
            "select": "user_id,username,name,profile_image",
            "username": f"eq.{username}",
            "limit": "1",
        },
    ) or []
    return dict(rows[0]) if rows else None


def _social_user_by_id(user_id: str) -> dict[str, Any] | None:
    rows = _social_data_request(
        "GET",
        "canary_users",
        query={
            "select": "user_id,username,name,profile_image",
            "user_id": f"eq.{user_id}",
            "limit": "1",
        },
    ) or []
    return dict(rows[0]) if rows else None


def _social_kv_rows(user_id: str, prefix: str, *, limit: int = 200) -> list[dict[str, Any]]:
    rows = _social_data_request(
        "GET",
        "canary_user_kv",
        query={
            "select": "key,value",
            "user_id": f"eq.{user_id}",
            "key": f"like.{prefix}*",
            "limit": str(max(1, min(limit, 1000))),
        },
    ) or []
    return [dict(row) for row in rows]


def _social_kv_value(row: dict[str, Any]) -> dict[str, Any] | None:
    try:
        decoded = json.loads(str(row.get("value") or ""))
    except (TypeError, ValueError):
        return None
    return dict(decoded) if isinstance(decoded, dict) else None


def _social_group_for_user(user_id: str, group_id: str) -> dict[str, Any] | None:
    rows = _social_data_request(
        "GET",
        "canary_user_kv",
        query={
            "select": "key,value",
            "user_id": f"eq.{user_id}",
            "key": f"eq.{_SOCIAL_GROUP_PREFIX}{group_id}",
            "limit": "1",
        },
    ) or []
    return _social_kv_value(dict(rows[0])) if rows else None


def _social_global_group_rows(*, key: str | None = None, value_query: str | None = None, limit: int = 200) -> list[dict[str, Any]]:
    query = {
        "select": "user_id,key,value",
        "key": f"eq.{key}" if key else f"like.{_SOCIAL_GROUP_PREFIX}*",
        "limit": str(limit),
    }
    if value_query:
        query["value"] = f"ilike.*{value_query}*"
    rows = _social_data_request("GET", "canary_user_kv", query=query) or []
    return [dict(row) for row in rows]


def _social_canonical_group(group_id: str) -> dict[str, Any] | None:
    fallback: dict[str, Any] | None = None
    for row in _social_global_group_rows(key=f"{_SOCIAL_GROUP_PREFIX}{group_id}"):
        group = _social_kv_value(row)
        if not group:
            continue
        fallback = fallback or group
        if str(row.get("user_id") or "") == str(group.get("creator_id") or ""):
            return group
    return fallback


def _social_group_member_ids(group: dict[str, Any]) -> list[str]:
    group_id = str(group.get("group_id") or "")
    rows = _social_data_request(
        "GET",
        "canary_user_kv",
        query={
            "select": "user_id",
            "key": f"eq.{_SOCIAL_GROUP_MEMBER_PREFIX}{group_id}",
            "limit": "101",
        },
    ) or []
    ids = {str(value) for value in group.get("member_ids") or [] if str(value)}
    ids.update(str(row.get("user_id") or "") for row in rows if row.get("user_id"))
    return sorted(ids)


def _social_public_group(group: dict[str, Any]) -> dict[str, Any]:
    member_ids = _social_group_member_ids(group)
    return {
        key: value
        for key, value in {**group, "member_ids": member_ids, "members": len(member_ids)}.items()
        if key not in {"password_salt", "password_hash"}
    }


def _social_add_group_member(group: dict[str, Any], user_id: str) -> dict[str, Any]:
    group_id = str(group.get("group_id") or "")
    member_ids = _social_group_member_ids(group)
    if user_id in member_ids:
        existing = _social_group_for_user(user_id, group_id)
        return _social_public_group(existing or group)
    if len(member_ids) >= int(group.get("max_members") or 0):
        raise HTTPException(status_code=409, detail="Group is full")
    if len(_social_kv_rows(user_id, _SOCIAL_GROUP_PREFIX)) >= 3:
        raise HTTPException(status_code=409, detail="User reached max groups")
    joined_at = datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")
    next_member_ids = [*member_ids, user_id]
    _social_upsert_kv_rows(
        [
            (
                user_id,
                f"{_SOCIAL_GROUP_MEMBER_PREFIX}{group_id}",
                {"group_id": group_id, "joined_at": joined_at},
            ),
            (
                user_id,
                f"{_SOCIAL_GROUP_PREFIX}{group_id}",
                {**group, "member_ids": next_member_ids, "members": len(next_member_ids)},
            ),
        ]
    )
    return _social_public_group({**group, "member_ids": next_member_ids})


def _social_join_group(group: dict[str, Any], user_id: str, password: str | None) -> dict[str, Any]:
    member_ids = _social_group_member_ids(group)
    if user_id in member_ids:
        existing = _social_group_for_user(user_id, str(group.get("group_id") or ""))
        return _social_public_group(existing or group)
    if group.get("lock_enabled"):
        supplied = (password or "").strip()
        expected = str(group.get("password_hash") or "")
        salt = str(group.get("password_salt") or "")
        if not supplied or not expected or not hmac.compare_digest(_hash_password(supplied, salt), expected):
            raise HTTPException(status_code=400, detail="Invalid group password")
    return _social_add_group_member(group, user_id)


def _social_upsert_kv(user_id: str, key: str, value: dict[str, Any]) -> None:
    _social_data_request(
        "POST",
        "canary_user_kv",
        query={"on_conflict": "user_id,key"},
        body={
            "user_id": user_id,
            "key": key,
            "value": json.dumps(value, ensure_ascii=False, separators=(",", ":")),
        },
        prefer="resolution=merge-duplicates,return=minimal",
    )


def _social_upsert_kv_rows(rows: list[tuple[str, str, dict[str, Any]]]) -> None:
    """필요 변수: 여러 사용자 KV 행. 작동 원리: 한 PostgREST 요청으로 송수신 메시지와 대화 요약을 함께 커밋한다."""
    _social_data_request(
        "POST",
        "canary_user_kv",
        query={"on_conflict": "user_id,key"},
        body=[
            {
                "user_id": user_id,
                "key": key,
                "value": json.dumps(value, ensure_ascii=False, separators=(",", ":")),
            }
            for user_id, key, value in rows
        ],
        prefer="resolution=merge-duplicates,return=minimal",
    )


def _social_delete_kv(user_id: str, key: str) -> None:
    _social_data_request(
        "DELETE",
        "canary_user_kv",
        query={"user_id": f"eq.{user_id}", "key": f"eq.{key}"},
        prefer="return=minimal",
    )


def _social_group_message_rows(group_id: str) -> list[dict[str, Any]]:
    rows = _social_data_request(
        "GET",
        "canary_user_kv",
        query={
            "select": "user_id,key,value",
            "key": f"like.{_SOCIAL_GROUP_MESSAGE_PREFIX}{group_id}.*",
            "limit": str(_SOCIAL_GROUP_MESSAGE_LIMIT + 1),
        },
    ) or []
    return [dict(row) for row in rows]


def _social_group_messages(group_id: str) -> list[dict[str, Any]]:
    messages = [
        value
        for row in _social_group_message_rows(group_id)
        if (value := _social_kv_value(row))
    ]
    messages.sort(key=lambda item: (str(item.get("created_at") or ""), str(item.get("message_id") or "")))
    return messages


def _social_has_key(user_id: str, key: str) -> bool:
    rows = _social_data_request(
        "GET",
        "canary_user_kv",
        query={
            "select": "key",
            "user_id": f"eq.{user_id}",
            "key": f"eq.{key}",
            "limit": "1",
        },
    ) or []
    return bool(rows)


def _social_find_request(user_id: str, request_id: str, direction: str) -> tuple[dict[str, Any], str] | None:
    prefix = _SOCIAL_REQUEST_IN_PREFIX if direction == "incoming" else _SOCIAL_REQUEST_OUT_PREFIX
    for row in _social_kv_rows(user_id, prefix):
        value = _social_kv_value(row)
        if value and str(value.get("request_id") or value.get("id") or "") == request_id:
            return value, str(row.get("key") or "")
    return None


def _social_request_response(value: dict[str, Any]) -> dict[str, Any]:
    return {
        "request_id": str(value.get("request_id") or value.get("id") or ""),
        "id": str(value.get("request_id") or value.get("id") or ""),
        "from_user_id": str(value.get("from_user_id") or ""),
        "to_user_id": str(value.get("to_user_id") or ""),
        "status": str(value.get("status") or "pending"),
        "username": str(value.get("peer_username") or ""),
        "direction": str(value.get("direction") or "incoming"),
        "message": value.get("message"),
        "created_at": value.get("created_at"),
    }


def _social_message_response(value: dict[str, Any]) -> dict[str, Any]:
    """필요 변수: 사용자별 메시지 KV. 작동 원리: Flutter DirectMessage 계약의 공개 필드만 반환한다."""
    return {
        "id": str(value.get("id") or value.get("message_id") or ""),
        "from": str(value.get("from") or ""),
        "to": str(value.get("to") or ""),
        "text": str(value.get("text") or ""),
        "created_at": str(value.get("created_at") or ""),
        "is_mine": value.get("is_mine") is True,
        "is_read": value.get("is_read") is True,
    }


def _social_trim_messages(user_id: str, peer_id: str) -> None:
    """필요 변수: 사용자·대화 상대 ID. 작동 원리: 최신 200개를 넘는 사용자별 쪽지만 오래된 순서로 제거한다."""
    prefix = f"{_SOCIAL_MESSAGE_PREFIX}{peer_id}."
    rows = _social_kv_rows(user_id, prefix, limit=_SOCIAL_MESSAGE_LIMIT + 1)
    if len(rows) <= _SOCIAL_MESSAGE_LIMIT:
        return
    decoded = [
        (str((_social_kv_value(row) or {}).get("created_at") or ""), str(row.get("key") or ""))
        for row in rows
    ]
    decoded.sort()
    for _, key in decoded[: len(decoded) - _SOCIAL_MESSAGE_LIMIT]:
        if key:
            _social_delete_kv(user_id, key)


@app.post("/social/friends/search")
def search_friends(payload: FriendSearchRequest, user_id: str = Depends(_current_user)) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자와 사용자명 일부. 작동 원리: 본인을 제외한 공개 프로필을 최대 50개 검색한다."""
    query = payload.query.strip()
    if not re.fullmatch(r"[A-Za-z0-9]{1,16}", query):
        return {"users": []}
    rows = _social_data_request(
        "GET",
        "canary_users",
        query={
            "select": "user_id,username,name,profile_image",
            "username": f"ilike.*{query}*",
            "user_id": f"neq.{user_id}",
            "order": "username.asc",
            "limit": str(payload.limit),
        },
    ) or []
    return {"users": [_social_public_profile(dict(row)) for row in rows]}


@app.get("/social/friends")
def list_friends(user_id: str = Depends(_current_user)) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자. 작동 원리: 사용자별 멱등 친구 표식에서 현재 공개 프로필을 복원한다."""
    friends: list[dict[str, Any]] = []
    seen: set[str] = set()
    for row in _social_kv_rows(user_id, _SOCIAL_FRIEND_PREFIX):
        peer_id = str(row.get("key") or "").removeprefix(_SOCIAL_FRIEND_PREFIX)
        if not peer_id or peer_id in seen:
            continue
        seen.add(peer_id)
        peer = _social_user_by_id(peer_id)
        if peer:
            friends.append(_social_public_profile(peer))
    friends.sort(key=lambda item: str(item.get("username") or "").lower())
    return {"friends": friends}


@app.get("/social/friend-requests")
def list_friend_requests(user_id: str = Depends(_current_user)) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자. 작동 원리: 수신·발신 대기 요청을 하나의 시간순 목록으로 반환한다."""
    requests: list[dict[str, Any]] = []
    seen: set[str] = set()
    for prefix in (_SOCIAL_REQUEST_IN_PREFIX, _SOCIAL_REQUEST_OUT_PREFIX):
        for row in _social_kv_rows(user_id, prefix):
            value = _social_kv_value(row)
            if not value:
                continue
            request_id = str(value.get("request_id") or value.get("id") or "")
            if not request_id or request_id in seen:
                continue
            seen.add(request_id)
            requests.append(_social_request_response(value))
    requests.sort(key=lambda item: str(item.get("created_at") or ""), reverse=True)
    return {"requests": requests}


@app.post("/social/friend-requests", status_code=status.HTTP_201_CREATED)
def create_friend_request(payload: FriendRequestCreateRequest, user_id: str = Depends(_current_user)) -> dict[str, Any]:
    """필요 변수: 인증 사용자와 대상 사용자명. 작동 원리: 양쪽 KV에 같은 결정적 요청을 보상 가능한 순서로 저장한다."""
    target = _social_user_by_username(payload.username.strip())
    if not target:
        raise HTTPException(status_code=404, detail="User not found")
    target_id = str(target.get("user_id") or "")
    if target_id == user_id:
        raise HTTPException(status_code=400, detail="Cannot add yourself")
    if _social_has_key(user_id, f"{_SOCIAL_FRIEND_PREFIX}{target_id}"):
        raise HTTPException(status_code=409, detail="Already friends")
    if _social_has_key(user_id, f"{_SOCIAL_REQUEST_IN_PREFIX}{target_id}"):
        raise HTTPException(status_code=409, detail="Incoming request already exists")

    current = _social_user_by_id(user_id)
    if not current:
        raise HTTPException(status_code=404, detail="Current user not found")
    request_id = str(uuid.uuid5(uuid.NAMESPACE_URL, f"aiflow-friend-request:{user_id}:{target_id}"))
    created_at = datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")
    common = {
        "request_id": request_id,
        "id": request_id,
        "from_user_id": user_id,
        "to_user_id": target_id,
        "status": "pending",
        "message": (payload.message or "").strip(),
        "created_at": created_at,
    }
    outgoing = {**common, "direction": "outgoing", "peer_username": str(target.get("username") or "")}
    incoming = {**common, "direction": "incoming", "peer_username": str(current.get("username") or "")}
    outgoing_key = f"{_SOCIAL_REQUEST_OUT_PREFIX}{target_id}"
    incoming_key = f"{_SOCIAL_REQUEST_IN_PREFIX}{user_id}"
    _social_upsert_kv(user_id, outgoing_key, outgoing)
    try:
        _social_upsert_kv(target_id, incoming_key, incoming)
    except HTTPException:
        _social_delete_kv(user_id, outgoing_key)
        raise
    return _social_request_response(outgoing)


@app.post("/social/friend-requests/{request_id}/accept")
def accept_friend_request(request_id: str, user_id: str = Depends(_current_user)) -> dict[str, Any]:
    """필요 변수: 수신 대기 요청 ID. 작동 원리: 양쪽 친구 표식을 먼저 저장한 뒤 대기 요청을 제거한다."""
    found = _social_find_request(user_id, request_id, "incoming")
    if not found:
        raise HTTPException(status_code=404, detail="Request not found")
    request, own_request_key = found
    peer_id = str(request.get("from_user_id") or "")
    peer = _social_user_by_id(peer_id)
    if not peer:
        raise HTTPException(status_code=404, detail="User not found")
    created_at = datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")
    _social_upsert_kv_rows(
        [
            (
                user_id,
                f"{_SOCIAL_FRIEND_PREFIX}{peer_id}",
                {"friend_id": peer_id, "created_at": created_at},
            ),
            (
                peer_id,
                f"{_SOCIAL_FRIEND_PREFIX}{user_id}",
                {"friend_id": user_id, "created_at": created_at},
            ),
        ]
    )
    _social_delete_kv(user_id, own_request_key)
    _social_delete_kv(peer_id, f"{_SOCIAL_REQUEST_OUT_PREFIX}{user_id}")
    return _social_public_profile(peer)


def _close_friend_request(request_id: str, user_id: str, direction: str, status_value: str) -> dict[str, Any]:
    found = _social_find_request(user_id, request_id, direction)
    if not found:
        raise HTTPException(status_code=404, detail="Request not found")
    request, own_key = found
    peer_id = str(request.get("from_user_id") if direction == "incoming" else request.get("to_user_id") or "")
    peer_prefix = _SOCIAL_REQUEST_OUT_PREFIX if direction == "incoming" else _SOCIAL_REQUEST_IN_PREFIX
    _social_delete_kv(user_id, own_key)
    if peer_id:
        _social_delete_kv(peer_id, f"{peer_prefix}{user_id}")
    return _social_request_response({**request, "status": status_value})


@app.post("/social/friend-requests/{request_id}/decline")
def decline_friend_request(request_id: str, user_id: str = Depends(_current_user)) -> dict[str, Any]:
    return _close_friend_request(request_id, user_id, "incoming", "declined")


@app.post("/social/friend-requests/{request_id}/cancel")
def cancel_friend_request(request_id: str, user_id: str = Depends(_current_user)) -> dict[str, Any]:
    return _close_friend_request(request_id, user_id, "outgoing", "cancelled")


@app.post("/social/friends/remove")
def remove_friend(payload: FriendTargetRequest, user_id: str = Depends(_current_user)) -> dict[str, str]:
    target = _social_user_by_username(payload.username.strip())
    if not target:
        raise HTTPException(status_code=404, detail="User not found")
    target_id = str(target.get("user_id") or "")
    _social_delete_kv(user_id, f"{_SOCIAL_FRIEND_PREFIX}{target_id}")
    _social_delete_kv(target_id, f"{_SOCIAL_FRIEND_PREFIX}{user_id}")
    return {"status": "removed"}


@app.get("/social/friends/rankings")
def list_friend_rankings(_user_id: str = Depends(_current_user)) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자. 작동 원리: 친구 랭킹이 없는 초기 상태를 반환한다."""
    return {"ranks": []}


@app.get("/social/messages")
def list_direct_messages(
    peer: str,
    limit: int = 30,
    before: str | None = None,
    user_id: str = Depends(_current_user),
) -> dict[str, list[Any]]:
    """필요 변수: 친구 사용자명·페이지 제한·선택 기준 ID. 작동 원리: 사용자별 KV에서 해당 대화를 시간순으로 반환한다."""
    peer_user = _social_user_by_username(peer.strip())
    if not peer_user:
        raise HTTPException(status_code=404, detail="Peer not found")
    peer_id = str(peer_user.get("user_id") or "")
    rows = _social_kv_rows(
        user_id,
        f"{_SOCIAL_MESSAGE_PREFIX}{peer_id}.",
        limit=_SOCIAL_MESSAGE_LIMIT,
    )
    messages = [value for row in rows if (value := _social_kv_value(row))]
    messages.sort(key=lambda item: (str(item.get("created_at") or ""), str(item.get("id") or "")))
    if before:
        before_index = next(
            (index for index, item in enumerate(messages) if str(item.get("id") or "") == before),
            len(messages),
        )
        messages = messages[:before_index]
    bounded_limit = max(1, min(limit, 100))
    conversation_rows = _social_kv_rows(user_id, f"{_SOCIAL_CONVERSATION_PREFIX}{peer_id}", limit=1)
    conversation = _social_kv_value(conversation_rows[0]) if conversation_rows else None
    if conversation and conversation.get("is_read") is not True:
        _social_upsert_kv(
            user_id,
            f"{_SOCIAL_CONVERSATION_PREFIX}{peer_id}",
            {**conversation, "is_read": True},
        )
    return {"messages": [_social_message_response(item) for item in messages[-bounded_limit:]]}


@app.post("/social/messages")
def send_direct_message(
    payload: DirectMessageCreateRequest,
    user_id: str = Depends(_current_user),
) -> dict[str, Any]:
    """필요 변수: 인증 사용자·친구 사용자명·본문. 작동 원리: 송수신 메시지와 양쪽 대화 요약을 한 번의 DB 요청으로 저장한다."""
    text = payload.text.strip()
    if not text:
        raise HTTPException(status_code=400, detail="Text is required")
    peer = _social_user_by_username(payload.peer.strip())
    if not peer:
        raise HTTPException(status_code=404, detail="Peer not found")
    peer_id = str(peer.get("user_id") or "")
    if peer_id == user_id:
        raise HTTPException(status_code=400, detail="Cannot message yourself")
    if not _social_has_key(user_id, f"{_SOCIAL_FRIEND_PREFIX}{peer_id}"):
        raise HTTPException(status_code=403, detail="Friends only")
    current = _social_user_by_id(user_id)
    if not current:
        raise HTTPException(status_code=404, detail="Current user not found")

    sender = str(current.get("username") or "")
    receiver = str(peer.get("username") or "")
    message_id = str(uuid.uuid4())
    created_at = datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")
    suffix = f"{time.time_ns():020d}.{message_id}"
    common = {
        "id": message_id,
        "message_id": message_id,
        "from": sender,
        "to": receiver,
        "text": text,
        "created_at": created_at,
    }
    sender_message = {**common, "peer_id": peer_id, "is_mine": True, "is_read": True}
    receiver_message = {**common, "peer_id": user_id, "is_mine": False, "is_read": False}
    _social_upsert_kv_rows(
        [
            (user_id, f"{_SOCIAL_MESSAGE_PREFIX}{peer_id}.{suffix}", sender_message),
            (peer_id, f"{_SOCIAL_MESSAGE_PREFIX}{user_id}.{suffix}", receiver_message),
            (user_id, f"{_SOCIAL_CONVERSATION_PREFIX}{peer_id}", sender_message),
            (peer_id, f"{_SOCIAL_CONVERSATION_PREFIX}{user_id}", receiver_message),
        ]
    )
    _social_trim_messages(user_id, peer_id)
    _social_trim_messages(peer_id, user_id)
    return _social_message_response(sender_message)


@app.post("/social/messages/{peer}/delete")
def delete_direct_message_thread(peer: str, user_id: str = Depends(_current_user)) -> dict[str, str]:
    """필요 변수: 인증 사용자와 대화 상대. 작동 원리: 요청한 사용자의 메시지 사본과 대화 요약만 제거한다."""
    peer_user = _social_user_by_username(peer.strip())
    if not peer_user:
        raise HTTPException(status_code=404, detail="Peer not found")
    peer_id = str(peer_user.get("user_id") or "")
    for row in _social_kv_rows(user_id, f"{_SOCIAL_MESSAGE_PREFIX}{peer_id}.", limit=_SOCIAL_MESSAGE_LIMIT):
        key = str(row.get("key") or "")
        if key:
            _social_delete_kv(user_id, key)
    _social_delete_kv(user_id, f"{_SOCIAL_CONVERSATION_PREFIX}{peer_id}")
    return {"status": "deleted"}


@app.get("/social/conversations")
def list_conversations(
    limit: int = 15,
    before: str | None = None,
    user_id: str = Depends(_current_user),
) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자와 페이지 기준. 작동 원리: 상대별 최신 대화 요약을 최근순으로 반환한다."""
    summaries = [
        value
        for row in _social_kv_rows(user_id, _SOCIAL_CONVERSATION_PREFIX)
        if (value := _social_kv_value(row))
    ]
    if before:
        summaries = [item for item in summaries if str(item.get("created_at") or "") < before]
    summaries.sort(key=lambda item: str(item.get("created_at") or ""), reverse=True)
    bounded_limit = max(1, min(limit, 100))
    return {"messages": [_social_message_response(item) for item in summaries[:bounded_limit]]}


@app.post("/social/study-groups", status_code=status.HTTP_201_CREATED)
def create_study_group(payload: StudyGroupCreateRequest, user_id: str = Depends(_current_user)) -> dict[str, Any]:
    """필요 변수: 인증 사용자와 검증된 그룹 입력. 작동 원리: 기존 사용자 KV에 생성자 멤버십을 포함한 그룹을 한 번 저장한다."""
    name = payload.name.strip()
    if not name:
        raise HTTPException(status_code=422, detail="Group name is required")
    password = (payload.password or "").strip()
    if payload.lock_enabled and not re.fullmatch(r"\d{4,10}", password):
        raise HTTPException(status_code=422, detail="Password must be 4 to 10 digits")
    group_id = str(uuid.uuid4())
    created_at = datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")
    invite_code = (payload.invite_code or "").strip().upper() or secrets.token_hex(4).upper()
    group: dict[str, Any] = {
        "group_id": group_id,
        "name": name,
        "description": (payload.description or "").strip(),
        "max_members": payload.max_members,
        "is_public": payload.is_public,
        "logo_index": payload.logo_index,
        "lock_enabled": payload.lock_enabled,
        "owner_role": "student",
        "invite_code": invite_code,
        "is_teacher_group": False,
        "created_at": created_at,
        "creator_id": user_id,
        "member_ids": [user_id],
        "members": 1,
    }
    if payload.lock_enabled:
        salt = secrets.token_hex(16)
        group["password_salt"] = salt
        group["password_hash"] = _hash_password(password, salt)
    _social_upsert_kv(user_id, f"{_SOCIAL_GROUP_PREFIX}{group_id}", group)
    try:
        _social_upsert_kv(
            user_id,
            f"{_SOCIAL_GROUP_MEMBER_PREFIX}{group_id}",
            {"group_id": group_id, "joined_at": created_at},
        )
    except HTTPException:
        _social_delete_kv(user_id, f"{_SOCIAL_GROUP_PREFIX}{group_id}")
        raise
    return _social_public_group(group)


@app.get("/social/study-groups/mine")
def list_my_study_groups(user_id: str = Depends(_current_user)) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자. 작동 원리: 사용자 KV의 그룹만 복원해 Flutter의 groups 계약으로 반환한다."""
    groups: list[dict[str, Any]] = []
    for row in _social_kv_rows(user_id, _SOCIAL_GROUP_PREFIX):
        value = _social_kv_value(row)
        if not value:
            continue
        groups.append(_social_public_group(value))
    groups.sort(key=lambda item: str(item.get("created_at") or ""), reverse=True)
    return {"groups": groups}


@app.get("/social/study-groups/search")
def search_study_groups(q: str, limit: int = 20, user_id: str = Depends(_current_user)) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자와 그룹명 일부. 작동 원리: 공개 그룹 KV를 이름으로 제한 검색하고 이미 가입한 그룹은 제외한다."""
    keyword = q.strip()
    if not re.fullmatch(r"[가-힣A-Za-z0-9 _-]{1,80}", keyword):
        return {"groups": []}
    bounded_limit = max(1, min(limit, 50))
    groups: list[dict[str, Any]] = []
    seen: set[str] = set()
    for row in _social_global_group_rows(value_query=keyword, limit=max(100, bounded_limit * 10)):
        group = _social_kv_value(row)
        group_id = str((group or {}).get("group_id") or "")
        if (
            not group
            or not group_id
            or group_id in seen
            or not group.get("is_public")
            or keyword.casefold() not in str(group.get("name") or "").casefold()
            or user_id in _social_group_member_ids(group)
        ):
            continue
        seen.add(group_id)
        groups.append(_social_public_group(group))
        if len(groups) >= bounded_limit:
            break
    return {"groups": groups}


@app.get("/social/study-groups/invite/{invite_code}")
def get_study_group_invite(invite_code: str, _user_id: str = Depends(_current_user)) -> dict[str, Any]:
    code = invite_code.strip().upper()
    if not re.fullmatch(r"[A-Z0-9-]{4,20}", code):
        raise HTTPException(status_code=404, detail="Invite code not found")
    for row in _social_global_group_rows(value_query=code, limit=50):
        group = _social_kv_value(row)
        if group and str(group.get("invite_code") or "").upper() == code:
            public = _social_public_group(group)
            return {
                "group_id": public["group_id"],
                "name": public["name"],
                "description": public.get("description") or "",
                "max_members": public["max_members"],
                "members": public["members"],
                "lock_enabled": bool(public.get("lock_enabled")),
                "owner_role": public.get("owner_role") or "student",
                "is_teacher_group": bool(public.get("is_teacher_group")),
                "invite_code": code,
            }
    raise HTTPException(status_code=404, detail="Invite code not found")


@app.post("/social/study-groups/join-by-code")
def join_study_group_by_code(payload: StudyGroupJoinByCodeRequest, user_id: str = Depends(_current_user)) -> dict[str, Any]:
    code = payload.invite_code.strip().upper()
    if not re.fullmatch(r"[A-Z0-9-]{4,20}", code):
        raise HTTPException(status_code=404, detail="Invite code not found")
    for row in _social_global_group_rows(value_query=code, limit=50):
        group = _social_kv_value(row)
        if group and str(group.get("invite_code") or "").upper() == code:
            return _social_join_group(group, user_id, payload.password)
    raise HTTPException(status_code=404, detail="Invite code not found")


@app.post("/social/study-groups/{group_id}/join")
def join_study_group(group_id: str, payload: StudyGroupJoinRequest, user_id: str = Depends(_current_user)) -> dict[str, Any]:
    group = _social_canonical_group(group_id)
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")
    return _social_join_group(group, user_id, payload.password)


@app.get("/social/study-groups/{group_id}/members")
def list_study_group_members(group_id: str, user_id: str = Depends(_current_user)) -> list[dict[str, str]]:
    """필요 변수: 인증 사용자와 소속 그룹 ID. 작동 원리: 사용자 KV의 그룹 멤버 ID를 공개 프로필로 복원한다."""
    group = _social_group_for_user(user_id, group_id)
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")
    members: list[dict[str, str]] = []
    for member_id in _social_group_member_ids(group):
        profile = _social_user_by_id(str(member_id))
        if profile:
            members.append({"user_id": str(member_id), "username": str(profile.get("username") or member_id)})
    return members


@app.post("/social/study-groups/{group_id}/invite-friend")
def invite_friend_to_study_group(
    group_id: str,
    payload: StudyGroupFriendInviteRequest,
    user_id: str = Depends(_current_user),
) -> dict[str, Any]:
    group = _social_group_for_user(user_id, group_id)
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")
    friend = _social_user_by_username(payload.username.strip())
    if not friend:
        raise HTTPException(status_code=404, detail="Friend not found")
    friend_id = str(friend.get("user_id") or "")
    if friend_id == user_id or not _social_has_key(user_id, f"{_SOCIAL_FRIEND_PREFIX}{friend_id}"):
        raise HTTPException(status_code=403, detail="Only your friends can be invited")
    canonical = _social_canonical_group(group_id)
    if not canonical:
        raise HTTPException(status_code=404, detail="Group not found")
    return _social_add_group_member(canonical, friend_id)


@app.get("/social/study-groups/{group_id}/messages")
def list_study_group_messages(
    group_id: str,
    limit: int = 30,
    before: str | None = None,
    user_id: str = Depends(_current_user),
) -> dict[str, list[Any]]:
    if not _social_group_for_user(user_id, group_id):
        raise HTTPException(status_code=404, detail="Group not found")
    messages = _social_group_messages(group_id)
    if before:
        messages = [item for item in messages if str(item.get("created_at") or "") < before]
    bounded_limit = max(1, min(limit, 100))
    return {"messages": messages[-bounded_limit:]}


@app.post("/social/study-groups/{group_id}/messages", status_code=status.HTTP_201_CREATED)
def create_study_group_message(
    group_id: str,
    payload: StudyGroupMessageCreateRequest,
    user_id: str = Depends(_current_user),
) -> dict[str, Any]:
    group = _social_group_for_user(user_id, group_id)
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")
    text = payload.text.strip()
    if not text:
        raise HTTPException(status_code=422, detail="Message text is required")
    profile = _social_user_by_id(user_id)
    message_id = str(uuid.uuid4())
    created_at = datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")
    message = {
        "message_id": message_id,
        "user_id": user_id,
        "sender_name": str((profile or {}).get("name") or (profile or {}).get("username") or user_id),
        "text": text,
        "message_type": "text",
        "payload": None,
        "created_at": created_at,
    }
    canonical = _social_canonical_group(group_id) or group
    owner_id = str(canonical.get("creator_id") or user_id)
    key = f"{_SOCIAL_GROUP_MESSAGE_PREFIX}{group_id}.{created_at}.{message_id}"
    _social_upsert_kv(owner_id, key, message)
    rows = _social_group_message_rows(group_id)
    if len(rows) > _SOCIAL_GROUP_MESSAGE_LIMIT:
        rows.sort(key=lambda row: str((_social_kv_value(row) or {}).get("created_at") or ""))
        for row in rows[: len(rows) - _SOCIAL_GROUP_MESSAGE_LIMIT]:
            _social_delete_kv(str(row.get("user_id") or owner_id), str(row.get("key") or ""))
    return message


@app.get("/social/study-groups/notices/my/system")
def list_my_group_notices(_user_id: str = Depends(_current_user)) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자. 작동 원리: 그룹 알림이 없는 초기 상태를 기존 items 계약으로 반환한다."""
    return {"items": []}


@app.get("/account/system-notices")
def list_system_notices(_user_id: str = Depends(_current_user)) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자. 작동 원리: 전역 알림이 없을 때 빈 목록을 반환한다."""
    return {"items": []}


_PUBLIC_TEXTBOOKS: tuple[dict[str, Any], ...] = (
    {
        "textbook_id": "public_manual_textbook",
        "title": "Upstudy 학습 가이드",
        "subtitle": "책가방과 교재 읽기의 기본 사용법",
        "category": "common",
        "tags": ["가이드", "공개 교재"],
        "cover_color": 0xFF202024,
        "progress": 0,
        "progress_label": "0%",
        "chapters": [
            {
                "title": "1. 책가방 시작하기",
                "intro": ["책가방에서는 저장한 교재를 한곳에서 확인하고 이어 읽을 수 있습니다."],
                "sections": [
                    {
                        "title": "1-1. 교재 열기",
                        "paragraphs": [
                            "책가방의 교재 항목을 누르면 목차와 본문을 확인할 수 있습니다.",
                            "자주 보는 교재는 고정해 빠르게 다시 열 수 있습니다.",
                        ],
                        "images": [],
                    }
                ],
            }
        ],
    },
)


@app.get("/textbooks")
def list_textbooks(
    category: str | None = None,
    tag: str | None = None,
    type: str | None = None,
    _user_id: str = Depends(_current_user),
) -> dict[str, list[dict[str, Any]]]:
    """인증 사용자가 열 수 있는 공개 교재를 필터와 함께 반환한다."""
    normalized_category = (category or "").strip().lower()
    normalized_tag = (tag or "").strip().lower()
    normalized_type = (type or "").strip().lower()
    textbooks = []
    for textbook in _PUBLIC_TEXTBOOKS:
        textbook_category = str(textbook.get("category") or "").lower()
        if normalized_category and textbook_category != normalized_category:
            continue
        tags = [str(value).lower() for value in textbook.get("tags") or []]
        if normalized_tag and normalized_tag not in tags:
            continue
        if normalized_type and normalized_type not in {"public", "common"}:
            continue
        textbooks.append(copy.deepcopy(textbook))
    return {"textbooks": textbooks}


@app.get("/textbooks/{textbook_id}")
def get_textbook(
    textbook_id: str,
    _user_id: str = Depends(_current_user),
) -> dict[str, Any]:
    """목록에서 노출한 공개 교재 본문을 같은 ID로 반환한다."""
    normalized_id = textbook_id.strip()
    for textbook in _PUBLIC_TEXTBOOKS:
        if textbook["textbook_id"] == normalized_id:
            return copy.deepcopy(textbook)
    raise HTTPException(status_code=404, detail="Textbook not found")


@app.post("/quests/generate")
def generate_quest(
    payload: QuestGenerateRequest,
    _user_id: str = Depends(_current_user),
) -> dict[str, Any]:
    """필요 변수: 인증 사용자와 단건 생성 조건이다. 작동 원리: 스트림과 같은 결정적
    생성기를 사용해 기존 단건 API 계약의 `quest`를 즉시 반환한다."""
    request = payload.model_copy(update={"question_count": 1})
    return {"quest": _build_generated_questions(request)[0]}


@app.post("/quests/generate/stream")
def generate_quest_stream(
    payload: QuestGenerateRequest,
    _user_id: str = Depends(_current_user),
) -> StreamingResponse:
    """필요 변수: 인증 사용자와 최대 30개 생성 조건이다. 작동 원리: 미리 만든 작은
    문제 목록을 SSE 행으로 순서대로 보내 Flutter가 첫 문제부터 즉시 표시하게 한다."""
    questions = _build_generated_questions(payload)

    def event_stream():
        """필요 변수는 생성 완료된 문제 목록이다. 작동 원리는 문제별 SSE 행과 종료 행을 순서대로 방출하는 것이다."""
        for question in questions:
            encoded = json.dumps(
                question,
                ensure_ascii=False,
                separators=(",", ":"),
            )
            yield f"data: {encoded}\n\n"
        yield "data: [DONE]\n\n"

    return StreamingResponse(
        event_stream(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache, no-transform",
            "X-Accel-Buffering": "no",
        },
    )


@app.get("/quests")
def list_quests(
    quest_id: str | None = None,
    _user_id: str = Depends(_current_user),
) -> dict[str, Any]:
    """필요 변수: 인증 사용자와 선택적 문제 ID다. 작동 원리: 마켓 상품이 할당한 ID는
    공유 문항 원장에서 직접 조회하고, 일반 검색은 기존 빈 원장 계약을 유지한다."""
    normalized_id = (quest_id or "").strip()
    question = _find_marketplace_question(normalized_id) if normalized_id else None
    items = [question] if question is not None else []
    return {"quests": items, "items": items, "total": len(items)}


@app.get("/quests/generation-tags")
def list_generation_tags(_user_id: str = Depends(_current_user)) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자. 작동 원리: 생성 태그 원장 이관 전 빈 그룹을 반환한다."""
    return {"groups": []}


@app.get("/exams")
def list_exams(user_id: str = Depends(_current_user)) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자의 보유 마켓 자료다. 작동 원리: 보유 시험지만 카탈로그와
    결합해 반환하고 각 시험지의 실제 할당 문항 수를 함께 제공한다."""
    owned = _load_owned_marketplace(user_id)
    exams = [
        {**listing, **owned[listing["id"]], "owned": True}
        for listing in MARKETPLACE_CATALOG
        if listing["kind"] == "exam" and listing["id"] in owned
    ]
    return {"items": exams, "exams": exams}


@app.get("/exams/{exam_id}")
def get_exam_status(
    exam_id: str,
    user_id: str = Depends(_current_user),
) -> dict[str, Any]:
    """필요 변수: 시험지 ID와 인증 사용자의 보유 원장이다. 작동 원리: 실제 보유 시험지만
    공유 문항 원장에서 ExamPaperPage 계약으로 변환해 빈 종이 대신 문제를 렌더링한다."""
    listing = _find_catalog_listing(exam_id)
    if listing is None or listing.get("kind") != "exam":
        raise HTTPException(status_code=404, detail="exam_not_found")
    if listing["id"] not in _load_owned_marketplace(user_id):
        raise HTTPException(status_code=403, detail="purchase_required")
    return _build_marketplace_exam_status(listing)


_TUTOR_SYSTEM_PROMPT = (
    "너는 AIFlow의 한국어 수학 학습 튜터다. 정답만 대신 내놓지 말고, 학생이 다음 단계를 "
    "스스로 찾도록 짧고 명확하게 설명하라. 수식은 읽기 쉬운 텍스트로 쓰고 답변은 600자 이내로 제한하라."
)


def _request_tutor_reply(payload: ServerChatMessageRequest) -> tuple[str, str]:
    api_key = os.getenv("COMETAPI_KEY", "").strip()
    if not api_key:
        raise RuntimeError("AI tutor is not configured")
    model = os.getenv("OMJ_CHAT_MODEL", "gpt-4o-mini").strip() or "gpt-4o-mini"
    base_url = os.getenv("COMET_OPENAI_BASE_URL", "https://api.cometapi.com/v1").rstrip("/")
    context = "\n".join(
        part
        for part in (
            f"문제: {payload.quest_title}" if payload.quest_title else "",
            f"풀이 맥락: {payload.flow}" if payload.flow else "",
            f"인식 내용: {payload.ocr}" if payload.ocr else "",
        )
        if part
    )
    messages = [{"role": "system", "content": _TUTOR_SYSTEM_PROMPT}]
    if context:
        messages.append({"role": "system", "content": context})
    messages.append({"role": "user", "content": payload.user_message.strip()})
    body = json.dumps(
        {"model": model, "messages": messages, "temperature": 0.4, "max_tokens": 300},
        ensure_ascii=False,
    ).encode("utf-8")
    request = urllib.request.Request(
        f"{base_url}/chat/completions",
        data=body,
        headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            result = json.loads(response.read(200_000))
    except urllib.error.HTTPError as error:
        print(f"serverchat_upstream_http_error status={error.code}")
        raise RuntimeError("AI tutor upstream rejected the request") from error
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise RuntimeError("AI tutor upstream is unavailable") from error
    try:
        reply = str(result["choices"][0]["message"]["content"]).strip()
    except (KeyError, IndexError, TypeError) as error:
        raise RuntimeError("AI tutor returned an invalid response") from error
    if not reply:
        raise RuntimeError("AI tutor returned an empty response")
    return reply, model


@app.get("/serverchat/config")
def get_server_chat_config(_user_id: str = Depends(_current_user)) -> dict[str, Any]:
    enabled = bool(os.getenv("COMETAPI_KEY", "").strip())
    return {
        "enabled": enabled,
        "reason": "" if enabled else "AI tutor is not configured",
        "character": "gemma",
        "character_name": "AI 학습 튜터",
        "model": os.getenv("OMJ_CHAT_MODEL", "gpt-4o-mini"),
    }


@app.post("/serverchat/message")
async def send_server_chat_message(
    payload: ServerChatMessageRequest,
    _user_id: str = Depends(_current_user),
) -> dict[str, Any]:
    if not os.getenv("COMETAPI_KEY", "").strip():
        raise HTTPException(status_code=503, detail="AI tutor is not configured")
    try:
        reply, model = await run_in_threadpool(_request_tutor_reply, payload)
    except RuntimeError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error
    return {
        "assistant_message": reply,
        "character": payload.character or "gemma",
        "character_name": "AI 학습 튜터",
        "model": model,
    }


@app.post("/api/ocr/jobs", status_code=status.HTTP_202_ACCEPTED)
async def create_ocr_job(
    request: Request,
    job: OcrJobRequest,
    user_id: str = Depends(_current_user),
    idempotency_key: str | None = Header(default=None, alias="X-Idempotency-Key"),
) -> dict[str, Any]:
    """필요 변수: 인증 사용자·payload·멱등 키. 작동 원리: 중복 없이 큐에 넣고 Lightning을 깨운다."""
    size = len(json.dumps(job.model_dump(), ensure_ascii=False).encode("utf-8"))
    if int(request.headers.get("content-length") or 0) > MAX_JOB_BYTES or size > MAX_JOB_BYTES:
        raise HTTPException(status_code=413, detail=f"OCR job exceeds {MAX_JOB_BYTES} bytes")
    stable_key = (idempotency_key or str(uuid.uuid4())).strip()[:128]
    api = _data_api()
    try:
        rows = api.request(
            "POST",
            "ocr_jobs",
            query={"on_conflict": "user_id,idempotency_key"},
            body={"user_id": user_id, "mode": job.mode, "payload": job.payload, "idempotency_key": stable_key},
            prefer="resolution=ignore-duplicates,return=representation",
        ) or []
        if not rows:
            rows = api.request(
                "GET",
                "ocr_jobs",
                query={"select": VISIBLE_COLUMNS, "user_id": f"eq.{user_id}", "idempotency_key": f"eq.{stable_key}", "limit": "1"},
            ) or []
    except RuntimeError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error
    if not rows:
        raise HTTPException(status_code=502, detail="OCR job was not created")
    created = dict(rows[0])
    _wake_lightning(str(created["id"]))
    return {"job_id": created["id"], "status": created["status"]}


@app.get("/api/ocr/jobs/{job_id}")
def get_ocr_job(job_id: uuid.UUID, user_id: str = Depends(_current_user)) -> dict[str, Any]:
    """필요 변수: 작업 UUID·인증 사용자. 작동 원리: 본인의 단일 큐 행만 인덱스로 조회한다."""
    try:
        rows = _data_api().request(
            "GET",
            "ocr_jobs",
            query={"select": VISIBLE_COLUMNS, "id": f"eq.{job_id}", "user_id": f"eq.{user_id}", "limit": "1"},
        ) or []
    except RuntimeError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error
    if not rows:
        raise HTTPException(status_code=404, detail="OCR job not found")
    return dict(rows[0])
