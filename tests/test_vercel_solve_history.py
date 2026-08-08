from __future__ import annotations

import importlib

from fastapi.testclient import TestClient


class _FakeHistoryDataApi:
    def __init__(self) -> None:
        self.rows: dict[tuple[str, str], str] = {}

    def request(self, method, path, *, query=None, body=None, prefer=None):
        assert path == "canary_user_kv"
        if method == "POST":
            self.rows[(str(body["user_id"]), str(body["key"]))] = str(body["value"])
            return None
        if method == "GET":
            user_id = str(query["user_id"]).removeprefix("eq.")
            prefix = str(query["key"]).removeprefix("like.").removesuffix("*")
            return [
                {"key": key, "value": value}
                for (row_user_id, key), value in self.rows.items()
                if row_user_id == user_id and key.startswith(prefix)
            ]
        raise AssertionError((method, path, query, body, prefer))


def test_incorrect_solve_is_returned_for_review(monkeypatch):
    monkeypatch.setenv("OMJ_JWT_SECRET", "test-secret")
    module = importlib.import_module("api.index")
    fake = _FakeHistoryDataApi()
    monkeypatch.setattr(module, "_data_api", lambda: fake)
    token = module._create_token("student-id")
    headers = {"Authorization": f"Bearer {token}"}

    with TestClient(module.app) as client:
        saved = client.post(
            "/history/solve",
            headers=headers,
            json={"quest_id": "quest-wrong-1", "is_correct": False},
        )
        history = client.get(
            "/history/solve?days=30&limit=100&kind=problem",
            headers=headers,
        )

    assert saved.status_code == 200
    assert history.status_code == 200
    assert history.json()["items"] == [
        {
            "created_at": history.json()["items"][0]["created_at"],
            "kind": "problem",
            "quest_id": "quest-wrong-1",
            "codebase_id": None,
            "seed": None,
            "data": {"is_correct": False, "tags": []},
        }
    ]
