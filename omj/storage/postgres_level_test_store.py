"""Placement 레벨테스트 전용 PostgreSQL 저장소."""
from __future__ import annotations

import json
import uuid
from typing import Any, Iterable, Optional

from psycopg.rows import dict_row
from psycopg.types.json import Jsonb

from storage.postgres_problem_store import postgres_problem_store


class PostgresLevelTestStore:
    """공유 PostgreSQL 풀을 사용해 레벨테스트의 읽기·쓰기 계약을 제공한다."""

    def _connection(self) -> Any:
        """필요 변수: PostgreSQL 연결 풀. 작동 원리: 공용 풀에서 연결을 빌려 요청 종료 시 반환한다."""
        return postgres_problem_store.get_pool().connection()

    def require_ready(self) -> None:
        """필요 변수: 008 migration. 작동 원리: 핵심 테이블이 없으면 서버가 부분 배포 상태로 동작하지 않게 차단한다."""
        with self._connection() as connection, connection.cursor() as cursor:
            cursor.execute("SELECT to_regclass('public.level_test_template') AS table_name")
            row = cursor.fetchone()
        if not row or not row[0]:
            raise RuntimeError("PostgreSQL level-test migration 008 is not applied")

    def list_template_ids(self) -> list[str]:
        """필요 변수: 없음. 작동 원리: 활성 폼 ID를 순서대로 한 번 조회한다."""
        with self._connection() as connection, connection.cursor() as cursor:
            cursor.execute("SELECT template_id FROM level_test_template WHERE active ORDER BY form_index")
            return [str(row[0]) for row in cursor.fetchall()]

    def pick_template(self, user_id: str) -> Optional[dict[str, Any]]:
        """필요 변수: 사용자 ID. 작동 원리: 최근 3개를 피하고 사용량이 가장 적은 활성 폼을 잠금 없이 선택한다."""
        with self._connection() as connection, connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                """
                SELECT t.template_id, t.version, t.form_index, COUNT(s.session_id) AS usage_count
                FROM level_test_template t
                LEFT JOIN level_test_session s ON s.template_id = t.template_id
                WHERE t.active AND t.template_id NOT IN (
                    SELECT template_id FROM level_test_session
                    WHERE user_id = %s ORDER BY started_at DESC LIMIT 3
                )
                GROUP BY t.template_id, t.version, t.form_index
                ORDER BY usage_count, t.form_index
                LIMIT 1
                """,
                (user_id,),
            )
            row = cursor.fetchone()
            if row:
                return dict(row)
        # 폼이 3개 미만인 경우에도 시험을 막지 않고 전체 활성 폼에서 선택한다.
        with self._connection() as connection, connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                """
                SELECT t.template_id, t.version, t.form_index, COUNT(s.session_id) AS usage_count
                FROM level_test_template t
                LEFT JOIN level_test_session s ON s.template_id = t.template_id
                WHERE t.active
                GROUP BY t.template_id, t.version, t.form_index
                ORDER BY usage_count, t.form_index LIMIT 1
                """
            )
            row = cursor.fetchone()
            return dict(row) if row else None

    def get_template_items(self, template_id: str) -> list[dict[str, Any]]:
        """필요 변수: 폼 ID. 작동 원리: 슬롯과 PostgreSQL 문제 payload를 한 쿼리로 결합한다."""
        with self._connection() as connection, connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                """
                SELECT i.item_index, i.phase, i.subject_key, i.hash_tags,
                       i.difficulty_tier, i.quest_id, i.problem_rating, p.payload AS quest
                FROM level_test_template_item i
                JOIN problem_payload p ON p.quest_id = i.quest_id
                WHERE i.template_id = %s
                ORDER BY i.item_index
                """,
                (template_id,),
            )
            return [dict(row) for row in cursor.fetchall()]

    def get_template_item(self, template_id: str, item_index: int) -> Optional[dict[str, Any]]:
        """필요 변수: 폼 ID·문항 번호. 작동 원리: 답안 검증에 필요한 검수 슬롯을 단건 조회한다."""
        with self._connection() as connection, connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                """SELECT item_index, quest_id, hash_tags, problem_rating
                   FROM level_test_template_item
                   WHERE template_id = %s AND item_index = %s""",
                (template_id, item_index),
            )
            row = cursor.fetchone()
            return dict(row) if row else None

    def create_session(self, *, user_id: str, template_id: str) -> str:
        """필요 변수: 사용자·폼 ID. 작동 원리: UUID 세션을 PostgreSQL에 원자적으로 생성한다."""
        session_id = str(uuid.uuid4())
        with self._connection() as connection, connection.transaction(), connection.cursor() as cursor:
            cursor.execute(
                "INSERT INTO level_test_session(session_id, user_id, template_id, status) VALUES (%s, %s, %s, 'started')",
                (session_id, user_id, template_id),
            )
        return session_id

    def get_session(self, session_id: str) -> Optional[dict[str, Any]]:
        """필요 변수: 세션 ID. 작동 원리: 세션 소유자와 상태를 단건 조회한다."""
        with self._connection() as connection, connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute("SELECT * FROM level_test_session WHERE session_id = %s", (session_id,))
            row = cursor.fetchone()
            return dict(row) if row else None

    def upsert_answer(self, *, session_id: str, item_index: int, quest_id: str, is_correct: bool,
                      answer_time: Optional[float], step_correctness: list[dict[str, Any]], tags: list[str]) -> None:
        """필요 변수: 세션·슬롯·답안. 작동 원리: 복합키 UPSERT로 자동 저장 재시도를 멱등 처리한다."""
        with self._connection() as connection, connection.transaction(), connection.cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO level_test_answer(session_id, item_index, quest_id, is_correct, answer_time, step_correctness, tags)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (session_id, item_index) DO UPDATE SET
                    quest_id=EXCLUDED.quest_id, is_correct=EXCLUDED.is_correct,
                    answer_time=EXCLUDED.answer_time, step_correctness=EXCLUDED.step_correctness,
                    tags=EXCLUDED.tags, submitted_at=NOW()
                """,
                (session_id, item_index, quest_id, is_correct, answer_time, Jsonb(step_correctness), Jsonb(tags)),
            )

    def list_answers(self, session_id: str) -> list[dict[str, Any]]:
        """필요 변수: 세션 ID. 작동 원리: 저장된 답안을 문항 순서로 일괄 조회한다."""
        with self._connection() as connection, connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute("SELECT * FROM level_test_answer WHERE session_id = %s ORDER BY item_index", (session_id,))
            return [dict(row) for row in cursor.fetchall()]

    def complete_session(self, *, session_id: str, estimated_rating: float, estimated_ovr: float,
                         confidence: float, strong_tags: list[dict[str, Any]], weak_tags: list[dict[str, Any]]) -> None:
        """필요 변수: 채점 결과. 작동 원리: 세션 상태와 결과를 한 PostgreSQL UPDATE로 확정한다."""
        with self._connection() as connection, connection.transaction(), connection.cursor() as cursor:
            cursor.execute(
                """UPDATE level_test_session SET status='graded', estimated_rating=%s, estimated_ovr=%s,
                   confidence=%s, strong_tags=%s, weak_tags=%s, submitted_at=NOW() WHERE session_id=%s""",
                (estimated_rating, estimated_ovr, confidence, Jsonb(strong_tags), Jsonb(weak_tags), session_id),
            )

    def get_problem_payloads(self, quest_ids: Iterable[str]) -> dict[str, dict[str, Any]]:
        """필요 변수: 문제 ID 목록. 작동 원리: PostgreSQL JSONB payload를 한 번의 IN 조회로 가져온다."""
        ids = list(dict.fromkeys(str(value) for value in quest_ids if str(value)))
        if not ids:
            return {}
        with self._connection() as connection, connection.cursor() as cursor:
            cursor.execute("SELECT quest_id, payload FROM problem_payload WHERE quest_id = ANY(%s)", (ids,))
            result = {}
            for quest_id, payload in cursor.fetchall():
                if isinstance(payload, str):
                    payload = json.loads(payload)
                if isinstance(payload, dict):
                    result[str(quest_id)] = payload
            return result


postgres_level_test_store = PostgresLevelTestStore()
