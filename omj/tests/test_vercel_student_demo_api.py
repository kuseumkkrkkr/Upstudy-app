"""Vercel student demo API contract tests without a live Supabase project."""

from fastapi.testclient import TestClient

import api.index as vercel_api


class _FakeDataApi:
    def request(self, method, path, **kwargs):
        if path == "rpc/demo_student_store_snapshot":
            return {"points": 12840, "items": [{"id": "timer-theme", "owned": False}]}
        if path == "rpc/demo_redeem_student_store":
            return {
                "status": "completed",
                "order_id": "order-1",
                "item_id": "timer-theme",
                "points": 12040,
            }
        if path in {"student_school_exam_plan", "student_school_exam_task"}:
            return []
        raise AssertionError(f"unexpected request: {method} {path}")


def test_demo_store_requires_flag_and_idempotency_key(monkeypatch):
    monkeypatch.setenv("STUDENT_STORE_DEMO", "true")
    monkeypatch.setattr(vercel_api, "_data_api", lambda: _FakeDataApi())
    vercel_api.app.dependency_overrides[vercel_api._current_user] = lambda: "student-1"
    client = TestClient(vercel_api.app)
    try:
        snapshot = client.get("/demo/student-store")
        assert snapshot.status_code == 200
        assert snapshot.json()["points"] == 12840

        missing_key = client.post(
            "/demo/student-store/orders",
            json={"item_id": "timer-theme"},
        )
        assert missing_key.status_code == 400

        order = client.post(
            "/demo/student-store/orders",
            headers={"X-Idempotency-Key": "timer-theme-1"},
            json={"item_id": "timer-theme"},
        )
        assert order.status_code == 200
        assert order.json()["status"] == "completed"
    finally:
        vercel_api.app.dependency_overrides.pop(vercel_api._current_user, None)


def test_demo_store_is_hidden_when_flag_is_off(monkeypatch):
    monkeypatch.delenv("STUDENT_STORE_DEMO", raising=False)
    vercel_api.app.dependency_overrides[vercel_api._current_user] = lambda: "student-1"
    client = TestClient(vercel_api.app)
    try:
        assert client.get("/demo/student-store").status_code == 404
        assert client.post(
            "/demo/student-store/orders",
            headers={"X-Idempotency-Key": "timer-theme-1"},
            json={"item_id": "timer-theme"},
        ).status_code == 404
    finally:
        vercel_api.app.dependency_overrides.pop(vercel_api._current_user, None)


def test_demo_store_maps_idempotency_conflict_to_409(monkeypatch):
    class _ConflictApi:
        def request(self, method, path, **kwargs):
            return {"status": "conflict", "order_id": "order-1"}

    monkeypatch.setenv("STUDENT_STORE_DEMO", "true")
    monkeypatch.setattr(vercel_api, "_data_api", lambda: _ConflictApi())
    vercel_api.app.dependency_overrides[vercel_api._current_user] = lambda: "student-1"
    client = TestClient(vercel_api.app)
    try:
        response = client.post(
            "/demo/student-store/orders",
            headers={"X-Idempotency-Key": "timer-theme-1"},
            json={"item_id": "timer-theme"},
        )
        assert response.status_code == 409
        assert response.json()["detail"] == "idempotency_key_payload_mismatch"
    finally:
        vercel_api.app.dependency_overrides.pop(vercel_api._current_user, None)


def test_school_exam_plan_is_math_only(monkeypatch):
    monkeypatch.setattr(vercel_api, "_data_api", lambda: _FakeDataApi())
    vercel_api.app.dependency_overrides[vercel_api._current_user] = lambda: "student-1"
    client = TestClient(vercel_api.app)
    try:
        # The fake intentionally has no school-exam rows; a production empty
        # response must still identify the subject as math.
        response = client.get("/student/school-exam-plan/active")
        assert response.status_code == 200
        assert response.json() == {"plan": None, "tasks": [], "subject": "math"}
    finally:
        vercel_api.app.dependency_overrides.pop(vercel_api._current_user, None)


def test_social_friend_search_and_request_use_post_contract(monkeypatch):
    """친구 검색·요청은 클라이언트 계약인 POST를 유지한다."""
    target = {
        "user_id": "student-2",
        "username": "friend2",
        "name": "친구",
        "profile_image": None,
    }
    monkeypatch.setattr(vercel_api, "_social_data_request", lambda *args, **kwargs: [target])
    monkeypatch.setattr(vercel_api, "_social_user_by_username", lambda _: target)
    monkeypatch.setattr(vercel_api, "_social_user_by_id", lambda _: target)
    monkeypatch.setattr(vercel_api, "_social_has_key", lambda *args: False)
    monkeypatch.setattr(vercel_api, "_social_upsert_kv", lambda *args, **kwargs: None)
    vercel_api.app.dependency_overrides[vercel_api._current_user] = lambda: "student-1"
    client = TestClient(vercel_api.app)
    try:
        search = client.post(
            "/social/friends/search",
            json={"query": "friend", "limit": 20},
        )
        assert search.status_code == 200
        assert search.json()["users"][0]["username"] == "friend2"

        request = client.post(
            "/social/friend-requests",
            json={"username": "friend2", "message": "안녕하세요"},
        )
        assert request.status_code == 201
        assert request.json()["status"] == "pending"
    finally:
        vercel_api.app.dependency_overrides.pop(vercel_api._current_user, None)
