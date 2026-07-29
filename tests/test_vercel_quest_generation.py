"""Vercel 카나리의 단건·스트림 문제 생성 계약을 검증한다."""

from __future__ import annotations

import importlib.util
import re
from pathlib import Path
from typing import Any

from fastapi.testclient import TestClient


# 필요한 변수: 저장소 루트와 Vercel API 모듈 경로다.
# 작동 원리: 일반 패키지 이름과 충돌하지 않게 파일 경로에서 API 모듈을 직접 불러온다.
def _load_api_module() -> Any:
    api_path = Path(__file__).resolve().parents[1] / "api" / "index.py"
    spec = importlib.util.spec_from_file_location(
        "aiflow_vercel_generation_api",
        api_path,
    )
    if spec is None or spec.loader is None:
        raise RuntimeError("Vercel API 모듈을 불러올 수 없습니다.")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


api = _load_api_module()


# 필요한 변수: 같은 태그·난이도·시드의 생성 요청이다.
# 작동 원리: 두 번 만든 문제를 비교하고 정답 선택지가 실제 방정식을 만족하는지 계산한다.
def test_generated_questions_are_deterministic_and_solvable() -> None:
    request = api.QuestGenerateRequest(
        hash_tags=["방정식"],
        question_count=4,
        min_difficulty_tier=1,
        max_difficulty_tier=3,
        seed=17,
    )

    first = api._build_generated_questions(request)
    second = api._build_generated_questions(request)

    assert first == second
    assert len(first) == 4
    assert len({item["header"]["quest_id"] for item in first}) == 4
    for item in first:
        data = item["data"]
        equation = data["quest_title"].splitlines()[-1]
        match = re.fullmatch(r"(\d+)x \+ (\d+) = (\d+)", equation)
        assert match is not None
        coefficient, constant, result = map(int, match.groups())
        correct_index = int(data["correct_choice_index"])
        answer = int(data["quest_options"][correct_index])
        assert coefficient * answer + constant == result


# 필요한 변수: 인증을 통과한 카나리 FastAPI와 두 개 문항 요청이다.
# 작동 원리: 스트림 응답이 두 문제와 명시적 종료 행을 SSE 형식으로 반환하는지 확인한다.
def test_generate_stream_returns_sse_contract() -> None:
    api.app.dependency_overrides[api._current_user] = lambda: "test-user"
    try:
        with TestClient(api.app) as client:
            response = client.post(
                "/quests/generate/stream",
                json={
                    "hash_tags": ["일차방정식"],
                    "question_count": 2,
                    "min_difficulty_tier": 1,
                    "max_difficulty_tier": 2,
                },
            )
    finally:
        api.app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/event-stream")
    assert response.text.count('"quest_id"') == 2
    assert response.text.endswith("data: [DONE]\n\n")


# 필요한 변수: 인증을 통과한 카나리 FastAPI와 단건 생성 요청이다.
# 작동 원리: 기존 클라이언트가 기대하는 최상위 `quest` 객체를 즉시 받는지 확인한다.
def test_generate_single_returns_quest_contract() -> None:
    api.app.dependency_overrides[api._current_user] = lambda: "test-user"
    try:
        with TestClient(api.app) as client:
            response = client.post(
                "/quests/generate",
                json={"hash_tags": ["함수"], "seed": 9},
            )
    finally:
        api.app.dependency_overrides.clear()

    assert response.status_code == 200
    payload = response.json()
    assert payload["quest"]["header"]["quest_type"] == "multiple_choice"
    assert len(payload["quest"]["data"]["quest_options"]) == 4
