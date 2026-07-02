"""Pydantic models for the Quest Variant domain.

Provides:
- QuestVariant : a generated variant of an original quest problem
- QuestFlow    : a teacher-defined sequence of quests with flow rules
"""
from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, ConfigDict, Field


class QuestVariant(BaseModel):
    """A generated variant of an original quest problem."""

    model_config = ConfigDict(from_attributes=True)

    id: Optional[int] = None
    original_quest_id: int = Field(..., ge=1, description="FK to the original quest")
    variant_type: str = Field(
        ...,
        pattern=r"^(easier|harder|hint_heavy|scaffolded|speed_drill|proof_variant)$",
        description="Type of variant transformation applied",
    )
    generated_problem_json: str = Field(
        ...,
        description="JSON-serialized generated problem matching the variant schema",
    )
    difficulty_adjustment: int = Field(
        default=0,
        ge=-2,
        le=2,
        description="Difficulty delta applied to the original problem",
    )
    ai_confidence: Optional[float] = Field(
        default=None,
        ge=0.0,
        le=1.0,
        description="Model confidence score for the generated variant",
    )
    created_at: Optional[datetime] = Field(default=None)


class QuestFlow(BaseModel):
    """A teacher-defined sequence of quests with optional flow rules."""

    model_config = ConfigDict(from_attributes=True)

    id: Optional[int] = None
    course_id: int = Field(..., ge=1, description="FK to the parent course")
    quest_sequence: List[int] = Field(
        default_factory=list,
        description="Ordered list of quest IDs in the flow",
    )
    flow_rules_json: Optional[str] = Field(
        default=None,
        description="JSON-serialized flow rules (gating, branching, etc.)",
    )
