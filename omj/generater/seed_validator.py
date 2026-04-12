from __future__ import annotations

import random
import time
from typing import Any, Dict

from generater.codebase_runner import run_codebase, validate_result
from generater.codebase_store import (
    compute_code_hash,
    get_seed_stats,
    load_codebases,
    record_seed_attempt,
    save_cached_seed,
    save_seed_log,
)


def _extract_stage(message: str) -> str | None:
    if not message:
        return None
    marker = "stage:"
    if marker not in message:
        return None
    tail = message.split(marker, 1)[-1].strip()
    if tail.endswith(")"):
        tail = tail[:-1].strip()
    return tail or None


def run_seed_validation_cycle(
    *,
    max_codebases: int = 5,
    attempts_per_codebase: int = 10,
    max_successes_per_codebase: int = 3,
) -> Dict[str, Any]:
    codebases = load_codebases()
    rng = random.Random()
    rng.shuffle(codebases)

    processed = 0
    total_attempts = 0
    total_successes = 0
    skipped = 0

    for entry in codebases:
        if processed >= max_codebases:
            break
        entry_id = entry.get("id")
        if entry_id is None:
            continue
        code_hash = compute_code_hash(entry.get("code") or "")
        attempts, successes = get_seed_stats(entry_id, code_hash)
        if attempts >= 10 and successes == 0:
            skipped += 1
            continue

        processed += 1
        result = validate_codebase(
            entry,
            attempts_per_codebase=attempts_per_codebase,
            max_successes_per_codebase=max_successes_per_codebase,
            source="background",
        )
        total_attempts += result["attempts"]
        total_successes += result["successes"]
    return {
        "processed_codebases": processed,
        "skipped_codebases": skipped,
        "attempts": total_attempts,
        "successes": total_successes,
    }


def validate_codebase(
    entry: Dict[str, Any],
    *,
    attempts_per_codebase: int,
    max_successes_per_codebase: int,
    source: str,
) -> Dict[str, Any]:
    entry_id = entry.get("id")
    if entry_id is None:
        return {"attempts": 0, "successes": 0, "deleted": False}

    code_hash = compute_code_hash(entry.get("code") or "")
    code_text = entry.get("code") or ""
    if "import sympy" in code_text.lower() or "from sympy" in code_text.lower():
        save_seed_log(
            codebase_id=entry_id,
            code_hash=code_hash,
            seed=None,
            status="failure",
            error_type="ForbiddenImport",
            error_message="sympy import is not allowed in codebase.",
            stage="compile",
            elapsed_ms=0,
            source=source,
        )
        return {"attempts": 0, "successes": 0, "deleted": False}
    successes_here = 0
    attempts_here = 0
    rng = random.Random()

    for _ in range(attempts_per_codebase):
        seed_value = rng.randint(1, 1_000_000_000)
        record_seed_attempt(entry_id, code_hash, success=False)
        attempts_here += 1
        started_at = time.monotonic()
        try:
            raw = run_codebase(entry, seed_value)
            validate_result(
                raw,
                fallback_hash_tags=entry.get("tags") or [],
                expected_solves=entry.get("solves_count"),
                expected_branches=entry.get("branch_conditions"),
                main_huddle=entry.get("strategy_level"),
            )
            elapsed_ms = int((time.monotonic() - started_at) * 1000)
        except Exception as exc:
            elapsed_ms = int((time.monotonic() - started_at) * 1000)
            save_seed_log(
                codebase_id=entry_id,
                code_hash=code_hash,
                seed=seed_value,
                status="timeout" if isinstance(exc, TimeoutError) else "failure",
                error_type=exc.__class__.__name__,
                error_message=str(exc),
                stage=_extract_stage(str(exc)),
                elapsed_ms=elapsed_ms,
                source=source,
            )
            continue

        record_seed_attempt(entry_id, code_hash, success=True)
        save_cached_seed(entry_id, code_hash, seed_value)
        save_seed_log(
            codebase_id=entry_id,
            code_hash=code_hash,
            seed=seed_value,
            status="success",
            elapsed_ms=elapsed_ms,
            source=source,
        )
        successes_here += 1
        if successes_here >= max_successes_per_codebase:
            break

    attempts_total, successes_total = get_seed_stats(entry_id, code_hash)
    return {
        "attempts": attempts_here,
        "successes": successes_here,
        "deleted": False,
    }
