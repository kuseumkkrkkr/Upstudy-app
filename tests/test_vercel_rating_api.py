"""Vercel owns rating API calls; Lightning remains OCR-only."""
from __future__ import annotations

from pathlib import Path
from unittest.mock import patch

from fastapi.testclient import TestClient

from api import index as api


class _DataApi:
    def __init__(self):
        self.calls = []

    def request(self, method, path, *, query=None, body=None, prefer=None):
        self.calls.append((method, path, query, body, prefer))
        if path == "user_tag_rating":
            return [{"tag": "이차방정식", "attempts": 4, "rating": 1432.5, "rating_prev": 1400}]
        if path == "user_weakness_tags":
            return [{"tag": "이차방정식", "count": 2, "updated_at": "2026-10-12T00:00:00Z"}]
        if path == "rpc/apply_rating_submission_v2":
            return {"rating": 1210, "ovr": 1210, "ovr_delta": 10,
                    "recent_accuracy": 1, "lose_streak": 0}
        if path == "rpc/get_rating_user_snapshot":
            return {"rating": 1210, "ovr": 1210, "ovr_delta": 10,
                    "recent_accuracy": 1, "lose_streak": 0,
                    "levelity_percentile": 60, "levelity_cohort_size": 20}
        raise AssertionError(f"unexpected Supabase request: {path}")


def _quest():
    return {
        "header": {"quest_id": "question-1"},
        "info": {"hash_tag": ["#이차방정식"], "difficulty_score": 8,
                 "main_huddle": 1, "flow_rate": 0.5},
        "solves": [
            {"hash_tag": ["#이차방정식"], "enter_huddle": 2},
            {"hash_tag": ["#허용되지않은태그"], "enter_huddle": 9},
        ],
    }


def test_rating_reads_are_authenticated_and_use_supabase(monkeypatch):
    data_api = _DataApi()
    monkeypatch.setattr(api, "_data_api", lambda: data_api)
    previous = dict(api.app.dependency_overrides)
    api.app.dependency_overrides[api._current_user] = lambda: "student-1"
    try:
        with TestClient(api.app) as client:
            tags = client.get("/rating/tags")
            user = client.get("/rating/user")
        assert tags.status_code == 200
        assert tags.json()["tags"] == [{"tag": "이차방정식", "attempts": 4,
                                         "rating": 1432.5, "delta": 32.5}]
        assert user.status_code == 200
        assert user.json()["levelity"]["tier"] == "Powerful 0"
        assert [call[1] for call in data_api.calls] == [
            "user_tag_rating", "rpc/get_rating_user_snapshot"
        ]
    finally:
        api.app.dependency_overrides.clear()
        api.app.dependency_overrides.update(previous)


def test_rating_submission_requires_server_grade_receipt(monkeypatch):
    data_api = _DataApi()
    monkeypatch.setenv("OMJ_JWT_SECRET", "test-only-rating-secret-32-bytes")
    monkeypatch.setattr(api, "_data_api", lambda: data_api)
    monkeypatch.setattr(api, "_find_vercel_question", lambda _quest_id: _quest())
    previous = dict(api.app.dependency_overrides)
    api.app.dependency_overrides[api._current_user] = lambda: "student-1"
    steps = [{"step_id": 1, "correct": True}]
    submission_id = "solve:test:rating-1"
    quest = _quest()
    proof = api._issue_grade_receipt(
        user_id="student-1", quest_id="question-1", is_correct=True,
        step_correctness=steps, submission_id=submission_id,
        question_sha256=api._grade_question_digest(quest),
    )
    try:
        with TestClient(api.app) as client:
            response = client.post("/rating/submit", json={
                "quest_id": "question-1", "is_correct": True,
                "step_correctness": steps, "answer_time": 18,
                "submission_id": submission_id, "grade_proof": proof,
            })
        assert response.status_code == 200
        assert response.json()["ovr_delta"] == 10
        rpc = next(call for call in data_api.calls if call[1] == "rpc/apply_rating_submission_v2")
        assert rpc[3]["p_user_id"] == "student-1"
        assert rpc[3]["p_submission_id"] == submission_id
        assert len(rpc[3]["p_request_fingerprint"]) == 64
        assert set(rpc[3]["p_request_fingerprint"]) <= set("0123456789abcdef")
        assert rpc[3]["p_tag_flows"] == [{
            "tag": "이차방정식", "enter_huddles": [2.0], "correct": True
        }]
        assert all("grade_proof" not in str(call[3]) for call in data_api.calls)
    finally:
        api.app.dependency_overrides.clear()
        api.app.dependency_overrides.update(previous)


def test_rating_submission_rejects_invalid_receipt_before_storage(monkeypatch):
    data_api = _DataApi()
    monkeypatch.setenv("OMJ_JWT_SECRET", "test-only-rating-secret-32-bytes")
    monkeypatch.setattr(api, "_data_api", lambda: data_api)
    previous = dict(api.app.dependency_overrides)
    api.app.dependency_overrides[api._current_user] = lambda: "student-1"
    try:
        with TestClient(api.app) as client:
            response = client.post("/rating/submit", json={
                "quest_id": "question-1", "is_correct": True,
                "submission_id": "solve:test:invalid", "grade_proof": "x" * 40,
            })
        assert response.status_code == 403
        assert data_api.calls == []
    finally:
        api.app.dependency_overrides.clear()
        api.app.dependency_overrides.update(previous)


def test_weakness_tags_read_from_user_scoped_supabase_rows(monkeypatch):
    data_api = _DataApi()
    monkeypatch.setattr(api, "_data_api", lambda: data_api)
    previous = dict(api.app.dependency_overrides)
    api.app.dependency_overrides[api._current_user] = lambda: "student-1"
    try:
        with TestClient(api.app) as client:
            response = client.get("/weakness/tags")
        assert response.status_code == 200
        assert response.json()["tags"] == [{
            "tag": "이차방정식", "count": 2, "updated_at": "2026-10-12T00:00:00Z"
        }]
        method, path, query, _body, _prefer = data_api.calls[0]
        assert (method, path) == ("GET", "user_weakness_tags")
        assert query["user_id"] == "eq.student-1"
    finally:
        api.app.dependency_overrides.clear()
        api.app.dependency_overrides.update(previous)


def test_ocr_grade_completion_passes_only_canonical_weakness_tags(monkeypatch):
    calls = []

    class _GradeDataApi:
        def request(self, method, path, *, query=None, body=None, prefer=None):
            calls.append((path, body))
            if path == "rpc/claim_ocr_solve_grade":
                return {"state": "claimed", "quest_id": "question-1",
                        "submission_id": "solve:one", "ocr_result": {"all_formulas": []}}
            if path == "rpc/complete_ocr_solve_grade_with_weakness":
                return True
            raise AssertionError(f"unexpected data API path: {path}")

    quest = {
        "solves": [
            {"answer_riddle": "첫 단계", "hash_tag": ["#이차방정식"]},
            {"answer_riddle": "둘째 단계", "hash_tag": ["#이차방정식", "#인수분해"]},
        ]
    }
    monkeypatch.setattr(api, "_data_api", _GradeDataApi)
    monkeypatch.setattr(api, "_find_vercel_question", lambda _quest_id: quest)
    monkeypatch.setattr(api, "_request_solve_grade", lambda **_kwargs: {
        "in_panic": [0, 1, 0, 99, True], "is_correct": False,
    })
    previous = dict(api.app.dependency_overrides)
    api.app.dependency_overrides[api._current_user] = lambda: "student-1"
    try:
        with TestClient(api.app) as client:
            response = client.post("/api/ocr/jobs/6c9dcbe7-9e19-44f5-a141-6fc2f09d2170/grade")
        assert response.status_code == 200
        assert calls[-1] == (
            "rpc/complete_ocr_solve_grade_with_weakness",
            {"p_job_id": "6c9dcbe7-9e19-44f5-a141-6fc2f09d2170",
             "p_user_id": "student-1", "p_worker_id": calls[0][1]["p_worker_id"],
             "p_grade_result": {"in_panic": [0, 1, 0, 99, True], "is_correct": False},
             "p_weakness_tags": ["#이차방정식", "#이차방정식", "#인수분해"]},
        )
    finally:
        api.app.dependency_overrides.clear()
        api.app.dependency_overrides.update(previous)


def test_rating_contract_sql_is_transactional_idempotent_and_service_only():
    sql_path = Path(__file__).parents[1] / "deploy" / "vercel" / "supabase_rating.sql"
    sql = sql_path.read_text(encoding="utf-8").lower()
    assert "primary key (user_id, submission_id)" in sql
    assert "for update" in sql
    assert "on conflict(user_id,submission_id) do nothing" in sql
    assert "p_request_fingerprint" in sql
    assert "previous.request_fingerprint is distinct from p_request_fingerprint" in sql
    assert "apply_rating_submission_v2" in sql
    assert "from public,anon,authenticated,service_role" in sql
    assert "previous.response" in sql
    assert "revoke all on function public.apply_rating_submission" in sql
    assert "to service_role" in sql
    assert "delete from public.user_rating" not in sql
    assert "delete from public.user_tag_rating" not in sql
