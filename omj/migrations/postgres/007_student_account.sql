-- UTF-8 / PostgreSQL 15+
-- 코인은 PostgreSQL 원장만을 기준으로 한다. 사유 코드는 운영 사전의 SMALLINT 값만 저장한다.

CREATE TABLE IF NOT EXISTS student_account_stats (
    user_id TEXT PRIMARY KEY,
    total_points BIGINT NOT NULL DEFAULT 0 CHECK (total_points >= 0),
    activity_score BIGINT NOT NULL DEFAULT 0 CHECK (activity_score >= 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS student_daily_point_usage (
    user_id TEXT NOT NULL,
    date_key DATE NOT NULL,
    earned_points INTEGER NOT NULL DEFAULT 0 CHECK (earned_points >= 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, date_key)
);

CREATE TABLE IF NOT EXISTS student_point_ledger (
    id BIGSERIAL PRIMARY KEY,
    user_id TEXT NOT NULL,
    delta_points INTEGER NOT NULL CHECK (delta_points > 0),
    reason_code SMALLINT NOT NULL CHECK (reason_code IN (1, 2)),
    ref_id TEXT NOT NULL,
    source_date DATE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, reason_code, ref_id)
);

CREATE TABLE IF NOT EXISTS student_activity_score_ledger (
    id BIGSERIAL PRIMARY KEY,
    user_id TEXT NOT NULL,
    delta_score INTEGER NOT NULL CHECK (delta_score > 0),
    reason TEXT NOT NULL,
    ref_id TEXT NOT NULL,
    source_date DATE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, reason, ref_id)
);

CREATE INDEX IF NOT EXISTS idx_student_point_ledger_user_created
    ON student_point_ledger (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_student_activity_score_ledger_user_created
    ON student_activity_score_ledger (user_id, created_at DESC);
