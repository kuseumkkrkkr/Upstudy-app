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
from domain.challenge.daily_templates import DAILY_DIFFICULTY_QUOTA, POINTS_BY_DIFFICULTY
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
    "exam_attempt",
    "hint_retry",
    "wrong_answer_open",
    "formula_check",
    "focus_minutes",
    "tag_review",
    "graph_tool_open",
    "solution_read",
    "daily_plan_check",
    "level_status_view",
    "micro_goal_complete",
    "wrong_answer_correct",
    "graph_problem_analyze",
    "friend_help_answer",
    "solution_compare",
    "formula_apply",
    "level_checkpoint",
    "retry_correct",
    "bundle_complete",
    "exam_perfect_score",
    "no_hint_correct",
    "timed_solve",
    "solution_explain",
    "exam_average_accuracy",
    "final_check_complete",
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


def _difficulty_reward_points(difficulty: str) -> int:
    return POINTS_BY_DIFFICULTY.get(difficulty, student_account_store.DAILY_QUEST_REWARD_POINTS)


def _difficulty_label(difficulty: str) -> str:
    return {"easy": "하", "medium": "중", "hard": "상"}.get(difficulty, "하")


def _normalize_daily_items(data: dict[str, Any]) -> dict[str, Any]:
    items = data.get("items")
    if not isinstance(items, list):
        data["items"] = []
        return data
    for item in items:
        if not isinstance(item, dict):
            continue
        quest_type = str(item.get("quest_type") or "")
        difficulty = str(item.get("difficulty") or "easy")
        item["target"] = max(1, int(item.get("target") or _quest_target(quest_type)))
        item["progress"] = max(0, int(item.get("progress") or 0))
        item["difficulty"] = difficulty
        item["difficulty_label"] = str(item.get("difficulty_label") or _difficulty_label(difficulty))
        item["description"] = str(item.get("description") or "")
        item["reward_points"] = max(
            0,
            int(item.get("reward_points") or _difficulty_reward_points(difficulty)),
        )
        item.setdefault("reward_claimed", False)
        item.setdefault("claimed_points", 0)
        item["claimable"] = (
            item.get("status") == "completed"
            and int(item.get("progress") or 0) >= int(item.get("target") or 1)
            and not bool(item.get("reward_claimed"))
        )
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
    picked_count = sum(DAILY_DIFFICULTY_QUOTA.values())
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
                "difficulty": "medium",
                "difficulty_label": "중",
                "description": "",
                "reward_claimed": False,
                "claimed_points": 0,
                "claimable": False,
            }
        )
    return out


def _course_module_weights(course: Any) -> dict[str, float]:
    modules = getattr(course, "modules", []) or []
    counts: dict[str, int] = {}
    for module in modules:
        raw_type = getattr(module, "type", "")
        module_type = str(getattr(raw_type, "value", raw_type) or "")
        if "." in module_type:
            module_type = module_type.rsplit(".", 1)[-1]
        if module_type:
            counts[module_type] = counts.get(module_type, 0) + 1
    total = sum(counts.values())
    if total <= 0:
        return {}
    return {key: value / total for key, value in counts.items()}


def _template_weight(template: dict[str, Any], module_weights: dict[str, float]) -> float:
    module_types = template.get("module_types")
    if not isinstance(module_types, list) or not module_types:
        return 0.1
    weight = sum(module_weights.get(str(module_type), 0.0) for module_type in module_types)
    return weight if weight > 0 else 0.05


def _pick_templates_for_difficulty(
    *,
    templates: list[dict[str, Any]],
    difficulty: str,
    count: int,
    rng: random.Random,
    module_weights: dict[str, float],
    used_keys: set[str],
) -> list[dict[str, Any]]:
    candidates = [
        template
        for template in templates
        if template.get("difficulty") == difficulty and template.get("template_key") not in used_keys
    ]
    if not candidates:
        candidates = [template for template in templates if template.get("difficulty") == difficulty]
    picked: list[dict[str, Any]] = []
    while candidates and len(picked) < count:
        weights = [_template_weight(template, module_weights) for template in candidates]
        selected = rng.choices(candidates, weights=weights, k=1)[0]
        picked.append(selected)
        used_keys.add(str(selected.get("template_key") or ""))
        candidates = [
            template
            for template in candidates
            if template.get("template_key") != selected.get("template_key")
        ]
    return picked


def _build_daily_items_from_templates(
    *,
    templates: list[dict[str, Any]],
    course: Any,
    user_id: str,
    course_id: str,
    day: str,
) -> list[dict[str, Any]]:
    rng = random.Random(f"{user_id}:{course_id}:{day}")
    module_weights = _course_module_weights(course)
    used_keys: set[str] = set()
    selected: list[dict[str, Any]] = []
    for difficulty, count in DAILY_DIFFICULTY_QUOTA.items():
        selected.extend(
            _pick_templates_for_difficulty(
                templates=templates,
                difficulty=difficulty,
                count=count,
                rng=rng,
                module_weights=module_weights,
                used_keys=used_keys,
            )
        )
    rng.shuffle(selected)

    out: list[dict[str, Any]] = []
    for index, template in enumerate(selected):
        difficulty = str(template.get("difficulty") or "easy")
        target = max(1, int(template.get("target") or 1))
        reward_points = max(
            0,
            int(template.get("reward_points") or _difficulty_reward_points(difficulty)),
        )
        out.append(
            {
                "id": f"{day}-{index + 1}-{template.get('template_key')}",
                "template_key": str(template.get("template_key") or ""),
                "quest_type": str(template.get("quest_type") or ""),
                "title": str(template.get("title") or ""),
                "description": str(template.get("description") or ""),
                "difficulty": difficulty,
                "difficulty_label": _difficulty_label(difficulty),
                "target": target,
                "progress": 0,
                "status": "pending",
                "reward_points": reward_points,
                "reward_claimed": False,
                "claimed_points": 0,
                "claimable": False,
            }
        )
    return out


def _load_or_create_daily_quests(user_id: str, course_id: str) -> dict[str, Any]:
    course = course_repo.get_course_v2(course_id)
    if course is None:
        raise HTTPException(status_code=404, detail="Course not found")

    challenge_settings = course.challenge_settings or {}
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

    all_templates = repo.list_daily_challenge_templates(enabled=True)
    templates = list(all_templates)
    configured_types = challenge_settings.get("available_types") or []
    if isinstance(configured_types, list) and configured_types:
        safe_types = {
            str(t)
            for t in configured_types
            if isinstance(t, str) and t in _ALLOWED_DAILY_TYPES
        }
        if safe_types:
            templates = [
                template
                for template in templates
                if str(template.get("quest_type") or "") in safe_types
            ]
            for difficulty in DAILY_DIFFICULTY_QUOTA:
                if not any(template.get("difficulty") == difficulty for template in templates):
                    templates.extend(
                        template
                        for template in all_templates
                        if template.get("difficulty") == difficulty
                    )

    created = {
        "course_id": course_id,
        "date": day,
        "items": _build_daily_items_from_templates(
            templates=templates,
            course=course,
            user_id=user_id,
            course_id=course_id,
            day=day,
        ),
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
    for item in data.get("items", []):
        if item.get("quest_type") != event_type:
            continue
        if item.get("status") == "completed":
            continue
        target = max(1, int(item.get("target") or 1))
        item["progress"] = min(target, int(item.get("progress") or 0) + max(1, min(value, target)))
        if int(item["progress"]) >= target:
            item["status"] = "completed"
            item["claim_status"] = "ready"
            item["claimable"] = not bool(item.get("reward_claimed"))
        updated = True

    if updated:
        key = _daily_kv_key(course_id, str(data.get("date") or _daily_today()))
        set_user_kv(user_id, key, json.dumps(data, ensure_ascii=False))
    response = _with_account_summary(data, user_id)
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
                item["claimable"] = False
                key = _daily_kv_key(course_id, str(data.get("date") or _daily_today()))
                set_user_kv(user_id, key, json.dumps(data, ensure_ascii=False))
                return _with_account_summary(data, user_id)

            reward = student_account_store.award_daily_quest_points(
                user_id=user_id,
                course_id=course_id,
                quest_id=quest_id,
                reward_points=int(
                    item.get("reward_points")
                    or _difficulty_reward_points(str(item.get("difficulty") or "easy"))
                ),
                date_key=str(data.get("date") or _daily_today()),
            )
            item["reward_claimed"] = True
            item["claimed_points"] = int(item.get("claimed_points") or 0) + int(
                (reward.get("reward") or {}).get("granted_points") or 0
            )
            item["claim_status"] = "claimed"
            item["claimable"] = False
            key = _daily_kv_key(course_id, str(data.get("date") or _daily_today()))
            set_user_kv(user_id, key, json.dumps(data, ensure_ascii=False))
            response = _with_account_summary(data, user_id)
            response["account"] = reward
            return response
    raise HTTPException(status_code=404, detail="quest not found")


def list_challenges(course_id: int | None):
    challenges = repo.list_active_challenges(course_id=course_id)
    return [c.model_dump() for c in challenges]


def list_daily_challenge_templates(
    *,
    enabled: bool | None = None,
    difficulty: str | None = None,
) -> dict[str, Any]:
    templates = repo.list_daily_challenge_templates(enabled=enabled, difficulty=difficulty)
    return {
        "items": templates,
        "total": len(templates),
        "quota": DAILY_DIFFICULTY_QUOTA,
        "points_by_difficulty": POINTS_BY_DIFFICULTY,
    }


def upsert_daily_challenge_template(body: dict[str, Any]) -> dict[str, Any]:
    try:
        template = repo.upsert_daily_challenge_template(body)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return {"item": template}


def reset_daily_challenge_templates() -> dict[str, Any]:
    count = repo.reset_default_daily_challenge_templates()
    return {"reset_count": count}


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
