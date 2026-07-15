from __future__ import annotations

import re
from typing import Any, Dict, Iterable, List


_META_LEAK_PATTERNS = (
    "역방향으로 설계",
    "생성된 문제",
    "ai가 생성",
    "프롬프트",
    "문제 생성 과정",
    "정답값을 기준",
)
_ARTIFICIAL_SCAFFOLD_PATTERNS = (
    re.compile(r"참이면\s*[a-z가-힣]\s*=.*거짓이면\s*[a-z가-힣]\s*=", re.IGNORECASE),
    re.compile(r"거짓이면\s*[a-z가-힣]\s*=.*참이면\s*[a-z가-힣]\s*=", re.IGNORECASE),
)
_VAGUE_TITLE_PATTERNS = (
    re.compile(r"정답으로\s*하는\s*값\s*구하기", re.IGNORECASE),
    re.compile(r"정답을\s*만드는\s*문제", re.IGNORECASE),
)
_QUESTION_IN_SOLUTION_PATTERN = re.compile(
    r"구하시오|제\s*몇\s*항|최대\s*정수해|최소\s*정수해|의\s*해(?:\s|$)|인가\?",
    re.IGNORECASE,
)


class StudentProblemContractRejected(ValueError):
    """학생 노출용 내용 또는 구조 계약을 통과하지 못했음을 나타낸다."""


def content_text(value: Any) -> str:
    """필요 변수: 문자열 또는 콘텐츠 블록. 작동 원리: 문제·풀이의 모든 텍스트와 LaTeX를 검수 가능한 한 문자열로 펼친다."""
    if value is None:
        return ""
    if isinstance(value, str):
        return value.strip()
    if isinstance(value, list):
        parts = [content_text(item) for item in value]
        return " ".join(part for part in parts if part).strip()
    if isinstance(value, dict):
        if isinstance(value.get("blocks"), list):
            return content_text(value["blocks"])
        return str(value.get("content") or value.get("text") or "").strip()
    return str(value).strip()


def _all_solution_text(solves: Iterable[object]) -> str:
    """필요 변수: 풀이 단계 목록. 작동 원리: 본선과 분기 풀이의 설명·힌트·정답 해설을 재귀적으로 합친다."""
    parts: List[str] = []
    for raw in solves:
        if not isinstance(raw, dict):
            continue
        for key in ("flow", "hint_riddle", "answer_riddle"):
            text = content_text(raw.get(key))
            if text:
                parts.append(text)
        branches = raw.get("branches")
        if isinstance(branches, list):
            nested = _all_solution_text(branches)
            if nested:
                parts.append(nested)
    return " ".join(parts).strip()


def _direct_answer_leak(title: str, answer: str) -> bool:
    """필요 변수: 문제 본문과 정답. 작동 원리: 짧은 수치 정답이 등식이나 정답 안내 형태로 본문에 직접 노출됐는지 찾는다."""
    compact_answer = re.sub(r"[^0-9+\-./]", "", answer)
    if not compact_answer or len(compact_answer) > 12:
        return False
    escaped = re.escape(compact_answer)
    patterns = (
        rf"(?:x|y|k|n|a|b)\s*=\s*{escaped}(?![0-9])",
        rf"정답(?:은|이|:)\s*\$?{escaped}(?![0-9])",
        rf"{escaped}\s*(?:가|이)\s*되도록",
    )
    return any(re.search(pattern, title, flags=re.IGNORECASE) for pattern in patterns)


def review_student_problem_content(quest: Dict[str, Any]) -> Dict[str, object]:
    """필요 변수: 생성된 문제 전체. 작동 원리: 본문·정답·모든 풀이를 읽어 누락, 생성 메타, 정답 직접 노출을 판정한다."""
    data = quest.get("data") if isinstance(quest.get("data"), dict) else {}
    title = content_text(data.get("quest_title"))
    answer = content_text(data.get("quest_answer"))
    solves = quest.get("solves") if isinstance(quest.get("solves"), list) else []
    solution_text = _all_solution_text(solves)
    combined = f"{title} {solution_text}".casefold()
    reasons: List[str] = []
    if len(title) < 10:
        reasons.append("problem_title_missing_or_too_short")
    if not answer:
        reasons.append("problem_answer_missing")
    if not solves or not solution_text:
        reasons.append("solution_content_missing")
    if any(pattern in combined for pattern in _META_LEAK_PATTERNS):
        reasons.append("generation_metadata_exposed")
    if any(pattern.search(title) for pattern in _ARTIFICIAL_SCAFFOLD_PATTERNS):
        reasons.append("artificial_condition_scaffolding")
    if any(pattern.search(title) for pattern in _VAGUE_TITLE_PATTERNS):
        reasons.append("vague_or_answer_driven_title")
    if answer and _direct_answer_leak(title, answer):
        reasons.append("answer_exposed_in_problem_title")
    return {
        "approved": not reasons,
        "reasons": reasons,
        "title_chars": len(title),
        "solution_chars": len(solution_text),
        "solve_count": len(solves),
    }


def require_student_problem_content(quest: Dict[str, Any]) -> Dict[str, Any]:
    """필요 변수: 생성 문제. 작동 원리: 내용 검수 실패 문제를 학생 응답·캐시 저장 전에 차단한다."""
    result = review_student_problem_content(quest)
    if result["approved"] is not True:
        reasons = ", ".join(str(reason) for reason in result["reasons"])
        raise ValueError(f"student problem content rejected: {reasons}")
    return quest


def review_student_problem_contract(
    quest: Dict[str, Any],
    *,
    expected_solve_count: int,
    expected_tags: Iterable[str],
) -> Dict[str, object]:
    """필요 변수: 생성 문제·목표 풀이 수·목표 태그. 작동 원리: 콘텐츠 검수에 구조 수와 태그 보존 계약을 합쳐 재사용 가능성을 판정한다."""
    content_review = review_student_problem_content(quest)
    reasons = [str(reason) for reason in content_review["reasons"]]
    solves = quest.get("solves") if isinstance(quest.get("solves"), list) else []
    if len(solves) != int(expected_solve_count):
        reasons.append("solve_count_contract_mismatch")
    info = quest.get("info") if isinstance(quest.get("info"), dict) else {}
    data = quest.get("data") if isinstance(quest.get("data"), dict) else {}
    actual_tags = {
        str(tag).strip().lstrip("#").casefold()
        for tag in [*(info.get("hash_tag") or []), *(data.get("hash_tag") or [])]
        if str(tag).strip()
    }
    required_tags = {
        str(tag).strip().lstrip("#").casefold()
        for tag in expected_tags
        if str(tag).strip()
    }
    if actual_tags != required_tags:
        reasons.append("tag_contract_mismatch")
    question_like_steps = 0
    for solve in solves:
        if isinstance(solve, dict) and _QUESTION_IN_SOLUTION_PATTERN.search(content_text(solve.get("flow"))):
            question_like_steps += 1
    if question_like_steps >= 2:
        reasons.append("independent_subproblems_hidden_in_solutions")
    all_text = f"{content_text(data.get('quest_title'))} {_all_solution_text(solves)}".casefold()
    if "구간의분할" in required_tags and "내분" in all_text:
        reasons.append("tag_semantic_collision:구간의분할_vs_내분")
    reasons = list(dict.fromkeys(reasons))
    return {
        **content_review,
        "approved": not reasons,
        "reasons": reasons,
        "expected_solve_count": int(expected_solve_count),
        "actual_solve_count": len(solves),
        "expected_tag_count": len(required_tags),
        "actual_tag_count": len(actual_tags),
    }


def require_student_problem_contract(
    quest: Dict[str, Any],
    *,
    expected_solve_count: int,
    expected_tags: Iterable[str],
) -> Dict[str, Any]:
    """필요 변수: 생성 문제와 구조 계약. 작동 원리: 내용·풀이 수·태그 중 하나라도 어긋난 문제를 저장과 학생 전달 전에 차단한다."""
    result = review_student_problem_contract(
        quest,
        expected_solve_count=expected_solve_count,
        expected_tags=expected_tags,
    )
    if result["approved"] is not True:
        reasons = ", ".join(str(reason) for reason in result["reasons"])
        raise StudentProblemContractRejected(
            "student problem contract rejected: "
            f"{reasons}; solves={result['actual_solve_count']}/{result['expected_solve_count']}; "
            f"tags={result['actual_tag_count']}/{result['expected_tag_count']}"
        )
    return quest
