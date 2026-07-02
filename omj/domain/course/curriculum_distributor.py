"""Curriculum distributor — distributes curriculum items into CourseModule tree.

Algorithm (non-AI, rule-based):
1. Parse student calendar (daily_target_minutes, max_modules_per_day)
2. Distribute modules by estimated_minutes
3. Enforce redistribute_limit; pause on exceed
4. Notify on resume with new schedule

Reference: docs/COURSE_BUILDER_V2_PLAN.md §3.5
"""
from __future__ import annotations

from copy import deepcopy
from dataclasses import dataclass, field
from typing import Any, Optional

from domain.course.v2_models import CourseModule, CourseModuleType, CourseV2


# ---------------------------------------------------------------------------
# Data structures
# ---------------------------------------------------------------------------


@dataclass
class DailySchedule:
    """A single day's schedule slot."""

    day_index: int  # 0-based day offset from course start
    modules: list[CourseModule] = field(default_factory=list)
    total_minutes: int = 0


@dataclass
class DistributionResult:
    """Result of distributing a course into a daily schedule."""

    days: list[DailySchedule]
    redistributed_count: int = 0
    paused: bool = False
    pause_reason: Optional[str] = None
    unscheduled_modules: list[CourseModule] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return {
            "days": [
                {
                    "day_index": d.day_index,
                    "module_ids": [m.id for m in d.modules],
                    "total_minutes": d.total_minutes,
                }
                for d in self.days
            ],
            "redistributed_count": self.redistributed_count,
            "paused": self.paused,
            "pause_reason": self.pause_reason,
            "unscheduled_module_ids": [m.id for m in self.unscheduled_modules],
        }


# ---------------------------------------------------------------------------
# Core algorithm
# ---------------------------------------------------------------------------


def distribute_curriculum(
    course: CourseV2,
    student_calendar: Optional[dict[str, Any]] = None,
) -> DistributionResult:
    """Distribute course modules into daily schedule based on student calendar.

    Args:
        course: the CourseV2 with modules to distribute.
        student_calendar: optional dict with keys:
            - daily_target_minutes (int): target study time per day (default from course.schedule_policy)
            - max_modules_per_day (int): max modules per day (default from course.schedule_policy)
            - start_day_offset (int): day index to start from (default 0)
            - redistribute_count (int): how many times already redistributed (default 0)

    Returns:
        DistributionResult with daily schedules and pause status.
    """
    policy = course.schedule_policy
    calendar = student_calendar or {}

    daily_target = int(calendar.get("daily_target_minutes", policy.daily_target_minutes))
    max_modules = int(calendar.get("max_modules_per_day", policy.max_modules_per_day))
    start_offset = int(calendar.get("start_day_offset", 0))
    redistribute_count = int(calendar.get("redistribute_count", 0))

    # Check redistribute limit
    if redistribute_count >= policy.redistribute_limit:
        if policy.redistribute_pause_on_exceed:
            return DistributionResult(
                days=[],
                redistributed_count=redistribute_count,
                paused=True,
                pause_reason=(
                    f"재분배 한도({policy.redistribute_limit}회)를 초과하여 "
                    f"수강이 일시정지되었습니다. 새 일정을 설정해 주세요."
                ),
                unscheduled_modules=list(course.modules),
            )

    # Filter schedulable modules (skip auto-inserted wrong_answer_review — they follow parent)
    schedulable = [
        m for m in course.modules
        if m.type not in {CourseModuleType.wrong_answer_review}
    ]

    days: list[DailySchedule] = []
    current_day = DailySchedule(day_index=start_offset)
    unscheduled: list[CourseModule] = []

    for module in schedulable:
        # Check if module fits in current day
        fits_time = current_day.total_minutes + module.estimated_minutes <= daily_target
        fits_count = len(current_day.modules) < max_modules

        if fits_time and fits_count:
            current_day.modules.append(module)
            current_day.total_minutes += module.estimated_minutes
        else:
            # Day is full — start a new day
            if current_day.modules:
                days.append(current_day)
            current_day = DailySchedule(day_index=start_offset + len(days))
            current_day.modules.append(module)
            current_day.total_minutes += module.estimated_minutes

    # Append the last day if it has modules
    if current_day.modules:
        days.append(current_day)

    # Attach wrong_answer_review module IDs to the day of their parent module
    _attach_wrong_answer_reviews(course, days)

    return DistributionResult(
        days=days,
        redistributed_count=redistribute_count,
        paused=False,
        pause_reason=None,
        unscheduled_modules=unscheduled,
    )


def _attach_wrong_answer_reviews(
    course: CourseV2,
    days: list[DailySchedule],
) -> None:
    """Attach wrong_answer_review module IDs to the same day as their parent module."""
    # Build a map from parent module id -> wrong_answer_review module
    wa_modules: dict[str, CourseModule] = {}
    for m in course.modules:
        if m.type == CourseModuleType.wrong_answer_review:
            # Extract parent id from review_id pattern: "{parent_id}_wa_{count}"
            parts = m.id.rsplit("_wa_", 1)
            if len(parts) == 2:
                parent_id = parts[0]
                wa_modules[parent_id] = m

    # Attach to days (by module id reference)
    for day in days:
        for module in list(day.modules):
            wa = wa_modules.get(module.id)
            if wa is not None and wa.id not in [dm.id for dm in day.modules]:
                day.modules.append(wa)
                day.total_minutes += wa.estimated_minutes


def redistribute_on_calendar_change(
    course: CourseV2,
    previous_result: DistributionResult,
    new_calendar: dict[str, Any],
) -> DistributionResult:
    """Redistribute course modules when student calendar changes.

    Increments redistribute_count and checks limit before re-distributing.
    """
    new_calendar = dict(new_calendar)
    new_calendar["redistribute_count"] = previous_result.redistributed_count + 1
    return distribute_curriculum(course, new_calendar)


def build_curriculum_group_module(
    course: CourseV2,
    student_calendar: Optional[dict[str, Any]] = None,
) -> CourseModule:
    """Build a curriculum_group module that embeds the distributed schedule.

    This module can be inserted into a CourseV2 to represent the curriculum
    schedule as a single navigable group.
    """
    result = distribute_curriculum(course, student_calendar)

    # Serialize schedule into children (module IDs)
    children: list[str] = []
    for day in result.days:
        day_mod = CourseModule(
            id=f"curriculum_day_{day.day_index}",
            type=CourseModuleType.curriculum_group,
            title=f"Day {day.day_index + 1} ({day.total_minutes}분)",
            description=f"{len(day.modules)}개 모듈",
            position=day.day_index,
            estimated_minutes=day.total_minutes,
            children=[m.id for m in day.modules],
        )
        children.append(day_mod.id)

    return CourseModule(
        id=f"{course.id}_curriculum",
        type=CourseModuleType.curriculum_group,
        title="학습 일정",
        description="AI 알고리즘으로 분배된 학습 일정입니다.",
        position=0,  # caller should re-assign
        estimated_minutes=sum(d.total_minutes for d in result.days),
        children=children,
        state={
            "paused": result.paused,
            "pause_reason": result.pause_reason,
            "redistributed_count": result.redistributed_count,
        },
    )
