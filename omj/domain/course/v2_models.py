"""Pydantic v2 domain models for Course V2 engine.

Provides:
- CourseModuleType: enum of supported module types.
- PassPolicy, FlowPolicy, ChallengePolicy, SchedulePolicy, RuntimeFlags:
  JSON-serializable policy objects stored in the DB.
- CourseModule: a single module within a V2 course.
- CourseV2: the top-level course aggregate.
"""
from __future__ import annotations

from enum import Enum
from typing import Any, Optional

from pydantic import BaseModel, ConfigDict, Field


class CourseModuleType(str, Enum):
    """Supported module types in a V2 course."""

    textbook_view = "textbook_view"
    problem_solve = "problem_solve"
    exam_solve = "exam_solve"
    wrong_answer_review = "wrong_answer_review"
    curriculum_group = "curriculum_group"
    challenge_group = "challenge_group"
    level_test = "level_test"


class PassPolicy(BaseModel):
    """Rules for passing a module or the entire course."""

    model_config = ConfigDict(from_attributes=True)

    required_accuracy: float = Field(default=0.0, ge=0.0, le=100.0)
    min_correct: int = Field(default=0, ge=0)
    max_time_seconds: Optional[int] = Field(default=None, ge=1)
    min_time_seconds: Optional[int] = Field(default=None, ge=0)
    retry_limit: int = Field(default=0, ge=0)


class FlowPolicy(BaseModel):
    """Flowchart interaction restrictions for a module."""

    model_config = ConfigDict(from_attributes=True)

    mode: str = Field(
        default="full",
        pattern=r"^(full|blocked|answer_riddle_only|linear|sequential)$",
    )
    allow_skip: bool = Field(default=False)
    allow_back: bool = Field(default=True)


class ChallengePolicy(BaseModel):
    """Challenge generation policy attached to a course."""

    model_config = ConfigDict(from_attributes=True)

    daily_count: int = Field(default=3, ge=1, le=10)
    weekly_count: int = Field(default=5, ge=1, le=20)
    auto_generate: bool = Field(default=True)
    types: list[str] = Field(default_factory=list)


class SchedulePolicy(BaseModel):
    """Curriculum scheduling and redistribution rules."""

    model_config = ConfigDict(from_attributes=True)

    redistribute_limit: int = Field(default=5, ge=0)
    redistribute_pause_on_exceed: bool = Field(default=True)
    daily_target_minutes: int = Field(default=30, ge=1)
    max_modules_per_day: int = Field(default=5, ge=1)


class RuntimeFlags(BaseModel):
    """Feature toggles for course runtime behaviour."""

    model_config = ConfigDict(from_attributes=True)

    show_timer: bool = Field(default=True)
    show_progress_bar: bool = Field(default=True)
    force_answer_riddle: bool = Field(default=False)
    enable_wrong_answer_auto_insert: bool = Field(default=True)
    enable_hints: bool = Field(default=True)


class CourseModule(BaseModel):
    """A single module inside a V2 course."""

    model_config = ConfigDict(from_attributes=True)

    id: str = Field(..., description="Unique module id within the course")
    type: CourseModuleType
    title: str
    description: Optional[str] = None
    position: int = Field(default=0, ge=0, description="Display order")
    estimated_minutes: int = Field(default=0, ge=0)

    # Problem-solve / exam-solve constraints
    problem_ids: Optional[list[str]] = None
    exam_id: Optional[str] = None
    max_problems: int = Field(default=10, ge=1, le=50)
    textbook_id: Optional[str] = None
    page_from: Optional[int] = None
    page_to: Optional[int] = None
    min_minutes: Optional[int] = None
    enforce_min_minutes: bool = False

    # Policy overrides at module level (falls back to course-level policy)
    pass_policy: Optional[PassPolicy] = None
    flow_policy: Optional[FlowPolicy] = None

    # Curriculum grouping
    children: Optional[list[str]] = Field(
        default=None,
        description="Module ids grouped under this curriculum_group / challenge_group",
    )

    # Runtime state (transient, not stored in course definition)
    state: Optional[dict[str, Any]] = Field(
        default=None,
        description="Transient runtime state (locked, completed, score, etc.)",
    )


class CourseV2(BaseModel):
    """V2 course aggregate."""

    model_config = ConfigDict(from_attributes=True)

    id: str = ""
    title: str
    description: str = ""
    difficulty: str = ""
    duration: str = ""
    tags: list[str] = Field(default_factory=list)
    focus_tags: list[str] = Field(default_factory=list)
    target_ovr: int = Field(default=0, ge=0)
    textbook_id: Optional[str] = None
    textbook_pages: int = Field(default=0, ge=0)
    is_demo: bool = Field(default=False)
    is_public: bool = Field(default=False)
    owner_user_id: str = ""
    access_academy_id: Optional[str] = None
    access_group_id: Optional[str] = None

    modules: list[CourseModule] = Field(default_factory=list)

    pass_policy: PassPolicy = Field(default_factory=PassPolicy)
    flow_policy: FlowPolicy = Field(default_factory=FlowPolicy)
    challenge_policy: ChallengePolicy = Field(default_factory=ChallengePolicy)
    schedule_policy: SchedulePolicy = Field(default_factory=SchedulePolicy)
    runtime_flags: RuntimeFlags = Field(default_factory=RuntimeFlags)
    curriculum_settings: dict[str, Any] = Field(default_factory=dict)
    challenge_settings: dict[str, Any] = Field(default_factory=dict)

    created_at: Optional[int] = None
    updated_at: Optional[int] = None

    @property
    def module_map(self) -> dict[str, CourseModule]:
        """Return a dict mapping module id -> CourseModule."""
        return {m.id: m for m in self.modules}

    def get_module(self, module_id: str) -> Optional[CourseModule]:
        """Fetch a module by id."""
        return self.module_map.get(module_id)

    def index_of(self, module_id: str) -> int:
        """Return the position index of a module, or -1 if not found."""
        for i, m in enumerate(self.modules):
            if m.id == module_id:
                return i
        return -1
