import tempfile
import unittest
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

import storage.exam_editor_storage as exam_editor_storage
import storage.storage as quest_storage
import server


class ExamEditorProblemSearchTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmpdir = tempfile.TemporaryDirectory()
        self.db_path = str(Path(self._tmpdir.name) / "test.db")
        self._old_exam_db_path = exam_editor_storage.DB_PATH
        self._old_quest_db_path = quest_storage.DB_PATH
        exam_editor_storage.DB_PATH = self.db_path
        quest_storage.DB_PATH = self.db_path
        exam_editor_storage.init_exam_editor_db()
        quest_storage.init_db()

    def tearDown(self) -> None:
        exam_editor_storage.DB_PATH = self._old_exam_db_path
        quest_storage.DB_PATH = self._old_quest_db_path
        self._tmpdir.cleanup()

    def test_search_user_problem_set_matches_answer_content_and_flattens_preview(self) -> None:
        quest_storage.store_data(
            {
                "header": {"quest_id": "q-search-1", "quest_model": []},
                "info": {
                    "main": "수학",
                    "sub": [],
                    "hash_tag": ["#미분"],
                    "flow_rate": 0.5,
                    "difficulty": 3,
                    "main_huddle": "",
                },
                "data": {
                    "quest_title": {
                        "blocks": [
                            {"type": "text", "content": "도함수 부호를 구하시오."},
                        ]
                    },
                    "quest_answer": {
                        "blocks": [
                            {"type": "text", "content": "증가 구간에서 양수이다."},
                        ]
                    },
                    "question_type": "subjective",
                    "codebase_id": 17,
                    "seed": 99,
                },
                "solves": [],
            }
        )
        exam_editor_storage.upsert_user_problem_set(
            "teacher-1",
            [
                {
                    "quest_id": "q-search-1",
                    "codebase_id": 17,
                    "seed": 99,
                    "question_type": "subjective",
                    "hash_tags": ["#미분"],
                }
            ],
        )

        result = exam_editor_storage.search_user_problem_set(
            user_id="teacher-1",
            text="증가 구간",
        )

        self.assertEqual(result["total"], 1)
        self.assertEqual(result["items"][0]["quest_title_text"], "도함수 부호를 구하시오.")
        self.assertEqual(result["items"][0]["quest_answer_text"], "증가 구간에서 양수이다.")

    def test_search_endpoint_returns_only_teacher_document_problem_set(self) -> None:
        quest_storage.store_data(
            {
                "header": {"quest_id": "q-owned", "quest_model": []},
                "info": {
                    "main": "수학",
                    "sub": [],
                    "hash_tag": ["#미분"],
                    "flow_rate": 0.5,
                    "difficulty": 3,
                    "main_huddle": "",
                },
                "data": {
                    "quest_title": {
                        "blocks": [
                            {"type": "text", "content": "도함수 부호를 구하시오."},
                        ]
                    },
                    "quest_answer": {"blocks": []},
                },
                "solves": [],
            }
        )
        quest_storage.store_data(
            {
                "header": {"quest_id": "q-global", "quest_model": []},
                "info": {
                    "main": "수학",
                    "sub": [],
                    "hash_tag": ["#미분"],
                    "flow_rate": 0.5,
                    "difficulty": 3,
                    "main_huddle": "",
                },
                "data": {
                    "quest_title": {
                        "blocks": [
                            {"type": "text", "content": "도함수 전역 문제"},
                        ]
                    },
                    "quest_answer": {"blocks": []},
                },
                "solves": [],
            }
        )
        exam_editor_storage.upsert_user_problem_set(
            "teacher-1",
            [
                {
                    "quest_id": "q-owned",
                    "codebase_id": 17,
                    "seed": 99,
                    "question_type": "subjective",
                    "hash_tags": ["#미분"],
                }
            ],
        )

        response = server.search_exam_editor_problems_handler(
            text="도함수",
            owned_only=False,
            user_id="teacher-1",
        )

        self.assertEqual(response.total, 1)
        self.assertEqual(response.items[0]["quest_id"], "q-owned")
        self.assertFalse(response.source_connected)

    def test_search_endpoint_filters_quest_id_within_teacher_document_problem_set(self) -> None:
        for quest_id in ("q-owned-target", "q-owned-other", "q-global-target"):
            quest_storage.store_data(
                {
                    "header": {"quest_id": quest_id, "quest_model": []},
                    "info": {
                        "main": "수학",
                        "sub": [],
                        "hash_tag": ["#함수"],
                        "flow_rate": 0.5,
                        "difficulty": 3,
                        "main_huddle": "",
                    },
                    "data": {
                        "quest_title": {
                            "blocks": [{"type": "text", "content": quest_id}]
                        },
                        "quest_answer": {"blocks": []},
                    },
                    "solves": [],
                }
            )
        exam_editor_storage.upsert_user_problem_set(
            "teacher-1",
            [
                {
                    "quest_id": "q-owned-target",
                    "codebase_id": 17,
                    "seed": 99,
                    "question_type": "subjective",
                    "hash_tags": ["#함수"],
                },
                {
                    "quest_id": "q-owned-other",
                    "codebase_id": 18,
                    "seed": 100,
                    "question_type": "subjective",
                    "hash_tags": ["#함수"],
                },
            ],
        )

        response = server.search_exam_editor_problems_handler(
            quest_id="target",
            owned_only=False,
            user_id="teacher-1",
        )

        self.assertEqual(response.total, 1)
        self.assertEqual(response.items[0]["quest_id"], "q-owned-target")
        self.assertFalse(response.source_connected)

    def test_global_quests_endpoint_is_owned_only_for_teacher_role(self) -> None:
        for quest_id, title in (
            ("q-owned-teacher", "교사 보유 도함수 문제"),
            ("q-global-teacher", "전역 도함수 문제"),
        ):
            quest_storage.store_data(
                {
                    "header": {"quest_id": quest_id, "quest_model": []},
                    "info": {
                        "main": "수학",
                        "sub": [],
                        "hash_tag": ["#도함수"],
                        "flow_rate": 0.5,
                        "difficulty": 3,
                        "main_huddle": "",
                    },
                    "data": {
                        "quest_title": {
                            "blocks": [{"type": "text", "content": title}]
                        },
                        "quest_answer": {"blocks": []},
                    },
                    "solves": [],
                }
            )
        exam_editor_storage.upsert_user_problem_set(
            "teacher-1",
            [
                {
                    "quest_id": "q-owned-teacher",
                    "codebase_id": 17,
                    "seed": 99,
                    "question_type": "subjective",
                    "hash_tags": ["#도함수"],
                },
            ],
        )
        old_get_user_by_id = server.get_user_by_id
        try:
            server.get_user_by_id = lambda user_id: {"role": "teacher"}
            response = server.search_quests_handler(
                text="도함수",
                auth_payload={"sub": "teacher-1", "role": "teacher"},
            )
        finally:
            server.get_user_by_id = old_get_user_by_id

        self.assertEqual(response.total, 1)
        self.assertEqual(response.quests[0]["quest_id"], "q-owned-teacher")
        self.assertNotIn(
            "q-global-teacher",
            {item["quest_id"] for item in response.quests},
        )


if __name__ == "__main__":
    unittest.main()
