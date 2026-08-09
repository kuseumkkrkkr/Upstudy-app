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
        bob_conversation = client.get("/social/conversations", headers=bob).json()["messages"][0]
        assert bob_conversation["is_read"] is False
        alice_messages = client.get("/social/messages", headers=alice, params={"peer": "bob0001"})
        bob_messages = client.get("/social/messages", headers=bob, params={"peer": "alice01"})
        assert [item["text"] for item in alice_messages.json()["messages"]] == ["수락 확인 메시지"]
        assert bob_messages.json()["messages"][0]["is_mine"] is False
        assert client.get("/social/conversations", headers=alice).json()["messages"][0]["to"] == "bob0001"
        assert client.get("/social/conversations", headers=bob).json()["messages"][0]["from"] == "alice01"
        assert client.get("/social/conversations", headers=bob).json()["messages"][0]["is_read"] is True

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
        assert "member_ids" not in created.json()
        assert "creator_id" not in created.json()
        assert "password" not in created.text

        listed = client.get("/social/study-groups/mine", headers=alice)
        assert listed.status_code == 200
        assert [group["group_id"] for group in listed.json()["groups"]] == [created.json()["group_id"]]
        assert listed.json()["groups"][0]["name"] == "매일 수학"

        members = client.get(f"/social/study-groups/{created.json()['group_id']}/members", headers=alice)
        assert members.status_code == 200
        assert members.json() == [{"username": "alice01", "role": "admin"}]


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
        assert all("user_id" not in member for member in members.json())


def test_study_group_friend_invite_and_member_chat_contract(monkeypatch):
    """그룹 멤버 자신의 친구만 초대하며 초대된 멤버와 채팅 원장을 공유하는지 검증한다."""
    monkeypatch.setenv("OMJ_JWT_SECRET", "test-secret")
    module = importlib.import_module("api.index")
    fake = _FakeSocialDataApi()
    monkeypatch.setattr(module, "_data_api", lambda: fake)
    alice = _headers(module, "user-alice")
    bob = _headers(module, "user-bob")
    bobby = _headers(module, "user-bobby")

    with TestClient(module.app) as client:
        request = client.post(
            "/social/friend-requests",
            headers=alice,
            json={"username": "bob0001"},
        ).json()
        assert client.post(
            f"/social/friend-requests/{request['request_id']}/accept",
            headers=bob,
        ).status_code == 200

        group = client.post(
            "/social/study-groups",
            headers=alice,
            json={"name": "친구 수학방", "max_members": 4, "is_public": True},
        ).json()
        group_id = group["group_id"]

        denied = client.post(
            f"/social/study-groups/{group_id}/invite-friend",
            headers=alice,
            json={"username": "bobby02"},
        )
        assert denied.status_code == 403

        invited = client.post(
            f"/social/study-groups/{group_id}/invite-friend",
            headers=alice,
            json={"username": "bob0001"},
        )
        assert invited.status_code == 200
        assert invited.json()["group_id"] == group_id
        assert client.get("/social/study-groups/mine", headers=bob).json()["groups"] == []
        pending = client.get("/social/study-group-invitations", headers=bob)
        assert pending.status_code == 200
        assert pending.json()["invitations"][0]["group_name"] == "친구 수학방"
        assert "invited_by_user_id" not in pending.text
        repeated = client.post(
            f"/social/study-groups/{group_id}/invite-friend",
            headers=alice,
            json={"username": "bob0001"},
        )
        assert repeated.status_code == 200
        assert len(client.get("/social/study-group-invitations", headers=bob).json()["invitations"]) == 1
        accepted = client.post(
            f"/social/study-group-invitations/{group_id}/accept",
            headers=bob,
        )
        assert accepted.status_code == 200
        assert accepted.json()["members"] == 2
        assert client.get("/social/study-groups/mine", headers=bob).json()["groups"][0]["group_id"] == group_id
        assert client.get("/social/study-group-invitations", headers=bob).json()["invitations"] == []

        first = client.post(
            f"/social/study-groups/{group_id}/messages",
            headers=alice,
            json={"text": "  첫 메시지  "},
        )
        assert first.status_code == 201
        assert first.json()["text"] == "첫 메시지"
        assert first.json()["sender_name"] == "앨리스"
        assert first.json()["is_mine"] is True
        assert "user_id" not in first.json()
        assert client.get(
            f"/social/study-groups/{group_id}/messages",
            headers=bob,
        ).json()["messages"][0]["message_id"] == first.json()["message_id"]

        second = client.post(
            f"/social/study-groups/{group_id}/messages",
            headers=bob,
            json={"text": "답장"},
        )
        assert second.status_code == 201
        messages = client.get(
            f"/social/study-groups/{group_id}/messages",
            headers=alice,
        ).json()["messages"]
        assert [message["text"] for message in messages] == ["첫 메시지", "답장"]
        previous = client.get(
            f"/social/study-groups/{group_id}/messages",
            headers=alice,
            params={"before": second.json()["created_at"]},
        ).json()["messages"]
        assert [message["text"] for message in previous] == ["첫 메시지"]
        assert client.get(f"/social/study-groups/{group_id}/messages", headers=bobby).status_code == 404
        assert client.post(
            f"/social/study-groups/{group_id}/messages",
            headers=bobby,
            json={"text": "침입"},
        ).status_code == 404


def test_study_group_roles_schedule_removal_transfer_and_delete(monkeypatch):
    """초대 거절과 관리자 계층의 일정·추방·양도·삭제 권한을 서버에서 검증한다."""
    monkeypatch.setenv("OMJ_JWT_SECRET", "test-secret")
    module = importlib.import_module("api.index")
    fake = _FakeSocialDataApi()
    monkeypatch.setattr(module, "_data_api", lambda: fake)
    alice = _headers(module, "user-alice")
    bob = _headers(module, "user-bob")
    bobby = _headers(module, "user-bobby")

    with TestClient(module.app) as client:
        for username, target_headers in (("bob0001", bob), ("bobby02", bobby)):
            request = client.post(
                "/social/friend-requests",
                headers=alice,
                json={"username": username},
            ).json()
            assert client.post(
                f"/social/friend-requests/{request['request_id']}/accept",
                headers=target_headers,
            ).status_code == 200

        group_id = client.post(
            "/social/study-groups",
            headers=alice,
            json={"name": "권한 검증방", "max_members": 5},
        ).json()["group_id"]

        assert client.post(
            f"/social/study-groups/{group_id}/invite-friend",
            headers=alice,
            json={"username": "bobby02"},
        ).status_code == 200
        assert client.post(
            f"/social/study-group-invitations/{group_id}/reject",
            headers=bobby,
        ).status_code == 200
        assert client.get("/social/study-groups/mine", headers=bobby).json()["groups"] == []

        for username, target_headers in (("bob0001", bob), ("bobby02", bobby)):
            assert client.post(
                f"/social/study-groups/{group_id}/invite-friend",
                headers=alice,
                json={"username": username},
            ).status_code == 200
            assert client.post(
                f"/social/study-group-invitations/{group_id}/accept",
                headers=target_headers,
            ).status_code == 200

        promoted = client.post(
            f"/social/study-groups/{group_id}/members/bob0001/role",
            headers=alice,
            json={"role": "deputy"},
        )
        assert promoted.status_code == 200
        assert {member["username"]: member["role"] for member in promoted.json()} == {
            "alice01": "admin",
            "bob0001": "deputy",
            "bobby02": "member",
        }
        assert client.post(
            f"/social/study-groups/{group_id}/members/bobby02/role",
            headers=bob,
            json={"role": "deputy"},
        ).status_code == 403

        schedule = client.post(
            f"/social/study-groups/{group_id}/schedules",
            headers=bob,
            json={"title": "부관리자 일정", "scheduled_date": "2099-01-01", "scheduled_time": "18:30"},
        )
        assert schedule.status_code == 201
        assert client.post(
            f"/social/study-groups/{group_id}/schedules",
            headers=bobby,
            json={"title": "권한 없음", "scheduled_date": "2099-01-01"},
        ).status_code == 403
        assert client.get(
            f"/social/study-groups/{group_id}/schedules",
            headers=alice,
        ).json()["schedules"][0]["title"] == "부관리자 일정"

        assert client.delete(
            f"/social/study-groups/{group_id}/members/bobby02",
            headers=bob,
        ).status_code == 200
        assert client.get(f"/social/study-groups/{group_id}/members", headers=bobby).status_code == 404

        transferred = client.post(
            f"/social/study-groups/{group_id}/members/bob0001/role",
            headers=alice,
            json={"role": "admin"},
        )
        assert transferred.status_code == 200
        assert {member["username"]: member["role"] for member in transferred.json()} == {
            "bob0001": "admin",
            "alice01": "member",
        }
        assert client.delete(f"/social/study-groups/{group_id}", headers=alice).status_code == 403
        assert client.delete(f"/social/study-groups/{group_id}", headers=bob).status_code == 200
        assert client.get("/social/study-groups/mine", headers=alice).json()["groups"] == []
        assert client.get("/social/study-groups/mine", headers=bob).json()["groups"] == []
