from __future__ import annotations

import random
from typing import Any, Dict, List, Tuple


def build_multiple_choice_options(answer: int, rng: random.Random) -> Tuple[List[str], int]:
    options = {answer}
    deltas = [-4, -3, -2, -1, 1, 2, 3, 4, 5, -5, 6, -6, 7, -7]
    rng.shuffle(deltas)
    for delta in deltas:
        if len(options) >= 5:
            break
        options.add(answer + delta)

    while len(options) < 5:
        delta = rng.randint(-9, 9)
        if delta == 0:
            continue
        options.add(answer + delta)

    option_list = list(options)
    rng.shuffle(option_list)
    correct_index = option_list.index(answer)
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
    if question_type == "mcq":
        options, correct_index = build_multiple_choice_options(answer, rng)
        data["quest_options"] = options
        data["choice_answer_index"] = correct_index
    else:
        data["quest_options"] = []
    storage_data["data"] = data
