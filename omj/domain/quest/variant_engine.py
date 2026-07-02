"""Quest variant engine: generation and local transformations.

Provides:
- generate_variant          : AI-driven variant generation via quest_variant_prompt
- apply_difficulty_adjustment: local difficulty tuning (+/- distractors, scaffolding)
- _scaffold_problem         : wrap with step-by-step sub-questions
- _speed_drill_variant      : strip explanation, tighten time limit
"""
from __future__ import annotations

import json
from typing import Any, Dict, List, Optional

from domain.quest.models import QuestVariant
from services.ai.prompts import quest_variant_prompt
from services.ai.providers.base import AIProvider


VARIANT_TYPES = {
    "easier",
    "harder",
    "hint_heavy",
    "scaffolded",
    "speed_drill",
    "proof_variant",
}


def generate_variant(
    original_problem: Dict[str, Any],
    variant_type: str,
    ai_provider: AIProvider,
) -> QuestVariant:
    """Generate a quest variant using AI and return a ``QuestVariant`` model.

    The *original_problem* dict is expected to contain:
        - question (str)
        - options (list[str])
        - correct_index (int)
        - difficulty (str)
        - topic (str)
        - explanation (str)

    The AI is asked to return JSON matching the variant schema, which is stored
    verbatim in ``generated_problem_json``.
    """
    if variant_type not in VARIANT_TYPES:
        raise ValueError(f"Unsupported variant_type: {variant_type}")

    original_flow = json.dumps(original_problem, ensure_ascii=False)
    instructions = _build_instructions(variant_type, original_problem)
    prompt = quest_variant_prompt(variant_type, original_flow, instructions)

    response = ai_provider.generate(
        prompt,
        temperature=0.7,
        max_tokens=4096,
    )
    text = response.get("text", "{}")
    try:
        parsed = json.loads(text)
    except json.JSONDecodeError:
        parsed = {}

    generated_problem_json = json.dumps(parsed, ensure_ascii=False)

    ai_confidence: Optional[float] = None
    if isinstance(parsed, dict):
        ai_confidence = parsed.get("confidence")
        if isinstance(ai_confidence, (int, float)):
            ai_confidence = float(ai_confidence)
        else:
            ai_confidence = None

    difficulty_adjustment = _default_adjustment(variant_type)

    return QuestVariant(
        original_quest_id=original_problem.get("quest_id", 0),
        variant_type=variant_type,
        generated_problem_json=generated_problem_json,
        difficulty_adjustment=difficulty_adjustment,
        ai_confidence=ai_confidence,
    )


def apply_difficulty_adjustment(problem: Dict[str, Any], adjustment: int) -> Dict[str, Any]:
    """Apply a local difficulty adjustment to a problem dict.

    Rules:
        +1 : add distractor options, increase calculations
        -1 : remove distractors, add scaffolding hints
         0 : no change
    """
    if adjustment == 0:
        return dict(problem)

    result = dict(problem)
    options: List[str] = list(result.get("options", []))
    explanation: str = result.get("explanation", "")

    if adjustment > 0:
        # Add distractor options
        while len(options) < 6:
            options.append(f"(distractor {len(options) + 1})")
        result["options"] = options
        result["difficulty"] = _bump_difficulty(result.get("difficulty", "medium"), 1)
    elif adjustment < 0:
        # Remove distractors down to 3, add scaffolding hints
        while len(options) > 3:
            options.pop()
        result["options"] = options
        if explanation:
            result["explanation"] = f"[힌트] {explanation}"
        else:
            result["explanation"] = "[힌트] 단계별로 생각해 보세요."
        result["difficulty"] = _bump_difficulty(result.get("difficulty", "medium"), -1)

    return result


def _scaffold_problem(problem: Dict[str, Any]) -> Dict[str, Any]:
    """Wrap a problem with step-by-step sub-questions for guided solving."""
    result = dict(problem)
    steps = [
        "1. 주어진 조건을 정리하세요.",
        "2. 적용할 공식이나 개념을 떠올리세요.",
        "3. 계산을 단계별로 진행하세요.",
        "4. 최종 답을 선택하세요.",
    ]
    result["scaffold_steps"] = steps
    result["variant_note"] = "scaffolded"
    return result


def _speed_drill_variant(problem: Dict[str, Any]) -> Dict[str, Any]:
    """Strip explanation and apply a stricter time limit for speed drills."""
    result = dict(problem)
    result.pop("explanation", None)
    original_time = result.get("time_budget_seconds", 60)
    result["time_budget_seconds"] = max(10, original_time // 2)
    result["variant_note"] = "speed_drill"
    return result


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------


def _build_instructions(variant_type: str, original_problem: Dict[str, Any]) -> str:
    """Build human-readable instructions for the AI prompt."""
    base = {
        "easier": "쉬운 버전으로 변형: 보기를 단순화하고, 계산량을 줄이세요.",
        "harder": "어려운 버전으로 변형: 보기에 교란 항목을 추가하고, 계산량을 늘리세요.",
        "hint_heavy": "힌트 중심 변형: 각 단계에 풀이 힌트를 풍부하게 추가하세요.",
        "scaffolded": "발판 변형: 문제를 여러 하위 단계로 나누어 제시하세요.",
        "speed_drill": "속도 훈련 변형: 해설을 제거하고 시간 제한을 짧게 하세요.",
        "proof_variant": "증명 변형: 논리적 추론과 증명 과정을 요구하도록 변경하세요.",
    }
    return base.get(variant_type, "주어진 문제를 변형 유형에 맞게 재구성하세요.")


def _default_adjustment(variant_type: str) -> int:
    """Return the default difficulty adjustment for a given variant type."""
    mapping = {
        "easier": -1,
        "harder": 1,
        "hint_heavy": 0,
        "scaffolded": 0,
        "speed_drill": 0,
        "proof_variant": 1,
    }
    return mapping.get(variant_type, 0)


def _bump_difficulty(current: str, delta: int) -> str:
    """Bump a difficulty string by *delta* steps."""
    levels = ["easy", "medium", "hard"]
    try:
        idx = levels.index(current)
    except ValueError:
        idx = 1
    new_idx = max(0, min(len(levels) - 1, idx + delta))
    return levels[new_idx]
