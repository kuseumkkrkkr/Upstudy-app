import json
import math
import os
import random
import sqlite3
import time
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional, Tuple

from google import genai

from env_loader import load_env
from rating_service import fetch_user_rating, fetch_tag_ratings
from storage.storage import DB_PATH
from storage.user_kv_storage import get_user_kv, set_user_kv
from user_habit import list_problem_history

load_env()

BASE_URL = "https://api.cometapi.com"
MODEL_NAME = os.environ.get("OMJ_CHAT_MODEL", "gemini-3.1-flash-lite")
COMETAPI_KEY = os.environ.get("COMETAPI_KEY")

# SQLite helpers ------------------------------------------------------------

def _ensure_table() -> None:
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS serverchat_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            role TEXT NOT NULL,
            message TEXT NOT NULL,
            created_at INTEGER NOT NULL
        )
        """
    )
    cur.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_serverchat_history_user
        ON serverchat_history(user_id, created_at)
        """
    )
    conn.commit()
    conn.close()


def init() -> None:
    _ensure_table()


# Character persistence ----------------------------------------------------

_ALLOWED_CHARACTERS = {"female", "male"}
_DEFAULT_CHARACTER = "female"
_FEMALE_NAMES = ["하린", "소연", "지안", "서윤", "유나", "다연", "지우"]
_MALE_NAMES = ["민준", "지후", "서준", "도윤", "현우", "준호", "윤우"]


def get_character(user_id: str) -> str:
    stored = get_user_kv(user_id, "serverchat_character")
    if stored and stored in _ALLOWED_CHARACTERS:
        return stored
    return _DEFAULT_CHARACTER


def set_character(user_id: str, value: str) -> str:
    value = (value or "").strip().lower()
    if value not in _ALLOWED_CHARACTERS:
        value = _DEFAULT_CHARACTER
    set_user_kv(user_id, "serverchat_character", value)
    return value


def get_character_profile(user_id: str) -> Dict[str, str]:
    character = get_character(user_id)
    name = _get_character_name(user_id, character)
    return {"character": character, "character_name": name}


def _get_character_name(user_id: str, gender: str) -> str:
    key = f"serverchat_character_name::{gender}"
    stored = get_user_kv(user_id, key)
    if stored:
        return stored
    pool = _FEMALE_NAMES if gender == "female" else _MALE_NAMES
    name = random.choice(pool)
    set_user_kv(user_id, key, name)
    return name


# History management -------------------------------------------------------

MessageEntry = Tuple[str, str]


def _append_history(user_id: str, role: str, message: str, max_entries: int = 500) -> None:
    if not message:
        return
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    ts = int(time.time())
    cur.execute(
        "INSERT INTO serverchat_history (user_id, role, message, created_at) VALUES (?, ?, ?, ?)",
        (user_id, role, message, ts),
    )
    cur.execute(
        "SELECT COUNT(1) FROM serverchat_history WHERE user_id = ?",
        (user_id,),
    )
    (count,) = cur.fetchone()
    if count > max_entries:
        overflow = count - max_entries
        cur.execute(
            """
            DELETE FROM serverchat_history
            WHERE id IN (
                SELECT id FROM serverchat_history
                WHERE user_id = ?
                ORDER BY created_at ASC
                LIMIT ?
            )
            """,
            (user_id, overflow),
        )
    conn.commit()
    conn.close()


def load_history(user_id: str, limit: int = 30) -> List[MessageEntry]:
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        SELECT role, message
        FROM serverchat_history
        WHERE user_id = ?
        ORDER BY created_at DESC, id DESC
        LIMIT ?
        """,
        (user_id, max(1, limit)),
    )
    rows = cur.fetchall()
    conn.close()
    rows.reverse()
    return [(row[0], row[1]) for row in rows]


def history_size(user_id: str) -> int:
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("SELECT COUNT(1) FROM serverchat_history WHERE user_id = ?", (user_id,))
    (count,) = cur.fetchone()
    conn.close()
    return int(count)


# Stats computation --------------------------------------------------------

@dataclass
class ChatStats:
    attendance_score: float
    solved_today: int
    accuracy_today: float
    visible_ovr: float
    affection: float
    breakdown: Dict[str, float]


def _parse_iso_date(value: str) -> Optional[datetime]:
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except Exception:
        return None


def _linear(value: float, src_min: float, src_max: float, dst_min: float, dst_max: float) -> float:
    if src_max <= src_min:
        return dst_min
    ratio = (value - src_min) / (src_max - src_min)
    ratio = max(0.0, min(1.0, ratio))
    return dst_min + (dst_max - dst_min) * ratio


def _visible_ovr_from_rating(rating_value: float) -> float:
    # Align with Flutter display: max(rating-1200,0)/128
    return max(0.0, rating_value - 1200.0) / 128.0


def compute_stats(user_id: str) -> ChatStats:
    today = datetime.utcnow().date()
    history = list_problem_history(user_id=user_id, days=7, limit=400)

    unique_days: set[datetime.date] = set()
    solved_today = 0
    for entry in history:
        updated_at = entry.get("updated_at")
        dt = _parse_iso_date(str(updated_at)) if updated_at else None
        if not dt:
            continue
        day = dt.date()
        unique_days.add(day)
        if day == today:
            solved_today += 1

    active_days = len(unique_days)
    attendance_score = 2000.0 * active_days / 7.0  # 0~2000

    rating = fetch_user_rating(user_id)
    accuracy_today = max(0.0, min(1.0, float(rating.recent_accuracy))) * 100.0
    visible_ovr = _visible_ovr_from_rating(float(rating.rating))

    activity_pts = _linear(attendance_score, 0.0, 1400.0, 0.0, 50.0)
    solved_pts = _linear(float(solved_today), 0.0, 50.0, 0.0, 10.0)
    accuracy_pts = _linear(accuracy_today, 0.0, 100.0, 0.0, 10.0)
    ovr_pts = _linear(visible_ovr, 0.0, 256.0, 0.0, 30.0)

    affection = activity_pts + solved_pts + accuracy_pts + ovr_pts
    breakdown = {
        "activity": round(activity_pts, 2),
        "solved_today": round(solved_pts, 2),
        "accuracy": round(accuracy_pts, 2),
        "ovr": round(ovr_pts, 2),
    }

    return ChatStats(
        attendance_score=round(attendance_score, 2),
        solved_today=solved_today,
        accuracy_today=round(accuracy_today, 2),
        visible_ovr=round(visible_ovr, 2),
        affection=round(affection, 2),
        breakdown=breakdown,
    )


def _counseling_payload(user_id: str) -> Dict[str, Any]:
    tags = fetch_tag_ratings(user_id)
    ordered = sorted(tags, key=lambda t: t.get("rating", 0), reverse=True)
    top15 = ordered[:15]
    top100 = ordered[:100]
    rating_sum = sum(t.get("rating", 0.0) for t in top100) or 1.0
    dist = [
        {
            "tag": t.get("tag", ""),
            "ratio": round((t.get("rating", 0.0) / rating_sum) * 100.0, 2),
        }
        for t in top15
    ]
    return {
        "top15": top15,
        "dist": dist,
    }


# Prompt + generation ------------------------------------------------------

_PERSONA = {
    "female": """
너는 다정하지만 솔직한 여자친구 캐릭터다. 상대의 학습을 돕되, 장난스럽게 피드백을 준다.
말투는 친근하고 따뜻하며, 필요할 때는 직설적으로 조언한다.
    """.strip(),
    "male": """
너는 듬직하고 유머러스한 남자친구 캐릭터다. 파트너를 격려하며, 실용적인 힌트를 던진다.
말투는 편안하지만 핵심을 찌르는 질문을 던진다.
    """.strip(),
}


def _mood_instruction(affection: float) -> str:
    if affection >= 75:
        return "호감도가 높아 매우 따뜻하고 적극적으로 칭찬한다."
    if affection >= 50:
        return "호감도가 중간이므로 차분하게 격려하고 필요한 질문을 이어간다."
    if affection >= 30:
        return "호감도가 낮으니 조금은 무덤덤하지만 예의를 지킨다."
    return "호감도가 매우 낮으니 짧고 건조하게 응대하지만 무례하지 않다."


def _summarize_pairs(pairs: List[MessageEntry], max_chars: int = 140) -> List[str]:
    lines: List[str] = []
    for role, msg in pairs[-6:]:
        prefix = "User" if role == "user" else "AI"
        text = msg.replace("\n", " ")
        if len(text) > max_chars:
            text = text[: max_chars - 3] + "..."
        lines.append(f"{prefix}: {text}")
    return lines


def _build_prompt(
    *,
    character: str,
    character_name: str,
    user_message: str,
    stats: ChatStats,
    history: List[MessageEntry],
    quest_title: Optional[str] = None,
    flow: Optional[str] = None,
    ocr: Optional[str] = None,
    mode: str = "chat",
    counseling: Optional[Dict[str, Any]] = None,
) -> str:
    persona = _PERSONA.get(character, _PERSONA[_DEFAULT_CHARACTER])
    persona = f"{character_name}인 {('여자친구' if character=='female' else '남자친구')} 캐릭터. " + persona
    mood = _mood_instruction(stats.affection)
    history_lines = _summarize_pairs(history)
    socratic_goal = (
        "소크라테스식 질문법을 우선한다. 한 번에 한두 문장, 한두 개 질문만 던진다. "
        "사용자 질문 횟수가 10회를 넘었다면, 즉각 핵심 풀이/설명을 자세히 제공한다."
    )
    latex_rule = "수식은 반드시 LaTeX로 표기하고 $$ ... $$ 사이에 넣는다."

    hidden_status = (
        "다음 학습 상태는 사용자가 이미 알고 있다고 가정하고, 숫자나 지표를 직접 말하지 말 것: "
        f"활동점수 {stats.attendance_score:.1f}, 오늘 푼 문제 {stats.solved_today}, 정답률 {stats.accuracy_today:.1f}, "
        f"가시 OVR {stats.visible_ovr:.1f}, 호감도 {stats.affection:.1f}."
    )

    quest_context: List[str] = []
    if quest_title:
        quest_context.append(f"관련 문제 제목: {quest_title}")
    if flow:
        quest_context.append(f"flow 힌트: {flow}")
    if ocr:
        quest_context.append(f"OCR 추출: {ocr}")

    prompt_sections = [
        persona,
        mood,
        hidden_status,
        socratic_goal,
        latex_rule,
    ]
    if quest_context:
        prompt_sections.append("문제 컨텍스트:\n" + "\n".join(f"- {line}" for line in quest_context))
    if mode == "counseling" and counseling:
        top_lines = [
            f"{item.get('tag','')}: {item.get('rating',0):.1f}"
            for item in counseling.get("top15", [])
            if item.get("tag")
        ]
        dist_lines = [
            f"{item.get('tag','')}: {item.get('ratio',0):.1f}%"
            for item in counseling.get("dist", [])
            if item.get("tag")
        ]
        counseling_text = []
        if top_lines:
            counseling_text.append("상위 태그 15개(점수): " + ", ".join(top_lines))
        if dist_lines:
            counseling_text.append("상위 태그 비율 요약: " + ", ".join(dist_lines))
        counseling_text.append("이 정보를 참고해 학습 상담/커리큘럼 제안을 해라. 수치는 말하지 말고 추상적으로 조언.")
        prompt_sections.append("\n".join(counseling_text))
    if mode == "problem":
        prompt_sections.append("지금은 문제 모드다. 사용자가 고른 문제를 중심으로 힌트/설명을 제공하되 단계별로 질문을 던져라.")
    else:
        prompt_sections.append("지금은 일반 대화/상담 모드다.")
    if history_lines:
        prompt_sections.append("최근 대화 요약:\n" + "\n".join(history_lines))
    prompt_sections.append(f"사용자 질문: {user_message}")
    prompt_sections.append("친근하지만 과한 장황함 없이 3~6문장으로 답변한다.")

    return "\n\n".join(section for section in prompt_sections if section)


def _make_client() -> genai.Client:
    if not COMETAPI_KEY:
        raise RuntimeError("COMETAPI_KEY is not set")
    return genai.Client(http_options={"api_version": "v1beta", "base_url": BASE_URL}, api_key=COMETAPI_KEY)


def generate_reply(
    *,
    character: str,
    character_name: str,
    user_message: str,
    stats: ChatStats,
    history: List[MessageEntry],
    quest_title: Optional[str] = None,
    flow: Optional[str] = None,
    ocr: Optional[str] = None,
    mode: str = "chat",
    counseling: Optional[Dict[str, Any]] = None,
) -> str:
    prompt = _build_prompt(
        character=character,
        character_name=character_name,
        user_message=user_message,
        stats=stats,
        history=history,
        quest_title=quest_title,
        flow=flow,
        ocr=ocr,
        mode=mode,
        counseling=counseling,
    )
    client = _make_client()
    response = client.models.generate_content(model=MODEL_NAME, contents=prompt)
    text = (response.text or "").strip()
    if text.startswith("```"):
        text = text.lstrip("`").split("\n", 1)[-1]
    if text.endswith("```"):
        text = text.rsplit("\n", 1)[0]
    cleaned = text.strip()
    if not cleaned:
        raise RuntimeError("Empty response from model")
    return cleaned


# Public entry -------------------------------------------------------------


def handle_chat_message(
    *,
    user_id: str,
    user_message: str,
    character: Optional[str] = None,
    quest_title: Optional[str] = None,
    flow: Optional[str] = None,
    ocr: Optional[str] = None,
    mode: str = "chat",
) -> Dict[str, Any]:
    init()
    character_value = set_character(user_id, character or get_character(user_id))
    character_name = _get_character_name(user_id, character_value)

    stats = compute_stats(user_id)
    recent_history = load_history(user_id, limit=40)
    counseling = _counseling_payload(user_id) if mode == "counseling" else None

    _append_history(user_id, "user", user_message)
    assistant_message = generate_reply(
        character=character_value,
        character_name=character_name,
        user_message=user_message,
        stats=stats,
        history=recent_history,
        quest_title=quest_title,
        flow=flow,
        ocr=ocr,
        mode=mode,
        counseling=counseling,
    )
    _append_history(user_id, "assistant", assistant_message)

    return {
        "assistant_message": assistant_message,
        "affection_score": stats.affection,
        "affection_breakdown": stats.breakdown,
        "character": character_value,
        "character_name": character_name,
        "stats": {
            "attendance_score": stats.attendance_score,
            "solved_today": stats.solved_today,
            "accuracy_today": stats.accuracy_today,
            "visible_ovr": stats.visible_ovr,
        },
        "history_size": history_size(user_id),
        "user_turns": len([1 for role, _ in recent_history if role == "user"]) + 1,
    }


__all__ = [
    "init",
    "get_character",
    "set_character",
    "get_character_profile",
    "handle_chat_message",
    "load_history",
    "history_size",
]

