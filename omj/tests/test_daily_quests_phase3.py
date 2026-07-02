import unittest
import uuid
from importlib import import_module

challenge_router = import_module('app.api.routes.challenge.router')
from domain.course.v2_models import CourseModule, CourseModuleType, CourseV2
from domain.course import v2_repository as course_repo


class DailyQuestPhase3Tests(unittest.TestCase):
    def test_daily_items_count_between_3_and_5(self) -> None:
        types = sorted(challenge_router._ALLOWED_DAILY_TYPES)
        for _ in range(20):
            items = challenge_router._build_daily_items(types, 3, 5, '2026-01-01')
            self.assertGreaterEqual(len(items), 3)
            self.assertLessEqual(len(items), 5)

    def test_daily_quests_filter_out_disallowed_types(self) -> None:
        course_id = f"course_{uuid.uuid4().hex[:8]}"
        user_id = f"user_{uuid.uuid4().hex[:8]}"
        course = CourseV2(
            id=course_id,
            title='Phase3',
            modules=[CourseModule(id='m1', type=CourseModuleType.textbook_view, title='M1')],
            challenge_settings={
                'daily_random_count_min': 3,
                'daily_random_count_max': 5,
                'available_types': ['solve_n_problems', 'not_allowed_type'],
            },
        )
        course_repo.create_course_v2(course)

        data = challenge_router._load_or_create_daily_quests(user_id, course_id)
        items = data.get('items', [])

        self.assertGreaterEqual(len(items), 3)
        self.assertLessEqual(len(items), 5)
        for item in items:
            self.assertIn(item.get('quest_type'), challenge_router._ALLOWED_DAILY_TYPES)


if __name__ == '__main__':
    unittest.main()
