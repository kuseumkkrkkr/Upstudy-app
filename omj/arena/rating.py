"""대결장 전용 Glicko-2 및 팀 기여도 계산 함수."""

from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Iterable


GLICKO_SCALE = 173.7178


@dataclass(frozen=True)
class GlickoRating:
    """필요 변수: rating, deviation, volatility. Glicko-2 한 선수의 상태를 보관한다."""

    rating: float = 1500.0
    deviation: float = 350.0
    volatility: float = 0.06


@dataclass(frozen=True)
class TrueSkillRating:
    """필요 변수: 평균 실력 mu와 불확실성 sigma. 2v2 큐의 개인 상태를 보관한다."""

    mu: float = 25.0
    sigma: float = 25.0 / 3.0


def update_glicko2(
    player: GlickoRating,
    opponents: Iterable[tuple[GlickoRating, float]],
    *,
    tau: float = 0.5,
) -> GlickoRating:
    """필요 변수: 선수 상태와 (상대, 결과) 목록. 공식 Glicko-2 반복식으로 새 상태를 계산한다."""

    games = list(opponents)
    mu = (player.rating - 1500.0) / GLICKO_SCALE
    phi = player.deviation / GLICKO_SCALE
    if not games:
        return GlickoRating(player.rating, math.sqrt(phi * phi + player.volatility**2) * GLICKO_SCALE, player.volatility)

    converted = [((other.rating - 1500.0) / GLICKO_SCALE, other.deviation / GLICKO_SCALE, score) for other, score in games]

    def g(value: float) -> float:
        return 1.0 / math.sqrt(1.0 + 3.0 * value * value / (math.pi * math.pi))

    def expected(other_mu: float, other_phi: float) -> float:
        return 1.0 / (1.0 + math.exp(-g(other_phi) * (mu - other_mu)))

    variance = 1.0 / sum(g(p) ** 2 * expected(m, p) * (1.0 - expected(m, p)) for m, p, _ in converted)
    delta = variance * sum(g(p) * (score - expected(m, p)) for m, p, score in converted)
    a = math.log(player.volatility**2)

    def objective(x: float) -> float:
        exp_x = math.exp(x)
        top = exp_x * (delta * delta - phi * phi - variance - exp_x)
        bottom = 2.0 * (phi * phi + variance + exp_x) ** 2
        return top / bottom - (x - a) / (tau * tau)

    left = a
    if delta * delta > phi * phi + variance:
        right = math.log(delta * delta - phi * phi - variance)
    else:
        step = 1
        while objective(a - step * tau) < 0:
            step += 1
        right = a - step * tau
    f_left, f_right = objective(left), objective(right)
    while abs(right - left) > 1e-6:
        middle = left + (left - right) * f_left / (f_right - f_left)
        f_middle = objective(middle)
        if f_middle * f_right <= 0:
            left, f_left = right, f_right
        else:
            f_left /= 2.0
        right, f_right = middle, f_middle
    volatility = math.exp(left / 2.0)
    pre_phi = math.sqrt(phi * phi + volatility * volatility)
    new_phi = 1.0 / math.sqrt(1.0 / (pre_phi * pre_phi) + 1.0 / variance)
    new_mu = mu + new_phi * new_phi * sum(g(p) * (score - expected(m, p)) for m, p, score in converted)
    return GlickoRating(new_mu * GLICKO_SCALE + 1500.0, new_phi * GLICKO_SCALE, volatility)


def contribution_score(correct_weights: Iterable[float], wrong_weights: Iterable[float]) -> float:
    """필요 변수: 맞힌/틀린 문항 난이도. 정답 합에서 오답 난이도의 10%를 차감한다."""

    return sum(max(0.0, value) for value in correct_weights) - 0.1 * sum(max(0.0, value) for value in wrong_weights)


def update_trueskill_teams(
    team_a: Iterable[TrueSkillRating],
    team_b: Iterable[TrueSkillRating],
    outcome: int,
    *,
    beta: float = 25.0 / 6.0,
) -> tuple[list[TrueSkillRating], list[TrueSkillRating]]:
    """필요 변수: 두 팀 실력과 결과(1=A승, -1=B승, 0=무). TrueSkill 승패 요인으로 mu/sigma를 갱신한다."""

    first, second = list(team_a), list(team_b)
    if outcome == 0:
        return first, second
    variance = sum(item.sigma**2 for item in first + second) + 2.0 * beta * beta
    c = math.sqrt(variance)
    difference = (sum(item.mu for item in first) - sum(item.mu for item in second)) * outcome
    t = difference / c
    pdf = math.exp(-0.5 * t * t) / math.sqrt(2.0 * math.pi)
    cdf = max(1e-12, 0.5 * (1.0 + math.erf(t / math.sqrt(2.0))))
    v = pdf / cdf
    w = v * (v + t)

    def updated(team: list[TrueSkillRating], sign: int) -> list[TrueSkillRating]:
        values = []
        for item in team:
            ratio = item.sigma * item.sigma / variance
            mu = item.mu + sign * outcome * item.sigma * item.sigma / c * v
            sigma = item.sigma * math.sqrt(max(1e-9, 1.0 - ratio * w))
            values.append(TrueSkillRating(mu, sigma))
        return values

    return updated(first, 1), updated(second, -1)


def contribution_multipliers(scores: Iterable[float]) -> list[float]:
    """필요 변수: 팀원별 기여점수. 평균 대비 보정을 ±20% 범위의 배수로 변환한다."""

    values = list(scores)
    if not values:
        return []
    shifted = [value - min(0.0, min(values)) for value in values]
    total = sum(shifted)
    if total <= 1e-9:
        return [1.0] * len(values)
    expected = 1.0 / len(values)
    return [max(0.8, min(1.2, 1.0 + (value / total - expected) * 0.4)) for value in shifted]


def tier_for_rating(rating: float) -> str:
    """필요 변수: 표시 레이팅. 고정 경계에 따라 A~E 티어를 반환한다."""

    if rating >= 2000:
        return "A"
    if rating >= 1750:
        return "B"
    if rating >= 1500:
        return "C"
    if rating >= 1000:
        return "D"
    return "E"
