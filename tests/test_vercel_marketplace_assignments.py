"""Vercel 마켓플레이스 시험지·문제세트의 문항 배정을 검증한다."""

from __future__ import annotations

import importlib.util
from pathlib import Path
from typing import Any

import pytest


# 필요한 변수: 저장소 루트와 Vercel API 모듈 경로.
# 작동 원리: 일반 패키지와 충돌하지 않도록 파일 경로에서 API 모듈을 직접 불러온다.
def _load_api_module() -> Any:
    api_path = Path(__file__).resolve().parents[1] / "api" / "index.py"
    spec = importlib.util.spec_from_file_location("aiflow_vercel_api", api_path)
    if spec is None or spec.loader is None:
        raise RuntimeError("Vercel API 모듈을 불러올 수 없습니다.")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


api = _load_api_module()


# 필요한 변수: 소유 상품 ID와 원본 카탈로그.
# 작동 원리: 테스트 대상 상품만 소유한 것처럼 반환해 인증 이후 계약을 독립적으로 검증한다.
def _owned_item(listing_id: str) -> dict[str, dict[str, Any]]:
    listing = api._find_catalog_listing(listing_id)
    assert listing is not None
    return {listing_id: dict(listing)}


# 필요한 변수: 전체 마켓플레이스 카탈로그.
# 작동 원리: 모든 시험지·문제세트의 선언 문항 수와 실제 생성 문항을 일대일 대조한다.
def test_every_exam_and_problem_set_has_consistent_assignments() -> None:
    listings = api.MARKETPLACE_CATALOG
    exams = [item for item in listings if item["kind"] == "exam"]
    problem_sets = [item for item in listings if item["kind"] == "problem_set"]
    courses = [item for item in listings if item["kind"] == "course"]

    assert len(exams) == 85
    assert len(problem_sets) == 166
    assert len(courses) == 81

    all_question_ids: list[str] = []
    for listing in [*exams, *problem_sets]:
        expected_count = int(listing["item_count"])
        assigned_ids = listing["problem_ids"]
        questions = api._build_marketplace_questions(listing)

        assert len(assigned_ids) == expected_count, listing["id"]
        assert len(set(assigned_ids)) == expected_count, listing["id"]
        assert [
            question["header"]["quest_id"] for question in questions
        ] == assigned_ids

        for question in questions:
            data = question["data"]
            assert data["quest_title"].strip()
            assert len(data["quest_options"]) == 4
            assert 0 <= int(data["correct_choice_index"]) < len(
                data["quest_options"]
            )

        all_question_ids.extend(assigned_ids)

    assert len(all_question_ids) == len(set(all_question_ids))


# 필요한 변수: 시험지 상품과 소유 상품 조회 대역.
# 작동 원리: 모바일 시험지 뷰어가 요구하는 ExamStatus 응답이 모든 문항을 포함하는지 확인한다.
def test_exam_status_contract_contains_all_assigned_questions(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    exam = next(item for item in api.MARKETPLACE_CATALOG if item["kind"] == "exam")
    monkeypatch.setattr(
        api,
        "_load_owned_marketplace",
        lambda _user_id: _owned_item(exam["id"]),
    )

    status = api.get_exam_status(exam["id"], user_id="test-user")

    assert status["exam_id"] == exam["id"]
    assert status["status"] == "done"
    assert len(status["items"]) == exam["item_count"]
    assert [item["quest_id"] for item in status["items"]] == exam["problem_ids"]


# 필요한 변수: 문제세트 상품, 첫 문항 ID, 소유 상품 조회 대역.
# 작동 원리: 문제세트 상세와 단일 문제 검색이 같은 문항 데이터를 반환하는지 대조한다.
def test_problem_set_and_quest_lookup_share_the_same_assignment(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    problem_set = next(
        item for item in api.MARKETPLACE_CATALOG if item["kind"] == "problem_set"
    )
    monkeypatch.setattr(
        api,
        "_load_owned_marketplace",
        lambda _user_id: _owned_item(problem_set["id"]),
    )

    detail = api.get_owned_problem_set_questions(
        problem_set["id"],
        user_id="test-user",
    )
    first_id = problem_set["problem_ids"][0]
    search = api.list_quests(quest_id=first_id, _user_id="test-user")

    assert len(detail["items"]) == problem_set["item_count"]
    assert search["quests"][0]["header"]["quest_id"] == first_id
    assert search["quests"][0] == detail["items"][0]
