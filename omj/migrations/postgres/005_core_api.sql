-- UTF-8 / PostgreSQL 15+
-- 인증·학원·코스 v2 운영 테이블을 PostgreSQL에 구성한다.

CREATE TABLE IF NOT EXISTS users (
    user_id TEXT PRIMARY KEY,
    username TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    grade TEXT NOT NULL,
    track TEXT,
    subject TEXT,
    school TEXT,
    profile_image TEXT,
    email TEXT,
    ovr INTEGER DEFAULT 0,
    status TEXT DEFAULT '',
    role TEXT DEFAULT 'student',
    password_hash TEXT NOT NULL,
    salt TEXT NOT NULL,
    created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS academy (
    academy_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    address TEXT,
    phone TEXT,
    admin_user_id TEXT,
    created_at TEXT,
    updated_at TEXT
);

CREATE TABLE IF NOT EXISTS academy_group (
    group_id TEXT PRIMARY KEY,
    academy_id TEXT NOT NULL,
    name TEXT NOT NULL,
    grade TEXT,
    subject TEXT,
    teacher_user_id TEXT,
    group_type TEXT NOT NULL DEFAULT 'academy_tutoring_group',
    searchable INTEGER NOT NULL DEFAULT 0,
    friend_verification_required INTEGER NOT NULL DEFAULT 1,
    max_members INTEGER NOT NULL DEFAULT 20,
    style_border_color TEXT,
    style_badge_text TEXT,
    schedule_json TEXT,
    timetable_plan_json TEXT,
    timetable_version TEXT,
    timetable_generated_at TEXT,
    created_at TEXT
);

CREATE TABLE IF NOT EXISTS academy_group_member (
    member_id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'student',
    joined_at TEXT,
    removed_at TEXT,
    status TEXT NOT NULL DEFAULT 'active'
);

CREATE TABLE IF NOT EXISTS member_event_log (
    event_id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    event_type TEXT NOT NULL,
    triggered_by_user_id TEXT,
    reason TEXT,
    created_at TEXT
);

CREATE TABLE IF NOT EXISTS attendance_log (
    log_id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    date TEXT NOT NULL,
    status TEXT NOT NULL,
    checked_by_user_id TEXT,
    checked_at TEXT,
    note TEXT
);

CREATE TABLE IF NOT EXISTS tuition_payment (
    payment_id TEXT PRIMARY KEY,
    academy_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    amount INTEGER NOT NULL,
    month_label TEXT NOT NULL,
    method TEXT,
    paid_at TEXT,
    receipt_url TEXT,
    memo TEXT
);

CREATE TABLE IF NOT EXISTS finance_ledger (
    ledger_id TEXT PRIMARY KEY,
    academy_id TEXT NOT NULL,
    category TEXT NOT NULL,
    amount INTEGER NOT NULL,
    description TEXT,
    transaction_date TEXT NOT NULL,
    recorded_by_user_id TEXT,
    created_at TEXT
);

CREATE TABLE IF NOT EXISTS parent_consult_note (
    note_id TEXT PRIMARY KEY,
    academy_id TEXT NOT NULL,
    student_user_id TEXT NOT NULL,
    parent_name TEXT,
    parent_contact TEXT,
    topic TEXT,
    content TEXT,
    consulted_by_user_id TEXT,
    consulted_at TEXT,
    follow_up_date TEXT
);

CREATE TABLE IF NOT EXISTS group_assignment (
    assignment_id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL,
    sender_user_id TEXT NOT NULL,
    kind TEXT NOT NULL,
    ref_id TEXT NOT NULL,
    title TEXT,
    message TEXT,
    due_date TEXT,
    created_at TEXT
);

CREATE TABLE IF NOT EXISTS group_submission (
    submission_id TEXT PRIMARY KEY,
    assignment_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    submitted_at TEXT,
    data_json TEXT
);

CREATE TABLE IF NOT EXISTS submission_report (
    report_id TEXT PRIMARY KEY,
    submission_id TEXT NOT NULL,
    correct_rate DOUBLE PRECISION,
    time_spent_seconds INTEGER,
    weak_tags_json TEXT,
    feedback TEXT,
    created_at TEXT
);

CREATE TABLE IF NOT EXISTS timetable_preference (
    preference_id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    day_of_week TEXT NOT NULL,
    time_slot TEXT NOT NULL,
    priority INTEGER NOT NULL DEFAULT 1,
    created_at TEXT
);

CREATE TABLE IF NOT EXISTS timetable_plan (
    plan_id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL,
    plan_json TEXT NOT NULL,
    version TEXT NOT NULL DEFAULT 'v1',
    generated_at TEXT,
    applied INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS student_overview_snapshot (
    snapshot_id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    academy_id TEXT NOT NULL,
    group_id TEXT,
    overall_score DOUBLE PRECISION,
    attendance_rate DOUBLE PRECISION,
    tuition_status TEXT,
    last_consult_note_id TEXT,
    summary_json TEXT,
    created_at TEXT
);

CREATE TABLE IF NOT EXISTS student_schedule_task (
    task_id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    date TEXT NOT NULL,
    title TEXT NOT NULL,
    source TEXT NOT NULL DEFAULT 'student',
    created_at TEXT,
    updated_at TEXT
);

CREATE TABLE IF NOT EXISTS course_v2 (
    id TEXT PRIMARY KEY,
    owner_user_id TEXT NOT NULL DEFAULT '',
    access_academy_id TEXT,
    access_group_id TEXT,
    title TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    difficulty TEXT NOT NULL DEFAULT '',
    duration TEXT NOT NULL DEFAULT '',
    tags TEXT NOT NULL DEFAULT '[]',
    focus_tags TEXT NOT NULL DEFAULT '[]',
    target_ovr INTEGER DEFAULT 0,
    textbook_id TEXT,
    textbook_pages INTEGER DEFAULT 0,
    is_demo INTEGER NOT NULL DEFAULT 0,
    is_public INTEGER NOT NULL DEFAULT 0,
    modules_json TEXT NOT NULL DEFAULT '[]',
    pass_policy_json TEXT,
    flow_policy_json TEXT,
    challenge_policy_json TEXT,
    schedule_policy_json TEXT,
    runtime_flags_json TEXT,
    curriculum_settings_json TEXT,
    challenge_settings_json TEXT,
    created_at BIGINT NOT NULL DEFAULT (EXTRACT(EPOCH FROM NOW())::BIGINT),
    updated_at BIGINT NOT NULL DEFAULT (EXTRACT(EPOCH FROM NOW())::BIGINT)
);

CREATE TABLE IF NOT EXISTS course_v2_runtime (
    user_id TEXT NOT NULL,
    course_id TEXT NOT NULL,
    state_json TEXT NOT NULL DEFAULT '{}',
    created_at BIGINT NOT NULL DEFAULT (EXTRACT(EPOCH FROM NOW())::BIGINT),
    updated_at BIGINT NOT NULL DEFAULT (EXTRACT(EPOCH FROM NOW())::BIGINT),
    PRIMARY KEY (user_id, course_id)
);

CREATE INDEX IF NOT EXISTS idx_academy_group_academy
    ON academy_group (academy_id);
CREATE INDEX IF NOT EXISTS idx_academy_group_member_group_status
    ON academy_group_member (group_id, status);
CREATE INDEX IF NOT EXISTS idx_attendance_group_date
    ON attendance_log (group_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_tuition_academy_month
    ON tuition_payment (academy_id, month_label);
CREATE INDEX IF NOT EXISTS idx_assignment_group_created
    ON group_assignment (group_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_schedule_user_date
    ON student_schedule_task (user_id, date);
CREATE INDEX IF NOT EXISTS idx_course_v2_visibility_updated
    ON course_v2 (is_public, updated_at DESC);
