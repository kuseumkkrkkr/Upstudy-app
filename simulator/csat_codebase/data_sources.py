from __future__ import annotations

from typing import Dict, List

from .config import DEFAULT_TIER_PARAMS, TagCategory, TierParams
from .tag_data import SUBJECT_TAG_RULES


def build_tag_catalog() -> List[TagCategory]:
    categories: List[TagCategory] = []
    for entry in SUBJECT_TAG_RULES:
        if not isinstance(entry, dict):
            continue
        name = str(entry.get("name") or "unknown")
        grade = int(entry.get("grade") or 0)
        tags = entry.get("tags")
        if not isinstance(tags, (list, set, tuple)):
            continue
        normalized = [str(tag) for tag in tags if str(tag).strip()]
        normalized = sorted(set(normalized))
        categories.append(TagCategory(name=name, grade=grade, tags=normalized))
    categories.sort(key=lambda item: (item.grade, item.name))
    all_tags = sorted({tag for category in categories for tag in category.tags})
    if all_tags:
        categories.insert(0, TagCategory(name="전체", grade=0, tags=all_tags))
    return categories


def load_tier_params() -> Dict[int, TierParams]:
    return DEFAULT_TIER_PARAMS.copy()


def estimate_difficulty(tag_count: int, params: TierParams) -> int:
    return int(tag_count + 4 * params.solves_count + 3 * params.branch_conditions + 2 * params.strategy_level)
