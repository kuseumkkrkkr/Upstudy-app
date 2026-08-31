from __future__ import annotations
from dataclasses import dataclass
from typing import Any

from k_wolfram_handwriting_probability import TextCandidate, resolve_with_discrete_prior


@dataclass
class HandwriteCandidate:
    """필요 변수: 후보 텍스트와 신뢰도.
    작동 원리: 서로 다른 OCR 엔진 후보를 점수 기반으로 비교해 최종 채점 입력 문자열을 정제한다."""
    text: str
    confidence: float
    source: str


def normalize_formula_text(raw: str) -> str:
    """필요 변수: 원문 텍스트.
    작동 원리: 수식 자주 발생 오탈자를 치환해 Vercel 오탐을 줄인다."""
    if not isinstance(raw, str):
        return ""
    text = raw.replace("—", "-").replace("－", "-").replace("＋", "+")
    text = text.replace("＝", "=").replace("×", "*").replace("÷", "/")
    text = text.replace("𝘌", "E")
    text = text.strip()
    return text


def select_formula_text(
    candidates: list[HandwriteCandidate],
    *,
    min_confidence: float = 0.82,
    min_agreement: float = 0.70,
    fallback_text: str = "",
) -> str:
    """필요 변수: OCR 후보 목록.
    작동 원리: 최고 신뢰도+동의어 보정+중복 동의 규칙으로 최종 문자열을 결정한다."""
    if not candidates:
        return fallback_text

    scored = [c for c in candidates if c.confidence >= min_confidence]
    if not scored:
        # 최소 기준 미달이면 top1으로 가더라도 검증 단계에서 review_required로 처리할 수 있게 둔다.
        scored = sorted(candidates, key=lambda item: item.confidence, reverse=True)[:1]

    normalized = [normalize_formula_text(c.text) for c in scored]
    if not normalized:
        return fallback_text

    # 동의 문자열 빈도 기반으로 가장 안정적인 표기를 선택한다.
    freq: dict[str, int] = {}
    for text in normalized:
        freq[text] = freq.get(text, 0) + 1
    best = max(freq.items(), key=lambda kv: kv[1])[0]
    if len(freq) == 1:
        return best

    top2 = sorted(((k, v) for k, v in freq.items()), key=lambda kv: kv[1], reverse=True)
    if top2[0][1] / max(1, len(scored)) >= min_agreement:
        return top2[0][0]
    return top2[0][0]


def build_retry_plan(
    base_result: str,
    texteller_ok: bool,
    *,
    extra_retry_budget: int = 1,
) -> dict[str, Any]:
    """필요 변수: 기본 채점 문자열, Texteller 성공 유무.
    작동 원리: Vercel 분기 실패 시 2차 보정/수동 검토를 결정해 오류 누출을 줄인다."""
    normalized = normalize_formula_text(base_result)
    if not normalized:
        return {"status": "RETRY", "need_manual_review": True, "retries_left": extra_retry_budget}
    if texteller_ok:
        return {"status": "ACCEPT", "need_manual_review": False, "retries_left": 0}
    # Vercel 신뢰도 저하 구간이면 동의어 보정 + 이산확률 사전 우선순위로 교차확인한다.
    prior_result = resolve_with_discrete_prior(
        [
            TextCandidate(text=base_result, confidence=0.82, source="manual"),
            TextCandidate(text=normalized, confidence=0.90, source="vercel_normalized"),
        ],
        baseline_text=base_result,
        min_confidence=0.75,
    )

    if prior_result["status"] == "ACCEPT":
        return {
            "status": "RETRY_WITH_GUARD",
            "need_manual_review": False,
            "retries_left": max(0, extra_retry_budget),
            "guarded_text": str(prior_result["text"]),
            "prior": prior_result.get("score", 0.0),
        }
    return {"status": "REVIEW_REQUIRED", "need_manual_review": True, "retries_left": 0}
