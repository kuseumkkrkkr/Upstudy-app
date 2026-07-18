"""마켓 구매와 사용자별 학습 진행 저장소."""
from __future__ import annotations

from threading import Lock
from typing import Any

from psycopg.rows import dict_row

from storage.postgres_problem_store import postgres_problem_store


_schema_lock = Lock()
_schema_ready = False


def _pool() -> Any:
    """필요 변수는 운영 PostgreSQL 연결 풀이다. 코인과 구매를 같은 DB 트랜잭션으로 묶는다."""
    return postgres_problem_store.get_pool()


def ensure_schema() -> None:
    """필요 변수는 구매 테이블이다. 배포 누락 시에도 첫 구매 요청에서 멱등적으로 준비한다."""
    global _schema_ready
    if _schema_ready:
        return
    with _schema_lock:
        if _schema_ready:
            return
        _ensure_schema()
        _schema_ready = True


def _ensure_schema() -> None:
    """필요 변수는 공유 PostgreSQL 풀이다. 프로세스당 한 번만 구매 테이블과 인덱스를 준비한다."""
    with _pool().connection() as connection, connection.cursor() as cursor:
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS marketplace_purchase (
                user_id TEXT NOT NULL,
                listing_id TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'in_progress',
                progress_index INTEGER NOT NULL DEFAULT 0,
                purchased_price_points INTEGER NOT NULL DEFAULT 0,
                purchased_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                completed_at TIMESTAMPTZ,
                updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                PRIMARY KEY (user_id, listing_id)
            )
            """
        )
        cursor.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_marketplace_purchase_user_updated
            ON marketplace_purchase (user_id, status, updated_at DESC)
            """
        )
        connection.commit()


def purchase(*, user_id: str, listing_id: str, price_points: int) -> dict[str, Any]:
    """필요 변수는 사용자·상품·가격이다. 보유 중이면 재사용하고, 아니면 코인을 잠근 뒤 구매와 원장을 한 번에 확정한다."""
    ensure_schema()
    safe_price = max(0, int(price_points))
    with _pool().connection() as connection, connection.transaction():
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                "SELECT * FROM marketplace_purchase WHERE user_id = %s AND listing_id = %s FOR UPDATE",
                (user_id, listing_id),
            )
            existing = cursor.fetchone()
            if existing:
                return dict(existing)
            cursor.execute(
                "INSERT INTO student_account_stats (user_id) VALUES (%s) ON CONFLICT DO NOTHING",
                (user_id,),
            )
            cursor.execute(
                "SELECT total_points FROM student_account_stats WHERE user_id = %s FOR UPDATE",
                (user_id,),
            )
            balance = int((cursor.fetchone() or {"total_points": 0})["total_points"])
            if balance < safe_price:
                raise ValueError("insufficient_coins")
            if safe_price:
                cursor.execute(
                    "UPDATE student_account_stats SET total_points = total_points - %s, updated_at = NOW() WHERE user_id = %s",
                    (safe_price, user_id),
                )
                cursor.execute(
                    """INSERT INTO student_point_ledger
                       (user_id, delta_points, reason_code, ref_id, source_date)
                       VALUES (%s, %s, 3, %s, CURRENT_DATE)""",
                    (user_id, safe_price, f"marketplace:{listing_id}"),
                )
            cursor.execute(
                """INSERT INTO marketplace_purchase
                   (user_id, listing_id, purchased_price_points)
                   VALUES (%s, %s, %s)
                   RETURNING *""",
                (user_id, listing_id, safe_price),
            )
            return dict(cursor.fetchone())


def list_owned(user_id: str) -> list[dict[str, Any]]:
    """필요 변수는 사용자 ID다. 보유 자료를 미완료 우선·완료 후순위로 반환한다."""
    ensure_schema()
    with _pool().connection() as connection, connection.cursor(row_factory=dict_row) as cursor:
        cursor.execute(
            """SELECT user_id, listing_id, status, progress_index,
                      purchased_price_points, purchased_at, completed_at, updated_at
               FROM marketplace_purchase
               WHERE user_id = %s
               ORDER BY CASE WHEN status = 'completed' THEN 1 ELSE 0 END,
                        updated_at DESC""",
            (user_id,),
        )
        return [dict(row) for row in cursor.fetchall()]


def update_progress(*, user_id: str, listing_id: str, progress_index: int, completed: bool) -> dict[str, Any]:
    """필요 변수는 사용자·상품·현재 문제 위치·완료 여부다. 보유 행만 갱신해 이어풀기와 완료 정렬에 사용한다."""
    ensure_schema()
    status = "completed" if completed else "in_progress"
    with _pool().connection() as connection, connection.transaction():
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                """UPDATE marketplace_purchase
                   SET status = %s, progress_index = %s,
                       completed_at = CASE WHEN %s THEN COALESCE(completed_at, NOW()) ELSE NULL END,
                       updated_at = NOW()
                   WHERE user_id = %s AND listing_id = %s
                   RETURNING *""",
                (status, max(0, int(progress_index)), completed, user_id, listing_id),
            )
            row = cursor.fetchone()
            if not row:
                raise KeyError("purchase_not_found")
            return dict(row)
