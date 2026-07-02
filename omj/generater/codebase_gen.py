from __future__ import annotations

import json
import os
import random
import textwrap
import threading
from typing import Any, Dict, List, Optional, Tuple

from google import genai

from env_loader import load_env
from generater.codebase_repair import repair_codebase
from generater.codebase_runner import run_codebase, run_codebase_batch, validate_result


def _log_done(label: str) -> None:
    print(f"[{label}] 실행완료")


def _print_progress(current: int, total: int, status: str) -> None:
    bar_len = 30
    filled = int(bar_len * current / total)
    bar = "█" * filled + "-" * (bar_len - filled)
    print(f"[진행률] |{bar}| {current}/{total} ({status})")


load_env()

COMETAPI_KEY = os.environ.get("COMETAPI_KEY")
BASE_URL = "https://api.cometapi.com"
DEFAULT_MODEL = "gemini-3.5-flash"

_client = genai.Client(
    http_options={"api_version": "v1beta", "base_url": BASE_URL},
    api_key=COMETAPI_KEY,
)


class CodebaseGenerationError(RuntimeError):
    """Raised when the unified generation pipeline gives up."""


def _extract_code_text(text: str) -> str:
    print(f"[입력] raw_text_length={len(text or '')}")
    raw = (text or "").strip()
    if raw.startswith("```"):
        raw = raw.split("\n", 1)[-1]
    if raw.endswith("```"):
        raw = raw.rsplit("\n", 1)[0]
    value = raw.strip()
    _log_done("코드 텍스트 추출")
    return value


def _build_generation_prompt(
    *,
    hash_tags: List[str],
    solves_count: int,
    branch_conditions: int,
    main_huddle: int,
) -> str:
    print(
        f"[입력] build_generation_prompt hash_tags={hash_tags}, "
        f"solves_count={solves_count}, branch_conditions={branch_conditions}, main_huddle={main_huddle}"
    )
    tags_json = json.dumps(hash_tags, ensure_ascii=False)
    branch_note = (
        "- branch_conditions 만큼 분기 레인을 만든다. branches 배열에 조건별 레인을 추가한다."
        if branch_conditions > 0
        else "- 분기가 필요 없으면 branches 는 빈 리스트로 둔다."
    )
    prompt = f"""
    수학/과학 문제를 무한히 생성하는 단일 Python 스크립트를 작성하라.
    - 입력 hash_tags: {tags_json}
    - root_flows(solves 길이): {solves_count}
    - branch_conditions: {branch_conditions}
    - 답 변수는 정수 k ( -20 ~ 20, 0 제외 ) 한 개만 사용한다.
    - random.Random(seed) 로 모든 난수를 생성해 동일 seed 시 동일 문제를 재현한다.
    - k 를 기준으로 역방향으로 공식을 설계하여 quest_answer 가 항상 k 가 되도록 한다.
    - 외부 라이브러리, 파일/네트워크 접근 금지. 표준 라이브러리만 사용.
    - generate_problem(seed=None) 하나만 공개하고, 호출 시 아래 JSON 스키마를 그대로 반환한다.
    - 모든 수식 문자열은 $...$ 로 감싼다.
    - main_huddle 은 {main_huddle} 으로 설정한다.
    - primary_hash_tag 는 hash_tags 중 대표 1개를 선택한다.
    {branch_note}

    반환 스키마(키/구조를 변경하지 말 것):
    {{
      "quest_title": "문제 본문 수식 $...$안에 ",
      "quest_answer": "정답값 $...$",
      "main_huddle": {main_huddle},
      "primary_hash_tag": "hash_tags 중 가장 대표적인 태그 1개",
      "quest_image": null,
      "solves": [
        {{
          "flow": "요약 텍스트와 수식 $...$",
          "hash_tag": ["hash_tags 중 현재 solves에 가장 부합하는 1개 선택"],
          "hint_riddle": "힌트 텍스트와 수식 $...$",
          "answer_riddle": "상세 풀이 설명 텍스트와 수식 $...$",
          "enter_huddle": 0,
          "branches": [
            {{
              "flow": "...",
              "hash_tag": ["hash_tags 중 선택"],
              "hint_riddle": "...",
              "answer_riddle": "...",
              "enter_huddle": 0,
              "branches": []
            }}
          ]
        }}
      ]
    }}

    오직 순수 Python 코드만 반환하고 마크다운 코드펜스는 넣지 말라.
    """
    result = textwrap.dedent(prompt).strip()
    _log_done("프롬프트 생성")
    return result


def _request_code(prompt: str, *, model: str = DEFAULT_MODEL) -> str:
    print(f"[입력] LLM model={model}, prompt_len={len(prompt)}")
    if not COMETAPI_KEY:
        raise RuntimeError("COMETAPI_KEY is not set")
    response = _client.models.generate_content(
        model=model,
        contents=prompt,
    )
    _log_done("LLM 호출")
    return response.text or ""


def _review_codebase(
    *,
    prompt: str,
    code_text: str,
    hash_tags: List[str],
    solves_count: int,
    branch_conditions: int,
    main_huddle: int,
) -> Tuple[str, str]:
    print(
        "[입력] review_codebase "
        f"solves_count={solves_count}, branch_conditions={branch_conditions}, main_huddle={main_huddle}"
    )
    try:
        _ = validate_result(
            run_codebase({"code": code_text}, seed=123456),
            fallback_hash_tags=hash_tags,
            expected_solves=solves_count,
            expected_branches=branch_conditions,
            main_huddle=main_huddle,
        )
        _log_done("1차 리뷰")
        return code_text, "0"
    except Exception as exc:
        repaired = repair_codebase(
            prompt=prompt,
            code_text=code_text,
            error_message=f"[review] {exc}",
        )
        _log_done("diff 수정")
        return repaired["code"], "patched"


def _execute_once(
    code_text: str,
    *,
    seed: int,
    hash_tags: List[str],
    solves_count: int,
    branch_conditions: int,
    main_huddle: int,
) -> Dict[str, Any]:
    print(
        f"[입력] execute_once seed={seed}, solves_count={solves_count}, "
        f"branch_conditions={branch_conditions}, main_huddle={main_huddle}"
    )
    raw = run_codebase({"code": code_text}, seed=seed)
    result = validate_result(
        raw,
        fallback_hash_tags=hash_tags,
        expected_solves=solves_count,
        expected_branches=branch_conditions,
        main_huddle=main_huddle,
    )
    _log_done("단일 실행 검증")
    return result


def _attempt_repair(
    *,
    prompt: str,
    code_text: str,
    error_message: str,
) -> str:
    print(f"[입력] attempt_repair error_message={error_message[:200]}")
    repaired = repair_codebase(
        prompt=prompt,
        code_text=code_text,
        error_message=error_message,
    )
    _log_done("실패 후 diff 수정")
    return repaired["code"]


def _collect_seed_bank(
    code_text: str,
    *,
    attempts: int,
    hash_tags: List[str],
    solves_count: int,
    branch_conditions: int,
    main_huddle: int,
) -> List[int]:
    rng = random.Random(2026)
    seeds: List[int] = []
    batch_size = 8
    remaining = attempts

    while remaining > 0:
        batch_seeds = []
        while len(batch_seeds) < batch_size and remaining > 0:
            seed = rng.randint(1, 1_000_000_000)
            batch_seeds.append(seed)
            remaining -= 1

        entry = {"code": code_text}
        batch_results = run_codebase_batch(entry, batch_seeds, timeout_seconds=12.0)

        for idx, raw_result in enumerate(batch_results):
            seed = batch_seeds[idx]
            if isinstance(raw_result, dict) and "_error" in raw_result:
                print(f"[코드베이스실행] {attempts - remaining + idx - len(batch_seeds) + 1}/{attempts} 시도 ... 실패")
                continue
            try:
                validate_result(
                    raw_result,
                    fallback_hash_tags=hash_tags,
                    expected_solves=solves_count,
                    expected_branches=branch_conditions,
                    main_huddle=main_huddle,
                )
                seeds.append(seed)
                print(f"[코드베이스실행] {attempts - remaining + idx - len(batch_seeds) + 1}/{attempts} 시도 ... 성공")
            except Exception:
                print(f"[코드베이스실행] {attempts - remaining + idx - len(batch_seeds) + 1}/{attempts} 시도 ... 실패")
                continue

        _print_progress(min(attempts - remaining, attempts), attempts, "seed 검증 중")

    _log_done("seed 수집")
    return seeds


def generate_codebase(
    *,
    tags: List[str],
    difficulty: int,
    solves_count: int,
    strategy_level: int,
    branch_conditions: int,
    max_attempts: int = 3,
) -> Dict[str, Any]:
    """
    Unified pipeline:
    1) LLM으로 코드 생성
    2) 1회 리뷰(실패 시 diff 수정 1회)
    3) 실행 실패 시 diff 기반 수정 최대 3회, 그래도 실패면 새 코드 재생성
    4) 최초 성공 후 100회 추가 실행, 성공 seed 수집
    """
    if not tags:
        raise ValueError("tags must not be empty")
    prompt = _build_generation_prompt(
        hash_tags=tags,
        solves_count=solves_count,
        branch_conditions=branch_conditions,
        main_huddle=strategy_level,
    )
    print(
        f"[입력] generate_codebase tags={tags}, difficulty={difficulty}, "
        f"solves_count={solves_count}, strategy_level={strategy_level}, branch_conditions={branch_conditions}, "
        f"max_attempts={max_attempts}"
    )
    regen_attempts = 0
    last_error: Optional[Exception] = None
    total_steps = 5  # prompt/llm, review, seed-collect, finish, regen loops

    while regen_attempts < max_attempts:
        code_text = _extract_code_text(_request_code(prompt))
        _print_progress(1, total_steps, "프롬프트/LLM 완료")
        code_text, review_status = _review_codebase(
            prompt=prompt,
            code_text=code_text,
            hash_tags=tags,
            solves_count=solves_count,
            branch_conditions=branch_conditions,
            main_huddle=strategy_level,
        )
        _print_progress(2, total_steps, "리뷰 완료")

        repaired_runs = 0
        while repaired_runs < 3:
            seed = random.randint(1, 1_000_000_000)
            try:
                validated = _execute_once(
                    code_text,
                    seed=seed,
                    hash_tags=tags,
                    solves_count=solves_count,
                    branch_conditions=branch_conditions,
                    main_huddle=strategy_level,
                )
                threading.Thread(
                    target=_collect_seed_bank,
                    kwargs=dict(
                        code_text=code_text,
                        attempts=6,
                        hash_tags=tags,
                        solves_count=solves_count,
                        branch_conditions=branch_conditions,
                        main_huddle=strategy_level,
                    ),
                    daemon=True,
                ).start()
                validated["review_status"] = review_status
                _log_done("generate_codebase 완료")
                _print_progress(5, total_steps, "최종 완료")
                return {
                    "prompt": prompt,
                    "code": code_text,
                    "mode": "unified",
                    "tags": tags,
                    "difficulty": difficulty,
                    "tier": None,
                    "solves_count": solves_count,
                    "strategy_level": strategy_level,
                    "branch_conditions": branch_conditions,
                    "seed_cache": [],
                    "validated_sample": {
                        "seed": seed,
                        "ai_result": validated.get("ai_result"),
                    },
                }
            except Exception as exc:
                last_error = exc
                repaired_runs += 1
                print(f"[diff 수정] {repaired_runs}/3 회차 ... 실패: {exc}")
                if repaired_runs >= 3:
                    break
                code_text = _attempt_repair(
                    prompt=prompt,
                    code_text=code_text,
                    error_message=str(exc),
                )

        regen_attempts += 1
        _print_progress(regen_attempts, max_attempts, "재생성 시도")

    raise CodebaseGenerationError(f"codebase generation failed: {last_error}")
