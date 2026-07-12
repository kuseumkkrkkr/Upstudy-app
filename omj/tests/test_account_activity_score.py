import os
import tempfile
import unittest
from pathlib import Path

from fastapi import FastAPI
from fastapi.testclient import TestClient

import auth
from app.api.routes.account import router as account_router
from storage import student_account_store


class AccountActivityScoreTests(unittest.TestCase):
    def setUp(self) -> None:
        fd, path = tempfile.mkstemp(suffix=".db")
        os.close(fd)
        self._db_file = Path(path)
        self._old_db = student_account_store.DB_PATH
        student_account_store.DB_PATH = str(self._db_file)
        student_account_store.init_student_account_db()
        self.app = FastAPI()
        self.app.include_router(account_router)
        self.client = TestClient(self.app)
        self.headers = {
            "Authorization": f"Bearer {auth.create_token('student-activity-1', 'student')}"
        }

    def tearDown(self) -> None:
        student_account_store.DB_PATH = self._old_db
        try:
            self._db_file.unlink(missing_ok=True)
        except PermissionError:
            pass

    def test_activity_score_endpoint_accumulates_once_per_ref(self) -> None:
        payload = {
            "delta_score": 300,
            "ref_id": "problem:2026-07-06:q-1",
            "reason": "problem_solve",
            "date_key": "2026-07-06",
        }

        first = self.client.post(
            "/account/activity-score",
            json=payload,
            headers=self.headers,
        )
        duplicate = self.client.post(
            "/account/activity-score",
            json=payload,
            headers=self.headers,
        )

        self.assertEqual(first.status_code, 200)
        self.assertEqual(duplicate.status_code, 200)
        first_data = first.json()["data"]
        duplicate_data = duplicate.json()["data"]
        self.assertEqual(first_data["activity_score"], 300)
        self.assertEqual(first_data["level"], 2)
        self.assertEqual(first_data["total_points"], 0)
        self.assertEqual(first_data["activity_score_reward"]["granted_score"], 300)
        self.assertEqual(duplicate_data["activity_score"], 300)
        self.assertEqual(
            duplicate_data["activity_score_reward"]["granted_score"],
            0,
        )
        self.assertTrue(duplicate_data["activity_score_reward"]["duplicate"])


if __name__ == "__main__":
    unittest.main()
