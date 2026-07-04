import os
import gc
import tempfile
import unittest
from datetime import datetime, timedelta
from pathlib import Path

from fastapi import HTTPException

from app.api.routes.academy import router as academy_router
from domain.academy import repository as academy_repo
from domain.course import v2_repository as course_repo
from domain.course.v2_models import CourseModule, CourseModuleType, CourseV2


class AcademyAssignmentOperationTests(unittest.TestCase):
    def setUp(self) -> None:
        fd, path = tempfile.mkstemp(suffix=".db")
        os.close(fd)
        self._db_file = Path(path)
        self._old_academy_db = academy_repo.DB_PATH
        self._old_course_db = course_repo.DB_PATH
        academy_repo.DB_PATH = str(self._db_file)
        course_repo.DB_PATH = str(self._db_file)

        self.group = academy_repo.create_group(
            academy_id="academy-1",
            name="테스트반",
        )
        academy_repo.add_group_member(
            group_id=self.group["group_id"],
            user_id="teacher-1",
            role="teacher",
            status="active",
        )
        for user_id in ("student-a", "student-b", "student-c"):
            academy_repo.add_group_member(
                group_id=self.group["group_id"],
                user_id=user_id,
                role="student",
                status="active",
            )
        academy_repo.add_group_member(
            group_id=self.group["group_id"],
            user_id="student-removed",
            role="student",
            status="removed",
        )
        course_repo.create_course_v2(
            CourseV2(
                id="course-1",
                owner_user_id="teacher-1",
                title="권장 코스",
                description="desc",
                duration="2주",
                modules=[
                    CourseModule(
                        id="m1",
                        type=CourseModuleType.textbook_view,
                        title="교재",
                    )
                ],
            )
        )

    def tearDown(self) -> None:
        academy_repo.DB_PATH = self._old_academy_db
        course_repo.DB_PATH = self._old_course_db
        try:
            gc.collect()
            self._db_file.unlink()
        except (FileNotFoundError, PermissionError):
            pass

    def test_group_assignment_targets_all_active_members_by_default(self) -> None:
        assignment = academy_repo.create_assignment(
            group_id=self.group["group_id"],
            sender_user_id="teacher-1",
            kind="homework",
            ref_id="doc-1",
            title="숙제",
        )

        submissions = academy_repo.list_submissions(
            assignment_id=assignment["assignment_id"],
        )

        self.assertEqual({s["user_id"] for s in submissions}, {"student-a", "student-b", "student-c"})

    def test_group_assignment_targets_selected_active_members_only(self) -> None:
        assignment = academy_repo.create_assignment(
            group_id=self.group["group_id"],
            sender_user_id="teacher-1",
            kind="homework",
            ref_id="doc-1",
            target_user_ids=["student-a", "student-c", "student-removed"],
        )

        submissions = academy_repo.list_submissions(
            assignment_id=assignment["assignment_id"],
        )

        self.assertEqual({s["user_id"] for s in submissions}, {"student-a", "student-c"})

    def test_course_assignment_enrolls_runtime_state(self) -> None:
        academy_router._enroll_course_v2_for_students("course-1", ["student-a"])

        state = course_repo.get_runtime_state("student-a", "course-1")

        self.assertTrue(state["assigned_by_teacher"])
        self.assertEqual(state["status"], "in_progress")

    def test_course_due_date_rejects_dates_after_duration(self) -> None:
        too_late = (datetime.utcnow().date() + timedelta(days=20)).isoformat()

        with self.assertRaises(HTTPException):
            academy_router._validate_course_due_date("course-1", too_late)

    def test_assignment_update_delete_and_my_list_are_consistent(self) -> None:
        assignment = academy_repo.create_assignment(
            group_id=self.group["group_id"],
            sender_user_id="teacher-1",
            kind="homework",
            ref_id="doc-1",
            due_date="2026-07-10",
            target_user_ids=["student-a"],
        )
        updated = academy_repo.update_assignment(
            assignment["assignment_id"],
            due_date="2026-07-12",
        )
        mine = academy_repo.list_my_assignments("student-a")

        self.assertEqual(updated["due_date"], "2026-07-12")
        self.assertEqual(len(mine), 1)
        self.assertEqual(mine[0]["submission_status"], "pending")

        self.assertTrue(academy_repo.delete_assignment(assignment["assignment_id"]))
        self.assertEqual(academy_repo.list_my_assignments("student-a"), [])

    def test_student_analysis_payload_includes_schedule_and_assignments(self) -> None:
        academy_repo.create_assignment(
            group_id=self.group["group_id"],
            sender_user_id="teacher-1",
            kind="homework",
            ref_id="doc-1",
            due_date="2026-07-10",
            target_user_ids=["student-a"],
        )
        academy_repo.replace_student_schedule_tasks(
            user_id="student-a",
            tasks_by_date={"2026-07-11": ["개인 복습"]},
        )

        data = academy_router._build_student_analysis("student-a")

        self.assertIn("rating", data)
        self.assertEqual(len(data["homework"]), 1)
        self.assertEqual(data["student_schedule"][0]["title"], "개인 복습")


if __name__ == "__main__":
    unittest.main()
