"""PostgreSQL 레이팅 저장소의 선택적 startup 동작을 검증한다."""
from __future__ import annotations

import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from rating_service import apply_rating_update, fetch_user_rating
from storage.postgres_rating_store import PostgresRatingStore
from storage import sqlite_rating_store as sqlite_backend


class PostgresRatingStoreTest(unittest.TestCase):
    """PostgreSQL 선택 여부가 startup에서 일관되게 적용되는지 검증한다."""

    def test_require_ready_uses_sqlite_fallback_without_database_url(self):
        """필요 변수: DATABASE_URL 환경 변수. 작동 원리: 미설정 시 DB 연결 없이 fallback을 선택한다."""
        with patch.dict(os.environ, {"DATABASE_URL": ""}):
            self.assertFalse(PostgresRatingStore().require_ready())

    def test_sqlite_fallback_persists_rating_and_replays_submission(self):
        """필요 변수: 임시 SQLite DB·정규 문제. 작동 원리: 첫 제출은 저장하고 같은 키 재전송은 같은 결과를 반환한다."""
        quest = {
            "header": {"quest_id": "sqlite-fallback-quest"},
            "info": {"hash_tag": ["#algebra"], "difficulty_score": 4, "main_huddle": 1, "flow_rate": 1},
            "solves": [{"hash_tag": ["#algebra"], "enter_huddle": 1}],
        }
        with tempfile.TemporaryDirectory() as temp_dir:
            db_path = Path(temp_dir) / "rating.sqlite3"
            with (
                patch.dict(os.environ, {"DATABASE_URL": ""}),
                patch.object(sqlite_backend, "DB_PATH", str(db_path)),
                patch.object(sqlite_backend, "_SCHEMA_READY", False),
            ):
                first = apply_rating_update(
                    user_id="sqlite-fallback-user",
                    quest=quest,
                    is_correct=True,
                    step_outcomes=[],
                    response_time_seconds=20,
                    submission_ref="sqlite-fallback-submission",
                )
                replay = apply_rating_update(
                    user_id="sqlite-fallback-user",
                    quest=quest,
                    is_correct=False,
                    step_outcomes=[],
                    response_time_seconds=20,
                    submission_ref="sqlite-fallback-submission",
                )

                self.assertEqual(replay, first)
                self.assertEqual(fetch_user_rating("sqlite-fallback-user"), first)


if __name__ == "__main__":
    unittest.main()
