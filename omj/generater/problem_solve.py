from __future__ import annotations

import os
import random
from dataclasses import dataclass
from typing import Any, Dict, Iterable, List, Optional, Sequence, Tuple

from generater.codebase_gen import generate_codebase
from generater.codebase_runner import (
    build_ai_result,
    estimate_difficulty,
    run_codebase,
    validate_result,
)
from generater.codebase_store import load_codebases, save_codebase
from generater.question_format import apply_question_format
from generater.fix_gen import fix_gen
from resampling import resample_storage_data


@dataclass(frozen=True)
class TierParams:
    solves_count: int
    strategy_level: int
    branch_conditions: int


TIER_PARAMS: Dict[int, TierParams] = {
    1: TierParams(solves_count=2, strategy_level=1, branch_conditions=0),
    2: TierParams(solves_count=3, strategy_level=1, branch_conditions=0),
    3: TierParams(solves_count=4, strategy_level=2, branch_conditions=1),
    4: TierParams(solves_count=5, strategy_level=2, branch_conditions=1),
    5: TierParams(solves_count=6, strategy_level=3, branch_conditions=2),
}


def min_tag_count_for_tier(tier: int) -> int:
    tier = int(max(1, min(5, tier)))
    if tier == 1:
        return 1
    if tier == 2:
        return 1
    if tier == 3:
        return 3
    if tier == 4:
        return 3
    return 5


def max_tag_count_for_tier(tier: int) -> int:
    tier = int(max(1, min(5, tier)))
    if tier == 1:
        return 1
    if tier == 2:
        return 3
    if tier == 3:
        return 3
    if tier == 4:
        return 5
    return 5


def tag_count_for_tier(tier: int, rng: random.Random) -> int:
    tier = int(max(1, min(5, tier)))
    if tier == 1:
        return 1
    if tier == 2:
        return 1 + rng.randint(0, 2)
    if tier == 3:
        return 3
    if tier == 4:
        return 3 + rng.randint(0, 2)
    return 5


def tier_for_index(index: int, total: int, min_tier: int, max_tier: int) -> int:
    min_tier = int(max(1, min(5, min_tier)))
    max_tier = int(max(1, min(5, max_tier)))
    if total <= 1 or min_tier == max_tier:
        return min_tier
    ratio = index / max(1, total - 1)
    value = min_tier + (max_tier - min_tier) * ratio
    return int(round(value))


def normalize_tag(tag: str) -> str:
    return tag.strip().lstrip("#").strip()


def normalize_tags(tags: Iterable[str]) -> List[str]:
    seen = set()
    results: List[str] = []
    for tag in tags:
        norm = normalize_tag(tag)
        if not norm:
            continue
        if norm in seen:
            continue
        seen.add(norm)
        results.append(f"#{norm}")
    return results


def pick_random_tags(pool: Sequence[str], count: int, rng: random.Random) -> List[str]:
    if count <= 0 or not pool:
        return []
    if len(pool) <= count:
        return list(pool)
    pool_list = list(pool)
    rng.shuffle(pool_list)
    return pool_list[:count]


def _infer_tier(entry: Dict[str, Any]) -> Optional[int]:
    tier = entry.get("tier")
    if isinstance(tier, int):
        return tier
    solves = entry.get("solves_count")
    strategy = entry.get("strategy_level")
    branch = entry.get("branch_conditions")
    for key, params in TIER_PARAMS.items():
        if (
            solves == params.solves_count
            and strategy == params.strategy_level
            and branch == params.branch_conditions
        ):
            return key
    return None


def _flow_tolerance_match(entry: Dict[str, Any], min_tier: int, max_tier: int) -> bool:
    solves = entry.get("solves_count")
    if solves is None or solves <= 0:
        return False
    for tier in range(min_tier, max_tier + 1):
        params = TIER_PARAMS.get(tier)
        if not params:
            continue
        if abs(params.solves_count - solves) <= 1:
            return True
    return False


def _tags_match(entry: Dict[str, Any], tag_pool: Sequence[str]) -> bool:
    pool_norm = {normalize_tag(tag) for tag in tag_pool if normalize_tag(tag)}
    entry_tags = [normalize_tag(tag) for tag in entry.get("tags", []) if normalize_tag(tag)]
    if not entry_tags:
        return False
    return set(entry_tags).issubset(pool_norm)


def filter_codebases(
    codebases: Sequence[Dict[str, Any]],
    tag_pool: Sequence[str],
    min_tier: int,
    max_tier: int,
) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
    strict_matches: List[Dict[str, Any]] = []
    relaxed_matches: List[Dict[str, Any]] = []
    for entry in codebases:
        solves = entry.get("solves_count")
        if solves is None or solves <= 0:
            continue
        if not _tags_match(entry, tag_pool):
            continue
        entry_tier = _infer_tier(entry)
        if entry_tier is not None and min_tier <= entry_tier <= max_tier:
            strict_matches.append(entry)
            continue
        if _flow_tolerance_match(entry, min_tier, max_tier):
            relaxed_matches.append(entry)
    return strict_matches, relaxed_matches


def _generate_and_store_codebase(
    tags: List[str],
    tier: int,
    rng: random.Random,
) -> Dict[str, Any]:
    params = TIER_PARAMS.get(tier, TIER_PARAMS[3])
    difficulty = estimate_difficulty(len(tags), params.solves_count, params.strategy_level, params.branch_conditions)
    entry = generate_codebase(
        tags=tags,
        difficulty=difficulty,
        solves_count=params.solves_count,
        strategy_level=params.strategy_level,
        branch_conditions=params.branch_conditions,
    )
    entry["tier"] = tier
    saved = save_codebase(entry)
    return saved


def _build_quest_from_codebase(
    entry: Dict[str, Any],
    tags: List[str],
    params: TierParams,
    seed: Optional[int],
    question_type: str,
) -> Dict[str, Any]:
    raw_result = run_codebase(entry, seed)
    result = validate_result(raw_result)
    ai_result = build_ai_result(
        problem=result["problem"],
        answer=result["answer"],
        solution=result["solution"],
        hash_tags=tags,
        solves_count=params.solves_count,
        strategy_level=params.strategy_level,
        branch_conditions=params.branch_conditions,
    )
    storage_data = fix_gen(ai_result, tags, strict_tags=False)
    apply_question_format(
        storage_data,
        question_type=question_type,
        answer=int(result["answer"]),
        rng=random.Random(seed or random.randint(1, 1_000_000_000)),
    )
    if isinstance(storage_data.get("data"), dict):
        storage_data["data"]["codebase_id"] = entry.get("id")
    return resample_storage_data(storage_data)


def _assign_counts(
    entries: List[Dict[str, Any]],
    total_needed: int,
    rng: random.Random,
) -> Tuple[List[Tuple[Dict[str, Any], int]], int]:
    assignments: List[Tuple[Dict[str, Any], int]] = []
    remaining = total_needed
    for entry in entries:
        if remaining <= 0:
            break
        count = rng.randint(1, min(4, remaining))
        assignments.append((entry, count))
        remaining -= count
    return assignments, remaining


def generate_problem_set(
    *,
    hash_tags: List[str],
    min_difficulty_tier: int,
    max_difficulty_tier: int,
    question_count: int,
    seed: Optional[int] = None,
) -> List[Dict[str, Any]]:
    clean_tags = normalize_tags(hash_tags)
    if not clean_tags:
        raise ValueError("hash_tags must not be empty")
    if question_count < 1:
        raise ValueError("question_count must be >= 1")

    min_tier = int(max(1, min(5, min_difficulty_tier)))
    max_tier = int(max(1, min(5, max_difficulty_tier)))
    if min_tier > max_tier:
        min_tier, max_tier = max_tier, min_tier

    min_required = min_tag_count_for_tier(max_tier)
    if len(clean_tags) < min_required:
        raise ValueError(f"최고 난이도(티어 {max_tier}) 최소 선택 개념 갯수는 {min_required}개입니다.")

    narrow_range = len(clean_tags) == min_required or len(clean_tags) < 10
    rng = random.Random(seed or int.from_bytes(os.urandom(4), "big"))

    tiers = [tier_for_index(i, question_count, min_tier, max_tier) for i in range(question_count)]
    tag_counts = [tag_count_for_tier(tier, rng) for tier in tiers]
    per_problem_tags = [pick_random_tags(clean_tags, count, rng) for count in tag_counts]

    codebases = load_codebases()
    strict_pool, relaxed_pool = filter_codebases(codebases, clean_tags, min_tier, max_tier)
    filtered_pool = list(strict_pool)
    if len(filtered_pool) < question_count:
        for entry in relaxed_pool:
            if entry not in filtered_pool:
                filtered_pool.append(entry)

    selected_codebases: List[Dict[str, Any]] = []
    generated_codebases: List[Dict[str, Any]] = []

    if narrow_range:
        assignments: List[Tuple[Dict[str, Any], int]] = []
        remaining = question_count
        if filtered_pool:
            rng.shuffle(filtered_pool)
            assignments, remaining = _assign_counts(filtered_pool, remaining, rng)
        while remaining > 0:
            tier = rng.randint(min_tier, max_tier)
            new_tags = pick_random_tags(clean_tags, max(min_required, min_tag_count_for_tier(tier)), rng)
            new_entry = _generate_and_store_codebase(new_tags, tier, rng)
            generated_codebases.append(new_entry)
            count = rng.randint(1, min(4, remaining))
            assignments.append((new_entry, count))
            remaining -= count
        for entry, count in assignments:
            selected_codebases.extend([entry] * count)
        rng.shuffle(selected_codebases)
        selected_codebases = selected_codebases[:question_count]
    else:
        new_count = max(1, round(question_count * 0.05))
        if filtered_pool and len(filtered_pool) >= question_count:
            rng.shuffle(filtered_pool)
            reuse_count = max(0, question_count - new_count)
            selected_codebases = filtered_pool[:reuse_count]
            for _ in range(new_count):
                tier = rng.randint(min_tier, max_tier)
                new_tags = pick_random_tags(clean_tags, max(min_required, min_tag_count_for_tier(tier)), rng)
                new_entry = _generate_and_store_codebase(new_tags, tier, rng)
                generated_codebases.append(new_entry)
                selected_codebases.append(new_entry)
        else:
            if filtered_pool:
                selected_codebases = list(filtered_pool)
            deficit = question_count - len(selected_codebases)
            for _ in range(deficit):
                tier = rng.randint(min_tier, max_tier)
                new_tags = pick_random_tags(clean_tags, max(min_required, min_tag_count_for_tier(tier)), rng)
                new_entry = _generate_and_store_codebase(new_tags, tier, rng)
                generated_codebases.append(new_entry)
                selected_codebases.append(new_entry)

    quests: List[Dict[str, Any]] = []
    for idx in range(question_count):
        entry = selected_codebases[idx % len(selected_codebases)]
        tier = tiers[idx]
        params = TIER_PARAMS.get(tier, TIER_PARAMS[3])
        tags_for_problem = per_problem_tags[idx]
        if not tags_for_problem:
            tags_for_problem = clean_tags[:]
        seed_value = rng.randint(1, 1_000_000_000)
        try:
            quest = _build_quest_from_codebase(
                entry,
                tags_for_problem,
                params,
                seed_value,
                question_type="short",
            )
        except Exception:
            new_entry = _generate_and_store_codebase(tags_for_problem, tier, rng)
            quest = _build_quest_from_codebase(
                new_entry,
                tags_for_problem,
                params,
                seed_value,
                question_type="short",
            )
        quests.append(quest)

    return quests
