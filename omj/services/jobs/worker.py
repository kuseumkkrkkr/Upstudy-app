"""Background worker for durable job state machine.

Provides a simple async worker that polls the JobStore for queued jobs
and executes them.  Designed to be started once at application startup
(e.g. via lifespan or a dedicated process).

Reference: docs/COURSE_BUILDER_V2_PLAN.md §9.2
"""
from __future__ import annotations

import asyncio
import json
import logging
import time
import traceback
from typing import Any, Awaitable, Callable, Optional

try:
    from services.jobs.state_machine import JobStateMachine, JobState, InvalidTransitionError
    from services.jobs.store import JobStore
except ImportError:
    from services.jobs.state_machine import JobStateMachine, JobState, InvalidTransitionError
    from services.jobs.store import JobStore

from generater.codebase_runner import hard_cancel_process_pool
from services.jobs.cancellation import (
    GenerationCancelled,
    check_cancelled,
    register_token,
    release_token,
)

logger = logging.getLogger("jobs.worker")

# Registry of job-type → async handler
JobHandler = Callable[[str, dict[str, Any]], Awaitable[dict[str, Any]]]
_registry: dict[str, JobHandler] = {}


def register_handler(job_type: str, handler: JobHandler) -> None:
    """Register an async handler for a given job type."""
    _registry[job_type] = handler
    logger.info("Registered job handler for type=%s", job_type)


def get_handler(job_type: str) -> Optional[JobHandler]:
    """Return the registered handler for *job_type* or None."""
    return _registry.get(job_type)


class JobWorker:
    """Polls the job store and executes queued jobs."""

    def __init__(
        self,
        db_path: Optional[str] = None,
        poll_interval: float = 2.0,
        max_concurrent: int = 3,
    ):
        self.sm = JobStateMachine(db_path)
        self.store = JobStore(db_path)
        self.poll_interval = poll_interval
        self.semaphore = asyncio.Semaphore(max_concurrent)
        self._shutdown = False
        self._task: Optional[asyncio.Task] = None

    # ------------------------------------------------------------------
    # lifecycle
    # ------------------------------------------------------------------

    async def start(self) -> None:
        """Start the background polling loop."""
        if self._task is not None:
            return
        self._shutdown = False
        self._task = asyncio.create_task(self._loop())
        logger.info("JobWorker started (poll=%.1fs)", self.poll_interval)

    async def stop(self) -> None:
        """Signal shutdown and wait for the loop to finish."""
        self._shutdown = True
        if self._task:
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
            self._task = None
        logger.info("JobWorker stopped")

    # ------------------------------------------------------------------
    # polling loop
    # ------------------------------------------------------------------

    async def _loop(self) -> None:
        while not self._shutdown:
            try:
                await self._tick()
            except Exception:
                logger.exception("Worker tick failed")
            await asyncio.sleep(self.poll_interval)

    async def _tick(self) -> None:
        """Fetch one queued job and dispatch it."""
        rows = self.store.list_jobs(status=JobState.queued, limit=10)
        if not rows:
            return

        # Run up to max_concurrent jobs in parallel
        tasks = [
            asyncio.create_task(self._execute(row["job_id"], row))
            for row in rows[: self.semaphore._value or 1]
        ]
        if tasks:
            await asyncio.gather(*tasks, return_exceptions=True)

    # ------------------------------------------------------------------
    # execution
    # ------------------------------------------------------------------

    async def _execute(self, job_id: str, row: dict) -> None:
        async with self.semaphore:
            job_type: str = row.get("operation", "")
            payload: dict = row.get("payload") or {}
            if not payload:
                payload_json = row.get("payload_json")
                if isinstance(payload_json, str) and payload_json.strip():
                    try:
                        parsed = json.loads(payload_json)
                    except Exception:
                        parsed = {}
                    if isinstance(parsed, dict):
                        payload = parsed

            handler = get_handler(job_type)
            if handler is None:
                logger.warning("No handler for job_type=%s job_id=%s", job_type, job_id)
                self.sm.transition(
                    job_id,
                    JobState.failed,
                    error=f"No handler registered for job_type={job_type}",
                )
                return

            # Move to generating
            try:
                self.sm.transition(job_id, JobState.generating)
            except InvalidTransitionError as exc:
                logger.warning("Invalid transition for job_id=%s: %s", job_id, exc)
                return

            cancel_event = register_token(job_id)
            try:
                check_cancelled(cancel_event)
                result = await handler(job_id, payload)
                check_cancelled(cancel_event)
                current = self.store.get(job_id) or {}
                if current.get("status") != JobState.generating.value:
                    logger.info("Job finished after status changed job_id=%s status=%s", job_id, current.get("status"))
                    return
                self.sm.transition(job_id, JobState.done, result=result)
                logger.info("Job done job_id=%s type=%s", job_id, job_type)
            except GenerationCancelled:
                hard_cancel_process_pool()
                current = self.store.get(job_id) or {}
                if current.get("status") != JobState.rejected.value:
                    self.sm.transition(
                        job_id,
                        JobState.rejected,
                        reason="Generation cancelled",
                        rejection_reason="user_cancelled",
                    )
                logger.info("Job cancelled job_id=%s type=%s", job_id, job_type)
            except Exception as exc:
                error_msg = f"{exc}\n{traceback.format_exc()}"
                logger.error("Job failed job_id=%s type=%s: %s", job_id, job_type, exc)
                current = self.store.get(job_id) or {}
                if current.get("status") == JobState.generating.value:
                    self.sm.transition(job_id, JobState.failed, error=error_msg)
            finally:
                release_token(job_id)


# ------------------------------------------------------------------
# Convenience helpers for common job types
# ------------------------------------------------------------------

async def run_ai_course_proposal(job_id: str, payload: dict[str, Any]) -> dict[str, Any]:
    """Handler for 'ai_course_proposal' jobs.

    Expected payload keys:
        - student_ovr: dict
        - weakness_tags: list[str]
        - available_modules: list[str] (optional)
        - prompt_extra: str (optional)
        - course_title_hint: str (optional)

    Returns a dict with the proposed course JSON.
    """
    from services.ai.providers.base import get_default_provider
    from services.ai import prompts
    from services.ai import guard

    # Safety check
    text = str(payload)
    rejection = guard.check_excessive(text) or guard.check_harmful(text)
    if rejection:
        raise ValueError(f"Safety guard rejected: {rejection.detail}")

    provider = get_default_provider()
    system_prompt = prompts.course_proposal_system_prompt()
    user_prompt = prompts.course_proposal_user_prompt(
        student_ovr=payload.get("student_ovr", {}),
        weakness_tags=payload.get("weakness_tags", []),
        available_modules=payload.get("available_modules"),
        prompt_extra=payload.get("prompt_extra"),
        course_title_hint=payload.get("course_title_hint"),
    )

    raw = await provider.generate(system=system_prompt, user=user_prompt, json_mode=True)
    # Validate basic structure
    if not isinstance(raw, dict) or "modules" not in raw:
        raise ValueError(f"AI response missing 'modules' key: {raw}")

    return {"course": raw}


async def run_variant_generation(job_id: str, payload: dict[str, Any]) -> dict[str, Any]:
    """Handler for 'variant_generation' jobs.

    Expected payload keys:
        - base_question_id: str
        - variant_count: int (default 3)
        - difficulty_shift: int (-2..+2, default 0)

    Returns a dict with list of variant question dicts.
    """
    from services.ai.providers.base import get_default_provider
    from services.ai import prompts
    from services.ai import guard

    text = str(payload)
    rejection = guard.check_excessive(text) or guard.check_harmful(text)
    if rejection:
        raise ValueError(f"Safety guard rejected: {rejection.detail}")

    provider = get_default_provider()
    system_prompt = prompts.variant_generation_system_prompt()
    user_prompt = prompts.variant_generation_user_prompt(
        base_question_id=payload["base_question_id"],
        variant_count=payload.get("variant_count", 3),
        difficulty_shift=payload.get("difficulty_shift", 0),
    )

    raw = await provider.generate(system=system_prompt, user=user_prompt, json_mode=True)
    variants = raw if isinstance(raw, list) else raw.get("variants", [])
    return {"variants": variants}


async def run_quest_variant(job_id: str, payload: dict[str, Any]) -> dict[str, Any]:
    """Handler for 'quest_variant' jobs.

    Expected payload keys:
        - quest_id: int
        - variant_type: str (easier|harder|hint_heavy|scaffolded|speed_drill|proof_variant)
        - original_problem: dict

    Returns a dict with the generated variant JSON.
    """
    from services.ai.providers.base import get_default_provider
    from domain.quest.variant_engine import generate_variant
    from services.ai import guard

    text = str(payload)
    rejection = guard.check_excessive(text) or guard.check_harmful(text)
    if rejection:
        raise ValueError(f"Safety guard rejected: {rejection.detail}")

    provider = get_default_provider()
    variant = generate_variant(
        original_problem=payload.get("original_problem", {}),
        variant_type=payload.get("variant_type", "easier"),
        ai_provider=provider,
    )
    return {
        "variant": variant.model_dump(),
        "quest_id": payload.get("quest_id"),
        "variant_type": payload.get("variant_type"),
    }


async def run_textbook_build(job_id: str, payload: dict[str, Any]) -> dict[str, Any]:
    """Handler for 'textbook_build' jobs.

    Expected payload keys:
        - course_id: int
        - root_ids: list[int]
        - ai_provider: str (optional, default "kimi")

    Returns a dict with generated blocks.
    """
    from services.ai.providers.base import get_default_provider
    from domain.textbook.build_service import TextbookBuilderService, TextbookBlock, TextbookGraph
    from services.ai import guard

    text = str(payload)
    rejection = guard.check_excessive(text) or guard.check_harmful(text)
    if rejection:
        raise ValueError(f"Safety guard rejected: {rejection.detail}")

    provider = get_default_provider()
    service = TextbookBuilderService(ai_provider=provider)

    graph = TextbookGraph(course_id=payload["course_id"], root_blocks=payload.get("root_ids", []))
    blocks = service.build_blocks_sync(graph)
    return {
        "blocks": [b.model_dump() for b in blocks],
        "course_id": payload.get("course_id"),
    }


async def run_level_test(job_id: str, payload: dict[str, Any]) -> dict[str, Any]:
    """Handler for 'level_test' jobs.

    Expected payload keys:
        - user_id: str
        - test_type: str ("speed" | "power")
        - topics: list[str] (speed only)
        - difficulty: str (speed only, default "medium")
        - weakness_report: str (power only)

    Returns a dict with the generated test JSON.
    """
    from services.ai.providers.base import get_default_provider
    from domain.level_test import engine, repository as repo
    from services.ai import guard

    text = str(payload)
    rejection = guard.check_excessive(text) or guard.check_harmful(text)
    if rejection:
        raise ValueError(f"Safety guard rejected: {rejection.detail}")

    provider = get_default_provider()
    test_type = payload.get("test_type", "speed")
    user_id = payload["user_id"]

    if test_type == "speed":
        test = engine.generate_speed_test(
            user_id=user_id,
            topics=payload.get("topics", []),
            difficulty=payload.get("difficulty", "medium"),
            ai_provider=provider,
        )
        test_id = repo.create_speed_test(test)
        test.id = test_id
        return {"test": test.model_dump(), "test_type": "speed", "test_id": test_id}

    elif test_type == "power":
        test = engine.generate_power_test(
            user_id=user_id,
            weakness_report=payload.get("weakness_report", ""),
            ai_provider=provider,
        )
        test_id = repo.create_power_test(test)
        test.id = test_id
        return {"test": test.model_dump(), "test_type": "power", "test_id": test_id}

    else:
        raise ValueError(f"Unsupported test_type: {test_type}")


async def run_quest_generation(job_id: str, payload: dict[str, Any]) -> dict[str, Any]:
    """Handler for single quest generation jobs."""
    from generater.fix_gen import validate_generation_tags
    from generater.make import make
    from storage.storage import get_last_store_error, store_data

    hash_tags = validate_generation_tags(payload.get("hash_tags") or [])
    if not hash_tags:
        raise ValueError("hash_tags must not be empty")

    solves_count = int(payload.get("solves_count") or 1)
    strategy_level = int(payload.get("strategy_level") or 1)
    branch_conditions = int(payload.get("branch_conditions") or 0)
    seed = payload.get("seed")
    reference_quest_id = payload.get("reference_quest_id")
    cancel_event = register_token(job_id)

    def _status_cb(message: str) -> None:
        if message:
            logger.info("Quest generation progress job_id=%s message=%s", job_id, message)

    check_cancelled(cancel_event)
    storage_data = await asyncio.to_thread(
        make,
        hash_tags,
        solves_count,
        strategy_level,
        branch_conditions,
        reference_quest_id,
        True,
        seed,
        None,
        None,
        _status_cb,
        cancel_event=cancel_event,
    )
    check_cancelled(cancel_event)

    if not store_data(storage_data):
        detail = get_last_store_error() or "failed to store quest"
        raise RuntimeError(detail)

    return {"quest": storage_data}


async def run_quest_batch_generation(job_id: str, payload: dict[str, Any]) -> dict[str, Any]:
    """Handler for 'quest_batch_generation' jobs.

    Expected payload keys:
        - user_id: str
        - hash_tags: list[str]
        - min_difficulty_tier: int
        - max_difficulty_tier: int
        - question_count: int
    """
    import json
    from generater.problem_solve import generate_problem_set
    from storage.storage import get_last_store_error, store_data
    from storage.user_kv_storage import get_user_kv, set_user_kv

    user_id = str(payload.get("user_id") or "").strip()
    hash_tags = payload.get("hash_tags") or []
    min_tier = int(payload.get("min_difficulty_tier") or 1)
    max_tier = int(payload.get("max_difficulty_tier") or 5)
    question_count = int(payload.get("question_count") or 3)

    history_key = "problem_history_v2"
    history_window_sec = 3 * 24 * 60 * 60
    history_max = 500

    def _load_recent_seed_history() -> tuple[list[dict[str, Any]], dict[int, set[int]]]:
        raw = get_user_kv(user_id, history_key) if user_id else None
        entries: list[dict[str, Any]] = []
        mapping: dict[int, set[int]] = {}
        now = int(time.time())
        cutoff = now - history_window_sec
        if raw:
            try:
                data = json.loads(raw)
            except Exception:
                data = None
            if isinstance(data, list):
                for item in data:
                    if not isinstance(item, dict):
                        continue
                    cb_raw = item.get("codebase_id")
                    seed_raw = item.get("seed")
                    ts_raw = item.get("ts") or item.get("timestamp")
                    try:
                        cb_id = int(cb_raw) if cb_raw is not None else None
                        seed_val = int(seed_raw) if seed_raw is not None else None
                        ts_val = int(ts_raw) if ts_raw is not None else 0
                    except Exception:
                        continue
                    if cb_id is None or seed_val is None or ts_val < cutoff:
                        continue
                    entries.append({"codebase_id": cb_id, "seed": seed_val, "ts": ts_val})
        for item in entries:
            try:
                cb = int(item.get("codebase_id"))
                sd = int(item.get("seed"))
            except Exception:
                continue
            mapping.setdefault(cb, set()).add(sd)
        return entries, mapping

    def _save_seed_history(entries: list[dict[str, Any]]) -> None:
        if not user_id:
            return
        try:
            set_user_kv(user_id, history_key, json.dumps(entries))
        except Exception:
            pass

    def _record_seed_history_entry(
        entries: list[dict[str, Any]],
        mapping: dict[int, set[int]],
        codebase_id: Any,
        seed: Any,
    ) -> None:
        if not user_id or codebase_id is None or seed is None:
            return
        now = int(time.time())
        entries.append({"codebase_id": int(codebase_id), "seed": int(seed), "ts": now})
        cutoff = now - history_window_sec
        filtered = [
            item
            for item in entries
            if item.get("codebase_id") is not None
            and item.get("seed") is not None
            and int(item.get("ts", 0)) >= cutoff
        ]
        if len(filtered) > history_max:
            filtered = filtered[-history_max:]
        entries[:] = filtered
        mapping.clear()
        for item in entries:
            try:
                cb = int(item.get("codebase_id"))
                sd = int(item.get("seed"))
            except Exception:
                continue
            mapping.setdefault(cb, set()).add(sd)

    history_entries, history_map = _load_recent_seed_history()
    cancel_event = register_token(job_id)
    check_cancelled(cancel_event)

    quests = await asyncio.to_thread(
        generate_problem_set,
        hash_tags=hash_tags,
        min_difficulty_tier=min_tier,
        max_difficulty_tier=max_tier,
        question_count=question_count,
        recent_codebase_seeds={key: list(value) for key, value in history_map.items()},
        cancel_event=cancel_event,
    )
    check_cancelled(cancel_event)

    stored_quests: list[dict[str, Any]] = []
    for quest in quests:
        check_cancelled(cancel_event)
        if not store_data(quest):
            detail = get_last_store_error() or "failed to store quest"
            raise RuntimeError(detail)
        data = quest.get("data") if isinstance(quest, dict) else {}
        cb_id = data.get("codebase_id") if isinstance(data, dict) else None
        seed_val = data.get("seed") if isinstance(data, dict) else None
        _record_seed_history_entry(history_entries, history_map, cb_id, seed_val)
        stored_quests.append(quest)

    _save_seed_history(history_entries)
    return {"quests": stored_quests, "count": len(stored_quests)}


# Register built-in handlers
register_handler("ai_course_proposal", run_ai_course_proposal)
register_handler("variant_generation", run_variant_generation)
register_handler("quest_variant", run_quest_variant)
register_handler("textbook_build", run_textbook_build)
register_handler("level_test", run_level_test)
register_handler("quest_generation", run_quest_generation)
register_handler("quest_batch_generation", run_quest_batch_generation)
