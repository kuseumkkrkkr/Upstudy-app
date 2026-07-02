"""Challenge selector — selects challenges based on policy and student state.

Algorithm (non-AI, rule-based):
1. Filter out modules already in curriculum
2. Filter by difficulty (student OVR ±1 range)
3. Prioritize tag diversity across focus_tags
4. Select 3~5 challenges (min 3 preferred, but <3 is OK)
5. If insufficient, return whatever is available

Reference: docs/COURSE_BUILDER_V2_PLAN.md §3.6
"""
from __future__ import annotations

from typing import Any, Optional

from domain.course.v2_models import (
    ChallengePolicy,
    CourseModule,
    CourseModuleType,
    CourseV2,
)


# ---------------------------------------------------------------------------
# Core selection
# ---------------------------------------------------------------------------


def select_challenges(
    course: CourseV2,
    student_state: dict[str, Any],
    curriculum_module_ids: Optional[set[str]] = None,
) -> list[CourseModule]:
    """Auto-select challenge modules from a course based on student state.

    Args:
        course: the CourseV2 containing candidate modules.
        student_state: dict with keys:
            - ovr (int): student overall readiness score (0-10 scale)
            - completed_module_ids (list[str]): modules already completed
        curriculum_module_ids: set of module ids already assigned to curriculum.
            If None, extracts from any curriculum_group children.

    Returns:
        List of selected CourseModule challenge candidates (3~5 items).
    """
    policy = course.challenge_policy
    ovr = int(student_state.get("ovr", course.target_ovr))
    completed_ids = set(student_state.get("completed_module_ids", []))

    if curriculum_module_ids is None:
        curriculum_module_ids = _extract_curriculum_module_ids(course)

    # 1. Base filter: problem_solve modules not in curriculum and not completed
    available = [
        m for m in course.modules
        if m.type == CourseModuleType.problem_solve
        and m.id not in curriculum_module_ids
        and m.id not in completed_ids
    ]

    # 2. Difficulty filter: OVR ±1 range
    # Map difficulty string to numeric tier if available
    filtered = _filter_by_difficulty(available, ovr)

    # 3. Tag diversity selection (use state["tags"] or default to module title keywords)
    selected = _diversify_by_tags(filtered, min_count=policy.daily_count, max_count=policy.weekly_count)

    return selected


def _extract_curriculum_module_ids(course: CourseV2) -> set[str]:
    """Extract module ids that are already part of curriculum_group children."""
    ids: set[str] = set()
    for m in course.modules:
        if m.type == CourseModuleType.curriculum_group and m.children:
            for child in m.children:
                ids.add(child.id)
                # Also include grandchildren (day -> actual modules)
                if child.children:
                    for grandchild in child.children:
                        ids.add(grandchild.id)
    return ids


def _difficulty_tier(module: CourseModule) -> int:
    """Extract numeric difficulty tier from module state or default to medium (3)."""
    if module.state and "difficulty_tier" in module.state:
        return int(module.state["difficulty_tier"])
    # Try to infer from difficulty string (stored in state, not a direct field)
    diff_map = {"easy": 2, "medium": 3, "hard": 4, "very_hard": 5}
    if module.state and "difficulty" in module.state:
        return diff_map.get(str(module.state["difficulty"]).lower(), 3)
    return 3  # default medium


def _filter_by_difficulty(modules: list[CourseModule], ovr: int) -> list[CourseModule]:
    """Filter modules whose difficulty is within OVR ±1 range.

    OVR is on a 0-10 scale; difficulty tiers are 1-5.
    We map OVR to tier by dividing by 2.
    """
    target_tier = max(1, min(5, ovr // 2))
    min_tier = max(1, target_tier - 1)
    max_tier = min(5, target_tier + 1)

    return [m for m in modules if min_tier <= _difficulty_tier(m) <= max_tier]


def _module_tags(module: CourseModule) -> list[str]:
    """Extract tags from module state, or infer from title."""
    if module.state and "tags" in module.state:
        tags = module.state["tags"]
        if isinstance(tags, list):
            return tags
    # Fallback: extract keywords from title
    return [module.title.split()[0].lower()] if module.title else ["untagged"]


def _diversify_by_tags(
    modules: list[CourseModule],
    min_count: int = 3,
    max_count: int = 5,
) -> list[CourseModule]:
    """Select modules prioritizing tag diversity.

    Strategy:
    - Group modules by their primary focus tag (first tag in tags list)
    - Round-robin pick one from each tag group until max_count
    - If still below min_count, pick additional from largest groups
    """
    if not modules:
        return []

    # Group by primary tag
    tag_groups: dict[str, list[CourseModule]] = {}
    for m in modules:
        primary_tag = _module_tags(m)[0]
        tag_groups.setdefault(primary_tag, []).append(m)

    selected: list[CourseModule] = []
    used_ids: set[str] = set()

    # Round-robin across tag groups
    round_idx = 0
    while len(selected) < max_count:
        added_in_round = 0
        for tag, group in tag_groups.items():
            # Pick the module at round_idx from this group if available
            if round_idx < len(group):
                candidate = group[round_idx]
                if candidate.id not in used_ids:
                    selected.append(candidate)
                    used_ids.add(candidate.id)
                    added_in_round += 1
                    if len(selected) >= max_count:
                        break
        if added_in_round == 0:
            break  # No more modules to pick
        round_idx += 1

    # If below min_count, fill from remaining modules
    if len(selected) < min_count:
        remaining = [m for m in modules if m.id not in used_ids]
        for m in remaining:
            selected.append(m)
            used_ids.add(m.id)
            if len(selected) >= min_count:
                break

    return selected


# ---------------------------------------------------------------------------
# Challenge group builder
# ---------------------------------------------------------------------------


def build_challenge_group_module(
    course: CourseV2,
    student_state: dict[str, Any],
) -> Optional[CourseModule]:
    """Build a challenge_group module containing auto-selected challenges.

    Returns None if no challenges are available.
    """
    selected = select_challenges(course, student_state)
    if not selected:
        return None

    return CourseModule(
        id=f"{course.id}_challenges",
        type=CourseModuleType.challenge_group,
        title="도전과제",
        description=f"{len(selected)}개의 도전과제가 선택되었습니다.",
        position=0,  # caller should re-assign
        estimated_minutes=sum(m.estimated_minutes for m in selected),
        children=[m.id for m in selected],
        state={
            "selected_count": len(selected),
            "daily_target": course.challenge_policy.daily_count,
            "weekly_target": course.challenge_policy.weekly_count,
            "auto_generated": course.challenge_policy.auto_generate,
        },
    )
