"""Curriculum recommendation engine.

Provides:
- analyze_weaknesses: identifies topics below a threshold.
- build_curriculum: assembles a weekly CurriculumPath from weaknesses and OVR.
- adapt_path: mutates a path with new OVR data.
- serialize_path / deserialize_path: JSON conversions.
"""
from __future__ import annotations

import json
from typing import Optional

from domain.course.v2_models import CourseV2
from domain.curriculum.models import (
    CurriculumPath,
    PathStep,
    StudentOVR,
    WeaknessTag,
)


def analyze_weaknesses(ovr: StudentOVR, threshold: float = 0.6) -> list[WeaknessTag]:
    """Identify topics whose accuracy is below the threshold.

    Severity is computed as (threshold - accuracy) / threshold so that
    lower accuracy yields higher severity.
    """
    weaknesses: list[WeaknessTag] = []
    for topic, accuracy in ovr.accuracy_by_topic.items():
        if accuracy < threshold:
            severity = min(1.0, max(0.0, (threshold - accuracy) / threshold))
            weaknesses.append(
                WeaknessTag(
                    topic=topic,
                    subtopic="",
                    severity=round(severity, 4),
                    evidence_count=1,
                )
            )
    # Sort by severity descending
    weaknesses.sort(key=lambda w: w.severity, reverse=True)
    return weaknesses


def _difficulty_for_topic(topic: str, ovr: StudentOVR, week: int, total_weeks: int) -> str:
    """Map power and week progression to a difficulty label."""
    power = ovr.power_by_topic.get(topic, 0.5)
    if power > 0.7:
        difficulty = "hard"
    elif power > 0.4:
        difficulty = "medium"
    else:
        difficulty = "easy"

    # Progressive escalation toward the end of the path
    progress = week / max(total_weeks, 1)
    if progress > 0.8 and difficulty == "medium":
        difficulty = "hard"
    elif progress > 0.6 and difficulty == "easy":
        difficulty = "medium"

    return difficulty


def build_curriculum(
    course: CourseV2,
    weaknesses: list[WeaknessTag],
    ovr: StudentOVR,
    total_weeks: int = 12,
) -> CurriculumPath:
    """Assemble a weekly path targeting weakest topics first.

    Rules:
    - Weeks 1-N target weakest topics first.
    - Every 3rd week is a review week.
    - Difficulty is based on ovr.power_by_topic with late-week escalation.
    """
    sorted_weaknesses = sorted(weaknesses, key=lambda w: w.severity, reverse=True)
    review_weeks = set(range(3, total_weeks + 1, 3))

    sequence: list[PathStep] = []
    topic_index = 0

    # Fallback topics from course metadata
    fallback_topics: list[str] = list(course.focus_tags or course.tags or ["general"])

    for week in range(1, total_weeks + 1):
        if week in review_weeks:
            sequence.append(
                PathStep(
                    week=week,
                    module_type="review",
                    topic="review",
                    goal="Review and consolidate previous topics",
                    difficulty="medium",
                )
            )
            continue

        if topic_index < len(sorted_weaknesses):
            topic = sorted_weaknesses[topic_index].topic
        else:
            topic = fallback_topics[
                (topic_index - len(sorted_weaknesses)) % len(fallback_topics)
            ]

        difficulty = _difficulty_for_topic(topic, ovr, week, total_weeks)

        sequence.append(
            PathStep(
                week=week,
                module_type="curriculum_group",
                topic=topic,
                goal=f"Strengthen {topic}",
                difficulty=difficulty,
            )
        )
        topic_index += 1

    return CurriculumPath(
        course_id=course.id,
        sequence=sequence,
        estimated_weeks=total_weeks,
        target_mastery=0.8,
        adaptive_rules_json=json.dumps({"review_interval": 3}, ensure_ascii=False),
    )


def adapt_path(path: CurriculumPath, new_ovr: StudentOVR) -> CurriculumPath:
    """Mutate an existing path with new OVR data.

    Reorders remaining (non-review) weeks to target the newly weakest topics
    and recalculates difficulty based on the updated power map.
    """
    weaknesses = analyze_weaknesses(new_ovr)
    sorted_weaknesses = sorted(weaknesses, key=lambda w: w.severity, reverse=True)

    review_steps = [s for s in path.sequence if s.module_type == "review"]
    learn_steps = [s for s in path.sequence if s.module_type != "review"]

    # Reassign topics to learning weeks
    for i, step in enumerate(learn_steps):
        if i < len(sorted_weaknesses):
            step.topic = sorted_weaknesses[i].topic
        step.difficulty = _difficulty_for_topic(
            step.topic, new_ovr, step.week, path.estimated_weeks
        )

    # Rebuild sequence preserving week order
    week_to_step: dict[int, PathStep] = {}
    learn_iter = iter(learn_steps)
    for step in path.sequence:
        if step.module_type == "review":
            week_to_step[step.week] = step
        else:
            try:
                week_to_step[step.week] = next(learn_iter)
            except StopIteration:
                week_to_step[step.week] = step

    path.sequence = [week_to_step[w] for w in sorted(week_to_step.keys())]
    return path


def serialize_path(path: CurriculumPath) -> str:
    """Serialize a CurriculumPath to a JSON string."""
    return path.model_dump_json()


def deserialize_path(json_str: str) -> CurriculumPath:
    """Deserialize a JSON string into a CurriculumPath."""
    data = json.loads(json_str)
    return CurriculumPath.model_validate(data)
