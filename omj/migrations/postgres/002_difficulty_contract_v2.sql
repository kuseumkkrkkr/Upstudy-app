-- UTF-8 / PostgreSQL 15+
-- 기존 계산 점수와 학생용 티어를 분리하고 검수 통과 문제만 캐시 후보가 되게 한다.

ALTER TABLE problem_payload
    ADD COLUMN IF NOT EXISTS difficulty_score INTEGER;
ALTER TABLE problem_payload
    ADD COLUMN IF NOT EXISTS quality_status TEXT NOT NULL DEFAULT 'pending';
ALTER TABLE problem_payload
    ADD COLUMN IF NOT EXISTS quality_reasons JSONB NOT NULL DEFAULT '[]'::jsonb;

UPDATE problem_payload
SET difficulty_score = GREATEST(
    1,
    COALESCE((payload->'info'->>'difficulty_score')::INTEGER, difficulty_tier)
)
WHERE difficulty_score IS NULL;

ALTER TABLE problem_payload
    ALTER COLUMN difficulty_score SET NOT NULL;

ALTER TABLE problem_payload
    DROP CONSTRAINT IF EXISTS problem_payload_difficulty_score_check;
ALTER TABLE problem_payload
    ADD CONSTRAINT problem_payload_difficulty_score_check CHECK (difficulty_score >= 1);

ALTER TABLE problem_payload
    DROP CONSTRAINT IF EXISTS problem_payload_quality_status_check;
ALTER TABLE problem_payload
    ADD CONSTRAINT problem_payload_quality_status_check
    CHECK (quality_status IN ('pending', 'approved', 'quarantined', 'rejected'));

DROP INDEX IF EXISTS idx_problem_payload_difficulty;
CREATE INDEX idx_problem_payload_difficulty
    ON problem_payload (difficulty_tier, quality_status, updated_at DESC);

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
