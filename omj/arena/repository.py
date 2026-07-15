"""아레나 Redis 실시간 상태와 PostgreSQL 영속 결과 저장소."""

from __future__ import annotations

import asyncio
import json
import os
import time
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Any, AsyncIterator


class ArenaStoreUnavailable(RuntimeError):
    """운영 실시간 저장소가 응답하지 않을 때 신규 매칭을 차단하는 오류."""


class RedisArenaRepository:
    """Redis에서 큐·활성 경기·멱등키·임시 팀 채팅을 공유한다."""

    def __init__(self, url: str | None = None) -> None:
        """필요 변수: 선택 Redis URL. 클라이언트와 단일 health-check 잠금을 지연 사용하도록 준비한다."""

        self.url = (url if url is not None else os.getenv("REDIS_URL", "")).strip()
        self._client: Any | None = None
        self._last_ping_at = 0.0
        self._ping_lock = asyncio.Lock()

    @property
    def enabled(self) -> bool:
        """필요 변수 없음. Redis 운영 모드 활성 여부를 반환한다."""

        return bool(self.url)

    async def _redis(self) -> Any:
        """필요 변수: Redis URL·풀 크기·연결/응답 대기 시간. 제한된 Blocking 풀을 만들고 ping 실패는 운영 오류로 변환한다."""

        if not self.enabled:
            return None
        if self._client is None:
            try:
                from redis.asyncio import BlockingConnectionPool, Redis

                max_connections = max(
                    16,
                    int(os.getenv("ARENA_REDIS_MAX_CONNECTIONS", "256")),
                )
                pool_timeout = max(
                    0.5,
                    float(os.getenv("ARENA_REDIS_POOL_TIMEOUT_SECONDS", "10")),
                )
                pool = BlockingConnectionPool.from_url(
                    self.url,
                    max_connections=max_connections,
                    timeout=pool_timeout,
                    encoding="utf-8",
                    decode_responses=True,
                    socket_connect_timeout=max(
                        1.5,
                        float(
                            os.getenv(
                                "ARENA_REDIS_CONNECT_TIMEOUT_SECONDS",
                                "3",
                            )
                        ),
                    ),
                    socket_timeout=max(
                        2.0,
                        float(os.getenv("ARENA_REDIS_SOCKET_TIMEOUT_SECONDS", "10")),
                    ),
                    health_check_interval=15,
                )
                self._client = Redis.from_pool(pool)
            except Exception as exc:  # pragma: no cover - 선택 의존성 로드 실패
                raise ArenaStoreUnavailable("Redis 클라이언트를 초기화할 수 없습니다.") from exc
        if time.monotonic() - self._last_ping_at >= 5:
            async with self._ping_lock:
                if time.monotonic() - self._last_ping_at >= 5:
                    try:
                        await self._client.ping()
                        self._last_ping_at = time.monotonic()
                    except Exception as exc:
                        self._last_ping_at = 0.0
                        raise ArenaStoreUnavailable(
                            "Redis 연결 장애로 신규 매칭을 중단했습니다."
                        ) from exc
        return self._client

    async def join(
        self,
        user_id: str,
        queue_type: str,
        required: int,
        match_id: str,
        idempotency_key: str,
    ) -> dict[str, Any]:
        """필요 변수: 사용자·큐·필요 인원·예비 경기 ID·멱등키. Lua 한 번으로 중복 검사와 인원 추출을 처리한다."""

        redis = await self._redis()
        script = """
        local cached = redis.call('GET', KEYS[1])
        if cached then return cached end
        if redis.call('EXISTS', KEYS[2]) == 1 or redis.call('EXISTS', KEYS[3]) == 1 then
          return cjson.encode({error='already_active'})
        end
        redis.call('SET', KEYS[3], ARGV[1], 'EX', 1800)
        redis.call('ZADD', KEYS[4], ARGV[2], ARGV[3])
        local result = {status='queued', queue_type=ARGV[1]}
        if redis.call('ZCARD', KEYS[4]) >= tonumber(ARGV[4]) then
          local popped = redis.call('ZPOPMIN', KEYS[4], tonumber(ARGV[4]))
          local users = {}
          for index=1,#popped,2 do
            local member = popped[index]
            table.insert(users, member)
            redis.call('DEL', 'arena:user_queue:' .. member)
            redis.call('SET', 'arena:user_match:' .. member, ARGV[5], 'EX', 1800)
          end
          result = {status='matched', queue_type=ARGV[1], match_id=ARGV[5], users=users}
        end
        local encoded = cjson.encode(result)
        redis.call('SET', KEYS[1], encoded, 'EX', 86400)
        return encoded
        """
        keys = [
            f"arena:idem:join:{user_id}:{idempotency_key}",
            f"arena:user_match:{user_id}",
            f"arena:user_queue:{user_id}",
            f"arena:queue:{queue_type}",
        ]
        raw = await redis.eval(
            script,
            len(keys),
            *keys,
            queue_type,
            str(time.time_ns()),
            user_id,
            str(required),
            match_id,
        )
        result = json.loads(raw)
        if result.get("error") == "already_active":
            raise ValueError("이미 매칭 중이거나 진행 중인 경기가 있습니다.")
        return result

    async def cancel(self, user_id: str) -> bool:
        """필요 변수: 사용자 ID. 사용자 큐 표시와 정렬 집합 항목을 원자적으로 제거한다."""

        redis = await self._redis()
        script = """
        local queue = redis.call('GET', KEYS[1])
        if not queue then return 0 end
        redis.call('ZREM', 'arena:queue:' .. queue, ARGV[1])
        redis.call('DEL', KEYS[1])
        return 1
        """
        return bool(await redis.eval(script, 1, f"arena:user_queue:{user_id}", user_id))

    async def active_match(self, user_id: str) -> str | None:
        """필요 변수: 사용자 ID. 다른 서버에서 성립한 활성 경기 ID까지 조회한다."""

        redis = await self._redis()
        return await redis.get(f"arena:user_match:{user_id}")

    async def queue_length(self, queue_type: str) -> int:
        """필요 변수: 큐 유형. 공유 정렬 집합의 현재 대기 인원을 반환한다."""

        redis = await self._redis()
        return int(await redis.zcard(f"arena:queue:{queue_type}"))

    async def save_match(self, match_id: str, payload: dict[str, Any]) -> None:
        """필요 변수: 경기 ID와 직렬화 상태. 활성 경기 TTL 동안 모든 서버가 같은 상태를 읽게 저장한다."""

        redis = await self._redis()
        await redis.set(f"arena:match:{match_id}", json.dumps(payload, ensure_ascii=False), ex=1800)

    async def idempotent_result(self, user_id: str, key: str) -> dict[str, Any] | None:
        """필요 변수: 사용자·멱등키. 여러 서버에서 공유하는 답안 결과가 있으면 반환한다."""

        redis = await self._redis()
        raw = await redis.get(f"arena:idem:submit:{user_id}:{key}")
        return json.loads(raw) if raw else None

    async def save_idempotent_result(self, user_id: str, key: str, result: dict[str, Any]) -> None:
        """필요 변수: 사용자·멱등키·결과. 답안 재전송에 동일 결과를 주도록 하루 동안 저장한다."""

        redis = await self._redis()
        await redis.set(
            f"arena:idem:submit:{user_id}:{key}",
            json.dumps(result, ensure_ascii=False),
            ex=86400,
        )

    async def load_match(self, match_id: str) -> dict[str, Any] | None:
        """필요 변수: 경기 ID. 공유 활성 경기 JSON을 읽어 반환한다."""

        redis = await self._redis()
        raw = await redis.get(f"arena:match:{match_id}")
        return json.loads(raw) if raw else None

    @asynccontextmanager
    async def match_lock(self, match_id: str) -> AsyncIterator[None]:
        """필요 변수: 경기 ID·잠금 임대/대기 시간. 답안 중복 제출과 상태 유실을 막는 분산 잠금을 제공한다."""

        redis = await self._redis()
        lock = redis.lock(
            f"arena:lock:{match_id}",
            timeout=max(
                8.0,
                float(os.getenv("ARENA_REDIS_LOCK_TTL_SECONDS", "30")),
            ),
            blocking_timeout=max(
                3.0,
                float(os.getenv("ARENA_REDIS_LOCK_WAIT_SECONDS", "10")),
            ),
        )
        acquired = await lock.acquire()
        if not acquired:
            raise ArenaStoreUnavailable("경기 상태 잠금을 획득하지 못했습니다.")
        try:
            yield
        finally:
            try:
                await lock.release()
            except Exception:
                pass

    async def append_chat(self, match_id: str, team: int, item: dict[str, Any]) -> None:
        """필요 변수: 경기·팀·메시지. 팀별 목록을 100개로 제한하고 경기 TTL과 함께 만료한다."""

        redis = await self._redis()
        key = f"arena:chat:{match_id}:{team}"
        pipe = redis.pipeline(transaction=True)
        pipe.rpush(key, json.dumps(item, ensure_ascii=False))
        pipe.ltrim(key, -100, -1)
        pipe.expire(key, 1800)
        await pipe.execute()

    async def chat(self, match_id: str, team: int) -> list[dict[str, Any]]:
        """필요 변수: 경기·팀. 해당 팀의 임시 채팅을 시간순으로 반환한다."""

        redis = await self._redis()
        return [json.loads(value) for value in await redis.lrange(f"arena:chat:{match_id}:{team}", 0, -1)]

    async def finish(self, match_id: str, user_ids: list[str]) -> None:
        """필요 변수: 경기 ID와 참가자. 활성 사용자 키와 팀 채팅을 즉시 제거한다."""

        redis = await self._redis()
        keys = [f"arena:user_match:{value}" for value in user_ids]
        keys.extend([f"arena:chat:{match_id}:0", f"arena:chat:{match_id}:1"])
        if keys:
            await redis.delete(*keys)


class PostgresArenaRepository:
    """종료 경기와 큐별 레이팅을 PostgreSQL 트랜잭션으로 보존한다."""

    def __init__(self, dsn: str | None = None) -> None:
        """필요 변수: 선택 PostgreSQL DSN. 연결 풀은 실제 저장 시 지연 생성한다."""

        self.dsn = (dsn if dsn is not None else os.getenv("DATABASE_URL", "")).strip()
        self._pool: Any | None = None
        self._initialized = False

    async def _ensure_pool(self) -> Any | None:
        """필요 변수: DSN과 UTF-8 스키마 파일. 최소 연결 풀을 만들고 스키마를 한 번 적용한다."""

        if not self.dsn:
            return None
        if self._pool is None:
            from psycopg_pool import AsyncConnectionPool

            self._pool = AsyncConnectionPool(self.dsn, min_size=1, max_size=12, open=False)
            await self._pool.open()
        if not self._initialized:
            schema = Path(__file__).with_name("schema_postgresql.sql").read_text(encoding="utf-8")
            async with self._pool.connection() as connection:
                await connection.execute(schema)
            self._initialized = True
        return self._pool

    async def save_result(self, result: dict[str, Any]) -> None:
        """필요 변수: 종료 결과·참가자·레이팅. 한 트랜잭션으로 경기 원문과 큐별 사용자 레이팅을 upsert한다."""

        pool = await self._ensure_pool()
        if pool is None:
            return
        async with pool.connection() as connection:
            async with connection.transaction():
                await connection.execute(
                    """INSERT INTO arena_match
                    (match_id, queue_type, status, started_at, finished_at, winner_team, idempotency_key, result_json)
                    VALUES (%s, %s, 'finished', %s, %s, %s, %s, %s::jsonb)
                    ON CONFLICT (match_id) DO UPDATE SET status='finished', finished_at=EXCLUDED.finished_at,
                    winner_team=EXCLUDED.winner_team, result_json=EXCLUDED.result_json""",
                    (
                        result["match_id"], result["queue_type"], result["started_at"],
                        result["finished_at"], result.get("winner_team"), f"finish:{result['match_id']}",
                        json.dumps(result, ensure_ascii=False),
                    ),
                )
                for participant in result["participants"]:
                    await connection.execute(
                        """INSERT INTO arena_participant
                        (match_id, user_id, team, contribution, rating_before, rating_after)
                        VALUES (%s, %s, %s, %s, %s, %s)
                        ON CONFLICT (match_id, user_id) DO UPDATE SET contribution=EXCLUDED.contribution,
                        rating_after=EXCLUDED.rating_after""",
                        (
                            result["match_id"], participant["user_id"], participant["team"],
                            participant["contribution"], participant["rating_before"], participant["rating_after"],
                        ),
                    )
                    await connection.execute(
                        """INSERT INTO arena_rating (user_id, queue_type, rating, wins, losses, draws)
                        VALUES (%s, %s, %s, %s, %s, %s)
                        ON CONFLICT (user_id, queue_type) DO UPDATE SET rating=EXCLUDED.rating,
                        wins=arena_rating.wins+EXCLUDED.wins, losses=arena_rating.losses+EXCLUDED.losses,
                        draws=arena_rating.draws+EXCLUDED.draws, updated_at=NOW()""",
                        (
                            participant["user_id"], result["queue_type"], participant["rating_after"],
                            int(participant["record"] == "win"), int(participant["record"] == "loss"),
                            int(participant["record"] == "draw"),
                        ),
                    )

    async def get_result(self, match_id: str, user_id: str) -> dict[str, Any] | None:
        """필요 변수: 경기·사용자 ID. 참가 권한이 있는 영속 경기 결과만 반환한다."""

        pool = await self._ensure_pool()
        if pool is None:
            return None
        async with pool.connection() as connection:
            cursor = await connection.execute(
                """SELECT m.result_json FROM arena_match m
                JOIN arena_participant p ON p.match_id=m.match_id
                WHERE m.match_id=%s AND p.user_id=%s""",
                (match_id, user_id),
            )
            row = await cursor.fetchone()
            return dict(row[0]) if row and row[0] else None
