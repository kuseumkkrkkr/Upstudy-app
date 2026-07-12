import unittest
import tempfile
from pathlib import Path

from storage import storage
from storage.storage import _matches_filters


class StorageSearchFilterTests(unittest.TestCase):
    def _quest(self, tags, title):
        return {
            "data": {
                "hash_tag": tags,
                "quest_title": {"blocks": [{"content": title}]},
            },
            "info": {},
        }

    def test_single_tag_matches_any_item_with_that_tag(self) -> None:
        quest = self._quest(["A", "C"], "수열 일반항")
        self.assertTrue(_matches_filters(quest, ["a"], ""))

    def test_multi_tag_requires_all_tags(self) -> None:
        quest_ok = self._quest(["A", "B", "F"], "함수 문제")
        quest_fail = self._quest(["A", "D"], "함수 문제")
        self.assertTrue(_matches_filters(quest_ok, ["a", "b"], ""))
        self.assertFalse(_matches_filters(quest_fail, ["a", "b"], ""))

    def test_title_keyword_partial_match(self) -> None:
        quest = self._quest(["수열"], "등차수열 일반항 구하기")
        self.assertTrue(_matches_filters(quest, [], "일반항"))
        self.assertFalse(_matches_filters(quest, [], "극한"))

    def test_tag_search_prefilters_escaped_korean_tags(self) -> None:
        original_path = storage.DB_PATH
        temp = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
        temp_path = temp.name
        temp.close()
        storage.DB_PATH = temp_path
        try:
            storage.init_db()
            self.assertTrue(
                storage.store_data(
                    {
                        "header": {
                            "quest_id": "q-korean-tag",
                            "quest_model": {"models": []},
                        },
                        "info": {
                            "main": 1,
                            "sub": ["#밑"],
                            "hash_tag": ["#밑"],
                            "flow_rate": 1,
                            "difficulty": 3,
                            "main_huddle": 1,
                        },
                        "data": {
                            "quest_title": "밑 조건을 찾는 문제",
                            "quest_answer": "1",
                        },
                        "solves": [
                            {
                                "flow": "조건을 확인한다.",
                                "hash_tag": ["#밑"],
                                "hint_riddle": "태그 확인",
                                "answer_riddle": "정답 확인",
                                "enter_huddle": 1,
                            }
                        ],
                    }
                )
            )

            result = storage.search_quests(hash_tag="밑", page=1, page_size=10)

            self.assertEqual(result["total"], 1)
            self.assertEqual(result["quests"][0]["header"]["quest_id"], "q-korean-tag")
        finally:
            storage.DB_PATH = original_path
            Path(temp_path).unlink(missing_ok=True)


if __name__ == "__main__":
    unittest.main()
