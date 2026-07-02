"""Pydantic models for the Challenge domain.

Provides:
- Challenge: a challenge definition (daily, weekly, special).
- StudentChallengeProgress: per-student attempt tracking.
"""
from __future__ import annotations

from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class Challenge(BaseModel):
    """A challenge (daily, weekly, or special event)."""

    model_config = ConfigDict(from_attributes=True)

    id: Optional[int] = Field(default=None, description="Auto-generated primary key")
    course_id: int
    title: str
    challenge_type: str = Field(
        default="daily",
        pattern=r"^(daily|weekly|special)$",
    )
    difficulty: str = ""
    problems_json: str = Field(default="[]", description="JSON array of problems")
    reward_points: int = Field(default=0, ge=0)
    time_limit_seconds: int = Field(default=300, ge=1)
    start_date: str = ""
    end_date: str = ""
    status: str = Field(
        default="active",
        pattern=r"^(active|completed|expired)$",
    )


class StudentChallengeProgress(BaseModel):
    """Per-student progress on a single challenge."""

    model_config = ConfigDict(from_attributes=True)

    id: Optional[int] = Field(default=None, description="Auto-generated primary key")
    user_id: str
    challenge_id: int
    score: float = Field(default=0.0, ge=0.0, le=100.0)
    attempts: int = Field(default=0, ge=0)
    best_time_seconds: int = Field(default=0, ge=0)
    completed_at: Optional[str] = None
    reward_claimed: bool = False
