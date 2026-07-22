"""Vercel 카나리 회원가입·로그인·세션 계약 테스트."""
from __future__ import annotations

import importlib
import time

import jwt
from fastapi.testclient import TestClient


class _FakeAuthDataApi:
    """필요 변수: 없음. 작동 원리: Supabase 사용자 행을 메모리에 보관해 인증 왕복을 검증한다."""

    def __init__(self) -> None:
        self.users: list[dict] = []

    def request(self, method, path, *, query=None, body=None, prefer=None):
        """필요 변수: Data API 호출. 작동 원리: canary_users의 삽입과 인덱스 조회만 모사한다."""
        assert path == "canary_users"
        if method == "POST":
            if any(row["username"] == body["username"] for row in self.users):
                raise RuntimeError('409: {"code":"23505"}')
            row = {**body, "role": "student", "created_at": "2026-07-22T00:00:00Z"}
            self.users.append(row)
            return [dict(row)]
        rows = self.users
        for key in ("username", "user_id"):
            expected = (query or {}).get(key)
            if expected:
                rows = [row for row in rows if str(row[key]) == expected.removeprefix("eq.")]
        selected = (query or {}).get("select", "*").split(",")
        return [{key: row.get(key) for key in selected} for row in rows[:1]]


def test_register_login_and_profile(monkeypatch):
    """필요 변수: 가짜 Supabase·JWT Secret. 작동 원리: 가입 토큰으로 로그인과 프로필 조회까지 이어지는지 확인한다."""
    monkeypatch.setenv("OMJ_JWT_SECRET", "test-secret")
    module = importlib.import_module("api.index")
    fake = _FakeAuthDataApi()
    monkeypatch.setattr(module, "_data_api", lambda: fake)
    payload = {
        "username": "student01",
        "password": "password123",
        "name": "김학생",
        "grade": "2학년",
        "track": "중학교",
        "subject": "수학",
        "school": "AIFlow 중학교",
        "email": "student@example.com",
    }
    with TestClient(module.app) as client:
        registered = client.post("/auth/register", json=payload)
        assert registered.status_code == 201
        token = registered.json()["token"]
        claims = jwt.decode(token, "test-secret", algorithms=["HS256"])
        assert claims["role"] == "student"
        assert claims["exp"] > int(time.time())

        profile = client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
        assert profile.status_code == 200
        assert profile.json()["school"] == "AIFlow 중학교"

        logged_in = client.post("/auth/login", json={"username": "student01", "password": "password123"})
        assert logged_in.status_code == 200


def test_duplicate_and_invalid_registration(monkeypatch):
    """필요 변수: 중복 사용자와 잘못된 입력. 작동 원리: 중복은 409, 형식 오류는 400으로 구분한다."""
    monkeypatch.setenv("OMJ_JWT_SECRET", "test-secret")
    module = importlib.import_module("api.index")
    fake = _FakeAuthDataApi()
    monkeypatch.setattr(module, "_data_api", lambda: fake)
    valid = {"username": "student02", "password": "password123", "name": "학생2", "grade": "2학년"}
    with TestClient(module.app) as client:
        assert client.post("/auth/register", json=valid).status_code == 201
        assert client.post("/auth/register", json=valid).status_code == 409
        invalid = {**valid, "username": "x"}
        assert client.post("/auth/register", json=invalid).status_code == 400
