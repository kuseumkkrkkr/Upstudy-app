"""Course V2 engine: module pass/fail evaluator + forced wrong-answer insertion.

Provides:
- evaluate_module_pass: determines whether a student's attempt on a module meets
  the pass policy.
- insert_forced_wrong_answer_modules: scans a CourseV2 and auto-inserts
  `wrong_answer_review` modules after any module whose required_accuracy < 100.
- next_module: determines the next module a student should attempt, respecting
  flow_policy and runtime state.
- evaluate_wrong_answer_eligibility: checks whether a wrong_answer_review module
  is eligible to be activated based on accumulated wrong answers.
"""
from __future__ import annotations

from copy import deepcopy
from typing import Any, Optional

from domain.course.v2_models import (
    CourseModule,
    CourseModuleType,
    CourseV2,
    PassPolicy,
    FlowPolicy,
)


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

MAX_PROBLEMS_PER_MODULE = 10


# ---------------------------------------------------------------------------
# Pass / Fail evaluation
# ---------------------------------------------------------------------------


def _effective_pass_policy(course: CourseV2, module: CourseModule) -> PassPolicy:
    """Return the module-level pass_policy if set, otherwise the course-level."""
    policy = module.pass_policy or course.pass_policy
    if module.pass_rate is not None and module.pass_policy is None:
        policy = policy.model_copy(update={"required_accuracy": float(module.pass_rate)})
    return policy


def evaluate_module_pass(
    module: CourseModule,
    course: CourseV2,
    correct_count: int,
    total_count: int,
    elapsed_seconds: Optional[int] = None,
) -> dict[str, Any]:
    """Evaluate whether a student's attempt passes the module's policy.

    Returns a dict:
        {
            "passed": bool,
            "reason": str,          # human-readable explanation
            "accuracy": float,      # 0.0 - 100.0
            "detail": {
                "correct_count": int,
                "total_count": int,
                "required_accuracy": float,
                "min_correct": int,
                "max_time_seconds": int | None,
                "elapsed_seconds": int | None,
            }
        }
    """
    policy = _effective_pass_policy(course, module)
    accuracy = (correct_count / total_count * 100.0) if total_count > 0 else 0.0

    detail = {
        "correct_count": correct_count,
        "total_count": total_count,
        "required_accuracy": policy.required_accuracy,
        "min_correct": policy.min_correct,
        "max_time_seconds": policy.max_time_seconds,
        "elapsed_seconds": elapsed_seconds,
    }

    # Accuracy check
    if accuracy < policy.required_accuracy:
        return {
            "passed": False,
            "reason": (
                f"Accuracy {accuracy:.1f}% is below required "
                f"{policy.required_accuracy:.1f}%"
            ),
            "accuracy": accuracy,
            "detail": detail,
        }

    # Minimum correct count check
    if correct_count < policy.min_correct:
        return {
            "passed": False,
            "reason": (
                f"Correct count {correct_count} is below required "
                f"{policy.min_correct}"
            ),
            "accuracy": accuracy,
            "detail": detail,
        }

    # Max time check
    if policy.max_time_seconds is not None and elapsed_seconds is not None:
        if elapsed_seconds > policy.max_time_seconds:
            return {
                "passed": False,
                "reason": (
                    f"Elapsed time {elapsed_seconds}s exceeds maximum "
                    f"{policy.max_time_seconds}s"
                ),
                "accuracy": accuracy,
                "detail": detail,
            }

    return {
        "passed": True,
        "reason": "All pass conditions satisfied",
        "accuracy": accuracy,
        "detail": detail,
    }


# ---------------------------------------------------------------------------
# Forced wrong-answer insertion
# ---------------------------------------------------------------------------


def _needs_wrong_answer_review(module: CourseModule) -> bool:
    """Return True if this module triggers a forced wrong_answer_review."""
    if module.type == CourseModuleType.wrong_answer_review:
        return False
    policy = module.pass_policy
    if policy is None:
        return False
    return policy.required_accuracy < 100.0


def insert_forced_wrong_answer_modules(course: CourseV2) -> CourseV2:
    """Return a new CourseV2 with auto-inserted `wrong_answer_review` modules.

    Rule (from PLANnow.md):
      Any module whose `required_accuracy < 100` must have a
      `wrong_answer_review` module inserted after it.

    The inserted wrong_answer_review module:
      - position is immediately after the triggering module
      - flow_policy is always "full" (bypasses flowchart restrictions)
      - max_problems defaults to 10
    """
    new_modules: list[CourseModule] = []
    inserted_count = 0

    for module in course.modules:
        new_modules.append(module)

        if not course.runtime_flags.enable_wrong_answer_auto_insert:
            continue

        if _needs_wrong_answer_review(module):
            inserted_count += 1
            review_id = f"{module.id}_wa_{inserted_count}"
            review_mod = CourseModule(
                id=review_id,
                type=CourseModuleType.wrong_answer_review,
                title=f"오답 복습: {module.title}",
                description="자동 삽입된 오답 복습 모듈입니다.",
                position=module.position,
                estimated_minutes=module.estimated_minutes,
                max_problems=MAX_PROBLEMS_PER_MODULE,
                pass_policy=deepcopy(module.pass_policy),
                flow_policy=FlowPolicy(mode="full", allow_skip=False, allow_back=True),
            )
            new_modules.append(review_mod)

    # Re-assign positions sequentially
    for idx, m in enumerate(new_modules):
        m.position = idx

    # Build a new course (don't mutate the original)
    new_course = course.model_copy(deep=True)
    new_course.modules = new_modules
    return new_course


# ---------------------------------------------------------------------------
# Next-module resolution
# ---------------------------------------------------------------------------


def next_module(
    course: CourseV2,
    current_module_id: Optional[str] = None,
    student_state: Optional[dict[str, Any]] = None,
) -> dict[str, Any]:
    """Determine the next module for a student.

    Args:
        course: the CourseV2 definition.
        current_module_id: the module the student just finished (None = start).
        student_state: optional runtime state dict mapping module_id -> state dict.

    Returns:
        {
            "next_module_id": str | None,
            "next_module": CourseModule | None,
            "status": str,   # "ready", "completed", "locked", "paused"
            "reason": str,
        }
    """
    state = student_state or {}
    modules = course.modules
    if not modules:
        return {
            "next_module_id": None,
            "next_module": None,
            "status": "completed",
            "reason": "Course has no modules",
        }

    # If starting fresh, return the first module
    if current_module_id is None:
        first = modules[0]
        return {
            "next_module_id": first.id,
            "next_module": first,
            "status": "ready",
            "reason": "Starting the course",
        }

    curr_idx = course.index_of(current_module_id)
    if curr_idx == -1:
        return {
            "next_module_id": None,
            "next_module": None,
            "status": "locked",
            "reason": "Current module not found in course",
        }

    # Check if there's a next module
    next_idx = curr_idx + 1
    if next_idx >= len(modules):
        return {
            "next_module_id": None,
            "next_module": None,
            "status": "completed",
            "reason": "All modules completed",
        }

    next_mod = modules[next_idx]

    # Flow policy check: if the next module is a regular (non-wrong_answer_review)
    # module and the course flow_policy is "blocked", we might need to verify
    # the current module passed.  For wrong_answer_review, we always allow
    # access regardless of flowchart restrictions.
    if next_mod.type == CourseModuleType.wrong_answer_review:
        # Bypass all flowchart restrictions for wrong-answer review modules
        return {
            "next_module_id": next_mod.id,
            "next_module": next_mod,
            "status": "ready",
            "reason": "Wrong-answer review module bypasses flow restrictions",
        }

    # For other modules, check whether previous module passed
    curr_state = state.get(current_module_id, {})
    passed = curr_state.get("passed", False)
    course_flow = course.flow_policy.mode

    if not passed and course_flow == "blocked":
        return {
            "next_module_id": None,
            "next_module": None,
            "status": "locked",
            "reason": "Previous module not passed and course flow is blocked",
        }

    return {
        "next_module_id": next_mod.id,
        "next_module": next_mod,
        "status": "ready",
        "reason": "Next module available",
    }


# ---------------------------------------------------------------------------
# Wrong-answer eligibility
# ---------------------------------------------------------------------------


def evaluate_wrong_answer_eligibility(
    wrong_answers: list[dict[str, Any]],
    min_count: int = 1,
) -> dict[str, Any]:
    """Determine whether a student has enough wrong answers to unlock a review.

    Args:
        wrong_answers: list of wrong-answer records (dicts with at least "quest_id").
        min_count: minimum number of wrong answers required.

    Returns:
        {
            "eligible": bool,
            "available_count": int,
            "min_required": int,
            "reason": str,
        }
    """
    available = len(wrong_answers)
    if available >= min_count:
        return {
            "eligible": True,
            "available_count": available,
            "min_required": min_count,
            "reason": f"{available} wrong answers available (>= {min_count})",
        }
    return {
        "eligible": False,
        "available_count": available,
        "min_required": min_count,
        "reason": f"Only {available} wrong answers (need {min_count})",
    }
