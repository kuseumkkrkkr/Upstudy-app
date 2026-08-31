from __future__ import annotations

import json
import random
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from k_wolfram_alpha_dsl import _normalize_list


_BASE = Path(__file__).resolve().parent / "k_alpha"
_GRAPH_PATH = _BASE / "math_knowledge_graph.json"
_RULE_PATH = _BASE / "math_rule_library.json"
_TEMPLATE_PATH = _BASE / "math_template_pack.json"
_VALIDATION_PATH = _BASE / "validation_contract.json"


@dataclass
class _Knowledge:
    """필요 변수: 노드/규칙/템플릿/검증 계약.
    작동 원리: 검색 엔진에서 반복 사용되는 원본 데이터를 한 번만 메모리에 올린다."""

    graph: dict[str, Any]
    rules: dict[str, Any]
    templates: dict[str, Any]
    validation: dict[str, Any]


class KAlphaKnowledgeEngine:
    """필요 변수: 지식 JSON 경로.
    작동 원리: 학년, 태그, 규칙 중심으로 템플릿/룰을 인덱싱해 후보를 빠르게 반환한다."""

    def __init__(self) -> None:
        self._db = self._load()
        self._template_index = self._build_template_index(self._db.templates)

    def _load(self) -> _Knowledge:
        """필요 변수: 파일 경로 상수.
        작동 원리: 4개 JSON을 UTF-8로 읽고 누락 필드를 기본값으로 보완해 런타임 실패를 줄인다."""
        def _read(path: Path, fallback: dict[str, Any]) -> dict[str, Any]:
            if not path.exists():
                return fallback
            with path.open("r", encoding="utf-8") as f:
                return json.load(f)

        return _Knowledge(
            graph=_read(_GRAPH_PATH, {"nodes": []}),
            rules=_read(_RULE_PATH, {"rules": []}),
            templates=_read(_TEMPLATE_PATH, {"templates": []}),
            validation=_read(_VALIDATION_PATH, {"validation": {}}),
        )

    def _build_template_index(self, templates: dict[str, Any]) -> dict[str, list[dict[str, Any]]]:
        """필요 변수: 템플릿 리스트.
        작동 원리: 문제유형 단위 인덱스를 만들어 특정 유형 요청 시 필터 비용을 줄인다."""
        idx: dict[str, list[dict[str, Any]]] = {}
        for tpl in templates.get("templates", []):
            if not isinstance(tpl, dict):
                continue
            q_type = str(tpl.get("problem_type", "unknown"))
            idx.setdefault(q_type, []).append(tpl)
        return idx

    def get_rules(self) -> list[dict[str, Any]]:
        """필요 변수: 캐시된 룰 목록.
        작동 원리: 규칙 검증/재사용 단계에서 최신 룰 데이터 접근점을 제공한다."""
        return list(self._db.rules.get("rules", []))

    def search_templates(
        self,
        *,
        tags: list[str] | None = None,
        question_type: str | None = None,
        grade_code: int | None = None,
        min_grade_code: int | None = None,
        top_k: int = 10,
    ) -> list[dict[str, Any]]:
        """필요 변수: 태그/문항유형/학년.
        작동 원리: 태그 포함도와 규칙 존재성을 가중치로 정렬하고,
        학년 범위가 겹치는 템플릿만 반환한다."""
        normalized_tags = set(_normalize_list(tags))
        base = self._template_index.get(question_type or "sequence", self._db.templates.get("templates", []))
        candidates: list[tuple[int, dict[str, Any]]] = []
        min_code = 1 if min_grade_code is None else max(1, min(9, int(min_grade_code)))
        max_code = 9 if grade_code is None else max(1, min(9, int(grade_code)))
        for tpl in base:
            if not isinstance(tpl, dict):
                continue

            gmin = int(tpl.get("grade_min", 1))
            gmax = int(tpl.get("grade_max", 9))
            if gmax < min_code or gmin > max_code:
                continue
            tpl_tags = set(_normalize_list(tpl.get("required_rules")))
            score = 0
            if normalized_tags:
                score += len(normalized_tags & tpl_tags)
            else:
                score += 1
            score += 1 if tpl.get("required_rules") else 0
            candidates.append((score, tpl))

        if not candidates:
            return []
        candidates.sort(key=lambda x: x[0], reverse=True)
        return [tpl for _, tpl in candidates[:top_k]]

    def sample_template(self, templates: list[dict[str, Any]], rng: random.Random | None = None) -> dict[str, Any] | None:
        """필요 변수: 후보 템플릿 목록, 난수기.
        작동 원리: 우선순위를 유지하면서도 반복 실행 시 다양성을 확보하기 위해 랜덤 샘플링한다."""
        if not templates:
            return None
        source = rng or random
        return dict(source.choice(templates))

    def get_validation_contract(self) -> dict[str, Any]:
        """필요 변수: 유효성 계약.
        작동 원리: 채점기와 생성기가 공통 규약을 참조해 편차를 줄인다."""
        return dict(self._db.validation.get("validation", {}))
