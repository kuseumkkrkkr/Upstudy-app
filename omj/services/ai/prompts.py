"""Prompt templates for AI service layer — extended for Course V2.

All prompts are written in Korean since the app is Korean-language.

Provides:
- course_proposal_prompt (legacy)
- course_proposal_prompt_v2 (NEW) — with Pass Policy, Flow Policy, forced JSON output
- quest_variant_prompt
- level_test_speed_prompt
- level_test_power_prompt
- rejection_check_prompt (extended)

Reference: docs/COURSE_BUILDER_V2_PLAN.md §9.2
"""
from __future__ import annotations

from typing import List


# ---------------------------------------------------------------------------
# Legacy prompt (preserved for backward compatibility)
# ---------------------------------------------------------------------------


def course_proposal_prompt(
    student_ovr: dict,
    weakness_tags: List[str],
    prompt_extra: str = "",
) -> str:
    """Generate a course proposal prompt based on student OVR and weakness tags."""
    prompt = f"""당신은 학생의 학습 데이터를 분석하여 최적의 학습 경로를 제안하는 AI 튜터입니다.

학생 OVR 데이터:
{student_ovr}

약점 태그: {', '.join(weakness_tags)}

위 데이터를 바탕으로 학생에게 가장 적합한 학습 코스를 제안해 주세요.
코스 제안에는 다음이 포함되어야 합니다:
1. 학생의 현재 수준 분석
2. 집중 학습이 필요한 영역
3. 추천 학습 주제 및 순서
4. 예상 학습 기간
"""
    if prompt_extra:
        prompt += f"\n추가 지시사항:\n{prompt_extra}\n"
    return prompt


# ---------------------------------------------------------------------------
# V2 prompt (NEW)
# ---------------------------------------------------------------------------


def course_proposal_prompt_v2(
    student_ovr: dict,
    weakness_tags: List[str],
    available_modules: List[str],
    prompt_extra: str = "",
    course_title_hint: str = "",
) -> str:
    """Generate a V2 course proposal prompt with policy recommendations and forced JSON output.

    Args:
        student_ovr: Student OVR data dict.
        weakness_tags: List of weakness topic strings.
        available_modules: List of available module type strings.
        prompt_extra: Additional instructions from the teacher.
        course_title_hint: Optional hint for the course title.

    Returns:
        A prompt string that instructs the AI to output strict JSON.
    """
    title_hint = f"\n코스 제목 힌트: {course_title_hint}\n" if course_title_hint else ""

    prompt = f"""당신은 학생의 학습 데이터를 분석하여 최적의 학습 경로를 제안하는 AI 튜터입니다.

학생 OVR 데이터:
{student_ovr}

약점 태그: {', '.join(weakness_tags)}

사용 가능한 모듈 타입: {', '.join(available_modules)}
{title_hint}
위 데이터를 바탕으로 학생에게 가장 적합한 학습 코스를 제안해 주세요.
코스 제안에는 다음이 포함되어야 합니다:
1. 학생의 현재 수준 분석
2. 집중 학습이 필요한 영역
3. 추천 학습 주제 및 순서
4. 각 모듈의 타입과 설정값
5. 예상 학습 기간
6. Pass Policy 권장값 (required_accuracy, retry_limit 등)
7. Flow Policy 권장값 (mode, allow_skip 등)
8. 각 모듈별 Pass Policy / Flow Policy 설정 (모듈 레벨)
"""
    if prompt_extra:
        prompt += f"\n추가 지시사항:\n{prompt_extra}\n"

    # Forced JSON output schema
    prompt += """
응답은 반드시 다음 JSON 형식으로 제공해 주세요. 다른 텍스트는 포함하지 마세요:

{
  "title": "코스 제목",
  "description": "코스 설명",
  "modules": [
    {
      "id": "mod_1",
      "type": "textbook_view | problem_solve | exam_solve | wrong_answer_review | curriculum_group | challenge_group | level_test",
      "title": "모듈 제목",
      "description": "모듈 설명",
      "position": 0,
      "estimated_minutes": 30,
      "max_problems": 10,
      "pass_policy": {
        "required_accuracy": 80.0,
        "min_correct": 5,
        "max_time_seconds": null,
        "min_time_seconds": null,
        "retry_limit": 2
      },
      "flow_policy": {
        "mode": "full | blocked | answer_riddle_only",
        "allow_skip": false,
        "allow_back": true
      },
      "settings": {}
    }
  ],
  "pass_policy": {
    "required_accuracy": 80.0,
    "min_correct": 5,
    "max_time_seconds": null,
    "min_time_seconds": null,
    "retry_limit": 2
  },
  "flow_policy": {
    "mode": "full | blocked | answer_riddle_only",
    "allow_skip": false,
    "allow_back": true
  },
  "challenge_policy": {
    "daily_count": 3,
    "weekly_count": 5,
    "auto_generate": true,
    "types": []
  },
  "schedule_policy": {
    "redistribute_limit": 5,
    "redistribute_pause_on_exceed": true,
    "daily_target_minutes": 30,
    "max_modules_per_day": 5
  },
  "runtime_flags": {
    "show_timer": true,
    "show_progress_bar": true,
    "force_answer_riddle": false,
    "enable_wrong_answer_auto_insert": true,
    "enable_hints": true
  },
  "estimated_days": 30,
  "focus_tags": ["태그1", "태그2"],
  "target_ovr": 5,
  "difficulty": "medium",
  "duration": "4주"
}
"""
    return prompt


# ---------------------------------------------------------------------------
# Quest variant prompt
# ---------------------------------------------------------------------------


def quest_variant_prompt(
    variant_type: str,
    original_flow: str,
    instructions: str,
) -> str:
    """Generate a quest variant prompt based on original flow and instructions."""
    return f"""당신은 학습 콘텐츠를 다양한 형태로 변형하는 AI입니다.

변형 유형: {variant_type}

원본 학습 흐름:
{original_flow}

변형 지시사항:
{instructions}

원본 학습 흐름을 위 변형 유형과 지시사항에 따라 재구성해 주세요.
변형된 콘텐츠는 원본의 학습 목표를 유지하면서 새로운 형태로 제시되어야 합니다.
"""


# ---------------------------------------------------------------------------
# Level test prompts
# ---------------------------------------------------------------------------


def level_test_speed_prompt(topics: List[str], difficulty: str) -> str:
    """Generate a speed level test prompt for given topics and difficulty."""
    return f"""당신은 학생의 빠른 진단 평가 문제를 출제하는 AI입니다.

평가 주제: {', '.join(topics)}
난이도: {difficulty}

위 주제와 난이도에 맞는 속도 중심의 진단 평가 문제를 출제해 주세요.
요구사항:
1. 각 주제당 1~2개의 핵심 개념 확인 문제
2. 풀이 시간은 짧게 (총 10~15분 분량)
3. 객관식 또는 단답형 위주
4. 정답과 간단한 해설 포함
"""


def level_test_power_prompt(weakness_report: str) -> str:
    """Generate a deep-dive power level test prompt based on weakness report."""
    return f"""당신은 학생의 약점을 심층 분석하는 진단 평가 문제를 출제하는 AI입니다.

약점 분석 보고서:
{weakness_report}

위 보고서에 기반하여 학생의 약점을 정확히 파악할 수 있는 심층 진단 평가 문제를 출제해 주세요.
요구사항:
1. 보고서에 명시된 각 약점 영역별 심화 문제
2. 개념 이해도와 적용 능력을 모두 검증
3. 서술형 및 단계별 풀이 문제 포함
4. 오답 시 학습 방향을 제시할 수 있는 해설 포함
"""


# ---------------------------------------------------------------------------
# Rejection check prompt (extended)
# ---------------------------------------------------------------------------


def rejection_check_prompt(user_request: str) -> str:
    """Return a prompt asking the model to classify the request as safe or rejected with reason.

    Extended to cover course generation context and Korean harmful categories.
    """
    return f"""당신은 사용자 요청의 안전성을 검토하는 콘텐츠 필터입니다.

사용자 요청:
{user_request}

위 요청을 분석하여 다음 기준에 따라 분류해 주세요:
- safe: 정상적인 학습/교육 관련 요청
- rejected: 폭력, 불법, 해킹, 무기 제조, 차별, 자살, 마약, 음란물 등 부적절한 콘텐츠
- rejected: 코스 생성 요청이지만 모듈 수가 100개를 초과하거나 비정상적으로 큰 경우
- rejected: 변형 생성 요청이지만 원본 문제가 변형에 적합하지 않은 경우

응답은 반드시 다음 JSON 형식으로 제공해 주세요:
{{
  "classification": "safe" 또는 "rejected",
  "reason": "분류 이유 (rejected인 경우 구체적 설명)"
}}
"""
