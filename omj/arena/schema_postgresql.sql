-- UTF-8 PostgreSQL 대결장 영구 저장 스키마
CREATE TABLE IF NOT EXISTS arena_rating (
    user_id TEXT NOT NULL,
    queue_type TEXT NOT NULL CHECK (queue_type IN ('duel_exam','duel_ox','team_exam','team_ox')),
    rating DOUBLE PRECISION NOT NULL DEFAULT 1500,
    deviation DOUBLE PRECISION NOT NULL DEFAULT 350,
    volatility DOUBLE PRECISION NOT NULL DEFAULT 0.06,
    mu DOUBLE PRECISION NOT NULL DEFAULT 25,
    sigma DOUBLE PRECISION NOT NULL DEFAULT 8.333333,
    wins INTEGER NOT NULL DEFAULT 0,
    losses INTEGER NOT NULL DEFAULT 0,
    draws INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, queue_type)
);

CREATE TABLE IF NOT EXISTS arena_match (
    match_id UUID PRIMARY KEY,
    queue_type TEXT NOT NULL,
    status TEXT NOT NULL,
    started_at TIMESTAMPTZ NOT NULL,
    finished_at TIMESTAMPTZ,
    winner_team SMALLINT,
    idempotency_key TEXT UNIQUE NOT NULL,
    result_json JSONB
);

ALTER TABLE arena_match ADD COLUMN IF NOT EXISTS result_json JSONB;

CREATE TABLE IF NOT EXISTS arena_participant (
    match_id UUID NOT NULL REFERENCES arena_match(match_id),
    user_id TEXT NOT NULL,
    team SMALLINT NOT NULL,
    contribution DOUBLE PRECISION NOT NULL DEFAULT 0,
    rating_before DOUBLE PRECISION NOT NULL,
    rating_after DOUBLE PRECISION,
    PRIMARY KEY (match_id, user_id)
);

CREATE TABLE IF NOT EXISTS arena_match_question (
    match_id UUID NOT NULL REFERENCES arena_match(match_id),
    position SMALLINT NOT NULL,
    question_id TEXT NOT NULL,
    answer_type TEXT NOT NULL,
    difficulty DOUBLE PRECISION NOT NULL,
    payload JSONB NOT NULL,
    PRIMARY KEY (match_id, position)
);

CREATE TABLE IF NOT EXISTS arena_submission (
    submission_id UUID PRIMARY KEY,
    match_id UUID NOT NULL REFERENCES arena_match(match_id),
    user_id TEXT NOT NULL,
    team SMALLINT NOT NULL,
    question_id TEXT NOT NULL,
    submitted_answer TEXT NOT NULL,
    correct BOOLEAN NOT NULL,
    attempt_number SMALLINT NOT NULL,
    elapsed_ms INTEGER NOT NULL,
    idempotency_key TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, idempotency_key)
);

CREATE TABLE IF NOT EXISTS arena_tag_xp_ledger (
    ledger_id UUID PRIMARY KEY,
    match_id UUID NOT NULL REFERENCES arena_match(match_id),
    user_id TEXT NOT NULL,
    question_id TEXT NOT NULL,
    tag TEXT NOT NULL,
    amount DOUBLE PRECISION NOT NULL,
    reason TEXT NOT NULL,
    idempotency_key TEXT UNIQUE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS arena_match_user_idx ON arena_participant (user_id, match_id);
CREATE INDEX IF NOT EXISTS arena_submission_match_idx ON arena_submission (match_id, question_id, team);
CREATE INDEX IF NOT EXISTS arena_xp_user_idx ON arena_tag_xp_ledger (user_id, created_at DESC);
