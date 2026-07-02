"""Deterministic layout builder for exam papers.

Provides:
- build_layout               : maps units to sections deterministically
- serialize_layout           : JSON round-trip (ExamPaperLayout -> str)
- deserialize_layout         : JSON round-trip (str -> ExamPaperLayout)
- calculate_difficulty_distribution : seed-based pseudo-random split
"""
import json
import random
from typing import Dict, List

from domain.exam.models import ExamPaperLayout, ExamSection


_DEFAULT_COUNT = 5
_DEFAULT_TYPES = ["multiple_choice", "short_answer"]


def build_layout(
    course_id: int,
    unit_ids: List[int],
    difficulty_map: Dict[str, str],
) -> ExamPaperLayout:
    """Deterministically build an exam layout from units.

    Each ``unit_id`` becomes one :class:`ExamSection`.  The *difficulty_map*
    keys are ``str(unit_id)`` and values are ``easy|medium|hard``.  Sections
    default to 5 problems with mixed question types.
    """
    sections: List[ExamSection] = []
    for uid in unit_ids:
        preset = difficulty_map.get(str(uid), "medium")
        sections.append(
            ExamSection(
                unit_id=uid,
                difficulty_preset=preset,
                count=_DEFAULT_COUNT,
                types=list(_DEFAULT_TYPES),
            )
        )
    total_count = sum(s.count for s in sections)
    return ExamPaperLayout(sections=sections, total_count=total_count)


def serialize_layout(layout: ExamPaperLayout) -> str:
    """Return a JSON string representation of *layout*."""
    return layout.model_dump_json()


def deserialize_layout(json_str: str) -> ExamPaperLayout:
    """Reconstruct an :class:`ExamPaperLayout` from its JSON string."""
    return ExamPaperLayout.model_validate_json(json_str)


def calculate_difficulty_distribution(codebase_id: int, seed: int) -> Dict[str, int]:
    """Return a deterministic difficulty split for a codebase.

    Uses ``random.Random(seed)`` so the result is stable and cacheable.
    """
    rng = random.Random(seed)
    total = rng.randint(10, 30)
    easy = rng.randint(1, total - 2)
    medium = rng.randint(1, total - easy - 1)
    hard = total - easy - medium
    return {"easy": easy, "medium": medium, "hard": hard}
