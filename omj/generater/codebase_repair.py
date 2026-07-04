from __future__ import annotations

import difflib
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


def _extract_code_text(text: str) -> str:
    raw = (text or "").strip()
    if raw.startswith("```"):
        raw = raw.split("\n", 1)[-1]
    if raw.endswith("```"):
        raw = raw.rsplit("\n", 1)[0]
    return raw.strip()


def _build_repair_prompt(
    *,
    prompt: str,
    code_text: str,
    error_message: str,
) -> str:
    snippet = code_text.strip()
    if len(snippet) > 5000:
        snippet = snippet[-5000:]

    return textwrap.dedent(
        f"""
        아래 Python 코드베이스를 오류 메시지에 맞게 수정하세요.

        오류:
        {error_message}

        필수 규칙:
        - 반드시 generate_problem(seed=None) 함수를 포함하세요.
        - sympy import 금지.
        - meta["sympy"]는 문자열 기반의 SymPy 표현식만 사용하세요.
        - meta["sympy"]["param_symbols"]와 meta["params"] 키는 정확히 일치해야 합니다.
        - equations/constraints/answer_expr는 bool 값이 아니라 문자열이어야 합니다.
        - 출력은 전체 Python 코드만 포함하세요 (설명/마크다운/JSON 금지).

        기존 코드 (일부):
        {snippet}

        원본 프롬프트:
        {prompt}
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
            max_tokens=8192,
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
