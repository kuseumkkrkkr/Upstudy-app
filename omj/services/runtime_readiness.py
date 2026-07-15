from __future__ import annotations

import os
import sqlite3
from typing import Any

from services.problem_runtime_cache import problem_runtime_cache
from storage import storage as sqlite_store
from storage.postgres_problem_store import postgres_problem_store


def _sqlite_ping() -> bool:
    """필요 변수: 현재 문제 SQLite 경로. 작동 원리: fallback 저장소가 실제로 열리고 읽히는지 최소 쿼리로 확인한다."""
    try:
        connection = sqlite_store._connect()
        try:
            row = connection.execute("SELECT 1").fetchone()
        finally:
            connection.close()
        return bool(row and int(row[0]) == 1)
    except (OSError, sqlite3.Error, ValueError):
        return False


def runtime_readiness() -> dict[str, Any]:
    """필요 변수: 저장소 전환 환경 변수. 작동 원리: SQLite fallback과 선택된 PostgreSQL·Redis의 실제 준비 여부를 배포 게이트로 계산한다."""
    backend = os.getenv("PROBLEM_CACHE_BACKEND", "sqlite").strip().lower() or "sqlite"
    wants_postgres = backend == "postgres"
    verified = os.getenv("PROBLEM_CACHE_VERIFIED", "").strip().lower() in {"1", "true", "yes"}
    sqlite_ok = _sqlite_ping()
    postgres_ok = postgres_problem_store.ping() if wants_postgres else None
    redis_ok = problem_runtime_cache.ping() if wants_postgres else None
    # 감사 레코드는 배포 중 변하지 않으므로 프로세스별 30초 TTL을 사용해 readiness 폭주가 DB를 압박하지 않게 한다.
    audit_ok = postgres_problem_store.has_verified_migration() if wants_postgres else None
    ready = sqlite_ok and (
        not wants_postgres
        or (verified and postgres_ok is True and redis_ok is True and audit_ok is True)
    )
    return {
        "ready": ready,
        "problem_cache_backend": backend,
        "sqlite_fallback": sqlite_ok,
        "migration_verified": verified if wants_postgres else None,
        "postgres": postgres_ok,
        "redis": redis_ok,
        "migration_audit": audit_ok,
    }
