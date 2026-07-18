-- UTF-8 / PostgreSQL 15+
-- 시험지·문제세트·코스의 공개 마켓 목록을 하나의 인덱스된 원장에 저장한다.

CREATE TABLE IF NOT EXISTS marketplace_listing (
    id TEXT PRIMARY KEY,
    kind TEXT NOT NULL CHECK (kind IN ('exam', 'problem_set', 'course')),
    title TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    subject TEXT NOT NULL DEFAULT '수학',
    grade_band TEXT NOT NULL DEFAULT '',
    difficulty TEXT NOT NULL DEFAULT '',
    item_count INTEGER NOT NULL DEFAULT 0 CHECK (item_count >= 0),
    estimated_minutes INTEGER NOT NULL DEFAULT 0 CHECK (estimated_minutes >= 0),
    price_points INTEGER NOT NULL DEFAULT 0 CHECK (price_points >= 0),
    asset_id TEXT NOT NULL DEFAULT '',
    tags_json TEXT NOT NULL DEFAULT '[]',
    problem_ids_json TEXT NOT NULL DEFAULT '[]',
    payload_json TEXT NOT NULL DEFAULT '{}',
    status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'archived')),
    featured_rank INTEGER NOT NULL DEFAULT 0,
    created_at BIGINT NOT NULL DEFAULT (EXTRACT(EPOCH FROM NOW())::BIGINT),
    updated_at BIGINT NOT NULL DEFAULT (EXTRACT(EPOCH FROM NOW())::BIGINT)
);

CREATE INDEX IF NOT EXISTS idx_marketplace_listing_public
    ON marketplace_listing (status, kind, featured_rank DESC, updated_at DESC);

