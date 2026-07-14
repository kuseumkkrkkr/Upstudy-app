import asyncio
import unittest

from arena.grading import grade_answer, max_attempts
from arena.models import ArenaMatch, ArenaQuestion, Participant
from arena.rating import GlickoRating, TrueSkillRating, contribution_multipliers, contribution_score, tier_for_rating, update_glicko2, update_trueskill_teams
from arena.service import ArenaService
from arena.repository import ArenaStoreUnavailable


class ArenaRulesTest(unittest.TestCase):
    """문자열 채점, 레이팅, 기여도와 제출 제한을 검증한다."""

    def test_unicode_nfc_and_exact_comparison(self) -> None:
        self.assertTrue(grade_answer("short", "  가\u0301 ", ["가́"]))
        self.assertFalse(grade_answer("short", "정답 ", ["정 답"]))
        self.assertTrue(grade_answer("multiple_choice", "2", ["2"]))
        self.assertEqual(max_attempts("short"), 5)
        self.assertEqual(max_attempts("ox"), 2)

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

    def test_team_attempt_limit_and_idempotency(self) -> None:
        async def scenario() -> None:
            service = ArenaService()
            question = ArenaQuestion("q1", "1+1", "multiple_choice", ("2",), choices=({"id": "1", "label": "1"}, {"id": "2", "label": "2"}))
            match = ArenaMatch("m1", "duel_exam", {"u1": Participant("u1", 0), "u2": Participant("u2", 1)}, [question])
            service._matches[match.id] = match
            service._user_match.update({"u1": match.id, "u2": match.id})
            first = await service.submit("u1", "m1", "q1", "0", "attempt-0001")
            duplicate = await service.submit("u1", "m1", "q1", "0", "attempt-0001")
            self.assertEqual(first, duplicate)
            await service.submit("u1", "m1", "q1", "1", "attempt-0002")
            with self.assertRaises(ValueError):
                await service.submit("u1", "m1", "q1", "2", "attempt-0003")

        asyncio.run(scenario())

    def test_finished_result_is_authorized_and_persisted_in_service(self) -> None:
        """필요 변수: 한 문항 경기. 양 팀 정답 뒤 결과 조회 권한과 레이팅 결과 생성을 검증한다."""

        async def scenario() -> None:
            service = ArenaService()
            question = ArenaQuestion("q1", "1+1", "short", ("2",))
            match = ArenaMatch(
                "m-result",
                "duel_exam",
                {"u1": Participant("u1", 0), "u2": Participant("u2", 1)},
                [question],
            )
            service._matches[match.id] = match
            await service.submit("u1", match.id, "q1", "2", "result-0001")
            await service.submit("u2", match.id, "q1", "2", "result-0002")
            result = await service.result("u1", match.id)
            self.assertEqual(result["match_id"], match.id)
            self.assertEqual(len(result["participants"]), 2)
            with self.assertRaises(ValueError):
                await service.result("outsider", match.id)

        asyncio.run(scenario())

    def test_match_serialization_preserves_atomic_state(self) -> None:
        """필요 변수: 시도·해결 상태가 있는 경기. Redis 왕복 뒤 동일 상태가 복원되는지 검증한다."""

        service = ArenaService()
        question = ArenaQuestion("q1", "1+1", "short", ("2",), tags=("수학",))
        match = ArenaMatch(
            "m-serialize",
            "duel_exam",
            {"u1": Participant("u1", 0), "u2": Participant("u2", 1)},
            [question],
        )
        match.attempts[(0, "q1")] = 1
        match.solved[(0, "q1")] = ("u1", 3.5)
        restored = service._deserialize_match(service._serialize_match(match))
        self.assertEqual(restored.attempts, match.attempts)
        self.assertEqual(restored.solved, match.solved)
        self.assertEqual(restored.questions[0].tags, ("수학",))

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
