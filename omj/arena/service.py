"""대결장 매칭, 출제, 제출, 채팅을 조정하는 서비스."""

from __future__ import annotations

import asyncio
import random
import uuid
from datetime import timedelta
from typing import Any

from storage.storage import search_quests
from storage.ox_quiz_storage import fetch_random_questions

from .grading import grade_answer, max_attempts
from .models import ArenaMatch, ArenaQuestion, Participant, QUEUE_TYPES, utc_now
from .rating import (
    GlickoRating,
    TrueSkillRating,
    contribution_multipliers,
    contribution_score,
    tier_for_rating,
    update_glicko2,
    update_trueskill_teams,
)


def _block_text(value: Any) -> str:
    """필요 변수: 콘텐츠 블록 자료. DB 콘텐츠에서 화면에 표시할 문자열을 안전하게 추출한다."""

    if isinstance(value, str):
        return value
    if isinstance(value, dict):
        if "content" in value:
            return str(value.get("content") or "")
        return " ".join(_block_text(item) for item in value.get("blocks", []))
    if isinstance(value, list):
        return " ".join(_block_text(item) for item in value)
    return "" if value is None else str(value)


def _quest_question(raw: dict[str, Any]) -> ArenaQuestion | None:
    """필요 변수: 기존 quest 자료. 문자열 채점 가능한 대결 문항으로 변환하며 정답 없는 문제는 제외한다."""

    data, info = raw.get("data") or {}, raw.get("info") or {}
    prompt = _block_text(data.get("quest_title")).strip()
    answer = _block_text(data.get("quest_answer")).strip()
    options = data.get("quest_options") or []
    answer_index = data.get("choice_answer_index")
    if options and answer_index is not None:
        choices = tuple({"id": str(index), "label": _block_text(value)} for index, value in enumerate(options))
        accepted, answer_type = (str(answer_index),), "multiple_choice"
    elif answer:
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
        difficulty=max(1.0, float(info.get("difficulty_score") or info.get("difficulty") or 1.0)),
        tags=tags,
    )


class ArenaService:
    """공유 상태는 asyncio 잠금 아래 변경한다. 운영 어댑터는 같은 원자 연산을 Redis로 교체할 수 있다."""

    def __init__(self) -> None:
        self._lock = asyncio.Lock()
        self._queues: dict[str, list[str]] = {name: [] for name in QUEUE_TYPES}
        self._user_queue: dict[str, str] = {}
        self._user_match: dict[str, str] = {}
        self._matches: dict[str, ArenaMatch] = {}
        self._ratings: dict[tuple[str, str], float] = {}
        self._glicko: dict[tuple[str, str], GlickoRating] = {}
        self._trueskill: dict[tuple[str, str], TrueSkillRating] = {}
        self._records: dict[tuple[str, str], list[str]] = {}
        self._idempotency: dict[tuple[str, str], dict[str, Any]] = {}
        self._chat: dict[tuple[str, int], list[dict[str, Any]]] = {}

    async def summary(self, user_id: str) -> dict[str, Any]:
        """필요 변수: 사용자 ID. 네 큐의 독립 레이팅·티어·최근 전적을 반환한다."""

        result = []
        for queue_type in sorted(QUEUE_TYPES):
            rating = self._ratings.get((user_id, queue_type), 1500.0)
            records = self._records.get((user_id, queue_type), [])[-10:]
            result.append({
                "queue_type": queue_type,
                "rating": rating,
                "tier": tier_for_rating(rating),
                "wins": records.count("win"),
                "losses": records.count("loss"),
                "draws": records.count("draw"),
                "recent_results": records,
                "estimated_wait_seconds": max(5, 25 - len(self._queues[queue_type]) * 5),
            })
        return {"queues": result, "active_match_id": self._user_match.get(user_id)}

    async def join(self, user_id: str, queue_type: str, idempotency_key: str) -> dict[str, Any]:
        """필요 변수: 사용자·큐·멱등키. 중복 참가를 차단하고 인원이 차면 한 경기를 원자적으로 만든다."""

        if queue_type not in QUEUE_TYPES:
            raise ValueError("지원하지 않는 대결 큐입니다.")
        cache_key = (user_id, idempotency_key)
        async with self._lock:
            if cache_key in self._idempotency:
                return self._idempotency[cache_key]
            if user_id in self._user_match or user_id in self._user_queue:
                raise ValueError("이미 매칭 중이거나 진행 중인 경기가 있습니다.")
            self._queues[queue_type].append(user_id)
            self._user_queue[user_id] = queue_type
            required = 4 if queue_type.startswith("team_") else 2
            result: dict[str, Any] = {"status": "queued", "queue_type": queue_type}
            if len(self._queues[queue_type]) >= required:
                users = self._queues[queue_type][:required]
                del self._queues[queue_type][:required]
                for value in users:
                    self._user_queue.pop(value, None)
                questions = self._select_questions(queue_type)
                match_id = uuid.uuid4().hex
                participants = {
                    value: Participant(value, 0 if index < required // 2 else 1)
                    for index, value in enumerate(users)
                }
                match = ArenaMatch(match_id, queue_type, participants, questions)
                self._matches[match_id] = match
                for value in users:
                    self._user_match[value] = match_id
                result = {"status": "matched", "queue_type": queue_type, "match_id": match_id}
            self._idempotency[cache_key] = result
            return result

    async def cancel(self, user_id: str) -> dict[str, Any]:
        """필요 변수: 사용자 ID. 활성 경기에는 손대지 않고 대기열에서만 제거한다."""

        async with self._lock:
            queue_type = self._user_queue.pop(user_id, None)
            if queue_type and user_id in self._queues[queue_type]:
                self._queues[queue_type].remove(user_id)
            return {"cancelled": queue_type is not None}

    async def state(self, user_id: str, match_id: str) -> dict[str, Any]:
        """필요 변수: 사용자·경기 ID. 재접속 가능한 공개 경기 상태를 반환한다."""

        match = self._authorized_match(user_id, match_id)
        if not match.finished and utc_now() >= match.started_at + timedelta(seconds=match.duration_seconds):
            self._finish(match)
        elapsed = (utc_now() - match.started_at).total_seconds()
        participant = match.participants[user_id]
        return {
            "match_id": match.id,
            "queue_type": match.queue_type,
            "team": participant.team,
            "remaining_seconds": max(0, match.duration_seconds - int(elapsed)),
            "questions": [question.public_dict() for question in match.questions],
            "participants": [
                {"user_id": item.user_id, "team": item.team, "strong_tags": item.strong_tags, "weak_tags": item.weak_tags}
                for item in match.participants.values()
            ],
            "scores": self._scores(match),
            "finished": match.finished,
            "chat": list(self._chat.get((match.id, participant.team), [])),
        }

    async def submit(self, user_id: str, match_id: str, question_id: str, answer: str, idempotency_key: str) -> dict[str, Any]:
        """필요 변수: 사용자·경기·문항·답·멱등키. 팀 제출 한도와 최초 정답을 원자적으로 판정한다."""

        cache_key = (user_id, idempotency_key)
        async with self._lock:
            if cache_key in self._idempotency:
                return self._idempotency[cache_key]
            match = self._authorized_match(user_id, match_id)
            if match.finished or utc_now() >= match.started_at + timedelta(seconds=match.duration_seconds):
                raise ValueError("종료된 경기입니다.")
            question = next((item for item in match.questions if item.id == question_id), None)
            if question is None:
                raise ValueError("경기 문항을 찾을 수 없습니다.")
            participant = match.participants[user_id]
            team_key = (participant.team, question.id)
            attempts = match.attempts.get(team_key, 0)
            if attempts >= max_attempts(question.answer_type):
                raise ValueError("이 문항의 팀 제출 횟수를 모두 사용했습니다.")
            if team_key in match.solved:
                raise ValueError("이미 팀이 해결한 문항입니다.")
            match.attempts[team_key] = attempts + 1
            correct = grade_answer(question.answer_type, answer, question.accepted_answers)
            if correct:
                elapsed = max(0.0, (utc_now() - match.started_at).total_seconds())
                match.solved[team_key] = (user_id, elapsed)
                participant.correct_weights.append(question.difficulty)
            else:
                participant.wrong_weights.append(question.difficulty)
            result = {
                "correct": correct,
                "attempts_used": attempts + 1,
                "attempts_remaining": max_attempts(question.answer_type) - attempts - 1,
                "scores": self._scores(match),
                "xp_delta": question.base_correct_xp * 0.2 if correct else 0.0,
            }
            if all(sum(1 for key in match.solved if key[0] == team) == len(match.questions) for team in (0, 1)):
                self._finish(match)
            self._idempotency[cache_key] = result
            return result

    async def send_chat(self, user_id: str, match_id: str, message: str) -> dict[str, Any]:
        """필요 변수: 사용자·경기·문자열. 2v2 팀 채팅에 최신 100개만 남긴다."""

        match = self._authorized_match(user_id, match_id)
        if not match.queue_type.startswith("team_") or match.finished:
            raise ValueError("현재 경기에서는 팀 채팅을 사용할 수 없습니다.")
        text = message.strip()
        if not text or len(text) > 500:
            raise ValueError("채팅은 1자 이상 500자 이하로 입력해주세요.")
        team = match.participants[user_id].team
        item = {"id": uuid.uuid4().hex, "user_id": user_id, "message": text, "sent_at": utc_now().isoformat()}
        async with self._lock:
            messages = self._chat.setdefault((match.id, team), [])
            messages.append(item)
            del messages[:-100]
        return item

    def _authorized_match(self, user_id: str, match_id: str) -> ArenaMatch:
        """필요 변수: 사용자·경기 ID. 참가 권한이 확인된 경기만 반환한다."""

        match = self._matches.get(match_id)
        if match is None or user_id not in match.participants:
            raise ValueError("경기에 접근할 수 없습니다.")
        return match

    def _scores(self, match: ArenaMatch) -> dict[str, Any]:
        """필요 변수: 경기. 정답 수와 최초 정답 시간 합계를 팀별로 계산한다."""

        return {
            str(team): {
                "correct": sum(1 for key in match.solved if key[0] == team),
                "answer_time": sum(value[1] for key, value in match.solved.items() if key[0] == team),
            }
            for team in (0, 1)
        }

    def _finish(self, match: ArenaMatch) -> None:
        """필요 변수: 종료할 경기. 정답 수와 시간으로 승패를 정하고 큐별 레이팅을 한 번만 반영한다."""

        if match.finished:
            return
        scores = self._scores(match)
        first, second = scores["0"], scores["1"]
        if first["correct"] != second["correct"]:
            winner = 0 if first["correct"] > second["correct"] else 1
        elif abs(first["answer_time"] - second["answer_time"]) > 1e-9:
            winner = 0 if first["answer_time"] < second["answer_time"] else 1
        else:
            winner = None
        if match.queue_type.startswith("duel_"):
            users = [match.team_members(0)[0], match.team_members(1)[0]]
            states = [self._glicko.get((value, match.queue_type), GlickoRating()) for value in users]
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

    def _select_questions(self, queue_type: str) -> list[ArenaQuestion]:
        """필요 변수: 큐 유형. OX 10개 또는 객관식/단답형 5개씩을 DB에서 고정한다."""

        if queue_type.endswith("_ox"):
            rows = fetch_random_questions(10)
            questions = [
                ArenaQuestion(str(row["id"]), str(row["question"]), "ox", ("O" if row["answer"] else "X",), choices=({"id": "O", "label": "O"}, {"id": "X", "label": "X"}), tags=(str(row["tag"]),))
                for row in rows[:10]
            ]
            if len(questions) < 10:
                raise ValueError("OX 대결에 필요한 문자열 채점 문항이 부족합니다.")
            return questions
        raw = search_quests(page=1, page_size=200).get("quests", [])
        converted = [item for item in (_quest_question(value) for value in raw) if item is not None]
        multiple = [item for item in converted if item.answer_type == "multiple_choice"]
        short = [item for item in converted if item.answer_type == "short"]
        if len(multiple) < 5 or len(short) < 5:
            raise ValueError("시험 대결에 필요한 객관식/단답형 문항이 부족합니다.")
        random.shuffle(multiple)
        random.shuffle(short)
        return [value for pair in zip(multiple[:5], short[:5]) for value in pair]


arena_service = ArenaService()
