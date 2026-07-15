-- UTF-8 / PostgreSQL 15+
-- 학생 레이팅, 태그별 레이팅, 중복 제출 결과를 PostgreSQL에 영속화한다.

CREATE TABLE IF NOT EXISTS user_rating (
    user_id TEXT PRIMARY KEY,
    rating DOUBLE PRECISION NOT NULL DEFAULT 1200,
    ovr DOUBLE PRECISION NOT NULL DEFAULT 1200,
    ovr_prev DOUBLE PRECISION NOT NULL DEFAULT 1200,
    lose_streak INTEGER NOT NULL DEFAULT 0 CHECK (lose_streak >= 0),
    last_attempt_at TIMESTAMPTZ,
    recent_results JSONB NOT NULL DEFAULT '[]'::jsonb,
    recent_index SMALLINT NOT NULL DEFAULT 0 CHECK (recent_index BETWEEN 0 AND 49),
    recent_count SMALLINT NOT NULL DEFAULT 0 CHECK (recent_count BETWEEN 0 AND 50),
    recent_sum SMALLINT NOT NULL DEFAULT 0 CHECK (recent_sum BETWEEN 0 AND 50),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_tag_rating (
    user_id TEXT NOT NULL REFERENCES user_rating(user_id) ON DELETE CASCADE,
    tag TEXT NOT NULL,
    attempts INTEGER NOT NULL DEFAULT 0 CHECK (attempts >= 0),
    rating DOUBLE PRECISION NOT NULL DEFAULT 1200,
    rating_prev DOUBLE PRECISION NOT NULL DEFAULT 1200,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, tag)
);

CREATE INDEX IF NOT EXISTS idx_user_tag_rating_rank
    ON user_tag_rating (user_id, rating DESC);

CREATE TABLE IF NOT EXISTS rating_submission (
    user_id TEXT NOT NULL,
    submission_id TEXT NOT NULL,
    quest_id TEXT NOT NULL,
    response JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, submission_id)
);

CREATE INDEX IF NOT EXISTS idx_rating_submission_created
    ON rating_submission (created_at);
