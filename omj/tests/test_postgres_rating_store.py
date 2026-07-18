"""PostgreSQL 레이팅 저장소의 필수 startup 동작을 검증한다."""
from __future__ import annotations

import os
import unittest
from unittest.mock import patch

from storage.postgres_rating_store import PostgresRatingStore


class PostgresRatingStoreTest(unittest.TestCase):
    """PostgreSQL 선택 여부가 startup에서 일관되게 적용되는지 검증한다."""

    def test_require_ready_rejects_missing_database_url(self):
        """필요 변수: DATABASE_URL 환경 변수. 작동 원리: 미설정 시 서버 준비를 즉시 거부한다."""
        with patch.dict(os.environ, {"DATABASE_URL": ""}):
            with self.assertRaisesRegex(RuntimeError, "DATABASE_URL"):
                PostgresRatingStore().require_ready()


if __name__ == "__main__":
    unittest.main()
