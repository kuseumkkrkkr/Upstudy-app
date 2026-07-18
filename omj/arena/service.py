"""대결장 매칭, 출제, 제출, 채팅을 조정하는 서비스."""

from __future__ import annotations

import asyncio
import json
import random
import sqlite3
import time
import uuid
from datetime import datetime, timedelta
from typing import Any

from storage.storage import DB_PATH
from storage.ox_quiz_storage import fetch_random_questions

from .grading import grade_answer, is_numeric_answer
from .models import (
    ArenaMatch,
    ArenaQuestion,
    JOINABLE_QUEUE_TYPES,
    PUBLIC_QUEUE_TYPES,
    Participant,
    QUEUE_TYPES,
    utc_now,
)
from .rating import (
    GlickoRating,
    TrueSkillRating,
    contribution_multipliers,
    contribution_score,
    tier_for_rating,
    update_glicko2,
    update_trueskill_teams,
)
from .repository import PostgresArenaRepository, RedisArenaRepository


_BOT_PROFILES: dict[str, tuple[float, float, float]] = {
    "A": (0.88, 2.4, 5.2),
    "B": (0.78, 3.5, 7.2),
    "C": (0.68, 5.0, 9.5),
    "D": (0.58, 6.5, 12.0),
    "E": (0.48, 8.0, 15.0),
}

BOT_MATCH_WAIT_SECONDS = 5
INACTIVE_FORFEIT_SECONDS = 6 * 60
ANTI_CHEAT_WINDOW_SECONDS = 10
ANTI_CHEAT_MAX_SUBMISSIONS = 3
QUESTION_LOAD_TIMEOUT_SECONDS = 0.75
QUESTION_CACHE_SECONDS = 30
BOT_WIN_RATING_REWARD = 20.0
BOT_LOSS_RATING_PENALTY = 10.0


def _block_text(value: Any, *, preserve_latex: bool = False) -> str:
    """필요 변수: 콘텐츠 블록 자료와 수식 보존 여부.

    작동 원리: 정답 판정용 문자열은 순수 텍스트로 평탄화하고, 화면 표시용
    문제·선택지는 latex/formula/math 블록을 인라인 수식 구분자로 감싸
    Flutter 수식 렌더러가 원래 블록 타입을 복원할 수 있게 한다.
    """

    if isinstance(value, str):
        return value
    if isinstance(value, dict):
        if "content" in value:
            content = str(value.get("content") or "")
            block_type = str(value.get("type") or "text").lower()
            if preserve_latex and block_type in {"latex", "formula", "math"} and content.strip():
                return rf"\({content.strip()}\)"
            return content
        return "".join(
            _block_text(item, preserve_latex=preserve_latex)
            for item in value.get("blocks", [])
        )
    if isinstance(value, list):
        return " ".join(
            _block_text(item, preserve_latex=preserve_latex)
            for item in value
        )
    return "" if value is None else str(value)


def _quest_question(raw: dict[str, Any]) -> ArenaQuestion | None:
    """필요 변수: 기존 quest 자료. 객관식 또는 숫자 직접 입력 문항만 변환하고 서술형은 제외한다."""

    data, info = raw.get("data") or {}, raw.get("info") or {}
    prompt = _block_text(data.get("quest_title"), preserve_latex=True).strip()
    answer = _block_text(data.get("quest_answer")).strip()
    options = data.get("quest_options") or []
    answer_index = data.get("choice_answer_index")
    if options and answer_index is not None:
        choices = tuple(
            {
                "id": str(index),
                "label": _block_text(value, preserve_latex=True),
            }
            for index, value in enumerate(options)
        )
        accepted, answer_type = (str(answer_index),), "multiple_choice"
    elif answer and is_numeric_answer(answer):
        choices, accepted, answer_type = (), (answer,), "short"
    else:
        return None
    if not prompt:
        return None
    tags = tuple(str(value) for value in (data.get("hash_tag") or info.get("hash_tag") or []))
    return ArenaQuestion(
        id=str((raw.get("header") or {}).get("quest_id") or uuid.uuid4()),
        prompt=prompt,
        answer_type=answer_type,
        accepted_answers=accepted,
        choices=choices,
        difficulty=max(1.0, float(info.get("difficulty") or 1.0)),
        tags=tags,
    )


def _temporary_multiple_choice(question: ArenaQuestion, index: int) -> ArenaQuestion:
    """필요 변수: 숫자 단답형 문항·임시 문항 번호.

    작동 원리: 코드베이스 조립 결과 객관식이 부족할 때 숫자 정답 주변에
    서로 다른 오답을 생성하고, 정답 선택지의 ID를 서버 정답으로 고정한다.
    원본 단답형은 보존하므로 시험에 객관식과 단답형을 모두 구성할 수 있다.
    """

    value = float(question.accepted_answers[0])
    step = 1.0 if value.is_integer() else 0.5
    candidates = [value, value + step, value - step, value + step * 2]
    labels: list[str] = []
    for candidate in candidates:
        label = str(int(candidate)) if candidate.is_integer() else f"{candidate:.2f}".rstrip("0").rstrip(".")
        if label not in labels:
            labels.append(label)
    while len(labels) < 4:
        labels.append(str(len(labels) + 1))
    random.shuffle(labels)
    correct_label = str(int(value)) if value.is_integer() else f"{value:.2f}".rstrip("0").rstrip(".")
    choices = tuple({"id": str(choice_index), "label": label} for choice_index, label in enumerate(labels))
    correct_id = str(labels.index(correct_label))
    return ArenaQuestion(
        id=f"{question.id}-temporary-choice-{index}",
        prompt=question.prompt,
        answer_type="multiple_choice",
        accepted_answers=(correct_id,),
        choices=choices,
        difficulty=question.difficulty,
        tags=question.tags,
        base_correct_xp=question.base_correct_xp,
        base_wrong_xp=question.base_wrong_xp,
    )


def _arena_quest_rows(limit: int = 160) -> list[dict[str, Any]]:
    """필요 변수: 최대 문항 수.

    작동 원리: 대결장 시작 시 전체 문제를 하나씩 복원하는 기존 검색 대신,
    SQLite에서 필요한 열만 제한 개수로 읽는다. 잠금·지연 시 빈 목록을 반환해
    호출자가 경량 기본 문항으로 즉시 전환할 수 있게 한다.
    """

    try:
        connection = sqlite3.connect(DB_PATH, timeout=0.2)
        connection.row_factory = sqlite3.Row
        rows = connection.execute(
            """
            SELECT quest_id, quest_title, quest_answer, quest_options,
                   choice_answer_index, hash_tag, meta_json
            FROM quest_data
            WHERE quest_title IS NOT NULL AND quest_answer IS NOT NULL
            LIMIT ?
            """,
            (max(10, min(limit, 200)),),
        ).fetchall()
        connection.close()
    except sqlite3.Error:
        return []

    result: list[dict[str, Any]] = []
    for row in rows:
        def decode(value: Any, default: Any) -> Any:
            if not isinstance(value, str):
                return default if value is None else value
            try:
                return json.loads(value)
            except json.JSONDecodeError:
                return value

        meta = decode(row["meta_json"], {})
        result.append({
            "header": {"quest_id": str(row["quest_id"])},
            "data": {
                "quest_title": decode(row["quest_title"], row["quest_title"]),
                "quest_answer": decode(row["quest_answer"], row["quest_answer"]),
                "quest_options": decode(row["quest_options"], []),
                "choice_answer_index": row["choice_answer_index"],
                "hash_tag": decode(row["hash_tag"], []),
            },
            "info": meta if isinstance(meta, dict) else {},
        })
    return result


class ArenaService:
    """공유 상태는 asyncio 잠금 아래 변경한다. 운영 어댑터는 같은 원자 연산을 Redis로 교체할 수 있다."""

    def __init__(
        self,
        redis_repository: RedisArenaRepository | None = None,
        postgres_repository: PostgresArenaRepository | None = None,
    ) -> None:
        """필요 변수: 선택 Redis·PostgreSQL 저장소. 미지정 시 환경 변수 기반 운영 저장소를 구성한다."""

        self._lock = asyncio.Lock()
        self._redis = redis_repository or RedisArenaRepository()
        self._postgres = postgres_repository or PostgresArenaRepository()
        self._queues: dict[str, list[str]] = {name: [] for name in QUEUE_TYPES}
        self._user_queue: dict[str, str] = {}
        self._user_match: dict[str, str] = {}
        self._user_practice: dict[str, str] = {}
        self._matches: dict[str, ArenaMatch] = {}
        self._ratings: dict[tuple[str, str], float] = {}
        self._glicko: dict[tuple[str, str], GlickoRating] = {}
        self._trueskill: dict[tuple[str, str], TrueSkillRating] = {}
        self._records: dict[tuple[str, str], list[str]] = {}
        self._idempotency: dict[tuple[str, str], dict[str, Any]] = {}
        self._chat: dict[tuple[str, int], list[dict[str, Any]]] = {}
        self._finished_results: dict[str, dict[str, Any]] = {}
        self._practice_question_cache: dict[str, tuple[float, tuple[ArenaQuestion, ...]]] = {}
        self._question_load_tasks: dict[str, asyncio.Task[list[ArenaQuestion]]] = {}
        self._persisted_records: dict[tuple[str, str], dict[str, int]] = {}

    async def _hydrate_profiles(
        self,
        user_ids: list[str],
        queue_types: list[str],
        *,
        force: bool = False,
    ) -> None:
        """필요 변수: 사용자·큐 목록과 강제 갱신 여부.

        작동 원리: PostgreSQL의 기본키 조회 한 번으로 레이팅 상태를 현재 웹
        프로세스에 복원한다. 경기 생성은 누락 항목만, 요약 화면은 영속 값을
        강제로 갱신해 여러 서버 사이의 승급 결과를 일관되게 보여 준다.
        """

        if not self._postgres.dsn:
            return
        targets = [
            user_id
            for user_id in dict.fromkeys(user_ids)
            if force
            or any((user_id, queue_type) not in self._ratings for queue_type in queue_types)
        ]
        if not targets:
            return
        profiles = await self._postgres.profiles(targets, list(dict.fromkeys(queue_types)))
        for key, profile in profiles.items():
            rating = float(profile["rating"])
            self._ratings[key] = rating
            self._glicko[key] = GlickoRating(
                rating,
                float(profile["deviation"]),
                float(profile["volatility"]),
            )
            self._trueskill[key] = TrueSkillRating(
                float(profile["mu"]),
                float(profile["sigma"]),
            )
            self._persisted_records[key] = {
                "wins": int(profile["wins"]),
                "losses": int(profile["losses"]),
                "draws": int(profile["draws"]),
            }

    async def summary(self, user_id: str) -> dict[str, Any]:
        """필요 변수: 사용자 ID. 공개된 1v1·2v2 문제풀이 카드 정보만 반환한다."""

        await self._hydrate_profiles([user_id], list(PUBLIC_QUEUE_TYPES), force=True)
        result = []
        for queue_type in PUBLIC_QUEUE_TYPES:
            rating = self._ratings.get((user_id, queue_type), 1500.0)
            records = self._records.get((user_id, queue_type), [])[-10:]
            persisted = self._persisted_records.get((user_id, queue_type))
            result.append({
                "queue_type": queue_type,
                "rating": rating,
                "tier": tier_for_rating(rating),
                "wins": persisted["wins"] if persisted else records.count("win"),
                "losses": persisted["losses"] if persisted else records.count("loss"),
                "draws": persisted["draws"] if persisted else records.count("draw"),
                "recent_results": records,
                "coming_soon": queue_type not in JOINABLE_QUEUE_TYPES,
                "estimated_wait_seconds": max(
                    5,
                    25
                    - (
                        await self._redis.queue_length(queue_type)
                        if self._redis.enabled
                        else len(self._queues[queue_type])
                    )
                    * 5,
                ),
            })
        active_match_id = (
            await self._redis.active_match(user_id)
            if self._redis.enabled
            else self._user_match.get(user_id)
        )
        active_practice_match_id = (
            await self._redis.practice_match(user_id)
            if self._redis.enabled
            else self._user_practice.get(user_id)
        )
        return {
            "queues": result,
            "active_match_id": active_match_id,
            "active_practice_match_id": active_practice_match_id,
        }

    async def rankings(self, queue_type: str, limit: int = 100) -> list[dict[str, Any]]:
        """필요 변수: 큐 유형·표시 개수. 실제 사용자 레이팅만 점수 내림차순으로 제공한다."""

        if queue_type not in JOINABLE_QUEUE_TYPES:
            raise ValueError("현재 사용할 수 없는 대결 방식입니다.")
        if self._postgres.dsn:
            persisted = await self._postgres.rankings(queue_type, limit)
            if persisted:
                return persisted
        rows = [
            {
                "user_id": user_id,
                "rating": rating,
                "wins": self._records.get((user_id, queue_type), []).count("win"),
                "losses": self._records.get((user_id, queue_type), []).count("loss"),
                "draws": self._records.get((user_id, queue_type), []).count("draw"),
            }
            for (user_id, stored_queue), rating in self._ratings.items()
            if stored_queue == queue_type
        ]
        return sorted(rows, key=lambda item: (-float(item["rating"]), str(item["user_id"])))[:limit]

    async def join(self, user_id: str, queue_type: str, idempotency_key: str) -> dict[str, Any]:
        """필요 변수: 사용자·큐·멱등키. 중복 참가를 차단하고 인원이 차면 한 경기를 원자적으로 만든다."""

        if queue_type not in JOINABLE_QUEUE_TYPES:
            raise ValueError("현재 사용할 수 없는 대결 방식입니다.")
        required = 4 if queue_type.startswith("team_") else 2
        if self._redis.enabled:
            match_id = uuid.uuid4().hex
            result = await self._redis.join(
                user_id,
                queue_type,
                required,
                match_id,
                idempotency_key,
            )
            users = [str(value) for value in result.pop("users", [])]
            if result.get("status") == "queued":
                active_match_id = await self._redis.active_match(user_id)
                if active_match_id:
                    await self._redis.detach_practice(user_id)
                    return {
                        "status": "matched",
                        "queue_type": queue_type,
                        "match_id": active_match_id,
                    }
            if result.get("status") == "matched":
                match = await self._create_match(match_id, queue_type, users)
                self._matches[match_id] = match
                await self._redis.save_match(match_id, self._serialize_match(match))
                for value in users:
                    await self._redis.detach_practice(value)
            else:
                try:
                    practice_id = await self._ensure_redis_practice(user_id, queue_type)
                except Exception:
                    await self._redis.cancel(user_id)
                    raise
                result["practice_match_id"] = practice_id
            return result
        cache_key = (user_id, idempotency_key)
        async with self._lock:
            if cache_key in self._idempotency:
                cached = self._idempotency[cache_key]
                active_match_id = self._user_match.get(user_id)
                if cached.get("status") == "queued" and active_match_id:
                    return {
                        "status": "matched",
                        "queue_type": queue_type,
                        "match_id": active_match_id,
                    }
                return cached
            if user_id in self._user_match or user_id in self._user_queue:
                raise ValueError("이미 매칭 중이거나 진행 중인 경기가 있습니다.")
            self._queues[queue_type].append(user_id)
            self._user_queue[user_id] = queue_type
            result: dict[str, Any] = {"status": "queued", "queue_type": queue_type}
            if len(self._queues[queue_type]) >= required:
                users = self._queues[queue_type][:required]
                del self._queues[queue_type][:required]
                for value in users:
                    self._user_queue.pop(value, None)
                match_id = uuid.uuid4().hex
                match = await self._create_match(match_id, queue_type, users)
                self._matches[match_id] = match
                for value in users:
                    self._user_match[value] = match_id
                    self._user_practice.pop(value, None)
                result = {"status": "matched", "queue_type": queue_type, "match_id": match_id}
            else:
                try:
                    practice = await self._create_practice_match(user_id, queue_type)
                except Exception:
                    self._queues[queue_type].remove(user_id)
                    self._user_queue.pop(user_id, None)
                    raise
                self._matches[practice.id] = practice
                self._user_practice[user_id] = practice.id
                result["practice_match_id"] = practice.id
            self._idempotency[cache_key] = result
            return result

    async def _ensure_redis_practice(self, user_id: str, queue_type: str) -> str:
        """필요 변수: 대기 사용자·큐. 분산 잠금으로 사용자당 연습 경기를 하나만 만들고 Redis에 공유한다."""

        lock_id = f"practice-user-{user_id}"
        async with self._redis.match_lock(lock_id):
            existing = await self._redis.practice_match(user_id)
            if existing:
                return existing
            match = await self._create_practice_match(user_id, queue_type)
            self._matches[match.id] = match
            await self._redis.save_match(match.id, self._serialize_match(match))
            await self._redis.save_practice(user_id, match.id)
            return match.id

    async def cancel(self, user_id: str) -> dict[str, Any]:
        """필요 변수: 사용자 ID.

        작동 원리: 실전 경기 키는 보존하고, 실제 큐와 연습 봇 연결만 원자적으로
        제거한다. 매칭 완료와 취소가 겹치면 취소 결과에 활성 경기 ID를 함께
        반환해 클라이언트가 이미 시작된 경기를 놓치지 않게 한다.
        """

        if self._redis.enabled:
            active_match_id = await self._redis.active_match(user_id)
            if active_match_id:
                payload = await self._redis.load_match(active_match_id)
                elapsed = 0.0
                if payload and payload.get("started_at"):
                    elapsed = max(
                        0.0,
                        (utc_now() - datetime.fromisoformat(str(payload["started_at"]))).total_seconds(),
                    )
                if elapsed <= 3:
                    users = [str(value) for value in (payload or {}).get("participants", {})]
                    await self._redis.finish(active_match_id, users)
                    return {"cancelled": True, "active_match_id": None}
                return {"cancelled": False, "active_match_id": active_match_id}
            practice_match_id = await self._redis.practice_match(user_id)
            if practice_match_id:
                payload = await self._redis.load_match(practice_match_id)
                if payload and payload.get("started_at"):
                    elapsed = max(
                        0.0,
                        (utc_now() - datetime.fromisoformat(str(payload["started_at"]))).total_seconds(),
                    )
                    if elapsed > 3:
                        return {"cancelled": False, "active_match_id": None}
            cancelled = await self._redis.cancel(user_id)
            if not active_match_id:
                await self._redis.discard_practice(user_id)
            return {
                "cancelled": cancelled or (practice_match_id is not None and not active_match_id),
                "active_match_id": active_match_id,
            }
        async with self._lock:
            active_match_id = self._user_match.get(user_id)
            if active_match_id:
                match = self._matches.get(active_match_id)
                elapsed = (
                    (utc_now() - match.started_at).total_seconds()
                    if match is not None
                    else 4
                )
                if elapsed <= 3 and match is not None:
                    for participant in match.participants.values():
                        self._user_match.pop(participant.user_id, None)
                    self._matches.pop(active_match_id, None)
                    return {"cancelled": True, "active_match_id": None}
                return {"cancelled": False, "active_match_id": active_match_id}
            practice_match_id = self._user_practice.get(user_id)
            if practice_match_id:
                practice = self._matches.get(practice_match_id)
                if (
                    practice is not None
                    and (utc_now() - practice.started_at).total_seconds() > 3
                ):
                    return {"cancelled": False, "active_match_id": None}
            queue_type = self._user_queue.pop(user_id, None)
            if queue_type and user_id in self._queues[queue_type]:
                self._queues[queue_type].remove(user_id)
            practice_id = self._user_practice.pop(user_id, None)
            if practice_id is not None:
                self._matches.pop(practice_id, None)
            return {
                "cancelled": queue_type is not None or practice_id is not None,
                "active_match_id": self._user_match.get(user_id),
            }

    async def state(self, user_id: str, match_id: str) -> dict[str, Any]:
        """필요 변수: 사용자·경기 ID.

        작동 원리: 상태 조회 자체를 접속 신호로 기록한다. 경기 시작 5초 뒤
        아직 한 번도 접속하지 않은 상대는 봇으로 대체하고, 6분 동안 답안
        활동이 없는 이탈 사용자는 몰수패 처리한다.
        """

        # 여러 웹 프로세스의 접속·봇 전환 상태를 놓치지 않도록 Redis 운영 모드에서는 최신 경기만 읽는다.
        match = await self._load_authorized_match(
            user_id,
            match_id,
            force_redis=self._redis.enabled,
        )
        elapsed = max(0.0, (utc_now() - match.started_at).total_seconds())
        connection_changed = user_id not in match.connected_users
        match.connected_users.add(user_id)
        match.last_seen_at[user_id] = time.time()
        if self._redis.enabled:
            await self._redis.touch_presence(match.id, user_id)
        replacement_changed = False
        if not match.practice and elapsed >= BOT_MATCH_WAIT_SECONDS:
            replacement_changed = await self._replace_missing_opponent_with_bot(match, user_id)
            if (connection_changed or replacement_changed) and self._redis.enabled:
                await self._redis.save_match(match_id, self._serialize_match(match))
        elif connection_changed and self._redis.enabled:
            await self._redis.save_match(match_id, self._serialize_match(match))
        if match.bot_user_id is not None and self._practice_bot_has_due_answer(match):
            if self._redis.enabled:
                async with self._redis.match_lock(match_id):
                    match = await self._load_authorized_match(user_id, match_id, force_redis=True)
                    changed = await self._advance_practice_bot(match)
                    if changed:
                        await self._redis.save_match(match_id, self._serialize_match(match))
            else:
                async with self._lock:
                    match = await self._load_authorized_match(user_id, match_id)
                    await self._advance_practice_bot(match)
        if match.practice and not match.bot_fallback and elapsed >= BOT_MATCH_WAIT_SECONDS:
            await self._close_waiting_queue(user_id)
        if not match.finished:
            await self._check_inactive_forfeit(match, user_id)
        if not match.finished and utc_now() >= match.started_at + timedelta(seconds=match.duration_seconds):
            match.finish_reason = "time_expired"
            await self._finish(match)
        elapsed = (utc_now() - match.started_at).total_seconds()
        participant = match.participants[user_id]
        replacement_match_id = None
        if match.practice and not match.bot_fallback:
            replacement_match_id = (
                await self._redis.active_match(user_id)
                if self._redis.enabled
                else self._user_match.get(user_id)
            )
        return {
            "match_id": match.id,
            "queue_type": match.queue_type,
            "practice": match.practice,
            "bot_fallback": match.bot_fallback,
            "waiting_for_opponent": bool(
                not match.practice
                and elapsed < BOT_MATCH_WAIT_SECONDS
                and len(match.connected_users) < len(match.participants)
            ),
            "finish_reason": match.finish_reason,
            "bot_tier": match.bot_tier,
            "bot_win_rating_reward": BOT_WIN_RATING_REWARD,
            "bot_loss_rating_penalty": BOT_LOSS_RATING_PENALTY,
            "bot_activity": match.bot_events[-1] if match.bot_events else None,
            "replacement_match_id": replacement_match_id,
            "team": participant.team,
            "remaining_seconds": max(0, match.duration_seconds - int(elapsed)),
            "questions": [question.public_dict() for question in match.questions],
            "participants": [
                {
                    "user_id": item.user_id,
                    "team": item.team,
                    "is_bot": item.user_id == match.bot_user_id,
                    "strong_tags": item.strong_tags,
                    "weak_tags": item.weak_tags,
                }
                for item in match.participants.values()
            ],
            "scores": self._scores(match),
            "submitted_question_ids": [
                question.id
                for question in match.questions
                if (participant.team, question.id) in match.attempts
            ],
            "finished": match.finished,
            "chat": (
                await self._redis.chat(match.id, participant.team)
                if self._redis.enabled
                else list(self._chat.get((match.id, participant.team), []))
            ),
        }

    async def _close_waiting_queue(self, user_id: str) -> None:
        """필요 변수: 봇 경기로 전환된 사용자 ID.

        작동 원리: 5초 대기 뒤 봇 경기가 시작되면 실제 사용자 큐만 제거한다.
        이미 진행된 봇 세션은 유지해 늦게 들어온 사람이 중간 경기를 가로채지 못하게 한다.
        """

        if self._redis.enabled:
            await self._redis.cancel(user_id)
            return
        queue_type = self._user_queue.pop(user_id, None)
        if queue_type and user_id in self._queues[queue_type]:
            self._queues[queue_type].remove(user_id)

    def _practice_bot_has_due_answer(self, match: ArenaMatch) -> bool:
        """필요 변수: 연습 경기. 다음 봇 답안 시각이 지난 경우에만 분산 잠금이 필요하다고 판정한다."""

        if not match.practice or match.finished or match.bot_user_id is None:
            return False
        participant = match.participants[match.bot_user_id]
        elapsed = max(0.0, (utc_now() - match.started_at).total_seconds())
        return any(
            question.id in match.bot_plan
            and match.bot_plan[question.id][0] <= elapsed
            and (participant.team, question.id) not in match.attempts
            for question in match.questions
        )

    async def _advance_practice_bot(self, match: ArenaMatch) -> bool:
        """필요 변수: 연습 경기와 서버 경과 시간. 예정 시각이 지난 봇 정오답을 팀 점수에 한 번만 반영한다."""

        if not match.practice or match.finished or match.bot_user_id is None:
            return False
        elapsed = max(0.0, (utc_now() - match.started_at).total_seconds())
        changed = False
        for index, question in enumerate(match.questions):
            planned = match.bot_plan.get(question.id)
            team_key = (match.participants[match.bot_user_id].team, question.id)
            if planned is None or planned[0] > elapsed or team_key in match.attempts:
                continue
            due_at, correct = planned
            changed = True
            answer = (
                question.accepted_answers[0]
                if correct
                else f"__arena_bot_wrong__:{match.id}:{question.id}"
            )
            result = await self._apply_submission(
                match,
                match.bot_user_id,
                question.id,
                answer,
            )
            match.bot_events.append({
                "question_id": question.id,
                "question_number": index + 1,
                "correct": result["correct"],
                "elapsed": due_at,
            })
            if match.finished:
                break
        return changed

    async def submit(self, user_id: str, match_id: str, question_id: str, answer: str, idempotency_key: str) -> dict[str, Any]:
        """필요 변수: 사용자·경기·문항·답·멱등키. 팀 제출 한도와 최초 정답을 원자적으로 판정한다."""

        cache_key = (user_id, idempotency_key)
        if self._redis.enabled:
            cached = await self._redis.idempotent_result(user_id, idempotency_key)
            if cached is not None:
                return cached
            async with self._redis.match_lock(match_id):
                match = await self._load_authorized_match(user_id, match_id, force_redis=True)
                result = await self._apply_submission(match, user_id, question_id, answer)
                await self._redis.save_match(match_id, self._serialize_match(match))
                await self._redis.save_idempotent_result(user_id, idempotency_key, result)
                return result
        async with self._lock:
            if cache_key in self._idempotency:
                return self._idempotency[cache_key]
            match = await self._load_authorized_match(user_id, match_id)
            result = await self._apply_submission(match, user_id, question_id, answer)
            self._idempotency[cache_key] = result
            return result

    async def _apply_submission(
        self,
        match: ArenaMatch,
        user_id: str,
        question_id: str,
        answer: str,
    ) -> dict[str, Any]:
        """필요 변수: 경기·사용자·문항·답안.

        작동 원리: 문항별 단 한 번의 제출을 기록하고, 가드레일·전 문항 완료·
        남은 문항으로 뒤집을 수 없는 점수 차를 즉시 판정해 잠금 안에서 경기를 끝낸다.
        """

        if match.finished:
            raise ValueError("종료된 경기입니다.")
        if utc_now() >= match.started_at + timedelta(seconds=match.duration_seconds):
            match.finish_reason = "time_expired"
            await self._finish(match)
            raise ValueError("경기 시간이 종료되었습니다.")
        question = next((item for item in match.questions if item.id == question_id), None)
        if question is None:
            raise ValueError("경기 문항을 찾을 수 없습니다.")
        participant = match.participants[user_id]
        next_question = next(
            (
                item
                for item in match.questions
                if (participant.team, item.id) not in match.attempts
            ),
            None,
        )
        if next_question is None or next_question.id != question_id:
            raise ValueError("현재 순서의 문항만 제출할 수 있습니다. 이전 문제로 돌아갈 수 없습니다.")
        team_key = (participant.team, question.id)
        attempts = match.attempts.get(team_key, 0)
        if attempts >= 1:
            raise ValueError("이미 제출한 문항입니다. 이전 문제로 돌아갈 수 없습니다.")
        now = time.time()
        events = [
            item
            for item in match.submission_events.get(user_id, [])
            if now - item[0] <= ANTI_CHEAT_WINDOW_SECONDS
        ]
        if question_id not in {item[1] for item in events}:
            events.append((now, question_id))
        match.submission_events[user_id] = events
        match.attempts[team_key] = attempts + 1
        correct = grade_answer(question.answer_type, answer, question.accepted_answers)
        elapsed = max(0.0, (utc_now() - match.started_at).total_seconds())
        match.answers[team_key] = {
            "user_id": user_id,
            "answer": answer,
            "correct": correct,
            "elapsed": elapsed,
        }
        if correct:
            match.solved[team_key] = (user_id, elapsed)
            participant.correct_weights.append(question.difficulty)
        else:
            participant.wrong_weights.append(question.difficulty)
        result = {
            "question_id": question.id,
            "correct": correct,
            "attempts_used": 1,
            "attempts_remaining": 0,
            "scores": self._scores(match),
            "xp_delta": question.base_correct_xp * 0.2 if correct else 0.0,
        }
        if (
            user_id != match.bot_user_id
            and len({item[1] for item in events}) >= ANTI_CHEAT_MAX_SUBMISSIONS
        ):
            match.forfeit_winner_team = 1 - participant.team
            match.finish_reason = "anti_cheat_speed"
            await self._finish(match)
            result.update({"abusive": True, "finished": True, "finish_reason": match.finish_reason})
            return result
        finish_reason = self._completion_reason(match)
        if finish_reason is not None:
            match.finish_reason = finish_reason
            await self._finish(match)
        result.update({
            "finished": match.finished,
            "finish_reason": match.finish_reason,
        })
        return result

    async def send_chat(self, user_id: str, match_id: str, message: str) -> dict[str, Any]:
        """필요 변수: 사용자·경기·문자열. 2v2 팀 채팅에 최신 100개만 남긴다."""

        match = await self._load_authorized_match(user_id, match_id)
        if not match.queue_type.startswith("team_") or match.finished:
            raise ValueError("현재 경기에서는 팀 채팅을 사용할 수 없습니다.")
        text = message.strip()
        if not text or len(text) > 500:
            raise ValueError("채팅은 1자 이상 500자 이하로 입력해주세요.")
        team = match.participants[user_id].team
        item = {"id": uuid.uuid4().hex, "user_id": user_id, "message": text, "sent_at": utc_now().isoformat()}
        if self._redis.enabled:
            await self._redis.append_chat(match.id, team, item)
            return item
        async with self._lock:
            messages = self._chat.setdefault((match.id, team), [])
            messages.append(item)
            del messages[:-100]
        return item

    async def _load_authorized_match(
        self,
        user_id: str,
        match_id: str,
        *,
        force_redis: bool = False,
    ) -> ArenaMatch:
        """필요 변수: 사용자·경기 ID·Redis 강제 조회 여부. 공유 상태를 복원한 뒤 참가 권한을 확인한다."""

        match = None if force_redis else self._matches.get(match_id)
        if match is None and self._redis.enabled:
            payload = await self._redis.load_match(match_id)
            if payload is not None:
                match = self._deserialize_match(payload)
                self._matches[match_id] = match
        if match is None or user_id not in match.participants:
            raise ValueError("경기에 접근할 수 없습니다.")
        return match

    def _scores(self, match: ArenaMatch) -> dict[str, Any]:
        """필요 변수: 경기. 팀별 정답·제출·남은 문항과 정답 시간 합계를 계산한다."""

        return {
            str(team): {
                "correct": sum(1 for key in match.solved if key[0] == team),
                "attempted": sum(1 for key in match.attempts if key[0] == team),
                "remaining": len(match.questions) - sum(
                    1 for key in match.attempts if key[0] == team
                ),
                "answer_time": sum(value[1] for key, value in match.solved.items() if key[0] == team),
            }
            for team in (0, 1)
        }

    def _completion_reason(self, match: ArenaMatch) -> str | None:
        """필요 변수: 제출이 반영된 경기.

        작동 원리: 어느 팀이든 전 문항을 제출했거나, 뒤지는 팀이 남은 문항을
        모두 맞혀도 역전할 수 없으면 즉시 종료 사유를 반환한다.
        """

        scores = self._scores(match)
        first, second = scores["0"], scores["1"]
        if first["attempted"] >= len(match.questions) or second["attempted"] >= len(match.questions):
            return "all_questions_answered"
        if first["correct"] > second["correct"] + second["remaining"]:
            return "decisive_lead"
        if second["correct"] > first["correct"] + first["remaining"]:
            return "decisive_lead"
        return None

    def _winner_team(self, match: ArenaMatch, scores: dict[str, Any]) -> int | None:
        """필요 변수: 경기와 팀별 점수. 몰수승을 우선하고 정답 수·정답 시간을 차례로 비교한다."""

        if match.forfeit_winner_team in (0, 1):
            return int(match.forfeit_winner_team)
        first, second = scores["0"], scores["1"]
        if first["correct"] != second["correct"]:
            return 0 if first["correct"] > second["correct"] else 1
        if abs(first["answer_time"] - second["answer_time"]) > 1e-9:
            return 0 if first["answer_time"] < second["answer_time"] else 1
        return None

    def _answer_label(self, question: ArenaQuestion, answer: str) -> str:
        """필요 변수: 문항과 저장 답안. 객관식 ID는 표시 라벨로 바꾸고 단답은 원문을 반환한다."""

        if question.answer_type != "multiple_choice":
            return answer
        return next(
            (
                str(choice.get("label", answer))
                for choice in question.choices
                if str(choice.get("id")) == answer
            ),
            answer,
        )

    def _result_analysis(self, match: ArenaMatch) -> list[dict[str, Any]]:
        """필요 변수: 종료 경기의 문항·팀 답안.

        작동 원리: 경기 중에는 숨긴 정답을 종료 결과에서만 공개하고, 팀별 제출
        답안·정오답·소요 시간을 문항 순서대로 묶어 클라이언트 분석 화면에 제공한다.
        """

        analysis: list[dict[str, Any]] = []
        for position, question in enumerate(match.questions, start=1):
            correct_answer = question.accepted_answers[0] if question.accepted_answers else ""
            team_answers: dict[str, Any] = {}
            for team in (0, 1):
                submitted = match.answers.get((team, question.id))
                if submitted is None:
                    continue
                raw_answer = str(submitted.get("answer", ""))
                team_answers[str(team)] = {
                    "user_id": str(submitted.get("user_id", "")),
                    "answer": raw_answer,
                    "answer_label": self._answer_label(question, raw_answer),
                    "correct": bool(submitted.get("correct", False)),
                    "elapsed": float(submitted.get("elapsed", 0.0)),
                }
            analysis.append({
                "position": position,
                "question_id": question.id,
                "prompt": question.prompt,
                "answer_type": question.answer_type,
                "choices": list(question.choices),
                "tags": list(question.tags),
                "correct_answer": correct_answer,
                "correct_answer_label": self._answer_label(question, correct_answer),
                "team_answers": team_answers,
            })
        return analysis

    async def _finish(self, match: ArenaMatch) -> None:
        """필요 변수: 종료할 경기. 정답 수와 시간으로 승패를 정하고 큐별 레이팅을 한 번만 반영한다."""

        if match.finished:
            return
        if match.practice:
            await self._finish_practice(match)
            return
        rating_before = {
            value: self._ratings.get((value, match.queue_type), 1500.0)
            for value in match.participants
        }
        scores = self._scores(match)
        winner = self._winner_team(match, scores)
        if match.finish_reason is None:
            match.finish_reason = "score_decided"
        if match.queue_type.startswith("duel_"):
            users = [match.team_members(0)[0], match.team_members(1)[0]]
            states = [
                self._glicko.get(
                    (value, match.queue_type),
                    GlickoRating(self._ratings.get((value, match.queue_type), 1500.0)),
                )
                for value in users
            ]
            outcomes = (0.5, 0.5) if winner is None else ((1.0, 0.0) if winner == 0 else (0.0, 1.0))
            updated = [update_glicko2(states[0], [(states[1], outcomes[0])]), update_glicko2(states[1], [(states[0], outcomes[1])])]
            for user, state in zip(users, updated):
                self._glicko[(user, match.queue_type)] = state
                self._ratings[(user, match.queue_type)] = state.rating
        else:
            users_a, users_b = match.team_members(0), match.team_members(1)
            states_a = [self._trueskill.get((value, match.queue_type), TrueSkillRating()) for value in users_a]
            states_b = [self._trueskill.get((value, match.queue_type), TrueSkillRating()) for value in users_b]
            updated_a, updated_b = update_trueskill_teams(states_a, states_b, 0 if winner is None else (1 if winner == 0 else -1))
            for users, old, updated in ((users_a, states_a, updated_a), (users_b, states_b, updated_b)):
                scores_by_user = [contribution_score(match.participants[value].correct_weights, match.participants[value].wrong_weights) for value in users]
                multipliers = contribution_multipliers(scores_by_user)
                for user, before, after, multiplier in zip(users, old, updated, multipliers):
                    adjusted = TrueSkillRating(before.mu + (after.mu - before.mu) * multiplier, after.sigma)
                    self._trueskill[(user, match.queue_type)] = adjusted
                    self._ratings[(user, match.queue_type)] = 1000.0 + adjusted.mu * 20.0
        for participant in match.participants.values():
            record = "draw" if winner is None else ("win" if participant.team == winner else "loss")
            self._records.setdefault((participant.user_id, match.queue_type), []).append(record)
            self._user_match.pop(participant.user_id, None)
        self._chat.pop((match.id, 0), None)
        self._chat.pop((match.id, 1), None)
        match.finished = True
        finished_at = utc_now()
        result = {
            "match_id": match.id,
            "queue_type": match.queue_type,
            "started_at": match.started_at.isoformat(),
            "finished_at": finished_at.isoformat(),
            "winner_team": winner,
            "finish_reason": match.finish_reason,
            "scores": scores,
            "analysis": self._result_analysis(match),
            "participants": [
                {
                    "user_id": participant.user_id,
                    "team": participant.team,
                    "contribution": contribution_score(
                        participant.correct_weights,
                        participant.wrong_weights,
                    ),
                    "rating_before": rating_before[participant.user_id],
                    "rating_after": self._ratings.get(
                        (participant.user_id, match.queue_type),
                        rating_before[participant.user_id],
                    ),
                    "rating_delta": self._ratings.get(
                        (participant.user_id, match.queue_type),
                        rating_before[participant.user_id],
                    ) - rating_before[participant.user_id],
                    "is_bot": False,
                    "record": (
                        "draw"
                        if winner is None
                        else "win"
                        if participant.team == winner
                        else "loss"
                    ),
                }
                for participant in match.participants.values()
            ],
        }
        self._finished_results[match.id] = result
        await self._postgres.save_result(result)
        if self._redis.enabled:
            await self._redis.save_match(match.id, self._serialize_match(match))
            await self._redis.finish(match.id, list(match.participants))

    async def _finish_practice(self, match: ArenaMatch) -> None:
        """필요 변수: 종료할 봇 경기.

        작동 원리: 실제 사용자는 승리 +20·패배 -10·무승부 0의 고정 레이팅을
        받고, 봇은 레이팅·랭킹에 저장하지 않는다. 결과와 문항 분석은 실전과
        동일하게 영속화한 뒤 활성 큐·경기 연결을 즉시 정리한다.
        """

        scores = self._scores(match)
        winner = self._winner_team(match, scores)
        if match.finish_reason is None:
            match.finish_reason = "score_decided"
        participant_results: list[dict[str, Any]] = []
        for participant in match.participants.values():
            is_bot = participant.user_id == match.bot_user_id
            before = self._ratings.get((participant.user_id, match.queue_type), 1500.0)
            record = "draw" if winner is None else ("win" if participant.team == winner else "loss")
            delta = 0.0
            if not is_bot:
                if record == "win":
                    delta = BOT_WIN_RATING_REWARD
                elif record == "loss":
                    delta = -BOT_LOSS_RATING_PENALTY
                key = (participant.user_id, match.queue_type)
                after = max(0.0, before + delta)
                self._ratings[key] = after
                glicko = self._glicko.get(key, GlickoRating(before))
                self._glicko[key] = GlickoRating(
                    after,
                    glicko.deviation,
                    glicko.volatility,
                )
                self._records.setdefault((participant.user_id, match.queue_type), []).append(record)
                self._user_practice.pop(participant.user_id, None)
                self._user_match.pop(participant.user_id, None)
                queued = self._user_queue.pop(participant.user_id, None)
                if queued and participant.user_id in self._queues[queued]:
                    self._queues[queued].remove(participant.user_id)
            participant_results.append({
                "user_id": participant.user_id,
                "team": participant.team,
                "contribution": contribution_score(
                    participant.correct_weights,
                    participant.wrong_weights,
                ),
                "rating_before": before,
                "rating_after": max(0.0, before + delta),
                "rating_delta": max(0.0, before + delta) - before,
                "is_bot": is_bot,
                "record": record,
            })

        match.finished = True
        result = {
            "match_id": match.id,
            "queue_type": match.queue_type,
            "practice": True,
            "started_at": match.started_at.isoformat(),
            "finished_at": utc_now().isoformat(),
            "winner_team": winner,
            "finish_reason": match.finish_reason,
            "scores": scores,
            "analysis": self._result_analysis(match),
            "participants": participant_results,
        }
        self._finished_results[match.id] = result
        await self._postgres.save_result(result)
        if self._redis.enabled:
            human_ids = [
                value.user_id
                for value in match.participants.values()
                if value.user_id != match.bot_user_id
            ]
            for human_id in human_ids:
                await self._redis.cancel(human_id)
                await self._redis.detach_practice(human_id)
            await self._redis.save_match(match.id, self._serialize_match(match))
            await self._redis.finish(match.id, list(match.participants))

    async def result(self, user_id: str, match_id: str) -> dict[str, Any]:
        """필요 변수: 사용자·경기 ID. 메모리 또는 PostgreSQL에서 참가 권한이 확인된 종료 결과를 반환한다."""

        result = self._finished_results.get(match_id)
        if result is None:
            result = await self._postgres.get_result(match_id, user_id)
        if result is None or user_id not in {
            str(value["user_id"]) for value in result.get("participants", [])
        }:
            raise ValueError("경기 결과에 접근할 수 없습니다.")
        viewer = next(
            value
            for value in result["participants"]
            if str(value["user_id"]) == user_id
        )
        return {
            **result,
            "viewer_user_id": user_id,
            "viewer_team": int(viewer["team"]),
        }

    async def _create_match(self, match_id: str, queue_type: str, users: list[str]) -> ArenaMatch:
        """필요 변수: 경기 ID·큐·사용자 순서. 앞뒤 절반을 두 팀으로 나누고 문항을 한 번만 고정한다."""

        await self._hydrate_profiles(users, [queue_type])
        required = len(users)
        participants = {
            value: Participant(value, 0 if index < required // 2 else 1)
            for index, value in enumerate(users)
        }
        questions = await self._session_questions(queue_type)
        return ArenaMatch(match_id, queue_type, participants, questions)

    async def _create_practice_match(self, user_id: str, queue_type: str) -> ArenaMatch:
        """필요 변수: 대기 사용자·큐. 같은 실전 문항 구조와 사용자 티어에 맞춘 봇 계획으로 연습 경기를 만든다."""

        await self._hydrate_profiles([user_id], [queue_type])
        match_id = uuid.uuid4().hex
        bot_user_id = f"bot-{match_id}"
        tier = tier_for_rating(self._ratings.get((user_id, queue_type), 1500.0))
        accuracy, min_delay, max_delay = _BOT_PROFILES[tier]
        questions = await self._session_questions(queue_type)
        # 실제 상대를 기다리는 5초 동안에는 봇이 먼저 답하지 않게 한다.
        elapsed = BOT_MATCH_WAIT_SECONDS
        plan: dict[str, tuple[float, bool]] = {}
        for question in questions:
            elapsed += random.uniform(min_delay, max_delay)
            plan[question.id] = (elapsed, random.random() < accuracy)
        return ArenaMatch(
            id=match_id,
            queue_type=queue_type,
            participants={
                user_id: Participant(user_id, 0),
                bot_user_id: Participant(bot_user_id, 1),
            },
            questions=questions,
            practice=True,
            bot_user_id=bot_user_id,
            bot_tier=tier,
            bot_plan=plan,
        )

    async def _session_questions(self, queue_type: str) -> list[ArenaQuestion]:
        """필요 변수: 큐 유형.

        작동 원리: 문제 DB 전체 탐색은 별도 스레드의 단일 공유 작업으로 제한한다.
        0.75초 안에 캐시가 준비되지 않으면 즉시 시작 가능한 기본 문항을 반환해
        매칭 요청과 다른 사용자 이벤트 루프를 멈추지 않는다.
        """

        now = time.monotonic()
        cached = self._practice_question_cache.get(queue_type)
        if cached is not None and cached[0] > now:
            return list(cached[1])
        task = self._question_load_tasks.get(queue_type)
        if task is None:
            task = asyncio.create_task(asyncio.to_thread(self._select_questions, queue_type))
            self._question_load_tasks[queue_type] = task
        try:
            questions = await asyncio.wait_for(
                asyncio.shield(task),
                timeout=QUESTION_LOAD_TIMEOUT_SECONDS,
            )
        except asyncio.TimeoutError:
            return self._fallback_questions(queue_type)
        except Exception:
            return self._fallback_questions(queue_type)
        finally:
            if task.done():
                self._question_load_tasks.pop(queue_type, None)
        self._practice_question_cache[queue_type] = (
            now + QUESTION_CACHE_SECONDS,
            tuple(questions),
        )
        return list(questions)

    def _fallback_questions(self, queue_type: str) -> list[ArenaQuestion]:
        """필요 변수: 큐 유형. DB 읽기가 지연될 때만 사용하는 10개 경량 수학 문항을 만든다."""

        values = [(2, 3), (4, 5), (6, 7), (8, 2), (9, 3), (7, 4), (12, 5), (15, 3), (11, 8), (14, 6)]
        if queue_type.endswith("_ox"):
            return [
                ArenaQuestion(
                    id=f"fallback-ox-{index}",
                    prompt=f"{left} + {right} = {left + right} 은(는) 참이다.",
                    answer_type="ox",
                    accepted_answers=("O",),
                    choices=({"id": "O", "label": "O"}, {"id": "X", "label": "X"}),
                    tags=("기본 연산",),
                )
                for index, (left, right) in enumerate(values)
            ]
        questions: list[ArenaQuestion] = []
        for index, (left, right) in enumerate(values):
            answer = left + right
            if index % 2 == 0:
                labels = [str(answer - 1), str(answer), str(answer + 1), str(answer + 2)]
                questions.append(
                    ArenaQuestion(
                        id=f"fallback-choice-{index}",
                        prompt=f"{left} + {right}의 값은?",
                        answer_type="multiple_choice",
                        accepted_answers=("1",),
                        choices=tuple({"id": str(choice), "label": label} for choice, label in enumerate(labels)),
                        tags=("기본 연산",),
                    )
                )
            else:
                questions.append(
                    ArenaQuestion(
                        id=f"fallback-short-{index}",
                        prompt=f"{left} + {right}의 값은?",
                        answer_type="short",
                        accepted_answers=(str(answer),),
                        tags=("기본 연산",),
                    )
                )
        return questions

    def _serialize_match(self, match: ArenaMatch) -> dict[str, Any]:
        """필요 변수: 활성 경기. Redis 공유에 필요한 정답 포함 서버 상태를 UTF-8 JSON 자료로 변환한다."""

        return {
            "id": match.id,
            "queue_type": match.queue_type,
            "started_at": match.started_at.isoformat(),
            "duration_seconds": match.duration_seconds,
            "finished": match.finished,
            "practice": match.practice,
            "bot_fallback": match.bot_fallback,
            "bot_user_id": match.bot_user_id,
            "bot_tier": match.bot_tier,
            "bot_plan": [
                {
                    "question_id": question_id,
                    "due_at": value[0],
                    "correct": value[1],
                }
                for question_id, value in match.bot_plan.items()
            ],
            "bot_events": list(match.bot_events),
            "connected_users": list(match.connected_users),
            "last_seen_at": dict(match.last_seen_at),
            "submission_events": {
                user_id: [[timestamp, question_id] for timestamp, question_id in events]
                for user_id, events in match.submission_events.items()
            },
            "forfeit_winner_team": match.forfeit_winner_team,
            "finish_reason": match.finish_reason,
            "participants": {
                key: {
                    "user_id": value.user_id,
                    "team": value.team,
                    "strong_tags": value.strong_tags,
                    "weak_tags": value.weak_tags,
                    "correct_weights": value.correct_weights,
                    "wrong_weights": value.wrong_weights,
                }
                for key, value in match.participants.items()
            },
            "questions": [
                {
                    "id": value.id,
                    "prompt": value.prompt,
                    "answer_type": value.answer_type,
                    "accepted_answers": list(value.accepted_answers),
                    "choices": list(value.choices),
                    "difficulty": value.difficulty,
                    "tags": list(value.tags),
                    "base_correct_xp": value.base_correct_xp,
                    "base_wrong_xp": value.base_wrong_xp,
                }
                for value in match.questions
            ],
            "attempts": [
                {"team": key[0], "question_id": key[1], "count": count}
                for key, count in match.attempts.items()
            ],
            "solved": [
                {
                    "team": key[0],
                    "question_id": key[1],
                    "user_id": value[0],
                    "elapsed": value[1],
                }
                for key, value in match.solved.items()
            ],
            "answers": [
                {
                    "team": key[0],
                    "question_id": key[1],
                    **value,
                }
                for key, value in match.answers.items()
            ],
        }

    async def _replace_missing_opponent_with_bot(
        self,
        match: ArenaMatch,
        user_id: str,
    ) -> bool:
        """필요 변수: 경기·현재 접속 사용자. 5초 안에 접속하지 않은 상대를 봇으로 대체한다."""

        if match.finished or match.practice or match.bot_user_id is not None:
            return False
        missing = [
            value
            for value in match.participants.values()
            if value.user_id != user_id and value.user_id not in match.connected_users
        ]
        if not missing:
            return False
        opponent = missing[0]
        match.participants.pop(opponent.user_id, None)
        bot_user_id = f"bot-{match.id}"
        match.participants[bot_user_id] = Participant(bot_user_id, opponent.team)
        match.bot_user_id = bot_user_id
        match.bot_tier = tier_for_rating(self._ratings.get((user_id, match.queue_type), 1500.0))
        accuracy, min_delay, max_delay = _BOT_PROFILES[match.bot_tier]
        match.bot_plan = {
            question.id: (
                BOT_MATCH_WAIT_SECONDS + random.uniform(min_delay, max_delay) + index * 4,
                random.random() < accuracy,
            )
            for index, question in enumerate(match.questions)
        }
        match.practice = True
        match.bot_fallback = True
        self._user_match.pop(opponent.user_id, None)
        if self._redis.enabled:
            await self._redis.clear_active_match(opponent.user_id)
        return True

    async def _check_inactive_forfeit(self, match: ArenaMatch, user_id: str) -> None:
        """필요 변수: 경기·상태 조회 사용자. 6분 동안 답안이 없는 이탈 상대를 몰수패 처리한다."""

        if match.finished or len(match.participants) != 2:
            return
        current = match.participants.get(user_id)
        if current is None:
            return
        opponent = next(
            (value for value in match.participants.values() if value.team != current.team),
            None,
        )
        if opponent is None or opponent.user_id == match.bot_user_id:
            return
        elapsed = (utc_now() - match.started_at).total_seconds()
        opponent_events = match.submission_events.get(opponent.user_id, [])
        last_seen = match.last_seen_at.get(opponent.user_id, 0.0)
        if elapsed < INACTIVE_FORFEIT_SECONDS or opponent_events:
            return
        if self._redis.enabled:
            opponent_present = await self._redis.has_presence(match.id, opponent.user_id)
        else:
            opponent_present = (
                opponent.user_id in match.connected_users
                and time.time() - last_seen < INACTIVE_FORFEIT_SECONDS
            )
        if opponent_present:
            return
        if not match.submission_events.get(user_id):
            return
        match.forfeit_winner_team = current.team
        match.finish_reason = "inactive_forfeit"
        await self._finish(match)

    def _deserialize_match(self, payload: dict[str, Any]) -> ArenaMatch:
        """필요 변수: Redis 경기 JSON. 타입을 검증하며 프로세스 로컬 ArenaMatch로 복원한다."""

        participants = {
            str(key): Participant(
                user_id=str(value["user_id"]),
                team=int(value["team"]),
                strong_tags=[str(item) for item in value.get("strong_tags", [])],
                weak_tags=[str(item) for item in value.get("weak_tags", [])],
                correct_weights=[float(item) for item in value.get("correct_weights", [])],
                wrong_weights=[float(item) for item in value.get("wrong_weights", [])],
            )
            for key, value in payload["participants"].items()
        }
        questions = [
            ArenaQuestion(
                id=str(value["id"]),
                prompt=str(value["prompt"]),
                answer_type=str(value["answer_type"]),
                accepted_answers=tuple(str(item) for item in value["accepted_answers"]),
                choices=tuple(dict(item) for item in value.get("choices", [])),
                difficulty=float(value.get("difficulty", 1)),
                tags=tuple(str(item) for item in value.get("tags", [])),
                base_correct_xp=float(value.get("base_correct_xp", 10)),
                base_wrong_xp=float(value.get("base_wrong_xp", 5)),
            )
            for value in payload["questions"]
        ]
        match = ArenaMatch(
            id=str(payload["id"]),
            queue_type=str(payload["queue_type"]),
            participants=participants,
            questions=questions,
            started_at=datetime.fromisoformat(str(payload["started_at"])),
            duration_seconds=int(payload.get("duration_seconds", 1200)),
            finished=bool(payload.get("finished", False)),
            practice=bool(payload.get("practice", False)),
            bot_fallback=bool(payload.get("bot_fallback", False)),
            bot_user_id=(
                str(payload["bot_user_id"])
                if payload.get("bot_user_id") is not None
                else None
            ),
            bot_tier=(
                str(payload["bot_tier"])
                if payload.get("bot_tier") is not None
                else None
            ),
            bot_plan={
                str(value["question_id"]): (
                    float(value["due_at"]),
                    bool(value["correct"]),
                )
                for value in payload.get("bot_plan", [])
            },
            bot_events=[dict(value) for value in payload.get("bot_events", [])],
        )
        match.attempts = {
            (int(value["team"]), str(value["question_id"])): int(value["count"])
            for value in payload.get("attempts", [])
        }
        match.solved = {
            (int(value["team"]), str(value["question_id"])): (
                str(value["user_id"]),
                float(value["elapsed"]),
            )
            for value in payload.get("solved", [])
        }
        match.answers = {
            (int(value["team"]), str(value["question_id"])): {
                "user_id": str(value.get("user_id", "")),
                "answer": str(value.get("answer", "")),
                "correct": bool(value.get("correct", False)),
                "elapsed": float(value.get("elapsed", 0.0)),
            }
            for value in payload.get("answers", [])
        }
        match.connected_users = {str(value) for value in payload.get("connected_users", [])}
        match.last_seen_at = {
            str(user_id): float(timestamp)
            for user_id, timestamp in payload.get("last_seen_at", {}).items()
        }
        match.submission_events = {
            str(user_id): [(float(item[0]), str(item[1])) for item in events]
            for user_id, events in payload.get("submission_events", {}).items()
        }
        match.forfeit_winner_team = payload.get("forfeit_winner_team")
        match.finish_reason = payload.get("finish_reason")
        return match

    def _select_questions(self, queue_type: str) -> list[ArenaQuestion]:
        """필요 변수: 큐 유형. OX 10개 또는 객관식/숫자 단답형 5개씩을 DB에서 고정한다."""

        if queue_type.endswith("_ox"):
            rows = fetch_random_questions(10)
            questions = [
                ArenaQuestion(str(row["id"]), str(row["question"]), "ox", ("O" if row["answer"] else "X",), choices=({"id": "O", "label": "O"}, {"id": "X", "label": "X"}), tags=(str(row["tag"]),))
                for row in rows[:10]
            ]
            if len(questions) < 10:
                raise ValueError("OX 대결에 필요한 문자열 채점 문항이 부족합니다.")
            return questions
        raw = _arena_quest_rows()
        converted = [item for item in (_quest_question(value) for value in raw) if item is not None]
        multiple = [item for item in converted if item.answer_type == "multiple_choice"]
        short = [item for item in converted if item.answer_type == "short"]
        if len(multiple) < 5 and len(short) >= 5:
            for index, question in enumerate(short[: 5 - len(multiple)]):
                multiple.append(_temporary_multiple_choice(question, index))
        if len(multiple) < 5 or len(short) < 5:
            raise ValueError("시험 대결에 필요한 객관식/숫자 단답형 문항이 부족합니다.")
        random.shuffle(multiple)
        random.shuffle(short)
        return [value for pair in zip(multiple[:5], short[:5]) for value in pair]


arena_service = ArenaService()
