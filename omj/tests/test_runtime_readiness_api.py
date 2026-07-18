from __future__ import annotations

import os
import unittest
from unittest.mock import patch

from fastapi.testclient import TestClient

import server


class RuntimeReadinessApiTests(unittest.TestCase):
    """필요 변수: 저장소 운영 모드. 작동 원리: PostgreSQL 미설정·미검증 인스턴스를 로드밸런서에서 차단하는지 검증한다."""

    def setUp(self) -> None:
        """필요 변수: FastAPI 앱. 작동 원리: 실제 네트워크 없이 준비 상태 응답을 호출한다."""
        self.client = TestClient(server.app)

    def test_missing_postgres_configuration_is_not_ready(self) -> None:
        """필요 변수: 비어 있는 배포 환경. 작동 원리: DB 시크릿이 없으면 503으로 트래픽 진입을 막는다."""
        with patch.dict(os.environ, {}, clear=True):
            response = self.client.get("/health/ready")
        self.assertEqual(response.status_code, 503)
        detail = response.json()["detail"]
        self.assertFalse(detail["ready"])
        self.assertFalse(detail["database_configured"])

    def test_unverified_postgres_is_not_ready(self) -> None:
        """필요 변수: 감사 표식 없는 PostgreSQL 모드. 작동 원리: 잘못된 조기 전환을 503으로 로드밸런서에서 차단한다."""
        with patch.dict(
            os.environ,
            {
                "PROBLEM_CACHE_BACKEND": "postgres",
                "PROBLEM_CACHE_VERIFIED": "false",
            },
            clear=True,
        ):
            response = self.client.get("/health/ready")
        self.assertEqual(response.status_code, 503)
        self.assertFalse(response.json()["detail"]["ready"])

    def test_web_process_can_disable_embedded_background_workers(self) -> None:
        """필요 변수: 상용 웹 프로세스 환경 변수. 작동 원리: 웹 워커별 작업·생성 풀 중복 기동을 끌 수 있어야 한다."""
        with patch.dict(os.environ, {"RUN_EMBEDDED_BACKGROUND_WORKERS": "false"}, clear=True):
            self.assertFalse(server._embedded_background_workers_enabled())
        with patch.dict(os.environ, {"RUN_EMBEDDED_BACKGROUND_WORKERS": "true"}, clear=True):
            self.assertTrue(server._embedded_background_workers_enabled())


if __name__ == "__main__":
    unittest.main()
