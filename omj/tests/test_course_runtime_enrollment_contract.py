import os
import gc
import tempfile
import time
import unittest
import asyncio
from importlib import import_module
from pathlib import Path

from app.api.routes.courses import service as course_service
from domain.course import v2_repository as course_repo
from domain.course.v2_models import CourseModule, CourseModuleType, CourseV2
from storage import course_storage

runtime_router = import_module("app.api.routes.courses.runtime_router")


class _RequestState:
    role = "student"
    user_id = "student-1"


class _DummyRequest:
    state = _RequestState()


class _TeacherRequestState:
    role = "teacher"
    user_id = "teacher-1"


class _TeacherRequest:
    state = _TeacherRequestState()


class CourseRuntimeEnrollmentContractTests(unittest.TestCase):
    def setUp(self) -> None:
        fd, path = tempfile.mkstemp(suffix=".db")
        os.close(fd)
        self._db_file = Path(path)
        self._old_v2_db = course_repo.DB_PATH
        self._old_legacy_db = course_storage.DB_PATH
        course_repo.DB_PATH = str(self._db_file)
        course_storage.DB_PATH = str(self._db_file)

    def tearDown(self) -> None:
        course_repo.DB_PATH = self._old_v2_db
        course_storage.DB_PATH = self._old_legacy_db
        gc.collect()
        for _ in range(5):
            try:
                self._db_file.unlink()
                break
            except FileNotFoundError:
                break
            except PermissionError:
                time.sleep(0.1)

    def test_v2_payload_includes_current_student_runtime_progress(self) -> None:
        course_repo.create_course_v2(
            CourseV2(
                id="course-v2",
                owner_user_id="teacher-1",
                title="런타임 코스",
                description="desc",
                difficulty="중",
                duration="2일",
                is_public=True,
                modules=[
                    CourseModule(
                        id="m1",
                        type=CourseModuleType.problem_solve,
                        title="1강",
                    ),
                    CourseModule(
                        id="m2",
                        type=CourseModuleType.problem_solve,
                        title="2강",
                    ),
                ],
            )
        )
        course_repo.upsert_runtime_state(
            "student-1",
            "course-v2",
            {"completed_modules": ["m1"], "module_results": {}},
        )

        course = course_service.get_course_v2(
            "course-v2",
            {"user_id": "student-1", "role": "student"},
        )
        payload = course_service.course_v2_payload(
            course,
            {"user_id": "student-1", "role": "student"},
        )

        self.assertEqual(payload["percent"], 0.5)
        self.assertEqual(payload["status"], "in_progress")
        self.assertEqual(payload["completed_modules"], ["m1"])

    def test_legacy_enroll_rejects_unknown_course_id(self) -> None:
        with self.assertRaisesRegex(ValueError, "course_not_found"):
            course_storage.enroll_course("student-1", "missing-v2-id")

    def test_perfect_score_auto_completes_empty_wrong_answer_review(self) -> None:
        course_repo.create_course_v2(
            CourseV2(
                id="course-review",
                owner_user_id="teacher-1",
                title="복습 코스",
                description="desc",
                difficulty="중",
                duration="1일",
                is_public=True,
                modules=[
                    CourseModule(
                        id="m1",
                        type=CourseModuleType.problem_solve,
                        title="1강",
                        pass_rate=80,
                    ),
                    CourseModule(
                        id="m1_wa_1",
                        type=CourseModuleType.wrong_answer_review,
                        title="오답 복습",
                    ),
                ],
            )
        )

        response = asyncio.run(
            runtime_router.runtime_submit(
                _DummyRequest(),
                {
                    "course_id": "course-review",
                    "module_id": "m1",
                    "correct_count": 3,
                    "total_count": 3,
                    "elapsed_seconds": 30,
                },
                _user={"user_id": "student-1", "role": "student"},
            )
        )

        completed = response.data["student_state"]["completed_modules"]
        self.assertEqual(completed, ["m1", "m1_wa_1"])
        state = course_repo.get_runtime_state("student-1", "course-review")
        self.assertTrue(state["module_results"]["m1_wa_1"]["auto_completed"])

    def test_public_course_owner_can_view_existing_student_runtime(self) -> None:
        course_repo.create_course_v2(
            CourseV2(
                id="course-public",
                owner_user_id="teacher-1",
                title="공개 코스",
                description="desc",
                difficulty="중",
                duration="1일",
                is_public=True,
                modules=[
                    CourseModule(
                        id="m1",
                        type=CourseModuleType.problem_solve,
                        title="1강",
                    ),
                ],
            )
        )
        course_repo.upsert_runtime_state(
            "student-1",
            "course-public",
            {"completed_modules": ["m1"], "module_results": {}},
        )

        response = asyncio.run(
            runtime_router.runtime_state(
                _TeacherRequest(),
                "course-public",
                user_id="student-1",
                _user={"user_id": "teacher-1", "role": "teacher"},
            )
        )

        self.assertEqual(response.data["status"], "completed")
        self.assertEqual(response.data["completed_modules"], ["m1"])


if __name__ == "__main__":
    unittest.main()
