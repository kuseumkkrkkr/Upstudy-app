"""Vercel OCR 큐의 인증·멱등 등록·소유자 조회 계약 테스트."""
from __future__ import annotations

import importlib
import time

import jwt
from fastapi.testclient import TestClient


class _FakeDataApi:
    """필요 변수: 없음. 작동 원리: Supabase 호출을 메모리 행으로 대체해 API 계약만 검증한다."""

    def __init__(self) -> None:
        self.row = {
            "id": "5d94e310-4fa3-4659-ac29-182e22ce5f20",
            "status": "queued",
            "result": None,
            "error": None,
            "created_at": "2026-07-22T00:00:00Z",
            "updated_at": "2026-07-22T00:00:00Z",
            "expires_at": "2026-07-23T00:00:00Z",
        }

    def request(self, method, path, **kwargs):
        """필요 변수: Data API 호출 정보. 작동 원리: 등록·조회 모두 같은 소유 행을 반환한다."""
        return [dict(self.row)]


def test_create_and_get_job(monkeypatch):
    """필요 변수: 테스트 JWT·가짜 DB. 작동 원리: 동일 인증으로 등록과 조회가 모두 성공하는지 확인한다."""
    monkeypatch.setenv("OMJ_JWT_SECRET", "test-secret")
    module = importlib.import_module("api.index")
    fake = _FakeDataApi()
    monkeypatch.setattr(module, "_data_api", lambda: fake)
    monkeypatch.setattr(module, "_wake_lightning", lambda job_id: None)
    token = jwt.encode({"sub": "canary-user", "exp": int(time.time()) + 60}, "test-secret", algorithm="HS256")
    headers = {"Authorization": f"Bearer {token}", "X-Idempotency-Key": "same-request"}
    with TestClient(module.app) as client:
        created = client.post("/api/ocr/jobs", headers=headers, json={"mode": "solve", "payload": {"quest_id": "q1"}})
        assert created.status_code == 202
        job_id = created.json()["job_id"]
        fetched = client.get(f"/api/ocr/jobs/{job_id}", headers=headers)
        assert fetched.status_code == 200
        assert fetched.json()["status"] == "queued"


def test_job_requires_bearer_token():
    """필요 변수: 인증 없는 요청. 작동 원리: DB 접근 전에 401로 차단되는지 확인한다."""
    module = importlib.import_module("api.index")
    with TestClient(module.app) as client:
        response = client.post("/api/ocr/jobs", json={"mode": "ocr", "payload": {}})
    assert response.status_code == 401


def test_lightning_start_is_pinned_to_free_cpu(monkeypatch):
    """필요 변수: Lightning 관리 API Secret·가짜 HTTP. 작동 원리: wake가 기존 Studio를 cpu-4로만 시작하는지 검증한다."""
    module = importlib.import_module("api.index")
    monkeypatch.setenv("LIGHTNING_API_AUTH", "Basic test-credential")
    monkeypatch.setenv("LIGHTNING_TEAMSPACE_ID", "teamspace-id")
    monkeypatch.setenv("LIGHTNING_STUDIO_ID", "studio-id")
    captured = {}

    class _Response:
        def __enter__(self):
            return self

        def __exit__(self, *_args):
            return False

        def read(self, _limit):
            return b"{}"

    def _urlopen(request, timeout):
        captured["url"] = request.full_url
        captured["authorization"] = request.headers["Authorization"]
        captured["body"] = request.data.decode("utf-8")
        captured["timeout"] = timeout
        return _Response()

    monkeypatch.setattr(module.urllib.request, "urlopen", _urlopen)
    module._start_lightning_studio()

    assert captured["url"].endswith("/v1/projects/teamspace-id/cloudspaces/studio-id/start")
    assert captured["authorization"] == "Basic test-credential"
    assert '"name": "cpu-4"' in captured["body"]
    assert '"spot": false' in captured["body"]
