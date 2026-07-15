from __future__ import annotations

from typing import Any


def content_to_text(value: Any) -> str:
    """Normalize quest_title-like structures to plain text."""
    if value is None:
        return ""
    if isinstance(value, str):
        return value.strip()
    if isinstance(value, dict):
        blocks = value.get("blocks")
        if isinstance(blocks, list):
            chunks: list[str] = []
            for block in blocks:
                if isinstance(block, dict):
                    text = block.get("content")
                    if isinstance(text, str) and text.strip():
                        chunks.append(text.strip())
            return " ".join(chunks).strip()
        return ""
    if isinstance(value, list):
        chunks = [content_to_text(item) for item in value]
        return " ".join([c for c in chunks if c]).strip()
    return str(value).strip()


def normalize_hash_tags(quest: dict[str, Any]) -> list[str]:
    data = (quest.get("data") or {}) if isinstance(quest, dict) else {}
    info = (quest.get("info") or {}) if isinstance(quest, dict) else {}
    candidates = [data.get("hash_tag"), data.get("hash_tags"), info.get("hash_tag"), info.get("hash_tags")]

    tags: list[str] = []
    for value in candidates:
        if isinstance(value, list):
            for item in value:
                text = str(item).strip()
                if text and text not in tags:
                    tags.append(text)
    return tags


def quest_title_text(quest: dict[str, Any]) -> str:
    data = (quest.get("data") or {}) if isinstance(quest, dict) else {}
    return content_to_text(data.get("quest_title"))


def normalize_difficulty_tier(quest: dict[str, Any], default_tier: int = 3) -> int:
    """필요 변수: 문제 응답. 작동 원리: 분리된 difficulty_tier만 우선 사용하고 구형 응답은 마지막 호환값으로 제한한다."""
    info = (quest.get("info") or {}) if isinstance(quest, dict) else {}
    data = (quest.get("data") or {}) if isinstance(quest, dict) else {}
    raw = info.get("difficulty_tier")
    if raw is None:
        raw = data.get("difficulty_tier")
    if raw is None:
        raw = info.get("difficulty")
    try:
        tier = int(raw)
    except Exception:
        tier = default_tier
    return max(1, min(5, tier))


def normalize_seed(quest: dict[str, Any]) -> int | None:
    data = (quest.get("data") or {}) if isinstance(quest, dict) else {}
    raw = data.get("seed")
    try:
        return int(raw) if raw is not None else None
    except Exception:
        return None


def enrich_quest_search_item(quest: dict[str, Any]) -> dict[str, Any]:
    out = dict(quest)
    out["quest_title_text"] = quest_title_text(quest)
    out["hash_tags"] = normalize_hash_tags(quest)
    out["difficulty_tier"] = normalize_difficulty_tier(quest)
    out["seed"] = normalize_seed(quest)
    return out
