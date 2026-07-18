"""대결장 서비스가 공유하는 데이터 모델."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any


QUEUE_TYPES = {"duel_exam", "duel_ox", "team_exam", "team_ox"}
# 공개 화면은 문제풀이 대결만 노출하고, 2v2는 준비 완료 전까지 서버도 참가를 막는다.
PUBLIC_QUEUE_TYPES = ("duel_exam", "team_exam")
JOINABLE_QUEUE_TYPES = {"duel_exam"}


def utc_now() -> datetime:
    """필요 변수 없음. 세션 계산에 사용할 UTC 현재 시각을 반환한다."""

    return datetime.now(timezone.utc)


@dataclass(frozen=True)
class ArenaQuestion:
    """문제·문자열 정답·난이도·경험치 정보를 한 문항으로 고정한다."""

    id: str
    prompt: str
    answer_type: str
    accepted_answers: tuple[str, ...]
    choices: tuple[dict[str, str], ...] = ()
    difficulty: float = 1.0
    tags: tuple[str, ...] = ()
    base_correct_xp: float = 10.0
    base_wrong_xp: float = 5.0

    def public_dict(self) -> dict[str, Any]:
        """필요 변수 없음. 정답을 제외한 클라이언트 공개 문항을 반환한다."""

        return {
            "id": self.id,
            "prompt": self.prompt,
            "answer_type": self.answer_type,
            "choices": list(self.choices),
            "difficulty": self.difficulty,
            "tags": list(self.tags),
        }


@dataclass
class Participant:
    """사용자의 팀·정답·오답 기여 상태를 보관한다."""

    user_id: str
    team: int
    strong_tags: list[str] = field(default_factory=list)
    weak_tags: list[str] = field(default_factory=list)
    correct_weights: list[float] = field(default_factory=list)
    wrong_weights: list[float] = field(default_factory=list)


@dataclass
class ArenaMatch:
    """20분 동안 유지되는 경기와 팀별 제출 상태를 보관한다."""

    id: str
    queue_type: str
    participants: dict[str, Participant]
    questions: list[ArenaQuestion]
    started_at: datetime = field(default_factory=utc_now)
    duration_seconds: int = 1200
    attempts: dict[tuple[int, str], int] = field(default_factory=dict)
    solved: dict[tuple[int, str], tuple[str, float]] = field(default_factory=dict)
    answers: dict[tuple[int, str], dict[str, Any]] = field(default_factory=dict)
    xp_applied: set[tuple[str, str, str]] = field(default_factory=set)
    finished: bool = False
    practice: bool = False
    bot_fallback: bool = False
    bot_user_id: str | None = None
    bot_tier: str | None = None
    bot_plan: dict[str, tuple[float, bool]] = field(default_factory=dict)
    bot_events: list[dict[str, Any]] = field(default_factory=list)
    connected_users: set[str] = field(default_factory=set)
    last_seen_at: dict[str, float] = field(default_factory=dict)
    submission_events: dict[str, list[tuple[float, str]]] = field(default_factory=dict)
    forfeit_winner_team: int | None = None
    finish_reason: str | None = None

    def team_members(self, team: int) -> list[str]:
        """필요 변수: 팀 번호. 해당 팀 사용자 ID를 반환한다."""

        return [item.user_id for item in self.participants.values() if item.team == team]
