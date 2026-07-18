-- UTF-8 / PostgreSQL 15+
-- Placement 레벨테스트의 폼·문항 배정·세션·답안을 PostgreSQL에 저장한다.

CREATE TABLE IF NOT EXISTS level_test_template (
    template_id TEXT PRIMARY KEY,
    version TEXT NOT NULL,
    form_index SMALLINT NOT NULL UNIQUE,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS level_test_template_item (
    template_id TEXT NOT NULL REFERENCES level_test_template(template_id),
    item_index SMALLINT NOT NULL CHECK (item_index BETWEEN 1 AND 50),
    phase SMALLINT NOT NULL,
    subject_key TEXT NOT NULL,
    hash_tags JSONB NOT NULL DEFAULT '[]'::jsonb,
    difficulty_tier SMALLINT NOT NULL CHECK (difficulty_tier BETWEEN 1 AND 5),
    quest_id TEXT NOT NULL REFERENCES problem_payload(quest_id),
    problem_rating DOUBLE PRECISION NOT NULL,
    PRIMARY KEY (template_id, item_index),
    UNIQUE (template_id, quest_id)
);

CREATE INDEX IF NOT EXISTS idx_level_test_template_item_quest
    ON level_test_template_item (quest_id);

CREATE TABLE IF NOT EXISTS level_test_session (
    session_id UUID PRIMARY KEY,
    user_id TEXT NOT NULL,
    template_id TEXT NOT NULL REFERENCES level_test_template(template_id),
    status TEXT NOT NULL CHECK (status IN ('started', 'graded')),
    estimated_rating DOUBLE PRECISION,
    estimated_ovr DOUBLE PRECISION,
    confidence DOUBLE PRECISION,
    strong_tags JSONB NOT NULL DEFAULT '[]'::jsonb,
    weak_tags JSONB NOT NULL DEFAULT '[]'::jsonb,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    submitted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_level_test_session_user_started
    ON level_test_session (user_id, started_at DESC);

CREATE TABLE IF NOT EXISTS level_test_answer (
    session_id UUID NOT NULL REFERENCES level_test_session(session_id) ON DELETE CASCADE,
    item_index SMALLINT NOT NULL CHECK (item_index BETWEEN 1 AND 50),
    quest_id TEXT NOT NULL,
    is_correct BOOLEAN NOT NULL,
    answer_time DOUBLE PRECISION,
    step_correctness JSONB NOT NULL DEFAULT '[]'::jsonb,
    tags JSONB NOT NULL DEFAULT '[]'::jsonb,
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (session_id, item_index)
);

CREATE TABLE IF NOT EXISTS level_test_result (
    user_id TEXT PRIMARY KEY,
    overall_speed DOUBLE PRECISION NOT NULL DEFAULT 0,
    overall_power DOUBLE PRECISION NOT NULL DEFAULT 0,
    topic_breakdown JSONB NOT NULL DEFAULT '{}'::jsonb,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
