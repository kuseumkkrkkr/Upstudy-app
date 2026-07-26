from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPTS_DIR = ROOT / "omj" / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.append(str(SCRIPTS_DIR))

from k_wolfram_alpha_dsl import KAlphaProblemProgram
from k_wolfram_alpha_grader import grade_program_answer
from k_wolfram_alpha_knowledge_search import KAlphaKnowledgeEngine


def _base_program() -> KAlphaProblemProgram:
    return KAlphaProblemProgram(
        schema_version="k-alpha-1.0",
        problem_id="t-1",
        prompt="set test",
        question_type="sequence",
        school_grade_code=9,
        tags=["수열"],
        rule_refs=[],
        vars={"a1": 5, "d": 2, "n": 3},
        answer_formula="a1 + (n - 1) * d",
        expected_answer="9",
        checks={"min": -1000, "max": 1000},
        steps=[],
        metadata={},
    )


def test_grade_program_answer_pass_and_fail() -> None:
    program = _base_program()
    assert grade_program_answer(program, "9").status == "PASS"
    assert grade_program_answer(program, "8").status == "FAIL"


def test_kalpha_search_finds_quadratic_template() -> None:
    knowledge = KAlphaKnowledgeEngine()
    tpl = knowledge.search_templates(question_type="quadratic", grade_code=9, tags=[])
    assert tpl, "quadratic template should exist in kalpha knowledge"


def test_wolfram_loop_smoke_200_cases() -> None:
    """필요 변수: 루프 실행 파라미터.
    작동 원리: 200문항 루프에서 채점이 중단되지 않고 통계를 산출하는지 검증한다."""
    from k_wolfram_alpha_loop import run_continuous_generation_grading

    report = run_continuous_generation_grading(
        case_count=100,
        repeat_per_case=2,
        min_grade=1,
        max_grade=9,
        seed=777,
    )
    assert report["metadata"]["total"] == 200
    assert report["metadata"]["pass_count"] + report["metadata"]["fail_count"] + report["metadata"]["review_count"] == 200
    for case in report["cases"]:
        assert 1 <= int(case.get("school_grade_code", 0)) <= 9


def test_discrete_probability_guard_accepts_clear_candidate() -> None:
    from k_wolfram_handwriting_probability import TextCandidate, resolve_with_discrete_prior

    result = resolve_with_discrete_prior(
        [
            TextCandidate(text="x+1", confidence=0.95, source="vercel"),
            TextCandidate(text="x-1", confidence=0.60, source="texteller"),
        ],
        baseline_text="x+1",
        min_confidence=0.7,
    )
    assert result["status"] == "ACCEPT"
    assert result["text"] == "x+1"
