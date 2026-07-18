"""검증된 sqlite_staging 코드베이스 데이터를 운영 PostgreSQL 테이블로 승격한다."""
from __future__ import annotations

import json
import os
from typing import Any


_TABLES = (
    "codebases",
    "codebase_seed_cache",
    "codebase_seed_stats",
    "codebase_seed_logs",
    "codebase_agent_logs",
    "codebase_quality_validation",
    "formula_seed_cache",
)


def promote() -> dict[str, int]:
    """필요 변수: 008 스키마와 검증 완료 스테이징 데이터.
    작동 원리: 운영 테이블이 비어 있을 때만 단일 트랜잭션으로 복사하고, 원본·대상 행 수가 다르면 전체를 되돌린다.
    """
    database_url = os.getenv("DATABASE_URL", "").strip()
    if not database_url:
        raise RuntimeError("DATABASE_URL is required")
    import psycopg

    with psycopg.connect(database_url) as conn, conn.transaction(), conn.cursor() as cur:
        for table in _TABLES:
            cur.execute(f"SELECT COUNT(*) FROM public.{table}")
            if int(cur.fetchone()[0]) != 0:
                raise RuntimeError(f"public.{table} is not empty; refusing to overwrite operational data")

        cur.execute("""INSERT INTO codebases (id,name,prompt,code,mode,tags,difficulty,tier,solves_count,strategy_level,branch_conditions,validated_seeds,tier_source,quality_status,quality_reasons,created_at)
            SELECT id,name,prompt,code,mode,COALESCE(NULLIF(tags,''),'[]')::jsonb,difficulty,tier,solves_count,strategy_level,branch_conditions,COALESCE(NULLIF(validated_seeds,''),'[]')::jsonb,tier_source,quality_status,COALESCE(NULLIF(quality_reasons,''),'[]')::jsonb,created_at::timestamptz
            FROM sqlite_staging.codebases__codebases""")
        cur.execute("""INSERT INTO codebase_seed_cache (id,codebase_id,code_hash,seed,created_at)
            SELECT id,codebase_id,code_hash,seed,created_at::timestamptz FROM sqlite_staging.codebases__codebase_seed_cache""")
        cur.execute("""INSERT INTO codebase_seed_stats (codebase_id,code_hash,attempts,successes,updated_at)
            SELECT codebase_id,code_hash,attempts,successes,updated_at::timestamptz FROM sqlite_staging.codebases__codebase_seed_stats""")
        cur.execute("""INSERT INTO codebase_seed_logs (id,codebase_id,code_hash,seed,status,error_type,error_message,stage,elapsed_ms,source,created_at)
            SELECT id,codebase_id,code_hash,seed,status,error_type,error_message,stage,elapsed_ms,source,created_at::timestamptz FROM sqlite_staging.codebases__codebase_seed_logs""")
        cur.execute("""INSERT INTO codebase_agent_logs (id,codebase_id,action,status,attempt,error_message,detail,created_at)
            SELECT id,codebase_id,action,status,attempt,error_message,COALESCE(NULLIF(detail,''),'{}')::jsonb,created_at::timestamptz FROM sqlite_staging.codebases__codebase_agent_logs""")
        cur.execute("""INSERT INTO codebase_quality_validation (codebase_id,code_hash,seed,status,reasons_json,checked_at)
            SELECT codebase_id,code_hash,seed,status,COALESCE(NULLIF(reasons_json,''),'[]')::jsonb,checked_at FROM sqlite_staging.codebases__codebase_quality_validation""")
        cur.execute("""INSERT INTO formula_seed_cache (id,signature,seed,params_json,answers_json,created_at)
            SELECT id,signature,seed,NULLIF(params_json,'')::jsonb,NULLIF(answers_json,'')::jsonb,created_at::timestamptz FROM sqlite_staging.codebases__formula_seed_cache""")
        for table in ("codebases", "codebase_seed_cache", "codebase_seed_logs", "codebase_agent_logs", "formula_seed_cache"):
            cur.execute(f"SELECT setval(pg_get_serial_sequence('public.{table}', 'id'), COALESCE((SELECT MAX(id) FROM public.{table}), 1), true)")

        report: dict[str, int] = {}
        for table in _TABLES:
            cur.execute(f"SELECT COUNT(*) FROM sqlite_staging.codebases__{table}")
            source_count = int(cur.fetchone()[0])
            cur.execute(f"SELECT COUNT(*) FROM public.{table}")
            target_count = int(cur.fetchone()[0])
            if source_count != target_count:
                raise RuntimeError(f"row count mismatch for {table}: {source_count} != {target_count}")
            report[table] = target_count
        cur.execute("CREATE TABLE IF NOT EXISTS codebase_migration_audit (id BIGSERIAL PRIMARY KEY, created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), report JSONB NOT NULL)")
        cur.execute("INSERT INTO codebase_migration_audit (report) VALUES (%s::jsonb)", (json.dumps(report),))
        return report


if __name__ == "__main__":
    print(promote())
