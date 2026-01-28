import copy
import re
from typing import Any, Dict, List

# 기존 $...$ 인라인 LaTeX 패턴
LATEX_PATTERN = re.compile(r"(?<!\\)\${1,2}(.*?)(?<!\\)\${1,2}", re.DOTALL)
# $ 없이 LaTeX 명령어 패턴 (\frac, \sum 등)
LATEX_CMD_PATTERN = re.compile(r"(\\[a-zA-Z]+(?:\{.*?\})*)")  

_STEP_FIELDS = ("flow", "hint_riddle", "answer_riddle")


def resample_storage_data(storage: Dict[str, Any]) -> Dict[str, Any]:
    """
    Split inline $...$ LaTeX inside text blocks into separate latex/text blocks.
    Applies to quest_title, quest_answer, and solve steps (excluding hash_tag and enter_huddle).
    """
    cloned = copy.deepcopy(storage)
    data = cloned.get("data")
    if isinstance(data, dict):
        for key in ("quest_title", "quest_answer"):
            if key in data:
                data[key] = _resample_field(data[key])

    solves = cloned.get("solves")
    if isinstance(solves, list):
        cloned["solves"] = [_resample_solve_step(step) for step in solves]

    return cloned


def _resample_solve_step(step: Dict[str, Any]) -> Dict[str, Any]:
    updated = copy.deepcopy(step)
    for field in _STEP_FIELDS:
        if field in updated:
            updated[field] = _resample_field(updated[field])
    if isinstance(updated.get("branches"), list):
        updated["branches"] = [_resample_solve_step(branch) for branch in updated["branches"]]
    return updated


def _resample_field(value: Any) -> Dict[str, List[Dict[str, str]]]:
    blocks = _normalize_to_blocks(value)
    split_blocks: List[Dict[str, str]] = []
    for block in blocks:
        split_blocks.extend(_split_block(block))
    merged = _merge_adjacent_blocks(split_blocks)
    return {"blocks": merged}


def _normalize_to_blocks(value: Any) -> List[Dict[str, str]]:
    if value is None:
        return []
    if isinstance(value, str):
        return [{"type": "text", "content": value}]
    if isinstance(value, dict):
        if isinstance(value.get("blocks"), list):
            return [_coerce_block(block) for block in value["blocks"]]
        if "type" in value and ("content" in value or "text" in value):
            return [_coerce_block(value)]
    if isinstance(value, list):
        return [_coerce_block(block) for block in value]
    return [{"type": "text", "content": str(value)}]


def _coerce_block(block: Any) -> Dict[str, str]:
    if isinstance(block, dict):
        block_type = str(block.get("type") or "text")
        content = str(block.get("content") if block.get("content") is not None else block.get("text") or "")
        return {"type": block_type, "content": content}
    return {"type": "text", "content": str(block)}


def _split_block(block: Dict[str, str]) -> List[Dict[str, str]]:
    block_type = (block.get("type") or "text").lower()
    content = block.get("content") or ""
    if block_type != "text":
        return [{"type": block_type, "content": content}]
    return _split_text_content(content)


def _split_text_content(text: str) -> List[Dict[str, str]]:
    if not text:
        return []

    blocks: List[Dict[str, str]] = []
    last_idx = 0

    # 1. 먼저 $...$ 처리
    for match in LATEX_PATTERN.finditer(text):
        start, end = match.span()
        if start > last_idx:
            prefix = text[last_idx:start]
            blocks.extend(_split_latex_commands(prefix))  # LaTeX 명령어 분화
        latex_body = match.group(1)
        if latex_body.strip():
            blocks.append({"type": "latex", "content": latex_body})
        else:
            blocks.append({"type": "text", "content": _unescape_text(match.group(0))})
        last_idx = end

    if last_idx < len(text):
        suffix = text[last_idx:]
        blocks.extend(_split_latex_commands(suffix))

    if not blocks:
        return [{"type": "text", "content": _unescape_text(text)}]

    return blocks


def _split_latex_commands(text: str) -> List[Dict[str, str]]:
    """
    $...$ 밖의 text 안에 \frac, \sum 등 LaTeX 명령어가 들어있으면 분화
    """
    if not text:
        return []

    result = []
    last_idx = 0
    for match in LATEX_CMD_PATTERN.finditer(text):
        start, end = match.span()
        if start > last_idx:
            prefix = text[last_idx:start]
            if prefix.strip():
                result.append({"type": "text", "content": _unescape_text(prefix)})
        cmd_body = match.group(0)
        if cmd_body.strip():
            result.append({"type": "latex", "content": cmd_body})
        last_idx = end
    if last_idx < len(text):
        suffix = text[last_idx:]
        if suffix.strip():
            result.append({"type": "text", "content": _unescape_text(suffix)})
    if not result:
        return [{"type": "text", "content": _unescape_text(text)}]
    return result


def _merge_adjacent_blocks(blocks: List[Dict[str, str]]) -> List[Dict[str, str]]:
    merged: List[Dict[str, str]] = []
    for block in blocks:
        block_type = (block.get("type") or "text").lower()
        content = block.get("content") or ""
        if not content:
            continue
        if merged and merged[-1]["type"] == block_type:
            merged[-1]["content"] += content
        else:
            merged.append({"type": block_type, "content": content})
    return merged


def _unescape_text(value: str) -> str:
    return value.replace(r"\$", "$")
