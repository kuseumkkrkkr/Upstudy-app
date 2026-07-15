-- UTF-8 / PostgreSQL 15+
-- 문제 원본과 최근 풀이 이력을 영속화한다. Redis는 이 데이터의 단기 캐시·실시간 통계 계층이다.

CREATE TABLE IF NOT EXISTS problem_payload (
    quest_id TEXT PRIMARY KEY,
    codebase_id BIGINT,
    seed BIGINT,
    difficulty_tier SMALLINT NOT NULL CHECK (difficulty_tier BETWEEN 1 AND 5),
    difficulty_score INTEGER NOT NULL CHECK (difficulty_score >= 1),
    quality_status TEXT NOT NULL DEFAULT 'pending'
        CHECK (quality_status IN ('pending', 'approved', 'quarantined', 'rejected')),
    quality_reasons JSONB NOT NULL DEFAULT '[]'::jsonb,
    tags JSONB NOT NULL DEFAULT '[]'::jsonb,
    payload JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_problem_payload_difficulty
    ON problem_payload (difficulty_tier, quality_status, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_problem_payload_tags ON problem_payload USING GIN (tags);
CREATE INDEX IF NOT EXISTS idx_problem_payload_codebase_seed
    ON problem_payload (codebase_id, seed)
    WHERE codebase_id IS NOT NULL AND seed IS NOT NULL;

CREATE TABLE IF NOT EXISTS user_problem_history (
    user_id TEXT NOT NULL,
    codebase_id BIGINT NOT NULL,
    seed BIGINT NOT NULL,
    tags JSONB NOT NULL DEFAULT '[]'::jsonb,
    solved_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    solve_count INTEGER NOT NULL DEFAULT 1,
    PRIMARY KEY (user_id, codebase_id, seed)
);

CREATE INDEX IF NOT EXISTS idx_user_problem_history_recent
    ON user_problem_history (user_id, solved_at DESC);

CREATE TABLE IF NOT EXISTS problem_cache_migration_audit (
    id BIGSERIAL PRIMARY KEY,
    verified_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    source_count INTEGER NOT NULL,
    target_count INTEGER NOT NULL,
    source_digest TEXT NOT NULL,
    target_digest TEXT NOT NULL,
    tier_counts JSONB NOT NULL,
    report JSONB NOT NULL,
    CHECK (source_count = target_count),
    CHECK (source_digest = target_digest)
);
