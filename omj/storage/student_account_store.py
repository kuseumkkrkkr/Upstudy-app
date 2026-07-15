from __future__ import annotations

import math
import sqlite3
import threading
from datetime import date, datetime
from typing import Any, Dict, Optional

from storage.storage import DB_PATH


DAILY_POINT_LIMIT = 100
DAILY_QUEST_REWARD_POINTS = 20
ACTIVITY_DISPLAY_DAILY_CAP = 2000
MAX_ACCOUNT_LEVEL = 256
LEVEL_MILESTONE_INTERVAL = 5
LEVEL_MILESTONE_BASE_COINS = 10
_SQLITE_TIMEOUT_SECONDS = 30.0
_ACCOUNT_TABLES_READY: set[str] = set()
_ACCOUNT_TABLES_LOCK = threading.Lock()


def _now_iso() -> str:
    return datetime.utcnow().isoformat(timespec="seconds") + "Z"


def today_key() -> str:
    return date.today().isoformat()


def _connect(*, isolation_level: str | None = "") -> sqlite3.Connection:
    conn = sqlite3.connect(
        DB_PATH,
        timeout=_SQLITE_TIMEOUT_SECONDS,
        isolation_level=isolation_level,
    )
    conn.execute("PRAGMA busy_timeout = 30000")
    return conn


def level_for_activity_score(activity_score: int) -> int:
    """누적 경험치로 레벨을 계산합니다.

    activity_score는 누적 경험치이며, 제곱 증가식으로 요구 경험치를 높입니다.
    반환값은 서비스 정책상 최대 레벨 256을 넘지 않습니다.
    """
    score = max(0, int(activity_score or 0))
    return min(MAX_ACCOUNT_LEVEL, int(math.sqrt(score / 100)) + 1)


def required_activity_score_for_level(level: int) -> int:
    """특정 레벨에 도달하기 위한 누적 경험치를 반환합니다.

    level은 1~256 범위로 고정하고, (레벨 - 1)^2 * 100 식으로
    레벨이 높아질수록 다음 레벨 요구 경험치가 증가하게 합니다.
    """
    safe_level = min(MAX_ACCOUNT_LEVEL, max(1, int(level or 1)))
    return (safe_level - 1) * (safe_level - 1) * 100


def coins_for_level_milestone(level: int) -> int:
    """5의 배수 레벨 달성 보상 코인을 계산합니다.

    level은 5의 배수여야 하며, 5레벨마다 보상 그룹이 하나 증가합니다.
    기본 10코인에 그룹 번호를 곱해 보상도 단계적으로 늘립니다.
    """
    group = max(1, min(MAX_ACCOUNT_LEVEL // LEVEL_MILESTONE_INTERVAL, level // LEVEL_MILESTONE_INTERVAL))
    return LEVEL_MILESTONE_BASE_COINS * group


def _grant_level_milestone_rewards(
    cur: sqlite3.Cursor, user_id: str, previous_level: int, current_level: int, now: str
) -> int:
    """이번 경험치 획득으로 통과한 5레벨 단위 보상을 한 번씩 지급합니다.

    student_point_ledger의 (사용자, 사유, 유형, 참조값) 고유 인덱스를 사용해
    같은 마일스톤을 재시도하거나 동시 요청해도 코인이 중복 지급되지 않게 합니다.
    """
    first_milestone = ((previous_level // LEVEL_MILESTONE_INTERVAL) + 1) * LEVEL_MILESTONE_INTERVAL
    granted_coins = 0
    for level in range(first_milestone, min(current_level, MAX_ACCOUNT_LEVEL) + 1, LEVEL_MILESTONE_INTERVAL):
        coins = coins_for_level_milestone(level)
        cur.execute(
            """
            INSERT OR IGNORE INTO student_point_ledger (
                user_id, delta_points, reason, ref_type, ref_id, source_date, created_at
            ) VALUES (?, ?, 'level_milestone', 'level_milestone', ?, ?, ?)
            """,
            (user_id, coins, f"level:{level}", today_key(), now),
        )
        if cur.rowcount == 1:
            granted_coins += coins
    if granted_coins:
        cur.execute(
            """UPDATE student_account_stats
               SET total_points = total_points + ?, updated_at = ? WHERE user_id = ?""",
            (granted_coins, now, user_id),
        )
    return granted_coins


def init_student_account_db() -> None:
    if DB_PATH in _ACCOUNT_TABLES_READY:
        return
    with _ACCOUNT_TABLES_LOCK:
        if DB_PATH in _ACCOUNT_TABLES_READY:
            return
        conn = _connect()
        conn.execute("PRAGMA journal_mode = WAL")
        conn.execute("PRAGMA synchronous = NORMAL")
        cur = conn.cursor()
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS student_account_stats (
                user_id TEXT PRIMARY KEY,
                total_points INTEGER NOT NULL DEFAULT 0,
                activity_score INTEGER NOT NULL DEFAULT 0,
                updated_at TEXT NOT NULL
            )
            """
        )
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS student_daily_point_usage (
                user_id TEXT NOT NULL,
                date_key TEXT NOT NULL,
                earned_points INTEGER NOT NULL DEFAULT 0,
                updated_at TEXT NOT NULL,
                PRIMARY KEY (user_id, date_key)
            )
            """
        )
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS student_point_ledger (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id TEXT NOT NULL,
                delta_points INTEGER NOT NULL,
                reason TEXT NOT NULL,
                ref_type TEXT NOT NULL,
                ref_id TEXT NOT NULL,
                source_date TEXT NOT NULL,
                created_at TEXT NOT NULL
            )
            """
        )
        cur.execute(
            """
            CREATE UNIQUE INDEX IF NOT EXISTS idx_student_point_ledger_unique_ref
            ON student_point_ledger(user_id, reason, ref_type, ref_id)
            """
        )
        cur.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_student_point_ledger_user_time
            ON student_point_ledger(user_id, created_at DESC)
            """
        )
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS student_activity_score_ledger (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id TEXT NOT NULL,
                delta_score INTEGER NOT NULL,
                reason TEXT NOT NULL,
                ref_id TEXT NOT NULL,
                source_date TEXT NOT NULL,
                created_at TEXT NOT NULL
            )
            """
        )
        cur.execute(
            """
            CREATE UNIQUE INDEX IF NOT EXISTS idx_student_activity_score_unique_ref
            ON student_activity_score_ledger(user_id, reason, ref_id)
            """
        )
        cur.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_student_activity_score_user_time
            ON student_activity_score_ledger(user_id, created_at DESC)
            """
        )
        conn.commit()
        conn.close()
        _ACCOUNT_TABLES_READY.add(DB_PATH)


def _ensure_stats(cur: sqlite3.Cursor, user_id: str, now: str) -> None:
    cur.execute(
        """
        INSERT INTO student_account_stats (
            user_id, total_points, activity_score, updated_at
        ) VALUES (?, 0, 0, ?)
        ON CONFLICT(user_id) DO NOTHING
        """,
        (user_id, now),
    )


def _summary_from_cursor(
    cur: sqlite3.Cursor,
    user_id: str,
    *,
    date_key: Optional[str] = None,
) -> Dict[str, Any]:
    day = date_key or today_key()
    now = _now_iso()
    _ensure_stats(cur, user_id, now)
    cur.execute(
        """
        INSERT INTO student_daily_point_usage (
            user_id, date_key, earned_points, updated_at
        ) VALUES (?, ?, 0, ?)
        ON CONFLICT(user_id, date_key) DO NOTHING
        """,
        (user_id, day, now),
    )
    cur.execute(
        """
        SELECT total_points, activity_score
        FROM student_account_stats
        WHERE user_id = ?
        """,
        (user_id,),
    )
    stats_row = cur.fetchone() or (0, 0)
    total_points = int(stats_row[0] or 0)
    activity_score = int(stats_row[1] or 0)
    cur.execute(
        """
        SELECT earned_points
        FROM student_daily_point_usage
        WHERE user_id = ? AND date_key = ?
        """,
        (user_id, day),
    )
    usage_row = cur.fetchone() or (0,)
    today_points = int(usage_row[0] or 0)
    level = level_for_activity_score(activity_score)
    current_level_score = required_activity_score_for_level(level)
    next_level_score = required_activity_score_for_level(level + 1)
    span = max(1, next_level_score - current_level_score)
    level_progress = 1.0 if level >= MAX_ACCOUNT_LEVEL else (activity_score - current_level_score) / span
    return {
        "user_id": user_id,
        "total_points": total_points,
        "activity_score": activity_score,
        "level": level,
        "current_level_score": current_level_score,
        "next_level_score": next_level_score,
        "level_progress": round(max(0.0, min(1.0, level_progress)), 4),
        "daily_points": today_points,
        "daily_point_limit": DAILY_POINT_LIMIT,
        "daily_points_remaining": max(0, DAILY_POINT_LIMIT - today_points),
        "activity_display_daily_cap": ACTIVITY_DISPLAY_DAILY_CAP,
        "max_level": MAX_ACCOUNT_LEVEL,
    }


def get_account_summary(user_id: str, *, date_key: Optional[str] = None) -> Dict[str, Any]:
    init_student_account_db()
    conn = _connect()
    cur = conn.cursor()
    summary = _summary_from_cursor(cur, user_id, date_key=date_key)
    conn.commit()
    conn.close()
    return summary


def award_daily_quest_points(
    *,
    user_id: str,
    course_id: str,
    quest_id: str,
    reward_points: int = DAILY_QUEST_REWARD_POINTS,
    date_key: Optional[str] = None,
) -> Dict[str, Any]:
    init_student_account_db()
    day = date_key or today_key()
    safe_reward = max(0, min(int(reward_points or 0), DAILY_POINT_LIMIT))
    ref_id = f"{course_id}:{day}:{quest_id}"
    now = _now_iso()

    conn = _connect(isolation_level=None)
    cur = conn.cursor()
    try:
        cur.execute("BEGIN IMMEDIATE")
        _ensure_stats(cur, user_id, now)
        cur.execute(
            "SELECT activity_score FROM student_account_stats WHERE user_id = ?",
            (user_id,),
        )
        previous_score = int((cur.fetchone() or (0,))[0] or 0)
        previous_level = level_for_activity_score(previous_score)
        cur.execute(
            """
            INSERT INTO student_daily_point_usage (
                user_id, date_key, earned_points, updated_at
            ) VALUES (?, ?, 0, ?)
            ON CONFLICT(user_id, date_key) DO NOTHING
            """,
            (user_id, day, now),
        )
        cur.execute(
            """
            SELECT 1
            FROM student_point_ledger
            WHERE user_id = ?
              AND reason = 'daily_quest'
              AND ref_type = 'daily_quest'
              AND ref_id = ?
            """,
            (user_id, ref_id),
        )
        duplicate = cur.fetchone() is not None
        cur.execute(
            """
            SELECT earned_points
            FROM student_daily_point_usage
            WHERE user_id = ? AND date_key = ?
            """,
            (user_id, day),
        )
        today_points = int((cur.fetchone() or (0,))[0] or 0)
        remaining = max(0, DAILY_POINT_LIMIT - today_points)
        granted = 0 if duplicate else min(safe_reward, remaining)

        if granted > 0:
            cur.execute(
                """
                INSERT INTO student_point_ledger (
                    user_id, delta_points, reason, ref_type, ref_id, source_date, created_at
                ) VALUES (?, ?, 'daily_quest', 'daily_quest', ?, ?, ?)
                """,
                (user_id, granted, ref_id, day, now),
            )
            cur.execute(
                """
                UPDATE student_account_stats
                SET total_points = total_points + ?,
                    activity_score = activity_score + ?,
                    updated_at = ?
                WHERE user_id = ?
                """,
                (granted, granted, now, user_id),
            )
            cur.execute(
                """
                UPDATE student_daily_point_usage
                SET earned_points = earned_points + ?,
                    updated_at = ?
                WHERE user_id = ? AND date_key = ?
                """,
                (granted, now, user_id, day),
            )

        current_level = level_for_activity_score(previous_score + granted)
        granted_milestone_coins = _grant_level_milestone_rewards(
            cur, user_id, previous_level, current_level, now
        )

        summary = _summary_from_cursor(cur, user_id, date_key=day)
        conn.commit()
        summary["reward"] = {
            "granted_points": granted,
            "requested_points": safe_reward,
            "duplicate": duplicate,
            "daily_cap_reached": remaining <= 0,
            "granted_milestone_coins": granted_milestone_coins,
        }
        return summary
    except sqlite3.IntegrityError:
        conn.rollback()
        summary = get_account_summary(user_id, date_key=day)
        summary["reward"] = {
            "granted_points": 0,
            "requested_points": safe_reward,
            "duplicate": True,
            "daily_cap_reached": summary["daily_points_remaining"] <= 0,
        }
        return summary
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def add_activity_score(
    *,
    user_id: str,
    delta_score: int,
    ref_id: str,
    reason: str = "activity_log",
    date_key: Optional[str] = None,
) -> Dict[str, Any]:
    init_student_account_db()
    safe_delta = max(0, int(delta_score or 0))
    safe_ref_id = str(ref_id or "").strip()
    safe_reason = str(reason or "activity_log").strip() or "activity_log"
    if safe_delta <= 0 or not safe_ref_id:
        summary = get_account_summary(user_id, date_key=date_key)
        summary["activity_score_reward"] = {
            "granted_score": 0,
            "requested_score": safe_delta,
            "duplicate": False,
        }
        return summary

    day = date_key or today_key()
    now = _now_iso()
    conn = _connect(isolation_level=None)
    cur = conn.cursor()
    try:
        cur.execute("BEGIN IMMEDIATE")
        _ensure_stats(cur, user_id, now)
        cur.execute(
            "SELECT activity_score FROM student_account_stats WHERE user_id = ?",
            (user_id,),
        )
        previous_score = int((cur.fetchone() or (0,))[0] or 0)
        previous_level = level_for_activity_score(previous_score)
        cur.execute(
            """
            INSERT OR IGNORE INTO student_activity_score_ledger (
                user_id, delta_score, reason, ref_id, source_date, created_at
            ) VALUES (?, ?, ?, ?, ?, ?)
            """,
            (user_id, safe_delta, safe_reason, safe_ref_id, day, now),
        )
        granted = safe_delta if cur.rowcount == 1 else 0
        if granted > 0:
            cur.execute(
                """
                UPDATE student_account_stats
                SET activity_score = activity_score + ?,
                    updated_at = ?
                WHERE user_id = ?
                """,
                (granted, now, user_id),
            )

        current_level = level_for_activity_score(previous_score + granted)
        granted_milestone_coins = _grant_level_milestone_rewards(
            cur, user_id, previous_level, current_level, now
        )

        summary = _summary_from_cursor(cur, user_id, date_key=day)
        conn.commit()
        summary["activity_score_reward"] = {
            "granted_score": granted,
            "requested_score": safe_delta,
            "duplicate": granted == 0,
            "granted_milestone_coins": granted_milestone_coins,
        }
        return summary
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()
