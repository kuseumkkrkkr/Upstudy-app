import unittest

from domain.quest.search_view import content_to_text, enrich_quest_search_item


class QuestSearchViewTests(unittest.TestCase):
    def test_content_to_text_from_blocks(self) -> None:
        value = {
            'blocks': [
                {'content': '문제 본문'},
                {'content': '$x+1$'},
            ]
        }
        self.assertEqual(content_to_text(value), '문제 본문 $x+1$')

    def test_content_to_text_from_string(self) -> None:
        self.assertEqual(content_to_text('  hello  '), 'hello')

    def test_enrich_search_item_adds_flat_fields(self) -> None:
        quest = {
            'info': {'difficulty': 4, 'hash_tag': ['#함수']},
            'data': {
                'quest_title': {'blocks': [{'content': '제목'}]},
                'seed': 123,
            },
        }
        out = enrich_quest_search_item(quest)
        self.assertEqual(out['quest_title_text'], '제목')
        self.assertEqual(out['hash_tags'], ['#함수'])
        self.assertEqual(out['difficulty_tier'], 4)
        self.assertEqual(out['seed'], 123)


if __name__ == '__main__':
    unittest.main()
