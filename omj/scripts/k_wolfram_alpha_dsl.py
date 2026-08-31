from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Iterable


@dataclass
class KAlphaStep:
    """필요 변수: 단계 인덱스/목표/규칙 ID 목록/검증 힌트.
    작동 원리: 풀이 과정을 구조화해 생성/검증/피드백에서 재사용 가능한 형태로 보존한다."""

    step_id: str
    goal: str
    rule_ids: list[str] = field(default_factory=list)
    hints: list[str] = field(default_factory=list)


@dataclass
class KAlphaRuleRef:
    """필요 변수: 룰 참조 문자열 목록.
    작동 원리: 외부 지식 DB rule_id만 남겨서 템플릿-문항 간 결합 의존성만 유지한다."""

    rule_id: str
    weight: float = 1.0


@dataclass
class KAlphaProblemProgram:
    """필요 변수: 문제 템플릿 ID, 학교 단위, 변수 사전, 정답/검증식.
    작동 원리: 문제 생성기와 채점기가 동일한 형식(K-울프럼알파 DSL)을 해석해 일관성 있게 동작한다."""

    schema_version: str
    problem_id: str
    prompt: str
    question_type: str
    school_grade_code: int
    tags: list[str]
    rule_refs: list[KAlphaRuleRef]
    vars: dict[str, Any]
    answer_formula: str
    expected_answer: str
    checks: dict[str, Any]
    steps: list[KAlphaStep] = field(default_factory=list)
    metadata: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        """필요 변수: 클래스 속성값. 작동 원리: JSON 직렬화에서 타입 안정성을 위해 리스트/딕셔너리로 변환한다."""
        return {
            "schema_version": self.schema_version,
            "problem_id": self.problem_id,
            "prompt": self.prompt,
            "question_type": self.question_type,
            "school_grade_code": self.school_grade_code,
            "tags": self.tags,
            "rule_refs": [r.__dict__ for r in self.rule_refs],
            "vars": self.vars,
            "answer_formula": self.answer_formula,
            "expected_answer": self.expected_answer,
            "checks": self.checks,
            "steps": [s.__dict__ for s in self.steps],
            "metadata": self.metadata,
        }


def _normalize_list(values: Any) -> list[str]:
    """필요 변수: 입력 태그/배열.
    작동 원리: 공백 제거·중복 제거·빈 값 제거를 거쳐 검색/매칭 품질을 올린다."""
    if not values:
        return []
    if isinstance(values, str):
        return [values]
    normalized: list[str] = []
    seen: set[str] = set()
    for value in values:
        if not isinstance(value, str):
            continue
        token = value.strip()
        if not token or token in seen:
            continue
        seen.add(token)
        normalized.append(token)
    return normalized


def parse_program(raw: dict[str, Any]) -> KAlphaProblemProgram:
    """필요 변수: raw dict.
    작동 원리: 외부 JSON 입력을 KAlphaProblemProgram 객체로 강제 변환해 필수 필드 누락을 조기에 차단한다."""
    return KAlphaProblemProgram(
        schema_version=str(raw.get("schema_version", "k-alpha-1.0")),
        problem_id=str(raw.get("problem_id", "")),
        prompt=str(raw.get("prompt", "")),
        question_type=str(raw.get("question_type", "unknown")),
        school_grade_code=int(raw.get("school_grade_code", 0)),
        tags=_normalize_list(raw.get("tags")),
        rule_refs=[
            KAlphaRuleRef(rule_id=str(item.get("rule_id")), weight=float(item.get("weight", 1.0)))
            for item in raw.get("rule_refs", [])
            if isinstance(item, dict) and item.get("rule_id")
        ],
        vars=dict(raw.get("vars", {}) or {}),
        answer_formula=str(raw.get("answer_formula", "")),
        expected_answer=str(raw.get("expected_answer", "")),
        checks=dict(raw.get("checks", {}) or {}),
        steps=[
            KAlphaStep(
                step_id=str(item.get("step_id", f"s{idx + 1}")),
                goal=str(item.get("goal", "")),
                rule_ids=_normalize_list(item.get("rule_ids")),
                hints=_normalize_list(item.get("hints")),
            )
            for idx, item in enumerate(raw.get("steps", []) if isinstance(raw.get("steps", []), Iterable) else [])
            if isinstance(item, dict)
        ],
        metadata=dict(raw.get("metadata", {}) or {}),
    )
