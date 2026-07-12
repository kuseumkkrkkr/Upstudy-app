import gc
import os
import tempfile
import unittest
from pathlib import Path

from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.routes.academy import router as academy_router
from domain.academy import repository as academy_repo
from domain.course import v2_repository as course_repo
from domain.course.v2_models import CourseModule, CourseModuleType, CourseV2
from storage import level_test_analysis_storage as analysis_store
from storage import rating_storage, solve_history, weakness_storage


class LevelTestAnalysisApiTests(unittest.TestCase):
    def setUp(self) -> None:
        fd, path = tempfile.mkstemp(suffix=".db")
        os.close(fd)
        self._db_file = Path(path)
        self._old_academy_db = academy_repo.DB_PATH
        self._old_course_db = course_repo.DB_PATH
        self._old_analysis_db = analysis_store.DB_PATH
        self._old_router_db = academy_router.DB_PATH
        self._old_rating_db = rating_storage.DB_PATH
        self._old_weakness_db = weakness_storage.DB_PATH
        self._old_solve_history_db = solve_history.DB_PATH
        academy_repo.DB_PATH = str(self._db_file)
        course_repo.DB_PATH = str(self._db_file)
        analysis_store.DB_PATH = str(self._db_file)
        academy_router.DB_PATH = str(self._db_file)
        rating_storage.DB_PATH = str(self._db_file)
        weakness_storage.DB_PATH = str(self._db_file)
        solve_history.DB_PATH = str(self._db_file)
        rating_storage.init_rating_db()
        weakness_storage.init_weakness_db()
        solve_history.init_solve_history_db()

        self.group = academy_repo.create_group(academy_id="academy-1", name="반")
        academy_repo.add_group_member(
            group_id=self.group["group_id"],
            user_id="student-1",
            role="student",
            status="active",
        )
        course_repo.create_course_v2(
            CourseV2(
                id="course-level",
                title="레벨테스트 코스",
                owner_user_id="teacher-1",
                access_academy_id="academy-1",
                access_group_id=self.group["group_id"],
                modules=[
                    CourseModule(
                        id="module-level",
                        type=CourseModuleType.level_test,
                        title="레벨 테스트",
                    )
                ],
            )
        )
        self.app = FastAPI()
        self.app.dependency_overrides[academy_router.get_current_user] = lambda: {
            "user_id": "student-1",
            "role": "student",
        }
        self.app.include_router(academy_router.router)
        self.client = TestClient(self.app)

    def tearDown(self) -> None:
        academy_repo.DB_PATH = self._old_academy_db
        course_repo.DB_PATH = self._old_course_db
        analysis_store.DB_PATH = self._old_analysis_db
        academy_router.DB_PATH = self._old_router_db
        rating_storage.DB_PATH = self._old_rating_db
        weakness_storage.DB_PATH = self._old_weakness_db
        solve_history.DB_PATH = self._old_solve_history_db
        try:
            gc.collect()
            self._db_file.unlink()
        except (FileNotFoundError, PermissionError):
            pass

    def test_submit_level_test_analysis_is_saved_and_exposed_in_student_analysis(self) -> None:
        response = self.client.post(
            "/academy/analysis/level-test",
            json={
                "session_id": "lt-test-1",
                "course_id": "course-level",
                "module_id": "module-level",
                "exam_id": "exam-1",
                "exam_title": "진단 시험지",
                "tags": ["함수"],
                "correct_count": 1,
                "total_count": 2,
                "accuracy": 50,
                "passed": False,
                "elapsed_seconds": 120,
                "problem_results": [
                    {
                        "item_index": 1,
                        "quest_id": "q1",
                        "is_correct": True,
                        "tags": ["함수"],
                    },
                    {
                        "item_index": 2,
                        "quest_id": "q2",
                        "is_correct": False,
                        "tags": ["함수"],
                        "wrong_points": [{"flow_number": 2, "status": "X"}],
                    },
                ],
            },
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["data"]["session_id"], "lt-test-1")
        analysis = academy_router._build_student_analysis("student-1")
        summaries = analysis["level_test_analysis"]
        self.assertEqual(len(summaries), 1)
        self.assertEqual(summaries[0]["exam_id"], "exam-1")
        self.assertEqual(summaries[0]["incorrect_count"], 1)
        self.assertEqual(summaries[0]["weak_tags"][0]["tag"], "함수")


if __name__ == "__main__":
    unittest.main()
