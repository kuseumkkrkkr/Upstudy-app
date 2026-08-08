"""Vercel 카나리 친구 검색·요청·수락의 Supabase KV 계약 테스트."""
from __future__ import annotations

import importlib

from fastapi.testclient import TestClient


class _FakeSocialDataApi:
    """필요 변수: 사용자 행. 작동 원리: canary_users와 복합키 KV의 PostgREST 필터를 메모리로 모사한다."""

    def __init__(self) -> None:
        self.users = [
            {"user_id": "user-alice", "username": "alice01", "name": "앨리스", "profile_image": None},
            {"user_id": "user-bob", "username": "bob0001", "name": "밥", "profile_image": None},
            {"user_id": "user-bobby", "username": "bobby02", "name": "바비", "profile_image": None},
        ]
        self.kv: dict[tuple[str, str], str] = {}

    def request(self, method, path, *, query=None, body=None, prefer=None):
        query = query or {}
        if path == "canary_users":
            return self._users(query)
        assert path == "canary_user_kv"
        if method == "POST":
            self.kv[(body["user_id"], body["key"])] = body["value"]
            return None
        user_id = query.get("user_id", "").removeprefix("eq.")
        key_filter = query.get("key", "")
        if method == "DELETE":
            key = key_filter.removeprefix("eq.")
            self.kv.pop((user_id, key), None)
            return None
        rows = [
            {"key": key, "value": value}
            for (owner, key), value in self.kv.items()
            if owner == user_id and self._matches_key(key, key_filter)
        ]
        selected = query.get("select", "key,value").split(",")
        return [{field: row.get(field) for field in selected} for row in rows]

    def _users(self, query: dict[str, str]) -> list[dict]:
        rows = list(self.users)
        username = query.get("username", "")
        if username.startswith("eq."):
            expected = username.removeprefix("eq.")
            rows = [row for row in rows if row["username"] == expected]
        elif username.startswith("ilike."):
            needle = username.removeprefix("ilike.").strip("*").lower()
            rows = [row for row in rows if needle in row["username"].lower()]
        user_id = query.get("user_id", "")
        if user_id.startswith("eq."):
            expected = user_id.removeprefix("eq.")
            rows = [row for row in rows if row["user_id"] == expected]
        elif user_id.startswith("neq."):
            excluded = user_id.removeprefix("neq.")
            rows = [row for row in rows if row["user_id"] != excluded]
        if query.get("order") == "username.asc":
            rows.sort(key=lambda row: row["username"])
        rows = rows[: int(query.get("limit", "100"))]
        selected = query.get("select", "*").split(",")
        return [{field: row.get(field) for field in selected} for row in rows]

    @staticmethod
    def _matches_key(key: str, key_filter: str) -> bool:
        if key_filter.startswith("eq."):
            return key == key_filter.removeprefix("eq.")
        if key_filter.startswith("like."):
            return key.startswith(key_filter.removeprefix("like.").removesuffix("*"))
        return True


def _headers(module, user_id: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {module._create_token(user_id)}"}


def test_friend_search_request_accept_and_remove(monkeypatch):
    """검색부터 요청·수락·양방향 친구 생성·삭제까지 한 번의 운영 계약으로 검증한다."""
    monkeypatch.setenv("OMJ_JWT_SECRET", "test-secret")
    module = importlib.import_module("api.index")
    fake = _FakeSocialDataApi()
    monkeypatch.setattr(module, "_data_api", lambda: fake)
    alice = _headers(module, "user-alice")
    bob = _headers(module, "user-bob")

    with TestClient(module.app) as client:
        searched = client.post("/social/friends/search", headers=alice, json={"query": "bob", "limit": 20})
        assert searched.status_code == 200
        assert [row["username"] for row in searched.json()["users"]] == ["bob0001", "bobby02"]

        created = client.post(
            "/social/friend-requests",
            headers=alice,
            json={"username": "bob0001", "message": "같이 공부해요"},
        )
        assert created.status_code == 201
        request_id = created.json()["request_id"]
        assert created.json()["direction"] == "outgoing"

        repeated = client.post(
            "/social/friend-requests",
            headers=alice,
            json={"username": "bob0001", "message": "같이 공부해요"},
        )
        assert repeated.status_code == 201
        assert repeated.json()["request_id"] == request_id
        assert len(fake.kv) == 2

        alice_requests = client.get("/social/friend-requests", headers=alice).json()["requests"]
        bob_requests = client.get("/social/friend-requests", headers=bob).json()["requests"]
        assert alice_requests[0]["direction"] == "outgoing"
        assert alice_requests[0]["username"] == "bob0001"
        assert bob_requests[0]["direction"] == "incoming"
        assert bob_requests[0]["username"] == "alice01"

        accepted = client.post(f"/social/friend-requests/{request_id}/accept", headers=bob)
        assert accepted.status_code == 200
        assert accepted.json()["username"] == "alice01"
        assert client.get("/social/friends", headers=alice).json()["friends"][0]["username"] == "bob0001"
        assert client.get("/social/friends", headers=bob).json()["friends"][0]["username"] == "alice01"
        assert client.get("/social/friend-requests", headers=alice).json()["requests"] == []
        assert client.get("/social/friend-requests", headers=bob).json()["requests"] == []

        duplicate = client.post("/social/friend-requests", headers=alice, json={"username": "bob0001"})
        assert duplicate.status_code == 409
        removed = client.post("/social/friends/remove", headers=alice, json={"username": "bob0001"})
        assert removed.status_code == 200
        assert client.get("/social/friends", headers=alice).json()["friends"] == []
        assert client.get("/social/friends", headers=bob).json()["friends"] == []


def test_friend_request_guards_and_cancel(monkeypatch):
    """본인 추가 차단과 발신 취소가 양쪽 대기 행을 함께 제거하는지 검증한다."""
    monkeypatch.setenv("OMJ_JWT_SECRET", "test-secret")
    module = importlib.import_module("api.index")
    fake = _FakeSocialDataApi()
    monkeypatch.setattr(module, "_data_api", lambda: fake)
    alice = _headers(module, "user-alice")
    bob = _headers(module, "user-bob")

    with TestClient(module.app) as client:
        assert client.post("/social/friend-requests", headers=alice, json={"username": "alice01"}).status_code == 400
        created = client.post("/social/friend-requests", headers=alice, json={"username": "bob0001"})
        request_id = created.json()["request_id"]
        cancelled = client.post(f"/social/friend-requests/{request_id}/cancel", headers=alice)
        assert cancelled.status_code == 200
        assert cancelled.json()["status"] == "cancelled"
        assert client.get("/social/friend-requests", headers=alice).json()["requests"] == []
        assert client.get("/social/friend-requests", headers=bob).json()["requests"] == []
        assert all("friend_request" not in key for _, key in fake.kv)
