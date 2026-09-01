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
