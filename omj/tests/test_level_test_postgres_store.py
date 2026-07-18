"""PostgreSQL placement 레벨테스트 계약을 검증한다."""
from __future__ import annotations

import asyncio
import unittest
import uuid
from types import SimpleNamespace
from unittest.mock import patch

from fastapi import HTTPException

from app.api.routes.level_test import router as level_test_router
from domain.level_test import engine, repository
from rating_service import _build_placement_samples
from storage.postgres_level_test_store import postgres_level_test_store


class LevelTestPostgresStoreTests(unittest.TestCase):
    """필요 변수: 적용된 008 migration과 PostgreSQL 문제 payload. 작동 원리: 폼·payload·세션 계약을 실제 풀에서 검증한다."""

    def test_postgres_has_balanced_forms_and_payloads(self) -> None:
        """필요 변수: 활성 폼 ID. 작동 원리: 각 폼이 50개 슬롯과 결합된 문제 payload를 갖는지 확인한다."""
        postgres_level_test_store.require_ready()
        template_ids = postgres_level_test_store.list_template_ids()
        self.assertEqual(len(template_ids), 5)
        for template_id in template_ids:
            items = postgres_level_test_store.get_template_items(template_id)
            self.assertEqual(len(items), 50)
            self.assertEqual(len({item["quest_id"] for item in items}), 50)
            self.assertTrue(all(isinstance(item.get("quest"), dict) for item in items))

    def test_engine_uses_postgres_without_general_storage_lookup(self) -> None:
        """필요 변수: PostgreSQL placement 폼. 작동 원리: 일반 SQLite 문제 조회 없이 50개 payload를 완성한다."""
        items = engine.build_placement_template_items()
        with patch("storage.storage.get_quest", side_effect=AssertionError("general DB accessed")):
            payloads = engine.quest_payloads_for_template_items(items)
        self.assertEqual(len(payloads), 50)

    def test_rating_sample_uses_server_payload(self) -> None:
        """필요 변수: PostgreSQL 문제 한 개와 답안. 작동 원리: 클라이언트 태그가 아니라 서버 payload 태그를 사용한다."""
        item = postgres_level_test_store.get_template_items(
            postgres_level_test_store.list_template_ids()[0]
        )[0]
        samples = _build_placement_samples(
            [{"quest_id": item["quest_id"], "is_correct": True, "tags": ["조작태그"]}]
        )
        self.assertEqual(len(samples), 1)
        self.assertEqual(samples[0]["problem_rating"], item["problem_rating"])
        self.assertNotIn("조작태그", samples[0]["tags"])

    def test_start_and_answer_flow_validates_postgres_assignment(self) -> None:
        """필요 변수: 임시 사용자와 인증 요청. 작동 원리: 시작·답안 저장은 PostgreSQL에 기록하고 배정 밖 문제는 거부한다."""
        user_id = f"test-level-{uuid.uuid4()}"
        request = SimpleNamespace(state=SimpleNamespace(user_id=user_id))
        response = asyncio.run(level_test_router.start_placement_test(request, _user={}))
        payload = response.data
        self.assertEqual(payload.question_count, 50)
        first = payload.questions[0]
        try:
            asyncio.run(
                level_test_router.submit_placement_answer(
                    request,
                    payload.session_id,
                    level_test_router.PlacementAnswerRequest(
                        item_index=first.item_index,
                        quest_id=first.quest_id,
                        is_correct=True,
                        tags=["조작태그"],
                    ),
                    _user={},
                )
            )
            answers = repository.list_placement_answers(payload.session_id)
            self.assertEqual(answers[0]["tags"], first.hash_tags)
            with self.assertRaises(HTTPException) as raised:
                asyncio.run(
                    level_test_router.submit_placement_answer(
                        request,
                        payload.session_id,
                        level_test_router.PlacementAnswerRequest(
                            item_index=first.item_index,
                            quest_id="curated/general-db/problem",
                            is_correct=True,
                        ),
                        _user={},
                    )
                )
            self.assertEqual(raised.exception.status_code, 400)
        finally:
            with postgres_level_test_store._connection() as connection, connection.transaction(), connection.cursor() as cursor:
                cursor.execute("DELETE FROM level_test_session WHERE session_id = %s", (payload.session_id,))


if __name__ == "__main__":
    unittest.main()
