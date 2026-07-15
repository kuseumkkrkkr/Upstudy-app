"""Redis 기반 문제 런타임 캐시와 실시간 풀이 통계 서비스."""
from __future__ import annotations

import json
import os
import time
from threading import Lock
from typing import Any, Optional


class ProblemRuntimeCache:
    """문제 제공·풀이 이벤트를 Redis에 짧게 보관해 DB 쓰기 경합을 줄인다."""

    def __init__(self) -> None:
        self._client: Any = None
        self._lock = Lock()
        self._client_failed_at = 0.0

    def _get_client(self) -> Optional[Any]:
        """필요 변수: REDIS_URL. 작동 원리: Redis 클라이언트를 한 번만 만들고 연결 실패 시 요청 경로를 중단시키지 않는다."""
        if self._client is not None:
            return self._client
        redis_url = os.getenv("REDIS_URL", "").strip()
        if not redis_url:
            return None
        try:
            retry_seconds = max(1.0, float(os.getenv("REDIS_CONNECT_RETRY_SEC", "5")))
        except ValueError:
            retry_seconds = 5.0
        if self._client_failed_at and time.monotonic() - self._client_failed_at < retry_seconds:
            return None
        with self._lock:
            if self._client is not None:
                return self._client
            if self._client_failed_at and time.monotonic() - self._client_failed_at < retry_seconds:
                return None
            try:
                import redis

                client = redis.Redis.from_url(
                    redis_url,
                    decode_responses=True,
                    socket_connect_timeout=0.2,
                    socket_timeout=0.2,
                    health_check_interval=30,
                )
                client.ping()
                self._client = client
                self._client_failed_at = 0.0
            except Exception:
                self._client = None
                self._client_failed_at = time.monotonic()
        return self._client

    def ping(self) -> bool:
        """필요 변수: Redis 연결. 작동 원리: 준비 상태 점검에서 실제 PING 성공 여부만 노출한다."""
        client = self._get_client()
        if client is None:
            return False
        try:
            return bool(client.ping())
        except Exception:
            return False

    def record_delivery(self, *, user_id: str, quest: dict[str, Any]) -> None:
        """필요 변수: 사용자와 문제 payload. 작동 원리: payload·활성 사용자·분 단위 조회량을 파이프라인으로 갱신한다."""
        client = self._get_client()
        if client is None:
            return
        header = quest.get("header") if isinstance(quest, dict) else {}
        data = quest.get("data") if isinstance(quest, dict) else {}
        quest_id = str((header or {}).get("quest_id") or "").strip()
        if not quest_id:
            return
        now = int(time.time())
        active_cutoff = now - 30 * 60
        minute_bucket = now - (now % 60)
        codebase_id = (data or {}).get("codebase_id")
        seed = (data or {}).get("seed")
        try:
            pipe = client.pipeline(transaction=False)
            pipe.setex(f"problem:payload:{quest_id}", 900, json.dumps(quest, ensure_ascii=False))
            pipe.zadd(f"problem:active:{quest_id}", {user_id: now})
            pipe.zremrangebyscore(f"problem:active:{quest_id}", 0, active_cutoff)
            pipe.expire(f"problem:active:{quest_id}", 3600)
            pipe.zincrby(f"problem:trending:{minute_bucket}", 1, quest_id)
            pipe.expire(f"problem:trending:{minute_bucket}", 3600)
            if codebase_id is not None and seed is not None:
                pipe.sadd(f"problem:served:{user_id}", f"{codebase_id}:{seed}")
                pipe.expire(f"problem:served:{user_id}", 60 * 24 * 60 * 60)
            pipe.execute()
        except Exception:
            # Redis 장애는 문제 풀이 자체를 막지 않고 PostgreSQL/기존 DB 경로로 계속 처리한다.
            return

    def record_solved(self, *, user_id: str, codebase_id: int, seed: str) -> None:
        """필요 변수: 사용자·codebase·seed. 작동 원리: 최근 풀이 중복 제외용 Set을 즉시 갱신해 다음 문제 선택에 반영한다."""
        client = self._get_client()
        if client is None:
            return
        try:
            key = f"problem:served:{user_id}"
            client.sadd(key, f"{codebase_id}:{seed}")
            client.expire(key, 60 * 24 * 60 * 60)
        except Exception:
            return

    def claim_unserved_variant(self, *, user_id: str, codebase_id: int, seed: object) -> bool:
        """필요 변수: 사용자·codebase·seed. 작동 원리: Redis Set의 원자적 SADD로 아직 제공하지 않은 variant 하나만 동시 요청 중 승자에게 배정한다."""
        client = self._get_client()
        if client is None:
            # Redis 장애 시 PostgreSQL/SQLite fallback 가용성을 유지한다. 준비 상태 점검은 해당 인스턴스를 트래픽에서 제외한다.
            return True
        try:
            key = f"problem:served:{user_id}"
            claimed = int(client.sadd(key, f"{int(codebase_id)}:{int(seed)}")) == 1
            client.expire(key, 60 * 24 * 60 * 60)
            return claimed
        except (TypeError, ValueError):
            return False
        except Exception:
            return True

    def list_claimed_variants(self, *, user_id: str) -> set[str]:
        """필요 변수: 사용자 ID. 작동 원리: Redis에서 아직 풀이 이력으로 굳지 않은 제공 variant를 읽어 PostgreSQL 후보 SQL에서 제외한다."""
        client = self._get_client()
        if client is None:
            return set()
        try:
            return {str(value) for value in client.smembers(f"problem:served:{user_id}")}
        except Exception:
            return set()

    def take_prefetched(self, *, user_id: str, request_key: str, count: int) -> list[str]:
        """필요 변수: 사용자·요청 키·문항 수. 작동 원리: Redis List에서 미리 예약한 문제 ID를 먼저 꺼내 사용자별 DB 쓰기를 제거한다."""
        client = self._get_client()
        if client is None or count < 1:
            return []
        queue_key = f"problem:queue:{user_id}:{request_key}"
        ids_key = f"problem:queue_ids:{user_id}:{request_key}"
        result: list[str] = []
        try:
            for _ in range(count):
                quest_id = client.lpop(queue_key)
                if not quest_id:
                    break
                client.srem(ids_key, quest_id)
                result.append(str(quest_id))
            return result
        except Exception:
            return []

    def reserve_prefetch(self, *, user_id: str, request_key: str, quest_ids: list[str]) -> None:
        """필요 변수: 사용자·요청 키·문제 ID. 작동 원리: Set으로 중복 예약을 막고 List에 다음 문제를 넣어 이후 요청을 즉시 응답한다."""
        client = self._get_client()
        if client is None or not quest_ids:
            return
        queue_key = f"problem:queue:{user_id}:{request_key}"
        ids_key = f"problem:queue_ids:{user_id}:{request_key}"
        try:
            # Set 추가와 List 삽입을 Lua 한 번으로 묶어 여러 서버가 동시에 예약해도 중복을 막는다.
            client.eval(
                """
                local added = 0
                for index = 1, #ARGV do
                    if redis.call('SADD', KEYS[2], ARGV[index]) == 1 then
                        redis.call('RPUSH', KEYS[1], ARGV[index])
                        added = added + 1
                    end
                end
                redis.call('EXPIRE', KEYS[1], 3600)
                redis.call('EXPIRE', KEYS[2], 3600)
                return added
                """,
                2,
                queue_key,
                ids_key,
                *quest_ids,
            )
        except Exception:
            return

    def load_payloads(self, quest_ids: list[str]) -> dict[str, dict[str, Any]]:
        """필요 변수: 문제 ID 목록. 작동 원리: Redis MGET으로 문제 payload를 한 번에 읽어 PostgreSQL 원본 조회를 줄인다."""
        client = self._get_client()
        if client is None or not quest_ids:
            return {}
        try:
            values = client.mget([f"problem:payload:{quest_id}" for quest_id in quest_ids])
        except Exception:
            return {}
        result: dict[str, dict[str, Any]] = {}
        for quest_id, raw_value in zip(quest_ids, values):
            if not raw_value:
                continue
            try:
                payload = json.loads(raw_value)
            except (TypeError, json.JSONDecodeError):
                continue
            if isinstance(payload, dict):
                result[quest_id] = payload
        return result

    def cache_payloads(self, quests: list[dict[str, Any]]) -> None:
        """필요 변수: 문제 payload 목록. 작동 원리: PostgreSQL에서 읽은 payload를 Redis에 일괄 저장해 다음 사용자 요청을 메모리에서 처리한다."""
        client = self._get_client()
        if client is None:
            return
        try:
            pipe = client.pipeline(transaction=False)
            for quest in quests:
                quest_id = str(((quest.get("header") or {}).get("quest_id") or "")).strip()
                if quest_id:
                    pipe.setex(f"problem:payload:{quest_id}", 900, json.dumps(quest, ensure_ascii=False))
            pipe.execute()
        except Exception:
            return

    def list_trending(self, *, minutes: int = 15, limit: int = 20) -> list[dict[str, Any]]:
        """필요 변수: 집계 시간·개수. 작동 원리: 최근 분 단위 ZSET을 합산해 급상승 문제와 현재 활성 풀이 수를 반환한다."""
        client = self._get_client()
        if client is None:
            return []
        now = int(time.time())
        minutes = max(1, min(60, minutes))
        limit = max(1, min(100, limit))
        bucket = now - (now % 60)
        keys = [f"problem:trending:{bucket - offset * 60}" for offset in range(minutes)]
        temporary_key = f"problem:trending:window:{bucket}:{minutes}"
        try:
            client.zunionstore(temporary_key, keys)
            client.expire(temporary_key, 65)
            ranked = client.zrevrange(temporary_key, 0, limit - 1, withscores=True)
            active_cutoff = now - 30 * 60
            result: list[dict[str, Any]] = []
            for quest_id, score in ranked:
                active_key = f"problem:active:{quest_id}"
                client.zremrangebyscore(active_key, 0, active_cutoff)
                result.append(
                    {
                        "quest_id": quest_id,
                        "deliveries": int(score),
                        "active_users": int(client.zcard(active_key)),
                    }
                )
            return result
        except Exception:
            return []


problem_runtime_cache = ProblemRuntimeCache()
