from __future__ import annotations

import importlib

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
    assert data["time_limit_seconds"] == 3600
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
