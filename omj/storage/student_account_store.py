"""PostgreSQL 학생 코인·경험치 원장 저장소."""
from __future__ import annotations

import math
from datetime import date
from typing import Any, Dict, Optional

from psycopg.rows import dict_row

from storage.postgres_problem_store import postgres_problem_store


DAILY_POINT_LIMIT = 100
DAILY_QUEST_REWARD_POINTS = 20
ACTIVITY_DISPLAY_DAILY_CAP = 2000
MAX_ACCOUNT_LEVEL = 256
LEVEL_MILESTONE_INTERVAL = 5
LEVEL_MILESTONE_BASE_COINS = 10
COIN_REASON_LEVEL_MILESTONE = 1
COIN_REASON_DAILY_QUEST = 2
COIN_REASON_CATALOG = {
    COIN_REASON_LEVEL_MILESTONE: {"label": "레벨 마일스톤", "amount_rule": "레벨 5단위별 10 * 그룹"},
    COIN_REASON_DAILY_QUEST: {"label": "일일 퀘스트", "amount_rule": "서버 퀘스트 템플릿 보상"},
}


def today_key() -> str:
    """필요 변수: 서버 날짜. 작동 원리: 지급 한도와 원장 기준일을 서버 UTC 날짜로 고정한다."""
    return date.today().isoformat()


def level_for_activity_score(activity_score: int) -> int:
    """필요 변수: 누적 경험치. 작동 원리: 기존 제곱 증가식을 적용하되 정책 최대 레벨을 넘기지 않는다."""
    return min(MAX_ACCOUNT_LEVEL, int(math.sqrt(max(0, int(activity_score or 0)) / 100)) + 1)


def required_activity_score_for_level(level: int) -> int:
    """필요 변수: 레벨. 작동 원리: 레벨별 누적 경험치 기준을 기존 정책 식으로 계산한다."""
    safe_level = min(MAX_ACCOUNT_LEVEL, max(1, int(level or 1)))
    return (safe_level - 1) * (safe_level - 1) * 100


def coins_for_level_milestone(level: int) -> int:
    """필요 변수: 5의 배수 레벨. 작동 원리: 레벨 그룹에 비례한 고정 정책 코인을 계산한다."""
    group = max(1, min(MAX_ACCOUNT_LEVEL // LEVEL_MILESTONE_INTERVAL, level // LEVEL_MILESTONE_INTERVAL))
    return LEVEL_MILESTONE_BASE_COINS * group


def _pool() -> Any:
    """필요 변수: DATABASE_URL·공유 풀. 작동 원리: 코인 경로에 SQLite 대체 경로를 두지 않고 미설정 시 즉시 실패한다."""
    return postgres_problem_store.get_pool()


def init_student_account_db() -> None:
    """필요 변수: 007 PostgreSQL 마이그레이션. 작동 원리: 모든 지급 테이블 존재를 확인해 부분 배포를 시작 시 차단한다."""
    with _pool().connection() as conn, conn.cursor() as cur:
        cur.execute(
            """SELECT COUNT(*) FROM pg_tables WHERE schemaname = 'public'
               AND tablename = ANY(%s)""",
            (["student_account_stats", "student_daily_point_usage", "student_point_ledger", "student_activity_score_ledger"],),
        )
        if int(cur.fetchone()[0]) != 4:
            raise RuntimeError("PostgreSQL migration 007_student_account.sql is not applied")


def _ensure_rows(cur: Any, user_id: str, day: str) -> None:
    """필요 변수: 잠금 트랜잭션·사용자·기준일. 작동 원리: 잔액과 당일 한도 행을 UPSERT해 이후 행 잠금 대상을 보장한다."""
    cur.execute("INSERT INTO student_account_stats (user_id) VALUES (%s) ON CONFLICT DO NOTHING", (user_id,))
    cur.execute(
        """INSERT INTO student_daily_point_usage (user_id, date_key)
           VALUES (%s, %s::date) ON CONFLICT DO NOTHING""",
        (user_id, day),
    )


def _summary_from_cursor(cur: Any, user_id: str, day: str) -> Dict[str, Any]:
    """필요 변수: 같은 트랜잭션 커서·사용자·기준일. 작동 원리: 잔액과 일일 한도를 일관된 스냅샷으로 반환한다."""
    _ensure_rows(cur, user_id, day)
    cur.execute("SELECT total_points, activity_score FROM student_account_stats WHERE user_id = %s", (user_id,))
    stats = cur.fetchone() or {"total_points": 0, "activity_score": 0}
    cur.execute("SELECT earned_points FROM student_daily_point_usage WHERE user_id = %s AND date_key = %s::date", (user_id, day))
    usage = cur.fetchone() or {"earned_points": 0}
    total_points, activity_score = int(stats["total_points"]), int(stats["activity_score"])
    today_points = int(usage["earned_points"])
    level = level_for_activity_score(activity_score)
    current_level_score = required_activity_score_for_level(level)
    next_level_score = required_activity_score_for_level(level + 1)
    span = max(1, next_level_score - current_level_score)
    return {
        "user_id": user_id, "total_points": total_points, "activity_score": activity_score,
        "level": level, "current_level_score": current_level_score, "next_level_score": next_level_score,
        "level_progress": round(max(0.0, min(1.0, (activity_score - current_level_score) / span)), 4),
        "daily_points": today_points, "daily_point_limit": DAILY_POINT_LIMIT,
        "daily_points_remaining": max(0, DAILY_POINT_LIMIT - today_points),
        "activity_display_daily_cap": ACTIVITY_DISPLAY_DAILY_CAP, "max_level": MAX_ACCOUNT_LEVEL,
    }


def get_account_summary(user_id: str, *, date_key: Optional[str] = None) -> Dict[str, Any]:
    """필요 변수: 사용자·선택 기준일. 작동 원리: PostgreSQL 풀의 읽기 트랜잭션에서 계정 요약을 만든다."""
    init_student_account_db()
    with _pool().connection() as conn, conn.cursor(row_factory=dict_row) as cur:
        summary = _summary_from_cursor(cur, user_id, date_key or today_key())
        conn.commit()
        return summary


def _grant_level_milestones(cur: Any, user_id: str, previous_level: int, current_level: int) -> int:
    """필요 변수: 사용자 잠금 트랜잭션·전후 레벨. 작동 원리: 원장 UNIQUE와 INSERT ON CONFLICT로 모든 재시도·다중 프로세스 요청을 한 번만 지급한다."""
    granted = 0
    first = ((previous_level // LEVEL_MILESTONE_INTERVAL) + 1) * LEVEL_MILESTONE_INTERVAL
    for level in range(first, min(current_level, MAX_ACCOUNT_LEVEL) + 1, LEVEL_MILESTONE_INTERVAL):
        coins = coins_for_level_milestone(level)
        cur.execute(
            """INSERT INTO student_point_ledger (user_id, delta_points, reason_code, ref_id, source_date)
               VALUES (%s, %s, %s, %s, CURRENT_DATE)
               ON CONFLICT (user_id, reason_code, ref_id) DO NOTHING RETURNING delta_points""",
            (user_id, coins, COIN_REASON_LEVEL_MILESTONE, f"level:{level}"),
        )
        row = cur.fetchone()
        granted += int(row["delta_points"]) if row else 0
    if granted:
        cur.execute("UPDATE student_account_stats SET total_points = total_points + %s, updated_at = NOW() WHERE user_id = %s", (granted, user_id))
    return granted


def award_daily_quest_points(*, user_id: str, course_id: str, quest_id: str, reward_points: int = DAILY_QUEST_REWARD_POINTS, date_key: Optional[str] = None) -> Dict[str, Any]:
    """필요 변수: 서버 검증 퀘스트 참조·보상액·기준일. 작동 원리: 사용자 잔액 행을 FOR UPDATE로 잠그고 원장 INSERT와 한도 갱신을 한 PostgreSQL 트랜잭션으로 확정한다."""
    init_student_account_db()
    day, safe_reward = date_key or today_key(), max(0, min(int(reward_points or 0), DAILY_POINT_LIMIT))
    ref_id = f"{course_id}:{day}:{quest_id}"
    with _pool().connection() as conn, conn.transaction(), conn.cursor(row_factory=dict_row) as cur:
        _ensure_rows(cur, user_id, day)
        cur.execute("SELECT activity_score FROM student_account_stats WHERE user_id = %s FOR UPDATE", (user_id,))
        previous_score = int(cur.fetchone()["activity_score"])
        previous_level = level_for_activity_score(previous_score)
        cur.execute("SELECT earned_points FROM student_daily_point_usage WHERE user_id = %s AND date_key = %s::date FOR UPDATE", (user_id, day))
        remaining = max(0, DAILY_POINT_LIMIT - int(cur.fetchone()["earned_points"]))
        ledger = None
        requested_grant = min(safe_reward, remaining)
        if requested_grant:
            cur.execute(
                """INSERT INTO student_point_ledger (user_id, delta_points, reason_code, ref_id, source_date)
                   VALUES (%s, %s, %s, %s, %s::date)
                   ON CONFLICT (user_id, reason_code, ref_id) DO NOTHING RETURNING delta_points""",
                (user_id, requested_grant, COIN_REASON_DAILY_QUEST, ref_id, day),
            )
            ledger = cur.fetchone()
        granted = int(ledger["delta_points"]) if ledger else 0
        if granted:
            cur.execute("UPDATE student_account_stats SET total_points = total_points + %s, activity_score = activity_score + %s, updated_at = NOW() WHERE user_id = %s", (granted, granted, user_id))
            cur.execute("UPDATE student_daily_point_usage SET earned_points = earned_points + %s, updated_at = NOW() WHERE user_id = %s AND date_key = %s::date", (granted, user_id, day))
        milestones = _grant_level_milestones(cur, user_id, previous_level, level_for_activity_score(previous_score + granted))
        summary = _summary_from_cursor(cur, user_id, day)
        duplicate = False
        if ledger is None and requested_grant:
            duplicate = True
        summary["reward"] = {"granted_points": granted, "requested_points": safe_reward, "duplicate": duplicate, "daily_cap_reached": remaining <= 0, "granted_milestone_coins": milestones}
        return summary


def add_activity_score(*, user_id: str, delta_score: int, ref_id: str, reason: str = "activity_log", date_key: Optional[str] = None) -> Dict[str, Any]:
    """필요 변수: 신뢰 서버의 활동 참조·경험치. 작동 원리: 활동 원장 UNIQUE와 사용자 행 잠금으로 레벨 보상까지 같은 PostgreSQL 트랜잭션에서 멱등 처리한다."""
    init_student_account_db()
    day, safe_delta, safe_ref = date_key or today_key(), max(0, int(delta_score or 0)), str(ref_id or "").strip()
    if safe_delta <= 0 or not safe_ref:
        summary = get_account_summary(user_id, date_key=day)
        summary["activity_score_reward"] = {"granted_score": 0, "requested_score": safe_delta, "duplicate": False}
        return summary
    with _pool().connection() as conn, conn.transaction(), conn.cursor(row_factory=dict_row) as cur:
        _ensure_rows(cur, user_id, day)
        cur.execute("SELECT activity_score FROM student_account_stats WHERE user_id = %s FOR UPDATE", (user_id,))
        previous_score = int(cur.fetchone()["activity_score"])
        cur.execute(
            """INSERT INTO student_activity_score_ledger (user_id, delta_score, reason, ref_id, source_date)
               VALUES (%s, %s, %s, %s, %s::date) ON CONFLICT (user_id, reason, ref_id) DO NOTHING RETURNING delta_score""",
            (user_id, safe_delta, str(reason or "activity_log")[:80], safe_ref, day),
        )
        row = cur.fetchone(); granted = int(row["delta_score"]) if row else 0
        if granted:
            cur.execute("UPDATE student_account_stats SET activity_score = activity_score + %s, updated_at = NOW() WHERE user_id = %s", (granted, user_id))
        milestones = _grant_level_milestones(cur, user_id, level_for_activity_score(previous_score), level_for_activity_score(previous_score + granted))
        summary = _summary_from_cursor(cur, user_id, day)
        summary["activity_score_reward"] = {"granted_score": granted, "requested_score": safe_delta, "duplicate": row is None, "granted_milestone_coins": milestones}
        return summary
