import unittest

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


if __name__ == "__main__":
    unittest.main()
