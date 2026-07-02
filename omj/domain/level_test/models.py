"""Pydantic models for the Level Test domain.

Provides:
- SpeedTest     : a quick, time-bound diagnostic test
- PowerTest     : a deep-dive diagnostic test with weakness analysis
- LevelTestResult: aggregated results across speed and power tests
- DifficultyPreset: allowed difficulty values
"""
from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, ConfigDict, Field


class DifficultyPreset:
    """Allowed difficulty string literals."""

    easy: str = "easy"
    medium: str = "medium"
    hard: str = "hard"


class SpeedTest(BaseModel):
    """A speed-focused diagnostic test."""

    model_config = ConfigDict(from_attributes=True)

    id: Optional[int] = None
    user_id: str
    topic: str
    difficulty: str = Field(default="medium", pattern=r"^(easy|medium|hard)$")
    time_limit_seconds: int = Field(default=600, ge=1)
    problems_json: Optional[str] = None
    submitted_answers_json: Optional[str] = None
    score: Optional[float] = None
    status: str = Field(default="pending", pattern=r"^(pending|started|submitted|graded)$")
    started_at: Optional[datetime] = None
    submitted_at: Optional[datetime] = None


class PowerTest(BaseModel):
    """A power-focused deep-dive diagnostic test."""

    model_config = ConfigDict(from_attributes=True)

    id: Optional[int] = None
    user_id: str
    topic: str
    difficulty: str = Field(default="medium", pattern=r"^(easy|medium|hard)$")
    time_limit_seconds: int = Field(default=1800, ge=1)
    problems_json: Optional[str] = None
    submitted_answers_json: Optional[str] = None
    score: Optional[float] = None
    status: str = Field(default="pending", pattern=r"^(pending|started|submitted|graded)$")
    started_at: Optional[datetime] = None
    submitted_at: Optional[datetime] = None
    weakness_report_input: Optional[str] = None
    generated_explanations_json: Optional[str] = None


class LevelTestResult(BaseModel):
    """Aggregated level-test results for a user."""

    model_config = ConfigDict(from_attributes=True)

    user_id: str
    overall_speed: float = Field(default=0.0, ge=0.0, le=100.0)
    overall_power: float = Field(default=0.0, ge=0.0, le=100.0)
    topic_breakdown: Dict[str, Dict[str, Any]] = Field(default_factory=dict)
