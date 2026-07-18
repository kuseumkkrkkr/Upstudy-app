-- UTF-8 / PostgreSQL 15+
-- 사용자별 비정형 상태를 복합 키로 저장한다.

CREATE TABLE IF NOT EXISTS user_kv (
    user_id TEXT NOT NULL,
    key TEXT NOT NULL,
    value TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, key)
);

CREATE INDEX IF NOT EXISTS idx_user_kv_updated_at
    ON user_kv (updated_at DESC);
