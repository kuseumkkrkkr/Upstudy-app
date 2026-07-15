"""레벨테스트가 일반 문제은행 없이 전용 정적 DB만 사용하는지 검증한다."""
from __future__ import annotations

import asyncio
import sqlite3
import tempfile
import unittest
from collections import Counter
from contextlib import closing
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from fastapi import HTTPException

from app.api.routes.level_test import router as level_test_router
from domain.level_test import engine, repository, static_store
from rating_service import _build_placement_samples


class LevelTestStaticStoreTests(unittest.TestCase):
    """필요 변수: 배포 정적 DB와 임시 운영 DB. 작동 원리: 문항 구조·읽기 전용성·운영 DB 독립성을 교차 검증한다."""

    def test_static_database_has_five_balanced_unique_forms(self) -> None:
        """필요 변수: 정적 DB. 작동 원리: 각 폼의 50문항·난도·교과 분포와 끊어진 참조가 없어야 한다."""
        report = static_store.validate_static_database()
        self.assertEqual(report["template_count"], 5)
        self.assertEqual(report["template_question_counts"], [50] * 5)
        self.assertEqual(report["stale_items"], 0)
        for template_id in static_store.list_template_ids():
            items = static_store.get_template_items(template_id)
            self.assertEqual(len({item["quest_id"] for item in items}), 50)
            self.assertEqual(
                Counter(item["difficulty_tier"] for item in items),
                Counter({2: 10, 3: 20, 4: 15, 5: 5}),
            )
            self.assertEqual(
                Counter(item["subject_key"] for item in items),
                Counter(
                    {
                        "common_math_1": 12,
                        "common_math_2": 13,
                        "algebra": 12,
                        "calculus_1": 13,
                    }
                ),
            )

    def test_runtime_connection_is_read_only(self) -> None:
        """필요 변수: 런타임 정적 DB 연결. 작동 원리: query_only와 mode=ro가 모든 DDL 쓰기를 거부해야 한다."""
        connection = static_store._connect()
        try:
            with self.assertRaises(sqlite3.OperationalError):
                connection.execute("CREATE TABLE forbidden_write(id INTEGER)")
        finally:
            connection.close()

    def test_startup_validation_warms_runtime_snapshot(self) -> None:
        """필요 변수: 비운 정적 캐시. 작동 원리: 시작 검증 뒤에는 디스크 연결을 막아도 폼·슬롯·문제 조회가 모두 성공해야 한다."""
        static_store.clear_static_cache()
        static_store.validate_static_database()
        template_id = static_store.list_template_ids()[0]
        item = static_store.get_template_items(template_id)[0]
        with patch.object(static_store, "_connect", side_effect=AssertionError("disk reopened")):
            self.assertEqual(len(static_store.list_template_ids()), 5)
            self.assertEqual(len(static_store.get_template_items(template_id)), 50)
            self.assertIsNotNone(static_store.get_quest(item["quest_id"]))

    def test_engine_loads_complete_payloads_without_general_quest_lookup(self) -> None:
        """필요 변수: 정적 슬롯. 작동 원리: 일반 storage 조회를 실패시켜도 50개 전용 payload가 완성돼야 한다."""
        items = engine.build_placement_template_items()
        with patch("storage.storage.get_quest", side_effect=AssertionError("general DB accessed")):
            payloads = engine.quest_payloads_for_template_items(items)
        self.assertEqual(len(payloads), 50)
        self.assertTrue(
            all(item["quest_id"].startswith("level-test-static/v1/") for item in payloads)
        )

    def test_repository_keeps_only_sessions_in_runtime_database(self) -> None:
        """필요 변수: 빈 임시 운영 DB. 작동 원리: 폼 조회·세션 생성 후에도 구형 문제 템플릿 테이블을 만들지 않는다."""
        with tempfile.TemporaryDirectory() as temp_dir:
            runtime_db = Path(temp_dir) / "runtime.db"
            with patch.object(repository, "DB_PATH", str(runtime_db)):
                template = repository.pick_ready_placement_template("student-static")
                self.assertIsNotNone(template)
                repository.create_placement_session(
                    user_id="student-static",
                    template_id=str(template["template_id"]),
                )
            with closing(sqlite3.connect(runtime_db)) as connection:
                tables = {
                    str(row[0])
                    for row in connection.execute(
                        "SELECT name FROM sqlite_master WHERE type='table'"
                    )
                }
                session_count = int(
                    connection.execute("SELECT COUNT(*) FROM level_test_session").fetchone()[0]
                )
            self.assertEqual(session_count, 1)
            self.assertNotIn("level_test_template", tables)
            self.assertNotIn("level_test_template_item", tables)

    def test_rating_sample_uses_static_calibrated_rating(self) -> None:
        """필요 변수: 정적 문제 한 개와 답안. 작동 원리: 일반 난도 휴리스틱이 아니라 DB에 고정한 placement_rating이 표본에 들어간다."""
        item = static_store.get_template_items(static_store.list_template_ids()[0])[0]
        samples = _build_placement_samples(
            [{"quest_id": item["quest_id"], "is_correct": True, "tags": ["조작태그"]}]
        )
        self.assertEqual(len(samples), 1)
        self.assertEqual(samples[0]["problem_rating"], item["problem_rating"])
        self.assertNotIn("조작태그", samples[0]["tags"])

    def test_start_and_answer_flow_accepts_only_assigned_static_problem(self) -> None:
        """필요 변수: 임시 세션 DB와 가짜 인증 요청. 작동 원리: 시작 API는 50문항을 반환하고 답안 API는 배정 ID·정적 태그만 허용한다."""
        with tempfile.TemporaryDirectory() as temp_dir:
            runtime_db = Path(temp_dir) / "runtime.db"
            request = SimpleNamespace(state=SimpleNamespace(user_id="student-api"))
            with patch.object(repository, "DB_PATH", str(runtime_db)):
                response = asyncio.run(
                    level_test_router.start_placement_test(request, _user={})
                )
                payload = response.data
                self.assertIsNotNone(payload)
                self.assertEqual(payload.question_count, 50)
                first = payload.questions[0]
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


if __name__ == "__main__":
    unittest.main()
