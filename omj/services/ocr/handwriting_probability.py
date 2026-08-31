from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass
class TextCandidate:
    """필요 변수: 후보 문자열/신뢰도/엔진.
    작동 원리: Texteller/Qwen 결과를 공통 후보로 묶어 텍스트 선택 시 정합성 점수로 비교한다."""

    text: str
    confidence: float
    source: str


def _normalize(text: str) -> str:
    """필요 변수: 문자열.
    작동 원리: OCR이 자주 섞는 연산자 표기를 정규화해 후보 간 비교 오차를 축소한다."""
    return (
        text.replace("−", "-")
        .replace("－", "-")
        .replace("＋", "+")
        .replace("×", "*")
        .replace("÷", "/")
        .replace("＝", "=")
        .replace("ℓ", "l")
        .strip()
    )


class DiscreteSymbolPrior:
    """필요 변수: 혼동 토큰 사전.
    작동 원리: 1:1이 아닌 기호 혼동을 가중치로 반영해 오탐 위험 텍스트를 보수적으로 점수화한다."""

    def __init__(self) -> None:
        self.token_confusion: dict[str, dict[str, float]] = {
            "0": {"0": 0.86, "O": 0.06, "o": 0.04, "Q": 0.04},
            "1": {"1": 0.82, "l": 0.10, "I": 0.04, "|": 0.04},
            "x": {"x": 0.84, "X": 0.06, "×": 0.05, "*": 0.05},
            "+": {"+": 0.86, "t": 0.06, "ㅅ": 0.04, "X": 0.04},
            "2": {"2": 0.88, "Z": 0.05, "2.": 0.04, "s": 0.03},
            "3": {"3": 0.84, "Z": 0.09, "ε": 0.07},
        }

    def token_score(self, token: str, canonical: str) -> float:
        """필요 변수: 후보 토큰/정답 토큰.
        작동 원리: 후보가 정규 토큰으로 바뀔 확률을 사전 확률로 반환한다."""
        candidates = self.token_confusion.get(canonical)
        if candidates is None:
            return 0.5 if token == canonical else 0.0
        return float(candidates.get(token, candidates.get(token.lower(), 0.0)))

    def sequence_score(self, candidate: str, canonical: str) -> float:
        """필요 변수: 후보 문자열/기준 문자열.
        작동 원리: 길이 정규화된 토큰별 곱을 기하평균으로 계산해 전체 문자열 신뢰도를 산정한다."""
        if not canonical:
            return 0.0
        raw = _normalize(candidate).replace(" ", "")
        fixed = _normalize(canonical).replace(" ", "")
        if not raw or not fixed:
            return 0.0
        length = max(len(raw), len(fixed), 1)
        score = 1.0
        for idx in range(min(len(raw), len(fixed))):
            score *= self.token_score(raw[idx], fixed[idx])
        if len(raw) != len(fixed):
            score *= 0.7 ** abs(len(raw) - len(fixed))
        return score ** (1 / length)


def resolve_with_discrete_prior(
    candidates: list[TextCandidate],
    *,
    baseline_text: str,
    min_confidence: float = 0.7,
    prior_weight: float = 0.25,
) -> dict[str, Any]:
    """필요 변수: 후보 목록.
    작동 원리: 후보 신뢰도와 사전 점수를 결합해 ACCEPT/RETRY_WITH_GUARD/REVIEW_REQUIRED를 반환한다."""
    if not candidates:
        return {"status": "REVIEW_REQUIRED", "text": baseline_text, "reason": "empty_candidates", "candidates": []}

    normalized: list[dict[str, Any]] = []
    prior = DiscreteSymbolPrior()
    for candidate in candidates:
        text = _normalize(candidate.text)
        if not text:
            continue
        if candidate.confidence < min_confidence:
            continue
        prob = prior.sequence_score(text, baseline_text)
        score = (1 - prior_weight) * candidate.confidence + prior_weight * prob
        normalized.append(
            {
                "text": text,
                "source": candidate.source,
                "confidence": candidate.confidence,
                "prior": prob,
                "score": score,
            }
        )

    if not normalized:
        return {"status": "RETRY_WITH_GUARD", "text": baseline_text, "need_manual_review": True, "reason": "low_confidence_candidates", "candidates": []}

    winner = max(normalized, key=lambda item: item["score"])
    if winner["score"] < 0.22:
        return {
            "status": "RETRY_WITH_GUARD",
            "text": winner["text"],
            "need_manual_review": True,
            "score": winner["score"],
            "candidates": normalized,
        }

    return {
        "status": "ACCEPT",
        "text": winner["text"],
        "need_manual_review": False,
        "score": winner["score"],
        "candidates": normalized,
    }
