"""UTF-8 SQLite 학생 코인 원장을 PostgreSQL로 한 번 이관한다."""
from __future__ import annotations

import argparse
import sqlite3
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from storage.storage import DB_PATH
from storage.student_account_store import COIN_REASON_DAILY_QUEST, COIN_REASON_LEVEL_MILESTONE


def _table_exists(cur: sqlite3.Cursor, name: str) -> bool:
    """필요 변수: SQLite 커서·테이블명. 작동 원리: 레거시 설치에 원장 테이블이 없는 경우를 읽기 전 처리한다."""
    cur.execute("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?", (name,))
    return cur.fetchone() is not None


def migrate(*, source_path: str, dry_run: bool) -> dict[str, int]:
    """필요 변수: SQLite 원본 경로·dry-run. 작동 원리: PostgreSQL 007 테이블에 UPSERT하지 않고 최초 행만 INSERT해 이미 운영 중인 원장을 덮어쓰지 않는다."""
    source = Path(source_path)
    if not source.exists():
        raise RuntimeError(f"SQLite source does not exist: {source}")
    conn = sqlite3.connect(source)
    cur = conn.cursor()
    tables = ("student_account_stats", "student_daily_point_usage", "student_point_ledger", "student_activity_score_ledger")
    if not all(_table_exists(cur, table) for table in tables):
        raise RuntimeError("SQLite student account tables are missing")
    rows: dict[str, list[tuple[Any, ...]]] = {}
    for table in tables:
        cur.execute(f"SELECT * FROM {table}")
        rows[table] = cur.fetchall()
    conn.close()
    report = {table: len(values) for table, values in rows.items()}
    if dry_run:
        return report

    from psycopg import connect

    import os
    database_url = os.getenv("DATABASE_URL", "").strip()
    if not database_url:
        raise RuntimeError("DATABASE_URL is required")
    with connect(database_url) as target, target.transaction(), target.cursor() as out:
        for user_id, total_points, activity_score, updated_at in rows["student_account_stats"]:
            out.execute("INSERT INTO student_account_stats (user_id, total_points, activity_score, updated_at) VALUES (%s, %s, %s, %s) ON CONFLICT (user_id) DO NOTHING", (user_id, total_points, activity_score, updated_at))
        for user_id, date_key, earned_points, updated_at in rows["student_daily_point_usage"]:
            out.execute("INSERT INTO student_daily_point_usage (user_id, date_key, earned_points, updated_at) VALUES (%s, %s, %s, %s) ON CONFLICT (user_id, date_key) DO NOTHING", (user_id, date_key, earned_points, updated_at))
        for _id, user_id, delta, reason, _ref_type, ref_id, source_date, created_at in rows["student_point_ledger"]:
            code = COIN_REASON_LEVEL_MILESTONE if reason in {"level_milestone", "1"} else COIN_REASON_DAILY_QUEST
            out.execute("INSERT INTO student_point_ledger (user_id, delta_points, reason_code, ref_id, source_date, created_at) VALUES (%s, %s, %s, %s, %s, %s) ON CONFLICT (user_id, reason_code, ref_id) DO NOTHING", (user_id, delta, code, ref_id, source_date, created_at))
        for _id, user_id, delta, reason, ref_id, source_date, created_at in rows["student_activity_score_ledger"]:
            out.execute("INSERT INTO student_activity_score_ledger (user_id, delta_score, reason, ref_id, source_date, created_at) VALUES (%s, %s, %s, %s, %s, %s) ON CONFLICT (user_id, reason, ref_id) DO NOTHING", (user_id, delta, reason, ref_id, source_date, created_at))
    return report


def main() -> None:
    """필요 변수: 선택 SQLite 경로·dry-run. 작동 원리: 이관 전에는 행 수만 출력하고 실제 실행은 명시적으로 수행한다."""
    parser = argparse.ArgumentParser(description="학생 코인·경험치 SQLite → PostgreSQL 이관")
    parser.add_argument("--source", default=DB_PATH)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    print(migrate(source_path=args.source, dry_run=args.dry_run))


if __name__ == "__main__":
    main()
