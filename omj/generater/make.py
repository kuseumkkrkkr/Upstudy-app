from typing import Any, Callable, Dict, List, Optional, Set

import atexit
import hashlib
import os
import random
import threading
import time
from concurrent.futures import ThreadPoolExecutor

# 코드베이스 목록 캐시 (60초 TTL)
_codebases_cache: Optional[List[Dict[str, Any]]] = None
_codebases_cache_at: float = 0.0
_CODEBASES_CACHE_TTL = 60.0
_RUNTIME_SEED_BACKFILL_ENABLED = os.getenv(
    "RUNTIME_SEED_BACKFILL_ENABLED",
    "1",
).strip().lower() in {"1", "true", "yes", "on"}
_RUNTIME_SEED_BACKFILL_COUNT = max(
    0,
    int(os.getenv("RUNTIME_SEED_BACKFILL_COUNT", "4")),
)
_RUNTIME_SEED_BACKFILL_ATTEMPTS = max(
    _RUNTIME_SEED_BACKFILL_COUNT,
    int(os.getenv("RUNTIME_SEED_BACKFILL_ATTEMPTS", "16")),
)
_RUNTIME_SEED_BACKFILL_WORKERS = max(
    1,
    int(os.getenv("RUNTIME_SEED_BACKFILL_WORKERS", "1")),
)
_CODEBASE_CACHED_BATCH_TIMEOUT_SEC = max(
    1.0,
    float(os.getenv("CODEBASE_CACHED_BATCH_TIMEOUT_SEC", "8")),
)
_CODEBASE_RUNTIME_BATCH_TIMEOUT_SEC = max(
    1.0,
    float(os.getenv("CODEBASE_RUNTIME_BATCH_TIMEOUT_SEC", "6")),
)
_CODEBASE_RUNTIME_SEED_LIMITS_RAW = os.getenv("CODEBASE_RUNTIME_SEED_LIMITS", "32,32")
_runtime_seed_backfill_executor: Optional[ThreadPoolExecutor] = None
_runtime_seed_backfill_lock = threading.Lock()
_runtime_seed_backfill_inflight: set[tuple[int, str]] = set()


def _parse_seed_limits(raw: str) -> List[int]:
    values: List[int] = []
    for part in (raw or "").split(","):
        text = part.strip()
        if not text:
            continue
        try:
            value = int(text)
        except ValueError:
            continue
        if value > 0:
            values.append(min(value, 100))
    return values or [32, 32]


def _seed_from_request_signature(request_signature: Optional[str]) -> Optional[int]:
    if not request_signature:
        return None
    digest = hashlib.sha256(str(request_signature).encode("utf-8")).digest()
    return int.from_bytes(digest[:8], "big")


def _order_seed_candidates(
    candidates: List[int],
    request_signature: Optional[str],
    *,
    entry_id: Optional[int] = None,
    code_hash: str = "",
) -> List[int]:
    if not request_signature:
        return list(candidates)

    def rank(seed_value: int) -> str:
        material = f"{request_signature}:{entry_id or ''}:{code_hash}:{int(seed_value)}"
        return hashlib.sha256(material.encode("utf-8")).hexdigest()

    return sorted((int(candidate) for candidate in candidates), key=rank)


def _load_codebases_cached() -> List[Dict[str, Any]]:
    global _codebases_cache, _codebases_cache_at
    if _codebases_cache is None or time.time() - _codebases_cache_at > _CODEBASES_CACHE_TTL:
        _codebases_cache = load_codebases()
        _codebases_cache_at = time.time()
    return list(_codebases_cache)


def _runtime_seed_backfill_pool() -> ThreadPoolExecutor:
    global _runtime_seed_backfill_executor
    with _runtime_seed_backfill_lock:
        if _runtime_seed_backfill_executor is None:
            _runtime_seed_backfill_executor = ThreadPoolExecutor(
                max_workers=_RUNTIME_SEED_BACKFILL_WORKERS,
                thread_name_prefix="runtime-seed-backfill",
            )
        return _runtime_seed_backfill_executor


def _shutdown_runtime_seed_backfill_pool() -> None:
    global _runtime_seed_backfill_executor
    with _runtime_seed_backfill_lock:
        if _runtime_seed_backfill_executor is not None:
            _runtime_seed_backfill_executor.shutdown(wait=False, cancel_futures=True)
            _runtime_seed_backfill_executor = None


atexit.register(_shutdown_runtime_seed_backfill_pool)


def _schedule_runtime_seed_backfill(entry: Dict[str, Any], code_hash: str) -> None:
    if not _RUNTIME_SEED_BACKFILL_ENABLED or _RUNTIME_SEED_BACKFILL_COUNT <= 0:
        return
    entry_id = entry.get("id")
    if entry_id is None:
        return
    key = (int(entry_id), code_hash)
    with _runtime_seed_backfill_lock:
        if key in _runtime_seed_backfill_inflight:
            return
        _runtime_seed_backfill_inflight.add(key)

    entry_snapshot = dict(entry)

    def _worker() -> None:
        try:
            validate_codebase(
                entry_snapshot,
                attempts_per_codebase=_RUNTIME_SEED_BACKFILL_ATTEMPTS,
                max_successes_per_codebase=_RUNTIME_SEED_BACKFILL_COUNT,
                source="runtime_backfill",
            )
        except Exception:
            # Backfill is best-effort and must never affect the user request.
            pass
        finally:
            with _runtime_seed_backfill_lock:
                _runtime_seed_backfill_inflight.discard(key)

    _runtime_seed_backfill_pool().submit(_worker)

from generater.codebase_runner import (
    estimate_difficulty,
    run_codebase,
    run_codebase_batch,
    select_codebase,
    validate_result,
)
from generater.codebase_store import (
    compute_code_hash,
    count_cached_seeds,
    list_cached_seeds,
    load_codebases,
    record_seed_attempt,
    save_cached_seed,
    save_seed_log,
    save_seed_logs_batch,
)
from generater.codebase_gen import generate_codebase
from generater.codebase_store import save_codebase
from generater.question_format import apply_question_format
from generater.seed_validator import validate_codebase
from generater.fix_gen import fix_gen
from generater.tag_agent import TagAssignmentError, enforce_storage_step_tags
from generater.problem_solve import (
    infer_tier_from_params,
    max_tag_count_for_tier,
    normalize_tags,
    select_tags_for_tier,
)
from resampling import resample_storage_data
from services.jobs.cancellation import check_cancelled
from storage.storage import get_quest


def _extract_stage(message: str) -> Optional[str]:
    if not message:
        return None
    marker = "stage:"
    if marker not in message:
        return None
    tail = message.split(marker, 1)[-1].strip()
    if tail.endswith(")"):
        tail = tail[:-1].strip()
    return tail or None


def _generation_context_cache_name(request_signature: Optional[str]) -> Optional[str]:
    signature = str(request_signature or "").strip()
    if not signature:
        return None
    return f"variant:{signature[:16]}"


def _uses_advanced_generation_context(generation_context: Optional[Dict[str, Any]]) -> bool:
    if not isinstance(generation_context, dict) or not generation_context:
        return False
    for key in (
        "node_directives",
        "prompt_excerpt",
        "dominant_metrics",
        "metrics",
        "profile_intent",
    ):
        value = generation_context.get(key)
        if value:
            return True
    return False


def _filter_advanced_context_codebases(
    codebases: List[Dict[str, Any]],
    *,
    generation_context: Optional[Dict[str, Any]],
    request_signature: Optional[str],
) -> List[Dict[str, Any]]:
    if not _uses_advanced_generation_context(generation_context):
        return list(codebases)
    cache_name = _generation_context_cache_name(request_signature)
    if not cache_name:
        return []
    return [entry for entry in codebases if entry.get("name") == cache_name]


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
    status_callback: Optional[Callable[[str], None]] = None,
    avoid_seeds_by_codebase: Optional[Dict[int, Set[int]]] = None,
    cancel_event: Any = None,
    generation_context: Optional[Dict[str, Any]] = None,
    request_signature: Optional[str] = None,
) -> Dict[str, Any]:
    check_cancelled(cancel_event)
    def normalize_tag(tag: str) -> str:
        return (tag or "").strip().lstrip("#").strip()

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
    avoid_seeds_by_codebase = avoid_seeds_by_codebase or {}

    if reference_quest_id:
        reference_quest = get_quest(reference_quest_id)
        if reference_quest is None:
            raise ValueError(f"reference quest not found: {reference_quest_id}")

    clean_tags = normalize_tags(hash_tags)
    if not clean_tags:
        raise ValueError("hash_tags must not be empty")
    tier = infer_tier_from_params(solves_count, strategy_level, branch_conditions)
    signature_seed = _seed_from_request_signature(request_signature)
    base_rng_seed = seed if seed is not None else (
        signature_seed if signature_seed is not None else random.randint(1, 1_000_000_000)
    )
    rng = random.Random(base_rng_seed)
    if len(clean_tags) > max_tag_count_for_tier(tier):
        clean_tags = select_tags_for_tier(clean_tags, tier, rng)
    desired_difficulty = estimate_difficulty(
        len(clean_tags),
        solves_count,
        strategy_level,
        branch_conditions,
    )

    def _refresh_entry(entry: Dict[str, Any]) -> None:
        code = entry.get("code") or ""
        code_hash = compute_code_hash(code)
        entry["_code_hash"] = code_hash
        entry_id = entry.get("id")
        if entry_id is None:
            entry["_cached_seeds"] = 0
            return
        entry["_cached_seeds"] = count_cached_seeds(entry_id, code_hash)

    def _has_tag_subset(entry: Dict[str, Any]) -> bool:
        desired_tags = {normalize_tag(tag) for tag in clean_tags if normalize_tag(tag)}
        entry_tags = {
            normalize_tag(tag) for tag in (entry.get("tags") or []) if normalize_tag(tag)
        }
        return bool(entry_tags) and entry_tags.issubset(desired_tags)

    def _generate_codebase_entry() -> Dict[str, Any]:
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
            cancel_event=cancel_event,
            generation_context=generation_context,
        )
        cache_name = _generation_context_cache_name(request_signature)
        if cache_name and _uses_advanced_generation_context(generation_context):
            entry["name"] = cache_name
        entry["tier"] = None
        entry = save_codebase(entry)
        _refresh_entry(entry)
        seed_bank = entry.pop("seed_cache", []) if isinstance(entry, dict) else []
        if entry.get("id") and entry.get("_code_hash"):
            for seed_value in seed_bank:
                try:
                    save_cached_seed(entry["id"], entry["_code_hash"], int(seed_value))
                except Exception:
                    continue
        return entry

    codebases = _load_codebases_cached()
    for entry in codebases:
        _refresh_entry(entry)

    if used_codebase_ids is not None:
        codebases = [entry for entry in codebases if entry.get("id") not in used_codebase_ids]

    matching_codebases = [entry for entry in codebases if _has_tag_subset(entry)]
    matching_codebases = _filter_advanced_context_codebases(
        matching_codebases,
        generation_context=generation_context,
        request_signature=request_signature,
    )

    rng = random.Random(base_rng_seed)
    choice_rng_seed = seed if seed is not None else (
        (base_rng_seed ^ 0x5DEECE66D) if signature_seed is not None else random.randint(1, 1_000_000_000)
    )
    choice_rng = random.Random(choice_rng_seed)
    error_messages: List[str] = []
    regen_attempts = 0
    max_regen_attempts = 3

    if matching_codebases:
        if seed is None:
            matching_with_seeds = [
                entry for entry in matching_codebases if entry.get("_cached_seeds", 0) > 0
            ]
            if not matching_with_seeds:
                candidate = select_codebase(
                    matching_codebases,
                    clean_tags,
                    desired_difficulty,
                    rng,
                )
                validate_codebase(
                    candidate,
                    attempts_per_codebase=3,
                    max_successes_per_codebase=1,
                    source="runtime",
                    cancel_event=cancel_event,
                )
                _refresh_entry(candidate)
                matching_with_seeds = [
                    entry
                    for entry in matching_codebases
                    if entry.get("_cached_seeds", 0) > 0
                ]
            if matching_with_seeds:
                codebases = matching_with_seeds
            else:
                codebases = []
        else:
            codebases = matching_codebases
    else:
        codebases = []

    if not codebases:
        regen_limit = 10
        generated = None
        for regen_index in range(regen_limit):
            check_cancelled(cancel_event)
            try:
                candidate = _generate_codebase_entry()
            except Exception as exc:
                error_messages.append(str(exc))
                continue
            if seed is None:
                try:
                    validation = validate_codebase(
                        candidate,
                        attempts_per_codebase=3,
                        max_successes_per_codebase=1,
                        source="runtime",
                        cancel_event=cancel_event,
                    )
                except Exception as exc:
                    error_messages.append(str(exc))
                    continue
                _refresh_entry(candidate)
                if candidate.get("_cached_seeds", 0) <= 0:
                    error_messages.append(
                        "codebase %s validation failed (attempts=%s successes=%s)"
                        % (
                            candidate.get("id"),
                            validation.get("attempts"),
                            validation.get("successes"),
                        )
                    )
                    continue
            generated = candidate
            break
        if generated is None:
            raise RuntimeError(
                "codebase generation failed: %s" % (", ".join(error_messages) or "no seeds")
            )
        codebases = [generated]

    # Prefer codebases with cached seeds unless a seed is explicitly provided
    if seed is None:
        validated = [entry for entry in codebases if entry.get("_cached_seeds", 0) > 0]
        if not validated:
            # validate the best candidate and cache seeds
            candidate = select_codebase(codebases, clean_tags, desired_difficulty, rng)
            validation = validate_codebase(
                candidate,
                attempts_per_codebase=3,
                max_successes_per_codebase=1,
                source="runtime",
                cancel_event=cancel_event,
            )
            entry_id = candidate.get("id")
            if entry_id is not None:
                candidate["_cached_seeds"] = count_cached_seeds(entry_id, candidate.get("_code_hash") or "")
            validated = [entry for entry in codebases if entry.get("_cached_seeds", 0) > 0]
        if not validated:
            raise RuntimeError("no validated codebase seeds available")
        codebases = validated

    entry = select_codebase(codebases, clean_tags, desired_difficulty, rng)

    def _build_avoided_seeds(entry_id: Optional[int]) -> Set[int]:
        if entry_id is None:
            return set()
        return set(avoid_seeds_by_codebase.get(entry_id, set()))

    def _build_cached_seed_candidates(entry_id: Optional[int], code_hash: str) -> List[int]:
        if seed is not None or entry_id is None:
            return []
        avoided = _build_avoided_seeds(entry_id)
        candidates = list_cached_seeds(entry_id, code_hash, limit=16)
        filtered = [int(candidate) for candidate in candidates if int(candidate) not in avoided]
        return _order_seed_candidates(
            filtered,
            request_signature,
            entry_id=entry_id,
            code_hash=code_hash,
        )

    def _build_seed_candidates(entry_id: Optional[int], code_hash: str, limit: int) -> List[int]:
        if seed is not None:
            return [int(seed)]
        candidates: List[int] = []
        avoided = _build_avoided_seeds(entry_id)
        seen = set(candidates)
        while len(candidates) < limit:
            candidate = rng.randint(1, 1_000_000_000)
            if candidate in seen or candidate in avoided:
                continue
            seen.add(candidate)
            candidates.append(candidate)
        return candidates

    seed_limits = _parse_seed_limits(_CODEBASE_RUNTIME_SEED_LIMITS_RAW)
    sector_messages = {
        2: "평소보다 조금 더 오래 걸립니다",
        3: "조금만 더 기다려주세요...",
    }
    max_tag_sets = 3
    tag_set_attempts = 0
    last_error: Optional[Exception] = None

    while tag_set_attempts < max_tag_sets:
        check_cancelled(cancel_event)
        sector_index = 0
        current_entry = entry

        while sector_index < len(seed_limits):
            check_cancelled(cancel_event)
            try:
                entry_id = current_entry.get("id")
                code_hash = current_entry.get("_code_hash") or compute_code_hash(
                    current_entry.get("code") or ""
                )
                seed_candidates = _build_seed_candidates(
                    entry_id,
                    code_hash,
                    seed_limits[sector_index],
                )
                if not seed_candidates:
                    raise RuntimeError("no seed candidates available for codebase")

                # Try seeds in parallel batches instead of sequential loop
                last_seed_error: Optional[Exception] = None
                result: Optional[Dict[str, Any]] = None
                seed_value: Optional[int] = None
                cached_seed_candidates = _build_cached_seed_candidates(entry_id, code_hash)
                batch_size = 8
                for batch_start in range(0, len(cached_seed_candidates), batch_size):
                    if result is not None:
                        break
                    check_cancelled(cancel_event)
                    cached_batch = cached_seed_candidates[
                        batch_start:batch_start + batch_size
                    ]
                    if entry_id is not None:
                        for cached_seed in cached_batch:
                            record_seed_attempt(entry_id, code_hash, success=False)
                    batch_results = run_codebase_batch(
                        current_entry,
                        cached_batch,
                        timeout_seconds=_CODEBASE_CACHED_BATCH_TIMEOUT_SEC,
                        cancel_event=cancel_event,
                    )
                    batch_logs: List[Dict[str, Any]] = []
                    started_at = time.monotonic()
                    for idx, raw_result in enumerate(batch_results):
                        cached_seed = cached_batch[idx]
                        if isinstance(raw_result, dict) and "_error" in raw_result:
                            err_msg = raw_result["_error"]
                            last_seed_error = RuntimeError(err_msg)
                            if entry_id is not None:
                                batch_logs.append({
                                    "codebase_id": entry_id,
                                    "code_hash": code_hash,
                                    "seed": cached_seed,
                                    "status": "timeout" if "timeout" in err_msg.lower() else "failure",
                                    "error_type": "BatchExecutionError",
                                    "error_message": err_msg,
                                    "stage": _extract_stage(err_msg),
                                    "elapsed_ms": 0,
                                    "source": "runtime_cached",
                                })
                            continue
                        try:
                            result = validate_result(
                                raw_result,
                                fallback_hash_tags=clean_tags,
                                expected_solves=solves_count,
                                expected_branches=branch_conditions,
                                main_huddle=strategy_level,
                            )
                            elapsed_ms = int((time.monotonic() - started_at) * 1000)
                            seed_value = cached_seed
                            if entry_id is not None:
                                record_seed_attempt(entry_id, code_hash, success=True)
                                save_cached_seed(entry_id, code_hash, cached_seed)
                                batch_logs.append({
                                    "codebase_id": entry_id,
                                    "code_hash": code_hash,
                                    "seed": cached_seed,
                                    "status": "success",
                                    "elapsed_ms": elapsed_ms,
                                    "source": "runtime_cached",
                                })
                            break
                        except Exception as exc:
                            elapsed_ms = int((time.monotonic() - started_at) * 1000)
                            last_seed_error = exc
                            if entry_id is not None:
                                batch_logs.append({
                                    "codebase_id": entry_id,
                                    "code_hash": code_hash,
                                    "seed": cached_seed,
                                    "status": "timeout" if isinstance(exc, TimeoutError) else "failure",
                                    "error_type": exc.__class__.__name__,
                                    "error_message": str(exc),
                                    "stage": _extract_stage(str(exc)),
                                    "elapsed_ms": elapsed_ms,
                                    "source": "runtime_cached",
                                })
                    if batch_logs and entry_id is not None:
                        save_seed_logs_batch(batch_logs)

                for batch_start in range(0, len(seed_candidates), batch_size):
                    if result is not None:
                        break
                    check_cancelled(cancel_event)
                    batch = seed_candidates[batch_start:batch_start + batch_size]
                    # Record attempts before running batch
                    if entry_id is not None:
                        for s in batch:
                            record_seed_attempt(entry_id, code_hash, success=False)
                    batch_results = run_codebase_batch(
                        current_entry,
                        batch,
                        timeout_seconds=_CODEBASE_RUNTIME_BATCH_TIMEOUT_SEC,
                        cancel_event=cancel_event,
                    )
                    batch_logs: List[Dict[str, Any]] = []
                    for idx, raw_result in enumerate(batch_results):
                        check_cancelled(cancel_event)
                        s = batch[idx]
                        started_at = time.monotonic()
                        if isinstance(raw_result, dict) and "_error" in raw_result:
                            err_msg = raw_result["_error"]
                            last_seed_error = RuntimeError(err_msg)
                            if entry_id is not None:
                                batch_logs.append({
                                    "codebase_id": entry_id,
                                    "code_hash": code_hash,
                                    "seed": s,
                                    "status": "timeout" if "timeout" in err_msg.lower() else "failure",
                                    "error_type": "BatchExecutionError",
                                    "error_message": err_msg,
                                    "stage": _extract_stage(err_msg),
                                    "elapsed_ms": 0,
                                    "source": "runtime",
                                })
                            continue
                        try:
                            result = validate_result(
                                raw_result,
                                fallback_hash_tags=clean_tags,
                                expected_solves=solves_count,
                                expected_branches=branch_conditions,
                                main_huddle=strategy_level,
                            )
                            elapsed_ms = int((time.monotonic() - started_at) * 1000)
                            seed_value = s
                            if entry_id is not None:
                                record_seed_attempt(entry_id, code_hash, success=True)
                                if seed is None:
                                    save_cached_seed(entry_id, code_hash, s)
                                batch_logs.append({
                                    "codebase_id": entry_id,
                                    "code_hash": code_hash,
                                    "seed": s,
                                    "status": "success",
                                    "elapsed_ms": elapsed_ms,
                                    "source": "runtime",
                                })
                            break
                        except Exception as exc:
                            elapsed_ms = int((time.monotonic() - started_at) * 1000)
                            last_seed_error = exc
                            if entry_id is not None:
                                batch_logs.append({
                                    "codebase_id": entry_id,
                                    "code_hash": code_hash,
                                    "seed": s,
                                    "status": "timeout" if isinstance(exc, TimeoutError) else "failure",
                                    "error_type": exc.__class__.__name__,
                                    "error_message": str(exc),
                                    "stage": _extract_stage(str(exc)),
                                    "elapsed_ms": elapsed_ms,
                                    "source": "runtime",
                                })
                            continue
                    if batch_logs and entry_id is not None:
                        save_seed_logs_batch(batch_logs)
                    if result is not None:
                        break

                if result is None:
                    raise last_seed_error or RuntimeError("no valid seed")

                ai_result = result.get("ai_result")
                if ai_result is None:
                    raise RuntimeError("ai_result missing after validation")
                storage_data = fix_gen(ai_result, clean_tags, strict_tags=strict_tags)
                if question_type:
                    apply_question_format(
                        storage_data,
                        question_type=question_type,
                        answer=result["answer"],
                        rng=choice_rng,
                    )
                if isinstance(storage_data.get("data"), dict):
                    entry_id = current_entry.get("id")
                    storage_data["data"]["codebase_id"] = entry_id
                    storage_data["data"]["seed"] = seed_value
                    if entry_id is not None:
                        avoid_seeds_by_codebase.setdefault(int(entry_id), set()).add(int(seed_value))
                storage_data = enforce_storage_step_tags(
                    storage_data,
                    clean_tags,
                    codebase_id=current_entry.get("id"),
                )
                _schedule_runtime_seed_backfill(current_entry, code_hash)
                return resample_storage_data(storage_data, coerce_text_only=True)
            except TagAssignmentError as exc:
                last_error = exc
                error_messages.append(str(exc))
                tag_set_attempts += 1
                if tag_set_attempts >= max_tag_sets:
                    if status_callback:
                        status_callback("지금은 생성할 수 없습니다 다시 시도해주세요")
                    raise RuntimeError("지금은 생성할 수 없습니다 다시 시도해주세요")
                current_entry = _generate_codebase_entry()
                entry = current_entry
                sector_index = 0
                continue
            except Exception as exc:
                last_error = exc
                error_messages.append(str(exc))
                sector_index += 1
                if sector_index >= len(seed_limits):
                    if status_callback:
                        status_callback("오류가 발생했습니다 다시 시도해주세요")
                    raise RuntimeError("오류가 발생했습니다 다시 시도해주세요")
                message = sector_messages.get(sector_index)
                if status_callback and message:
                    status_callback(message)
                current_entry = _generate_codebase_entry()
                entry = current_entry
                continue

    detail = ", ".join(error_messages)
    if detail:
        raise RuntimeError(f"codebase generation failed: {detail}")
    raise RuntimeError(f"codebase generation failed: {last_error}")


# Legacy alias to avoid import errors; unified pipeline only
def make_legacy(
    hash_tags: List[str],
    solves_count: int,
    strategy_level: int,
    branch_conditions: int,
    reference_quest_id: Optional[str] = None,
    strict_tags: bool = True,
    seed: Optional[int] = None,
    question_type: Optional[str] = None,
    used_codebase_ids: Optional[set[int]] = None,
    status_callback: Optional[Callable[[str], None]] = None,
    cancel_event: Any = None,
) -> Dict[str, Any]:
    return make(
        hash_tags,
        solves_count,
        strategy_level,
        branch_conditions,
        reference_quest_id=reference_quest_id,
        strict_tags=strict_tags,
        seed=seed,
        question_type=question_type,
        used_codebase_ids=used_codebase_ids,
        status_callback=status_callback,
        cancel_event=cancel_event,
    )


# legacy pipeline removed in unified flow
