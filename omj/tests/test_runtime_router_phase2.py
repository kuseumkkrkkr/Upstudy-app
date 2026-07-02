import unittest
from importlib import import_module

rr = import_module('app.api.routes.courses.runtime_router')
from domain.course.v2_models import CourseModule, CourseModuleType, CourseV2


def _course(enabled: bool = True, max_dev: int = 1, daily_max: int = 2) -> CourseV2:
    modules = [
        CourseModule(id='m1', type=CourseModuleType.textbook_view, title='M1', position=0),
        CourseModule(id='m2', type=CourseModuleType.problem_solve, title='M2', position=1),
        CourseModule(id='m3', type=CourseModuleType.exam_solve, title='M3', position=2),
    ]
    return CourseV2(
        id='c1',
        title='Course',
        modules=modules,
        curriculum_settings={
            'enabled': enabled,
            'every_n_days': 0,
            'module_deadline_days': [0, 1, 2],
            'max_deadline_deviation': max_dev,
            'daily_max_modules': daily_max,
        },
    )


class RuntimeRouterPhase2Tests(unittest.TestCase):
    def test_pause_when_deviation_reaches_limit(self) -> None:
        course = _course(enabled=True, max_dev=1)
        state = {
            'started_day': rr._today_ordinal() - 5,
            'module_deadline_days': [0, 1, 2],
            'deviation_count': 0,
            'paused': False,
            'pause_reason': '',
        }

        updated = rr._enforce_deadline_and_pause(course, 'm1', state)

        self.assertEqual(updated['deviation_count'], 1)
        self.assertTrue(updated['paused'])
        self.assertIn('+3일', updated['pause_reason'])

    def test_resume_extends_all_deadlines_by_plus3(self) -> None:
        course = _course(enabled=True)
        state = {
            'paused': True,
            'pause_reason': 'paused',
            'module_deadline_days': [0, 2, 4],
        }

        resumed_state, resumed = rr._maybe_resume_with_extension(course, state, resume=True)

        self.assertTrue(resumed)
        self.assertFalse(resumed_state['paused'])
        self.assertEqual(resumed_state['pause_reason'], '')
        self.assertEqual(resumed_state['module_deadline_days'], [3, 5, 7])

    def test_daily_limit_lock_when_count_reaches_setting(self) -> None:
        course = _course(enabled=True, daily_max=2)
        state = {
            'daily_completed': {
                rr._today_iso(): 2,
            }
        }

        self.assertTrue(rr._is_daily_limit_reached(course, state))

    def test_curriculum_disabled_means_no_limits(self) -> None:
        course = _course(enabled=False, max_dev=1, daily_max=1)
        state = {
            'started_day': rr._today_ordinal() - 10,
            'module_deadline_days': [0, 1, 2],
            'deviation_count': 0,
            'paused': False,
            'pause_reason': '',
            'daily_completed': {rr._today_iso(): 99},
        }

        updated = rr._enforce_deadline_and_pause(course, 'm1', dict(state))

        self.assertEqual(updated['deviation_count'], 0)
        self.assertFalse(updated['paused'])
        self.assertFalse(rr._is_daily_limit_reached(course, state))
        self.assertEqual(rr._build_schedule(course, state), [])


if __name__ == '__main__':
    unittest.main()
