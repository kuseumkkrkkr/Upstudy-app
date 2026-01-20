from typing import Any, Dict, List, Optional

from generater.ai_gen import ai_gen
from generater.fix_gen import fix_gen
from generater.prompt_builder import build_prompt
from storage.storage import get_quest


def make(
    hash_tags: List[str],
    solves_count: int,
    strategy_level: int,
    branch_conditions: int,
    reference_quest_id: Optional[str] = None,
    strict_tags: bool = True,
) -> Dict[str, Any]:
    """
    Generate a quest with branching flows and a strategy difficulty level.

    Args:
        hash_tags: Hash tag list describing the topic.
        solves_count: Number of root solve steps (top-level flows).
        strategy_level: Strategy difficulty level (1-3).
        branch_conditions: Number of conditional lanes to branch on.
        reference_quest_id: Optional quest id to reuse as reference.
    """
    if solves_count < 1:
        raise ValueError("solves_count must be >= 1")
    if any(not isinstance(tag, str) for tag in hash_tags):
        raise TypeError("hash_tags must be a list of strings")
    if strategy_level not in (1, 2, 3):
        raise ValueError("strategy_level must be 1, 2, or 3")
    if branch_conditions < 0:
        raise ValueError("branch_conditions must be >= 0")

    reference_quest = None
    if reference_quest_id:
        reference_quest = get_quest(reference_quest_id)
        if reference_quest is None:
            raise ValueError(f"reference quest not found: {reference_quest_id}")

    prompt = build_prompt(
        hash_tags,
        solves_count,
        strategy_level,
        branch_conditions,
        reference_quest,
    )
    ai_result = ai_gen(prompt)

    if len(ai_result.solves) != solves_count:
        raise ValueError(
            f"AI returned {len(ai_result.solves)} solves; expected {solves_count}"
        )

    ai_result = ai_result.model_copy(update={"main_huddle": strategy_level})

    return fix_gen(ai_result, hash_tags, strict_tags=strict_tags)
