from __future__ import annotations

import importlib
import json

from fastapi.testclient import TestClient


class _FakeChatResponse:
    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def read(self, _limit):
        return json.dumps(
            {"choices": [{"message": {"content": "먼저 식의 양변에서 같은 항을 정리해 보세요."}}]}
        ).encode()


def test_server_chat_returns_authenticated_tutor_reply(monkeypatch):
    monkeypatch.setenv("OMJ_JWT_SECRET", "test-secret")
    monkeypatch.setenv("COMETAPI_KEY", "test-provider-key")
    module = importlib.import_module("api.index")

    def fake_urlopen(request, timeout):
        assert request.full_url == "https://api.cometapi.com/v1/chat/completions"
        assert timeout == 30
        assert json.loads(request.data)["messages"][-1]["content"] == "이 방정식은 어떻게 풀어?"
        return _FakeChatResponse()

    monkeypatch.setattr(module.urllib.request, "urlopen", fake_urlopen)
    token = module._create_token("student-id")
    headers = {"Authorization": f"Bearer {token}"}
    with TestClient(module.app) as client:
        config = client.get("/serverchat/config", headers=headers)
        response = client.post(
            "/serverchat/message",
            headers=headers,
            json={"user_message": "이 방정식은 어떻게 풀어?"},
        )

    assert config.status_code == 200
    assert config.json()["enabled"] is True
    assert response.status_code == 200
    assert response.json()["assistant_message"].startswith("먼저 식의 양변")
    assert response.json()["model"] == "gpt-4o-mini"
