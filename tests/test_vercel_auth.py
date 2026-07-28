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


class _FakeProfileDataApi(_FakeAuthDataApi):
    """필요 변수: 사용자·KV 메모리 행. 작동 원리: 프로필 수정과 사용자 저장소 CRUD를 함께 모사한다."""

    def __init__(self) -> None:
        super().__init__()
        self.kv: dict[tuple[str, str], str] = {}

    def request(self, method, path, *, query=None, body=None, prefer=None):
        """필요 변수: PostgREST 호출. 작동 원리: PATCH·DELETE·KV upsert를 메모리 상태에 반영한다."""
        if path == "canary_user_kv":
            user_id = (body or {}).get("user_id") or (query or {}).get("user_id", "").removeprefix("eq.")
            key = (body or {}).get("key") or (query or {}).get("key", "").removeprefix("eq.")
            item_key = (user_id, key)
            if method == "POST":
                self.kv[item_key] = body["value"]
                return None
            if method == "DELETE":
                self.kv.pop(item_key, None)
                return None
            return [{"value": self.kv[item_key]}] if item_key in self.kv else []
        if method == "PATCH":
            user_id = query["user_id"].removeprefix("eq.")
            for row in self.users:
                if row["user_id"] == user_id:
                    row.update(body)
            return None
        if method == "DELETE":
            user_id = query["user_id"].removeprefix("eq.")
            self.users = [row for row in self.users if row["user_id"] != user_id]
            return None
        return super().request(method, path, query=query, body=body, prefer=prefer)


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


def test_profile_and_user_storage_round_trip(monkeypatch):
    """필요 변수: 가입 사용자·KV 값. 작동 원리: 프로필 수정과 저장·조회·삭제를 동일 토큰으로 왕복한다."""
    monkeypatch.setenv("OMJ_JWT_SECRET", "test-secret")
    module = importlib.import_module("api.index")
    fake = _FakeProfileDataApi()
    monkeypatch.setattr(module, "_data_api", lambda: fake)
    with TestClient(module.app) as client:
        registered = client.post(
            "/auth/register",
            json={"username": "student03", "password": "password123", "name": "학생3", "grade": "3학년"},
        )
        headers = {"Authorization": f"Bearer {registered.json()['token']}"}
        updated = client.put("/auth/me", headers=headers, json={"school": "테스트학교"})
        assert updated.status_code == 200
        assert updated.json()["school"] == "테스트학교"
        assert client.put("/user/storage/activity", headers=headers, json={"value": '{"score":1}'}).status_code == 200
        loaded = client.get("/user/storage/activity", headers=headers)
        assert loaded.json()["value"] == '{"score":1}'
        assert client.delete("/user/storage/activity", headers=headers).status_code == 200
        assert client.get("/user/storage/activity", headers=headers).json()["value"] is None


def test_new_user_dashboard_endpoints(monkeypatch):
    """필요 변수: 신규 사용자 토큰. 작동 원리: 홈 초기 로딩 API가 404 없이 파싱 가능한 기본 응답을 주는지 순회한다."""
    monkeypatch.setenv("OMJ_JWT_SECRET", "test-secret")
    module = importlib.import_module("api.index")
    fake = _FakeProfileDataApi()
    monkeypatch.setattr(module, "_data_api", lambda: fake)
    with TestClient(module.app) as client:
        registered = client.post(
            "/auth/register",
            json={"username": "student04", "password": "password123", "name": "학생4", "grade": "1학년"},
        )
        headers = {"Authorization": f"Bearer {registered.json()['token']}"}
        paths = [
            "/account/summary",
            "/rating/user",
            "/arena/summary",
            "/arena/rankings?queue_type=duel_exam",
            "/rating/tags",
            "/weakness/tags",
            "/courses/v2",
            "/courses",
            "/courses/enrolled",
            "/academy/assignments/my",
            "/academy/students/me/schedule",
            "/challenges/daily-quests?course_id=none",
            "/marketplace/listings",
            "/marketplace/my-items",
            "/history/solve",
            "/social/friends",
            "/social/friend-requests",
            "/social/friends/rankings",
            "/social/conversations",
            "/social/study-groups/mine",
            "/account/system-notices",
            "/textbooks",
            "/quests",
            "/quests/generation-tags",
            "/exams",
            "/serverchat/config",
        ]
        for path in paths:
            response = client.get(path, headers=headers)
            assert response.status_code == 200, path
            assert isinstance(response.json(), dict), path

        arena = client.get("/arena/summary", headers=headers).json()
        assert [item["queue_type"] for item in arena["queues"]] == [
            "duel_exam",
            "team_exam",
        ]
        assert all(item["coming_soon"] is True for item in arena["queues"])
