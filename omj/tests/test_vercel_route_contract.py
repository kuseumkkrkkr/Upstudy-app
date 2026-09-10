"""FastAPI route registration invariants for the Vercel adapter."""

import json
from collections import Counter
from pathlib import Path

from fastapi.routing import APIRoute

import api.index as vercel_api


def test_each_http_method_path_is_registered_once():
    """A duplicated decorator must not shadow the intended handler."""

    registrations = Counter(
        (route.path, method)
        for route in vercel_api.app.routes
        if isinstance(route, APIRoute)
        for method in route.methods
    )
    duplicates = {
        key: count for key, count in registrations.items() if count > 1
    }
    assert duplicates == {}


def test_graph_sampling_path_is_forwarded_to_fastapi():
    """그래프 좌표 요청이 정적 index.html fallback으로 소비되지 않아야 한다."""

    config = json.loads(
        (Path(__file__).resolve().parents[2] / "vercel.json").read_text(
            encoding="utf-8"
        )
    )
    api_route = next(
        route for route in config["routes"] if route.get("dest") == "/api/index.py"
    )
    assert "graphs" in api_route["src"]
    assert "/graphs/sample" in {
        route.path for route in vercel_api.app.routes if isinstance(route, APIRoute)
    }
