"""Service layer for challenge-related domain flows."""
from __future__ import annotations

import json
import random
from datetime import date
from typing import Any, Dict, List

from fastapi import HTTPException

from domain.challenge.engine import (
    calculate_reward,
    evaluate_attempt,
    generate_daily_challenge,
    generate_weekly_challenge,
)
from domain.challenge.models import StudentChallengeProgress
from domain.challenge import repository as repo
from domain.course import v2_repository as course_repo
from storage import student_account_store
from storage.user_kv_storage import get_user_kv, set_user_kv
from services.ai.providers.base import get_default_provider

_ALLOWED_DAILY_TYPES = {
    "course_stage_progress",
    "solve_n_problems",
    "exam_accuracy_threshold",
    "attendance_complete",
    "attendance_3day_streak",
    "activity_score_reach",
    "textbook_read_complete",
    "ask_friend_problem",
    "open_documents_box",
    "weakness_review_n_problems",
}


def _daily_today() -> str:
    return date.today().isoformat()


def _daily_kv_key(course_id: str, day: str) -> str:
    return f"daily_quests:{course_id}:{day}"


def _quest_title(quest_type: str) -> str:
    labels = {
        "course_stage_progress": "Course progress milestone",
        "solve_n_problems": "Solve problems",
        "exam_accuracy_threshold": "Exam accuracy threshold",
        "attendance_complete": "Attendance complete",
        "attendance_3day_streak": "Attendance 3day streak",
        "activity_score_reach": "Activity score reach",
        "textbook_read_complete": "Textbook complete",
        "ask_friend_problem": "Ask friend problem",
        "open_documents_box": "Open documents box",
        "weakness_review_n_problems": "Weakness review problems",
    }
    return labels.get(quest_type, quest_type)


def _quest_target(quest_type: str) -> int:
    defaults = {
        "course_stage_progress": 1,
        "solve_n_problems": 5,
        "exam_accuracy_threshold": 80,
        "attendance_complete": 1,
        "attendance_3day_streak": 3,
        "activity_score_reach": 50,
        "textbook_read_complete": 1,
        "ask_friend_problem": 1,
        "open_documents_box": 1,
        "weakness_review_n_problems": 3,
    }
    return int(defaults.get(quest_type, 1))


def _quest_reward_points(quest_type: str) -> int:
    return student_account_store.DAILY_QUEST_REWARD_POINTS


def _normalize_daily_items(data: dict[str, Any]) -> dict[str, Any]:
    items = data.get("items")
    if not isinstance(items, list):
        data["items"] = []
        return data
    for item in items:
        if not isinstance(item, dict):
            continue
        quest_type = str(item.get("quest_type") or "")
        item["target"] = max(1, int(item.get("target") or _quest_target(quest_type)))
        item["progress"] = max(0, int(item.get("progress") or 0))
        item["reward_points"] = _quest_reward_points(quest_type)
        item.setdefault("reward_claimed", False)
        item.setdefault("claimed_points", 0)
    return data


def _with_account_summary(data: dict[str, Any], user_id: str) -> dict[str, Any]:
    out = _normalize_daily_items(dict(data))
    out["account"] = student_account_store.get_account_summary(user_id)
    return out


def _build_daily_items(
    available_types: list[str],
    min_count: int,
    max_count: int,
    day: str,
) -> list[dict[str, Any]]:
    if not available_types:
        return []
    picked_count = random.randint(min_count, max_count)
    if len(available_types) >= picked_count:
        picked = random.sample(available_types, k=picked_count)
    else:
        picked = list(available_types)
        while len(picked) < picked_count:
            picked.append(random.choice(available_types))

    out: list[dict[str, Any]] = []
    for i, quest_type in enumerate(picked):
        out.append(
            {
                "id": f"{day}-{i + 1}-{quest_type}",
                "quest_type": quest_type,
                "title": _quest_title(quest_type),
                "target": _quest_target(quest_type),
                "progress": 0,
                "status": "pending",
                "reward_points": _quest_reward_points(quest_type),
                "reward_claimed": False,
                "claimed_points": 0,
            }
        )
    return out


def _load_or_create_daily_quests(user_id: str, course_id: str) -> dict[str, Any]:
    course = course_repo.get_course_v2(course_id)
    if course is None:
        raise HTTPException(status_code=404, detail="Course not found")

    challenge_settings = course.challenge_settings or {}
    configured_types = challenge_settings.get("available_types") or []
    safe_types = [
        str(t)
        for t in configured_types
        if isinstance(t, str) and t in _ALLOWED_DAILY_TYPES
    ]
    if not safe_types:
        safe_types = sorted(_ALLOWED_DAILY_TYPES)

    min_count = int(challenge_settings.get("daily_random_count_min") or 3)
    max_count = int(challenge_settings.get("daily_random_count_max") or 5)
    min_count = max(3, min(5, min_count))
    max_count = max(3, min(5, max_count))
    if min_count > max_count:
        min_count, max_count = max_count, min_count

    day = _daily_today()
    key = _daily_kv_key(course_id, day)
    raw = get_user_kv(user_id, key)
    if raw:
        try:
            data = json.loads(raw)
            if isinstance(data, dict) and isinstance(data.get("items"), list):
                normalized = _normalize_daily_items(data)
                if normalized != data:
                    set_user_kv(user_id, key, json.dumps(normalized, ensure_ascii=False))
                return normalized
        except json.JSONDecodeError:
            pass

    created = {
        "course_id": course_id,
        "date": day,
        "items": _build_daily_items(safe_types, min_count, max_count, day),
    }
    set_user_kv(user_id, key, json.dumps(created, ensure_ascii=False))
    return created


def get_daily_quests(user_id: str, course_id: str) -> dict[str, Any]:
    return _with_account_summary(_load_or_create_daily_quests(user_id, course_id), user_id)


def apply_daily_quest_event(user_id: str, body: Dict[str, Any]) -> tuple[dict[str, Any], bool]:
    course_id = str(body.get("course_id") or "")
    event_type = str(body.get("event_type") or "")
    value = int(body.get("value") or 1)
    if not course_id or not event_type:
        raise HTTPException(status_code=400, detail="course_id and event_type are required")

    data = _load_or_create_daily_quests(user_id, course_id)
    updated = False
    awarded_account: dict[str, Any] | None = None
    for item in data.get("items", []):
        if item.get("quest_type") != event_type:
            continue
        if item.get("status") == "completed":
            continue
        target = max(1, int(item.get("target") or 1))
        item["progress"] = min(target, int(item.get("progress") or 0) + max(1, min(value, target)))
        if int(item["progress"]) >= target:
            item["status"] = "completed"
            awarded_account = student_account_store.award_daily_quest_points(
                user_id=user_id,
                course_id=course_id,
                quest_id=str(item.get("id") or ""),
                reward_points=int(item.get("reward_points") or _quest_reward_points(str(item.get("quest_type") or ""))),
                date_key=str(data.get("date") or _daily_today()),
            )
            item["reward_claimed"] = True
            item["claimed_points"] = int(item.get("claimed_points") or 0) + int(
                (awarded_account.get("reward") or {}).get("granted_points") or 0
            )
            item["claim_status"] = "claimed"
        updated = True

    if updated:
        key = _daily_kv_key(course_id, str(data.get("date") or _daily_today()))
        set_user_kv(user_id, key, json.dumps(data, ensure_ascii=False))
    response = _with_account_summary(data, user_id)
    if awarded_account is not None:
        response["account"] = awarded_account
    return response, updated


def complete_daily_quest(user_id: str, body: Dict[str, Any]) -> dict[str, Any]:
    course_id = str(body.get("course_id") or "")
    quest_id = str(body.get("quest_id") or "")
    if not course_id or not quest_id:
        raise HTTPException(status_code=400, detail="course_id and quest_id are required")

    data = _load_or_create_daily_quests(user_id, course_id)
    for item in data.get("items", []):
        if item.get("id") == quest_id:
            target = max(1, int(item.get("target") or 1))
            is_completed = item.get("status") == "completed" and int(item.get("progress") or 0) >= target
            if not is_completed:
                item["claim_status"] = "verification_required"
                key = _daily_kv_key(course_id, str(data.get("date") or _daily_today()))
                set_user_kv(user_id, key, json.dumps(data, ensure_ascii=False))
                return _with_account_summary(data, user_id)

            reward = student_account_store.award_daily_quest_points(
                user_id=user_id,
                course_id=course_id,
                quest_id=quest_id,
                reward_points=int(item.get("reward_points") or _quest_reward_points(str(item.get("quest_type") or ""))),
                date_key=str(data.get("date") or _daily_today()),
            )
            item["reward_claimed"] = True
            item["claimed_points"] = int(item.get("claimed_points") or 0) + int(
                (reward.get("reward") or {}).get("granted_points") or 0
            )
            item["claim_status"] = "claimed"
            key = _daily_kv_key(course_id, str(data.get("date") or _daily_today()))
            set_user_kv(user_id, key, json.dumps(data, ensure_ascii=False))
            response = _with_account_summary(data, user_id)
            response["account"] = reward
            return response
    raise HTTPException(status_code=404, detail="quest not found")


def list_challenges(course_id: int | None):
    challenges = repo.list_active_challenges(course_id=course_id)
    return [c.model_dump() for c in challenges]


def submit_attempt(user_id: str, challenge_id: int, body: Dict[str, Any]) -> dict[str, Any]:
    challenge = repo.get_challenge(challenge_id)
    if challenge is None:
        raise HTTPException(status_code=404, detail="Challenge not found")

    answers: List[int] = body.get("answers", [])
    result = evaluate_attempt(challenge, answers)

    progress = repo.get_progress(user_id, challenge_id)
    if progress is None:
        progress = StudentChallengeProgress(
            user_id=user_id,
            challenge_id=challenge_id,
            score=result["score"],
            attempts=1,
            best_time_seconds=body.get("time_seconds", 0),
            completed_at=None,
            reward_claimed=False,
        )
        repo.create_progress(progress)
    else:
        progress.attempts += 1
        if result["score"] > progress.score:
            progress.score = result["score"]
        if body.get("time_seconds", 0) < progress.best_time_seconds or progress.best_time_seconds == 0:
            progress.best_time_seconds = body.get("time_seconds", 0)
        if result["score"] >= 100.0:
            from domain.challenge.repository import _now_iso

            progress.completed_at = _now_iso()
        repo.update_progress(progress)

    reward = calculate_reward(challenge, progress)

    return {
        "score": result["score"],
        "correct_count": result["correct_count"],
        "total": result["total"],
        "time_bonus": result["time_bonus"],
        "reward": reward,
        "attempts": progress.attempts,
    }


def get_progress(caller_role: str, caller_id: str, challenge_id: int, user_id: str | None):
    target_user_id = caller_id if caller_role == "student" else (user_id or caller_id)
    progress = repo.get_progress(target_user_id, challenge_id)
    if progress is None:
        raise HTTPException(status_code=404, detail="Progress not found")
    return progress.model_dump()


def create_daily_challenge(body: Dict[str, Any]) -> dict[str, Any]:
    course_id = int(body.get("course_id", 0))
    date_str = str(body.get("date_str", "")).strip()
    if not date_str:
        from datetime import datetime, timezone

        date_str = datetime.now(timezone.utc).strftime("%Y-%m-%d")

    ai_provider = get_default_provider()
    challenge = generate_daily_challenge(course_id, ai_provider, date_str)
    return challenge.model_dump()


def create_weekly_challenge(body: Dict[str, Any]) -> dict[str, Any]:
    course_id = int(body.get("course_id", 0))
    week_str = str(body.get("week_str", "")).strip()
    if not week_str:
        from datetime import datetime, timezone

        week_str = datetime.now(timezone.utc).strftime("%Y-W%U")

    ai_provider = get_default_provider()
    challenge = generate_weekly_challenge(course_id, ai_provider, week_str)
    return challenge.model_dump()
