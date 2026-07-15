from __future__ import annotations

import json
import os
import sqlite3
import threading
from pathlib import Path
from typing import Dict, Iterable


_index_lock = threading.Lock()
_cached_mtime_ns: int | None = None
_cached_index: Dict[str, float] = {}


def _db_path() -> Path:
    """필요 변수: CODEBASE_DB_PATH 환경 변수. 작동 원리: 운영 설정을 우선하고 없으면 기본 codebases.db를 사용한다."""
    override = os.environ.get("CODEBASE_DB_PATH")
    if override:
        return Path(override)
    return Path(__file__).resolve().parent / "codebases.db"


def normalize_concept_tag(tag: str) -> str:
    """필요 변수: 원본 개념 태그. 작동 원리: 샵·공백·대소문자 차이를 제거해 인덱스 키를 통일한다."""
    return str(tag or "").strip().lstrip("#").strip().casefold()


def _load_index(path: Path) -> Dict[str, float]:
    """필요 변수: 코드베이스 DB 경로. 작동 원리: 태그별 검증 티어 평균을 한 번에 집계해 읽기 전용 인덱스를 만든다."""
    totals: Dict[str, float] = {}
    counts: Dict[str, int] = {}
    connection = sqlite3.connect(f"file:{path.as_posix()}?mode=ro", uri=True)
    try:
        rows = connection.execute(
            "SELECT tags, tier FROM codebases WHERE tier BETWEEN 1 AND 5"
        ).fetchall()
    finally:
        connection.close()
    for raw_tags, raw_tier in rows:
        try:
            tags = json.loads(raw_tags or "[]")
        except (TypeError, json.JSONDecodeError):
            continue
        if not isinstance(tags, list):
            continue
        tier = float(raw_tier)
        for raw_tag in tags:
            tag = normalize_concept_tag(raw_tag)
            if not tag:
                continue
            totals[tag] = totals.get(tag, 0.0) + tier
            counts[tag] = counts.get(tag, 0) + 1
    return {tag: totals[tag] / counts[tag] for tag in totals}


def get_concept_difficulty_index(tags: Iterable[str]) -> Dict[str, float]:
    """필요 변수: 시험지에서 선택한 개념들. 작동 원리: DB 변경 시에만 전체 인덱스를 갱신하고 요청에는 필요한 키만 복사한다."""
    global _cached_mtime_ns, _cached_index
    path = _db_path()
    try:
        mtime_ns = path.stat().st_mtime_ns
    except OSError:
        return {}
    with _index_lock:
        if _cached_mtime_ns != mtime_ns:
            try:
                _cached_index = _load_index(path)
                _cached_mtime_ns = mtime_ns
            except (OSError, sqlite3.Error):
                return {}
        normalized = {normalize_concept_tag(tag) for tag in tags}
        return {tag: _cached_index[tag] for tag in normalized if tag in _cached_index}
