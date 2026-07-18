"""LLM이나 OCR을 사용하지 않는 대결장 문자열 채점기."""

from __future__ import annotations

import re
import unicodedata
from decimal import Decimal
from typing import Iterable


_NUMERIC_ANSWER_PATTERN = re.compile(r"^[+-]?(?:\d+(?:\.\d+)?|\.\d+)$")


def normalize_answer(value: object) -> str:
    """필요 변수: 사용자 또는 정답 문자열. UTF-8 NFC 정규화와 양끝 공백 제거만 수행한다."""

    return unicodedata.normalize("NFC", str(value)).strip()


def is_numeric_answer(value: object) -> bool:
    """필요 변수: 단답형 정답. 부호가 있는 정수 또는 소수로 직접 입력 가능한 값인지 판정한다."""

    return bool(_NUMERIC_ANSWER_PATTERN.fullmatch(normalize_answer(value)))


def grade_answer(answer_type: str, submitted: object, accepted_answers: Iterable[object]) -> bool:
    """필요 변수: 문항 유형·제출값·허용 정답. 단답은 Decimal 숫자 비교, 선택형은 문자열 완전 일치로 채점한다."""

    if answer_type not in {"short", "multiple_choice", "ox"}:
        return False
    normalized = normalize_answer(submitted)
    if answer_type == "short":
        if not is_numeric_answer(normalized):
            return False
        submitted_number = Decimal(normalized)
        return submitted_number in {
            Decimal(normalize_answer(value))
            for value in accepted_answers
            if is_numeric_answer(value)
        }
    return bool(normalized) and normalized in {normalize_answer(value) for value in accepted_answers}


def max_attempts(answer_type: str) -> int:
    """필요 변수: 문항 유형. 객관식/OX는 2회, 단답형은 5회의 팀 제출 한도를 반환한다."""

    return 5 if answer_type == "short" else 2
