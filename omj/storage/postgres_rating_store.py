"""PostgreSQL 학생 레이팅 저장소."""
from __future__ import annotations

from contextlib import contextmanager
import logging
import os
from typing import Any, Dict, Iterable, Iterator, List, Optional

from rating_config import CONFIG
from storage.postgres_problem_store import postgres_problem_store


logger = logging.getLogger(__name__)


class PostgresRatingStore:
    """학생 레이팅의 잠금·중복방지·일괄 갱신을 한 PostgreSQL 트랜잭션으로 제공한다."""

    @contextmanager
    def transaction(self) -> Iterator[Any]:
        """필요 변수: DATABASE_URL·공유 연결 풀. 작동 원리: PostgreSQL 트랜잭션과 dict 행 커서를 제공한다."""
        from psycopg.rows import dict_row

        pool = postgres_problem_store.get_pool()
        with pool.connection() as conn:
            with conn.transaction():
                with conn.cursor(row_factory=dict_row) as cur:
                    yield cur

    def require_ready(self) -> bool:
        """필요 변수: DATABASE_URL·003_rating_runtime.sql 적용 상태.
        작동 원리: 설정과 핵심 테이블을 검사하며 하나라도 없으면 서버 시작을 중단한다.
        """
        if not os.getenv("DATABASE_URL", "").strip():
            raise RuntimeError("DATABASE_URL is required for the rating store")

        try:
            with self.transaction() as cur:
                cur.execute("SELECT to_regclass('public.user_rating') AS table_name")
                row = cur.fetchone()
                if not row or not row["table_name"]:
                    raise RuntimeError("PostgreSQL rating migration 003 is not applied")
        except Exception as exc:
            raise RuntimeError(
                "PostgreSQL is configured but the rating store is not ready; "
                "check DATABASE_URL, PostgreSQL availability, and migration 003"
            ) from exc
        return True

    def get_or_create_user(self, cur: Any, user_id: str, *, for_update: bool) -> Dict[str, Any]:
        """필요 변수: 사용자 ID·트랜잭션 커서. 작동 원리: 기본 레이팅 행을 원자적으로 만든 뒤 선택적으로 행 잠금을 건다."""
        cur.execute(
            """INSERT INTO user_rating (user_id, rating, ovr, ovr_prev)
               VALUES (%s, %s, %s, %s) ON CONFLICT (user_id) DO NOTHING""",
            (user_id, CONFIG.DEFAULT_RATING, CONFIG.DEFAULT_RATING, CONFIG.DEFAULT_RATING),
        )
        suffix = " FOR UPDATE" if for_update else ""
        cur.execute(f"SELECT * FROM user_rating WHERE user_id = %s{suffix}", (user_id,))
        row = cur.fetchone()
        if not row:
            raise RuntimeError("failed to load user rating")
        return dict(row)

    def claim_submission(self, cur: Any, *, user_id: str, submission_id: str, quest_id: str) -> Optional[Dict[str, Any]]:
        """필요 변수: 사용자·제출·문제 ID. 작동 원리: 복합 기본키로 최초 제출만 선점하고 재전송에는 저장된 동일 응답을 반환한다."""
        cur.execute(
            """INSERT INTO rating_submission (user_id, submission_id, quest_id)
               VALUES (%s, %s, %s) ON CONFLICT (user_id, submission_id) DO NOTHING
               RETURNING submission_id""",
            (user_id, submission_id, quest_id),
        )
        if cur.fetchone():
            return None
        cur.execute(
            "SELECT quest_id, response FROM rating_submission WHERE user_id = %s AND submission_id = %s",
            (user_id, submission_id),
        )
        row = cur.fetchone()
        if not row or row["quest_id"] != quest_id:
            raise ValueError("submission_id is already bound to another quest")
        if not row["response"]:
            raise RuntimeError("rating submission is incomplete")
        return dict(row["response"])

    def save_submission_response(self, cur: Any, *, user_id: str, submission_id: str, response: Dict[str, Any]) -> None:
        """필요 변수: 선점된 제출 키·응답. 작동 원리: 같은 트랜잭션 안에서 재전송용 결과 스냅샷을 완성한다."""
        from psycopg.types.json import Jsonb

        cur.execute(
            "UPDATE rating_submission SET response = %s WHERE user_id = %s AND submission_id = %s",
            (Jsonb(response), user_id, submission_id),
        )

    def get_tag_stats(self, cur: Any, user_id: str, tags: Iterable[str]) -> Dict[str, Dict[str, Any]]:
        """필요 변수: 사용자 ID·정규화 태그. 작동 원리: 이번 계산에 필요한 태그 행만 잠가 동시 갱신 손실을 막는다."""
        tag_list = list(tags)
        if not tag_list:
            return {}
        cur.execute(
            """SELECT tag, attempts, rating, rating_prev FROM user_tag_rating
               WHERE user_id = %s AND tag = ANY(%s) FOR UPDATE""",
            (user_id, tag_list),
        )
        return {str(row["tag"]): dict(row) for row in cur.fetchall()}

    def upsert_tag_stats(self, cur: Any, rows: List[Dict[str, Any]]) -> None:
        """필요 변수: 태그별 계산 결과. 작동 원리: 한 번의 executemany로 시도 수와 현재·직전 레이팅을 갱신한다."""
        if not rows:
            return
        cur.executemany(
            """INSERT INTO user_tag_rating
                   (user_id, tag, attempts, rating, rating_prev, updated_at)
               VALUES (%(user_id)s, %(tag)s, %(attempts)s, %(rating)s, %(rating_prev)s, %(updated_at)s)
               ON CONFLICT (user_id, tag) DO UPDATE SET
                   attempts = EXCLUDED.attempts, rating = EXCLUDED.rating,
                   rating_prev = EXCLUDED.rating_prev, updated_at = EXCLUDED.updated_at""",
            rows,
        )

    def compute_ovr(self, cur: Any, user_id: str, fallback: float) -> float:
        """필요 변수: 태그별 레이팅·시도 수. 작동 원리: 태그당 최대 C_MAX까지만 신뢰 가중치를 주어 소표본 태그의 과대영향을 제한한다."""
        cur.execute(
            """SELECT COALESCE(
                    SUM(rating * LEAST(attempts, %s)) / NULLIF(SUM(LEAST(attempts, %s)), 0), %s
                ) AS ovr FROM user_tag_rating WHERE user_id = %s""",
            (int(CONFIG.C_MAX), int(CONFIG.C_MAX), fallback, user_id),
        )
        row = cur.fetchone()
        return float(row["ovr"] if row else fallback)

    def update_user(self, cur: Any, values: Dict[str, Any]) -> None:
        """필요 변수: 계산이 끝난 사용자 레이팅 상태. 작동 원리: 단일 행 UPDATE로 원점수·OVR·최근 50문항 통계를 함께 기록한다."""
        from psycopg.types.json import Jsonb

        cur.execute(
            """UPDATE user_rating SET
                    rating = %(rating)s, ovr = %(ovr)s, ovr_prev = %(ovr_prev)s,
                    lose_streak = %(lose_streak)s, last_attempt_at = %(last_attempt_at)s,
                    recent_results = %(recent_results)s, recent_index = %(recent_index)s,
                    recent_count = %(recent_count)s, recent_sum = %(recent_sum)s,
                    updated_at = %(updated_at)s
               WHERE user_id = %(user_id)s""",
            {**values, "recent_results": Jsonb(values["recent_results"])},
        )

    def fetch_user(self, user_id: str) -> Dict[str, Any]:
        """필요 변수: 사용자 ID. 작동 원리: 사용자 행이 없으면 기본값으로 만든 후 최신 상태를 반환한다."""
        with self.transaction() as cur:
            return self.get_or_create_user(cur, user_id, for_update=False)

    def list_tag_stats(self, user_id: str) -> List[Dict[str, Any]]:
        """필요 변수: 사용자 ID. 작동 원리: 태그 레이팅을 높은 순으로 한 번에 조회한다."""
        with self.transaction() as cur:
            cur.execute(
                """SELECT tag, attempts, rating, rating_prev FROM user_tag_rating
                   WHERE user_id = %s ORDER BY rating DESC, tag ASC""",
                (user_id,),
            )
            return [dict(row) for row in cur.fetchall()]


postgres_rating_store = PostgresRatingStore()
