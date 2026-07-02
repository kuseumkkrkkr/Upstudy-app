import tempfile
import unittest
from pathlib import Path

from fastapi.testclient import TestClient

import auth
import server
import storage.social_storage as social_storage
import storage.storage as storage_mod
import storage.study_group_storage as sg_storage


class StudyGroupTeacherFlowTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmpdir = tempfile.TemporaryDirectory()
        self.db_path = str(Path(self._tmpdir.name) / "test.db")
        for mod in (storage_mod, auth, social_storage, sg_storage, server):
            setattr(mod, "DB_PATH", self.db_path)
        storage_mod.init_db()
        auth.init_user_db()
        social_storage.init_social_db()
        sg_storage.init_study_group_db()
        self.client = TestClient(server.app)

    def tearDown(self) -> None:
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

    def test_teacher_group_code_join_flow(self) -> None:
        teacher_token = self._register_teacher()
        student_token = self._register_student()

        create_resp = self.client.post(
            "/social/study-groups",
            headers={"Authorization": f"Bearer {teacher_token}"},
            json={
                "name": "더미 그룹",
                "description": "테스트용 그룹",
                "max_members": 10,
                "is_public": True,
                "lock_enabled": False,
                "invite_code": "ABC1234",
            },
        )
        self.assertEqual(create_resp.status_code, 201)
        group = create_resp.json()
        self.assertEqual(group["owner_role"], "teacher")
        self.assertFalse(group["is_public"])
        self.assertEqual(group["invite_code"], "ABC1234")

        meta_resp = self.client.get("/social/study-groups/invite/ABC1234")
        self.assertEqual(meta_resp.status_code, 200)
        self.assertEqual(meta_resp.json()["owner_role"], "teacher")

        search_resp = self.client.get(
            "/social/study-groups/search",
            params={"q": "더미"},
            headers={"Authorization": f"Bearer {student_token}"},
        )
        self.assertEqual(search_resp.status_code, 200)
        self.assertEqual(search_resp.json()["groups"], [])

        join_resp = self.client.post(
            "/social/study-groups/join-by-code",
            headers={"Authorization": f"Bearer {student_token}"},
            json={"invite_code": "ABC1234"},
        )
        self.assertEqual(join_resp.status_code, 200)
        joined = join_resp.json()
        self.assertEqual(joined["group_id"], group["group_id"])
        self.assertEqual(len(joined["member_ids"]), 2)

        members_resp = self.client.get(
            f"/social/study-groups/{group['group_id']}/members",
            headers={"Authorization": f"Bearer {teacher_token}"},
        )
        self.assertEqual(members_resp.status_code, 200)
        members = members_resp.json()
        self.assertEqual(len(members), 2)
        usernames = {item["username"] for item in members}
        self.assertIn("teacher@example.com", usernames)
        self.assertIn("stud01", usernames)


if __name__ == "__main__":
    unittest.main()
