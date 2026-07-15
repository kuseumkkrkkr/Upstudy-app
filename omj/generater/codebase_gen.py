from __future__ import annotations

import json
import os
import random
import textwrap
from typing import Any, Dict, List, Optional, Tuple

from env_loader import load_env
from generater.codebase_repair import repair_codebase
from generater.codebase_runner import run_codebase, run_codebase_batch, validate_result
from services.ai.sam_client import (
    DEFAULT_CODEBASE_MODEL,
    SAM_API_KEY_ENV,
    chat_completion_text,
    generate_json,
    is_sam_configured,
)
from services.jobs.cancellation import check_cancelled


def _log_done(label: str) -> None:
    print(f"[{label}] 실행완료")


def _print_progress(current: int, total: int, status: str) -> None:
    bar_len = 30
    filled = int(bar_len * current / total)
    bar = "#" * filled + "-" * (bar_len - filled)
    print(f"[진행률] |{bar}| {current}/{total} ({status})")


load_env()

DEFAULT_MODEL = DEFAULT_CODEBASE_MODEL
_CODEBASE_GEN_MAX_TOKENS = max(
    2048,
    int(os.getenv("CODEBASE_GEN_MAX_TOKENS", "6144")),
)
_CODEBASE_GEN_BATCH_TIMEOUT_SEC = max(
    1.0,
    float(os.getenv("CODEBASE_GEN_BATCH_TIMEOUT_SEC", "6")),
)
_CODEBASE_GEN_MAX_ATTEMPTS = max(
    1,
    int(os.getenv("CODEBASE_GEN_MAX_ATTEMPTS", "3")),
)
_SEMANTIC_REVIEW_ENABLED = os.getenv(
    "CODEBASE_SEMANTIC_REVIEW_ENABLED",
    "1",
).strip().lower() not in {"0", "false", "no"}
_SEMANTIC_REVIEW_MODEL = os.getenv(
    "CODEBASE_SEMANTIC_REVIEW_MODEL",
    "az-deepseek-v4-flash",
)
_SEMANTIC_REVIEW_SEEDS = (123456, 789012, 345678)
_SEMANTIC_REVIEW_REPAIR_ATTEMPTS = max(
    0,
    min(1, int(os.getenv("CODEBASE_SEMANTIC_REPAIR_ATTEMPTS", "1"))),
)


class CodebaseGenerationError(RuntimeError):
    """Raised when the unified generation pipeline gives up."""


def _review_json_default(value: Any) -> Any:
    """필요 변수: Pydantic 결과 등 기본 JSON 비지원 객체. 작동 원리: model_dump 결과를 우선 사용하고 나머지는 문자열로 안전 변환한다."""
    model_dump = getattr(value, "model_dump", None)
    if callable(model_dump):
        return model_dump()
    return str(value)


def _extract_code_text(text: str) -> str:
    print(f"[입력] raw_text_length={len(text or '')}")
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
    value = raw.strip()
    _log_done("코드 텍스트 추출")
    return value


def _format_generation_context(generation_context: Optional[Dict[str, Any]]) -> str:
    if not isinstance(generation_context, dict) or not generation_context:
        return ""

    lines = [
        "[고급 생성 파라미터 반영 지시]",
        "- 아래 지표는 메타데이터가 아니라 실제 문제 구조, 조건, 풀이 흐름에 반영한다.",
    ]

    expected_number = str(generation_context.get("expected_number") or "").strip()
    profile_label = str(generation_context.get("profile_label") or "").strip()
    profile_intent = str(generation_context.get("profile_intent") or "").strip()
    if expected_number:
        lines.append(f"- 수능 예상 번호: {expected_number}")
    if profile_label:
        lines.append(f"- 난이도 프로필: {profile_label}")
    if profile_intent:
        lines.append(f"- 출제 의도: {profile_intent}")

    metrics = generation_context.get("metrics")
    if isinstance(metrics, dict) and metrics:
        lines.append(
            "- 전체 고급 지표(조절 전 기준 성향이며 모든 횟수를 한 문항에 문자 그대로 강제하지 않음): "
            + json.dumps(metrics, ensure_ascii=False, sort_keys=True)
        )

    changed_metrics = generation_context.get("changed_metrics")
    if isinstance(changed_metrics, dict) and changed_metrics:
        lines.append(
            "- 기본값에서 조절한 지표: "
            + json.dumps(changed_metrics, ensure_ascii=False, sort_keys=True)
        )
        lines.append(
            "- 축 독립성 계약: 위에서 조절한 지표는 식별 가능한 하드 제약으로 반영한다. "
            "나머지 기본값은 일반 품질 성향으로만 참고하며 서로 충돌하는 횟수를 억지로 삽입하지 않는다. "
            "단, 한 축이 낮다고 관련 없는 문제 전체를 단순화하지 않는다."
        )

    dominant_metrics = generation_context.get("dominant_metrics")
    if isinstance(dominant_metrics, list) and dominant_metrics:
        lines.append("- 우선 반영 지표:")
        for item in dominant_metrics[:12]:
            if not isinstance(item, dict):
                continue
            label = item.get("label") or item.get("id")
            value = item.get("value")
            directive = item.get("directive")
            contract = item.get("contract") or ""
            lines.append(f"  - {label}={value}: {directive} {contract}".rstrip())

    node_directives = generation_context.get("node_directives")
    if isinstance(node_directives, list) and node_directives:
        lines.append("- 풀이 논리 노드 지시:")
        for node in node_directives[:32]:
            if not isinstance(node, dict):
                continue
            node_id = node.get("node_id") or "node"
            node_type = node.get("node_type") or "reasoning"
            instruction = node.get("instruction") or ""
            tags = node.get("tags") or []
            branches = node.get("branches") or []
            lines.append(
                f"  - {node_id} type={node_type} tags={tags} "
                f"next={branches}: {instruction}"
            )

    examples = generation_context.get("examples")
    if isinstance(examples, list) and examples:
        lines.append("- 생성 예시 방향:")
        for example in examples[:8]:
            lines.append(f"  - {example}")

    prompt_excerpt = str(generation_context.get("prompt_excerpt") or "").strip()
    if prompt_excerpt:
        lines.append(f"- 교사 프롬프트 요약: {prompt_excerpt}")

    return "\n".join(lines)


def _build_generation_prompt(
    *,
    hash_tags: List[str],
    solves_count: int,
    branch_conditions: int,
    main_huddle: int,
    generation_context: Optional[Dict[str, Any]] = None,
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
    advanced_note = _format_generation_context(generation_context)
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
    - 문제 조건은 서로 모순되지 않아야 하며 생성한 k를 모든 조건에 대입해 성립함을 코드 내부에서 검증한다.
    - quest_answer는 조건을 만족하는 유일한 값이어야 하며, 다른 후보가 존재하면 해당 seed 결과를 생성하지 않는다.
    - 고급 지표의 횟수형 목표는 풀이 설명에서 각 단계가 구분되도록 실제 연산·조건·분기로 구현한다.
    - 코드를 쓰기 전에 내부적으로 ① 풀이 그래프 구조 설계 ② k에서 조건을 역산 ③ 모든 조건의 동시 성립 검토
      ④ 각 노드의 근거와 다음 노드로 넘어가는 이유를 문장화 ⑤ 최종 코드 검증 순서로 작업한다.
    - 내부 검토 과정 자체는 출력하지 말고, 검토 결과를 quest_title과 solves의 구체적인 설명에 반영한다.
    - 각 answer_riddle에는 사용한 조건, 식 변형의 이유, 다음 단계로 이어지는 근거를 생략 없이 적는다.
    - 분기 branches에는 해당 경우로 나뉘는 조건과 다시 합쳐지는 공통 결론을 명시한다.
    {branch_note}
    {advanced_note}

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
    if not is_sam_configured():
        raise RuntimeError(f"{SAM_API_KEY_ENV} is not set")
    text = chat_completion_text(
        model=model,
        prompt=prompt,
        temperature=0.2,
        max_tokens=_CODEBASE_GEN_MAX_TOKENS,
    )
    _log_done("LLM 호출")
    return text


def _review_codebase(
    *,
    prompt: str,
    code_text: str,
    hash_tags: List[str],
    solves_count: int,
    branch_conditions: int,
    main_huddle: int,
    require_parameter_score: bool = True,
    cancel_event: Any = None,
) -> Tuple[str, str]:
    """필요 변수: 생성 코드·태그·풀이 구조 목표. 작동 원리: 서로 다른 고정 seed를 실행해 구조와 의미를 함께 검증한다."""
    print(
        "[입력] review_codebase "
        f"solves_count={solves_count}, branch_conditions={branch_conditions}, main_huddle={main_huddle}"
    )
    try:
        check_cancelled(cancel_event)
        samples = [
            validate_result(
                run_codebase({"code": code_text}, seed=seed, cancel_event=cancel_event),
                fallback_hash_tags=hash_tags,
                expected_solves=solves_count,
                expected_branches=branch_conditions,
                main_huddle=main_huddle,
            )
            for seed in _SEMANTIC_REVIEW_SEEDS
        ]
        if _SEMANTIC_REVIEW_ENABLED:
            code_text, semantic_status = _semantic_review_codebase(
                prompt=prompt,
                code_text=code_text,
                sample=samples,
                require_parameter_score=require_parameter_score,
            )
            _log_done("수학 정합성 리뷰")
            return code_text, semantic_status
        _log_done("1차 리뷰")
        return code_text, "0"
    except CodebaseGenerationError:
        raise
    except Exception as exc:
        repaired = repair_codebase(
            prompt=prompt,
            code_text=code_text,
            error_message=f"[review] {exc}",
        )
        _log_done("diff 수정")
        return repaired["code"], "patched"


def _semantic_review_codebase(
    *,
    prompt: str,
    code_text: str,
    sample: Any,
    sample_seeds: Optional[List[int]] = None,
    require_parameter_score: bool = True,
) -> Tuple[str, str]:
    """필요 변수: 생성 요구사항·코드·샘플·선택 seed. 작동 원리: 각 코드 경로와 샘플을 독립 검산하고 실패 시 같은 seed로 수리한다."""
    current_code = code_text
    current_samples = sample if isinstance(sample, list) else [sample]
    repair_seeds = sample_seeds or list(
        _SEMANTIC_REVIEW_SEEDS[: len(current_samples)]
    )
    last_scores = (0, 0)
    last_issues: List[str] = []
    for attempt in range(1 + _SEMANTIC_REVIEW_REPAIR_ATTEMPTS):
        review_prompt = (
            "다음 생성 문제 샘플의 수학적 정합성을 엄격히 검토하라. "
            "각 샘플마다 모든 본문 조건을 quest_answer에 직접 대입하고, 미지수를 독립적으로 풀어 "
            "정답이 유일한지 검산하라. 하나라도 미결정·모순·복수 정답이면 valid=false로 판정한다. "
            "answer_riddle의 식과 결론도 실제 계산과 대조한다. "
            f"파라미터 점수 하드 게이트 적용={require_parameter_score}. "
            "이 값이 False이면 기본 지표 미반영을 hard_constraint_issues에 넣지 말고, "
            "명시된 노드 지시만 하드 제약으로 검사한다. 노드 지시도 없으면 hard_constraints_valid=true, "
            "hard_constraint_issues=[]로 반환한다. "
            "기본값에서 조절한 고급 생성 축이 목표값대로 반영됐는지 확인하되, "
            "조절하지 않은 기준 성향의 횟수를 문자 그대로 요구하지 않는다. "
            "기본값에서 조절한 각 축과 노드 지시를 하나씩 대조하며, 하나라도 어기면 "
            "hard_constraints_valid=false로 판정한다. 제공된 생성 코드의 무작위 분기 전체도 읽고, "
            "샘플에 아직 나타나지 않은 코드 경로가 하드 제약을 어길 수 있어도 false로 판정한다. "
            "JSON 객체로 valid(boolean), "
            "hard_constraints_valid(boolean), math_score(0~10 정수), parameter_score(0~10 정수), "
            "issues(한국어 문자열 배열), hard_constraint_issues(한국어 문자열 배열)를 반환하라. "
            "두 오류 배열에는 실제 실패만 기록하고 통과하면 빈 배열로 둔다.\n\n"
            f"생성 요구사항:\n{prompt[:10000]}\n\n"
            f"검토할 생성 코드:\n{current_code[:12000]}\n\n"
            "서로 다른 고정 seed 샘플들:\n"
            f"{json.dumps(current_samples, ensure_ascii=False, default=_review_json_default)[:18000]}"
        )
        review = generate_json(
            model=_SEMANTIC_REVIEW_MODEL,
            prompt=review_prompt,
            temperature=0.0,
            max_tokens=1200,
        )
        valid = review.get("valid") is True
        hard_constraints_valid = review.get("hard_constraints_valid") is True
        try:
            score = int(review.get("math_score", 0))
        except (TypeError, ValueError):
            score = 0
        try:
            parameter_score = int(review.get("parameter_score", 0))
        except (TypeError, ValueError):
            parameter_score = 0
        issues = review.get("issues")
        hard_issues = review.get("hard_constraint_issues")
        if not isinstance(issues, list):
            issues = ["수학 오류 배열 형식이 올바르지 않습니다."]
        if not isinstance(hard_issues, list):
            hard_issues = ["하드 제약 오류 배열 형식이 올바르지 않습니다."]
        last_scores = (score, parameter_score)
        if (
            valid
            and hard_constraints_valid
            and not issues
            and not hard_issues
            and score >= 7
            and (not require_parameter_score or parameter_score >= 6)
        ):
            prefix = "semantic" if attempt == 0 else "semantic_repaired"
            return current_code, f"{prefix}:{score}:{parameter_score}"
        if not issues and not hard_issues:
            issues = ["조건 성립, 정답 유일성 또는 파라미터 반영 검토를 통과하지 못했습니다."]
        issues.extend(hard_issues)
        last_issues = [str(issue) for issue in issues[:5]]
        if attempt >= _SEMANTIC_REVIEW_REPAIR_ATTEMPTS:
            break
        repaired = repair_codebase(
            prompt=prompt,
            code_text=current_code,
            error_message="[semantic review] " + " | ".join(str(issue) for issue in issues[:8]),
        )
        current_code = repaired["code"]
        current_samples = [
            run_codebase({"code": current_code}, seed=seed)
            for seed in repair_seeds
        ]
    raise CodebaseGenerationError(
        "semantic review failed after repair: "
        f"math_score={last_scores[0]}, parameter_score={last_scores[1]}, "
        f"issues={' | '.join(last_issues)}"
    )


def _execute_once(
    code_text: str,
    *,
    seed: int,
    hash_tags: List[str],
    solves_count: int,
    branch_conditions: int,
    main_huddle: int,
    cancel_event: Any = None,
) -> Dict[str, Any]:
    print(
        f"[입력] execute_once seed={seed}, solves_count={solves_count}, "
        f"branch_conditions={branch_conditions}, main_huddle={main_huddle}"
    )
    check_cancelled(cancel_event)
    raw = run_codebase({"code": code_text}, seed=seed, cancel_event=cancel_event)
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
    max_successes: Optional[int] = None,
    cancel_event: Any = None,
) -> List[int]:
    rng = random.Random(2026)
    seeds: List[int] = []
    batch_size = 8
    remaining = attempts

    while remaining > 0:
        if max_successes is not None and len(seeds) >= max_successes:
            break
        check_cancelled(cancel_event)
        batch_seeds = []
        while len(batch_seeds) < batch_size and remaining > 0:
            seed = rng.randint(1, 1_000_000_000)
            batch_seeds.append(seed)
            remaining -= 1

        entry = {"code": code_text}
        batch_results = run_codebase_batch(
            entry,
            batch_seeds,
            timeout_seconds=_CODEBASE_GEN_BATCH_TIMEOUT_SEC,
            cancel_event=cancel_event,
        )

        for idx, raw_result in enumerate(batch_results):
            check_cancelled(cancel_event)
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
                if max_successes is not None and len(seeds) >= max_successes:
                    break
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
    cancel_event: Any = None,
    generation_context: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """필요 변수: 태그·풀이 구조·고급 생성 문맥. 작동 원리: 코드 생성, 다중 seed/코드 경로 검산, 최종 seed 재검산 후 실패 시 제한적으로 수리·재생성한다."""
    if not tags:
        raise ValueError("tags must not be empty")
    max_attempts = min(max_attempts, _CODEBASE_GEN_MAX_ATTEMPTS)
    check_cancelled(cancel_event)
    prompt = _build_generation_prompt(
        hash_tags=tags,
        solves_count=solves_count,
        branch_conditions=branch_conditions,
        main_huddle=strategy_level,
        generation_context=generation_context,
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
        check_cancelled(cancel_event)
        code_text = _extract_code_text(_request_code(prompt))
        check_cancelled(cancel_event)
        _print_progress(1, total_steps, "프롬프트/LLM 완료")
        try:
            code_text, review_status = _review_codebase(
                prompt=prompt,
                code_text=code_text,
                hash_tags=tags,
                solves_count=solves_count,
                branch_conditions=branch_conditions,
                main_huddle=strategy_level,
                require_parameter_score=bool(
                    (generation_context or {}).get("changed_metrics")
                ),
                cancel_event=cancel_event,
            )
        except CodebaseGenerationError as exc:
            last_error = exc
            regen_attempts += 1
            _print_progress(2, total_steps, f"정합성 실패, 코드 재생성 {regen_attempts}/{max_attempts}")
            continue
        _print_progress(2, total_steps, "리뷰 완료")

        repaired_runs = 0
        while repaired_runs < 3:
            check_cancelled(cancel_event)
            seed = random.randint(1, 1_000_000_000)
            try:
                validated = _execute_once(
                    code_text,
                    seed=seed,
                    hash_tags=tags,
                    solves_count=solves_count,
                    branch_conditions=branch_conditions,
                    main_huddle=strategy_level,
                    cancel_event=cancel_event,
                )
                if _SEMANTIC_REVIEW_ENABLED:
                    reviewed_code, runtime_status = _semantic_review_codebase(
                        prompt=prompt,
                        code_text=code_text,
                        sample=validated,
                        sample_seeds=[seed],
                        require_parameter_score=bool(
                            (generation_context or {}).get("changed_metrics")
                        ),
                    )
                    if reviewed_code != code_text:
                        code_text = reviewed_code
                        validated = _execute_once(
                            code_text,
                            seed=seed,
                            hash_tags=tags,
                            solves_count=solves_count,
                            branch_conditions=branch_conditions,
                            main_huddle=strategy_level,
                            cancel_event=cancel_event,
                        )
                    review_status = f"{review_status}/{runtime_status}"
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
                    "generation_context": generation_context or {},
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
                check_cancelled(cancel_event)

        regen_attempts += 1
        _print_progress(regen_attempts, max_attempts, "재생성 시도")

    raise CodebaseGenerationError(f"codebase generation failed: {last_error}")
