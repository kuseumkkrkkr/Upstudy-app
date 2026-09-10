"""FastAPI route registration invariants for the Vercel adapter."""

from collections import Counter

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
