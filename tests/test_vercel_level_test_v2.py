"""Level-test placement v2 reads the approved server-only Supabase bank."""
import importlib
import json
import re
import sqlite3
from pathlib import Path

import pytest
from fastapi.testclient import TestClient


class _MemoryUserKv:
    def __init__(self):
        self.values = {}
        self.rpc_calls = []
        self.fail_next_key = None
        tracks = (
            "middle_grade_1", "middle_grade_2", "middle_grade_3",
            "high_algebra", "high_common_math_1_2", "high_calculus_1",
            "high_calculus_2", "high_geometry", "high_probability_statistics",
        )
        self.question_bank = []
        question_index = 0
        for track in tracks:
            for form in "ABCS":
                count = 10 if form == "S" else 25
                for index in range(1, count + 1):
                    question_index += 1
                    question_id = f"leveltest-{track}-{form}-q{index:03d}"
                    self.question_bank.append({
                        "question_id": question_id,
                        "version": "expanded-v1",
                        "question_index": question_index,
                        "quest_title": f"{question_index} + 1의 값은?",
                        "quest_answer": str(question_index + 1),
                        "solves": [{"flow": "정답을 확인한다."}],
                        "tags": ["#테스트"],
                        "difficulty_tier": (question_index - 1) % 5 + 1,
                        "answer_format": "short_integer",
                        "parent_id": question_id,
                    })
        for variant_index in range(1, 12):
            parent_id = f"leveltest-high_common_math_1_2-C-q001"
            question_index += 1
            self.question_bank.append({
                "question_id": f"{parent_id}-nv{variant_index}",
                "version": "expanded-v1",
                "question_index": question_index,
                "quest_title": f"{question_index} + 1의 값은?",
                "quest_answer": str(question_index + 1),
                "solves": [{"flow": "정답을 확인한다."}],
                "tags": ["#테스트"],
                "difficulty_tier": (question_index - 1) % 5 + 1,
                "answer_format": "short_integer",
                "parent_id": parent_id,
            })

    def request(self, method, path, *, query=None, body=None, prefer=None):
        if path == "level_test_question_bank":
            assert method == "GET"
            assert query["version"] == "eq.expanded-v1"
            return self.question_bank
        if path == "rpc/commit_level_test_session":
            assert method == "POST"
            self.rpc_calls.append(body)
            row_key = (body["p_user_id"], body["p_key"])
            if self.values.get(row_key) != body["p_expected_value"]:
                return False
            self.values[row_key] = body["p_new_value"]
            return True
        assert path == "canary_user_kv"
        query = query or {}
        if method == "POST":
            if body["key"] == self.fail_next_key:
                self.fail_next_key = None
                raise RuntimeError("temporary storage failure")
            self.values[(body["user_id"], body["key"])] = body["value"]
            return None
        user_id = query.get("user_id", "").removeprefix("eq.")
        key = query.get("key", "").removeprefix("eq.")
        row_key = (user_id, key)
        if method == "GET":
            return [{"value": self.values[row_key]}] if row_key in self.values else []
        if method == "PATCH":
            expected = query.get("value", "").removeprefix("eq.")
            if self.values.get(row_key) != expected:
                return []
            self.values[row_key] = body["value"]
            return [{"value": self.values[row_key]}]
        raise AssertionError((method, path))


def _expanded_source_rows():
    """Read the committed expanded-v1 SQLite artifact without opening it for writes."""
    root = Path(__file__).resolve().parents[1] / "data" / "content" / "leveltest-expanded-v1"
    audit = json.loads((root / "leveltest_final_expanded.audit.json").read_text(encoding="utf-8"))
    database = root / "leveltest_final_expanded.db"
    with sqlite3.connect(f"file:{database.as_posix()}?mode=ro", uri=True) as connection:
        rows = connection.execute(
            "SELECT quest_title, quest_answer, solves_json FROM question ORDER BY rowid"
        ).fetchall()

    assert len(rows) == len(audit["records"]) == 776
    question_bank = []
    pattern = re.compile(r"^leveltest-(?P<track>.+)-(?P<form>[ABCS])-q\d+(?:-nv\d+)?$")
    for index, (record, row) in enumerate(zip(audit["records"], rows, strict=True), start=1):
        match = pattern.fullmatch(record["question_id"])
        assert match is not None
        title, answer, solves_json = row
        question_bank.append({
            "question_id": record["question_id"],
            "version": "expanded-v1",
            "question_index": index,
            "quest_title": title,
            "quest_answer": answer,
            "solves": json.loads(solves_json),
            "tags": record["tags"],
            "difficulty_tier": record["difficulty_tier"],
            "answer_format": record["answer_format"],
            "parent_id": record.get("numeric_variant_of") or record["question_id"],
            "track_id": match["track"],
            "form": match["form"],
        })
    return question_bank


def test_approved_level_test_database_starts_and_grades_once(monkeypatch):
    api = importlib.import_module("api.index")
    api._load_level_test_question_bank.cache_clear()
    fake = _MemoryUserKv()
    monkeypatch.setattr(api, "_data_api", lambda: fake)
    previous = dict(api.app.dependency_overrides)
    api.app.dependency_overrides[api._current_user] = lambda: "level-test-student"
    try:
        bank = api._load_level_test_question_bank()
        stats = api.get_level_test_placement_stats()
        assert len(bank) == stats["data"]["pool_count"]
        assert stats["data"]["question_count"] == 25
        assert stats["data"]["quick_question_count"] == 10
        assert len(stats["data"]["tracks"]) == 9
        common = next(track for track in stats["data"]["tracks"] if track["id"] == "high_common_math_1_2")
        assert {form["id"]: form["question_count"] for form in common["forms"]} == {
            "A": 25, "B": 25, "C": 25, "S": 10,
        }

        client = TestClient(api.app)
        rejected_track = client.post(
            "/level-tests/placement/start",
            json={"track_id": "untrusted/path", "form": "B"},
        )
        assert rejected_track.status_code == 400
        started = client.post(
            "/level-tests/placement/start",
            json={"track_id": "high_common_math_1_2", "form": "C"},
        )
        assert started.status_code == 200
        envelope = started.json()["data"]
        assert len(envelope["questions"]) == 25
        assert envelope["track_id"] == "high_common_math_1_2"
        assert envelope["form"] == "C"
        assert all(question["quest_id"].startswith("leveltest-high_common_math_1_2-C-") for question in envelope["questions"])
        assert len({state_question["parent_id"] for state_question in json.loads(fake.values[("level-test-student", f"level_test.v2.session.{envelope['session_id']}")])["questions"]}) == 25
        state_key = f"level_test.v2.session.{envelope['session_id']}"
        state = json.loads(fake.values[("level-test-student", state_key)])
        submitted_answers = []
        for index, question in enumerate(state["questions"], start=1):
            answer = {
                "item_index": index,
                "quest_id": question["quest_id"],
                "user_answer": question["quest_answer"],
            }
            if question["answer_format"] == "multiple_choice":
                answer["selected_index"] = api._multiple_choice_index(question["quest_answer"])
            submitted_answers.append(answer)
        payload = {"answers": submitted_answers, "elapsed_seconds": 420}
        submitted = client.post(
            f"/level-tests/placement/{envelope['session_id']}/submit", json=payload
        )
        assert submitted.status_code == 200
        result = submitted.json()["data"]
        assert result["correct_count"] == 25
        assert result["question_count"] == 25
        assert result["track_id"] == "high_common_math_1_2"
        assert result["form"] == "C"
        assert int(result["completed_at"]) > 0
        assert len(fake.rpc_calls) == 1
        assert "value" not in fake.rpc_calls[0]
        assert len(fake.rpc_calls[0]["p_expected_value"]) > 0
        replay = client.post(
            f"/level-tests/placement/{envelope['session_id']}/submit", json=payload
        )
        assert replay.status_code == 200
        assert replay.json()["data"] == result

        quick = client.post(
            "/level-tests/placement/start",
            json={"track_id": "middle_grade_1", "form": "S"},
        )
        assert quick.status_code == 200
        quick_data = quick.json()["data"]
        assert quick_data["question_count"] == 10
        assert all(question["quest_id"].startswith("leveltest-middle_grade_1-S-") for question in quick_data["questions"])
        quick_state = json.loads(fake.values[("level-test-student", f"level_test.v2.session.{quick_data['session_id']}")])
        quick_answers = [
            {"item_index": index, "quest_id": question["quest_id"], "user_answer": question["quest_answer"]}
            for index, question in enumerate(quick_state["questions"], start=1)
        ]
        incomplete = client.post(
            f"/level-tests/placement/{quick_data['session_id']}/submit",
            json={"answers": quick_answers[:-1], "elapsed_seconds": 120},
        )
        assert incomplete.status_code == 400
        quick_submit = client.post(
            f"/level-tests/placement/{quick_data['session_id']}/submit",
            json={"answers": quick_answers, "elapsed_seconds": 120},
        )
        assert quick_submit.status_code == 200
        assert quick_submit.json()["data"]["question_count"] == 10
        assert quick_submit.json()["data"]["accuracy"] == 1
        replay_old = client.post(
            f"/level-tests/placement/{envelope['session_id']}/submit", json=payload
        )
        assert replay_old.status_code == 200
        latest_result = json.loads(
            fake.values[("level-test-student", "level_test.v2.latest_result")]
        )
        assert latest_result["session_id"] == quick_data["session_id"]
    finally:
        api._load_level_test_question_bank.cache_clear()
        api.app.dependency_overrides.clear()
        api.app.dependency_overrides.update(previous)


@pytest.mark.parametrize("failed_result_key", ["result", "latest_result"])
def test_committed_placement_result_repairs_derived_keys_after_temporary_write_failure(
    monkeypatch, failed_result_key
):
    api = importlib.import_module("api.index")
    api._load_level_test_question_bank.cache_clear()
    fake = _MemoryUserKv()
    monkeypatch.setattr(api, "_data_api", lambda: fake)
    previous = dict(api.app.dependency_overrides)
    api.app.dependency_overrides[api._current_user] = lambda: "placement-recovery-student"
    try:
        client = TestClient(api.app)
        started = client.post(
            "/level-tests/placement/start",
            json={"track_id": "high_geometry", "form": "C"},
        )
        assert started.status_code == 200
        session_id = started.json()["data"]["session_id"]
        state = json.loads(
            fake.values[("placement-recovery-student", f"level_test.v2.session.{session_id}")]
        )
        answers = [
            {"item_index": index, "quest_id": question["quest_id"],
             "user_answer": question["quest_answer"]}
            for index, question in enumerate(state["questions"], start=1)
        ]
        payload = {"answers": answers, "elapsed_seconds": 300}
        fake.fail_next_key = (
            f"level_test.v2.result.{session_id}"
            if failed_result_key == "result"
            else "level_test.v2.latest_result"
        )
        first_submit = client.post(
            f"/level-tests/placement/{session_id}/submit", json=payload
        )
        assert first_submit.status_code == 503
        assert len(fake.rpc_calls) == 1

        retry = client.post(f"/level-tests/placement/{session_id}/submit", json=payload)
        assert retry.status_code == 200
        recovered = retry.json()["data"]
        status = client.get("/level-tests/placement/status")
        assert status.status_code == 200
        assert status.json()["data"]["completed"] is True
        assert status.json()["data"]["result"] == recovered
        assert len(fake.rpc_calls) == 1
    finally:
        api._load_level_test_question_bank.cache_clear()
        api.app.dependency_overrides.clear()
        api.app.dependency_overrides.update(previous)


def test_committed_expanded_database_runs_every_form_and_grades_test_answers(monkeypatch):
    api = importlib.import_module("api.index")
    api._load_level_test_question_bank.cache_clear()
    fake = _MemoryUserKv()
    fake.question_bank = _expanded_source_rows()
    monkeypatch.setattr(api, "_data_api", lambda: fake)
    previous = dict(api.app.dependency_overrides)
    api.app.dependency_overrides[api._current_user] = lambda: "expanded-db-test-student"
    try:
        bank = api._load_level_test_question_bank()
        assert len(bank) == 776
        for track_id in api.LEVEL_TEST_TRACK_LABELS:
            for form in api.LEVEL_TEST_FORM_LABELS:
                selected = api._select_level_test_questions(track_id, form)
                expected = 10 if form == "S" else 25
                assert len(selected) == expected
                assert len({question["parent_id"] for question in selected}) == expected

        client = TestClient(api.app)
        started = client.post(
            "/level-tests/placement/start",
            json={"track_id": "high_geometry", "form": "C"},
        )
        assert started.status_code == 200
        envelope = started.json()["data"]
        session_key = ("expanded-db-test-student", f"level_test.v2.session.{envelope['session_id']}")
        session = json.loads(fake.values[session_key])
        assert len(session["questions"]) == 25
        assert len({question["parent_id"] for question in session["questions"]}) == 25
        answers = []
        expected_correct: dict[str, bool] = {}
        for item_index, question in enumerate(session["questions"], start=1):
            is_correct = item_index > 3
            expected_correct[question["quest_id"]] = is_correct
            answer = {
                "item_index": item_index,
                "quest_id": question["quest_id"],
                "user_answer": question["quest_answer"],
            }
            if question["answer_format"] == "multiple_choice":
                correct_index = api._multiple_choice_index(question["quest_answer"])
                answer["selected_index"] = (
                    correct_index if is_correct else (correct_index + 1) % 5
                )
            elif not is_correct:
                answer["user_answer"] = "not-the-answer"
            answers.append(answer)
        submitted = client.post(
            f"/level-tests/placement/{envelope['session_id']}/submit",
            json={"answers": answers, "elapsed_seconds": 600},
        )
        assert submitted.status_code == 200
        result = submitted.json()["data"]
        assert result["question_count"] == 25
        assert result["correct_count"] == 22
        assert result["accuracy"] == 0.88
        assert result["track_id"] == "high_geometry"
        assert result["form"] == "C"
        expected_tiers: dict[int, list[int]] = {}
        expected_tags: dict[str, list[int]] = {}
        for question in session["questions"]:
            correct = expected_correct[question["quest_id"]]
            tier_counts = expected_tiers.setdefault(int(question["difficulty_tier"]), [0, 0])
            tier_counts[0] += int(correct)
            tier_counts[1] += 1
            for tag in question["tags"]:
                tag_counts = expected_tags.setdefault(str(tag), [0, 0])
                tag_counts[0] += int(correct)
                tag_counts[1] += 1
        assert result["difficulty_results"] == [
            {"tier": tier, "correct": counts[0], "total": counts[1],
             "accuracy": round(counts[0] / counts[1], 4)}
            for tier, counts in sorted(expected_tiers.items())
        ]
        expected_tag_results = [
            {"tag": tag, "correct": counts[0], "total": counts[1],
             "accuracy": round(counts[0] / counts[1], 4)}
            for tag, counts in expected_tags.items()
        ]
        assert result["weak_tags"] == sorted(
            expected_tag_results, key=lambda item: (item["accuracy"], item["tag"])
        )[:5]
        assert result["strong_tags"] == sorted(
            expected_tag_results, key=lambda item: (-item["accuracy"], item["tag"])
        )[:5]
        assert "placement" not in result
        assert "rating" not in result
        assert len(fake.rpc_calls) == 1
    finally:
        api._load_level_test_question_bank.cache_clear()
        api.app.dependency_overrides.clear()
        api.app.dependency_overrides.update(previous)


def test_level_test_health_checks_expanded_bank_count_version_and_order(monkeypatch):
    api = importlib.import_module("api.index")

    class _HealthDataApi:
        def __init__(self):
            self.questions = [
                {
                    "question_id": row["question_id"],
                    "version": "expanded-v1",
                    "question_index": index,
                }
                for index, row in enumerate(_expanded_source_rows(), start=1)
            ]

        def request(self, method, path, *, query=None, body=None, prefer=None):
            del body, prefer
            assert method == "GET"
            if path == "level_test_question_bank":
                return self.questions[: int(query["limit"])]
            return [{}]

    fake = _HealthDataApi()
    monkeypatch.setattr(api, "_data_api", lambda: fake)
    ready = api.level_test_health()
    assert ready["status"] == "ok"
    assert ready["checks"]["expanded_v1_question_bank"] is True
    client = TestClient(api.app)
    assert client.get("/health/ready").status_code == 200

    fake.questions.pop()
    unavailable = api.level_test_health()
    assert unavailable["status"] == "unavailable"
    assert unavailable["checks"]["expanded_v1_question_bank"] is False
    assert client.get("/health/ready").status_code == 503
