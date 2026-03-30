from __future__ import annotations

import os
import random
import textwrap
from typing import Any, Dict, List

from google import genai

from env_loader import load_env
from generater.codebase_runner import compile_code, validate_result


load_env()

COMETAPI_KEY = os.environ.get("COMETAPI_KEY")
BASE_URL = "https://api.cometapi.com"

_client = genai.Client(
    http_options={"api_version": "v1beta", "base_url": BASE_URL},
    api_key=COMETAPI_KEY,
)


def build_prompt(
    tags: List[str],
    difficulty: int,
    solves_count: int,
    strategy_level: int,
    branch_conditions: int,
) -> str:
    tags_json = ", ".join(tags)

    base_meta = textwrap.dedent(
        f"""
        - meta에는 반드시 다음을 포함해야 합니다:
            {{
              "difficulty": {difficulty},
              "concept": "...",
              "params": {{...}},
              "hash_tags": {tags}
            }}
        """
    ).strip()

    body = textwrap.dedent(
        f"""
        수능 스타일의 수학 문제를 생성하는 Python 모듈을 작성하여야 한다
        다음 해시태그를 주제로 반드시 포함하여야 함: {tags_json}

        서비스 난이도 설정:
        - solves_count = {solves_count}
        - strategy_level = {strategy_level}
        - branch_conditions = {branch_conditions}
        - 계산된 난이도 점수 = {difficulty}

        필수 인터페이스:
        - generate_problem(seed=None) 함수를 구현해야 합니다.
        - 반환 형식:
            {{
                "problem": str,
                "answer": int,
                "solution": str,
                "meta": dict
            }}
        {base_meta}

        필수 제약 조건:
        - 정답은 정수이며 0이 아니어야 하고, 절댓값은 100 이하
        - 파라미터는 작은 정수 사용 (가능하면 [-5, 5] 범위)
        - seed가 주어지면 반드시 결정론적으로 동일한 결과 생성
        - 최대 100번 재시도 후 실패 시 Exception 발생
        - sympy를 사용하여 최종 정답 검증
        - 함수는 모듈화하고 print 사용 금지

        단순 문제 방지 조건:
        - 너무 쉬운 문제는 금지 (예: abs(answer) <= 5)
        - 최소 2개의 구조 기반 안티-쇼트컷 검증 로직 구현 (브루트포스 방지)
        - 문제 및 해설에서 부호 표현을 깔끔하게 유지 ("x - -2", "+ -", "- +" 금지)

        주제 가이드:
        - 해시태그와 일관된 문제 유형 선택
        - 작은 정수 파라미터로도 풀이 가능한 구조 유지

        출력은 반드시 전체 Python 코드만 반환하세요. 설명은 포함하지 마세요.
        """
    ).strip()

    return body


def _extract_code_text(text: str) -> str:
    raw = text.strip()
    if raw.startswith("```"):
        raw = raw.split("\n", 1)[-1]
    if raw.endswith("```"):
        raw = raw.rsplit("\n", 1)[0]
    return raw.strip()


def _build_repair_prompt(base_prompt: str, code_text: str, error_message: str) -> str:
    snippet = code_text.strip()
    if len(snippet) > 4000:
        snippet = snippet[-4000:]

    return textwrap.dedent(
        f"""
        이전에 생성된 코드가 실행 또는 컴파일에 실패했습니다.

        오류:
        {error_message}

        이전 코드 (불완전할 수 있음):
        {snippet}

        원래 프롬프트:
        {base_prompt}

        전체 수정된 Python 코드를 다시 작성하세요.
        출력이 잘린 경우 누락된 부분을 포함하세요.
        그렇지 않다면 요구사항을 만족하도록 전체를 재작성하세요.
        """
    ).strip()


def _request_code(prompt: str) -> str:
    if not COMETAPI_KEY:
        raise RuntimeError("COMETAPI_KEY is not set")

    response = _client.models.generate_content(
        model="gemini-3.1-flash-lite",
        contents=prompt,
    )
    return response.text or ""


def generate_codebase(
    *,
    tags: List[str],
    difficulty: int,
    solves_count: int,
    strategy_level: int,
    branch_conditions: int,
    max_attempts: int = 3,
) -> Dict[str, Any]:
    if not tags:
        raise ValueError("tags must not be empty")

    base_prompt = build_prompt(
        tags,
        difficulty,
        solves_count,
        strategy_level,
        branch_conditions,
    )

    prompt = base_prompt
    last_error: Exception | None = None

    for _ in range(max_attempts):
        code_text = _extract_code_text(_request_code(prompt))

        try:
            module = compile_code(code_text)
            seed = random.randint(1, 1_000_000_000)
            result = module.generate_problem(seed=seed)

            validate_result(result)

            return {
                "prompt": base_prompt,
                "code": code_text,
                "mode": "tag_driven",
                "tags": tags,
                "difficulty": difficulty,
                "tier": None,
                "solves_count": solves_count,
                "strategy_level": strategy_level,
                "branch_conditions": branch_conditions,
            }

        except Exception as exc:
            last_error = exc
            prompt = _build_repair_prompt(base_prompt, code_text, str(exc))

    raise RuntimeError(f"codebase generation failed: {last_error}")