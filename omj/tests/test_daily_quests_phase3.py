import unittest
import uuid
from importlib import import_module

challenge_router = import_module('app.api.routes.challenge.router')
challenge_service = import_module('app.api.routes.challenge.service')
from domain.challenge import repository as challenge_repo
from domain.course.v2_models import CourseModule, CourseModuleType, CourseV2
from domain.course import v2_repository as course_repo
from storage.student_account_store import get_account_summary


class DailyQuestPhase3Tests(unittest.TestCase):
    def test_default_daily_challenge_templates_have_60_items(self) -> None:
        templates = challenge_repo.list_daily_challenge_templates(enabled=True)
        difficulties = [template['difficulty'] for template in templates]

        self.assertEqual(len(templates), 60)
        self.assertEqual(difficulties.count('easy'), 20)
        self.assertEqual(difficulties.count('medium'), 20)
        self.assertEqual(difficulties.count('hard'), 20)

    def test_daily_items_count_is_fixed_to_5(self) -> None:
        types = sorted(challenge_router._ALLOWED_DAILY_TYPES)
        for _ in range(20):
            items = challenge_router._build_daily_items(types, 3, 5, '2026-01-01')
            self.assertEqual(len(items), 5)

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

        self.assertEqual(len(items), 5)
        for item in items:
            self.assertIn(item.get('quest_type'), challenge_router._ALLOWED_DAILY_TYPES)

    def test_daily_quests_follow_difficulty_quota_and_points(self) -> None:
        course_id = f"course_{uuid.uuid4().hex[:8]}"
        user_id = f"user_{uuid.uuid4().hex[:8]}"
        course = CourseV2(
            id=course_id,
            title='Quota',
            modules=[
                CourseModule(id='m1', type=CourseModuleType.textbook_view, title='M1'),
                CourseModule(id='m2', type=CourseModuleType.problem_solve, title='M2'),
                CourseModule(id='m3', type=CourseModuleType.exam_solve, title='M3'),
            ],
        )
        course_repo.create_course_v2(course)

        data = challenge_router._load_or_create_daily_quests(user_id, course_id)
        items = data.get('items', [])
        difficulties = [item.get('difficulty') for item in items]

        self.assertEqual(len(items), 5)
        self.assertEqual(difficulties.count('easy'), 2)
        self.assertEqual(difficulties.count('medium'), 2)
        self.assertEqual(difficulties.count('hard'), 1)
        self.assertEqual(sum(int(item.get('reward_points') or 0) for item in items), 100)

    def test_daily_quest_direct_complete_does_not_award_points(self) -> None:
        course_id = f"course_{uuid.uuid4().hex[:8]}"
        user_id = f"user_{uuid.uuid4().hex[:8]}"
        course = CourseV2(
            id=course_id,
            title='NoDirectReward',
            modules=[CourseModule(id='m1', type=CourseModuleType.textbook_view, title='M1')],
            challenge_settings={
                'daily_random_count_min': 3,
                'daily_random_count_max': 3,
                'available_types': ['solve_n_problems'],
            },
        )
        course_repo.create_course_v2(course)

        data = challenge_router._load_or_create_daily_quests(user_id, course_id)
        first = data['items'][0]

        result = challenge_service.complete_daily_quest(
            user_id,
            {'course_id': course_id, 'quest_id': first['id']},
        )

        self.assertEqual(result['account']['total_points'], 0)
        self.assertEqual(result['items'][0].get('claim_status'), 'verification_required')

    def test_daily_quest_rewards_are_capped_at_100_points_per_day(self) -> None:
        course_id = f"course_{uuid.uuid4().hex[:8]}"
        user_id = f"user_{uuid.uuid4().hex[:8]}"
        course = CourseV2(
            id=course_id,
            title='RewardCap',
            modules=[CourseModule(id='m1', type=CourseModuleType.textbook_view, title='M1')],
            challenge_settings={
                'daily_random_count_min': 5,
                'daily_random_count_max': 5,
                'available_types': ['solve_n_problems'],
            },
        )
        course_repo.create_course_v2(course)

        data, updated = challenge_service.apply_daily_quest_event(
            user_id,
            {'course_id': course_id, 'event_type': 'solve_n_problems', 'value': 20},
        )

        self.assertTrue(updated)
        self.assertEqual(len(data['items']), 5)
        for item in data['items']:
            self.assertEqual(item['status'], 'completed')
            challenge_service.complete_daily_quest(
                user_id,
                {'course_id': course_id, 'quest_id': item['id']},
            )

        summary = get_account_summary(user_id)
        self.assertEqual(summary['daily_points'], 100)
        self.assertEqual(summary['total_points'], 100)
        self.assertEqual(summary['daily_points_remaining'], 0)


if __name__ == '__main__':
    unittest.main()
