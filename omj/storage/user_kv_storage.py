"""PostgreSQL 사용자 KV 저장소."""
from __future__ import annotations

import threading
from typing import Optional

from storage.postgres_problem_store import postgres_problem_store

_USER_KV_READY = False
_USER_KV_LOCK = threading.Lock()


def init_user_kv_db() -> None:
    """필요 변수: DATABASE_URL과 004_user_kv.sql 적용 상태.
    작동 원리: 연결 풀에서 테이블 존재 여부를 한 번 확인하고, 미적용 상태는 즉시 실패시킨다.
    """
    global _USER_KV_READY
    if _USER_KV_READY:
        return
    with _USER_KV_LOCK:
        if _USER_KV_READY:
            return
        pool = postgres_problem_store.get_pool()
        with pool.connection() as conn, conn.cursor() as cur:
            cur.execute("SELECT to_regclass('public.user_kv')")
            row = cur.fetchone()
        if not row or not row[0]:
            raise RuntimeError("PostgreSQL migration 004_user_kv.sql is not applied")
        _USER_KV_READY = True


def get_user_kv(user_id: str, key: str) -> Optional[str]:
    """필요 변수: 사용자 ID와 저장 키. 작동 원리: 복합 기본키로 단일 값을 조회한다."""
    init_user_kv_db()
    pool = postgres_problem_store.get_pool()
    with pool.connection() as conn, conn.cursor() as cur:
        cur.execute(
            "SELECT value FROM user_kv WHERE user_id = %s AND key = %s",
            (user_id, key),
        )
        row = cur.fetchone()
    return row[0] if row else None


def set_user_kv(user_id: str, key: str, value: str) -> None:
    """필요 변수: 사용자 ID·저장 키·UTF-8 문자열 값.
    작동 원리: PostgreSQL UPSERT로 동일 키의 값을 원자적으로 갱신한다.
    """
    init_user_kv_db()
    pool = postgres_problem_store.get_pool()
    with pool.connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO user_kv (user_id, key, value, updated_at)
                VALUES (%s, %s, %s, NOW())
                ON CONFLICT (user_id, key) DO UPDATE SET
                    value = EXCLUDED.value,
                    updated_at = NOW()
                """,
                (user_id, key, value),
            )
        conn.commit()


def delete_user_kv(user_id: str, key: str) -> None:
    """필요 변수: 사용자 ID와 저장 키. 작동 원리: 복합 키에 해당하는 행만 삭제한다."""
    init_user_kv_db()
    pool = postgres_problem_store.get_pool()
    with pool.connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "DELETE FROM user_kv WHERE user_id = %s AND key = %s",
                (user_id, key),
            )
        conn.commit()
