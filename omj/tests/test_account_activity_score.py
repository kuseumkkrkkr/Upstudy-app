import unittest
import uuid
from unittest.mock import patch

from fastapi import FastAPI
from fastapi.testclient import TestClient

import auth
from app.api.routes.account import router as account_router
from storage import student_account_store


class AccountActivityScoreTests(unittest.TestCase):
    def setUp(self) -> None:
        student_account_store.init_student_account_db()
        self.app = FastAPI()
        self.app.include_router(account_router)
        self.client = TestClient(self.app)
        self.user_id = f"account-worker-{uuid.uuid4().hex}"
        self.headers = {"Authorization": f"Bearer {auth.create_token(self.user_id, 'admin')}"}
        self._role_patcher = patch.object(auth, "get_user_role", return_value="admin")
        self._role_patcher.start()

    def tearDown(self) -> None:
        self._role_patcher.stop()
        pool = student_account_store.postgres_problem_store.get_pool()
        with pool.connection() as conn, conn.cursor() as cur:
            cur.execute("DELETE FROM student_point_ledger WHERE user_id = %s", (self.user_id,))
            cur.execute("DELETE FROM student_activity_score_ledger WHERE user_id = %s", (self.user_id,))
            cur.execute("DELETE FROM student_daily_point_usage WHERE user_id = %s", (self.user_id,))
            cur.execute("DELETE FROM student_account_stats WHERE user_id = %s", (self.user_id,))
            conn.commit()

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

    def test_level_milestone_grants_increasing_coins_once(self) -> None:
        """레벨 5와 10을 한 번에 통과해도 보상이 중복 없이 누적되는지 검증합니다."""
        response = self.client.post(
            "/account/activity-score",
            json={
                "delta_score": 8100,
                "ref_id": "problem:2026-07-06:q-milestone",
                "reason": "problem_solve",
                "date_key": "2026-07-06",
            },
            headers=self.headers,
        )

        self.assertEqual(response.status_code, 200)
        data = response.json()["data"]
        self.assertEqual(data["level"], 10)
        self.assertEqual(data["total_points"], 30)
        self.assertEqual(
            data["activity_score_reward"]["granted_milestone_coins"], 30
        )


if __name__ == "__main__":
    unittest.main()
