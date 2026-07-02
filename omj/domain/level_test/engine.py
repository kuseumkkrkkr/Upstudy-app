"""Level Test engine: generation, evaluation, and aggregation.

Provides:
- generate_speed_test  : AI-driven speed-test creation
- generate_power_test  : AI-driven power-test creation
- evaluate_speed_test  : accuracy-based scoring
- evaluate_power_test  : heuristic placeholder scoring
- aggregate_results    : combine into LevelTestResult
"""
from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from domain.level_test.models import LevelTestResult, PowerTest, SpeedTest
from services.ai.prompts import level_test_power_prompt, level_test_speed_prompt
from services.ai.providers.base import AIProvider


def generate_speed_test(
    user_id: str,
    topics: List[str],
    difficulty: str,
    ai_provider: AIProvider,
) -> SpeedTest:
    """Generate a SpeedTest with 10 problems via AI.

    The AI is asked to return JSON matching an internal schema where each
    problem has ``question``, ``options`` (4 items), ``correct_index``,
    and ``time_budget_seconds``.
    """
    prompt = level_test_speed_prompt(topics, difficulty)

    # Internal schema for structured generation
    class _SpeedProblemSchema:
        """Lightweight schema description passed to the provider."""

        pass

    # Build a JSON schema inline so the provider can request structured output
    schema_dict: Dict[str, Any] = {
        "type": "object",
        "properties": {
            "problems": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "question": {"type": "string"},
                        "options": {
                            "type": "array",
                            "items": {"type": "string"},
                            "minItems": 4,
                            "maxItems": 4,
                        },
                        "correct_index": {"type": "integer", "minimum": 0, "maximum": 3},
                        "time_budget_seconds": {"type": "integer", "minimum": 1},
                    },
                    "required": ["question", "options", "correct_index", "time_budget_seconds"],
                },
                "minItems": 10,
                "maxItems": 10,
            }
        },
        "required": ["problems"],
    }

    # TODO: integrate JobStateMachine for async generation (Wave 4)
    response = ai_provider.generate(
        prompt,
        temperature=0.7,
        max_tokens=4096,
    )
    text = response.get("text", "{}")
    try:
        parsed = json.loads(text)
    except json.JSONDecodeError:
        parsed = {"problems": []}

    problems = parsed.get("problems", [])
    if len(problems) < 10:
        # Pad with placeholders if the AI returns fewer than expected
        while len(problems) < 10:
            problems.append(
                {
                    "question": "(placeholder)",
                    "options": ["A", "B", "C", "D"],
                    "correct_index": 0,
                    "time_budget_seconds": 60,
                }
            )

    total_time = sum(p.get("time_budget_seconds", 60) for p in problems)

    return SpeedTest(
        user_id=user_id,
        topic=", ".join(topics),
        difficulty=difficulty,
        time_limit_seconds=total_time,
        problems_json=json.dumps(problems, ensure_ascii=False),
        status="pending",
    )


def generate_power_test(
    user_id: str,
    weakness_report: str,
    ai_provider: AIProvider,
) -> PowerTest:
    """Generate a PowerTest with 5 deep-dive problems via AI.

    The AI is asked to return JSON where each problem has ``question``,
    ``expected_explanation``, and ``time_budget_seconds``.
    """
    prompt = level_test_power_prompt(weakness_report)

    response = ai_provider.generate(
        prompt,
        temperature=0.7,
        max_tokens=4096,
    )
    text = response.get("text", "{}")
    try:
        parsed = json.loads(text)
    except json.JSONDecodeError:
        parsed = {"problems": []}

    problems = parsed.get("problems", [])
    if len(problems) < 5:
        while len(problems) < 5:
            problems.append(
                {
                    "question": "(placeholder)",
                    "expected_explanation": "",
                    "time_budget_seconds": 300,
                }
            )

    total_time = sum(p.get("time_budget_seconds", 300) for p in problems)

    return PowerTest(
        user_id=user_id,
        topic="weakness_deep_dive",
        difficulty="hard",
        time_limit_seconds=total_time,
        problems_json=json.dumps(problems, ensure_ascii=False),
        weakness_report_input=weakness_report,
        status="pending",
    )


def evaluate_speed_test(test: SpeedTest) -> float:
    """Return an accuracy-based score (0-100) for a submitted speed test."""
    if test.problems_json is None or test.submitted_answers_json is None:
        return 0.0

    try:
        problems: List[Dict[str, Any]] = json.loads(test.problems_json)
        answers: List[Optional[int]] = json.loads(test.submitted_answers_json)
    except json.JSONDecodeError:
        return 0.0

    if not problems:
        return 0.0

    correct = 0
    for idx, problem in enumerate(problems):
        correct_index = problem.get("correct_index")
        submitted = answers[idx] if idx < len(answers) else None
        if submitted is not None and submitted == correct_index:
            correct += 1

    return (correct / len(problems)) * 100.0


def evaluate_power_test(test: PowerTest) -> float:
    """Return a placeholder heuristic score (0-100) for a submitted power test.

    Currently scores based on total explanation length as a proxy for effort.
    """
    if test.submitted_answers_json is None:
        return 0.0

    try:
        answers: List[Dict[str, Any]] = json.loads(test.submitted_answers_json)
    except json.JSONDecodeError:
        return 0.0

    if not answers:
        return 0.0

    total_chars = 0
    for ans in answers:
        explanation = ans.get("explanation", "") if isinstance(ans, dict) else str(ans)
        total_chars += len(explanation)

    # Heuristic: 500 chars ≈ 100 points per answer, capped at 100
    avg = total_chars / len(answers)
    score = min(100.0, (avg / 500.0) * 100.0)
    return round(score, 2)


def aggregate_results(
    user_id: str,
    speed_tests: List[SpeedTest],
    power_tests: List[PowerTest],
) -> LevelTestResult:
    """Aggregate speed and power tests into a single result record."""
    speed_scores = [t.score for t in speed_tests if t.score is not None]
    power_scores = [t.score for t in power_tests if t.score is not None]

    overall_speed = sum(speed_scores) / len(speed_scores) if speed_scores else 0.0
    overall_power = sum(power_scores) / len(power_scores) if power_scores else 0.0

    topic_breakdown: Dict[str, Dict[str, Any]] = {}
    for t in speed_tests:
        if t.topic not in topic_breakdown:
            topic_breakdown[t.topic] = {"speed_count": 0, "speed_sum": 0.0}
        topic_breakdown[t.topic]["speed_count"] += 1
        topic_breakdown[t.topic]["speed_sum"] += t.score or 0.0

    for t in power_tests:
        if t.topic not in topic_breakdown:
            topic_breakdown[t.topic] = {"power_count": 0, "power_sum": 0.0}
        topic_breakdown[t.topic]["power_count"] += 1
        topic_breakdown[t.topic]["power_sum"] += t.score or 0.0

    # Compute averages inside the breakdown
    for topic, data in topic_breakdown.items():
        sc = data.get("speed_count", 0)
        ss = data.get("speed_sum", 0.0)
        pc = data.get("power_count", 0)
        ps = data.get("power_sum", 0.0)
        data["speed_avg"] = round(ss / sc, 2) if sc else None
        data["power_avg"] = round(ps / pc, 2) if pc else None

    return LevelTestResult(
        user_id=user_id,
        overall_speed=round(overall_speed, 2),
        overall_power=round(overall_power, 2),
        topic_breakdown=topic_breakdown,
    )
