from __future__ import annotations

import atexit
import multiprocessing
import os
import re
import types
from concurrent.futures import ProcessPoolExecutor, TimeoutError as FutureTimeoutError
from typing import Any, Dict, List, Optional, Sequence, Tuple

from baselines.basemodel import AISolveStep, AIQuestResult, ContentBlocks


# =========================
# Process pool for sandboxed execution
# =========================

_pool_executor: Optional[ProcessPoolExecutor] = None
_pool_max_workers: int = max(2, min(4, os.cpu_count() or 4))


def _get_pool() -> ProcessPoolExecutor:
    global _pool_executor
    if _pool_executor is None:
        _pool_executor = ProcessPoolExecutor(
            max_workers=_pool_max_workers,
            mp_context=multiprocessing.get_context("spawn"),
        )
    return _pool_executor


def shutdown_process_pool(wait: bool = True) -> None:
    global _pool_executor
    if _pool_executor is not None:
        _pool_executor.shutdown(wait=wait)
        _pool_executor = None


atexit.register(shutdown_process_pool, wait=True)


def _run_codebase_worker(args: Tuple[str, Optional[int]]) -> Dict[str, Any]:
    """Picklable worker for the process pool."""
    code, seed = args
    try:
        module = compile_code(code)
        generate_func = module.__dict__.get("generate_problem")
        result = generate_func(seed=seed)
        if not isinstance(result, dict):
            return {"ok": False, "error": "generate_problem result is not a dict."}
        return {"ok": True, "result": result}
    except Exception as exc:
        return {"ok": False, "error": f"{exc}"}


def _log_done(role: str) -> None:
    print(f"[{role}] 실행완료")


# =========================
# Utility helpers
# =========================


def estimate_difficulty(
    tag_count: int,
    solves_count: int,
    strategy_level: int,
    branch_conditions: int,
) -> int:
    value = int(tag_count + 4 * solves_count + 3 * branch_conditions + 2 * strategy_level)
    _log_done("difficulty 계산")
    return value


def compile_code(code: str) -> types.ModuleType:
    module = types.ModuleType("codebase_module")
    exec(compile(code, "<codebase>", "exec"), module.__dict__)
    generate_func = module.__dict__.get("generate_problem")
    if not callable(generate_func):
        raise RuntimeError("generate_problem 함수가 없습니다.")
    _log_done("코드 컴파일")
    print(f"[입력] compile_code code_length={len(code)}")
    return module


def normalize_signs(text: str) -> str:
    if not text:
        _log_done("부호 정규화")
        return text
    patterns = [
        (r"\-\s*\-\s*", "+"),
        (r"\+\s*\-\s*", "-"),
        (r"\-\s*\+\s*", "-"),
        (r"\+\s*\+\s*", "+"),
    ]
    cleaned = text
    for _ in range(2):
        for pattern, repl in patterns:
            cleaned = re.sub(pattern, repl, cleaned)
    cleaned = re.sub(r"\s{2,}", " ", cleaned)
    _log_done("부호 정규화")
    print(f"[입력] normalize_signs len_before={len(text)} len_after={len(cleaned)}")
    return cleaned


def _coerce_blocks(value: Any, field_name: str) -> ContentBlocks:
    blocks = ContentBlocks.model_validate(value)
    cleaned_blocks: List[Dict[str, str]] = []
    for block in blocks.blocks:
        content = str(block.content or "")
        if not content.strip():
            continue
        if block.type == "text":
            content = normalize_signs(content)
        cleaned_blocks.append({"type": block.type, "content": content})
    _log_done(f"{field_name} 정규화")
    print(f"[입력] _coerce_blocks field={field_name} blocks={len(cleaned_blocks)}")
    return ContentBlocks.model_validate({"blocks": cleaned_blocks})


def _normalize_solve_step(
    step: Dict[str, Any],
    *,
    fallback_tags: List[str],
    expected_branches: Optional[int],
    depth: int = 0,
) -> AISolveStep:
    flow = _coerce_blocks(step.get("flow"), f"solves[{depth}].flow")
    hint = _coerce_blocks(step.get("hint_riddle"), f"solves[{depth}].hint_riddle")
    answer_riddle = _coerce_blocks(step.get("answer_riddle"), f"solves[{depth}].answer_riddle")
    enter_huddle = step.get("enter_huddle", 0)
    tags = step.get("hash_tag")
    if tags is None:
        tags = fallback_tags
    if isinstance(tags, str):
        tags = [tags]
    if tags is None:
        tags = []
    branches_raw = step.get("branches") or []
    branches = [
        _normalize_solve_step(
            branch,
            fallback_tags=fallback_tags,
            expected_branches=expected_branches,  # no trimming
            depth=depth + 1,
        )
        for branch in branches_raw
        if isinstance(branch, dict)
    ]
    _log_done("solve 정규화")
    return AISolveStep(
        flow=flow,
        hint_riddle=hint,
        answer_riddle=answer_riddle,
        hash_tag=list(tags),
        enter_huddle=enter_huddle,
        branches=branches,
    )


def _solution_from_solves(solves: List[AISolveStep]) -> ContentBlocks:
    texts: List[str] = []

    def _append(step: AISolveStep, prefix: str = "") -> None:
        flow_text = " ".join(block.content for block in step.flow.blocks if block.content)
        if flow_text:
            texts.append(f"{prefix}flow: {flow_text}")
        hint_text = " ".join(block.content for block in step.hint_riddle.blocks if block.content)
        if hint_text:
            texts.append(f"{prefix}hint: {hint_text}")
        ans_text = " ".join(block.content for block in step.answer_riddle.blocks if block.content)
        if ans_text:
            texts.append(f"{prefix}answer: {ans_text}")
        for branch in step.branches:
            _append(branch, prefix + "branch> ")

    for solve in solves:
        _append(solve)
    _log_done("solution 빌드")
    return ContentBlocks.model_validate({"blocks": [{"type": "text", "content": " ".join(texts)}]})


# =========================
# Core validation & runtime
# =========================


def validate_result(
    result: Dict[str, Any],
    *,
    fallback_hash_tags: Optional[Sequence[str]] = None,
    expected_solves: Optional[int] = None,
    expected_branches: Optional[int] = None,
    main_huddle: Optional[int] = None,
) -> Dict[str, Any]:
    if not isinstance(result, dict):
        raise ValueError("generate_problem must return a dict.")

    quest_title = _coerce_blocks(result.get("quest_title"), "quest_title")
    quest_answer = _coerce_blocks(result.get("quest_answer"), "quest_answer")

    # 그대로 사용 (형식 강제 없음)
    answer_value: Any = result.get("answer", quest_answer)

    primary_hash_tag = result.get("primary_hash_tag") or ""

    solves_raw = result.get("solves") or []
    fallback_tags = [primary_hash_tag] if primary_hash_tag else list(fallback_hash_tags or [])
    solves: List[AISolveStep] = []
    for step in solves_raw:
        if not isinstance(step, dict):
            continue
        solves.append(
            _normalize_solve_step(
                step,
                fallback_tags=fallback_tags,
                expected_branches=expected_branches,
            )
        )
    if not solves:
        raise ValueError("solves must not be empty.")

    mh = main_huddle if main_huddle is not None else result.get("main_huddle", 0)

    ai_result = AIQuestResult(
        quest_title=quest_title,
        quest_answer=quest_answer,
        quest_model=["unified-codebase"],
        main_huddle=mh,
        primary_hash_tag=primary_hash_tag,
        quest_image=result.get("quest_image"),
        solves=solves,
    )

    solution_blocks = _coerce_blocks(
        result.get("solution") or _solution_from_solves(solves),
        "solution",
    )

    _log_done("결과 검증")
    return {
        "ai_result": ai_result,
        "problem": quest_title,
        "answer": answer_value,
        "solution": solution_blocks,
        "meta": result.get("meta") or {},
    }


def build_ai_result(
    *,
    problem: Any,
    answer: int,
    solution: Any,
    hash_tags: Sequence[str],
    solves_count: int,
    strategy_level: int,
    branch_conditions: int,
) -> AIQuestResult:
    title_blocks = _coerce_blocks(problem, "problem")
    answer_blocks = _coerce_blocks(answer, "answer")
    solution_blocks = _coerce_blocks(solution, "solution")
    fallback_tag = hash_tags[0] if hash_tags else ""

    root_steps: List[AISolveStep] = []
    for _ in range(max(1, solves_count)):
        root_steps.append(
            AISolveStep(
                flow=solution_blocks,
                hint_riddle=solution_blocks,
                answer_riddle=solution_blocks,
                hash_tag=[fallback_tag] if fallback_tag else [],
                enter_huddle=strategy_level,
                branches=[],
            )
        )

    if branch_conditions > 0 and root_steps:
        root_steps[0].branches = [
            AISolveStep(
                flow=solution_blocks,
                hint_riddle=solution_blocks,
                answer_riddle=solution_blocks,
                hash_tag=[fallback_tag] if fallback_tag else [],
                enter_huddle=strategy_level,
                branches=[],
            )
            for _ in range(branch_conditions)
        ]

    _log_done("AI 결과 빌드")
    return AIQuestResult(
        quest_title=title_blocks,
        quest_answer=answer_blocks,
        quest_model=["unified-codebase"],
        main_huddle=int(strategy_level),
        primary_hash_tag=fallback_tag,
        quest_image=None,
        solves=root_steps,
    )


def select_codebase(
    codebases: Sequence[Dict[str, Any]],
    hash_tags: Sequence[str],
    desired_difficulty: int,
    rng: Any,
) -> Dict[str, Any]:
    if not codebases:
        raise RuntimeError("등록된 codebase가 없습니다.")

    desired_tags = {_normalize_tag(tag) for tag in hash_tags if _normalize_tag(tag)}
    scored: List[Tuple[int, int, Dict[str, Any]]] = []
    for entry in codebases:
        entry_tags = {_normalize_tag(tag) for tag in entry.get("tags", []) if _normalize_tag(tag)}
        overlap = len(desired_tags & entry_tags) if entry_tags and desired_tags else 0
        diff = entry.get("difficulty")
        if diff is None:
            diff = desired_difficulty
        delta = abs(int(diff) - desired_difficulty)
        score = overlap * 1000 - delta
        scored.append((score, delta, entry))

    scored.sort(key=lambda item: (item[0], -item[1]), reverse=True)
    best_score = scored[0][0]
    candidates = [entry for score, _, entry in scored if score == best_score]
    choice = rng.choice(candidates) if candidates else scored[0][2]
    _log_done("codebase 선택")
    return choice


def run_codebase(entry: Dict[str, Any], seed: Optional[int]) -> Dict[str, Any]:
    code = entry.get("code") or ""
    if not code.strip():
        raise RuntimeError("Codebase code is empty.")
    result = _run_codebase_with_timeout(code, seed, timeout_seconds=None)
    _log_done("codebase 실행")
    return result


def run_codebase_batch(
    entry: Dict[str, Any],
    seeds: List[int],
    *,
    timeout_seconds: Optional[float] = None,
) -> List[Dict[str, Any]]:
    """
    Execute multiple seeds in parallel via the process pool.
    Returns a list of results in the same order as seeds.
    Each result is either a success dict or an error dict with "_error" key.
    """
    code = entry.get("code") or ""
    if not code.strip():
        return [{"_error": "Codebase code is empty."} for _ in seeds]

    pool = _get_pool()
    futures = {
        pool.submit(_run_codebase_worker, (code, seed)): idx
        for idx, seed in enumerate(seeds)
    }

    results: List[Dict[str, Any]] = [{"_error": "not executed"} for _ in seeds]
    for future in futures:
        idx = futures[future]
        try:
            payload = future.result(timeout=timeout_seconds)
            if not payload.get("ok"):
                results[idx] = {"_error": payload.get("error") or "codebase execution failed"}
            else:
                result = payload.get("result")
                if not isinstance(result, dict):
                    results[idx] = {"_error": "generate_problem result is not a dict."}
                else:
                    results[idx] = result
        except FutureTimeoutError:
            results[idx] = {"_error": "codebase execution timeout"}
        except Exception as exc:
            results[idx] = {"_error": f"{exc}"}

    return results


def _run_codebase_with_timeout(
    code: str,
    seed: Optional[int],
    *,
    timeout_seconds: Optional[float],
) -> Dict[str, Any]:
    pool = _get_pool()
    future = pool.submit(_run_codebase_worker, (code, seed))
    try:
        payload = future.result(timeout=timeout_seconds)
    except FutureTimeoutError:
        raise TimeoutError("codebase execution timeout")
    except Exception as exc:
        raise RuntimeError(f"codebase execution failed: {exc}")

    if not payload.get("ok"):
        raise RuntimeError(payload.get("error") or "codebase execution failed")
    result = payload.get("result")
    if not isinstance(result, dict):
        raise ValueError("generate_problem result is not a dict.")
    _log_done("codebase 실행(워커)")
    return result


def run_codebase_inline(entry: Dict[str, Any], seed: Optional[int]) -> Dict[str, Any]:
    """
    단일 프로세스에서 바로 generate_problem을 실행 (타임아웃/격리 없음).
    속도는 빠르지만 코드 오류가 그대로 전파된다.
    """
    code = entry.get("code") or ""
    if not code.strip():
        raise RuntimeError("Codebase code is empty.")
    module = compile_code(code)
    generate_func = module.__dict__.get("generate_problem")
    result = generate_func(seed=seed)
    if not isinstance(result, dict):
        raise ValueError("generate_problem result is not a dict.")
    _log_done("codebase 인라인 실행")
    return result


# Backward-compatible no-op to satisfy existing imports
def warmup_sympy_pool(*args: Any, **kwargs: Any) -> None:  # pragma: no cover
    _log_done("sympy warmup(skip)")
    return None


def _extract_answer_value(answer_payload: Any) -> Optional[int]:
    text = ""
    if isinstance(answer_payload, ContentBlocks):
        text = " ".join(block.content for block in answer_payload.blocks if block.content)
    elif isinstance(answer_payload, dict):
        blocks = answer_payload.get("blocks")
        if isinstance(blocks, list):
            parts = []
            for block in blocks:
                if isinstance(block, dict):
                    content = block.get("content")
                    if content:
                        parts.append(str(content).strip())
            text = " ".join(parts)
    elif isinstance(answer_payload, str):
        text = answer_payload.strip()
    else:
        text = str(answer_payload)

    cleaned = re.sub(r"[^\d-]+", " ", text)
    tokens = [token for token in cleaned.split() if token not in ("", "-", "+")]
    for token in tokens:
        try:
            return int(token)
        except ValueError:
            continue
    digits = re.findall(r"-?\d+", text)
    if digits:
        try:
            return int(digits[0])
        except ValueError:
            pass
    return None


# Shared normalize_tag with LRU cache
import functools


@functools.lru_cache(maxsize=512)
def _normalize_tag(tag: str) -> str:
    return tag.strip().lstrip("#").strip()
