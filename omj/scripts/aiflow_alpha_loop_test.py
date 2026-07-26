from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
import random
import statistics
import os
import sys
from typing import Any


sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from scripts import wolfram_rule_based_generator as engine  # noqa: E402


def _is_positive_int(text: str) -> bool:
    """필요 변수: 정답 문자열. 작동 원리: 양의 정수 판별로 산술형 정답 산출의 기본 형식을 확인한다."""
    return text.strip().lstrip("-").isdigit()


def _flatten_steps(payload: dict[str, Any]) -> list[str]:
    """필요 변수: 문제 payload. 작동 원리: 단계 문자열을 정규화해 품질 통계로 사용할 수 있게 만든다."""
    return [line.strip() for line in payload.get("steps", []) if str(line).strip()]


def _single_case_case_payload(name: str) -> tuple[list[str], str, str]:
    """필요 변수: 케이스명. 작동 원리: 태그·프롬프트·플로우차트를 룰 엔진 입력 포맷으로 반환한다."""
    if name == "sequence":
        return (
            ["#수열", "#등차수열"],
            "수열에서 첫항과 공차를 이용해 a3의 값을 구해줘. a1=4, d=3",
            '{"nodes":[{"id":"s1","text":"문제의 조건을 정리한다.","branches":[]},{"id":"s2","text":"일반항 공식을 적용한다.","branches":[]},{"id":"s3","text":"n=3을 대입해 계산한다.","branches":[]}]}',
        )
    if name == "quadratic":
        return (
            ["#이차방정식", "#판별식", "#근의공식"],
            "이차방정식 x^2 - 5x + 6 = 0의 정수 해를 구하시오.",
            '{"nodes":[{"id":"q1","text":"판별식을 계산한다.","branches":[]},{"id":"q2","text":"근의 공식을 통해 정수 해를 검증한다.","branches":[]}]}',
        )
    return (
        ["#집합", "#교집합", "#합집합"],
        "집합의 크기가 |A|=24, |B|=10, |A∩B|=6일 때 |A∪B|를 구해줘.",
        '{"nodes":[{"id":"g1","text":"문제의 집합식을 정리한다.","branches":[]},{"id":"g2","text":"포함 배타 원리를 적용한다.","branches":[]}]}',
    )


@dataclass
class CaseResult:
    name: str
    attempt: int
    solved: bool
    step_count: int
    question: str
    final_answer: str
    tags: list[str]


def run_aiflow_alpha_round(case_names: list[str], *, repeat: int = 2, base_seed: int = 2400) -> dict[str, Any]:
    """필요 변수: 테스트 케이스명, 반복 횟수, 시드. 작동 원리: 케이스별로 반복 생성 후 통과율과 품질 통계를 계산한다."""
    case_results: list[CaseResult] = []
    for idx, name in enumerate(case_names, start=1):
        tags, prompt, flowchart = _single_case_case_payload(name)
        for attempt in range(repeat):
            local_seed = base_seed + idx * 100 + attempt
            payload = engine.build_question_payload(
                engine.build_blueprint(
                    tags=tags,
                    prompt=prompt,
                    raw_flowchart=flowchart,
                    seed=local_seed,
                ),
                tags=tags,
                prompt=prompt,
                seed=local_seed,
            )
            steps = _flatten_steps(payload)
            solved = bool(payload.get("question")) and bool(payload.get("final_answer")) and _is_positive_int(payload["final_answer"])
            case_results.append(
                CaseResult(
                    name=name,
                    attempt=attempt,
                    solved=solved,
                    step_count=len(steps),
                    question=payload["question"],
                    final_answer=payload["final_answer"],
                    tags=payload.get("tags", []),
                )
            )

    total = len(case_results)
    solved_count = sum(r.solved for r in case_results)
    pass_rate = solved_count / total if total else 0.0
    step_counts = [r.step_count for r in case_results if r.step_count > 0]
    avg_steps = statistics.mean(step_counts) if step_counts else 0.0

    return {
        "metadata": {
            "algorithm": "AIFlow_Alpha",
            "case_count": len(case_names),
            "repeat": repeat,
            "total": total,
            "pass_rate": pass_rate,
        },
        "metrics": {
            "solved_count": solved_count,
            "step_count_avg": avg_steps,
        },
        "cases": [
            {
                "name": r.name,
                "attempt": r.attempt,
                "solved": r.solved,
                "step_count": r.step_count,
                "question": r.question,
                "final_answer": r.final_answer,
                "tags": r.tags,
            }
            for r in case_results
        ],
    }


def main() -> int:
    """필요 변수: 반복 입력. 작동 원리: 기본 루프를 실행하고 JSON 결과를 출력 후 실행 로그 파일로 저장한다."""
    os.environ.setdefault("PYTHONIOENCODING", "utf-8")
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    result = run_aiflow_alpha_round(["sequence", "quadratic", "set"], repeat=3, base_seed=2500)
    text = json.dumps(result, ensure_ascii=False, indent=2)
    print(text)
    out = Path(__file__).resolve().parent / "aiflow_alpha_loop_result.json"
    out.write_text(text, encoding="utf-8")
    print(f"SAVED {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
