-- UTF-8 / PostgreSQL 15+
-- 마켓 구매와 학습 진행 상태를 사용자별로 멱등하게 저장한다.

CREATE TABLE IF NOT EXISTS marketplace_purchase (
    user_id TEXT NOT NULL,
    listing_id TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'in_progress'
        CHECK (status IN ('in_progress', 'completed')),
    progress_index INTEGER NOT NULL DEFAULT 0 CHECK (progress_index >= 0),
    purchased_price_points INTEGER NOT NULL DEFAULT 0 CHECK (purchased_price_points >= 0),
    purchased_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, listing_id)
);

CREATE INDEX IF NOT EXISTS idx_marketplace_purchase_user_updated
    ON marketplace_purchase (user_id, status, updated_at DESC);

-- 현재 운영 정책: 기존 공개 상품은 모두 무료로 구매할 수 있다.
UPDATE marketplace_listing
SET price_points = 0,
    updated_at = EXTRACT(EPOCH FROM NOW())::BIGINT
WHERE status = 'published';

ALTER TABLE student_point_ledger
    DROP CONSTRAINT IF EXISTS student_point_ledger_reason_code_check;
ALTER TABLE student_point_ledger
    ADD CONSTRAINT student_point_ledger_reason_code_check
    CHECK (reason_code IN (1, 2, 3));
