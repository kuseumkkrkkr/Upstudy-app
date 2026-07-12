import gc
import json
import tempfile
import unittest
from pathlib import Path

from fastapi import HTTPException
from fastapi.testclient import TestClient

import auth
import server
import storage.social_storage as social_storage
import storage.exam_storage as exam_storage
import storage.teacher_exam_document_store as teacher_exam_document_store
import storage.teacher_store as teacher_store
import storage.storage as storage_mod
import storage.textbook_storage as textbook_storage
import storage.user_kv_storage as user_kv_storage
from app.api.routes.courses import service as course_service
from domain.course import v2_repository as course_v2_repo
from domain.course.v2_models import CourseModule, CourseModuleType, CourseV2


class TeacherDocumentsManualTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmpdir = tempfile.TemporaryDirectory()
        self.db_path = str(Path(self._tmpdir.name) / "test.db")
        self._db_modules = (
            storage_mod,
            auth,
            social_storage,
            exam_storage,
            teacher_exam_document_store,
            teacher_store,
            textbook_storage,
            user_kv_storage,
            server,
            course_v2_repo,
        )
        self._old_db_paths = {
            mod: getattr(mod, "DB_PATH", None) for mod in self._db_modules
        }
        for mod in self._db_modules:
            setattr(mod, "DB_PATH", self.db_path)
        storage_mod.init_db()
        auth.init_user_db()
        social_storage.init_social_db()
        exam_storage.init_exam_db()
        teacher_store.init_teacher_store_db()
        user_kv_storage.init_user_kv_db()
        textbook_storage.init_textbook_db()
        self.client = TestClient(server.app)

    def tearDown(self) -> None:
        self.client.close()
        for mod, db_path in self._old_db_paths.items():
            setattr(mod, "DB_PATH", db_path)
        gc.collect()
        self._tmpdir.cleanup()

    def _register_teacher(self) -> str:
        resp = self.client.post(
            "/auth/teacher/register",
            json={
                "email": "teacher@example.com",
                "password": "passw0rd",
                "name": "Teacher One",
            },
        )
        self.assertEqual(resp.status_code, 201)
        return resp.json()["token"]

    def _register_student(self) -> str:
        resp = self.client.post(
            "/auth/register",
            json={
                "username": "stud01",
                "password": "passw0rd",
                "name": "Student One",
                "grade": "1",
            },
        )
        self.assertEqual(resp.status_code, 201)
        return resp.json()["token"]

    def test_teacher_documents_include_manual_but_course_picker_flags_it_off(self) -> None:
        teacher_token = self._register_teacher()

        resp = self.client.get(
            "/teacher/documents",
            params={"type": "textbook"},
            headers={"Authorization": f"Bearer {teacher_token}"},
        )

        self.assertEqual(resp.status_code, 200)
        items = resp.json()["textbooks"]
        self.assertGreaterEqual(len(items), 2)
        by_id = {item["textbook_id"]: item for item in items}
        manual = by_id[server._TEACHER_MANUAL_TEXTBOOK_ID]
        self.assertEqual(manual["textbook_id"], server._TEACHER_MANUAL_TEXTBOOK_ID)
        self.assertEqual(manual["title"], "설명서 기본 교재")
        self.assertTrue(manual["is_teacher_manual"])
        self.assertFalse(manual["is_course_selectable"])
        self.assertFalse(manual["student_visible"])
        problem_manual = by_id[
            server._TEACHER_PROBLEM_GENERATION_MANUAL_TEXTBOOK_ID
        ]
        self.assertEqual(problem_manual["title"], "문제 생성 설명서")
        self.assertTrue(problem_manual["is_teacher_manual"])
        self.assertFalse(problem_manual["is_course_selectable"])
        self.assertFalse(problem_manual["student_visible"])

        stored = textbook_storage.get_textbook(server._TEACHER_MANUAL_TEXTBOOK_ID)
        self.assertIsNotNone(stored)
        self.assertEqual(stored["title"], "설명서 기본 교재")
        stored_problem_manual = textbook_storage.get_textbook(
            server._TEACHER_PROBLEM_GENERATION_MANUAL_TEXTBOOK_ID
        )
        self.assertIsNotNone(stored_problem_manual)
        self.assertEqual(stored_problem_manual["title"], "문제 생성 설명서")

    def test_teacher_documents_do_not_expand_to_store_textbook_db(self) -> None:
        teacher_token = self._register_teacher()
        teacher_user_id = auth.decode_token(teacher_token)["sub"]
        textbook_storage.create_textbook(
            {
                "textbook_id": "external-textbook",
                "title": "외부 교재",
                "category": "textbook",
                "tags": ["외부"],
                "chapters": [],
            },
            created_by="system",
        )
        teacher_store.top_up_test(teacher_user_id, 1000)
        teacher_store.purchase(teacher_user_id, "textbook_db")

        resp = self.client.get(
            "/teacher/documents",
            params={"type": "textbook"},
            headers={"Authorization": f"Bearer {teacher_token}"},
        )

        self.assertEqual(resp.status_code, 200)
        ids = {item["textbook_id"] for item in resp.json()["textbooks"]}
        self.assertIn(server._TEACHER_MANUAL_TEXTBOOK_ID, ids)
        self.assertNotIn("external-textbook", ids)

    def test_student_cannot_access_teacher_documents(self) -> None:
        student_token = self._register_student()

        resp = self.client.get(
            "/teacher/documents",
            params={"type": "textbook"},
            headers={"Authorization": f"Bearer {student_token}"},
        )

        self.assertEqual(resp.status_code, 403)

    def test_teacher_documents_lists_only_owned_exam_documents(self) -> None:
        teacher_token = self._register_teacher()
        teacher_user_id = auth.decode_token(teacher_token)["sub"]

        exam_storage.create_exam(
            exam_id="exam-doc-1",
            user_id=teacher_user_id,
            status="done",
            params={
                "title": "중간고사 대비",
                "question_count": 12,
                "ranges": [{"tags": ["함수", "수열"]}],
            },
        )
        exam_storage.add_exam_items(
            "exam-doc-1",
            [
                {
                    "item_index": 0,
                    "status": "done",
                    "subject_key": "math",
                    "hash_tags": ["함수"],
                    "difficulty_tier": 3,
                    "solves_count": 2,
                    "strategy_level": 2,
                    "branch_conditions": 1,
                    "question_type": "short",
                    "quest_id": "q-1",
                    "flow_count": 1,
                    "codebase_id": 1,
                    "seed": 1,
                    "error": None,
                }
            ],
        )
        exam_storage.create_exam(
            exam_id="exam-created-but-not-owned",
            user_id=teacher_user_id,
            status="done",
            params={
                "title": "생성 이력만 있는 시험지",
                "question_count": 8,
                "ranges": [{"tags": ["비공개"]}],
            },
        )
        teacher_exam_document_store.upsert_teacher_exam_document(
            teacher_user_id,
            "exam-doc-1",
            "문서함 시험지",
        )

        resp = self.client.get(
            "/teacher/documents",
            params={"type": "exam"},
            headers={"Authorization": f"Bearer {teacher_token}"},
        )

        self.assertEqual(resp.status_code, 200)
        items = resp.json()["textbooks"]
        self.assertEqual(len(items), 1)
        exam = items[0]
        self.assertEqual(exam["exam_id"], "exam-doc-1")
        self.assertEqual(exam["document_id"], "exam-doc-1")
        self.assertEqual(exam["title"], "문서함 시험지")
        self.assertEqual(exam["category"], "시험지")
        self.assertEqual(exam["type"], "exam")
        self.assertEqual(exam["item_count"], 1)
        self.assertEqual(exam["status"], "done")
        self.assertEqual(exam["tags"], ["함수", "수열"])
        self.assertFalse(exam["student_visible"])
        self.assertNotIn(
            "exam-created-but-not-owned",
            {item["exam_id"] for item in items},
        )

    def test_course_v2_rejects_unowned_exam_documents(self) -> None:
        teacher_token = self._register_teacher()
        teacher_user_id = auth.decode_token(teacher_token)["sub"]
        exam_storage.create_exam(
            exam_id="exam-doc-2",
            user_id="system-owner",
            status="done",
            params={
                "title": "문서함 시험지",
                "question_count": 4,
                "ranges": [{"tags": ["함수"]}],
            },
        )

        def course() -> CourseV2:
            return CourseV2(
                title="시험지 코스",
                description="",
                difficulty="중",
                duration="1주",
                modules=[
                    CourseModule(
                        id="m1",
                        type=CourseModuleType.exam_solve,
                        title="시험지 풀이",
                        exam_id="exam-doc-2",
                    ),
                    CourseModule(
                        id="m2",
                        type=CourseModuleType.level_test,
                        title="레벨 테스트",
                        exam_id="exam-doc-2",
                    ),
                ],
            )

        user = {"user_id": teacher_user_id, "role": "teacher"}
        with self.assertRaises(HTTPException) as raised:
            course_service.create_course_v2(user=user, course=course())
        self.assertEqual(raised.exception.status_code, 400)
        self.assertEqual(
            raised.exception.detail,
            "teacher_exam_document_not_owned",
        )

        teacher_exam_document_store.upsert_teacher_exam_document(
            teacher_user_id,
            "exam-doc-2",
            "문서함 시험지",
        )
        created = course_service.create_course_v2(user=user, course=course())
        self.assertEqual(created.owner_user_id, teacher_user_id)

    def test_student_can_access_exam_only_through_referencing_course(self) -> None:
        teacher_token = self._register_teacher()
        teacher_user_id = auth.decode_token(teacher_token)["sub"]
        student_token = self._register_student()
        exam_storage.create_exam(
            exam_id="exam-doc-3",
            user_id="system-owner",
            status="done",
            params={
                "title": "공개 코스 시험지",
                "question_count": 4,
                "ranges": [{"tags": ["함수"]}],
            },
        )
        teacher_exam_document_store.upsert_teacher_exam_document(
            teacher_user_id,
            "exam-doc-3",
            "공개 코스 시험지",
        )
        course_id = course_service.create_course_v2(
            user={"user_id": teacher_user_id, "role": "teacher"},
            course=CourseV2(
                title="공개 시험지 코스",
                is_public=True,
                modules=[
                    CourseModule(
                        id="m1",
                        type=CourseModuleType.exam_solve,
                        title="시험지 풀이",
                        exam_id="exam-doc-3",
                    ),
                ],
            ),
        ).id

        direct = self.client.get(
            "/exams/exam-doc-3",
            headers={"Authorization": f"Bearer {student_token}"},
        )
        self.assertEqual(direct.status_code, 404)

        via_course = self.client.get(
            "/exams/exam-doc-3",
            params={"course_id": course_id},
            headers={"Authorization": f"Bearer {student_token}"},
        )
        self.assertEqual(via_course.status_code, 200)
        self.assertEqual(via_course.json()["exam_id"], "exam-doc-3")

    def test_student_textbook_api_does_not_expose_manual(self) -> None:
        student_token = self._register_student()
        student_user_id = auth.decode_token(student_token)["sub"]
        user_kv_storage.set_user_kv(
            student_user_id,
            server._TEXTBOOK_LIBRARY_KEY,
            json.dumps(
                [{"textbook_id": "already-owned-book", "title": "기존 교재"}],
                ensure_ascii=False,
            ),
        )

        resp = self.client.get(
            "/textbooks",
            headers={"Authorization": f"Bearer {student_token}"},
        )
        self.assertEqual(resp.status_code, 200)
        ids = {item["textbook_id"] for item in resp.json()["textbooks"]}
        self.assertIn(textbook_storage.PUBLIC_MANUAL_TEXTBOOK_ID, ids)
        self.assertNotIn(server._TEACHER_MANUAL_TEXTBOOK_ID, ids)
        self.assertNotIn(
            server._TEACHER_PROBLEM_GENERATION_MANUAL_TEXTBOOK_ID,
            ids,
        )

        public_direct = self.client.get(
            f"/textbooks/{textbook_storage.PUBLIC_MANUAL_TEXTBOOK_ID}",
            headers={"Authorization": f"Bearer {student_token}"},
        )
        self.assertEqual(public_direct.status_code, 200)
        self.assertEqual(
            public_direct.json()["textbook_id"],
            textbook_storage.PUBLIC_MANUAL_TEXTBOOK_ID,
        )

        direct = self.client.get(
            f"/textbooks/{server._TEACHER_MANUAL_TEXTBOOK_ID}",
            headers={"Authorization": f"Bearer {student_token}"},
        )
        self.assertEqual(direct.status_code, 403)

        problem_manual_direct = self.client.get(
            f"/textbooks/{server._TEACHER_PROBLEM_GENERATION_MANUAL_TEXTBOOK_ID}",
            headers={"Authorization": f"Bearer {student_token}"},
        )
        self.assertEqual(problem_manual_direct.status_code, 403)

    def test_teacher_can_open_manual_directly(self) -> None:
        teacher_token = self._register_teacher()

        resp = self.client.get(
            f"/textbooks/{server._TEACHER_MANUAL_TEXTBOOK_ID}",
            headers={"Authorization": f"Bearer {teacher_token}"},
        )

        self.assertEqual(resp.status_code, 200)
        payload = resp.json()
        self.assertEqual(payload["textbook_id"], server._TEACHER_MANUAL_TEXTBOOK_ID)
        self.assertTrue(payload["is_teacher_manual"])
        self.assertFalse(payload["student_visible"])

        problem_manual = self.client.get(
            f"/textbooks/{server._TEACHER_PROBLEM_GENERATION_MANUAL_TEXTBOOK_ID}",
            headers={"Authorization": f"Bearer {teacher_token}"},
        )

        self.assertEqual(problem_manual.status_code, 200)
        problem_payload = problem_manual.json()
        self.assertEqual(
            problem_payload["textbook_id"],
            server._TEACHER_PROBLEM_GENERATION_MANUAL_TEXTBOOK_ID,
        )
        self.assertEqual(problem_payload["title"], "문제 생성 설명서")
        self.assertTrue(problem_payload["is_teacher_manual"])
        self.assertFalse(problem_payload["student_visible"])

    def test_course_v2_rejects_teacher_manual_textbook(self) -> None:
        teacher_token = self._register_teacher()
        base_payload = {
            "title": "설명서 차단 코스",
            "description": "설명서 기본 교재는 코스에 등록할 수 없습니다.",
            "difficulty": "중",
            "duration": "1주",
            "textbook_id": "test_textbook",
            "modules": [
                {
                    "id": "m1",
                    "type": "textbook_view",
                    "title": "교재 읽기",
                    "textbook_id": "test_textbook",
                    "page_from": 1,
                    "page_to": 1,
                }
            ],
        }

        top_level = {
            **base_payload,
            "textbook_id": server._TEACHER_MANUAL_TEXTBOOK_ID,
        }
        resp = self.client.post(
            "/courses/v2",
            headers={"Authorization": f"Bearer {teacher_token}"},
            json=top_level,
        )
        self.assertEqual(resp.status_code, 400)
        self.assertEqual(resp.json()["detail"], "teacher_manual_textbook_not_course_selectable")

        module_level = {
            **base_payload,
            "modules": [
                {
                    **base_payload["modules"][0],
                    "textbook_id": server._TEACHER_MANUAL_TEXTBOOK_ID,
                }
            ],
        }
        resp = self.client.post(
            "/courses/v2",
            headers={"Authorization": f"Bearer {teacher_token}"},
            json=module_level,
        )
        self.assertEqual(resp.status_code, 400)
        self.assertEqual(resp.json()["detail"], "teacher_manual_textbook_not_course_selectable")

        problem_generation_manual = {
            **base_payload,
            "textbook_id": server._TEACHER_PROBLEM_GENERATION_MANUAL_TEXTBOOK_ID,
        }
        resp = self.client.post(
            "/courses/v2",
            headers={"Authorization": f"Bearer {teacher_token}"},
            json=problem_generation_manual,
        )
        self.assertEqual(resp.status_code, 400)
        self.assertEqual(resp.json()["detail"], "teacher_manual_textbook_not_course_selectable")


if __name__ == "__main__":
    unittest.main()
