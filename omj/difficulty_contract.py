from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Mapping


@dataclass(frozen=True)
class DifficultyContract:
    """티어별 생성 구조와 기존 계산 난도 점수의 분리 계약이다."""

    tier: int
    solves_count: int
    strategy_level: int
    branch_conditions: int


DIFFICULTY_CONTRACTS = {
    1: DifficultyContract(1, 2, 1, 0),
    2: DifficultyContract(2, 3, 1, 0),
    3: DifficultyContract(3, 4, 2, 1),
    4: DifficultyContract(4, 5, 2, 1),
    5: DifficultyContract(5, 6, 3, 2),
}


def clamp_difficulty_tier(value: Any, default: int = 3) -> int:
    """필요 변수: 외부 티어 값과 기본값. 작동 원리: 정수 변환 실패를 흡수하고 운영 범위 1~5로 제한한다."""
    try:
        parsed = int(value)
    except (TypeError, ValueError):
        parsed = int(default)
    return max(1, min(5, parsed))


def infer_tier_from_contract(
    solves_count: Any,
    strategy_level: Any,
    branch_conditions: Any = None,
) -> tuple[int, str]:
    """필요 변수: 풀이 수·전략 수준·선택적 분기 수. 작동 원리: 정확한 계약을 우선하고 가중 거리로 가장 가까운 티어와 근거를 반환한다."""
    solves = max(0, int(solves_count or 0))
    strategy = max(0, int(strategy_level or 0))
    branches = None if branch_conditions is None else max(0, int(branch_conditions or 0))
    for contract in DIFFICULTY_CONTRACTS.values():
        branch_matches = branches is None or branches == contract.branch_conditions
        if solves == contract.solves_count and strategy == contract.strategy_level and branch_matches:
            return contract.tier, "contract_exact"
    best = min(
        DIFFICULTY_CONTRACTS.values(),
        key=lambda contract: (
            abs(contract.solves_count - solves) * 2
            + abs(contract.strategy_level - strategy) * 3
            + (abs(contract.branch_conditions - branches) * 2 if branches is not None else 0),
            contract.tier,
        ),
    )
    return best.tier, "contract_nearest"


def resolve_difficulty_score(info: Mapping[str, Any], default: int = 1) -> int:
    """필요 변수: 문제 info. 작동 원리: 신규 전용 점수를 우선하고 구형 difficulty 점수를 호환 값으로 사용한다."""
    raw = info.get("difficulty_score")
    if raw is None:
        raw = info.get("difficulty")
    try:
        return max(1, int(raw))
    except (TypeError, ValueError):
        return max(1, int(default))


def resolve_difficulty_tier(
    info: Mapping[str, Any],
    *,
    solves_count: Any = None,
    strategy_level: Any = None,
    branch_conditions: Any = None,
    default: int = 3,
) -> tuple[int, str]:
    """필요 변수: 문제 info와 선택적 구조 값. 작동 원리: 명시 티어를 우선하고 없으면 생성 구조로 복원한다."""
    explicit = info.get("difficulty_tier")
    if explicit is not None:
        return clamp_difficulty_tier(explicit, default), "explicit"
    if solves_count is not None and strategy_level is not None:
        return infer_tier_from_contract(solves_count, strategy_level, branch_conditions)
    return clamp_difficulty_tier(default), "default"
