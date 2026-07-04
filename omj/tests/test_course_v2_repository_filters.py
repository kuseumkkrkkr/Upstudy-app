import os
import tempfile
import unittest
from pathlib import Path

from domain.course.v2_models import CourseModule, CourseModuleType, CourseV2
from domain.course import v2_repository as repo


class CourseV2RepositoryFilterTests(unittest.TestCase):
    def setUp(self) -> None:
        fd, path = tempfile.mkstemp(suffix='.db')
        os.close(fd)
        self._db_file = Path(path)
        self._old_db_path = repo.DB_PATH
        repo.DB_PATH = str(self._db_file)

        repo.create_course_v2(
            CourseV2(
                id='course-a',
                title='미분 코스',
                description='도함수 중심',
                tags=['미분', '함수'],
                focus_tags=['미분'],
                target_ovr=1200,
                owner_user_id='teacher-a',
                is_public=True,
                modules=[
                    CourseModule(
                        id='m1',
                        type=CourseModuleType.textbook_view,
                        title='교재',
                    )
                ],
            )
        )
        repo.create_course_v2(
            CourseV2(
                id='course-b',
                title='적분 코스',
                description='넓이와 정적분',
                tags=['적분'],
                focus_tags=['정적분'],
                target_ovr=1100,
                owner_user_id='teacher-b',
                is_public=False,
                modules=[
                    CourseModule(
                        id='m2',
                        type=CourseModuleType.problem_solve,
                        title='문제',
                    )
                ],
            )
        )

    def tearDown(self) -> None:
        repo.DB_PATH = self._old_db_path

    def test_filters_and_pagination_are_applied_in_sql(self) -> None:
        self.assertEqual(repo.count_courses_v2(), 2)
        self.assertEqual(repo.count_courses_v2(query='미분'), 1)
        self.assertEqual(repo.count_courses_v2(tag='적분'), 1)
        self.assertEqual(repo.count_courses_v2(owner_user_id='teacher-a'), 1)
        self.assertEqual(repo.count_courses_v2(is_public=True), 1)

        courses = repo.list_courses_v2(limit=1, offset=0, sort='updated_at', order='desc')
        self.assertEqual(len(courses), 1)
        self.assertEqual(courses[0].id, 'course-b')

        courses = repo.list_courses_v2(limit=1, offset=1, sort='updated_at', order='desc')
        self.assertEqual(len(courses), 1)
        self.assertEqual(courses[0].id, 'course-a')


if __name__ == '__main__':
    unittest.main()
