from __future__ import annotations

import random
import re
import types
from typing import Any, Dict, Iterable, List, Optional, Sequence, Tuple

from baselines.basemodel import AIQuestResult


def estimate_difficulty(
    tag_count: int,
    solves_count: int,
    strategy_level: int,
    branch_conditions: int,
) -> int:
    return int(tag_count + 4 * solves_count + 3 * branch_conditions + 2 * strategy_level)


def compile_code(code: str) -> types.ModuleType:
    module = types.ModuleType("codebase_module")
    exec(compile(code, "<codebase>", "exec"), module.__dict__)
    generate_func = module.__dict__.get("generate_problem")
    if not callable(generate_func):
        raise RuntimeError("generate_problem 함수가 없습니다.")
    return module


def normalize_signs(text: str) -> str:
    if not text:
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
    return cleaned


def normalize_tag(tag: str) -> str:
    return tag.strip().lstrip("#").strip()


def select_codebase(
    codebases: Sequence[Dict[str, Any]],
    hash_tags: Sequence[str],
    desired_difficulty: int,
    rng: random.Random,
) -> Dict[str, Any]:
    if not codebases:
        raise RuntimeError("등록된 코드베이스가 없습니다.")

    desired_tags = {normalize_tag(tag) for tag in hash_tags if normalize_tag(tag)}
    scored: List[Tuple[int, int, Dict[str, Any]]] = []
    for entry in codebases:
        entry_tags = {normalize_tag(tag) for tag in entry.get("tags", []) if normalize_tag(tag)}
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
    return rng.choice(candidates) if candidates else scored[0][2]


def run_codebase(entry: Dict[str, Any], seed: Optional[int]) -> Dict[str, Any]:
    code = entry.get("code") or ""
    if not code.strip():
        raise RuntimeError("코드베이스 코드가 비어 있습니다.")
    module = compile_code(code)
    generate_func = module.__dict__.get("generate_problem")
    result = generate_func(seed=seed)
    if not isinstance(result, dict):
        raise ValueError("generate_problem 결과가 dict가 아닙니다.")
    return result

# 검증 함수
def validate_result(result: Dict[str, Any]) -> Dict[str, Any]:
    problem = str(result.get("problem") or "").strip()
    if not problem:
        raise ValueError("problem이 비어 있습니다.")

    raw_answer = result.get("answer")
    if isinstance(raw_answer, bool):
        raise ValueError("answer는 bool이 될 수 없습니다.")
    try:
        answer = int(raw_answer)
    except Exception as exc:
        raise ValueError("answer는 정수여야 합니다.") from exc
    if answer == 0 or abs(answer) > 50:
        raise ValueError("answer 범위가 유효하지 않습니다.")

    meta = result.get("meta") or {}
    solution = result.get("solution") or meta.get("solution") or ""
    solution = str(solution).strip()
    if not solution:
        raise ValueError("solution이 비어 있습니다.")

    problem = normalize_signs(problem)
    solution = normalize_signs(solution)

    return {
        "problem": problem,
        "answer": answer,
        "solution": solution,
        "meta": meta,
    }


def _split_solution(text: str) -> List[str]:
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    if len(lines) >= 2:
        return lines

    parts = [part.strip() for part in re.split(r"(?<=[.!?])\s+", text) if part.strip()]
    if len(parts) >= 2:
        return parts

    return [text.strip()] if text.strip() else []


def build_ai_result(
    *,
    problem: str,
    answer: int,
    solution: str,
    hash_tags: Sequence[str],
    solves_count: int,
    strategy_level: int,
    branch_conditions: int,
) -> AIQuestResult:
    segments = _split_solution(solution)
    if not segments:
        segments = [solution]

    enter_huddle = max(0, min(10, int(strategy_level) * 3))
    root_count = max(1, solves_count)
    root_steps: List[Dict[str, Any]] = []
    for idx in range(root_count):
        flow = segments[min(idx, len(segments) - 1)]
        hint = segments[0]
        answer_riddle = solution if idx == root_count - 1 else flow
        root_steps.append(
            {
                "flow": flow,
                "hint_riddle": hint,
                "answer_riddle": answer_riddle,
                "enter_huddle": enter_huddle,
                "branches": [],
            }
        )

    branch_total = max(0, int(branch_conditions))
    if branch_total > 0:
        branch_indices = list(range(root_count))
        branch_cursor = 0
        for branch_idx in range(branch_total):
            target_root = branch_indices[branch_cursor % len(branch_indices)]
            branch_cursor += 1
            branch_flow = segments[min(branch_idx, len(segments) - 1)]
            branch_steps = {
                "flow": f"{branch_flow} (조건 {branch_idx + 1})",
                "hint_riddle": segments[0],
                "answer_riddle": solution,
                "enter_huddle": enter_huddle,
                "branches": [],
            }
            root_steps[target_root]["branches"].append(branch_steps)

    ai_payload = {
        "quest_title": problem,
        "quest_answer": str(answer),
        "quest_model": ["codebase"],
        "main_huddle": int(strategy_level),
        "primary_hash_tag": hash_tags[0] if hash_tags else "",
        "quest_image": None,
        "solves": root_steps,
    }
    return AIQuestResult.model_validate(ai_payload)
