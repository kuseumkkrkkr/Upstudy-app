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
import math
import random
import sqlite3
from datetime import datetime, timezone
from typing import Any, Dict, Iterable, List, Optional

from domain.level_test.models import LevelTestResult, PowerTest, SpeedTest
from exam_service import plan_exam_items
from generater.make import make
from rating_service import compute_barrier, compute_problem_rating
from services.ai.prompts import level_test_power_prompt, level_test_speed_prompt
from services.ai.providers.base import AIProvider
from storage.storage import DB_PATH, get_quest, store_data


PLACEMENT_QUESTION_COUNT = 50
PLACEMENT_VERSION = "placement-v1"

PLACEMENT_SUBJECT_TAGS: Dict[str, List[str]] = {
    "common_math_1": [
        "합차공식",
        "미정계수법",
        "나머지정리증명",
        "나머지정리활용",
        "항등식의성질",
        "다항식의덧셈",
        "다항식의뺄셈",
        "다항식의곱셈",
        "이차함수의평행이동",
        "역행렬의성질",
    ],
    "common_math_2": [
        "거리공식",
        "내분점공식",
        "외분점",
        "중점",
        "기울기",
        "점기울기형",
        "합집합",
        "교집합",
        "여집합",
        "부분집합",
    ],
    "algebra": [
        "지수방정식",
        "지수부등식",
        "로그법칙",
        "상용로그",
        "밑의변환",
        "등차수열의일반항",
        "등비수열의일반항",
        "시그마의성질",
        "시그마공식",
        "수학적귀납법",
    ],
    "calculus_1": [
        "좌극한",
        "우극한",
        "극한값",
        "평균변화율",
        "미분계수",
        "접선의기울기",
        "도함수의부호",
        "증가함수",
        "극댓값",
        "극솟값",
    ],
}

_TIER_PARAMS = {
    1: {"solves_count": 2, "strategy_level": 1, "branch_conditions": 0},
    2: {"solves_count": 3, "strategy_level": 1, "branch_conditions": 0},
    3: {"solves_count": 4, "strategy_level": 2, "branch_conditions": 1},
    4: {"solves_count": 5, "strategy_level": 2, "branch_conditions": 1},
    5: {"solves_count": 6, "strategy_level": 3, "branch_conditions": 2},
}


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


def placement_subject_mix() -> Dict[str, Any]:
    return {key: list(tags) for key, tags in PLACEMENT_SUBJECT_TAGS.items()}


def placement_difficulty_profile() -> Dict[str, Any]:
    return {
        "phase_1": {"count": 20, "tiers": [2, 2, 3, 3]},
        "phase_2": {"count": 20, "tiers": [3, 3, 4, 4]},
        "phase_3": {"count": 10, "tiers": [4, 5]},
    }


def build_placement_template_items() -> List[Dict[str, Any]]:
    """Build a complete 50-question placement template.

    Existing reusable quests are preferred. If a slot cannot be filled from
    the local question DB, a new quest is generated through the same generator
    used by exam paper creation.
    """
    plan = _build_placement_plan()
    used_quest_ids: set[str] = set()
    items: List[Dict[str, Any]] = []
    for spec in plan:
        quest = _find_reusable_quest(
            tags=spec["hash_tags"],
            used_quest_ids=used_quest_ids,
        )
        if quest is None:
            quest = _find_any_reusable_quest(used_quest_ids=used_quest_ids)
        if quest is None:
            quest = _generate_placement_quest(spec)
        quest_id = _quest_id(quest)
        if not quest_id:
            raise RuntimeError("generated placement quest has no quest_id")
        used_quest_ids.add(quest_id)
        data = quest.get("data", {}) or {}
        info = quest.get("info", {}) or {}
        actual_tags = info.get("hash_tag") or spec["hash_tags"]
        items.append(
            {
                **spec,
                "hash_tags": actual_tags,
                "quest_id": quest_id,
                "codebase_id": data.get("codebase_id"),
                "seed": data.get("seed"),
                "problem_rating": _problem_rating_for_quest(quest, actual_tags),
            }
        )
    return items


def quest_payloads_for_template_items(items: Iterable[Dict[str, Any]]) -> List[Dict[str, Any]]:
    payloads: List[Dict[str, Any]] = []
    for item in items:
        quest = get_quest(str(item.get("quest_id") or ""))
        if not quest:
            continue
        payloads.append(
            {
                **item,
                "quest": quest,
            }
        )
    return payloads


def _build_placement_plan() -> List[Dict[str, Any]]:
    subjects = list(PLACEMENT_SUBJECT_TAGS.keys())
    ranges = [
        {"key": subject, "tags": PLACEMENT_SUBJECT_TAGS[subject]}
        for subject in subjects
    ]
    # Reuse existing exam tag distribution logic for broad coverage, then
    # override phase/tier so placement keeps a stable 20/20/10 structure.
    base_items = plan_exam_items(
        ranges=ranges,
        difficulty_tier=3,
        question_count=PLACEMENT_QUESTION_COUNT,
        paper_type="aiflow",
    )
    rng = random.Random()
    plan: List[Dict[str, Any]] = []
    for item in base_items:
        index = int(item["item_index"])
        phase = 1 if index <= 20 else 2 if index <= 40 else 3
        if phase == 1:
            tier = [2, 2, 3, 3][(index - 1) % 4]
        elif phase == 2:
            tier = [3, 3, 4, 4][(index - 21) % 4]
        else:
            tier = [4, 5][(index - 41) % 2]
        params = _TIER_PARAMS[tier]
        tags = list(item.get("hash_tags") or [])
        if phase == 3:
            subject_tags = PLACEMENT_SUBJECT_TAGS.get(str(item.get("subject_key")), [])
            tags = _expand_tags(tags, subject_tags, rng, 3)
        plan.append(
            {
                "item_index": index,
                "phase": phase,
                "subject_key": item.get("subject_key") or "placement",
                "hash_tags": tags,
                "difficulty_tier": tier,
                "solves_count": params["solves_count"],
                "strategy_level": params["strategy_level"],
                "branch_conditions": params["branch_conditions"],
            }
        )
    return plan


def _expand_tags(
    tags: List[str],
    pool: List[str],
    rng: random.Random,
    target_count: int,
) -> List[str]:
    out = []
    for tag in tags + rng.sample(pool, min(len(pool), target_count)):
        if tag and tag not in out:
            out.append(tag)
        if len(out) >= target_count:
            break
    return out


def _find_reusable_quest(
    *,
    tags: List[str],
    used_quest_ids: set[str],
) -> Optional[Dict[str, Any]]:
    norm_targets = {_normalize_tag(tag) for tag in tags if _normalize_tag(tag)}
    if not norm_targets:
        return None
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        SELECT qd.quest_id, qd.hash_tag
        FROM quest_data qd
        JOIN quest_info qi ON qi.quest_id = qd.quest_id
        ORDER BY qd.rowid DESC
        """
    )
    rows = cur.fetchall()
    conn.close()
    candidates: List[str] = []
    for quest_id, raw_tags in rows:
        if quest_id in used_quest_ids:
            continue
        try:
            quest_tags = json.loads(raw_tags or "[]")
        except json.JSONDecodeError:
            quest_tags = []
        norm_quest_tags = {_normalize_tag(str(tag)) for tag in quest_tags}
        if norm_targets & norm_quest_tags:
            candidates.append(str(quest_id))
    if not candidates:
        return None
    random.shuffle(candidates)
    return get_quest(candidates[0])


def _find_any_reusable_quest(*, used_quest_ids: set[str]) -> Optional[Dict[str, Any]]:
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        SELECT quest_id
        FROM quest_data
        ORDER BY rowid DESC
        """
    )
    rows = cur.fetchall()
    conn.close()
    candidates = [str(row[0]) for row in rows if str(row[0]) not in used_quest_ids]
    if not candidates:
        return None
    random.shuffle(candidates)
    return get_quest(candidates[0])


def _generate_placement_quest(spec: Dict[str, Any]) -> Dict[str, Any]:
    storage_data = make(
        spec["hash_tags"],
        int(spec["solves_count"]),
        int(spec["strategy_level"]),
        int(spec["branch_conditions"]),
        None,
        False,
        None,
        "short",
    )
    if not store_data(storage_data):
        raise RuntimeError("failed to store generated placement quest")
    return storage_data


def _quest_id(quest: Dict[str, Any]) -> str:
    header = quest.get("header", {}) or {}
    return str(header.get("quest_id") or quest.get("quest_id") or "")


def _problem_rating_for_quest(quest: Dict[str, Any], fallback_tags: List[str]) -> float:
    info = quest.get("info", {}) or {}
    try:
        difficulty = float(info.get("difficulty") or 0)
    except (TypeError, ValueError):
        difficulty = 0.0
    try:
        main_huddle = float(info.get("main_huddle") or 0)
    except (TypeError, ValueError):
        main_huddle = 0.0
    steps = _flatten_steps(quest.get("solves") or [])
    tags = info.get("hash_tag") or fallback_tags
    tag_ratings = []
    for tag in tags:
        entries = []
        norm = _normalize_tag(str(tag))
        for step in steps:
            step_tags = step.get("hash_tag") or []
            if norm in {_normalize_tag(str(t)) for t in step_tags}:
                try:
                    entries.append(float(step.get("enter_huddle") or 0))
                except (TypeError, ValueError):
                    entries.append(0.0)
        barrier = compute_barrier(entries, main_huddle)
        tag_ratings.append(compute_problem_rating(difficulty, barrier))
    if not tag_ratings:
        return compute_problem_rating(difficulty, compute_barrier([], main_huddle))
    return sum(tag_ratings) / len(tag_ratings)


def _flatten_steps(steps: Any) -> List[Dict[str, Any]]:
    out: List[Dict[str, Any]] = []

    def visit(step: Dict[str, Any]) -> None:
        out.append(step)
        for branch in step.get("branches") or []:
            if isinstance(branch, dict):
                visit(branch)

    if isinstance(steps, list):
        for step in steps:
            if isinstance(step, dict):
                visit(step)
    return out


def _normalize_tag(tag: str) -> str:
    return (tag or "").strip().lstrip("#").strip().lower()
