"""학원 다중 사용자 처리의 개별 오류 격리를 독립 저장소 없이 검증한다."""

import unittest
from types import SimpleNamespace
from unittest.mock import patch

from app.api.routes.academy import router as academy_router


class AcademyExceptionIsolationTests(unittest.TestCase):
    """필요 변수: 오류 학생과 정상 학생이 섞인 학원 작업 데이터.

    작동 원리: 외부 저장소를 모의 처리해 한 학생의 오류가 다음 학생 또는
    본인 데이터 응답으로 전파되지 않는지 검증한다.
    """

    def test_course_assignment_skips_failed_student_and_continues(self) -> None:
        """필요 변수: 런타임 조회가 실패하는 학생과 정상 학생 목록.

        작동 원리: 실패 학생 ID를 반환하고 뒤 학생의 코스 배정도 계속 저장한다.
        """
        saved_user_ids: list[str] = []

        def get_runtime_state(user_id: str, _course_id: str):
            if user_id == "student-b":
                raise RuntimeError("temporary lookup failure")
            return {}

        def save_runtime_state(user_id: str, _course_id: str, _state: dict) -> None:
            saved_user_ids.append(user_id)

        with (
            patch.object(
                academy_router.course_v2_repo,
                "get_course_v2",
                return_value=SimpleNamespace(id="course-1"),
            ),
            patch.object(
                academy_router.course_v2_repo,
                "get_runtime_state",
                side_effect=get_runtime_state,
            ),
            patch.object(
                academy_router.course_v2_repo,
                "upsert_runtime_state",
                side_effect=save_runtime_state,
            ),
        ):
            errors = academy_router._enroll_course_v2_for_students(
                "course-1",
                ["student-a", "student-b", "student-c"],
            )

        self.assertEqual(errors, ["student-b"])
        self.assertEqual(saved_user_ids, ["student-a", "student-c"])

    def test_snapshot_filter_falls_back_to_own_rows_on_friend_lookup_error(self) -> None:
        """필요 변수: 본인·타인 스냅샷과 실패하는 친구 목록 조회.

        작동 원리: 조회 실패 시 타인 정보는 노출하지 않고 본인 행만 반환한다.
        """
        rows = [
            {"snapshot_id": "mine", "user_id": "student-a"},
            {"snapshot_id": "other", "user_id": "student-b"},
        ]
        with patch.object(
            academy_router,
            "get_friends",
            side_effect=RuntimeError("temporary lookup failure"),
        ):
            filtered = academy_router._filter_accessible_snapshots(
                rows,
                caller_user_id="student-a",
            )

        self.assertEqual([row["snapshot_id"] for row in filtered], ["mine"])

    def test_student_analysis_keeps_other_sources_when_some_lookups_fail(self) -> None:
        """필요 변수: 손상 레이팅, 실패하는 코스·풀이 조회와 정상 보조 데이터.

        작동 원리: 실패 출처는 빈 값으로 대체하고 숙제·레벨 분석·일정은 응답에
        계속 포함되는지 검증한다.
        """
        assignments = [
            {"kind": "course", "ref_id": "course-broken", "title": "코스"},
            {"kind": "homework", "ref_id": "homework-ok", "title": "숙제"},
        ]
        with (
            patch.object(
                academy_router.postgres_rating_store,
                "fetch_user",
                return_value={"rating": "broken", "recent_count": "broken"},
            ),
            patch.object(
                academy_router.postgres_rating_store,
                "list_tag_stats",
                side_effect=RuntimeError("tag lookup failure"),
            ),
            patch.object(
                academy_router.repo,
                "list_my_assignments",
                return_value=assignments,
            ),
            patch.object(
                academy_router.course_v2_repo,
                "get_runtime_state",
                side_effect=RuntimeError("course lookup failure"),
            ),
            patch.object(
                academy_router,
                "list_solve_history",
                side_effect=RuntimeError("history lookup failure"),
            ),
            patch.object(
                academy_router,
                "list_level_test_analysis_summaries",
                return_value=[{"session_id": "level-ok"}],
            ),
            patch.object(
                academy_router,
                "list_weakness_tags",
                return_value=[{"tag": "함수"}],
            ),
            patch.object(
                academy_router.repo,
                "list_student_schedule_tasks",
                return_value=[{"task_id": "schedule-ok"}],
            ),
        ):
            analysis = academy_router._build_student_analysis("student-a")

        self.assertEqual(analysis["rating"]["rating"], 0)
        self.assertEqual(analysis["solve_history"], [])
        self.assertEqual(analysis["level_test_analysis"][0]["session_id"], "level-ok")
        self.assertEqual(analysis["courses"][0]["progress"], 0)
        self.assertEqual(analysis["homework"][0]["ref_id"], "homework-ok")
        self.assertEqual(analysis["student_schedule"][0]["task_id"], "schedule-ok")


if __name__ == "__main__":
    unittest.main()
