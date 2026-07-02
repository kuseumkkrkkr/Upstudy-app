"""Challenge generation and evaluation engine.

Provides:
- generate_daily_challenge
- generate_weekly_challenge
- evaluate_attempt
- calculate_reward
"""
from __future__ import annotations

import json
from typing import Any, Dict, List

from domain.challenge.models import Challenge
from domain.challenge.repository import create_challenge
from services.ai.providers.base import AIProvider


def _generate_problems(
    ai_provider: AIProvider,
    course_id: int,
    label: str,
    count: int,
    difficulty: str,
) -> List[Dict[str, Any]]:
    """Ask the AI provider for *count* multiple-choice problems."""
    prompt = (
        f"Generate {count} {difficulty} math challenge problems for course {course_id} "
        f"on {label}. Return a JSON array where each element has keys: "
        f'"question" (str), "options" (list of 4 str), "correct_index" (int 0-3), '
        f'"time_budget_seconds" (int).'
    )
    result = ai_provider.generate(prompt)
    text = result.get("text", "[]")
    try:
        parsed = json.loads(text)
        if isinstance(parsed, list):
            return parsed
        if isinstance(parsed, dict) and "problems" in parsed:
            return parsed["problems"]
        return []
    except json.JSONDecodeError:
        return []


def generate_daily_challenge(
    course_id: int,
    ai_provider: AIProvider,
    date_str: str,
) -> Challenge:
    """Generate a daily challenge with 5 medium-difficulty problems."""
    problems = _generate_problems(
        ai_provider=ai_provider,
        course_id=course_id,
        label=date_str,
        count=5,
        difficulty="medium",
    )
    challenge = Challenge(
        course_id=course_id,
        title=f"Daily Challenge {date_str}",
        challenge_type="daily",
        difficulty="medium",
        problems_json=json.dumps(problems, ensure_ascii=False),
        reward_points=50,
        time_limit_seconds=300,
        start_date=date_str,
        end_date=date_str,
        status="active",
    )
    challenge_id = create_challenge(challenge)
    challenge.id = challenge_id
    return challenge


def generate_weekly_challenge(
    course_id: int,
    ai_provider: AIProvider,
    week_str: str,
) -> Challenge:
    """Generate a weekly challenge with 10 mixed-difficulty problems."""
    problems = _generate_problems(
        ai_provider=ai_provider,
        course_id=course_id,
        label=week_str,
        count=10,
        difficulty="mixed",
    )
    challenge = Challenge(
        course_id=course_id,
        title=f"Weekly Challenge {week_str}",
        challenge_type="weekly",
        difficulty="mixed",
        problems_json=json.dumps(problems, ensure_ascii=False),
        reward_points=150,
        time_limit_seconds=600,
        start_date=week_str,
        end_date=week_str,
        status="active",
    )
    challenge_id = create_challenge(challenge)
    challenge.id = challenge_id
    return challenge


def evaluate_attempt(challenge: Challenge, answers: List[int]) -> Dict[str, Any]:
    """Evaluate a student's answers against the challenge problems.

    Returns a dict with score (0-100), correct_count, total, and time_bonus.
    """
    try:
        problems: List[Dict[str, Any]] = json.loads(challenge.problems_json)
    except json.JSONDecodeError:
        problems = []

    total = len(problems)
    if total == 0:
        return {"score": 0.0, "correct_count": 0, "total": 0, "time_bonus": 0}

    correct_count = 0
    for i, problem in enumerate(problems):
        correct_index = problem.get("correct_index")
        if correct_index is not None and i < len(answers) and answers[i] == correct_index:
            correct_count += 1

    accuracy = correct_count / total
    score = accuracy * 100.0
    return {
        "score": score,
        "correct_count": correct_count,
        "total": total,
        "time_bonus": 0,
    }


def calculate_reward(
    challenge: Challenge,
    progress: "StudentChallengeProgress",
) -> int:
    """Calculate total reward points including bonuses.

    - Base reward = challenge.reward_points
    - Perfect score (100): +50% bonus
    - First attempt (attempts == 1): +30% bonus
    """
    from domain.challenge.models import StudentChallengeProgress

    base = float(challenge.reward_points)
    bonus = 0.0
    if progress.score >= 100.0:
        bonus += base * 0.5
    if progress.attempts == 1:
        bonus += base * 0.3
    return int(base + bonus)
