"""Pydantic v2 domain models for curriculum engine.

Provides:
- StudentOVR: snapshot of a student's accuracy, speed, and power by topic.
- WeaknessTag: a diagnosed weakness with severity and evidence count.
- PathStep: a single week in a curriculum path.
- CurriculumPath: an assembled weekly learning path for a course.
"""
from __future__ import annotations

from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class StudentOVR(BaseModel):
    """Student Overall Performance Record (OVR) snapshot."""

    model_config = ConfigDict(from_attributes=True)

    user_id: str
    accuracy_by_topic: dict[str, float] = Field(default_factory=dict)
    speed_by_topic: dict[str, float] = Field(default_factory=dict)
    power_by_topic: dict[str, float] = Field(default_factory=dict)
    last_updated: Optional[int] = Field(
        default=None,
        description="Unix timestamp of the last update",
    )


class WeaknessTag(BaseModel):
    """A tagged weakness derived from OVR analysis."""

    model_config = ConfigDict(from_attributes=True)

    topic: str
    subtopic: str = ""
    severity: float = Field(default=0.0, ge=0.0, le=1.0)
    evidence_count: int = Field(default=0, ge=0)


class PathStep(BaseModel):
    """A single week in a curriculum path."""

    model_config = ConfigDict(from_attributes=True)

    week: int = Field(..., ge=1)
    module_type: str = Field(default="curriculum_group")
    topic: str
    goal: str = ""
    difficulty: str = Field(default="medium")


class CurriculumPath(BaseModel):
    """An assembled weekly learning path for a course."""

    model_config = ConfigDict(from_attributes=True)

    course_id: str
    sequence: list[PathStep] = Field(default_factory=list)
    estimated_weeks: int = Field(default=12, ge=1)
    target_mastery: float = Field(default=0.8, ge=0.0, le=1.0)
    adaptive_rules_json: str = Field(default='{}')
