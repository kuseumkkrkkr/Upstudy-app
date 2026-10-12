"""Lightning is an OCR caller of Vercel, not a database/API owner."""
from __future__ import annotations

import base64
import importlib
import sys
from types import ModuleType

import pytest


class _Response:
    def __init__(self, value):
        self.value = value

    def raise_for_status(self):
        return None

    def json(self):
        return self.value


class _Client:
    def __init__(self):
        self.calls = []

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return None

    def post(self, path, *, json):
        self.calls.append((path, json))
        if path == "/internal/ocr/claim":
            if sum(1 for item in self.calls if item[0] == path) == 1:
                return _Response([{
                    "id": "5d94e310-4fa3-4659-ac29-182e22ce5f20",
                    "mode": "ocr",
                    "payload": {
                        "student_work_image": base64.b64encode(b"image").decode(),
                        "writing_events": [{"stroke_id": 1}],
                    },
                }])
            return _Response([])
        return _Response({"completed": True})


def test_worker_claims_projects_and_completes_through_vercel_only(monkeypatch):
    recognized = []

    def recognize(image, writing_events):
        recognized.append((image, writing_events))
        return {
            "all_formulas": ["x+1"],
            "purple_formulas": [],
            "all_ocr": "x+1",
            "user_answer": "x+1",
            "ocr_source": "texteller_grid",
            "accepted": True,
            "warnings": [],
            "grids": [],
            "cache_hit": False,
        }

    services = ModuleType("services")
    services.__path__ = []
    ocr = ModuleType("services.ocr")
    ocr.__path__ = []
    texteller = ModuleType("services.ocr.texteller_grid")
    texteller.extract_math_with_texteller_grid = recognize
    monkeypatch.setitem(sys.modules, "services", services)
    monkeypatch.setitem(sys.modules, "services.ocr", ocr)
    monkeypatch.setitem(sys.modules, "services.ocr.texteller_grid", texteller)
    worker = importlib.import_module("deploy.lightning.worker_app")

    client = _Client()
    create_client = worker._client
    monkeypatch.setenv("VERCEL_API_BASE_URL", "https://aiflow-web-canary.vercel.app")
    monkeypatch.setenv("VERCEL_OCR_WORKER_SECRET", "worker-secret")
    monkeypatch.setattr(worker, "_client", lambda: client)
    worker._process_available_jobs()

    assert recognized == [(b"image", [{"stroke_id": 1}])]
    assert [call[0] for call in client.calls] == [
        "/internal/ocr/claim",
        "/internal/ocr/jobs/5d94e310-4fa3-4659-ac29-182e22ce5f20/complete",
        "/internal/ocr/claim",
    ]
    assert all("/rest/v1" not in call[0] for call in client.calls)
    assert "p_worker_id" not in client.calls[0][1]

    for untrusted_url in (
        "http://aiflow-web-canary.vercel.app",
        "https://aiflow-web-canary.vercel.app.evil.test",
        "https://worker.example",
        "https://user:password@aiflow-web-canary.vercel.app",
        "https://aiflow-web-canary.vercel.app/private-prefix",
        "https://aiflow-web-canary.vercel.app:8443",
    ):
        monkeypatch.setenv("VERCEL_API_BASE_URL", untrusted_url)
        with pytest.raises(RuntimeError, match="configuration is invalid"):
            create_client()
