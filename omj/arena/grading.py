"""LLM이나 OCR을 사용하지 않는 대결장 문자열 채점기."""

from __future__ import annotations

import unicodedata
from typing import Iterable


def normalize_answer(value: object) -> str:
    """필요 변수: 사용자 또는 정답 문자열. UTF-8 NFC 정규화와 양끝 공백 제거만 수행한다."""

    return unicodedata.normalize("NFC", str(value)).strip()


def grade_answer(answer_type: str, submitted: object, accepted_answers: Iterable[object]) -> bool:
    """필요 변수: 문항 유형, 제출값, 허용 정답. 정규화한 문자열의 완전 일치 여부를 반환한다."""

    if answer_type not in {"short", "multiple_choice", "ox"}:
        return False
    normalized = normalize_answer(submitted)
    return bool(normalized) and normalized in {normalize_answer(value) for value in accepted_answers}


def max_attempts(answer_type: str) -> int:
    """필요 변수: 문항 유형. 객관식/OX는 2회, 단답형은 5회의 팀 제출 한도를 반환한다."""

    return 5 if answer_type == "short" else 2
