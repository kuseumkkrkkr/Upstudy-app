import math
from typing import Any, Dict, List, Optional, Tuple

from storage.storage import get_quest
from env_loader import load_env
from services.ai.sam_client import (
    DEFAULT_CHAT_MODEL,
    SAM_API_KEY_ENV,
    chat_completion_text,
    is_sam_configured,
)

load_env()

PERSONA_PROMPT = (
    "너는 여자 과외 선생님이다. 말투는 매우 간결하고 필요한것만 전하며, "
    "학생의 사고를 이끌어내는 소크라테스식 질문을 사용한다. "
    "정답을 바로 말하지 말고, 핵심 개념과 조건을 스스로 설명하게 유도한다."
)

PAIR_SUMMARY_MIN_CHARS = 40
SUMMARY_SNIPPET_LIMIT = 80


def build_test_chat_response(payload: Dict[str, Any]) -> Dict[str, Any]:
    user_message = (payload.get("user_message") or "").strip()
    if not user_message:
        raise ValueError("user_message must not be empty")

    affection = _clamp_int(payload.get("affection", 1), 1, 255)
    attendance_days = max(1, int(payload.get("attendance_days", 1)))
    problem_number = _normalize_optional_text(payload.get("problem_number"))
    solution_notes = _normalize_optional_text(payload.get("solution_notes"))

    quest_id = _normalize_optional_text(payload.get("quest_id"))
    quest = get_quest(quest_id) if quest_id else None
    quest_title = _extract_quest_title(quest)
    quest_tags = _extract_quest_tags(quest)

    learning_ratings = _normalize_ratings(payload.get("learning_ratings") or {})
    recent_pairs = payload.get("recent_pairs") or []
    pair_summary = _summarize_last_pair(recent_pairs)

    attendance_label, attendance_prompt = _attendance_profile(attendance_days)

    prompt = _build_prompt(
        user_message=user_message,
        affection=affection,
        attendance_days=attendance_days,
        attendance_label=attendance_label,
        attendance_prompt=attendance_prompt,
        quest_id=quest_id,
        quest_title=quest_title,
        quest_tags=quest_tags,
        learning_ratings=learning_ratings,
        problem_number=problem_number,
        solution_notes=solution_notes,
        pair_summary=pair_summary,
    )

    assistant_message = _generate_chat_response(prompt)
    input_tokens = _estimate_tokens(prompt)
    output_tokens = _estimate_tokens(assistant_message)
    total_tokens = input_tokens + output_tokens

    return {
        "assistant_message": assistant_message,
        "pair_summary": pair_summary,
        "prompt": prompt,
        "input_token_estimate": input_tokens,
        "output_token_estimate": output_tokens,
        "token_estimate": total_tokens,
    }


def _build_prompt(
    *,
    user_message: str,
    affection: int,
    attendance_days: int,
    attendance_label: str,
    attendance_prompt: str,
    quest_id: Optional[str],
    quest_title: Optional[str],
    quest_tags: List[str],
    learning_ratings: Dict[str, int],
    problem_number: Optional[str],
    solution_notes: Optional[str],
    pair_summary: Optional[str],
) -> str:
    sections: List[str] = [
        PERSONA_PROMPT,
        "규칙: 256 만점은 금지이며 호감도는 1~255 범위로 유지한다.",
        f"호감도: {affection}/256",
        f"연속 출석일수: {attendance_days}일 ({attendance_label})",
        attendance_prompt,
    ]

    if quest_id or quest_title or quest_tags:
        quest_lines = ["문제 정보:"]
        if quest_id:
            quest_lines.append(f"- quest_id: {quest_id}")
        if quest_title:
            quest_lines.append(f"- 제목: {quest_title}")
        if quest_tags:
            quest_lines.append(f"- 해시태그: {', '.join(quest_tags)}")
        if learning_ratings:
            ratings = ", ".join(
                f"{tag}={score}" for tag, score in sorted(learning_ratings.items())
            )
            quest_lines.append(
                f"- 학습 Rating(질문 시에만 참고): {ratings}"
            )
        if problem_number or solution_notes:
            quest_lines.append(
                "- 문제풀이데이터: "
                f"문제번호={problem_number or '미입력'}, "
                f"풀이내역={solution_notes or '미입력'}"
            )
        quest_lines.append(
            "문제를 가져온 뒤에는 반드시 소크라테스식 되묻기를 포함한다."
        )
        sections.append("\n".join(quest_lines))

    if pair_summary:
        sections.append(f"직전 페어 요약: {pair_summary}")

    sections.append(f"사용자 질문: {user_message}")
    sections.append(
        "응답은 짧고 명확하게. 마지막 문장은 반드시 되묻는 질문으로 끝낸다."
    )

    return "\n\n".join(section for section in sections if section)


def _generate_chat_response(prompt: str) -> str:
    if not is_sam_configured():
        raise RuntimeError(f"{SAM_API_KEY_ENV} is not set")

    text = chat_completion_text(
        model=DEFAULT_CHAT_MODEL,
        prompt=prompt,
        temperature=0.7,
        max_tokens=1024,
    ).strip()
    cleaned = _strip_code_fences(text)
    if not cleaned:
        raise RuntimeError("Empty response from model")
    return cleaned


def _strip_code_fences(text: str) -> str:
    if text.startswith("```"):
        text = text.lstrip("`").split("\n", 1)[-1]
    if text.endswith("```"):
        text = text.rsplit("\n", 1)[0]
    return text.strip()


def _attendance_profile(days: int) -> Tuple[str, str]:
    if days <= 7:
        return (
            "1~7일",
            "출석이 막 시작된 단계다. 칭찬을 자주하고 질문은 짧게 이어간다.",
        )
    if days <= 14:
        return (
            "8~14일",
            "습관이 형성되는 단계다. 핵심 근거를 한 줄로 설명하게 유도한다.",
        )
    if days <= 30:
        return (
            "15~30일",
            "안정화 단계다. 풀이 과정을 스스로 말하게 하고 흐름을 점검한다.",
        )
    return (
        "30일 이상",
        "장기 지속 단계다. 반례나 일반화를 질문해 사고 범위를 넓힌다.",
    )


def _summarize_last_pair(pairs: List[Dict[str, Any]]) -> Optional[str]:
    if not pairs:
        return None
    last_pair = pairs[-1] or {}
    user = _normalize_optional_text(last_pair.get("user"))
    assistant = _normalize_optional_text(last_pair.get("assistant"))
    if not user or not assistant:
        return None
    if len(user) + len(assistant) < PAIR_SUMMARY_MIN_CHARS:
        return None
    return (
        f"사용자: {_compact(user, SUMMARY_SNIPPET_LIMIT)} / "
        f"AI: {_compact(assistant, SUMMARY_SNIPPET_LIMIT)}"
    )


def _extract_quest_title(quest: Optional[Dict[str, Any]]) -> Optional[str]:
    if not quest:
        return None
    data = quest.get("data") or {}
    title_value = data.get("quest_title")
    text = _content_to_text(title_value)
    return text or None


def _extract_quest_tags(quest: Optional[Dict[str, Any]]) -> List[str]:
    if not quest:
        return []
    info = quest.get("info") or {}
    tags = info.get("hash_tag") or []
    return [str(tag) for tag in tags if str(tag).strip()]


def _content_to_text(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, dict):
        blocks = value.get("blocks")
        if isinstance(blocks, list):
            return " ".join(
                str(block.get("content", "")).strip()
                for block in blocks
                if isinstance(block, dict) and block.get("content")
            ).strip()
        if "content" in value:
            return str(value.get("content") or "").strip()
    if isinstance(value, list):
        return " ".join(
            str(block.get("content", "")).strip()
            if isinstance(block, dict)
            else str(block).strip()
            for block in value
            if str(block).strip()
        ).strip()
    return str(value).strip()


def _normalize_ratings(raw: Dict[str, Any]) -> Dict[str, int]:
    normalized: Dict[str, int] = {}
    for tag, score in raw.items():
        if tag is None:
            continue
        tag_text = str(tag).strip()
        if not tag_text:
            continue
        try:
            value = int(score)
        except (TypeError, ValueError):
            value = 0
        normalized[tag_text] = _clamp_int(value, 0, 256)
    return normalized


def _normalize_optional_text(value: Any) -> Optional[str]:
    if value is None:
        return None
    text = str(value).strip()
    return text if text else None


def _compact(text: str, limit: int) -> str:
    normalized = " ".join(text.split())
    if len(normalized) <= limit:
        return normalized
    return normalized[:limit].rstrip() + "..."


def _estimate_tokens(text: str) -> int:
    if not text:
        return 0
    return max(1, int(math.ceil(len(text) / 4)))


def _clamp_int(value: Any, min_value: int, max_value: int) -> int:
    try:
        numeric = int(value)
    except (TypeError, ValueError):
        numeric = min_value
    return max(min_value, min(max_value, numeric))
