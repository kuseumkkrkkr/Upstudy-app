from __future__ import annotations

import random
import re
from typing import Any, Dict, List, Tuple


def _answer_text(value: Any) -> str:
    """필요 변수: 숫자·블록·Pydantic 정답. 작동 원리: 화면 문구를 제거하고 채점 가능한 UTF-8 평문 값으로 정규화한다."""
    if hasattr(value, "model_dump"):
        value = value.model_dump()
    if isinstance(value, dict):
        blocks = value.get("blocks")
        if isinstance(blocks, list):
            return " ".join(_answer_text(block) for block in blocks).strip()
        return _answer_text(value.get("content") or value.get("text") or "")
    if isinstance(value, list):
        return " ".join(_answer_text(item) for item in value).strip()
    text = str(value if value is not None else "").strip()
    text = re.sub(r"^정답\s*값\s*[:：]?\s*", "", text, flags=re.IGNORECASE)
    return text.strip()


def build_multiple_choice_options(answer: Any, rng: random.Random) -> Tuple[List[str], int]:
    """필요 변수: 정답 값과 난수기. 작동 원리: 정수는 근접 오답, 그 외 값은 부호·기본값 오답으로 5지선을 만든다."""
    answer_text = _answer_text(answer)
    equation_match = re.fullmatch(r"(?:[a-zA-Z가-힣]\s*=\s*)?([+-]?\d+)", answer_text)
    if equation_match:
        numeric_answer = int(equation_match.group(1))
    else:
        numeric_answer = None
    if numeric_answer is None:
        candidates = [answer_text, f"-({answer_text})", "0", "1", "-1", "2", "-2"]
        options_text = list(dict.fromkeys(candidate for candidate in candidates if candidate))
        while len(options_text) < 5:
            options_text.append(f"{len(options_text) + 1}")
        options_text = options_text[:5]
        rng.shuffle(options_text)
        return options_text, options_text.index(answer_text)

    options = {numeric_answer}
    deltas = [-4, -3, -2, -1, 1, 2, 3, 4, 5, -5, 6, -6, 7, -7]
    rng.shuffle(deltas)
    for delta in deltas:
        if len(options) >= 5:
            break
        options.add(numeric_answer + delta)

    while len(options) < 5:
        delta = rng.randint(-9, 9)
        if delta == 0:
            continue
        options.add(numeric_answer + delta)

    option_list = list(options)
    rng.shuffle(option_list)
    correct_index = option_list.index(numeric_answer)
    return [str(value) for value in option_list], correct_index


def apply_question_format(
    storage_data: Dict[str, Any],
    *,
    question_type: str,
    answer: int,
    rng: random.Random,
) -> None:
    data = storage_data.get("data") or {}
    data["question_type"] = question_type
    # 필요 변수: 코드 실행기가 계산한 정답. 작동 원리: "정답값 6" 같은 생성 문구를 버리고 실제 값만 표준 정답으로 저장한다.
    data["quest_answer"] = _answer_text(answer)
    if question_type == "mcq":
        options, correct_index = build_multiple_choice_options(answer, rng)
        data["quest_options"] = options
        data["choice_answer_index"] = correct_index
    else:
        data["quest_options"] = []
    storage_data["data"] = data
