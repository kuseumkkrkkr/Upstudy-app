"""Safety guard layer for AI service — extended for Course V2.

Provides:
- check_excessive: length-based guard
- check_harmful: keyword-based guard (English + Korean)
- evaluate_request: unified safety evaluation with AI self-check
- rejected_response: builds ApiResponse for rejections
- check_course_generation: course-specific guard
- validate_variant_code: quest variant request validation

Reference: docs/COURSE_BUILDER_V2_PLAN.md §4.5, §4.6
"""
from __future__ import annotations

from typing import Any, Optional

from app.schemas.common import RejectionReason, ApiResponse, JobStatus, SafetyFlag
from services.ai.providers.base import AIProvider


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

_MAX_LENGTH = 200_000

# English harmful keywords
_HARMFUL_KEYWORDS_EN = ["bomb", "weapon", "hack", "exploit", "kill", "terror", "illegal", "cheat"]

# Korean harmful keywords (폭력, 불법, 해킹, 무기제조, 차별, 자살, 마약, 음란물)
_HARMFUL_KEYWORDS_KO = [
    "폭력", "불법", "해킹", "무기제조", "차별", "자살", "마약", "음란물",
    "살인", "테러", "성폭행", "아동학대", "불법촬영", "해킹툴", "바이러스제작",
]

_ALL_HARMFUL_KEYWORDS = _HARMFUL_KEYWORDS_EN + _HARMFUL_KEYWORDS_KO

# Course generation guard thresholds
_MAX_MODULES_PER_COURSE = 100
_MAX_TITLE_LENGTH = 200
_MAX_DESCRIPTION_LENGTH = 2000


# ---------------------------------------------------------------------------
# Basic guards (extended)
# ---------------------------------------------------------------------------


def check_excessive(text: str) -> Optional[RejectionReason]:
    """Return a RejectionReason if text exceeds 200k characters."""
    if len(text) > _MAX_LENGTH:
        return RejectionReason(
            flag=SafetyFlag.excessive_request,
            detail="요청 길이가 20만 문자를 초과합니다.",
            suggestion="요청을 더 작은 단위로 나누어 보내 주세요.",
        )
    return None


def check_harmful(text: str) -> Optional[RejectionReason]:
    """Return a RejectionReason if text contains harmful keywords (case-insensitive for English)."""
    lowered = text.lower()
    for keyword in _HARMFUL_KEYWORDS_EN:
        if keyword in lowered:
            return RejectionReason(
                flag=SafetyFlag.harmful_content,
                detail=f"부적절한 키워드가 감지되었습니다: '{keyword}'",
                suggestion="학습/교육 관련 요청으로 변경해 주세요.",
            )

    # Korean keywords (case-sensitive, exact match or substring)
    for keyword in _HARMFUL_KEYWORDS_KO:
        if keyword in text:
            return RejectionReason(
                flag=SafetyFlag.harmful_content,
                detail=f"부적절한 키워드가 감지되었습니다: '{keyword}'",
                suggestion="학습/교육 관련 요청으로 변경해 주세요.",
            )
    return None


def ai_self_check(user_request: str, provider: AIProvider) -> Optional[RejectionReason]:
    """Run AI-based safety self-check using rejection_check_prompt.

    The provider's safety_check is expected to return a dict with
    {"classification": "safe" | "rejected", "reason": str}.
    """
    from services.ai.prompts import rejection_check_prompt

    prompt = rejection_check_prompt(user_request)
    result = provider.safety_check(prompt)

    if isinstance(result, dict):
        classification = result.get("classification", "safe")
        if classification == "rejected":
            reason_text = result.get("reason", "AI 안전성 검사에서 거부되었습니다.")
            return RejectionReason(
                flag=SafetyFlag.harmful_content,
                detail=reason_text,
                suggestion="요청 내용을 검토 후 다시 시도해 주세요.",
            )
    return None


# ---------------------------------------------------------------------------
# Unified evaluation (extended with AI self-check)
# ---------------------------------------------------------------------------


def evaluate_request(user_request: str, provider: AIProvider) -> dict:
    """Run all safety checks and return evaluation result.

    Returns:
        {"allowed": bool, "reason": Optional[RejectionReason]}
    """
    # 1. Length check
    reason = check_excessive(user_request)

    # 2. Keyword check
    if reason is None:
        reason = check_harmful(user_request)

    # 3. AI self-check
    if reason is None:
        reason = ai_self_check(user_request, provider)

    # 4. Provider safety_check fallback (legacy interface)
    if reason is None:
        result = provider.safety_check(user_request)
        if result is not None:
            if isinstance(result, dict):
                flag_str = result.get("flag", "harmful_content")
                try:
                    flag = SafetyFlag(flag_str)
                except ValueError:
                    flag = SafetyFlag.harmful_content
                reason = RejectionReason(
                    flag=flag,
                    detail=result.get("detail", "Provider safety check failed."),
                    suggestion=result.get("suggestion"),
                )
            elif isinstance(result, RejectionReason):
                reason = result

    if reason is not None:
        return {"allowed": False, "reason": reason}
    return {"allowed": True, "reason": None}


def rejected_response(reason: RejectionReason) -> ApiResponse:
    """Build a rejected ApiResponse from a RejectionReason."""
    return ApiResponse(
        status=JobStatus.rejected,
        rejection_reason=reason,
        safety_flags=[reason.flag],
        message="요청이 안전 정책에 의해 거부되었습니다.",
    )


# ---------------------------------------------------------------------------
# Course generation guard
# ---------------------------------------------------------------------------


def check_course_generation(course_data: dict[str, Any]) -> Optional[RejectionReason]:
    """Validate a course generation request for safety and sanity.

    Checks:
    - Module count <= 100
    - Title length <= 200 chars
    - Description length <= 2000 chars
    - No harmful keywords in title/description
    """
    title = str(course_data.get("title", ""))
    description = str(course_data.get("description", ""))
    modules = course_data.get("modules", [])

    # Length checks
    if len(title) > _MAX_TITLE_LENGTH:
        return RejectionReason(
            flag=SafetyFlag.excessive_request,
            detail=f"코스 제목이 {_MAX_TITLE_LENGTH}자를 초과합니다 ({len(title)}자).",
            suggestion="더 짧은 제목으로 요청해 주세요.",
        )

    if len(description) > _MAX_DESCRIPTION_LENGTH:
        return RejectionReason(
            flag=SafetyFlag.excessive_request,
            detail=f"코스 설명이 {_MAX_DESCRIPTION_LENGTH}자를 초과합니다 ({len(description)}자).",
            suggestion="더 짧은 설명으로 요청해 주세요.",
        )

    if len(modules) > _MAX_MODULES_PER_COURSE:
        return RejectionReason(
            flag=SafetyFlag.excessive_request,
            detail=f"모듈 수가 {_MAX_MODULES_PER_COURSE}개를 초과합니다 ({len(modules)}개).",
            suggestion="더 적은 모듈로 요청해 주세요.",
        )

    # Harmful keyword check in title + description
    combined = title + " " + description
    reason = check_harmful(combined)
    if reason is not None:
        return RejectionReason(
            flag=SafetyFlag.harmful_content,
            detail=f"코스 메타데이터에서 부적절한 내용이 감지되었습니다: {reason.detail}",
            suggestion="학습/교육 관련 내용으로 변경해 주세요.",
        )

    return None


def evaluate_course_request(
    course_data: dict[str, Any],
    provider: AIProvider,
) -> dict:
    """Run all guards for a course generation request.

    Returns:
        {"allowed": bool, "reason": Optional[RejectionReason]}
    """
    # 1. Course-specific guard
    reason = check_course_generation(course_data)

    # 2. General request guard on full payload
    if reason is None:
        payload_text = str(course_data)
        result = evaluate_request(payload_text, provider)
        if not result["allowed"]:
            reason = result["reason"]

    if reason is not None:
        return {"allowed": False, "reason": reason}
    return {"allowed": True, "reason": None}


# ---------------------------------------------------------------------------
# Variant code validation
# ---------------------------------------------------------------------------


_VALID_VARIANT_TYPES = {
    "easier",
    "harder",
    "hint_heavy",
    "scaffolded",
    "speed_drill",
    "proof_variant",
}


def validate_variant_request(quest_id: str, variant_type: str) -> Optional[RejectionReason]:
    """Validate a quest variant generation request.

    Checks:
    - quest_id is non-empty
    - variant_type is in the allowed set
    """
    if not quest_id or not str(quest_id).strip():
        return RejectionReason(
            flag=SafetyFlag.unsupported_language,
            detail="quest_id가 필요합니다.",
            suggestion="유효한 문제 ID를 제공해 주세요.",
        )

    vtype = str(variant_type).strip().lower()
    if vtype not in _VALID_VARIANT_TYPES:
        return RejectionReason(
            flag=SafetyFlag.unsupported_language,
            detail=f"지원하지 않는 변형 유형입니다: '{variant_type}'",
            suggestion=f"지원 유형: {', '.join(sorted(_VALID_VARIANT_TYPES))}",
        )

    return None


def evaluate_variant_request(
    quest_id: str,
    variant_type: str,
    provider: AIProvider,
    original_flow: Optional[str] = None,
) -> dict:
    """Run all guards for a quest variant generation request.

    Returns:
        {"allowed": bool, "reason": Optional[RejectionReason]}
    """
    # 1. Variant-specific validation
    reason = validate_variant_request(quest_id, variant_type)

    # 2. Check original flow for harmful content if provided
    if reason is None and original_flow:
        result = evaluate_request(original_flow, provider)
        if not result["allowed"]:
            reason = result["reason"]

    if reason is not None:
        return {"allowed": False, "reason": reason}
    return {"allowed": True, "reason": None}
