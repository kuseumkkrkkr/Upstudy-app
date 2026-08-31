from __future__ import annotations

import importlib
from datetime import datetime, timezone

from fastapi.testclient import TestClient


class _FakeLevelTestDataApi:
    def __init__(self) -> None:
        self.created_sessions: list[dict] = []

    def request(self, method, path, *, query=None, body=None, prefer=None):
        if path == "level_test_template" and method == "GET":
            return [{"template_id": "template-1", "version": 1, "form_index": 1}]
        if path == "level_test_session" and method == "POST":
            self.created_sessions.append(dict(body))
            return None
        if path == "level_test_session" and method == "PATCH":
            return None
        if method == "GET":
            return []
        raise AssertionError((method, path, query, body, prefer))


def test_vercel_placement_start_returns_25_questions(monkeypatch):
    monkeypatch.setenv("OMJ_JWT_SECRET", "test-secret")
    module = importlib.import_module("api.index")
    fake = _FakeLevelTestDataApi()
    monkeypatch.setattr(module, "_data_api", lambda: fake)

    items = [
        {
            "item_index": index,
            "phase": 1,
            "subject_key": "math",
            "hash_tags": ["algebra"],
            "difficulty_tier": 3,
            "quest_id": f"quest-{index}",
            "problem_rating": 1200,
        }
        for index in range(1, 26)
    ]
    payloads = {
        item["quest_id"]: {
            "header": {"quest_id": item["quest_id"]},
            "data": {"quest_title": f"Question {item['item_index']}"},
        }
        for item in items
    }
    monkeypatch.setattr(module, "_level_test_template_items", lambda _template_id: items)
    monkeypatch.setattr(module, "_level_test_problem_payloads", lambda _quest_ids: payloads)

    with TestClient(module.app) as client:
        token = client.post("/auth/anonymous").json()["token"]
        response = client.post(
            "/level-tests/placement/start",
            headers={"Authorization": f"Bearer {token}"},
        )

    assert response.status_code == 200
    data = response.json()["data"]
    assert data["question_count"] == 25
    assert data["time_limit_seconds"] == 1800
    assert len(data["questions"]) == 25
    assert len(fake.created_sessions) == 1


def test_vercel_placement_answer_rejects_item_26(monkeypatch):
    monkeypatch.setenv("OMJ_JWT_SECRET", "test-secret")
    module = importlib.import_module("api.index")
    with TestClient(module.app) as client:
        token = client.post("/auth/anonymous").json()["token"]
        response = client.post(
            "/level-tests/placement/session-1/answer",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "item_index": 26,
                "quest_id": "quest-26",
                "is_correct": False,
            },
        )

    assert response.status_code == 422


def test_level_test_selection_spans_all_difficulty_bands():
    module = importlib.import_module("api.index")
    tiers = [2] * 10 + [3] * 20 + [4] * 15 + [5] * 5
    items = [
        {
            "item_index": index,
            "difficulty_tier": tier,
            "quest_id": f"quest-{index}",
        }
        for index, tier in enumerate(tiers, start=1)
    ]

    selected = module._select_level_test_items(items)

    assert [item["item_index"] for item in selected] == list(range(1, 26))
    assert {
        tier: sum(item["difficulty_tier"] == tier for item in selected)
        for tier in range(2, 6)
    } == {2: 5, 3: 10, 4: 7, 5: 3}


def test_final_submit_grades_raw_answers_once_on_server(monkeypatch):
    module = importlib.import_module("api.index")
    items = [
        {
            "item_index": index,
            "difficulty_tier": 3,
            "quest_id": f"quest-{index}",
            "problem_rating": 1200,
            "hash_tags": ["algebra"],
        }
        for index in range(1, 26)
    ]
    problem_payloads = {
        f"quest-{index}": {
            "data": {"quest_options": [], "quest_answer": str(index)}
        }
        for index in range(1, 26)
    }

    class _BatchApi:
        def __init__(self):
            self.answers = []

        def request(self, method, path, *, query=None, body=None, prefer=None):
            if method == "POST" and path == "level_test_answer":
                self.answers = list(body)
                return None
            if method == "PATCH" and path == "level_test_session":
                return None
            raise AssertionError((method, path, query, body, prefer))

    fake = _BatchApi()
    monkeypatch.setattr(module, "_data_api", lambda: fake)
    monkeypatch.setattr(module, "_load_level_test_kv", lambda *_args, **_kwargs: None)
    monkeypatch.setattr(module, "_save_level_test_kv", lambda *_args, **_kwargs: None)
    monkeypatch.setattr(
        module,
        "_get_level_test_session",
        lambda _session_id, _user_id: {
            "session_id": "session-1",
            "user_id": "user-1",
            "template_id": "template-1",
            "status": "started",
            "started_at": datetime.now(timezone.utc),
        },
    )
    monkeypatch.setattr(module, "_level_test_template_items", lambda _template_id: items)
    monkeypatch.setattr(module, "_level_test_problem_payloads", lambda _quest_ids: problem_payloads)
    payload = module.LevelTestPlacementSubmitRequest(
        answers=[
            module.LevelTestPlacementSubmissionAnswer(
                item_index=index,
                quest_id=f"quest-{index}",
                user_answer=str(index) if index % 2 == 0 else None,
            )
            for index in range(1, 26)
        ],
        elapsed_seconds=1200,
    )

    response = module.submit_level_test_placement("session-1", payload, user_id="user-1")

    assert len(fake.answers) == 25
    assert sum(answer["is_correct"] for answer in fake.answers) == 12
    assert response["data"]["recent_accuracy"] == 12 / 25


def test_rating_falls_back_to_canonical_graded_session(monkeypatch):
    module = importlib.import_module("api.index")
    monkeypatch.setattr(module, "_load_level_test_kv", lambda *_args, **_kwargs: None)
    monkeypatch.setattr(
        module,
        "_latest_graded_level_test_session",
        lambda _user_id: {
            "session_id": "graded-1",
            "status": "graded",
            "estimated_rating": 1435,
            "estimated_ovr": 1435,
            "confidence": 1,
            "strong_tags": [],
            "weak_tags": [],
        },
    )

    response = module.get_user_rating("user-1")

    assert response["ovr"] == 1435
    assert response["placement_completed"] is True


def test_completed_user_cannot_start_placement(monkeypatch):
    module = importlib.import_module("api.index")
    monkeypatch.setattr(module, "_latest_graded_level_test_session", lambda _user_id: {"status": "graded"})

    try:
        module.start_level_test_placement("user-1")
    except Exception as error:
        assert getattr(error, "status_code", None) == 409
    else:
        raise AssertionError("completed placement must be locked")


def test_estimated_distribution_is_available_without_users():
    module = importlib.import_module("api.index")

    response = module.get_level_test_placement_stats("user-1")

    bands = response["data"]["estimated_bands"]
    assert len(bands) == 9
    assert bands[0]["grade"] == "9등급"
    assert bands[-1]["grade"] == "1등급"
    assert bands[0]["expected_correct"] < bands[-1]["expected_correct"]


def test_placement_estimator_uses_validation_prior_at_high_extreme():
    module = importlib.import_module("api.index")
    samples = [{"is_correct": True, "problem_rating": 1400} for _ in range(25)]

    assert module._estimate_level_test_rating(samples) < 2200
