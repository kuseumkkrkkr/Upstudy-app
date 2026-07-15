import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from fastapi import Depends, FastAPI
from fastapi.testclient import TestClient

import auth
from app.api.routes.account import router as account_router
from app.api.routes.auth.middleware import require_role
from storage import system_notice_store


class AuthSecurityTests(unittest.TestCase):
    def setUp(self) -> None:
        fd, path = tempfile.mkstemp(suffix=".db")
        os.close(fd)
        self.db_file = Path(path)
        self.old_auth_db = auth.DB_PATH
        self.old_notice_db = system_notice_store.DB_PATH
        auth.DB_PATH = str(self.db_file)
        system_notice_store.DB_PATH = str(self.db_file)
        auth.init_user_db()

    def tearDown(self) -> None:
        auth.DB_PATH = self.old_auth_db
        system_notice_store.DB_PATH = self.old_notice_db
        try:
            self.db_file.unlink(missing_ok=True)
        except PermissionError:
            pass

    def test_signed_elevated_role_claim_does_not_override_db_role(self) -> None:
        user_id = auth.register_user(
            username="secstudent",
            password="Testpass1",
            name="Sec Student",
            grade="1",
        )
        forged_role_token = auth.create_token(user_id, "admin")

        app = FastAPI()

        @app.get("/teacher-only")
        def teacher_only(_user=Depends(require_role("teacher", "admin"))):
            return {"ok": True}

        response = TestClient(app).get(
            "/teacher-only",
            headers={"Authorization": f"Bearer {forged_role_token}"},
        )

        self.assertEqual(response.status_code, 403)
        self.assertEqual(auth.get_user_role(user_id), "student")

    def test_signed_student_role_skips_database_lookup(self) -> None:
        """필요 변수: 서명 검증을 마친 학생 payload. 권한 상승 없는 학생 역할은 DB 조회 없이 확정한다."""

        with patch.object(auth, "get_user_role", side_effect=AssertionError("DB lookup")):
            user = auth.resolve_token_payload_user(
                {"sub": "load-student", "role": "student"}
            )

        self.assertEqual(user["user_id"], "load-student")
        self.assertEqual(user["role"], "student")

    def test_persisted_teacher_role_allows_roleless_token(self) -> None:
        user_id = auth.register_teacher(
            email="secteacher@example.com",
            password="passw0rd",
            name="Sec Teacher",
        )
        roleless_token = auth.create_token(user_id)

        app = FastAPI()

        @app.get("/teacher-only")
        def teacher_only(_user=Depends(require_role("teacher", "admin"))):
            return {"ok": True}

        response = TestClient(app).get(
            "/teacher-only",
            headers={"Authorization": f"Bearer {roleless_token}"},
        )

        self.assertEqual(response.status_code, 200)

    def test_account_admin_write_requires_persisted_admin_role(self) -> None:
        user_id = auth.register_user(
            username="secnotice",
            password="Testpass1",
            name="Sec Notice",
            grade="1",
        )
        forged_role_token = auth.create_token(user_id, "admin")
        app = FastAPI()
        app.include_router(account_router)

        response = TestClient(app).put(
            "/account/system-notices",
            json={"title": "security-test", "content_html": "<b>x</b>"},
            headers={"Authorization": f"Bearer {forged_role_token}"},
        )

        self.assertEqual(response.status_code, 403)


if __name__ == "__main__":
    unittest.main()
