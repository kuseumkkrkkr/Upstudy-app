from __future__ import annotations

import argparse
import json
import os
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


BASE_DIR = Path(__file__).resolve().parent / "aiflow_alpha_knowledge"


def _load_json(name: str) -> dict[str, Any]:
    """필요 변수: 파일명. 작동 원리: 스크립트 폴더 기준 JSON 파일을 UTF-8로 읽어 딕셔너리로 반환한다."""
    path = BASE_DIR / name
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


@dataclass
class Knowledge:
    concept_graph: dict[str, Any]
    rule_library: dict[str, Any]
    template_pack: dict[str, Any]
    validation_contract: dict[str, Any]


def _normalize_tag(raw: str) -> str:
    """필요 변수: 사용자 태그 문자열. 작동 원리: # 제거/공백 정리로 검색용 형태로 통일한다."""
    return raw.strip().lstrip("#")


def load_knowledge() -> Knowledge:
    """필요 변수: 네 개의 JSON 파일. 작동 원리: 지식 레이어를 한 번에 로드해 메모리 객체로 반환한다."""
    return Knowledge(
        concept_graph=_load_json("concept_graph.json"),
        rule_library=_load_json("rule_library.json"),
        template_pack=_load_json("template_pack.json"),
        validation_contract=_load_json("validation_contract.json"),
    )


def validate_minimum_schema(knowledge: Knowledge) -> list[str]:
    """필요 변수: 지식 객체. 작동 원리: 핵심 키 존재 여부만 검사해 초벌 스키마 누락을 빠르게 잡는다."""
    issues: list[str] = []
    required = {
        "concept_graph": [("nodes", list)],
        "rule_library": [("rules", list)],
        "template_pack": [("templates", list)],
        "validation_contract": [("validation", dict)],
    }
    payloads = {
        "concept_graph": knowledge.concept_graph,
        "rule_library": knowledge.rule_library,
        "template_pack": knowledge.template_pack,
        "validation_contract": knowledge.validation_contract,
    }
    for name, fields in required.items():
        payload = payloads[name]
        for field, typ in fields:
            if field not in payload:
                issues.append(f"{name}.{field} missing")
                continue
            if not isinstance(payload[field], typ):
                issues.append(f"{name}.{field} should be {typ.__name__}")
    return issues


def recommend_candidates(knowledge: Knowledge, tags: list[str], *, top_k: int = 3) -> dict[str, Any]:
    """필요 변수: 정규화 태그와 템플릿/규칙. 작동 원리: 태그 일치 비율로 적합 템플릿을 선별한다."""
    norm_tags = {_normalize_tag(t) for t in tags}
    template_scores: list[tuple[int, dict[str, Any]]] = []

    for template in knowledge.template_pack.get("templates", []):
        t_required = set(template.get("constraints", {}).get("requires_rules", []))
        requires_tags = set()
        for rule_id in t_required:
            for rule in knowledge.rule_library.get("rules", []):
                if rule.get("rule_id") == rule_id:
                    requires_tags.update(rule.get("conditions", {}).get("tags", []))
        match = len(norm_tags & set(template.get("prompt", "" ).split()) )
        match += len(norm_tags & requires_tags) * 3
        # 필요한 도메인 태그도 포함되면 가산점
        domain = template.get("domain")
        if domain:
            for node in knowledge.concept_graph.get("nodes", []):
                if node.get("id") == domain:
                    match += len(norm_tags & set(node.get("topics", [])))
        template_scores.append((match, template))

    template_scores.sort(key=lambda item: item[0], reverse=True)
    selected = []
    for score, template in template_scores[:top_k]:
        selected.append({
            "score": score,
            "template_id": template.get("template_id"),
            "problem_type": template.get("problem_type"),
            "prompt": template.get("prompt"),
            "domain": template.get("domain"),
        })
    return {"input_tags": sorted(norm_tags), "candidates": selected}


def main() -> int:
    """필요 변수: CLI 인자. 작동 원리: 지식 로드/검증/샘플 추천을 실행하고 결과를 JSON으로 출력한다."""
    os.environ.setdefault("PYTHONIOENCODING", "utf-8")
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")

    parser = argparse.ArgumentParser(
        description="AIFlow_Alpha 지식 데이터 초벌 로더/검증"
    )
    parser.add_argument("--tag", action="append", default=["#수열", "#등차수열"], help="문항 태그")
    parser.add_argument("--dry-run", action="store_true", help="샘플 추천만 출력")
    args = parser.parse_args()

    knowledge = load_knowledge()
    issues = validate_minimum_schema(knowledge)
    if issues:
        print(json.dumps({"status": "schema_error", "issues": issues}, ensure_ascii=False, indent=2))
        return 2

    result = recommend_candidates(knowledge, args.tag)
    print(json.dumps({"status": "ok", "result": result}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
