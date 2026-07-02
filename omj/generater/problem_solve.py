from __future__ import annotations

import os
import random
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from typing import Any, Callable, Dict, Iterable, List, Optional, Sequence, Tuple

from generater.codebase_gen import generate_codebase
from generater.codebase_runner import (
    estimate_difficulty,
    run_codebase,
    run_codebase_batch,
    validate_result,
)
from generater.codebase_store import (
    compute_code_hash,
    list_cached_seeds,
    load_codebases,
    save_codebase,
)
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


def infer_tier_from_params(
    solves_count: int,
    strategy_level: int,
    branch_conditions: int,
) -> int:
    for tier, params in TIER_PARAMS.items():
        if (
            solves_count == params.solves_count
            and strategy_level == params.strategy_level
            and branch_conditions == params.branch_conditions
        ):
            return tier
    best_tier = 3
    best_score = 1_000_000
    for tier, params in TIER_PARAMS.items():
        score = (
            abs(params.solves_count - solves_count) * 2
            + abs(params.strategy_level - strategy_level)
            + abs(params.branch_conditions - branch_conditions) * 2
        )
        if score < best_score:
            best_score = score
            best_tier = tier
    return best_tier


def _buffer_tag_count_for_tier(tier: int, rng: random.Random) -> int:
    tier = int(max(1, min(5, tier)))
    if tier <= 2:
        return 1 + rng.randint(0, 1)
    if tier <= 4:
        return 3 + rng.randint(0, 1)
    return 5


def select_tags_for_tier(tag_pool: Sequence[str], tier: int, rng: random.Random) -> List[str]:
    if not tag_pool:
        return []
    tier = int(max(1, min(5, tier)))
    if len(tag_pool) > max_tag_count_for_tier(tier):
        count = _buffer_tag_count_for_tier(tier, rng)
    else:
        count = tag_count_for_tier(tier, rng)
    count = min(count, len(tag_pool))
    return pick_random_tags(tag_pool, count, rng)


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
    raw_result: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    if raw_result is None:
        raw_result = run_codebase(entry, seed)
    result = validate_result(
        raw_result,
        fallback_hash_tags=tags,
        expected_solves=params.solves_count,
        expected_branches=params.branch_conditions,
        main_huddle=params.strategy_level,
    )
    ai_result = result.get("ai_result")
    if ai_result is None:
        raise RuntimeError("ai_result missing after validation")
    storage_data = fix_gen(ai_result, tags, strict_tags=False)
    apply_question_format(
        storage_data,
        question_type=question_type,
        answer=result["answer"],
        rng=random.Random(seed or random.randint(1, 1_000_000_000)),
    )
    if isinstance(storage_data.get("data"), dict):
        storage_data["data"]["codebase_id"] = entry.get("id")
        storage_data["data"]["seed"] = seed
    return resample_storage_data(storage_data, coerce_text_only=True)


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
    hash_tags: list[str],
    min_difficulty_tier: int,
    max_difficulty_tier: int,
    question_count: int,
    seed: int | None = None,
    recent_codebase_seeds: dict[int, list[int]] | None = None,
    on_quest: Callable[[dict[str, Any]], None] | None = None,
) -> list[dict[str, Any]]:
    clean_tags = normalize_tags(hash_tags)
    if not clean_tags:
        raise ValueError('hash_tags must not be empty')
    if question_count < 3 or question_count > 500:
        raise ValueError('question_count must be between 3 and 500')

    min_tier = int(max(1, min(5, min_difficulty_tier)))
    max_tier = int(max(1, min(5, max_difficulty_tier)))
    if min_tier > max_tier:
        min_tier, max_tier = max_tier, min_tier

    min_required = min_tag_count_for_tier(max_tier)
    if len(clean_tags) < min_required:
        raise ValueError(
            f'최대 난이도({max_tier})를 위해 필요한 최소 태그 수는 {min_required}개입니다.'
        )

    recent_map: dict[int, set[int]] = {}
    recent_map_lock = threading.Lock()
    if recent_codebase_seeds:
        for key, values in recent_codebase_seeds.items():
            try:
                cid = int(key)
            except Exception:
                continue
            recent_map[cid] = {int(v) for v in values}

    rng = random.Random(seed or int.from_bytes(os.urandom(4), 'big'))
    tiers = [tier_for_index(i, question_count, min_tier, max_tier) for i in range(question_count)]
    per_problem_tags = [select_tags_for_tier(clean_tags, tier, rng) for tier in tiers]

    selected_tag_set = {normalize_tag(tag) for tag in clean_tags}

    def _entry_within_selection(entry: dict[str, Any]) -> bool:
        entry_tags = {normalize_tag(tag) for tag in (entry.get('tags') or []) if normalize_tag(tag)}
        return bool(entry_tags) and entry_tags.issubset(selected_tag_set)

    eligible_codebases = [entry for entry in load_codebases() if _entry_within_selection(entry)]

    new_count = question_count
    if eligible_codebases:
        new_count = 0
        if question_count >= 10:
            new_count += round(question_count * 0.2)
        if question_count >= 30:
            new_count += round(question_count * 0.1)
        new_count = min(question_count, new_count)
    reuse_count = max(0, question_count - new_count)

    plan: list[dict[str, Any]] = []
    reuse_cursor = 0
    for idx in range(question_count):
        tags_for_problem = per_problem_tags[idx] or clean_tags[:]
        tier = tiers[idx]
        if idx < reuse_count and eligible_codebases:
            entry = eligible_codebases[reuse_cursor % len(eligible_codebases)]
            reuse_cursor += 1
        else:
            entry = None
        plan.append({'index': idx, 'entry': entry, 'tags': tags_for_problem, 'tier': tier})

    fallback_candidates = [entry for entry in eligible_codebases]
    quests: list[dict[str, Any] | None] = [None] * question_count

    def _generate_single(task: dict[str, Any], seed_base: int) -> dict[str, Any]:
        entry = task['entry']
        tier = task['tier']
        tags_for_problem = task['tags']
        params = TIER_PARAMS.get(tier, TIER_PARAMS[3])
        local_rng = random.Random(seed_base)

        def _build(entry_obj: dict[str, Any], allow_fallback: bool) -> dict[str, Any]:
            code_hash = compute_code_hash(entry_obj.get('code') or '')
            entry_id = entry_obj.get('id')
            if entry_id is not None:
                with recent_map_lock:
                    avoid = set(recent_map.get(int(entry_id), set()))
            else:
                avoid = set()

            seed_candidates = list_cached_seeds(entry_id, code_hash, limit=150) if entry_id is not None else []
            seed_candidates = [s for s in seed_candidates if s not in avoid]
            seen: set[int] = set()

            # Try cached seeds in parallel batches first
            batch_size = 8
            for batch_start in range(0, len(seed_candidates), batch_size):
                batch = seed_candidates[batch_start:batch_start + batch_size]
                batch = [s for s in batch if s not in seen]
                if not batch:
                    continue
                seen.update(batch)
                batch_results = run_codebase_batch(entry_obj, batch, timeout_seconds=12.0)
                for idx, raw_result in enumerate(batch_results):
                    s = batch[idx]
                    if isinstance(raw_result, dict) and "_error" in raw_result:
                        continue
                    try:
                        quest = _build_quest_from_codebase(
                            entry_obj,
                            tags_for_problem,
                            params,
                            s,
                            question_type='short',
                            raw_result=raw_result,
                        )
                        if entry_id is not None:
                            with recent_map_lock:
                                recent_map.setdefault(int(entry_id), set()).add(int(s))
                        return quest
                    except Exception:
                        continue

            attempts = 0
            last_error: Exception | None = None
            while attempts < 300:
                batch_seeds = []
                while len(batch_seeds) < 8 and attempts < 300:
                    seed_value = local_rng.randint(1, 1_000_000_000)
                    if seed_value in avoid or seed_value in seen:
                        continue
                    attempts += 1
                    seen.add(seed_value)
                    batch_seeds.append(seed_value)
                if not batch_seeds:
                    break
                batch_results = run_codebase_batch(entry_obj, batch_seeds, timeout_seconds=12.0)
                for idx, raw_result in enumerate(batch_results):
                    seed_value = batch_seeds[idx]
                    if isinstance(raw_result, dict) and "_error" in raw_result:
                        continue
                    try:
                        quest = _build_quest_from_codebase(
                            entry_obj,
                            tags_for_problem,
                            params,
                            seed_value,
                            question_type='short',
                            raw_result=raw_result,
                        )
                        if entry_id is not None:
                            with recent_map_lock:
                                recent_map.setdefault(int(entry_id), set()).add(int(seed_value))
                        return quest
                    except Exception as exc:
                        last_error = exc
                        continue
                # If batch had no success, continue to next batch

            if allow_fallback and fallback_candidates:
                fallback_pool = [cand for cand in fallback_candidates if cand is not entry_obj]
                if fallback_pool:
                    fallback_entry = local_rng.choice(fallback_pool)
                    return _build(fallback_entry, False)
            raise last_error or RuntimeError('no valid seed for codebase')

        if entry is None:
            new_entry = _generate_and_store_codebase(tags_for_problem, tier, local_rng)
            return _build(new_entry, False)
        return _build(entry, True)

    max_parallel = int(os.getenv("PROBLEM_SET_MAX_PARALLEL", "32"))
    max_parallel = max(2, min(128, max_parallel))
    max_workers = min(max_parallel, max(2, question_count))
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        future_map = {
            executor.submit(_generate_single, task, rng.randint(1, 1_000_000_000)): task
            for task in plan
        }
        for future in as_completed(future_map):
            task = future_map[future]
            idx = task['index']
            quest = future.result()
            quests[idx] = quest
            if on_quest is not None:
                on_quest(quest)

    return [quest for quest in quests if quest is not None]
