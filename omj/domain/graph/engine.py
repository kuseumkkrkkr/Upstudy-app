"""Graph engine: build, evaluate, update, and recommend.

Provides:
- build_objective_graph       : auto-generate edges from prerequisites and topic sequencing
- evaluate_objective_unlock   : check whether prerequisites are mastered
- update_mastery              : transition status based on score thresholds
- recommend_next_objectives   : suggest next objectives to study
"""
from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import List, Optional, Tuple

from domain.graph.models import LearningObjective, ObjectiveGraph, StudentObjectiveState


def build_objective_graph(
    course_id: int,
    objectives: List[LearningObjective],
) -> ObjectiveGraph:
    """Auto-generate edges and return an ``ObjectiveGraph``.

    Edges created:
    1. For each objective with non-empty ``prerequisites``, a ``prerequisite``
       edge from each prereq ID to the objective.
    2. ``sequential`` edges between objectives of the same ``topic`` and same
       ``level``, ordered by ``id`` ascending.
    """
    edges: List[dict] = []

    # Prerequisite edges
    for obj in objectives:
        for prereq_id in obj.prerequisites:
            edges.append({"from_id": prereq_id, "to_id": obj.id, "type": "prerequisite"})

    # Sequential edges: same topic + same level, ordered by id
    topic_level_map: dict = {}
    for obj in objectives:
        if obj.id is None:
            continue
        key = (obj.topic, obj.level)
        topic_level_map.setdefault(key, []).append(obj)

    for group in topic_level_map.values():
        sorted_group = sorted(group, key=lambda o: o.id)
        for i in range(len(sorted_group) - 1):
            edges.append(
                {
                    "from_id": sorted_group[i].id,
                    "to_id": sorted_group[i + 1].id,
                    "type": "sequential",
                }
            )

    return ObjectiveGraph(
        course_id=course_id,
        objectives=objectives,
        edges_json=json.dumps(edges, ensure_ascii=False),
    )


def evaluate_objective_unlock(
    user_id: str,
    objective_id: int,
    graph: ObjectiveGraph,
    student_states: List[StudentObjectiveState],
) -> Tuple[bool, str]:
    """Return whether ``objective_id`` is unlocked for ``user_id``.

    An objective is unlocked when all of its prerequisite objectives have
    ``status="mastered"`` in ``student_states``.
    """
    # Build a lookup for states
    state_map: dict = {}
    for st in student_states:
        state_map[(st.user_id, st.objective_id)] = st

    # Find the target objective in the graph
    target: Optional[LearningObjective] = None
    for obj in graph.objectives:
        if obj.id == objective_id:
            target = obj
            break

    if target is None:
        return False, f"Objective {objective_id} not found in graph"

    missing_prereq_ids: List[int] = []
    for prereq_id in target.prerequisites:
        state = state_map.get((user_id, prereq_id))
        if state is None or state.status != "mastered":
            missing_prereq_ids.append(prereq_id)

    if missing_prereq_ids:
        return False, f"Prerequisites not met: {missing_prereq_ids}"

    return True, "unlocked"


def update_mastery(
    user_id: str,
    objective_id: int,
    score: float,
    graph: ObjectiveGraph,
    states: List[StudentObjectiveState],
) -> StudentObjectiveState:
    """Update (or create) a ``StudentObjectiveState`` based on ``score``.

    Thresholds:
    - score >= 80 -> mastered
    - score >= 60 -> in_progress
    - else        -> available
    """
    now_iso = datetime.now(timezone.utc).isoformat()

    # Try to find existing state
    existing: Optional[StudentObjectiveState] = None
    for st in states:
        if st.user_id == user_id and st.objective_id == objective_id:
            existing = st
            break

    if score >= 80.0:
        status = "mastered"
        mastered_at = now_iso
    elif score >= 60.0:
        status = "in_progress"
        mastered_at = existing.mastered_at if existing else None
    else:
        status = "available"
        mastered_at = existing.mastered_at if existing else None

    if existing:
        updated = StudentObjectiveState(
            user_id=existing.user_id,
            objective_id=existing.objective_id,
            status=status,
            mastery_score=score,
            last_attempted_at=now_iso,
            mastered_at=mastered_at,
        )
    else:
        updated = StudentObjectiveState(
            user_id=user_id,
            objective_id=objective_id,
            status=status,
            mastery_score=score,
            last_attempted_at=now_iso,
            mastered_at=mastered_at,
        )

    return updated


def recommend_next_objectives(
    user_id: str,
    graph: ObjectiveGraph,
    states: List[StudentObjectiveState],
    count: int = 3,
) -> List[LearningObjective]:
    """Recommend up to ``count`` objectives that are available but not started.

    Filters to objectives where ``status="available"`` (prereqs met but not
    started), then sorts by ``level`` ascending, then ``estimated_minutes``
    ascending.
    """
    # Build state map
    state_map: dict = {}
    for st in states:
        state_map[st.objective_id] = st

    available_objs: List[LearningObjective] = []
    for obj in graph.objectives:
        if obj.id is None:
            continue
        st = state_map.get(obj.id)
        if st is not None and st.status == "available":
            available_objs.append(obj)

    available_objs.sort(key=lambda o: (o.level, o.estimated_minutes))
    return available_objs[:count]
