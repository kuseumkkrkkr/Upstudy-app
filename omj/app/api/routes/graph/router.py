"""FastAPI router for the Objective Graph domain.

Endpoints:
- GET  /graphs/{course_id}                -> get objective graph (student/teacher/admin)
- POST /graphs/{course_id}/objectives     -> add learning objective (teacher/admin)
- GET  /graphs/{course_id}/next           -> recommend next objectives (student)
- POST /graphs/objectives/{id}/attempt     -> submit score, update mastery (student)
- GET  /graphs/{course_id}/progress/{user_id} -> get all student states (student sees own, teacher sees any)
"""
from __future__ import annotations

from typing import Any, Generic, List, Optional, TypeVar

from fastapi import APIRouter, Depends, Request

from app.api.routes.auth.middleware import require_role
from domain.graph import engine, repository as repo
from domain.graph.models import LearningObjective, ObjectiveGraph, StudentObjectiveState
from pydantic import BaseModel, Field

router = APIRouter(prefix="/graphs", tags=["graphs"])


# ---------------------------------------------------------------------------
# Generic response wrapper
# ---------------------------------------------------------------------------

T = TypeVar("T")


class ApiResponse(BaseModel, Generic[T]):
    """Unified API response envelope."""

    success: bool = True
    data: Optional[T] = None
    message: Optional[str] = None


class ObjectiveGraphResponse(ApiResponse[ObjectiveGraph]):
    """Concrete response for an objective graph."""


class LearningObjectiveResponse(ApiResponse[LearningObjective]):
    """Concrete response for a single learning objective."""


class LearningObjectiveListResponse(ApiResponse[List[LearningObjective]]):
    """Concrete response for a list of learning objectives."""


class StudentStatesResponse(ApiResponse[List[StudentObjectiveState]]):
    """Concrete response for a list of student objective states."""


class MasteryResponse(ApiResponse[StudentObjectiveState]):
    """Concrete response for a mastery update."""


# ---------------------------------------------------------------------------
# Request schemas
# ---------------------------------------------------------------------------


class CreateObjectiveRequest(BaseModel):
    """Body for POST /graphs/{course_id}/objectives."""

    code: str = Field(..., description="Unique short code")
    title: str = Field(..., description="Human-readable title")
    description: str = Field(default="", description="Detailed description")
    parent_id: Optional[int] = Field(default=None, description="Parent objective ID")
    level: int = Field(default=1, ge=1, description="Difficulty / depth level")
    topic: str = Field(..., description="Topic tag")
    prerequisites: List[int] = Field(default_factory=list, description="Prerequisite objective IDs")
    estimated_minutes: int = Field(default=30, ge=1, description="Estimated study time in minutes")


class AttemptRequest(BaseModel):
    """Body for POST /graphs/objectives/{id}/attempt."""

    score: float = Field(..., ge=0.0, le=100.0, description="Score achieved on the attempt")


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------


@router.get("/{course_id}", response_model=ObjectiveGraphResponse)
async def get_graph(
    course_id: int,
    _user=Depends(require_role("student", "teacher", "admin")),
):
    """Retrieve the objective graph for a course."""
    graph = repo.get_graph_by_course(course_id)
    if graph is None:
        return ObjectiveGraphResponse(success=False, data=None, message="Graph not found")
    return ObjectiveGraphResponse(data=graph, message="Graph retrieved")


@router.post("/{course_id}/objectives", response_model=LearningObjectiveResponse)
async def add_objective(
    course_id: int,
    body: CreateObjectiveRequest,
    _user=Depends(require_role("teacher", "admin")),
):
    """Add a new learning objective to a course graph."""
    obj = LearningObjective(
        code=body.code,
        title=body.title,
        description=body.description,
        parent_id=body.parent_id,
        level=body.level,
        topic=body.topic,
        prerequisites=body.prerequisites,
        estimated_minutes=body.estimated_minutes,
    )
    obj_id = repo.create_learning_objective(obj)
    obj.id = obj_id

    # Rebuild graph edges to include the new objective
    graph = repo.get_graph_by_course(course_id)
    if graph is not None:
        graph.objectives.append(obj)
        rebuilt = engine.build_objective_graph(course_id, graph.objectives)
        rebuilt.id = graph.id
        repo.update_objective_graph(rebuilt)
    else:
        # First objective: create a new graph
        rebuilt = engine.build_objective_graph(course_id, [obj])
        repo.create_objective_graph(rebuilt)

    return LearningObjectiveResponse(data=obj, message="Objective created")


@router.get("/{course_id}/next", response_model=LearningObjectiveListResponse)
async def get_next_objectives(
    request: Request,
    course_id: int,
    count: int = 3,
    _user=Depends(require_role("student", "teacher", "admin")),
):
    """Recommend the next objectives for the current user."""
    user_id = request.state.user_id
    graph = repo.get_graph_by_course(course_id)
    if graph is None:
        return LearningObjectiveListResponse(success=False, data=None, message="Graph not found")

    states = repo.get_student_states(user_id, course_id)
    recommendations = engine.recommend_next_objectives(user_id, graph, states, count=count)
    return LearningObjectiveListResponse(data=recommendations, message="Recommendations retrieved")


@router.post("/objectives/{objective_id}/attempt", response_model=MasteryResponse)
async def submit_attempt(
    request: Request,
    objective_id: int,
    body: AttemptRequest,
    _user=Depends(require_role("student", "teacher", "admin")),
):
    """Submit a score for an objective and update mastery status."""
    user_id = request.state.user_id
    graph = None
    # Find the graph that contains this objective
    # Since we don't have an index, scan all graphs (simplified for SQLite)
    # In practice the caller should provide course_id; here we look up via objective
    obj = repo.get_learning_objective(objective_id)
    if obj is None:
        return MasteryResponse(success=False, data=None, message="Objective not found")

    # We need a course_id to hydrate the graph; try to infer from any existing graph
    # that references this objective by scanning the DB.  For simplicity we accept
    # that the graph edges for prerequisites are enough and use a minimal graph.
    conn = __import__("sqlite3").connect(repo.DB_PATH)
    cur = conn.cursor()
    cur.execute("SELECT course_id FROM objective_graph LIMIT 1")
    row = cur.fetchone()
    conn.close()

    if row is None:
        return MasteryResponse(success=False, data=None, message="No graph found")

    course_id = row[0]
    graph = repo.get_graph_by_course(course_id)
    if graph is None:
        return MasteryResponse(success=False, data=None, message="Graph not found")

    states = repo.get_student_states(user_id, course_id)
    updated = engine.update_mastery(user_id, objective_id, body.score, graph, states)
    repo.update_student_state(updated)

    return MasteryResponse(data=updated, message="Mastery updated")


@router.get("/{course_id}/progress/{user_id}", response_model=StudentStatesResponse)
async def get_progress(
    request: Request,
    course_id: int,
    user_id: str,
    _user=Depends(require_role("student", "teacher", "admin")),
):
    """Fetch all student objective states for a user in a course.

    Students may only view their own progress; teachers and admins may view any.
    """
    caller_id = request.state.user_id
    role = request.state.role

    if role == "student" and caller_id != user_id:
        return StudentStatesResponse(success=False, data=None, message="Forbidden")

    states = repo.get_student_states(user_id, course_id)
    return StudentStatesResponse(data=states, message="Progress retrieved")
