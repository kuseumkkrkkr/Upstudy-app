"""외부 Redis 없이 문제 런타임 캐시의 원자적 큐·통계 동작을 검증한다."""
from __future__ import annotations

import json
import os
import sys
import types
import unittest
from unittest.mock import patch

from services.problem_runtime_cache import ProblemRuntimeCache


class _FakeRedis:
    """필요 변수: 메모리 자료구조. 작동 원리: 테스트에 필요한 Redis List·Set·ZSET 명령만 동일한 형태로 제공한다."""

    def __init__(self) -> None:
        self.lists: dict[str, list[str]] = {}
        self.sets: dict[str, set[str]] = {}
        self.values: dict[str, str] = {}
        self.zsets: dict[str, dict[str, float]] = {}

    def pipeline(self, transaction: bool = False) -> "_FakeRedis":
        return self

    def execute(self) -> list[object]:
        return []

    def setex(self, key: str, _ttl: int, value: str) -> "_FakeRedis":
        self.values[key] = value
        return self

    def sadd(self, key: str, *values: str) -> int:
        target = self.sets.setdefault(key, set())
        before = len(target)
        target.update(values)
        return len(target) - before

    def srem(self, key: str, value: str) -> int:
        target = self.sets.setdefault(key, set())
        if value not in target:
            return 0
        target.remove(value)
        return 1

    def smembers(self, key: str) -> set[str]:
        return set(self.sets.get(key, set()))

    def lpop(self, key: str) -> str | None:
        values = self.lists.get(key, [])
        return values.pop(0) if values else None

    def zadd(self, key: str, values: dict[str, int]) -> "_FakeRedis":
        target = self.zsets.setdefault(key, {})
        target.update({member: float(score) for member, score in values.items()})
        return self

    def zremrangebyscore(self, key: str, minimum: int, maximum: int) -> "_FakeRedis":
        target = self.zsets.setdefault(key, {})
        for member in [member for member, score in target.items() if minimum <= score <= maximum]:
            target.pop(member, None)
        return self

    def zincrby(self, key: str, value: int, member: str) -> "_FakeRedis":
        target = self.zsets.setdefault(key, {})
        target[member] = target.get(member, 0) + value
        return self

    def expire(self, _key: str, _ttl: int) -> "_FakeRedis":
        return self

    def mget(self, keys: list[str]) -> list[str | None]:
        return [self.values.get(key) for key in keys]

    def eval(self, _script: str, _key_count: int, queue_key: str, ids_key: str, *quest_ids: str) -> int:
        added = 0
        for quest_id in quest_ids:
            if self.sadd(ids_key, quest_id):
                self.lists.setdefault(queue_key, []).append(quest_id)
                added += 1
        return added

    def zunionstore(self, destination: str, keys: list[str]) -> "_FakeRedis":
        target: dict[str, float] = {}
        for key in keys:
            for member, score in self.zsets.get(key, {}).items():
                target[member] = target.get(member, 0) + score
        self.zsets[destination] = target
        return self

    def zrevrange(self, key: str, _start: int, end: int, withscores: bool = False) -> list[object]:
        values = sorted(self.zsets.get(key, {}).items(), key=lambda item: item[1], reverse=True)[: end + 1]
        return values if withscores else [member for member, _score in values]

    def zcard(self, key: str) -> int:
        return len(self.zsets.get(key, {}))


class ProblemRuntimeCacheTests(unittest.TestCase):
    """필요 변수: 메모리 Redis 대역. 작동 원리: Redis 미설치 환경에서도 큐 중복 방지와 급상승 집계를 단위 검증한다."""

    def setUp(self) -> None:
        """필요 변수: Fake Redis. 작동 원리: 런타임 캐시의 연결 생성을 건너뛰고 명령 결과만 검증한다."""
        self.cache = ProblemRuntimeCache()
        self.cache._client = _FakeRedis()

    def test_prefetch_queue_deduplicates_and_consumes_in_order(self) -> None:
        """필요 변수: 중복 문제 ID. 작동 원리: Lua 예약은 중복을 한 번만 넣고 다음 요청은 예약 순서대로 꺼내야 한다."""
        self.cache.reserve_prefetch(
            user_id="student-1",
            request_key="비례|3|3",
            quest_ids=["q-1", "q-1", "q-2"],
        )
        self.assertEqual(
            self.cache.take_prefetched(user_id="student-1", request_key="비례|3|3", count=3),
            ["q-1", "q-2"],
        )

    def test_delivery_updates_payload_active_users_and_trending(self) -> None:
        """필요 변수: 동일 문제를 푸는 두 사용자. 작동 원리: payload 캐시·활성 사용자 수·급상승 전달량이 함께 누적돼야 한다."""
        quest = {
            "header": {"quest_id": "q-hot"},
            "data": {"codebase_id": 1, "seed": 2},
        }
        self.cache.record_delivery(user_id="student-1", quest=quest)
        self.cache.record_delivery(user_id="student-2", quest=quest)
        cached = self.cache.load_payloads(["q-hot"])
        trending = self.cache.list_trending(minutes=1, limit=1)
        self.assertEqual(cached["q-hot"], quest)
        self.assertEqual(trending[0]["quest_id"], "q-hot")
        self.assertEqual(trending[0]["deliveries"], 2)
        self.assertEqual(trending[0]["active_users"], 2)

    def test_variant_claim_is_atomic_per_user(self) -> None:
        """필요 변수: 같은 사용자·같은 variant의 연속 선점. 작동 원리: 첫 요청만 성공하고 이후 요청은 중복 제공 후보에서 제외한다."""
        first = self.cache.claim_unserved_variant(user_id="student-1", codebase_id=7, seed=101)
        second = self.cache.claim_unserved_variant(user_id="student-1", codebase_id=7, seed=101)
        other_user = self.cache.claim_unserved_variant(user_id="student-2", codebase_id=7, seed=101)
        self.assertTrue(first)
        self.assertFalse(second)
        self.assertTrue(other_user)
        self.assertEqual(self.cache.list_claimed_variants(user_id="student-1"), {"7:101"})

    def test_redis_connection_failure_uses_retry_circuit_breaker(self) -> None:
        """필요 변수: 반복되는 Redis 연결 실패. 작동 원리: 장애 중 요청마다 직렬 연결을 시도하지 않고 짧은 회로 차단 상태를 유지한다."""
        attempts: list[int] = []

        class _OfflineClient:
            def ping(self) -> None:
                attempts.append(1)
                raise RuntimeError("offline")

        redis_type = types.SimpleNamespace(from_url=lambda *_args, **_kwargs: _OfflineClient())
        module = types.SimpleNamespace(Redis=redis_type)
        cache = ProblemRuntimeCache()
        with (
            patch.dict(
                os.environ,
                {"REDIS_URL": "redis://offline", "REDIS_CONNECT_RETRY_SEC": "30"},
                clear=True,
            ),
            patch.dict(sys.modules, {"redis": module}),
        ):
            self.assertIsNone(cache._get_client())
            self.assertIsNone(cache._get_client())
        self.assertEqual(len(attempts), 1)
