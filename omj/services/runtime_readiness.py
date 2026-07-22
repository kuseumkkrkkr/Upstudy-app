from __future__ import annotations

import os
from typing import Any

from services.problem_runtime_cache import problem_runtime_cache
from storage.postgres_level_test_store import postgres_level_test_store
from storage.postgres_problem_store import postgres_problem_store


def runtime_readiness() -> dict[str, Any]:
    """필요 변수: DATABASE_URL·PostgreSQL 전환 검증값·Redis 설정.
    작동 원리: PostgreSQL과 Redis 및 이관 감사가 모두 확인될 때만 준비 완료를 반환한다.
    """
    backend = os.getenv("PROBLEM_CACHE_BACKEND", "postgres").strip().lower() or "postgres"
    # 카나리 단일 인스턴스는 Redis 캐시와 과거 문제 이관 감사 없이도 핵심 API를 검증한다.
    canary_relaxed = os.getenv("CANARY_RELAXED_READINESS", "").strip().lower() in {
        "1",
        "true",
        "yes",
    }
    database_configured = bool(os.getenv("DATABASE_URL", "").strip())
    verified = os.getenv("PROBLEM_CACHE_VERIFIED", "").strip().lower() in {"1", "true", "yes"}
    postgres_ok = postgres_problem_store.ping() if database_configured else False
    redis_ok = problem_runtime_cache.ping() if database_configured else False
    # 감사 레코드는 배포 중 변하지 않으므로 프로세스별 30초 TTL을 사용해 readiness 폭주가 DB를 압박하지 않게 한다.
    audit_ok = postgres_problem_store.has_verified_migration() if database_configured else False
    level_test_ok = False
    if postgres_ok is True:
        try:
            postgres_level_test_store.require_ready()
            level_test_ok = True
        except Exception:
            level_test_ok = False
    if canary_relaxed:
        # 필요한 변수: Supabase PostgreSQL과 레벨 테스트 스키마.
        # 작동 원리: 임시 캐시 재시작을 허용하는 단일 카나리에서는 영속 DB 핵심 경로만 readiness로 본다.
        ready = database_configured and postgres_ok is True and level_test_ok is True
    else:
        ready = (
            backend == "postgres"
            and database_configured
            and verified
            and postgres_ok is True
            and redis_ok is True
            and audit_ok is True
            and level_test_ok is True
        )
    return {
        "ready": ready,
        "problem_cache_backend": backend,
        "database_configured": database_configured,
        "migration_verified": verified,
        "postgres": postgres_ok,
        "redis": redis_ok,
        "migration_audit": audit_ok,
        "level_test_postgres": level_test_ok,
        "canary_relaxed": canary_relaxed,
    }
