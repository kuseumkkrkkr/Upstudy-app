from __future__ import annotations

import textwrap
import types
from typing import Optional


def extract_code_text(text: str) -> str:
    raw = text.strip()
    if raw.startswith("```"):
        raw = raw.split("\n", 1)[-1]
    if raw.endswith("```"):
        raw = raw.rsplit("\n", 1)[0]
    return raw.strip()


def normalize_signs(text: str) -> str:
    if not text:
        return text
    patterns = [
        (r"\-\s*\-\s*", "+"),
        (r"\+\s*\-\s*", "-"),
        (r"\-\s*\+\s*", "-"),
        (r"\+\s*\+\s*", "+"),
    ]
    import re

    cleaned = text
    for _ in range(2):
        for pattern, repl in patterns:
            cleaned = re.sub(pattern, repl, cleaned)
    cleaned = re.sub(r"\s{2,}", " ", cleaned)
    return cleaned


def build_repair_prompt(
    base_prompt: str,
    code_text: str,
    error_message: str,
) -> str:
    snippet = code_text.strip()
    if len(snippet) > 4000:
        snippet = snippet[-4000:]
    return textwrap.dedent(
        f"""
        The previous code failed to run or compile.

        Error:
        {error_message}

        Previous code (may be incomplete):
        {snippet}

        Original prompt:
        {base_prompt}

        Please return full corrected Python code only.
        If the previous output was truncated, continue and include missing parts.
        Otherwise, rewrite as needed to satisfy the prompt requirements.
        """
    ).strip()


def compile_code(code: str) -> types.ModuleType:
    module = types.ModuleType("codebase_module")
    exec(compile(code, "<codebase>", "exec"), module.__dict__)
    generate_func = module.__dict__.get("generate_problem")
    if not callable(generate_func):
        raise RuntimeError("generate_problem 함수가 없습니다.")
    return module
