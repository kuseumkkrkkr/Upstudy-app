from __future__ import annotations

import random
from dataclasses import dataclass
from typing import Any

from k_wolfram_alpha_dsl import KAlphaProblemProgram, KAlphaRuleRef, KAlphaStep
from k_wolfram_alpha_knowledge_search import KAlphaKnowledgeEngine


@dataclass
class GeneratedProblem:
    """필요 변수: 문제 본문, DSL 프로그램, 태그.
    작동 원리: 생성기 입력/출력 파이프라인에서 단일 계약 객체로 전달하기 위해 통합한다."""

    prompt: str
    program: KAlphaProblemProgram
    tags: list[str]


def _pick_values_by_template(template: dict[str, Any], rng: random.Random) -> dict[str, Any]:
    """필요 변수: 템플릿 슬롯, 난수기.
    작동 원리: 초1~중3 범위에서 수치가 과도하게 커지지 않도록 상한을 둔 샘플을 생성한다."""
    slots = template.get("slots", [])
    out: dict[str, Any] = {}
    for slot in slots:
        if slot == "a1":
            out[slot] = rng.randint(-9, 12)
        elif slot == "d":
            out[slot] = rng.randint(-4, 5) or 2
        elif slot == "n":
            out[slot] = rng.randint(2, 6)
        elif slot == "A":
            out[slot] = rng.randint(10, 30)
        elif slot == "B":
            out[slot] = rng.randint(8, 28)
        elif slot == "C":
            a = out.get("A", rng.randint(10, 30))
            b = out.get("B", rng.randint(8, 28))
            out[slot] = rng.randint(1, min(a, b))
        elif slot == "a":
            out[slot] = rng.randint(1, 9)
        elif slot == "b":
            out[slot] = rng.randint(1, 9)
        elif slot == "c":
            out[slot] = rng.randint(-6, 6)
        else:
            out[slot] = rng.randint(1, 5)
    return out


def _build_steps(template: dict[str, Any]) -> list[KAlphaStep]:
    """필요 변수: 템플릿의 단계 힌트.
    작동 원리: 루프 로그 및 피드백에서 동일한 단계 구조를 보존한다."""
    return [
        KAlphaStep(
            step_id=f"s{i+1}",
            goal=hint,
            rule_ids=_extract_rule_refs(template),
            hints=[hint],
        )
        for i, hint in enumerate(template.get("steps_hint", []))
    ]


def _extract_rule_refs(template: dict[str, Any]) -> list[str]:
    """필요 변수: 템플릿 메타데이터.
    작동 원리: 룰 ID를 추출해 채점/재현성에 필요한 근거 사슬을 채택한다."""
    return list(template.get("required_rules", []))


def _select_grade_code(rng: random.Random, lower: int, upper: int) -> int:
    """필요 변수: 난수기/학년 최소/최대.
    작동 원리: [lower, upper] 범위에서 균등 분포로 초/중 범위 학년을 선택한다."""
    lower = max(1, min(9, int(lower)))
    upper = max(1, min(9, int(upper)))
    if lower > upper:
        lower, upper = upper, lower
    return rng.randint(lower, upper)


def _pick_school_grade(
    rng: random.Random,
    tpl: dict[str, Any],
    *,
    min_grade: int,
    max_grade: int,
) -> int:
    """필요 변수: 템플릿, 요청 최소/최대 학년.
    작동 원리: 템플릿의 grade_min/max와 요청 범위를 교집합으로 만든 뒤 균등 샘플링한다."""
    gmin = max(1, min(9, int(tpl.get("grade_min", min_grade))))
    gmax = max(1, min(9, int(tpl.get("grade_max", max_grade))))
    scope_min = max(1, min(9, int(min_grade)))
    scope_max = max(1, min(9, int(max_grade)))
    lower = max(gmin, scope_min)
    upper = min(gmax, scope_max)
    if lower > upper:
        # 템플릿 범위가 요청 범위 밖이면 하한을 안전하게 clamp
        return _select_grade_code(rng, scope_min, scope_max)
    return rng.randint(lower, upper)


def generate_problem(
    *,
    knowledge: KAlphaKnowledgeEngine,
    tags: list[str],
    question_type: str,
    seed: int,
    min_grade: int = 1,
    max_grade: int = 9,
    problem_id: str,
) -> GeneratedProblem:
    """필요 변수: 검색엔진, 태그, 유형, 시드.
    작동 원리: 조건을 충족하는 템플릿을 뽑고, 슬롯을 채운 뒤 DSL을 생성해 반환한다."""
    rng = random.Random(seed)
    templates = knowledge.search_templates(
        tags=tags,
        question_type=question_type,
        min_grade_code=min_grade,
        grade_code=max_grade,
        top_k=20,
    )
    if not templates:
        raise RuntimeError("no template found for requested filter")

    tpl = knowledge.sample_template(templates, rng)
    if tpl is None:
        raise RuntimeError("template sampling returned None")

    values = _pick_values_by_template(tpl, rng)
    prompt_template = str(tpl.get("template", ""))
    prompt = prompt_template.format(**values)
    answer_formula = str(tpl.get("answer_formula", "0"))
    checks = dict(tpl.get("expected_check", {}))

    # 기본 정수 정답 계산을 위해 안전한 산술 평가를 재사용한다.
    from k_wolfram_alpha_grader import _eval_expr

    expected = _eval_expr(answer_formula, values)
    expected_text = str(int(expected)) if expected.denominator == 1 else str(expected.numerator / expected.denominator)
    school_grade = _pick_school_grade(
        rng,
        tpl,
        min_grade=min_grade,
        max_grade=max_grade,
    )

    # 규칙 기반 채점은 루프 재현성과 감사에 쓰므로 메타데이터로 저장.
    rule_refs = [KAlphaRuleRef(rule_id=str(r)) for r in _extract_rule_refs(tpl)]
    program = KAlphaProblemProgram(
        schema_version="k-alpha-1.0",
        problem_id=problem_id,
        prompt=prompt,
        question_type=str(tpl.get("problem_type", question_type)),
        school_grade_code=school_grade,
        tags=tags,
        rule_refs=rule_refs,
        vars=values,
        answer_formula=answer_formula,
        expected_answer=expected_text,
        checks=checks,
        steps=_build_steps(tpl),
        metadata={
            "template_id": tpl.get("template_id"),
            "topic": tpl.get("topic"),
            "domain_node": tpl.get("domain_node"),
        },
    )
    return GeneratedProblem(prompt=prompt, program=program, tags=tags)
