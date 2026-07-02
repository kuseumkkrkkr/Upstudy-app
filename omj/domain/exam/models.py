"""Pydantic models for the Exam domain.

Provides:
- ExamPaper      : a generated exam paper
- ExamSection    : a section within an exam layout
- ExamPaperLayout: aggregate of sections with total count
"""
from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, ConfigDict, Field


class ExamPaper(BaseModel):
    """A generated exam paper stored in the database."""

    model_config = ConfigDict(from_attributes=True)

    id: Optional[int] = None
    course_id: int
    title: str
    type: str = Field(..., pattern=r"^(daily|weekly|mock)$")
    total_minutes: int = Field(default=60, ge=1)
    layout_json: Optional[str] = None
    by_unit_json: Optional[str] = None
    created_at: Optional[datetime] = None


class ExamSection(BaseModel):
    """A single section within an exam layout."""

    model_config = ConfigDict(from_attributes=True)

    unit_id: int
    difficulty_preset: str = Field(default="medium", pattern=r"^(easy|medium|hard)$")
    count: int = Field(default=5, ge=0)
    types: List[str] = Field(default_factory=lambda: ["multiple_choice", "short_answer"])


class ExamPaperLayout(BaseModel):
    """Aggregate of sections representing an exam paper layout."""

    model_config = ConfigDict(from_attributes=True)

    sections: List[ExamSection] = Field(default_factory=list)
    total_count: int = 0
