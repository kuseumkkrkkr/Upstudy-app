import unittest
from pathlib import Path
import sys
from unittest.mock import patch

from fastapi.testclient import TestClient

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

import server
from generater import problem_solve


class ProblemSolveSingleCountTests(unittest.TestCase):
    def test_generate_problem_set_accepts_single_question(self) -> None:
        def fake_generate_codebase(tags, tier, rng):
            return {"id": 1, "code": "", "tags": tags, "tier": tier}

        def fake_build_quest(entry, tags, params, seed, question_type, raw_result=None):
            return {
                "header": {"quest_id": f"dummy-{seed}"},
                "info": {"difficulty_tier": entry["tier"]},
                "data": {"quest_title": "dummy"},
                "solves": [],
            }

        with (
            patch.object(problem_solve, "load_codebases", return_value=[]),
            patch.object(problem_solve, "list_cached_seeds", return_value=[]),
            patch.object(
                problem_solve,
                "run_codebase_batch",
                side_effect=lambda entry, seeds, **kwargs: [
                    {"ok": True} for _ in seeds
                ],
            ),
            patch.object(
                problem_solve,
                "_generate_and_store_codebase",
                side_effect=fake_generate_codebase,
            ),
            patch.object(
                problem_solve,
                "_build_quest_from_codebase",
                side_effect=fake_build_quest,
            ),
        ):
            quests = problem_solve.generate_problem_set(
                hash_tags=["#기울기"],
                min_difficulty_tier=1,
                max_difficulty_tier=1,
                question_count=1,
                seed=1234,
            )

        self.assertEqual(len(quests), 1)
        self.assertEqual(quests[0]["info"]["difficulty_tier"], 1)

    def test_generate_problem_set_rejects_zero_questions(self) -> None:
        with self.assertRaisesRegex(ValueError, "between 1 and 500"):
            problem_solve.generate_problem_set(
                hash_tags=["#기울기"],
                min_difficulty_tier=1,
                max_difficulty_tier=1,
                question_count=0,
            )

    def test_stream_endpoint_accepts_single_question_request(self) -> None:
        def fake_generate_problem_set(**kwargs):
            self.assertEqual(kwargs["question_count"], 1)
            return [
                {
                    "header": {"quest_id": "dummy-route"},
                    "info": {"difficulty_tier": 1},
                    "data": {"quest_title": "dummy"},
                    "solves": [],
                }
            ]

        server.app.dependency_overrides[server._get_user_id] = lambda: "dummy-user"
        try:
            with (
                patch.object(
                    server,
                    "_load_recent_seed_history",
                    return_value=([], {}),
                ),
                patch.object(
                    server,
                    "generate_problem_set",
                    side_effect=fake_generate_problem_set,
                ),
                patch.object(server, "store_data", return_value=True),
                patch.object(server, "_record_seed_history_entry"),
                patch.object(server, "_save_seed_history"),
            ):
                response = TestClient(server.app).post(
                    "/quests/generate/stream",
                    json={
                        "hash_tags": ["기울기"],
                        "min_difficulty_tier": 1,
                        "max_difficulty_tier": 1,
                        "question_count": 1,
                    },
                )
        finally:
            server.app.dependency_overrides.pop(server._get_user_id, None)

        self.assertEqual(response.status_code, 200)
        self.assertIn('"quest_id": "dummy-route"', response.text)
        self.assertIn("data: [DONE]", response.text)


if __name__ == "__main__":
    unittest.main()
