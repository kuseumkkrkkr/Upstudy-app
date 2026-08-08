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
            rows = body if isinstance(body, list) else [body]
            for row in rows:
                self.kv[(row["user_id"], row["key"])] = row["value"]
            return None
        user_id = query.get("user_id", "").removeprefix("eq.")
        key_filter = query.get("key", "")
        value_filter = query.get("value", "")
        if method == "DELETE":
            key = key_filter.removeprefix("eq.")
            self.kv.pop((user_id, key), None)
            return None
        rows = [
            {"user_id": owner, "key": key, "value": value}
            for (owner, key), value in self.kv.items()
            if (not user_id or owner == user_id)
            and self._matches_key(key, key_filter)
            and self._matches_value(value, value_filter)
        ]
        rows = rows[: int(query.get("limit", "100"))]
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

    @staticmethod
    def _matches_value(value: str, value_filter: str) -> bool:
        if value_filter.startswith("ilike."):
            needle = value_filter.removeprefix("ilike.").strip("*").lower()
            return needle in value.lower()
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

        sent = client.post(
            "/social/messages",
            headers=alice,
            json={"peer": "bob0001", "text": "수락 확인 메시지"},
        )
        assert sent.status_code == 200
        assert sent.json()["is_mine"] is True
        alice_messages = client.get("/social/messages", headers=alice, params={"peer": "bob0001"})
        bob_messages = client.get("/social/messages", headers=bob, params={"peer": "alice01"})
        assert [item["text"] for item in alice_messages.json()["messages"]] == ["수락 확인 메시지"]
        assert bob_messages.json()["messages"][0]["is_mine"] is False
        assert client.get("/social/conversations", headers=alice).json()["messages"][0]["to"] == "bob0001"
        assert client.get("/social/conversations", headers=bob).json()["messages"][0]["from"] == "alice01"

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

        blocked = client.post(
            "/social/messages",
            headers=alice,
            json={"peer": "bob0001", "text": "친구 전 메시지"},
        )
        assert blocked.status_code == 403


def test_study_group_create_and_list_contract(monkeypatch):
    """앱과 같은 생성 요청이 201로 저장되고 groups 목록에 즉시 보이는지 검증한다."""
    monkeypatch.setenv("OMJ_JWT_SECRET", "test-secret")
    module = importlib.import_module("api.index")
    fake = _FakeSocialDataApi()
    monkeypatch.setattr(module, "_data_api", lambda: fake)
    alice = _headers(module, "user-alice")

    with TestClient(module.app) as client:
        created = client.post(
            "/social/study-groups",
            headers=alice,
            json={
                "name": "매일 수학",
                "description": "한 문제씩 풀기",
                "max_members": 12,
                "is_public": True,
                "lock_enabled": True,
                "password": "1234",
            },
        )
        assert created.status_code == 201
        assert created.json()["members"] == 1
        assert created.json()["member_ids"] == ["user-alice"]
        assert "password" not in created.text

        listed = client.get("/social/study-groups/mine", headers=alice)
        assert listed.status_code == 200
        assert [group["group_id"] for group in listed.json()["groups"]] == [created.json()["group_id"]]
        assert listed.json()["groups"][0]["name"] == "매일 수학"

        members = client.get(f"/social/study-groups/{created.json()['group_id']}/members", headers=alice)
        assert members.status_code == 200
        assert members.json() == [{"user_id": "user-alice", "username": "alice01"}]


def test_study_group_search_invite_and_join_contract(monkeypatch):
    """다른 사용자의 공개 그룹 검색과 코드 확인·참가가 내 목록과 멤버에 반영되는지 검증한다."""
    monkeypatch.setenv("OMJ_JWT_SECRET", "test-secret")
    module = importlib.import_module("api.index")
    fake = _FakeSocialDataApi()
    monkeypatch.setattr(module, "_data_api", lambda: fake)
    alice = _headers(module, "user-alice")
    bob = _headers(module, "user-bob")

    with TestClient(module.app) as client:
        created = client.post(
            "/social/study-groups",
            headers=alice,
            json={
                "name": "중등 수학 같이 공부",
                "description": "매일 한 문제",
                "max_members": 12,
                "is_public": True,
                "lock_enabled": True,
                "password": "1234",
                "invite_code": "MATH-24",
            },
        ).json()

        searched = client.get("/social/study-groups/search?q=중등 수학&limit=10", headers=bob)
        assert searched.status_code == 200
        assert [group["group_id"] for group in searched.json()["groups"]] == [created["group_id"]]
        assert "password_hash" not in searched.text

        invite = client.get("/social/study-groups/invite/math-24", headers=bob)
        assert invite.status_code == 200
        assert invite.json()["name"] == "중등 수학 같이 공부"
        assert invite.json()["lock_enabled"] is True

        denied = client.post(
            "/social/study-groups/join-by-code",
            headers=bob,
            json={"invite_code": "MATH-24", "password": "9999"},
        )
        assert denied.status_code == 400

        joined = client.post(
            "/social/study-groups/join-by-code",
            headers=bob,
            json={"invite_code": "MATH-24", "password": "1234"},
        )
        assert joined.status_code == 200
        assert joined.json()["members"] == 2
        assert client.get("/social/study-groups/search?q=중등 수학", headers=bob).json()["groups"] == []
        assert client.get("/social/study-groups/mine", headers=bob).json()["groups"][0]["group_id"] == created["group_id"]

        members = client.get(f"/social/study-groups/{created['group_id']}/members", headers=alice)
        assert {member["username"] for member in members.json()} == {"alice01", "bob0001"}
