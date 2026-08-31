from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass
class TextCandidate:
    """필요 변수: 텍스트 후보/신뢰도/엔진.
    작동 원리: Vercel/Texteller 결과를 같은 규격으로 묶어 이산확률 점수로 재선정한다."""
    text: str
    confidence: float
    source: str


def _normalize(text: str) -> str:
    """필요 변수: 문자열.
    작동 원리: 인식기 노이즈가 자주 나는 연산자/기호를 정규화해 후보 비교 편차를 줄인다."""
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
    """필요 변수: 혼동 토큰 집합의 사전확률.
    작동 원리: 후보별 토큰 확률을 곱해 전체 문자열 점수를 계산하고 최종 점수화한다."""

    def __init__(self) -> None:
        self.token_confusion = {
            "0": {"0": 0.86, "O": 0.06, "o": 0.04, "Q": 0.04},
            "1": {"1": 0.82, "l": 0.10, "I": 0.04, "|": 0.04},
            "x": {"x": 0.84, "X": 0.06, "×": 0.05, "*": 0.05},
            "+": {"+": 0.86, "t": 0.06, "ㅅ": 0.04, "X": 0.04},
            "2": {"2": 0.88, "Z": 0.05, "2.": 0.04, "s": 0.03},
            "3": {"3": 0.84, "Z": 0.09, "ε": 0.07},
        }

    def token_score(self, token: str, canonical: str) -> float:
        """필요 변수: 타겟 토큰/정규 토큰.
        작동 원리: 혼동 사전을 기준으로 비대칭 가중치 점수를 반환한다."""
        candidates = self.token_confusion.get(canonical)
        if candidates is None:
            return 0.5 if token == canonical else 0.0
        return float(candidates.get(token, candidates.get(token.lower(), 0.0)))

    def sequence_score(self, candidate: str, canonical: str) -> float:
        """필요 변수: 후보 문자열/기준 문자열.
        작동 원리: 문자열 길이 정규화된 토큰별 사전 확률의 기하평균을 사용한다."""
        if not canonical:
            return 0.0
        raw = candidate.replace(" ", "")
        fixed = canonical.replace(" ", "")
        if not raw or not fixed:
            return 0.0
        L = max(len(raw), len(fixed), 1)
        score = 1.0
        for i in range(min(len(raw), len(fixed))):
            score *= self.token_score(raw[i], fixed[i])
        if len(raw) != len(fixed):
            score *= 0.7 ** abs(len(raw) - len(fixed))
        return (score ** (1 / L))


def resolve_with_discrete_prior(
    candidates: list[TextCandidate],
    *,
    baseline_text: str,
    min_confidence: float = 0.7,
    prior_weight: float = 0.25,
) -> dict[str, Any]:
    """필요 변수: 후보 목록, 베이스텍스트.
    작동 원리: 정규화 점수 + 엔진 신뢰도 + 사전 확률을 가중 결합해 최종 채택 문자열과 로그를 반환한다."""
    if not candidates:
        return {"status": "REVIEW_REQUIRED", "text": baseline_text, "reason": "empty_candidates", "candidates": []}

    normalized = []
    prior = DiscreteSymbolPrior()
    for c in candidates:
        text = _normalize(c.text)
        if not text:
            continue
        if c.confidence < min_confidence and not c.text:
            continue
        prob = prior.sequence_score(text, baseline_text)
        total = (0.75 * c.confidence + 0.25 * prob) if baseline_text else c.confidence
        normalized.append(
            {
                "text": text,
                "source": c.source,
                "confidence": c.confidence,
                "prior": prob,
                "score": total,
            }
        )

    if not normalized:
        return {"status": "REVIEW_REQUIRED", "text": baseline_text, "reason": "low_confidence_candidates", "candidates": []}

    winner = max(normalized, key=lambda item: item["score"])
    if winner["score"] < 0.2:
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
        "score": winner["score"],
        "need_manual_review": False,
        "candidates": normalized,
    }
