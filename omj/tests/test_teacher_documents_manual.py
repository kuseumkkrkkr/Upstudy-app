import tempfile
import unittest
from pathlib import Path

from fastapi.testclient import TestClient

import auth
import server
import storage.social_storage as social_storage
import storage.storage as storage_mod
import storage.textbook_storage as textbook_storage
import storage.user_kv_storage as user_kv_storage
from domain.course import v2_repository as course_v2_repo


class TeacherDocumentsManualTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmpdir = tempfile.TemporaryDirectory()
        self.db_path = str(Path(self._tmpdir.name) / "test.db")
        self._db_modules = (
            storage_mod,
            auth,
            social_storage,
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
        user_kv_storage.init_user_kv_db()
        textbook_storage.init_textbook_db()
        self.client = TestClient(server.app)

    def tearDown(self) -> None:
        for mod, db_path in self._old_db_paths.items():
            setattr(mod, "DB_PATH", db_path)
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
        self.assertGreaterEqual(len(items), 1)
        manual = items[0]
        self.assertEqual(manual["textbook_id"], server._TEACHER_MANUAL_TEXTBOOK_ID)
        self.assertEqual(manual["title"], "설명서 기본 교재")
        self.assertTrue(manual["is_teacher_manual"])
        self.assertFalse(manual["is_course_selectable"])
        self.assertFalse(manual["student_visible"])

        stored = textbook_storage.get_textbook(server._TEACHER_MANUAL_TEXTBOOK_ID)
        self.assertIsNotNone(stored)
        self.assertEqual(stored["title"], "설명서 기본 교재")

    def test_student_cannot_access_teacher_documents(self) -> None:
        student_token = self._register_student()

        resp = self.client.get(
            "/teacher/documents",
            params={"type": "textbook"},
            headers={"Authorization": f"Bearer {student_token}"},
        )

        self.assertEqual(resp.status_code, 403)

    def test_student_textbook_api_does_not_expose_manual(self) -> None:
        student_token = self._register_student()

        resp = self.client.get(
            "/textbooks",
            headers={"Authorization": f"Bearer {student_token}"},
        )
        self.assertEqual(resp.status_code, 200)
        ids = {item["textbook_id"] for item in resp.json()["textbooks"]}
        self.assertNotIn(server._TEACHER_MANUAL_TEXTBOOK_ID, ids)

        direct = self.client.get(
            f"/textbooks/{server._TEACHER_MANUAL_TEXTBOOK_ID}",
            headers={"Authorization": f"Bearer {student_token}"},
        )
        self.assertEqual(direct.status_code, 403)

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


if __name__ == "__main__":
    unittest.main()
