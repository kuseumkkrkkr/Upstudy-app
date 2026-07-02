"""Pydantic models for the textbook domain.

Provides:
- TextbookBlock: a single content block (chapter, section, subsection, problem)
- TextbookGraph: the graph structure linking blocks for a course
- TextbookBuildRequest: request to enqueue a textbook build job
- TextbookBuildResult: response from a build job enqueue
"""
from datetime import datetime, timezone
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class TextbookBlock(BaseModel):
    """A single content block within a textbook."""

    model_config = ConfigDict(from_attributes=True)

    id: Optional[int] = None
    type: str = Field(..., pattern=r"^(chapter|section|subsection|problem)$")
    title: str
    content: Optional[str] = None
    level: int = Field(default=1, ge=1, le=5)
    learning_objective_id: Optional[int] = None
    parent_id: Optional[int] = None
    course_id: Optional[int] = None


class TextbookGraph(BaseModel):
    """Graph structure that links blocks for a specific course."""

    model_config = ConfigDict(from_attributes=True)

    id: Optional[int] = None
    course_id: int
    root_blocks: list[int] = Field(default_factory=list)
    created_at: Optional[str] = Field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )


class TextbookBuildRequest(BaseModel):
    """Request to start a textbook build job."""

    model_config = ConfigDict(from_attributes=True)

    course_id: int
    root_ids: list[int] = Field(default_factory=list)
    ai_provider: str = "kimi"


class TextbookBuildResult(BaseModel):
    """Result returned after enqueueing a build job."""

    model_config = ConfigDict(from_attributes=True)

    job_id: str
    status: str
    blocks_generated: int = 0
    preview_url: Optional[str] = None
