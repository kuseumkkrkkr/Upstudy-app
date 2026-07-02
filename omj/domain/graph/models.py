"""Pydantic models for the Objective Graph domain.

Provides:
- LearningObjective   : a single learnable node in the graph
- ObjectiveGraph      : a course-level graph of objectives and edges
- StudentObjectiveState: per-user progress on an objective
"""
from __future__ import annotations

from typing import List, Optional

from pydantic import BaseModel, ConfigDict, Field


class LearningObjective(BaseModel):
    """A single learnable node in the graph."""

    model_config = ConfigDict(from_attributes=True)

    id: Optional[int] = None
    code: str = Field(..., description="Unique short code for the objective")
    title: str = Field(..., description="Human-readable title")
    description: str = Field(default="", description="Detailed description")
    parent_id: Optional[int] = Field(default=None, description="FK to parent objective")
    level: int = Field(default=1, ge=1, description="Difficulty / depth level")
    topic: str = Field(..., description="Topic tag for grouping")
    prerequisites: List[int] = Field(default_factory=list, description="List of prerequisite objective IDs")
    estimated_minutes: int = Field(default=30, ge=1, description="Estimated study time in minutes")


class ObjectiveGraph(BaseModel):
    """A course-level graph of objectives and edges."""

    model_config = ConfigDict(from_attributes=True)

    id: Optional[int] = None
    course_id: int = Field(..., ge=1, description="FK to the parent course")
    objectives: List[LearningObjective] = Field(default_factory=list, description="All objectives in the course")
    edges_json: str = Field(
        default="[]",
        description='JSON-serialized list of {from_id, to_id, type: prerequisite|related|sequential}',
    )


class StudentObjectiveState(BaseModel):
    """Per-user progress on an objective."""

    model_config = ConfigDict(from_attributes=True)

    user_id: str = Field(..., description="User identifier")
    objective_id: int = Field(..., ge=1, description="FK to the objective")
    status: str = Field(
        default="locked",
        pattern=r"^(locked|available|in_progress|mastered)$",
        description="Current mastery status",
    )
    mastery_score: float = Field(default=0.0, ge=0.0, le=100.0, description="Last recorded score")
    last_attempted_at: Optional[str] = Field(default=None, description="ISO timestamp of last attempt")
    mastered_at: Optional[str] = Field(default=None, description="ISO timestamp when mastered")
