import asyncio
import unittest
from datetime import timedelta

from arena.grading import grade_answer, is_numeric_answer, max_attempts, normalize_answer
from arena.models import ArenaMatch, ArenaQuestion, Participant
from arena.rating import GlickoRating, TrueSkillRating, contribution_multipliers, contribution_score, tier_for_rating, update_glicko2, update_trueskill_teams
from arena.service import ArenaService, _BOT_PROFILES, _quest_question
from arena.repository import ArenaStoreUnavailable, PostgresArenaRepository, RedisArenaRepository


def _local_service() -> ArenaService:
    """필요 변수 없음. 외부 환경 변수와 분리된 메모리 전용 아레나 서비스를 만든다."""

    return ArenaService(
        redis_repository=RedisArenaRepository(url=""),
        postgres_repository=PostgresArenaRepository(dsn=""),
    )


class ArenaRulesTest(unittest.TestCase):
    """문자열 채점, 레이팅, 기여도와 제출 제한을 검증한다."""

    def test_unicode_nfc_and_exact_comparison(self) -> None:
        self.assertEqual(normalize_answer("  가\u0301 "), normalize_answer("가́"))
        self.assertFalse(grade_answer("short", "정답 ", ["정 답"]))
        self.assertTrue(grade_answer("multiple_choice", "2", ["2"]))
        self.assertEqual(max_attempts("short"), 5)
        self.assertEqual(max_attempts("ox"), 2)

    def test_short_answer_only_accepts_typed_numbers(self) -> None:
        """필요 변수: 숫자·서술형 정답. 단답형은 부호 있는 정수와 소수만 출제·채점되는지 검증한다."""

        self.assertTrue(is_numeric_answer("-12.5"))
        self.assertTrue(grade_answer("short", "-12.5", ["-12.5"]))
        self.assertTrue(grade_answer("short", "2", ["2.0"]))
        self.assertFalse(is_numeric_answer("정답"))
        self.assertFalse(grade_answer("short", "정답", ["정답"]))
        self.assertIsNone(
            _quest_question({
                "header": {"quest_id": "written"},
                "data": {"quest_title": "설명하세요", "quest_answer": "서술 답안"},
            })
        )

    def test_quest_question_preserves_latex_blocks_for_client_rendering(self) -> None:
        """필요 변수: 텍스트·수식 혼합 문항. 공개 문자열에 인라인 수식 경계를 보존하는지 검증한다."""

        question = _quest_question({
            "header": {"quest_id": "latex-question"},
            "data": {
                "quest_title": {
                    "blocks": [
                        {"type": "text", "content": "복소수 "},
                        {"type": "latex", "content": "Z=(-5+4i)(-1-4i)"},
                        {"type": "text", "content": "의 값을 구하시오."},
                    ],
                },
                "quest_answer": {"blocks": [{"type": "latex", "content": "13"}]},
                "quest_options": [
                    {"blocks": [{"type": "latex", "content": r"\frac{13}{2}"}]},
                    {"blocks": [{"type": "text", "content": "13"}]},
                ],
                "choice_answer_index": 1,
            },
        })

        self.assertIsNotNone(question)
        assert question is not None
        self.assertEqual(
            question.prompt,
            r"복소수 \(Z=(-5+4i)(-1-4i)\)의 값을 구하시오.",
        )
        self.assertEqual(question.choices[0]["label"], r"\(\frac{13}{2}\)")

    def test_numeric_latex_answer_remains_plain_for_grading(self) -> None:
        """필요 변수: 수식 블록 숫자 정답. 표시용 구분자가 숫자 채점을 방해하지 않는지 검증한다."""

        question = _quest_question({
            "header": {"quest_id": "numeric-latex-answer"},
            "data": {
                "quest_title": {
                    "blocks": [
                        {"type": "latex", "content": "1+1"},
                        {"type": "text", "content": "의 값은?"},
                    ],
                },
                "quest_answer": {"blocks": [{"type": "latex", "content": "2"}]},
            },
        })

        self.assertIsNotNone(question)
        assert question is not None
        self.assertEqual(question.prompt, r"\(1+1\)의 값은?")
        self.assertEqual(question.accepted_answers, ("2",))

    def test_tier_boundaries(self) -> None:
        self.assertEqual(tier_for_rating(999.9), "E")
        self.assertEqual(tier_for_rating(1000), "D")
        self.assertEqual(tier_for_rating(1500), "C")
        self.assertEqual(tier_for_rating(1750), "B")
        self.assertEqual(tier_for_rating(2000), "A")

    def test_glicko2_official_example(self) -> None:
        player = GlickoRating(1500, 200, 0.06)
        opponents = [
            (GlickoRating(1400, 30, 0.06), 1.0),
            (GlickoRating(1550, 100, 0.06), 0.0),
            (GlickoRating(1700, 300, 0.06), 0.0),
        ]
        updated = update_glicko2(player, opponents)
        self.assertAlmostEqual(updated.rating, 1464.06, places=1)
        self.assertAlmostEqual(updated.deviation, 151.52, places=1)
        self.assertAlmostEqual(updated.volatility, 0.059996, places=4)

    def test_contribution_is_capped(self) -> None:
        self.assertAlmostEqual(contribution_score([5, 2], [3, 1]), 6.6)
        values = contribution_multipliers([100, 0])
        self.assertEqual(values, [1.2, 0.8])

    def test_trueskill_winner_moves_up(self) -> None:
        team_a, team_b = update_trueskill_teams(
            [TrueSkillRating(), TrueSkillRating()],
            [TrueSkillRating(), TrueSkillRating()],
            1,
        )
        self.assertGreater(team_a[0].mu, 25)
        self.assertLess(team_b[0].mu, 25)
        self.assertLess(team_a[0].sigma, 25 / 3)

    def test_question_allows_one_attempt_and_keeps_idempotency(self) -> None:
        """필요 변수: 두 문항 경기. 같은 요청 재전송은 허용하고 새 답안 재시도는 차단하는지 검증한다."""

        async def scenario() -> None:
            service = _local_service()
            questions = [
                ArenaQuestion("q1", "1+1", "multiple_choice", ("2",)),
                ArenaQuestion("q2", "2+2", "multiple_choice", ("4",)),
            ]
            match = ArenaMatch("m1", "duel_exam", {"u1": Participant("u1", 0), "u2": Participant("u2", 1)}, questions)
            service._matches[match.id] = match
            service._user_match.update({"u1": match.id, "u2": match.id})
            first = await service.submit("u1", "m1", "q1", "0", "attempt-0001")
            duplicate = await service.submit("u1", "m1", "q1", "0", "attempt-0001")
            self.assertEqual(first, duplicate)
            with self.assertRaises(ValueError):
                await service.submit("u1", "m1", "q1", "2", "attempt-0002")
            with self.assertRaises(ValueError):
                await service.submit("u2", "m1", "q2", "4", "attempt-0003")

        asyncio.run(scenario())

    def test_finished_result_is_authorized_and_persisted_in_service(self) -> None:
        """필요 변수: 한 문항 경기. 한 팀 완료 즉시 결과·분석과 참가 권한이 생성되는지 검증한다."""

        async def scenario() -> None:
            service = _local_service()
            question = ArenaQuestion("q1", "1+1", "short", ("2",))
            match = ArenaMatch(
                "m-result",
                "duel_exam",
                {"u1": Participant("u1", 0), "u2": Participant("u2", 1)},
                [question],
            )
            service._matches[match.id] = match
            await service.submit("u1", match.id, "q1", "2", "result-0001")
            result = await service.result("u1", match.id)
            self.assertEqual(result["match_id"], match.id)
            self.assertEqual(len(result["participants"]), 2)
            self.assertEqual(result["finish_reason"], "all_questions_answered")
            self.assertEqual(result["viewer_team"], 0)
            self.assertEqual(result["analysis"][0]["team_answers"]["0"]["answer"], "2")
            with self.assertRaises(ValueError):
                await service.result("outsider", match.id)

        asyncio.run(scenario())

    def test_match_serialization_preserves_atomic_state(self) -> None:
        """필요 변수: 시도·해결 상태가 있는 경기. Redis 왕복 뒤 동일 상태가 복원되는지 검증한다."""

        service = _local_service()
        question = ArenaQuestion("q1", "1+1", "short", ("2",), tags=("수학",))
        match = ArenaMatch(
            "m-serialize",
            "duel_exam",
            {"u1": Participant("u1", 0), "u2": Participant("u2", 1)},
            [question],
        )
        match.attempts[(0, "q1")] = 1
        match.solved[(0, "q1")] = ("u1", 3.5)
        match.answers[(0, "q1")] = {
            "user_id": "u1",
            "answer": "2",
            "correct": True,
            "elapsed": 3.5,
        }
        restored = service._deserialize_match(service._serialize_match(match))
        self.assertEqual(restored.attempts, match.attempts)
        self.assertEqual(restored.solved, match.solved)
        self.assertEqual(restored.answers, match.answers)
        self.assertEqual(restored.questions[0].tags, ("수학",))

    def test_practice_bot_uses_real_match_and_switches_to_human_match(self) -> None:
        """필요 변수: 두 사용자와 고정 문항. 첫 사용자는 연습 경기에서 풀고 실제 매칭 후 교체 ID를 받는지 검증한다."""

        async def scenario() -> None:
            service = _local_service()
            questions = [
                ArenaQuestion("q-practice-1", "1+1", "multiple_choice", ("2",)),
                ArenaQuestion("q-practice-2", "2+2", "multiple_choice", ("4",)),
            ]
            service._select_questions = lambda _queue_type: questions

            queued = await service.join("u1", "duel_exam", "practice-join-0001")
            practice_id = queued.get("practice_match_id")
            self.assertTrue(practice_id)
            practice = service._matches[str(practice_id)]
            practice.bot_plan[questions[0].id] = (0.0, True)
            practice.bot_plan[questions[1].id] = (9999.0, True)

            practice_state = await service.state("u1", str(practice_id))
            self.assertTrue(practice_state["practice"])
            self.assertEqual(practice_state["scores"]["1"]["correct"], 1)
            self.assertTrue(practice_state["bot_activity"]["correct"])

            matched = await service.join("u2", "duel_exam", "practice-join-0002")
            self.assertEqual(matched["status"], "matched")
            switched = await service.state("u1", str(practice_id))
            self.assertEqual(switched["replacement_match_id"], matched["match_id"])
            retried = await service.join("u1", "duel_exam", "practice-join-0001")
            self.assertEqual(retried["match_id"], matched["match_id"])

        asyncio.run(scenario())

    def test_practice_match_serialization_preserves_bot_plan(self) -> None:
        """필요 변수: 연습 봇 계획과 이벤트. Redis 왕복 뒤 봇 진행 상태가 중복 없이 유지되는지 검증한다."""

        service = _local_service()
        question = ArenaQuestion("q-bot", "O인가", "ox", ("O",))
        match = ArenaMatch(
            "practice-serialize",
            "duel_ox",
            {
                "u1": Participant("u1", 0),
                "bot": Participant("bot", 1),
            },
            [question],
            practice=True,
            bot_user_id="bot",
            bot_tier="B",
            bot_plan={"q-bot": (3.5, False)},
            bot_events=[{"question_id": "q-bot", "correct": False}],
        )

        restored = service._deserialize_match(service._serialize_match(match))
        self.assertTrue(restored.practice)
        self.assertEqual(restored.bot_tier, "B")
        self.assertEqual(restored.bot_plan["q-bot"], (3.5, False))
        self.assertEqual(restored.bot_events[0]["correct"], False)

    def test_bot_profiles_scale_accuracy_and_speed_by_tier(self) -> None:
        """필요 변수: A~E 봇 설정. 상위 티어일수록 정답률이 높고 응답 지연이 짧은지 검증한다."""

        tiers = ["A", "B", "C", "D", "E"]
        accuracies = [_BOT_PROFILES[tier][0] for tier in tiers]
        minimum_delays = [_BOT_PROFILES[tier][1] for tier in tiers]
        maximum_delays = [_BOT_PROFILES[tier][2] for tier in tiers]
        self.assertEqual(accuracies, sorted(accuracies, reverse=True))
        self.assertEqual(minimum_delays, sorted(minimum_delays))
        self.assertEqual(maximum_delays, sorted(maximum_delays))

    def test_cancel_removes_queue_and_practice_match(self) -> None:
        """필요 변수: 대기 사용자와 고정 문항. 연습 화면 이탈 시 실제 큐와 임시 경기를 함께 정리하는지 검증한다."""

        async def scenario() -> None:
            service = _local_service()
            service._select_questions = lambda _queue_type: [
                ArenaQuestion("q-cancel", "1+1", "short", ("2",))
            ]
            queued = await service.join("u-cancel", "duel_exam", "practice-cancel-0001")
            practice_id = str(queued["practice_match_id"])

            result = await service.cancel("u-cancel")
            self.assertTrue(result["cancelled"])
            self.assertNotIn("u-cancel", service._user_queue)
            self.assertNotIn(practice_id, service._matches)

        asyncio.run(scenario())

    def test_bot_win_rewards_rating_and_records_analysis(self) -> None:
        """필요 변수: 사용자가 이긴 한 문항 봇 경기. +20 레이팅·승리 전적·문항 분석을 검증한다."""

        async def scenario() -> None:
            service = _local_service()
            question = ArenaQuestion("q-rating", "1+1", "short", ("2",))
            service._select_questions = lambda _queue_type: [question]
            queued = await service.join("u-rating", "duel_exam", "practice-rating-0001")
            practice_id = str(queued["practice_match_id"])
            match = service._matches[practice_id]
            match.bot_plan[question.id] = (9999.0, True)
            await service.submit(
                "u-rating",
                practice_id,
                question.id,
                "2",
                "practice-rating-answer-0001",
            )

            result = await service.result("u-rating", practice_id)
            self.assertTrue(result["practice"])
            self.assertEqual(service._ratings[("u-rating", "duel_exam")], 1520.0)
            self.assertEqual(service._records[("u-rating", "duel_exam")], ["win"])
            self.assertEqual(result["participants"][0]["rating_delta"], 20.0)
            self.assertEqual(result["participants"][0]["record"], "win")
            self.assertEqual(result["analysis"][0]["team_answers"]["0"]["answer"], "2")

        asyncio.run(scenario())

    def test_decisive_lead_finishes_before_remaining_questions(self) -> None:
        """필요 변수: 4문항 경기. 남은 문항을 모두 맞혀도 역전 불가하면 즉시 종료하는지 검증한다."""

        async def scenario() -> None:
            service = _local_service()
            questions = [ArenaQuestion(f"q{index}", f"문제 {index}", "short", ("1",)) for index in range(4)]
            match = ArenaMatch(
                "decisive-match",
                "duel_exam",
                {"u1": Participant("u1", 0), "u2": Participant("u2", 1)},
                questions,
            )
            service._matches[match.id] = match
            await service.submit("u1", match.id, "q0", "1", "decisive-u1-0001")
            match.submission_events["u1"] = []
            await service.submit("u1", match.id, "q1", "1", "decisive-u1-0002")
            match.submission_events["u2"] = []
            await service.submit("u2", match.id, "q0", "0", "decisive-u2-0001")
            match.submission_events["u2"] = []
            await service.submit("u2", match.id, "q1", "0", "decisive-u2-0002")
            match.submission_events["u2"] = []
            result = await service.submit("u2", match.id, "q2", "0", "decisive-u2-0003")

            self.assertTrue(result["finished"])
            self.assertEqual(result["finish_reason"], "decisive_lead")
            self.assertEqual((await service.result("u1", match.id))["winner_team"], 0)

        asyncio.run(scenario())

    def test_guardrail_and_time_limit_finish_with_explicit_reason(self) -> None:
        """필요 변수: 빠른 연속 제출 경기와 만료 경기. 강제 종료 사유와 승자를 검증한다."""

        async def scenario() -> None:
            service = _local_service()
            questions = [ArenaQuestion(f"g{index}", f"문제 {index}", "short", ("1",)) for index in range(5)]
            guardrail = ArenaMatch(
                "guardrail-match",
                "duel_exam",
                {"u1": Participant("u1", 0), "u2": Participant("u2", 1)},
                questions,
            )
            service._matches[guardrail.id] = guardrail
            await service.submit("u1", guardrail.id, "g0", "0", "guardrail-0001")
            await service.submit("u1", guardrail.id, "g1", "0", "guardrail-0002")
            result = await service.submit("u1", guardrail.id, "g2", "0", "guardrail-0003")
            self.assertTrue(result["abusive"])
            self.assertEqual((await service.result("u2", guardrail.id))["winner_team"], 1)

            timed = ArenaMatch(
                "timed-match",
                "duel_exam",
                {"a": Participant("a", 0), "b": Participant("b", 1)},
                [ArenaQuestion("time-q", "시간 문제", "short", ("1",))],
                started_at=guardrail.started_at - timedelta(seconds=5),
                duration_seconds=1,
            )
            service._matches[timed.id] = timed
            state = await service.state("a", timed.id)
            self.assertTrue(state["finished"])
            self.assertEqual(state["finish_reason"], "time_expired")

        asyncio.run(scenario())

    def test_redis_failure_never_falls_back_to_local_queue(self) -> None:
        """필요 변수: 실패 Redis 저장소. 신규 매칭이 메모리 큐로 우회하지 않는지 검증한다."""

        class BrokenRedis:
            enabled = True

            async def join(self, *_args, **_kwargs):
                raise ArenaStoreUnavailable("redis down")

        async def scenario() -> None:
            service = ArenaService(redis_repository=BrokenRedis())
            with self.assertRaises(ArenaStoreUnavailable):
                await service.join("u1", "duel_exam", "redis-failure-0001")
            self.assertEqual(service._queues["duel_exam"], [])

        asyncio.run(scenario())


if __name__ == "__main__":
    unittest.main()
