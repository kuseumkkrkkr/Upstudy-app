from fastapi.testclient import TestClient

from api.index import app


def test_graph_sample_returns_real_coordinates() -> None:
    with TestClient(app) as client:
        response = client.post(
            "/graphs/sample",
            json={
                "expressions": [
                    {
                        "id": "line-1",
                        "label": "y=2x+1",
                        "color_hex": "#2F7CF6",
                        "expression": "2*x+1",
                    }
                ],
                "left": -1,
                "right": 1,
                "samples": 41,
            },
        )

    assert response.status_code == 200
    series = response.json()["series"][0]
    assert series["point_count"] == 41
    segment = series["segments"][0]
    zero_index = segment["x_values"].index(0.0)
    assert segment["y_values"][zero_index] == 1.0


def test_graph_sample_rejects_python_access() -> None:
    with TestClient(app) as client:
        response = client.post(
            "/graphs/sample",
            json={
                "expressions": [
                    {
                        "id": "unsafe",
                        "expression": "__import__('os').system('whoami')",
                    }
                ]
            },
        )

    assert response.status_code == 422


def test_graph_sample_rejects_excessive_power() -> None:
    with TestClient(app) as client:
        response = client.post(
            "/graphs/sample",
            json={
                "expressions": [
                    {"id": "expensive", "expression": "9^(9^9)"},
                ]
            },
        )

    assert response.status_code == 422
