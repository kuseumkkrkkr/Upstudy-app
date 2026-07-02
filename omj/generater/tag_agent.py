from __future__ import annotations

import json
import re
from typing import Any, Dict, Iterable, List, Optional, Sequence, Tuple

from pydantic import BaseModel, Field

from baselines.basemodel import AIQuestResult, AISolveStep, ContentBlocks, blocks_to_text
from generater.ai_gen import COMETAPI_KEY, client
from generater.codebase_store import save_agent_log


class TagAssignmentError(RuntimeError):
    pass


class _TagPatch(BaseModel):
    path: List[int] = Field(..., description="Indices path to the solve step")
    hash_tag: List[str] = Field(default_factory=list, description="Assigned tags")


class _TagPatchResult(BaseModel):
    patches: List[_TagPatch] = Field(default_factory=list)


import functools

@functools.lru_cache(maxsize=512)
def _normalize_tag(tag: str) -> str:
    return tag.strip().lstrip("#").strip()


def _build_tag_mapping(hash_tags: Sequence[str]) -> Dict[str, str]:
    mapping: Dict[str, str] = {}
    for tag in hash_tags:
        raw = tag.strip()
        if not raw:
            continue
        normalized = _normalize_tag(raw)
        if normalized and normalized not in mapping:
            mapping[normalized] = raw
    return mapping


def _normalize_step_tags(tags: Sequence[str], tag_mapping: Dict[str, str]) -> List[str]:
    if not tags:
        return []
    seen = set()
    resolved: List[str] = []
    for tag in tags:
        if not isinstance(tag, str):
            continue
        normalized = _normalize_tag(tag)
        if not normalized:
            continue
        mapped = tag_mapping.get(normalized)
        if not mapped or mapped in seen:
            continue
        seen.add(mapped)
        resolved.append(mapped)
    return resolved


def _content_to_text(content: ContentBlocks | dict | list | str | None) -> str:
    if content is None:
        return ""
    if isinstance(content, ContentBlocks):
        return blocks_to_text(content)
    if isinstance(content, str):
        return content
    try:
        return blocks_to_text(ContentBlocks.model_validate(content))
    except Exception:
        return str(content)


def _iter_steps(
    steps: List[AISolveStep],
    path: Tuple[int, ...] = (),
) -> Iterable[Tuple[Tuple[int, ...], AISolveStep]]:
    for idx, step in enumerate(steps):
        current = path + (idx,)
        yield current, step
        if step.branches:
            yield from _iter_steps(step.branches, current)


def _get_step_by_path(steps: List[AISolveStep], path: Sequence[int]) -> Optional[AISolveStep]:
    cursor = steps
    step: Optional[AISolveStep] = None
    for idx in path:
        if idx < 0 or idx >= len(cursor):
            return None
        step = cursor[idx]
        cursor = step.branches
    return step


def _request_tag_patches(
    missing_steps: List[Dict[str, Any]],
    allowed_tags: List[str],
) -> _TagPatchResult:
    payload = json.dumps(missing_steps, ensure_ascii=False)
    tags_json = json.dumps(allowed_tags, ensure_ascii=False)
    prompt = f"""
You are assigning hash tags to solve steps.
Choose 1-2 tags from the allowed list for each step.
Return JSON only and follow this schema:
{{
  "patches": [
    {{
      "path": [0, 1],
      "hash_tag": ["#tag1", "#tag2"]
    }}
  ]
}}

Rules:
- Use only tags from allowed_tags.
- If no good match, pick the closest single tag.
- If allowed_tags has multiple entries, avoid giving the same tag to every step.
- Do not modify flow/hint/answer text.

allowed_tags: {tags_json}
missing_steps: {payload}
""".strip()

    response = client.models.generate_content(
        model="kimi-k2.5",
        contents=prompt,
        config={
            "response_mime_type": "application/json",
            "response_json_schema": _TagPatchResult.model_json_schema(),
        },
    )

    json_text = response.text
    if json_text.startswith("```"):
        json_text = json_text.lstrip("`").split("\n", 1)[-1]
    if json_text.endswith("```"):
        json_text = json_text.rsplit("\n", 1)[0]
    parsed = json.loads(json_text)
    return _TagPatchResult.model_validate(parsed)


def enforce_step_tags(ai_result: AIQuestResult, hash_tags: List[str]) -> AIQuestResult:
    clean_tags = [tag.strip() for tag in hash_tags if isinstance(tag, str) and tag.strip()]
    tag_mapping = _build_tag_mapping(clean_tags)
    if not tag_mapping:
        return ai_result

    missing: List[Dict[str, Any]] = []
    for path, step in _iter_steps(ai_result.solves):
        normalized = _normalize_step_tags(step.hash_tag, tag_mapping)
        step.hash_tag = normalized
        if normalized:
            continue
        missing.append(
            {
                "path": list(path),
                "flow": _content_to_text(step.flow),
                "hint_riddle": _content_to_text(step.hint_riddle),
                "answer_riddle": _content_to_text(step.answer_riddle),
            }
        )

    if not missing or not COMETAPI_KEY:
        return ai_result

    patches = _request_tag_patches(missing, list(tag_mapping.values()))
    for patch in patches.patches:
        step = _get_step_by_path(ai_result.solves, patch.path)
        if step is None:
            continue
        normalized = _normalize_step_tags(patch.hash_tag, tag_mapping)
        if normalized:
            step.hash_tag = normalized

    return ai_result


def _iter_storage_steps(
    steps: List[Dict[str, Any]],
    path: Tuple[int, ...] = (),
) -> Iterable[Tuple[Tuple[int, ...], Dict[str, Any]]]:
    for idx, step in enumerate(steps):
        if not isinstance(step, dict):
            continue
        current = path + (idx,)
        yield current, step
        branches = step.get("branches") or []
        if isinstance(branches, list):
            yield from _iter_storage_steps(branches, current)


def _get_storage_step_by_path(
    steps: List[Dict[str, Any]],
    path: Sequence[int],
) -> Optional[Dict[str, Any]]:
    cursor = steps
    step: Optional[Dict[str, Any]] = None
    for idx in path:
        if idx < 0 or idx >= len(cursor):
            return None
        candidate = cursor[idx]
        if not isinstance(candidate, dict):
            return None
        step = candidate
        branches = step.get("branches") or []
        cursor = branches if isinstance(branches, list) else []
    return step


def _normalize_storage_tags(tags: Any, tag_mapping: Dict[str, str]) -> List[str]:
    if not isinstance(tags, list):
        return []
    return _normalize_step_tags([str(tag) for tag in tags], tag_mapping)


def _is_simple_arithmetic(storage_data: Dict[str, Any]) -> bool:
    def _collect_text(value: Any) -> List[str]:
        if value is None:
            return []
        if isinstance(value, str):
            return [value]
        if isinstance(value, dict) and isinstance(value.get("blocks"), list):
            texts = []
            for block in value.get("blocks") or []:
                if isinstance(block, dict):
                    texts.append(str(block.get("content") or ""))
            return texts
        if isinstance(value, list):
            return [str(item) for item in value]
        return [str(value)]

    def _step_text(step: Dict[str, Any]) -> List[str]:
        texts = []
        texts += _collect_text(step.get("flow"))
        texts += _collect_text(step.get("hint_riddle"))
        texts += _collect_text(step.get("answer_riddle"))
        return texts

    texts: List[str] = []
    data = storage_data.get("data") or {}
    texts += _collect_text(data.get("quest_title"))
    texts += _collect_text(data.get("quest_answer"))
    solves = storage_data.get("solves") or []
    if isinstance(solves, list):
        for step in solves:
            if isinstance(step, dict):
                texts += _step_text(step)

    if not texts:
        return False

    for text in texts:
        stripped = text.replace(" ", "")
        if not stripped:
            continue
        # allow only digits and basic arithmetic symbols
        if re.search(r"[a-zA-Zㄱ-ㅎㅏ-ㅣ가-힣]", stripped):
            return False
        if re.search(r"[^0-9+\-*/=().,^%]", stripped):
            return False
    return True


def _analyze_storage_tags(
    storage_data: Dict[str, Any],
    hash_tags: List[str],
) -> Tuple[bool, List[Dict[str, Any]], Dict[str, Any]]:
    tag_mapping = _build_tag_mapping(hash_tags)
    allowed_norms = list(tag_mapping.keys())
    if not allowed_norms:
        return False, [], {"reason": "no_allowed_tags"}

    solves = storage_data.get("solves") or []
    if not isinstance(solves, list):
        return False, [], {"reason": "no_solves"}

    normalized_tags_by_step: List[List[str]] = []
    missing_steps: List[Dict[str, Any]] = []
    for path, step in _iter_storage_steps(solves):
        tags = _normalize_storage_tags(step.get("hash_tag"), tag_mapping)
        normalized_tags_by_step.append(tags)
        if not tags:
            missing_steps.append(
                {
                    "path": list(path),
                    "flow": _content_to_text(step.get("flow")),
                    "hint_riddle": _content_to_text(step.get("hint_riddle")),
                    "answer_riddle": _content_to_text(step.get("answer_riddle")),
                }
            )

    unique_tags = {tag for tags in normalized_tags_by_step for tag in tags}
    steps_count = len(normalized_tags_by_step)
    multi_input = len(allowed_norms) > 1
    all_same = multi_input and len(unique_tags) <= 1

    used_norms = {_normalize_tag(tag) for tag in unique_tags if _normalize_tag(tag)}
    required_norms = set(allowed_norms)
    missing_required = bool(required_norms - used_norms)

    if multi_input:
        needs_redistribute = bool(missing_steps) or all_same or missing_required
    else:
        if steps_count <= 1:
            needs_redistribute = len(unique_tags) == 0
        else:
            needs_redistribute = len(unique_tags) == 0

    detail = {
        "missing_count": len(missing_steps),
        "unique_count": len(unique_tags),
        "allowed_count": len(allowed_norms),
        "all_same": all_same,
        "multi_input": multi_input,
        "missing_required": missing_required,
    }
    if not needs_redistribute:
        return False, [], detail

    if multi_input and missing_steps:
        return True, missing_steps, detail

    all_steps: List[Dict[str, Any]] = []
    for path, step in _iter_storage_steps(solves):
        all_steps.append(
            {
                "path": list(path),
                "flow": _content_to_text(step.get("flow")),
                "hint_riddle": _content_to_text(step.get("hint_riddle")),
                "answer_riddle": _content_to_text(step.get("answer_riddle")),
            }
        )
    return True, all_steps, detail


def enforce_storage_step_tags(
    storage_data: Dict[str, Any],
    hash_tags: List[str],
    *,
    codebase_id: Optional[int] = None,
    max_retries: int = 3,
) -> Dict[str, Any]:
    clean_tags = [tag.strip() for tag in hash_tags if isinstance(tag, str) and tag.strip()]
    tag_mapping = _build_tag_mapping(clean_tags)
    if not tag_mapping:
        return storage_data

    solves = storage_data.get("solves") or []
    if not isinstance(solves, list) or not solves:
        return storage_data

    for _, step in _iter_storage_steps(solves):
        step["hash_tag"] = _normalize_storage_tags(step.get("hash_tag"), tag_mapping)

    if _is_simple_arithmetic(storage_data):
        arithmetic_norm = _normalize_tag("사칙연산")
        if arithmetic_norm in tag_mapping:
            arithmetic_tag = tag_mapping[arithmetic_norm]
            for _, step in _iter_storage_steps(solves):
                step["hash_tag"] = [arithmetic_tag]
            save_agent_log(
                codebase_id=codebase_id,
                action="tag_patch",
                status="success",
                attempt=0,
                detail={"message": "simple_arithmetic", "tag": arithmetic_tag},
            )
            return storage_data

    action = "tag_patch"
    for attempt in range(1, max_retries + 1):
        needs_fix, target_steps, detail = _analyze_storage_tags(storage_data, clean_tags)
        if not needs_fix:
            save_agent_log(
                codebase_id=codebase_id,
                action=action,
                status="success",
                attempt=attempt,
                detail={**detail, "message": "no_fix_needed"},
            )
            return storage_data

        if not COMETAPI_KEY:
            save_agent_log(
                codebase_id=codebase_id,
                action=action,
                status="failure",
                attempt=attempt,
                error_message="COMETAPI_KEY is not set",
                detail=detail,
            )
            continue

        try:
            patches = _request_tag_patches(target_steps, list(tag_mapping.values()))
            for patch in patches.patches:
                step = _get_storage_step_by_path(solves, patch.path)
                if step is None:
                    continue
                normalized = _normalize_step_tags(patch.hash_tag, tag_mapping)
                if normalized:
                    step["hash_tag"] = normalized
            save_agent_log(
                codebase_id=codebase_id,
                action=action,
                status="attempt",
                attempt=attempt,
                detail={**detail, "patched": len(patches.patches)},
            )
        except Exception as exc:
            save_agent_log(
                codebase_id=codebase_id,
                action=action,
                status="failure",
                attempt=attempt,
                error_message=str(exc),
                detail=detail,
            )
            continue

        needs_fix, _, detail = _analyze_storage_tags(storage_data, clean_tags)
        if not needs_fix:
            save_agent_log(
                codebase_id=codebase_id,
                action=action,
                status="success",
                attempt=attempt,
                detail=detail,
            )
            return storage_data

    save_agent_log(
        codebase_id=codebase_id,
        action=action,
        status="failed",
        attempt=max_retries,
        error_message="tag assignment failed after retries",
    )
    raise TagAssignmentError("tag assignment failed after retries")
