from __future__ import annotations

import difflib
import os
import textwrap
from typing import Any, Dict

from env_loader import load_env
from services.ai.sam_client import (
    DEFAULT_CODEBASE_REPAIR_MODEL,
    SAM_API_KEY_ENV,
    chat_completion_text,
    is_sam_configured,
)


load_env()

_REPAIR_CODE_HEAD_CHARS = max(
    800,
    int(os.getenv("CODEBASE_REPAIR_CODE_HEAD_CHARS", "1800")),
)
_REPAIR_CODE_TAIL_CHARS = max(
    1200,
    int(os.getenv("CODEBASE_REPAIR_CODE_TAIL_CHARS", "2600")),
)
_REPAIR_ERROR_CHARS = max(
    300,
    int(os.getenv("CODEBASE_REPAIR_ERROR_CHARS", "800")),
)
_REPAIR_MAX_TOKENS = max(
    1024,
    int(os.getenv("CODEBASE_REPAIR_MAX_TOKENS", "4096")),
)


def _extract_code_text(text: str) -> str:
    raw = (text or "").strip()
    if "```" in raw:
        parts = raw.split("```")
        for part in parts[1::2]:
            candidate = part.strip()
            if "\n" in candidate:
                first_line, rest = candidate.split("\n", 1)
                if first_line.strip().lower() in {"python", "py"}:
                    candidate = rest.strip()
            if "def generate_problem" in candidate:
                raw = candidate
                break
    markers = [
        "import random",
        "from random",
        "def generate_problem",
    ]
    starts = [raw.find(marker) for marker in markers if raw.find(marker) >= 0]
    if starts:
        raw = raw[min(starts):]
    return raw.strip()


def _compact_generation_spec(prompt: str) -> str:
    keep_prefixes = (
        "- 입력 hash_tags:",
        "- root_flows",
        "- branch_conditions:",
        "- main_huddle",
    )
    lines = []
    for line in (prompt or "").splitlines():
        stripped = line.strip()
        if any(stripped.startswith(prefix) for prefix in keep_prefixes):
            lines.append(stripped)
    if not lines:
        return "generate_problem(seed=None)을 구현하고 기존 반환 스키마를 유지한다."
    return "\n".join(lines)


def _compact_code_context(code_text: str) -> str:
    snippet = (code_text or "").strip()
    limit = _REPAIR_CODE_HEAD_CHARS + _REPAIR_CODE_TAIL_CHARS
    if len(snippet) <= limit:
        return snippet
    head = snippet[:_REPAIR_CODE_HEAD_CHARS].rstrip()
    tail = snippet[-_REPAIR_CODE_TAIL_CHARS:].lstrip()
    return f"{head}\n\n# ... middle omitted for repair prompt ...\n\n{tail}"


def _build_repair_prompt(
    *,
    prompt: str,
    code_text: str,
    error_message: str,
) -> str:
    snippet = _compact_code_context(code_text)
    spec = _compact_generation_spec(prompt)
    error = (error_message or "").strip()
    if len(error) > _REPAIR_ERROR_CHARS:
        error = error[:_REPAIR_ERROR_CHARS] + "\n... truncated ..."

    return textwrap.dedent(
        f"""
        오류 난 문제 생성 코드를 최소 수정하세요.

        오류:
        {error}

        유지할 생성 조건:
        {spec}

        규칙:
        - 전체 Python 코드만 출력한다. 설명/마크다운/JSON 금지.
        - def generate_problem(seed=None) 필수.
        - 외부 라이브러리, 파일, 네트워크, sympy import 금지.
        - 반환 키: quest_title, quest_answer, answer, main_huddle, primary_hash_tag, quest_image, solves.
        - solves 각 항목은 flow, hash_tag, hint_riddle, answer_riddle, enter_huddle, branches를 가진다.
        - 기존 의도는 유지하되 오류 원인만 고친다.

        코드:
        {snippet}
        """
    ).strip()


def repair_codebase(
    *,
    prompt: str,
    code_text: str,
    error_message: str,
) -> Dict[str, Any]:
    if not is_sam_configured():
        raise RuntimeError(f"{SAM_API_KEY_ENV} is not set")

    repair_prompt = _build_repair_prompt(
        prompt=prompt,
        code_text=code_text,
        error_message=error_message,
    )

    new_code = _extract_code_text(
        chat_completion_text(
            model=DEFAULT_CODEBASE_REPAIR_MODEL,
            prompt=repair_prompt,
            temperature=0.1,
            max_tokens=_REPAIR_MAX_TOKENS,
        )
    )
    if not new_code or "def generate_problem" not in new_code:
        raise RuntimeError("repair model did not return valid code")

    diff = "\n".join(
        difflib.unified_diff(
            code_text.splitlines(),
            new_code.splitlines(),
            fromfile="before.py",
            tofile="after.py",
            lineterm="",
        )
    )
    return {"code": new_code, "diff": diff}
