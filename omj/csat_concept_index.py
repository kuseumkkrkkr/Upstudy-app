from __future__ import annotations

import json
import threading
import time
from pathlib import Path
from typing import Dict, Iterable, List, Mapping, Sequence


_INDEX_PATH = Path(__file__).resolve().parent / "data" / "csat_concept_index" / "v1.json"
_CACHE_TTL_SECONDS = 60.0
_cache_lock = threading.Lock()
_cached_mtime_ns: int | None = None
_cached_until = 0.0
_cached_data: Dict[str, object] = {}


def normalize_csat_tag(tag: str) -> str:
    """필요 변수: 서비스 개념 태그. 작동 원리: 샵·공백·대소문자 차이를 제거해 수능 인덱스 키를 통일한다."""
    return str(tag or "").strip().lstrip("#").strip().casefold()


def _read_index() -> Dict[str, object]:
    """필요 변수: UTF-8 JSON 인덱스 파일. 작동 원리: 출처와 문항별 복수 개념 근거를 메모리 객체로 읽는다."""
    with _INDEX_PATH.open("r", encoding="utf-8") as handle:
        raw = json.load(handle)
    if not isinstance(raw, dict) or not isinstance(raw.get("combinations"), list):
        raise ValueError("invalid CSAT concept index schema")
    return raw


def load_csat_concept_index() -> Mapping[str, object]:
    """필요 변수: 인덱스 파일 수정 시각. 작동 원리: 60초 TTL과 mtime으로 다중 요청의 파일 접근과 잠금 경합을 줄인다."""
    global _cached_data, _cached_mtime_ns, _cached_until
    now = time.monotonic()
    if _cached_data and now < _cached_until:
        return _cached_data
    with _cache_lock:
        now = time.monotonic()
        if _cached_data and now < _cached_until:
            return _cached_data
        mtime_ns = _INDEX_PATH.stat().st_mtime_ns
        if not _cached_data or _cached_mtime_ns != mtime_ns:
            _cached_data = _read_index()
            _cached_mtime_ns = mtime_ns
        _cached_until = now + _CACHE_TTL_SECONDS
        return _cached_data


def get_csat_concept_difficulty(tags: Iterable[str]) -> Dict[str, float]:
    """필요 변수: 사용자가 선택한 태그. 작동 원리: 실제 변별 문항에 등장한 태그만 문항 티어의 가중 평균으로 점수화한다."""
    selected = {normalize_csat_tag(tag) for tag in tags if normalize_csat_tag(tag)}
    totals: Dict[str, float] = {}
    weights: Dict[str, float] = {}
    for raw in load_csat_concept_index().get("combinations", []):
        if not isinstance(raw, dict):
            continue
        tier = float(raw.get("difficulty_tier") or 0)
        source_count = max(1, len(raw.get("source_ids") or []))
        weight = 1.0 + min(source_count - 1, 2) * 0.25
        for tag in raw.get("tags") or []:
            normalized = normalize_csat_tag(tag)
            if normalized not in selected:
                continue
            totals[normalized] = totals.get(normalized, 0.0) + tier * weight
            weights[normalized] = weights.get(normalized, 0.0) + weight
    return {tag: round(totals[tag] / weights[tag], 3) for tag in totals}


def get_csat_hard_combinations(tags: Iterable[str]) -> List[List[str]]:
    """필요 변수: 선택 태그 집합. 작동 원리: 두 개 이상 겹치는 실제 수능 결합을 난이도·겹침 수·근거 수 순으로 반환한다."""
    original_by_normalized = {
        normalize_csat_tag(tag): str(tag).strip()
        for tag in tags
        if normalize_csat_tag(tag)
    }
    ranked: List[tuple[tuple[float, int, int], List[str]]] = []
    seen: set[tuple[str, ...]] = set()
    for raw in load_csat_concept_index().get("combinations", []):
        if not isinstance(raw, dict):
            continue
        overlap = [
            original_by_normalized[normalize_csat_tag(tag)]
            for tag in raw.get("tags") or []
            if normalize_csat_tag(tag) in original_by_normalized
        ]
        normalized_overlap = tuple(dict.fromkeys(normalize_csat_tag(tag) for tag in overlap))
        if len(normalized_overlap) < 2 or normalized_overlap in seen:
            continue
        seen.add(normalized_overlap)
        source_count = len(raw.get("source_ids") or [])
        rank = (float(raw.get("difficulty_tier") or 0), len(overlap), source_count)
        ranked.append((rank, [original_by_normalized[tag] for tag in normalized_overlap]))
    ranked.sort(key=lambda item: item[0], reverse=True)
    return [combination for _, combination in ranked]


def csat_index_metadata() -> Dict[str, object]:
    """필요 변수: 현재 인덱스 데이터. 작동 원리: 운영 로그와 시험지 재현에 필요한 버전·출처·조합 수만 반환한다."""
    data = load_csat_concept_index()
    sources = data.get("sources") or []
    combinations = data.get("combinations") or []
    return {
        "version": data.get("version"),
        "source_count": len(sources) if isinstance(sources, Sequence) else 0,
        "combination_count": len(combinations) if isinstance(combinations, Sequence) else 0,
    }
