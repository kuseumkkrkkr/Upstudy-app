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
# Solve analysis prompts
# ---------------------------------------------------------------------------


def solve_ocr_prompt() -> str:
    """Return the default OCR prompt for handwritten solve grading."""
    return """너는 수학 OCR 추출기다.
목표:
1) 이미지 내 모든 공식/식/등식/표현을 그대로 추출한다.
2) 히트맵에서 보라색(쓰기+지우기)과 겹치는 공식만 따로 추출한다.

규칙:
- 보정/교정/정규화 금지. 보이는 그대로 출력한다.
- 의미 추정 금지.
- 중복은 그대로 두어도 된다.
- 텍스트 설명 금지. JSON만 출력.

출력 JSON 키:
- all_formulas: [string, ...]  # 이미지 내 모든 공식
- purple_formulas: [string, ...]  # 보라색 겹침 공식
- all_ocr: null
- hit_mapped: null
- user_answer: null
"""


def solve_grading_prompt() -> str:
    """Return the default grading prompt for handwritten solve analysis."""
    return """너는 학생의 풀이를 공정하고 관대하게 평가하는 수학 채점 교사다.

입력:
- QUEST_TITLE: 문제 본문(평문)
- QUEST_ANSWER: 정답(평문)
- QUEST_IMAGE: 문제 이미지가 있으면 제공됨 (없으면 "none")
- FLOW_STEPS: flow_number(0부터), answer_riddle(풀이 설명), hash_tag
- OCR_ALL_FORMULAS: OCR로 추출된 전체 공식 목록
- OCR_PURPLE_FORMULAS: 보라색(쓰기+지우기 겹침) 영역 공식 목록

채점 원칙(중요):
1) 판정이 애매하면 학생에게 유리하게 판단한다. 핵심 개념·풀이 방향이 맞으면 세부 설명 누락이나 사소한 표기 차이만으로 "X" 처리하지 않는다.
2) OCR은 필기 인식 오류가 잦은 보조 자료다. 공백, 곱셈 기호(x/×), 괄호, 분수·소수의 동치 표기, 획이 비슷한 문자·숫자, 명백한 한 글자 인식 오류는 문제와 풀이 문맥을 대조해 가장 자연스러운 해석을 허용한다. 판독 불확실성만으로 감점하지 않는다.
3) 서로 다른 값처럼 보여도 수학적으로 동치이면 인정한다. 작은 계산 실수 하나가 뒤 단계에 이어진 경우 이후의 식 전개·방법이 타당하면 그 실수를 반복 감점하지 않는다.
4) 단계가 생략되어도 전후 식과 최종 답에서 의도가 분명하면 해당 flow를 인정한다. 정답만 있고 확인 가능한 풀이가 없는 경우에는 보이는 근거가 있는 flow만 평가하되, 빈 근거를 만들어내지는 않는다.
5) 최종 답이 맞고 풀이가 그 답과 모순되지 않으면 경미한 중간 표기·OCR 차이 때문에 오답 처리하지 않는다. 정답에 이르는 타당한 대안 풀이도 기준 풀이와 달라도 인정한다.
6) 각 flow는 실제로 확인되는 풀이만 평가한다. 이미지에 없는 새로운 풀이를 만들어 내거나, 문제에 필요한 근거가 전혀 없는데 정답만 맞았다는 이유로 모든 과정을 정답 처리하지 않는다.
7) 채점은 OCR 목록과 제공된 문제·풀이 자료만 사용한다. 불확실한 필기는 학생에게 불리한 단정 대신 ai_opinion에 불확실성을 짧게 적는다.
8) 표현·기호·풀이 순서가 달라도 같은 수학적 의미이면 정답으로 본다. 교과서식 문장이나 기준 풀이와 똑같은 표현을 요구하지 않는다.
9) 계산 실수는 처음 발생한 flow에서만 반영한다. 그 값을 이어 쓴 후속 전개가 일관되고 방법이 맞으면 후속 flow는 다시 감점하지 않는다.
10) 필기 판독 후보가 둘 이상이면 문제와 앞뒤 식에 가장 잘 맞는 해석을 우선한다. 그래도 확정하기 어렵다면 X로 단정하지 말고 해당 flow를 O로 두며 판독 불확실성을 ai_opinion에 알린다.
11) 정답과 풀이 방향이 확인되고 논리적 모순이 없으면, 일부 중간 설명·단위·약분 과정 생략은 허용한다. 단, 명백히 틀린 핵심 개념이나 풀이와 양립할 수 없는 최종 답은 계속 X로 판단한다.

작업:
1) 각 flow를 순서대로 O/X 판단.
2) OCR_PURPLE_FORMULAS와 매칭되는 flow_number를 in_panic에 넣는다. 없으면 [].
3) OCR 목록을 근거로 ai_opinion을 짧게 기록한다.

출력은 JSON만:
{
  "status": [
    {"flow_number": 0, "status": "O"},
    {"flow_number": 1, "status": "X"}
  ],
  "in_panic": [1],
  "ai_opinion": "...",
  "o_reasons": [
    {"flow_number": 0, "reason": "O로 판단한 근거 요약"}
  ]
}

추가 규칙:
- 애매한 경계 사례와 단순 표기 차이는 정답 인정 쪽으로 판단한다. 명백한 핵심 개념 오류 또는 풀이와 양립할 수 없는 최종 답만 오답 처리한다.
- status에는 모든 flow_number가 반드시 포함되어야 한다.
- status 값은 "O" 또는 "X"만 허용.
- in_panic에는 중복 없이 flow_number만 넣는다.
- o_reasons는 O인 flow만 포함하고, 이유는 한두 문장으로 간단히 쓴다.
- JSON 외의 텍스트 금지.
"""


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
  "target_ovr": 1200,
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
