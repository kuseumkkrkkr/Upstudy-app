-- UTF-8 / PostgreSQL 15+
-- AIFlow S11 canary 데모 기능. 실제 학원·과외 전송과 결제는 하지 않는다.

CREATE TABLE IF NOT EXISTS student_school_exam_plan (
    user_id TEXT PRIMARY KEY,
    school TEXT NOT NULL,
    exam_name TEXT NOT NULL,
    exam_date DATE NOT NULL,
    exam_id TEXT,
    version INTEGER NOT NULL DEFAULT 1 CHECK (version > 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS student_school_exam_task (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    exam_id TEXT NOT NULL,
    title TEXT NOT NULL,
    completed BOOLEAN NOT NULL DEFAULT FALSE,
    version INTEGER NOT NULL DEFAULT 1 CHECK (version > 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, exam_id, title)
);

CREATE OR REPLACE FUNCTION upsert_student_school_exam_plan(
    p_user_id TEXT,
    p_school TEXT,
    p_exam_name TEXT,
    p_exam_date DATE,
    p_exam_id TEXT,
    p_expected_version INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    current_plan student_school_exam_plan%ROWTYPE;
    next_version INTEGER;
BEGIN
    SELECT * INTO current_plan
    FROM student_school_exam_plan
    WHERE user_id = p_user_id
    FOR UPDATE;
    IF FOUND AND current_plan.version <> p_expected_version THEN
        RETURN jsonb_build_object('status', 'conflict', 'version', current_plan.version);
    END IF;
    next_version := COALESCE(current_plan.version, 0) + 1;
    INSERT INTO student_school_exam_plan (user_id, school, exam_name, exam_date, exam_id, version, updated_at)
    VALUES (p_user_id, p_school, p_exam_name, p_exam_date, p_exam_id, next_version, NOW())
    ON CONFLICT (user_id) DO UPDATE SET
        school = EXCLUDED.school,
        exam_name = EXCLUDED.exam_name,
        exam_date = EXCLUDED.exam_date,
        exam_id = EXCLUDED.exam_id,
        version = EXCLUDED.version,
        updated_at = NOW();
    RETURN jsonb_build_object(
        'status', 'saved', 'school', p_school, 'exam_name', p_exam_name,
        'exam_date', p_exam_date, 'exam_id', p_exam_id, 'version', next_version
    );
END;
$$;

CREATE INDEX IF NOT EXISTS idx_student_school_exam_task_user
    ON student_school_exam_task (user_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS demo_student_wallet (
    user_id TEXT PRIMARY KEY,
    balance_points BIGINT NOT NULL DEFAULT 12840 CHECK (balance_points >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS demo_store_item (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    cost_points INTEGER NOT NULL CHECK (cost_points >= 0),
    kind TEXT NOT NULL CHECK (kind IN ('point_reward')),
    active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0
);

INSERT INTO demo_store_item (id, name, cost_points, kind, sort_order)
VALUES
    ('background-01', '풀이 배경 01', 1200, 'point_reward', 1),
    ('timer-theme', '집중 타이머 테마', 800, 'point_reward', 2),
    ('profile-badge', '프로필 배지', 2000, 'point_reward', 3),
    ('review-ticket', '오답 복습권', 600, 'point_reward', 4)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    cost_points = EXCLUDED.cost_points,
    kind = EXCLUDED.kind,
    sort_order = EXCLUDED.sort_order;

CREATE TABLE IF NOT EXISTS demo_store_order (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    item_id TEXT NOT NULL REFERENCES demo_store_item(id),
    idempotency_key TEXT NOT NULL,
    request_hash TEXT NOT NULL,
    cost_points INTEGER NOT NULL CHECK (cost_points >= 0),
    status TEXT NOT NULL CHECK (status IN ('completed', 'duplicate', 'insufficient')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, idempotency_key)
);

CREATE TABLE IF NOT EXISTS demo_store_entitlement (
    user_id TEXT NOT NULL,
    item_id TEXT NOT NULL REFERENCES demo_store_item(id),
    order_id UUID NOT NULL REFERENCES demo_store_order(id),
    granted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, item_id)
);

CREATE TABLE IF NOT EXISTS demo_store_ledger (
    id BIGSERIAL PRIMARY KEY,
    user_id TEXT NOT NULL,
    order_id UUID NOT NULL UNIQUE REFERENCES demo_store_order(id),
    delta_points INTEGER NOT NULL CHECK (delta_points < 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION demo_redeem_student_store(
    p_user_id TEXT,
    p_item_id TEXT,
    p_idempotency_key TEXT,
    p_request_hash TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    wallet demo_student_wallet%ROWTYPE;
    item demo_store_item%ROWTYPE;
    prior demo_store_order%ROWTYPE;
    order_row demo_store_order%ROWTYPE;
    owned BOOLEAN;
BEGIN
    INSERT INTO demo_student_wallet (user_id)
    VALUES (p_user_id)
    ON CONFLICT (user_id) DO NOTHING;
    SELECT * INTO wallet FROM demo_student_wallet WHERE user_id = p_user_id FOR UPDATE;

    SELECT * INTO item FROM demo_store_item WHERE id = p_item_id AND active;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('status', 'not_found');
    END IF;

    SELECT * INTO prior
    FROM demo_store_order
    WHERE user_id = p_user_id AND idempotency_key = p_idempotency_key
    FOR UPDATE;
    IF FOUND THEN
        IF prior.request_hash <> p_request_hash THEN
            RETURN jsonb_build_object('status', 'conflict', 'order_id', prior.id);
        END IF;
        RETURN jsonb_build_object(
            'status', prior.status,
            'order_id', prior.id,
            'item_id', prior.item_id,
            'points', wallet.balance_points,
            'already_processed', TRUE
        );
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM demo_store_entitlement
        WHERE user_id = p_user_id AND item_id = p_item_id
    ) INTO owned;
    IF owned THEN
        INSERT INTO demo_store_order (user_id, item_id, idempotency_key, request_hash, cost_points, status)
        VALUES (p_user_id, p_item_id, p_idempotency_key, p_request_hash, item.cost_points, 'duplicate')
        RETURNING * INTO order_row;
        RETURN jsonb_build_object(
            'status', 'duplicate', 'order_id', order_row.id, 'item_id', p_item_id,
            'points', wallet.balance_points, 'already_owned', TRUE
        );
    END IF;

    IF wallet.balance_points < item.cost_points THEN
        INSERT INTO demo_store_order (user_id, item_id, idempotency_key, request_hash, cost_points, status)
        VALUES (p_user_id, p_item_id, p_idempotency_key, p_request_hash, item.cost_points, 'insufficient')
        RETURNING * INTO order_row;
        RETURN jsonb_build_object(
            'status', 'insufficient', 'order_id', order_row.id, 'item_id', p_item_id,
            'points', wallet.balance_points
        );
    END IF;

    INSERT INTO demo_store_order (user_id, item_id, idempotency_key, request_hash, cost_points, status)
    VALUES (p_user_id, p_item_id, p_idempotency_key, p_request_hash, item.cost_points, 'completed')
    RETURNING * INTO order_row;
    UPDATE demo_student_wallet
    SET balance_points = balance_points - item.cost_points, updated_at = NOW()
    WHERE user_id = p_user_id
    RETURNING * INTO wallet;
    INSERT INTO demo_store_ledger (user_id, order_id, delta_points)
    VALUES (p_user_id, order_row.id, -item.cost_points);
    INSERT INTO demo_store_entitlement (user_id, item_id, order_id)
    VALUES (p_user_id, p_item_id, order_row.id);
    RETURN jsonb_build_object(
        'status', 'completed', 'order_id', order_row.id, 'item_id', p_item_id,
        'points', wallet.balance_points, 'already_processed', FALSE
    );
END;
$$;

CREATE OR REPLACE FUNCTION demo_student_store_snapshot(p_user_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    points BIGINT;
BEGIN
    INSERT INTO demo_student_wallet (user_id)
    VALUES (p_user_id)
    ON CONFLICT (user_id) DO NOTHING;
    SELECT balance_points INTO points FROM demo_student_wallet WHERE user_id = p_user_id;
    RETURN jsonb_build_object(
        'points', points,
        'items', COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                'id', item.id,
                'name', item.name,
                'cost_points', item.cost_points,
                'owned', EXISTS (
                    SELECT 1 FROM demo_store_entitlement entitlement
                    WHERE entitlement.user_id = p_user_id AND entitlement.item_id = item.id
                )
            ) ORDER BY item.sort_order)
            FROM demo_store_item item WHERE item.active
        ), '[]'::jsonb)
    );
END;
$$;

REVOKE ALL ON FUNCTION demo_redeem_student_store(TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION demo_student_store_snapshot(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION demo_redeem_student_store(TEXT, TEXT, TEXT, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION demo_student_store_snapshot(TEXT) TO service_role;
REVOKE ALL ON FUNCTION upsert_student_school_exam_plan(TEXT, TEXT, TEXT, DATE, TEXT, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION upsert_student_school_exam_plan(TEXT, TEXT, TEXT, DATE, TEXT, INTEGER) TO service_role;
