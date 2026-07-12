import os
import gc
import tempfile
import unittest
import asyncio
from importlib import import_module
from datetime import datetime, timedelta
from pathlib import Path

from fastapi import HTTPException

from app.api.routes.academy import router as academy_router
from app.api.routes.courses import service as course_service
from domain.academy import repository as academy_repo
from domain.course import v2_repository as course_repo
from domain.course.v2_models import CourseModule, CourseModuleType, CourseV2

runtime_router = import_module("app.api.routes.courses.runtime_router")


class _RequestState:
    role = "student"
    user_id = "student-a"


class _DummyRequest:
    state = _RequestState()


class _TeacherRequestState:
    role = "teacher"
    user_id = "teacher-1"


class _TeacherRequest:
    state = _TeacherRequestState()


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
        course_repo.create_course_v2(
            CourseV2(
                id="course-public",
                owner_user_id="teacher-1",
                title="공개 코스",
                description="public",
                duration="2주",
                is_public=True,
                modules=[
                    CourseModule(
                        id="m1",
                        type=CourseModuleType.problem_solve,
                        title="문제",
                        pass_rate=0,
                    )
                ],
            )
        )
        course_repo.create_course_v2(
            CourseV2(
                id="course-bound",
                owner_user_id="teacher-1",
                title="그룹 배포 코스",
                description="bound",
                duration="2주",
                access_academy_id="academy-1",
                access_group_id=self.group["group_id"],
                modules=[
                    CourseModule(
                        id="m1",
                        type=CourseModuleType.problem_solve,
                        title="문제",
                        pass_rate=0,
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

    def _create_other_group(self) -> dict:
        group = academy_repo.create_group(
            academy_id="academy-2",
            name="다른반",
        )
        academy_repo.add_group_member(
            group_id=group["group_id"],
            user_id="teacher-2",
            role="teacher",
            status="active",
        )
        academy_repo.add_group_member(
            group_id=group["group_id"],
            user_id="student-x",
            role="student",
            status="active",
        )
        return group

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

    def test_only_academy_manager_can_update_academy(self) -> None:
        academy = academy_repo.create_academy(
            name="관리 학원",
            admin_user_id="teacher-1",
        )

        with self.assertRaises(HTTPException):
            academy_router.update_academy(
                academy["academy_id"],
                academy_router.AcademyUpdate(name="침범"),
                user={"user_id": "teacher-2", "role": "teacher"},
            )

        response = academy_router.update_academy(
            academy["academy_id"],
            academy_router.AcademyUpdate(name="수정"),
            user={"user_id": "teacher-1", "role": "teacher"},
        )

        self.assertEqual(response.data["name"], "수정")

    def test_course_assignment_enrolls_runtime_state(self) -> None:
        academy_router._enroll_course_v2_for_students("course-1", ["student-a"])

        state = course_repo.get_runtime_state("student-a", "course-1")

        self.assertTrue(state["assigned_by_teacher"])
        self.assertEqual(state["status"], "in_progress")

    def test_course_assignment_scope_allows_public_owner_group_teacher(self) -> None:
        academy_router._validate_course_assignment_scope(
            course_id="course-public",
            group_id=self.group["group_id"],
            user={"user_id": "teacher-1", "role": "teacher"},
        )

    def test_course_assignment_scope_rejects_teacher_outside_group(self) -> None:
        with self.assertRaises(HTTPException):
            academy_router._validate_course_assignment_scope(
                course_id="course-public",
                group_id=self.group["group_id"],
                user={"user_id": "teacher-outside", "role": "teacher"},
            )

    def test_create_assignment_rejects_teacher_outside_group(self) -> None:
        with self.assertRaises(HTTPException):
            academy_router.create_assignment(
                academy_router.AssignmentCreate(
                    group_id=self.group["group_id"],
                    kind="homework",
                    ref_id="doc-1",
                ),
                user={"user_id": "teacher-outside", "role": "teacher"},
            )

        self.assertEqual(academy_repo.list_assignments(group_id=self.group["group_id"]), [])

    def test_student_cannot_use_global_assignment_list(self) -> None:
        with self.assertRaises(HTTPException):
            academy_router.list_assignments(user={"user_id": "student-a", "role": "student"})

    def test_teacher_assignment_list_is_limited_to_managed_groups(self) -> None:
        other_group = self._create_other_group()
        own_assignment = academy_repo.create_assignment(
            group_id=self.group["group_id"],
            sender_user_id="teacher-1",
            kind="homework",
            ref_id="doc-1",
            target_user_ids=["student-a"],
        )
        academy_repo.create_assignment(
            group_id=other_group["group_id"],
            sender_user_id="teacher-2",
            kind="homework",
            ref_id="doc-2",
            target_user_ids=["student-x"],
        )

        response = academy_router.list_assignments(
            user={"user_id": "teacher-1", "role": "teacher"},
        )

        self.assertEqual(
            [item["assignment_id"] for item in response.data["items"]],
            [own_assignment["assignment_id"]],
        )

    def test_teacher_cannot_update_or_delete_other_group_assignment(self) -> None:
        other_group = self._create_other_group()
        assignment = academy_repo.create_assignment(
            group_id=other_group["group_id"],
            sender_user_id="teacher-2",
            kind="homework",
            ref_id="doc-2",
            target_user_ids=["student-x"],
        )

        with self.assertRaises(HTTPException):
            academy_router.update_assignment(
                assignment["assignment_id"],
                academy_router.AssignmentUpdate(due_date="2026-07-12"),
                user={"user_id": "teacher-1", "role": "teacher"},
            )
        with self.assertRaises(HTTPException):
            academy_router.delete_assignment(
                assignment["assignment_id"],
                user={"user_id": "teacher-1", "role": "teacher"},
            )

        self.assertIsNotNone(academy_repo.get_assignment(assignment["assignment_id"]))

    def test_group_member_and_management_routes_are_group_scoped(self) -> None:
        other_group = self._create_other_group()
        other_member = academy_repo.list_group_members(
            group_id=other_group["group_id"],
            user_id="student-x",
        )[0]

        own_members = academy_router.list_group_members(
            self.group["group_id"],
            user={"user_id": "student-a", "role": "student"},
        )

        self.assertTrue(own_members.data["items"])
        with self.assertRaises(HTTPException):
            academy_router.list_group_members(
                other_group["group_id"],
                user={"user_id": "student-a", "role": "student"},
            )
        with self.assertRaises(HTTPException):
            academy_router.update_group(
                other_group["group_id"],
                academy_router.GroupUpdate(name="침범"),
                user={"user_id": "teacher-1", "role": "teacher"},
            )
        with self.assertRaises(HTTPException):
            academy_router.remove_group_member(
                other_member["member_id"],
                user={"user_id": "teacher-1", "role": "teacher"},
            )

    def test_attendance_routes_are_group_and_user_scoped(self) -> None:
        other_group = self._create_other_group()
        own_log = academy_repo.record_attendance(
            group_id=self.group["group_id"],
            user_id="student-a",
            date="2026-07-10",
            status="present",
            checked_by_user_id="teacher-1",
        )
        other_log = academy_repo.record_attendance(
            group_id=other_group["group_id"],
            user_id="student-x",
            date="2026-07-10",
            status="absent",
            checked_by_user_id="teacher-2",
        )

        teacher_response = academy_router.list_attendance(
            user={"user_id": "teacher-1", "role": "teacher"},
        )
        student_response = academy_router.list_attendance(
            user={"user_id": "student-a", "role": "student"},
        )

        self.assertEqual({item["log_id"] for item in teacher_response.data["items"]}, {own_log["log_id"]})
        self.assertEqual({item["log_id"] for item in student_response.data["items"]}, {own_log["log_id"]})
        with self.assertRaises(HTTPException):
            academy_router.record_attendance(
                academy_router.AttendanceCreate(
                    group_id=other_group["group_id"],
                    user_id="student-x",
                    date="2026-07-11",
                    status="present",
                ),
                user={"user_id": "teacher-1", "role": "teacher"},
            )
        with self.assertRaises(HTTPException):
            academy_router.update_attendance(
                other_log["log_id"],
                academy_router.AttendanceUpdate(status="present"),
                user={"user_id": "teacher-1", "role": "teacher"},
            )
        with self.assertRaises(HTTPException):
            academy_router.list_attendance(
                user_id="student-x",
                user={"user_id": "student-a", "role": "student"},
            )

    def test_tuition_routes_are_academy_and_user_scoped(self) -> None:
        self._create_other_group()
        own_payment = academy_repo.create_tuition_payment(
            academy_id="academy-1",
            user_id="student-a",
            amount=100,
            month_label="2026-07",
        )
        other_payment = academy_repo.create_tuition_payment(
            academy_id="academy-2",
            user_id="student-x",
            amount=200,
            month_label="2026-07",
        )

        teacher_response = academy_router.list_tuition_payments(
            user={"user_id": "teacher-1", "role": "teacher"},
        )
        student_response = academy_router.list_tuition_payments(
            user={"user_id": "student-a", "role": "student"},
        )

        self.assertEqual({item["payment_id"] for item in teacher_response.data["items"]}, {own_payment["payment_id"]})
        self.assertEqual({item["payment_id"] for item in student_response.data["items"]}, {own_payment["payment_id"]})
        with self.assertRaises(HTTPException):
            academy_router.create_tuition_payment(
                academy_router.TuitionCreate(
                    academy_id="academy-2",
                    user_id="student-x",
                    amount=300,
                    month_label="2026-07",
                ),
                user={"user_id": "teacher-1", "role": "teacher"},
            )
        with self.assertRaises(HTTPException):
            academy_router.update_tuition_payment(
                other_payment["payment_id"],
                academy_router.TuitionUpdate(amount=250),
                user={"user_id": "teacher-1", "role": "teacher"},
            )
        with self.assertRaises(HTTPException):
            academy_router.list_tuition_payments(
                user_id="student-x",
                user={"user_id": "student-a", "role": "student"},
            )

    def test_ledger_routes_are_academy_scoped(self) -> None:
        self._create_other_group()
        own_entry = academy_repo.create_ledger_entry(
            academy_id="academy-1",
            category="income",
            amount=100,
            transaction_date="2026-07-10",
            recorded_by_user_id="teacher-1",
        )
        other_entry = academy_repo.create_ledger_entry(
            academy_id="academy-2",
            category="income",
            amount=200,
            transaction_date="2026-07-10",
            recorded_by_user_id="teacher-2",
        )

        response = academy_router.list_ledger_entries(
            user={"user_id": "teacher-1", "role": "teacher"},
        )

        self.assertEqual({item["ledger_id"] for item in response.data["items"]}, {own_entry["ledger_id"]})
        with self.assertRaises(HTTPException):
            academy_router.list_ledger_entries(user={"user_id": "student-a", "role": "student"})
        with self.assertRaises(HTTPException):
            academy_router.update_ledger_entry(
                other_entry["ledger_id"],
                academy_router.LedgerUpdate(amount=250),
                user={"user_id": "teacher-1", "role": "teacher"},
            )

    def test_consult_routes_are_academy_scoped(self) -> None:
        self._create_other_group()
        own_note = academy_repo.create_consult_note(
            academy_id="academy-1",
            student_user_id="student-a",
            topic="상담",
            consulted_by_user_id="teacher-1",
        )
        other_note = academy_repo.create_consult_note(
            academy_id="academy-2",
            student_user_id="student-x",
            topic="다른 상담",
            consulted_by_user_id="teacher-2",
        )

        response = academy_router.list_consult_notes(
            user={"user_id": "teacher-1", "role": "teacher"},
        )

        self.assertEqual({item["note_id"] for item in response.data["items"]}, {own_note["note_id"]})
        with self.assertRaises(HTTPException):
            academy_router.list_consult_notes(user={"user_id": "student-a", "role": "student"})
        with self.assertRaises(HTTPException):
            academy_router.update_consult_note(
                other_note["note_id"],
                academy_router.ConsultUpdate(topic="침범"),
                user={"user_id": "teacher-1", "role": "teacher"},
            )
        with self.assertRaises(HTTPException):
            academy_router.create_consult_note(
                academy_router.ConsultCreate(
                    academy_id="academy-1",
                    student_user_id="student-x",
                    topic="외부 학생",
                ),
                user={"user_id": "teacher-1", "role": "teacher"},
            )

    def test_timetable_routes_are_group_scoped(self) -> None:
        other_group = self._create_other_group()
        preference = academy_repo.create_timetable_preference(
            group_id=self.group["group_id"],
            user_id="student-a",
            day_of_week="mon",
            time_slot="18:00-19:00",
            priority=3,
        )
        other_plan = academy_repo.create_timetable_plan(
            group_id=other_group["group_id"],
            plan_json="{}",
        )

        own_preferences = academy_router.list_timetable_preferences(
            group_id=self.group["group_id"],
            user={"user_id": "student-a", "role": "student"},
        )

        self.assertEqual(own_preferences.data["items"][0]["preference_id"], preference["preference_id"])
        with self.assertRaises(HTTPException):
            academy_router.list_timetable_preferences(
                group_id=other_group["group_id"],
                user={"user_id": "student-a", "role": "student"},
            )
        with self.assertRaises(HTTPException):
            academy_router.delete_timetable_preference(
                preference["preference_id"],
                user={"user_id": "student-b", "role": "student"},
            )
        with self.assertRaises(HTTPException):
            academy_router.apply_timetable_plan(
                other_plan["plan_id"],
                user={"user_id": "teacher-1", "role": "teacher"},
            )

    def test_course_assignment_scope_rejects_unbound_private_course(self) -> None:
        with self.assertRaises(HTTPException):
            academy_router._validate_course_assignment_scope(
                course_id="course-1",
                group_id=self.group["group_id"],
                user={"user_id": "teacher-1", "role": "teacher"},
            )

    def test_course_assignment_scope_allows_private_course_bound_to_group(self) -> None:
        academy_router._validate_course_assignment_scope(
            course_id="course-bound",
            group_id=self.group["group_id"],
            user={"user_id": "teacher-1", "role": "teacher"},
        )

    def test_course_group_bind_requires_teacher_group_membership(self) -> None:
        with self.assertRaises(HTTPException):
            course_service.bind_course_academy_group(
                user={"user_id": "teacher-outside", "role": "teacher"},
                course_id="course-1",
                academy_id="academy-1",
                group_id=self.group["group_id"],
            )

    def test_course_group_bind_allows_owner_teacher_in_group(self) -> None:
        updated = course_service.bind_course_academy_group(
            user={"user_id": "teacher-1", "role": "teacher"},
            course_id="course-1",
            academy_id="academy-1",
            group_id=self.group["group_id"],
        )

        self.assertEqual(updated.access_group_id, self.group["group_id"])
        self.assertEqual(updated.access_academy_id, "academy-1")
        self.assertFalse(updated.is_public)

    def test_assigned_private_course_is_visible_and_runtime_reports_to_teacher(self) -> None:
        academy_repo.create_assignment(
            group_id=self.group["group_id"],
            sender_user_id="teacher-1",
            kind="course",
            ref_id="course-1",
            title="권장 코스",
            target_user_ids=["student-a"],
        )
        academy_router._enroll_course_v2_for_students("course-1", ["student-a"])

        visible = course_service.get_course_v2(
            "course-1",
            {"user_id": "student-a", "role": "student"},
        )
        self.assertEqual(visible.id, "course-1")

        response = asyncio.run(
            runtime_router.runtime_submit(
                _DummyRequest(),
                {
                    "course_id": "course-1",
                    "module_id": "m1",
                    "correct_count": 1,
                    "total_count": 1,
                    "elapsed_seconds": 30,
                },
                _user={"user_id": "student-a", "role": "student"},
            )
        )

        self.assertTrue(response.data["passed"])
        analysis = academy_router._build_student_analysis("student-a")
        course_items = analysis["courses"]
        self.assertTrue(any(item["ref_id"] == "course-1" for item in course_items))
        course_item = next(item for item in course_items if item["ref_id"] == "course-1")
        self.assertIn("m1", course_item["runtime_state"]["completed_modules"])

    def test_submission_list_is_limited_by_user_or_teacher_group(self) -> None:
        other_group = self._create_other_group()
        own_assignment = academy_repo.create_assignment(
            group_id=self.group["group_id"],
            sender_user_id="teacher-1",
            kind="homework",
            ref_id="doc-1",
            target_user_ids=["student-a"],
        )
        academy_repo.create_assignment(
            group_id=other_group["group_id"],
            sender_user_id="teacher-2",
            kind="homework",
            ref_id="doc-2",
            target_user_ids=["student-x"],
        )

        student_response = academy_router.list_submissions(
            user={"user_id": "student-a", "role": "student"},
        )
        teacher_response = academy_router.list_submissions(
            user={"user_id": "teacher-1", "role": "teacher"},
        )

        self.assertEqual({item["user_id"] for item in student_response.data["items"]}, {"student-a"})
        self.assertEqual(
            {item["assignment_id"] for item in teacher_response.data["items"]},
            {own_assignment["assignment_id"]},
        )
        with self.assertRaises(HTTPException):
            academy_router.list_submissions(
                user_id="student-x",
                user={"user_id": "student-a", "role": "student"},
            )

    def test_report_access_is_limited_to_owner_or_group_teacher(self) -> None:
        assignment = academy_repo.create_assignment(
            group_id=self.group["group_id"],
            sender_user_id="teacher-1",
            kind="homework",
            ref_id="doc-1",
            target_user_ids=["student-a"],
        )
        submission = academy_repo.list_submissions(
            assignment_id=assignment["assignment_id"],
        )[0]
        report = academy_repo.create_submission_report(
            submission_id=submission["submission_id"],
            correct_rate=80.0,
        )

        owner_response = academy_router.get_submission_report(
            report["report_id"],
            user={"user_id": "student-a", "role": "student"},
        )
        teacher_response = academy_router.get_report_by_submission(
            submission["submission_id"],
            user={"user_id": "teacher-1", "role": "teacher"},
        )

        self.assertEqual(owner_response.data["report_id"], report["report_id"])
        self.assertEqual(teacher_response.data["report_id"], report["report_id"])
        with self.assertRaises(HTTPException):
            academy_router.get_submission_report(
                report["report_id"],
                user={"user_id": "student-b", "role": "student"},
            )
        with self.assertRaises(HTTPException):
            academy_router.get_report_by_submission(
                submission["submission_id"],
                user={"user_id": "teacher-outside", "role": "teacher"},
            )

    def test_teacher_cannot_create_report_for_other_group_submission(self) -> None:
        other_group = self._create_other_group()
        assignment = academy_repo.create_assignment(
            group_id=other_group["group_id"],
            sender_user_id="teacher-2",
            kind="homework",
            ref_id="doc-2",
            target_user_ids=["student-x"],
        )
        submission = academy_repo.list_submissions(
            assignment_id=assignment["assignment_id"],
        )[0]

        with self.assertRaises(HTTPException):
            academy_router.create_submission_report(
                academy_router.ReportCreate(submission_id=submission["submission_id"]),
                user={"user_id": "teacher-1", "role": "teacher"},
            )

    def test_teacher_cannot_create_runtime_state_for_unassigned_student(self) -> None:
        response = asyncio.run(
            runtime_router.runtime_state(
                _TeacherRequest(),
                "course-public",
                user_id="student-b",
                _user={"user_id": "teacher-1", "role": "teacher"},
            )
        )

        self.assertIsNone(response.data)
        self.assertEqual(response.message, "Course not found")
        self.assertEqual(course_repo.get_runtime_state("student-b", "course-public"), {})

    def test_teacher_can_view_runtime_state_for_assigned_student(self) -> None:
        academy_router._enroll_course_v2_for_students("course-1", ["student-a"])

        response = asyncio.run(
            runtime_router.runtime_state(
                _TeacherRequest(),
                "course-1",
                user_id="student-a",
                _user={"user_id": "teacher-1", "role": "teacher"},
            )
        )

        self.assertIsNotNone(response.data)
        self.assertEqual(response.data["user_id"], "student-a")

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
