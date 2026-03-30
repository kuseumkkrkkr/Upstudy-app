from typing import Any, Dict, List, Optional

import random

from generater.ai_gen import ai_gen
from generater.codebase_runner import (
    build_ai_result,
    estimate_difficulty,
    run_codebase,
    select_codebase,
    validate_result,
)
from generater.codebase_store import load_codebases
from generater.codebase_gen import generate_codebase
from generater.codebase_store import save_codebase
from generater.question_format import apply_question_format
from generater.fix_gen import fix_gen
from generater.prompt_builder import build_prompt
from resampling import resample_storage_data
from storage.storage import get_quest


def make(
    hash_tags: List[str],
    solves_count: int,
    strategy_level: int,
    branch_conditions: int,
    reference_quest_id: Optional[str] = None,
    strict_tags: bool = True,
    seed: Optional[int] = None,
    question_type: Optional[str] = None,
    used_codebase_ids: Optional[set[int]] = None,
) -> Dict[str, Any]:
    """
    Generate a quest using registered codebases.
    """
    if solves_count < 1:
        raise ValueError("solves_count must be >= 1")
    if any(not isinstance(tag, str) for tag in hash_tags):
        raise TypeError("hash_tags must be a list of strings")
    if strategy_level not in (1, 2, 3):
        raise ValueError("strategy_level must be 1, 2, or 3")
    if branch_conditions < 0:
        raise ValueError("branch_conditions must be >= 0")

    if reference_quest_id:
        reference_quest = get_quest(reference_quest_id)
        if reference_quest is None:
            raise ValueError(f"reference quest not found: {reference_quest_id}")

    clean_tags = [tag.strip() for tag in hash_tags if tag.strip()]
    desired_difficulty = estimate_difficulty(
        len(clean_tags),
        solves_count,
        strategy_level,
        branch_conditions,
    )

    codebases = load_codebases()
    if not codebases:
        difficulty = estimate_difficulty(
            len(clean_tags),
            solves_count,
            strategy_level,
            branch_conditions,
        )
        entry = generate_codebase(
            tags=clean_tags,
            difficulty=difficulty,
            solves_count=solves_count,
            strategy_level=strategy_level,
            branch_conditions=branch_conditions,
        )
        entry["tier"] = None
        codebases = [save_codebase(entry)]

    if used_codebase_ids is not None:
        available = [entry for entry in codebases if entry.get("id") not in used_codebase_ids]
        if not available:
            difficulty = estimate_difficulty(
                len(clean_tags),
                solves_count,
                strategy_level,
                branch_conditions,
            )
            entry = generate_codebase(
                tags=clean_tags,
                difficulty=difficulty,
                solves_count=solves_count,
                strategy_level=strategy_level,
                branch_conditions=branch_conditions,
            )
            entry["tier"] = None
            codebases = [save_codebase(entry)]
        else:
            codebases = available
    rng = random.Random(seed)
    choice_rng = random.Random(seed or random.randint(1, 1_000_000_000))
    entry = select_codebase(codebases, clean_tags, desired_difficulty, rng)

    last_error: Optional[Exception] = None
    for _ in range(max(1, len(codebases))):
        try:
            raw_result = run_codebase(entry, seed)
            result = validate_result(raw_result)
            ai_result = build_ai_result(
                problem=result["problem"],
                answer=result["answer"],
                solution=result["solution"],
                hash_tags=clean_tags,
                solves_count=solves_count,
                strategy_level=strategy_level,
                branch_conditions=branch_conditions,
            )
            storage_data = fix_gen(ai_result, clean_tags, strict_tags=strict_tags)
            if question_type:
                apply_question_format(
                    storage_data,
                    question_type=question_type,
                    answer=int(result["answer"]),
                    rng=choice_rng,
                )
            if isinstance(storage_data.get("data"), dict):
                storage_data["data"]["codebase_id"] = entry.get("id")
            return resample_storage_data(storage_data)
        except Exception as exc:
            last_error = exc
            remaining = [item for item in codebases if item.get("id") != entry.get("id")]
            if not remaining:
                break
            entry = select_codebase(remaining, clean_tags, desired_difficulty, rng)

    raise RuntimeError(f"codebase generation failed: {last_error}")


def make_legacy(
    hash_tags: List[str],
    solves_count: int,
    strategy_level: int,
    branch_conditions: int,
    reference_quest_id: Optional[str] = None,
    strict_tags: bool = True,
    seed: Optional[int] = None,
) -> Dict[str, Any]:
    """
    Legacy AI generation pipeline (prompt -> ai_gen -> fix_gen).
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

    storage_data = fix_gen(ai_result, hash_tags, strict_tags=strict_tags)
    return resample_storage_data(storage_data)
