import os
import sqlite3
import tempfile
import unittest

import auth


class TeacherRolePromotionTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(ignore_cleanup_errors=True)
        self.db_path = os.path.join(self.tmp.name, "quests.db")
        self.old_db_path = auth.DB_PATH
        auth.DB_PATH = self.db_path
        auth.init_user_db()

    def tearDown(self):
        auth.DB_PATH = self.old_db_path
        self.tmp.cleanup()

    def test_teacher_login_promotes_legacy_teacher_account(self):
        user_id = "legacy-teacher"
        email = "legacy.teacher@example.com"
        salt = "fixedsalt"
        password_hash = auth._hash_password("secret123", salt)
        with sqlite3.connect(self.db_path) as conn:
            conn.execute(
                """
                INSERT INTO users (
                    user_id, username, name, grade, email, role,
                    password_hash, salt, created_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    user_id,
                    email,
                    "Legacy Teacher",
                    "teacher",
                    email,
                    "student",
                    password_hash,
                    salt,
                    "2026-01-01T00:00:00Z",
                ),
            )

        user = auth.authenticate_teacher(email=email, password="secret123")

        self.assertIsNotNone(user)
        self.assertEqual(user["role"], "teacher")
        with sqlite3.connect(self.db_path) as conn:
            role = conn.execute(
                "SELECT role FROM users WHERE user_id = ?",
                (user_id,),
            ).fetchone()[0]
        self.assertEqual(role, "teacher")


if __name__ == "__main__":
    unittest.main()
