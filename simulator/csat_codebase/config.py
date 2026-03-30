from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, List


@dataclass(frozen=True)
class PromptMode:
    key: str
    title: str


@dataclass(frozen=True)
class TagCategory:
    name: str
    grade: int
    tags: List[str]


@dataclass(frozen=True)
class TierParams:
    solves_count: int
    strategy_level: int
    branch_conditions: int


PROMPT_MODES: List[PromptMode] = [
    PromptMode(key="tag_driven", title="태그 기반 (자동 유형)"),
    PromptMode(key="cubic_strict", title="삼차함수 고정 (엄격)"),
]


DEFAULT_TIER_PARAMS: Dict[int, TierParams] = {
    1: TierParams(solves_count=2, strategy_level=1, branch_conditions=0),
    2: TierParams(solves_count=3, strategy_level=1, branch_conditions=0),
    3: TierParams(solves_count=4, strategy_level=2, branch_conditions=1),
    4: TierParams(solves_count=5, strategy_level=2, branch_conditions=1),
    5: TierParams(solves_count=6, strategy_level=3, branch_conditions=2),
}
