import unittest
import json
from pathlib import Path
import sys
import tempfile
from unittest.mock import patch

from fastapi.testclient import TestClient

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

import server
from generater import problem_solve
from storage import storage as quest_storage
import user_habit


class ProblemSolveSingleCountTests(unittest.TestCase):
    def test_generate_problem_set_accepts_single_question(self) -> None:
        def fake_generate_codebase(tags, tier, rng):
            return {"id": 1, "code": "", "tags": tags, "tier": tier}

        def fake_build_quest(entry, tags, params, seed, question_type, raw_result=None):
            return {
                "header": {"quest_id": f"dummy-{seed}"},
                "info": {"difficulty_tier": entry["tier"], "hash_tag": tags},
                "data": {
                    "quest_title": "직선 y=x+1의 y절편을 구하시오.",
                    "quest_answer": "1",
                },
                "solves": [
                    {
                        "flow": f"x=0을 대입하는 풀이 단계 {index + 1}입니다.",
                        "hint_riddle": "y절편에서는 x=0입니다.",
                        "answer_riddle": "y=1이므로 y절편은 1입니다.",
                    }
                    for index in range(params.solves_count)
                ],
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
                patch.object(server, "claim_cached_quests", return_value=([], {"queued": 0, "cached": 0, "match_stage": 0})),
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


class CachedQuestSelectionTests(unittest.TestCase):
    """필요 변수: 임시 quest DB. 작동 원리: 캐시 선택이 사용자별 codebase+seed 이력을 정확히 제외하는지 검증한다."""

    def setUp(self) -> None:
        """필요 변수: 임시 DB 경로. 작동 원리: 운영 문제 DB를 건드리지 않는 독립 캐시 선택 환경을 만든다."""
        self._temp_dir = tempfile.TemporaryDirectory()
        self._db_path = str(Path(self._temp_dir.name) / "quests.db")
        self._old_storage_path = quest_storage.DB_PATH
        self._old_habit_path = user_habit.DB_PATH
        quest_storage.DB_PATH = self._db_path
        user_habit.DB_PATH = self._db_path
        quest_storage.init_db()
        user_habit.init_habit_db()
        self._insert_cached_quest("exact-solved", 7, 101, ["#비례", "#기울기"])
        self._insert_cached_quest("exact-fresh", 7, 102, ["#비례", "#기울기"])
        self._insert_cached_quest("partial-fresh", 8, 201, ["#비례"])

    def tearDown(self) -> None:
        """필요 변수: 기존 DB 경로. 작동 원리: 테스트가 끝나면 전역 경로를 원상복구하고 임시 파일을 삭제한다."""
        quest_storage.DB_PATH = self._old_storage_path
        user_habit.DB_PATH = self._old_habit_path
        self._temp_dir.cleanup()

    def _insert_cached_quest(self, quest_id: str, codebase_id: int, seed: int, tags: list[str]) -> None:
        """필요 변수: ID·codebase·seed·태그. 작동 원리: 캐시 후보 검색에 필요한 최소 행과 태그 역색인을 삽입한다."""
        conn = quest_storage._connect()
        try:
            conn.execute("INSERT INTO quest_header (quest_id, quest_model) VALUES (?, '[]')", (quest_id,))
            conn.execute(
                """INSERT INTO quest_info
                (quest_id, main, sub, hash_tag, flow_rate, difficulty, main_huddle,
                 difficulty_tier, difficulty_score, tier_source, quality_status,
                 quality_reasons, quality_checked_at)
                VALUES (?, 0, '[]', ?, 1, 3, 1, 3, 3, 'test', 'approved', '[]', 0)""",
                (quest_id, json.dumps(tags, ensure_ascii=False)),
            )
            conn.execute(
                """INSERT INTO quest_data
                (quest_id, quest_title, codebase_id, seed, hash_tag)
                VALUES (?, '{}', ?, ?, ?)""",
                (quest_id, codebase_id, seed, json.dumps(tags, ensure_ascii=False)),
            )
            for tag in tags:
                conn.execute(
                    "INSERT INTO quest_tag_index (quest_id, tag) VALUES (?, ?)",
                    (quest_id, tag.lstrip("#").lower()),
                )
            conn.commit()
        finally:
            conn.close()

    def test_same_codebase_different_seed_is_reusable(self) -> None:
        """필요 변수: 최근 풀이 seed. 작동 원리: 같은 codebase라도 seed가 다르면 캐시 문제를 재사용할 수 있어야 한다."""
        user_habit.record_problem_attempt(
            user_id="student-1",
            codebase_id=7,
            seed="101",
            tags_json="[]",
            quest_title="solved",
        )
        with patch.object(
            quest_storage,
            "get_quests_by_ids",
            side_effect=lambda quest_ids: [{"id": quest_id} for quest_id in quest_ids],
        ):
            quests, state = quest_storage.claim_cached_quests(
                user_id="student-1",
                hash_tags=["#비례", "#기울기"],
                min_difficulty_tier=3,
                max_difficulty_tier=3,
                question_count=1,
                prefetch_count=0,
            )
        self.assertEqual(quests, [{"id": "exact-fresh"}])
        self.assertEqual(state["match_stage"], 2)

    def test_tag_matching_expands_after_exact_cache_is_served(self) -> None:
        """필요 변수: 같은 조건의 두 요청. 작동 원리: 100% 태그 캐시를 먼저 쓰고 다음 요청에서 1개 일치 캐시로 확장한다."""
        with patch.object(
            quest_storage,
            "get_quests_by_ids",
            side_effect=lambda quest_ids: [{"id": quest_id} for quest_id in quest_ids],
        ):
            first, _ = quest_storage.claim_cached_quests(
                user_id="student-2",
                hash_tags=["#비례", "#기울기"],
                min_difficulty_tier=3,
                max_difficulty_tier=3,
                question_count=2,
                prefetch_count=0,
            )
            second, state = quest_storage.claim_cached_quests(
                user_id="student-2",
                hash_tags=["#비례", "#기울기"],
                min_difficulty_tier=3,
                max_difficulty_tier=3,
                question_count=1,
                prefetch_count=0,
            )
        self.assertEqual([quest["id"] for quest in first], ["exact-fresh", "exact-solved"])
        self.assertEqual(second, [{"id": "partial-fresh"}])
        self.assertEqual(state["match_stage"], 1)

    def test_bulk_cached_quest_load_preserves_request_order(self) -> None:
        """필요 변수: 캐시 문제 ID 목록. 작동 원리: 여러 문제를 한 번의 묶음 조회로 읽어도 호출 순서가 유지되어야 한다."""
        quests = quest_storage.get_quests_by_ids(["partial-fresh", "exact-fresh"])
        self.assertEqual(
            [quest["header"]["quest_id"] for quest in quests],
            ["partial-fresh", "exact-fresh"],
        )


if __name__ == "__main__":
    unittest.main()
