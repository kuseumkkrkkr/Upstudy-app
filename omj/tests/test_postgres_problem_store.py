from __future__ import annotations

import os
import sys
import types
import unittest
from unittest.mock import patch

from scripts import migrate_problem_cache_to_postgres as migration
from services import runtime_readiness as readiness
from storage.postgres_problem_store import PostgresProblemStore


class _NoSlot:
    """필요 변수: 없음. 작동 원리: 포화된 이중 기록 큐처럼 모든 비차단 획득을 거부한다."""

    def acquire(self, blocking: bool = False) -> bool:
        return False


class _CaptureCursor:
    """필요 변수: 없음. 작동 원리: PostgreSQL 호출 인자를 보관해 품질 상태 저장값을 검증한다."""

    def __init__(self) -> None:
        self.params = None

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def execute(self, _sql, params=None) -> None:
        self.params = params


class _CaptureConnection:
    """필요 변수: 캡처 커서. 작동 원리: psycopg 연결의 최소 컨텍스트·commit 인터페이스를 제공한다."""

    def __init__(self, cursor: _CaptureCursor) -> None:
        self._cursor = cursor

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def cursor(self) -> _CaptureCursor:
        return self._cursor

    def commit(self) -> None:
        return None


class _CapturePool:
    """필요 변수: 캡처 연결. 작동 원리: 저장소가 요청하는 connection을 고정 반환한다."""

    def __init__(self, connection: _CaptureConnection) -> None:
        self._connection = connection

    def connection(self) -> _CaptureConnection:
        return self._connection


class _RowsCursor(_CaptureCursor):
    """필요 변수: 고정 PostgreSQL 행. 작동 원리: 캐시 선택 SQL마다 같은 후보를 반환해 Redis 선점 결과를 검증한다."""

    def __init__(self, rows, payloads=None) -> None:
        super().__init__()
        self._rows = rows
        self._payloads = payloads or {}
        self._payload_query = False

    def execute(self, sql, params=None) -> None:
        super().execute(sql, params)
        self._payload_query = "SELECT quest_id, payload FROM problem_payload" in str(sql)

    def fetchall(self):
        if self._payload_query:
            requested = self.params[0] if self.params else []
            return [(quest_id, self._payloads[quest_id]) for quest_id in requested if quest_id in self._payloads]
        return list(self._rows)


class PostgresProblemStoreTests(unittest.TestCase):
    """필요 변수: 환경 변수와 가짜 snapshot. 작동 원리: 실제 PostgreSQL 없이 전환 차단·엄격 실패·전 행 대조 계약을 검증한다."""

    def test_backend_requires_completed_verification_flag(self) -> None:
        """필요 변수: PostgreSQL 백엔드 설정. 작동 원리: 이관 검증 표식이 없으면 읽기 전환을 허용하지 않는다."""
        store = PostgresProblemStore()
        with patch.dict(
            os.environ,
            {"DATABASE_URL": "postgresql://example", "PROBLEM_CACHE_BACKEND": "postgres"},
            clear=True,
        ), patch.object(store, "has_verified_migration", return_value=True):
            self.assertFalse(store.is_cache_backend_enabled())
            os.environ["PROBLEM_CACHE_VERIFIED"] = "true"
            self.assertTrue(store.is_cache_backend_enabled())

    def test_strict_upsert_does_not_hide_connection_failure(self) -> None:
        """필요 변수: 연결 불가 저장소. 작동 원리: 런타임 이중 기록은 실패를 반환하고 이관 엄격 모드는 즉시 예외를 낸다."""
        store = PostgresProblemStore()
        with patch.object(store, "_get_pool", return_value=None):
            self.assertFalse(store.upsert_problem({}, strict=False))
            with self.assertRaises(RuntimeError):
                store.upsert_problem({}, strict=True)

    def test_connection_failure_uses_retry_circuit_breaker(self) -> None:
        """필요 변수: 반복되는 PostgreSQL 연결 실패. 작동 원리: 재시도 간격 안의 동시 요청이 연결 생성을 계속 반복하지 않게 한다."""
        attempts = []

        def failing_pool(**_kwargs):
            attempts.append(1)
            raise RuntimeError("offline")

        module = types.SimpleNamespace(ConnectionPool=failing_pool)
        store = PostgresProblemStore()
        with (
            patch.dict(
                os.environ,
                {"DATABASE_URL": "postgresql://offline", "POSTGRES_CONNECT_RETRY_SEC": "30"},
                clear=True,
            ),
            patch.dict(sys.modules, {"psycopg_pool": module}),
        ):
            self.assertIsNone(store._get_pool())
            self.assertIsNone(store._get_pool())
        self.assertEqual(len(attempts), 1)

    def test_pool_uses_configured_acquire_timeout(self) -> None:
        """필요 변수: 풀 획득 제한시간 환경 변수. 작동 원리: 자동 재시작 직후 연결 준비를 기다릴 설정이 풀 생성에 전달되는지 검증한다."""
        captured = {}

        class FakePool:
            def __init__(self, **kwargs):
                captured.update(kwargs)

        module = types.SimpleNamespace(ConnectionPool=FakePool)
        store = PostgresProblemStore()
        with (
            patch.dict(
                os.environ,
                {
                    "DATABASE_URL": "postgresql://example",
                    "POSTGRES_POOL_ACQUIRE_TIMEOUT_SEC": "7.5",
                },
                clear=True,
            ),
            patch.dict(sys.modules, {"psycopg_pool": module}),
        ):
            self.assertIsNotNone(store._get_pool())
        self.assertEqual(captured["timeout"], 7.5)

    def test_bounded_dual_write_queue_rejects_overflow(self) -> None:
        """필요 변수: 포화 큐. 작동 원리: DB 지연 시 작업을 무한 적재하지 않고 SQLite 성공 경로를 보존한다."""
        store = PostgresProblemStore()
        store._write_slots = _NoSlot()
        self.assertFalse(store._submit_bounded(lambda: None))

    def test_content_failure_overrides_claimed_approved_status(self) -> None:
        """필요 변수: 승인 표시가 있지만 본문 계약을 위반한 문제. 작동 원리: PostgreSQL에 승인으로 복제되지 않게 재검수 결과를 우선한다."""
        cursor = _CaptureCursor()
        pool = _CapturePool(_CaptureConnection(cursor))
        quest = {
            "header": {"quest_id": "bad-approved"},
            "info": {
                "difficulty": 11,
                "difficulty_score": 11,
                "difficulty_tier": 1,
                "quality_status": "approved",
                "hash_tag": ["#지수법칙"],
            },
            "data": {"quest_title": "짧음", "quest_answer": "2", "codebase_id": 1, "seed": 1},
            "solves": [
                {
                    "flow": f"계산 단계 {index}",
                    "hint_riddle": "식을 정리합니다.",
                    "answer_riddle": "계산을 마칩니다.",
                    "branches": [],
                }
                for index in range(2)
            ],
        }
        store = PostgresProblemStore()
        with patch.object(store, "_get_pool", return_value=pool):
            self.assertTrue(store.upsert_problem(quest, strict=True))
        self.assertEqual(cursor.params[5], "rejected")

    def test_migration_verification_compares_every_approved_row(self) -> None:
        """필요 변수: 동일한 SQLite·PostgreSQL snapshot. 작동 원리: ID·티어·점수와 payload 자체 표식이 모두 같아야 승인한다."""
        payload = {
            "header": {"quest_id": "q-1"},
            "info": {"difficulty_tier": 4, "difficulty_score": 29},
        }
        with (
            patch.object(migration, "_source_snapshot", return_value={"q-1": (4, 29)}),
            patch.object(
                migration.postgres_problem_store,
                "approved_problem_snapshot",
                return_value={"q-1": (4, 29, payload)},
            ),
            patch.object(migration, "_problem_history", return_value=[]),
            patch.object(migration.postgres_problem_store, "problem_history_keys", return_value=set()),
        ):
            report = migration.verify_migration()
        self.assertTrue(report["verified"])
        self.assertEqual(report["source_approved"], 1)

    def test_postgres_selection_requires_atomic_redis_variant_claim(self) -> None:
        """필요 변수: 두 요청에서 반복 조회되는 동일 PostgreSQL 후보. 작동 원리: Redis 선점을 얻은 첫 요청만 학생에게 반환한다."""
        payload = {
            "header": {"quest_id": "q-1"},
            "info": {"difficulty_tier": 2, "difficulty_score": 15},
            "data": {"codebase_id": 7, "seed": 101},
        }
        cursor = _RowsCursor([("q-1", 7, 101, 1)], {"q-1": payload})
        pool = _CapturePool(_CaptureConnection(cursor))
        store = PostgresProblemStore()
        from services.problem_runtime_cache import problem_runtime_cache

        with (
            patch.object(store, "is_cache_backend_enabled", return_value=True),
            patch.object(store, "_get_pool", return_value=pool),
            patch.object(problem_runtime_cache, "take_prefetched", return_value=[]),
            patch.object(problem_runtime_cache, "load_payloads", return_value={}),
            patch.object(problem_runtime_cache, "list_claimed_variants", return_value=set()),
            patch.object(problem_runtime_cache, "cache_payloads"),
            patch.object(problem_runtime_cache, "reserve_prefetch"),
            patch.object(
                problem_runtime_cache,
                "claim_unserved_variant",
                side_effect=[True, False, False, False],
            ),
        ):
            first, _ = store.claim_cached_quests(
                user_id="student",
                hash_tags=["#포물선"],
                min_difficulty_tier=2,
                max_difficulty_tier=2,
                question_count=1,
                prefetch_count=0,
            )
            second, _ = store.claim_cached_quests(
                user_id="student",
                hash_tags=["#포물선"],
                min_difficulty_tier=2,
                max_difficulty_tier=2,
                question_count=1,
                prefetch_count=0,
            )
        self.assertEqual([quest["header"]["quest_id"] for quest in first], ["q-1"])
        self.assertEqual(second, [])

    def test_migration_verification_rejects_missing_row(self) -> None:
        """필요 변수: PostgreSQL에서 누락된 승인 행. 작동 원리: 일부 성공을 전체 성공으로 출력하지 못하게 한다."""
        with (
            patch.object(migration, "_source_snapshot", return_value={"q-1": (2, 15)}),
            patch.object(
                migration.postgres_problem_store,
                "approved_problem_snapshot",
                return_value={},
            ),
            patch.object(migration, "_problem_history", return_value=[]),
            patch.object(migration.postgres_problem_store, "problem_history_keys", return_value=set()),
        ):
            with self.assertRaises(RuntimeError):
                migration.verify_migration()

    def test_migration_verification_rejects_missing_history(self) -> None:
        """필요 변수: payload는 같지만 풀이 이력이 누락된 대상. 작동 원리: 사용자 중복 제외 데이터 손실도 전환 실패로 판정한다."""
        payload = {
            "header": {"quest_id": "q-1"},
            "info": {"difficulty_tier": 1, "difficulty_score": 11},
        }
        with (
            patch.object(migration, "_source_snapshot", return_value={"q-1": (1, 11)}),
            patch.object(
                migration.postgres_problem_store,
                "approved_problem_snapshot",
                return_value={"q-1": (1, 11, payload)},
            ),
            patch.object(
                migration,
                "_problem_history",
                return_value=[("student", 1, "7", ["#지수법칙"])],
            ),
            patch.object(migration.postgres_problem_store, "problem_history_keys", return_value=set()),
        ):
            with self.assertRaises(RuntimeError):
                migration.verify_migration()

    def test_postgres_readiness_requires_verified_database_and_redis(self) -> None:
        """필요 변수: PostgreSQL 운영 모드와 세 저장소 상태. 작동 원리: 이관 표식 또는 Redis가 없으면 배포 준비 상태를 거부한다."""
        environment = {
            "DATABASE_URL": "postgresql://example.invalid/omj",
            "PROBLEM_CACHE_BACKEND": "postgres",
            "PROBLEM_CACHE_VERIFIED": "false",
        }
        with (
            patch.dict(os.environ, environment, clear=True),
            patch.object(readiness.postgres_problem_store, "ping", return_value=True),
            patch.object(readiness.postgres_problem_store, "has_verified_migration", return_value=True),
            patch.object(readiness.problem_runtime_cache, "ping", return_value=True),
        ):
            self.assertFalse(readiness.runtime_readiness()["ready"])
            os.environ["PROBLEM_CACHE_VERIFIED"] = "true"
            self.assertTrue(readiness.runtime_readiness()["ready"])
            with patch.object(readiness.problem_runtime_cache, "ping", return_value=False):
                self.assertFalse(readiness.runtime_readiness()["ready"])
            with patch.object(readiness.postgres_problem_store, "has_verified_migration", return_value=False):
                self.assertFalse(readiness.runtime_readiness()["ready"])


if __name__ == "__main__":
    unittest.main()
