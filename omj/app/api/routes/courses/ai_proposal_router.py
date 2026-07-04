"""FastAPI router for AI course proposal.

Endpoints:
- POST /courses/v2/ai/proposal — AI 코스 제안 (비동기 job)

Reference: docs/COURSE_BUILDER_V2_PLAN.md §8.1, §9.2
"""
from __future__ import annotations

from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, Request

from app.api.routes.auth.middleware import require_role
from app.schemas.common import ApiResponse, JobStatus, RejectionReason
from domain.course.v2_models import CourseV2
from services.ai.providers.base import get_default_provider, AIProvider
from services.ai import guard
from services.ai import prompts
from storage.social_storage import get_friends, search_users_by_username

router = APIRouter(prefix="/courses/v2", tags=["courses-v2-ai"])


def _wrap(data: Optional[object], message: Optional[str] = None) -> ApiResponse:
    return ApiResponse(data=data, message=message)


def _agent_tools_spec() -> list[dict[str, Any]]:
    return [
        {
            "name": "list_friend_students",
            "description": "Returns profiles of students that current user added as friends.",
            "input_schema": {
                "type": "object",
                "properties": {
                    "limit": {"type": "integer", "minimum": 1, "maximum": 100},
                },
            },
        },
        {
            "name": "search_students_nickname",
            "description": "Search users by nickname/username.",
            "input_schema": {
                "type": "object",
                "required": ["query"],
                "properties": {
                    "query": {"type": "string"},
                    "limit": {"type": "integer", "minimum": 1, "maximum": 50},
                },
            },
        },
    ]


# ---------------------------------------------------------------------------
# AI Course Proposal
# ---------------------------------------------------------------------------


@router.post("/ai/proposal", response_model=ApiResponse)
async def ai_propose_course(
    request: Request,
    body: dict[str, Any],
    _user=Depends(require_role("teacher", "admin")),
):
    """Generate an AI-proposed CourseV2 based on student OVR and weakness tags.

    Request body:
        {
            "student_ovr": dict,
            "weakness_tags": list[str],
            "available_modules": list[str] (optional),
            "prompt_extra": str (optional),
            "course_title_hint": str (optional)
        }

    Returns:
        ApiResponse with status=done and data containing the proposed course,
        or status=rejected if safety guard blocks the request.
    """
    student_ovr: dict = body.get("student_ovr", {})
    weakness_tags: list[str] = body.get("weakness_tags", [])
    available_modules: list[str] = body.get(
        "available_modules",
        [
            "textbook_view",
            "problem_solve",
            "exam_solve",
            "wrong_answer_review",
            "curriculum_group",
            "challenge_group",
            "level_test",
        ],
    )
    prompt_extra: str = body.get("prompt_extra", "")
    course_title_hint: str = body.get("course_title_hint", "")

    # Safety guard on prompt_extra (free-form text most likely to contain abuse)
    provider = get_default_provider()
    safety = guard.evaluate_request(prompt_extra, provider)
    if not safety["allowed"]:
        reason = safety["reason"]
        if isinstance(reason, RejectionReason):
            return guard.rejected_response(reason)
        return _wrap(None, "Safety guard rejected the request")

    # Build V2 prompt
    prompt = prompts.course_proposal_prompt_v2(
        student_ovr=student_ovr,
        weakness_tags=weakness_tags,
        available_modules=available_modules,
        prompt_extra=prompt_extra,
        course_title_hint=course_title_hint,
    )

    # Call AI with forced JSON output
    try:
        # The SAM-backed provider handles JSON/schema formatting internally.
        raw_response = provider.generate(prompt)

        import json
        if isinstance(raw_response, str):
            proposed = json.loads(raw_response)
        else:
            text = raw_response.get("text") if isinstance(raw_response, dict) else None
            proposed = json.loads(text) if isinstance(text, str) else raw_response

        # Validate proposed course structure
        validation = guard.evaluate_course_request(proposed, provider)
        if not validation["allowed"]:
            reason = validation["reason"]
            if isinstance(reason, RejectionReason):
                return guard.rejected_response(reason)
            return _wrap(None, "Course validation failed")

        return _wrap(
            {
                "proposed_course": proposed,
                "generated_by": getattr(provider, "model_name", "unknown"),
            },
            "AI course proposal generated",
        )

    except Exception as e:
        return ApiResponse(
            status=JobStatus.failed,
            error=str(e),
            message="AI course proposal generation failed",
        )


@router.get("/ai/agent/tools", response_model=ApiResponse)
async def ai_agent_tools(
    _user=Depends(require_role("teacher", "admin")),
):
    return _wrap({"tools": _agent_tools_spec()}, "AI agent tools")


@router.post("/ai/agent/call", response_model=ApiResponse)
async def ai_agent_tool_call(
    request: Request,
    body: dict[str, Any],
    _user=Depends(require_role("teacher", "admin")),
):
    user_id = request.state.user_id
    name = (body.get("tool_name") or "").strip()
    args = body.get("arguments") or {}

    if name == "list_friend_students":
        limit = max(1, min(100, int(args.get("limit") or 30)))
        friends = get_friends(user_id)[:limit]
        return _wrap({"items": friends})

    if name == "search_students_nickname":
        query = (args.get("query") or "").strip()
        if not query:
            return _wrap({"items": []}, "query is empty")
        limit = max(1, min(50, int(args.get("limit") or 20)))
        items = search_users_by_username(query, exclude_user_id=user_id, limit=limit)
        return _wrap({"items": items})

    return _wrap(None, f"Unknown tool: {name}")


@router.post("/ai/agent/propose", response_model=ApiResponse)
async def ai_agent_propose(
    request: Request,
    body: dict[str, Any],
    _user=Depends(require_role("teacher", "admin")),
):
    """Tool-call style curriculum proposal entrypoint.

    Client may first call /ai/agent/tools and /ai/agent/call, then pass tool
    results into this endpoint.
    """
    provider = get_default_provider()
    tool_results = body.get("tool_results") or {}
    prompt_extra = (body.get("prompt_extra") or "").strip()
    weakness_tags = body.get("weakness_tags") or []
    student_ovr = body.get("student_ovr") or {}

    prompt = prompts.course_proposal_prompt_v2(
        student_ovr=student_ovr,
        weakness_tags=weakness_tags,
        available_modules=[
            "textbook_view",
            "problem_solve",
            "exam_solve",
        ],
        prompt_extra=(
            f"{prompt_extra}\n\n[TOOL_RESULTS]\n{tool_results}"
            if tool_results
            else prompt_extra
        ),
        course_title_hint=body.get("course_title_hint") or "",
    )
    try:
        raw = provider.generate(prompt)
        import json
        if isinstance(raw, str):
            proposed = json.loads(raw)
        else:
            text = raw.get("text") if isinstance(raw, dict) else None
            proposed = json.loads(text) if isinstance(text, str) else raw
        return _wrap(
            {
                "proposed_course": proposed,
                "generated_by": getattr(provider, "model_name", "unknown"),
                "tool_mode": True,
            },
            "AI agent proposal generated",
        )
    except Exception as e:
        return ApiResponse(
            status=JobStatus.failed,
            error=str(e),
            message="AI agent proposal generation failed",
        )
