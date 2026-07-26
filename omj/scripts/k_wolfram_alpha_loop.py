from __future__ import annotations

import argparse
import json
from collections import Counter
from datetime import datetime
from pathlib import Path
from typing import Any

from k_wolfram_alpha_knowledge_search import KAlphaKnowledgeEngine
from k_wolfram_alpha_engine import generate_problem
from k_wolfram_alpha_grader import GradingResult, grade_program_answer


def _student_submission_mimic(expected: str, seed: int) -> str:
    """학생 답안 모사.
    필요 변수: expected(정답), seed(난수 시드)
    원리: 홀수 시드에서는 오답을 일부러 만들어 채점 분포를 검증한다."""
    if seed % 2 == 0:
        return expected
    if expected.lstrip("-").isdigit():
        return str(int(expected) + 1)
    if "/" in expected:
        left, right = expected.split("/", 1)
        return f"{left}/{int(right) + 1}" if right.strip().lstrip("-").isdigit() else expected
    try:
        return f"{float(expected) + 1}"
    except Exception:
        return expected


def _extract_allowed_grade_codes(contract: dict[str, Any], *, min_grade: int, max_grade: int) -> set[int]:
    """학년 코드 허용 집합 산출.
    필요 변수: contract, min_grade, max_grade
    원리: contract가 깨져도 동작하도록 숫자 문자열만 파싱하고, 비어 있으면 파라미터 범위를 사용."""
    codes: set[int] = set()
    for value in contract.get("allowed_grade_codes", []):
        try:
            if isinstance(value, int):
                codes.add(int(value))
            else:
                text = str(value).strip()
                if text.isdigit():
                    codes.add(int(text))
        except Exception:
            continue

    if not codes:
        min_code = max(1, min(9, int(min_grade)))
        max_code = max(1, min(9, int(max_grade)))
        if min_code <= max_code:
            return set(range(min_code, max_code + 1))
        return {9}
    return {max(1, min(9, code)) for code in codes}


def run_continuous_generation_grading(
    *,
    case_count: int = 3,
    repeat_per_case: int = 2,
    max_grade: int = 9,
    min_grade: int = 1,
    max_scope_retry: int = 0,
    seed: int = 2026,
) -> dict[str, Any]:
    """문제 생성 이후 항상 채점기를 먼저 통과시켜 결과를 누적한다.
    필요 변수: case_count/repeat_per_case/max_grade/min_grade/seed
    결과: pass/fail/review 비율 및 각 케이스 상세.
    보강: 학년 범위 이탈 케이스는 제한 범위 재샘플 재시도로 한 번 더 보정한다."""
    knowledge = KAlphaKnowledgeEngine()
    contract = knowledge.get_validation_contract()
    allowed_codes = _extract_allowed_grade_codes(
        contract,
        min_grade=min_grade,
        max_grade=max_grade,
    )

    type_cycle = ["sequence", "set", "quadratic", "ratio"]
    total = 0
    pass_count = 0
    review_count = 0
    fail_count = 0
    scope_retry_count = 0
    grade_distribution: dict[int, int] = {i: 0 for i in range(1, 10)}
    question_type_counter: Counter[str] = Counter()
    results: list[dict[str, Any]] = []
    status_counter: Counter[str] = Counter()

    for i in range(case_count):
        q_type = type_cycle[i % len(type_cycle)]
        for attempt in range(repeat_per_case):
            local_seed = seed + i * 10000 + attempt
            need_retry = True
            retry_count = 0
            while need_retry and retry_count <= max_scope_retry:
                total += 1
                retry_count += 1
                problem_id = f"kalpha-{datetime.now().strftime('%Y%m%d%H%M%S')}-{i}-{attempt}-{retry_count}"
                gen = generate_problem(
                    knowledge=knowledge,
                    tags=[],
                    question_type=q_type,
                    min_grade=min_grade,
                    max_grade=max_grade,
                    seed=local_seed + retry_count,
                    problem_id=problem_id,
                )

                grade_scope_ok = gen.program.school_grade_code in allowed_codes and 1 <= gen.program.school_grade_code <= 9
                if not grade_scope_ok:
                    scope_retry_count += 1
                    status = "REVIEW_REQUIRED"
                    if retry_count <= max_scope_retry:
                        need_retry = True
                        continue
                    grade_result = GradingResult(status, 0.0, gen.program.expected_answer, "", "grade_scope_violation")
                else:
                    need_retry = False
                    expected = gen.program.expected_answer
                    submission = _student_submission_mimic(expected, local_seed + retry_count)
                    grade_result = grade_program_answer(gen.program, submission)
                    grade_scope_ok = True

                question_type_counter[q_type] += 1
                status_counter[grade_result.status] += 1
                grade_distribution[gen.program.school_grade_code] = grade_distribution.get(gen.program.school_grade_code, 0) + 1

                if grade_result.status == "PASS":
                    pass_count += 1
                elif grade_result.status == "REVIEW_REQUIRED":
                    review_count += 1
                else:
                    fail_count += 1

                results.append(
                    {
                        "problem_id": gen.program.problem_id,
                        "question_type": gen.program.question_type,
                        "prompt": gen.prompt,
                        "expected": gen.program.expected_answer,
                        "submission": "" if grade_result.status == "REVIEW_REQUIRED" and not grade_scope_ok else _student_submission_mimic(gen.program.expected_answer, local_seed + retry_count),
                        "grade_status": grade_result.status,
                        "grade_score": grade_result.score,
                        "reason": grade_result.reason,
                        "school_grade_code": gen.program.school_grade_code,
                        "retry_count": retry_count,
                    }
                )

                if grade_result.status != "REVIEW_REQUIRED":
                    break

    return {
        "metadata": {
            "case_count": case_count,
            "repeat_per_case": repeat_per_case,
            "total": total,
            "max_grade_code": max_grade,
            "min_grade_code": min_grade,
            "max_scope_retry": max_scope_retry,
            "pass_count": pass_count,
            "fail_count": fail_count,
            "review_count": review_count,
            "pass_rate": pass_count / total if total else 0.0,
            "fail_rate": fail_count / total if total else 0.0,
            "review_rate": review_count / total if total else 0.0,
            "grade_distribution": {str(k): v for k, v in grade_distribution.items()},
            "status_distribution": dict(status_counter),
            "scope_retry_count": scope_retry_count,
            "question_type_counts": dict(question_type_counter),
        },
        "cases": results,
    }


def main() -> int:
    """CLI 진입점.
    필요 변수: argparse 입력 값
    원리: 실행 결과를 JSON으로 저장하고 표시."""
    parser = argparse.ArgumentParser(description="K-울프럼알파 초안-채점 루프")
    parser.add_argument("--case_count", type=int, default=3)
    parser.add_argument("--repeat_per_case", type=int, default=2)
    parser.add_argument("--max_grade", type=int, default=9)
    parser.add_argument("--min_grade", type=int, default=1)
    parser.add_argument("--max_scope_retry", type=int, default=0)
    parser.add_argument("--seed", type=int, default=2026)
    parser.add_argument("--save_path", default="")
    args = parser.parse_args()

    out = run_continuous_generation_grading(
        case_count=args.case_count,
        repeat_per_case=args.repeat_per_case,
        max_grade=args.max_grade,
        min_grade=args.min_grade,
        max_scope_retry=args.max_scope_retry,
        seed=args.seed,
    )
    out["saved_at"] = datetime.now().isoformat(timespec="seconds")
    path = Path(args.save_path) if args.save_path else (Path(__file__).resolve().parent / "k_alpha_loop_result.json")
    path.write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(out, ensure_ascii=False, indent=2))
    print(f"SAVED {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
