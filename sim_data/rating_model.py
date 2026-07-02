from __future__ import annotations

import math
import random
from dataclasses import dataclass
from typing import Sequence


RATING_FLOOR = 1200.0
DISPLAY_MAX = 32767.0
OVR_DIVIDER = 128.0


def rating_display_value(rating: float) -> float:
    return min(max(max(rating, RATING_FLOOR) - RATING_FLOOR, 0.0), DISPLAY_MAX)


def rating_to_ovr(rating: float) -> float:
    return rating_display_value(rating) / OVR_DIVIDER


@dataclass(frozen=True)
class ModelParams:
    k_user: float = 18.0
    k_tag: float = 7.0
    expected_scale: float = 420.0
    correct_bonus: float = 4.0
    wrong_penalty_multiplier: float = 1.15
    streak_window: int = 30
    hot_bonus: float = 1.4
    cold_penalty: float = 0.6
    progress_pivot: float = 7000.0
    progress_damping: float = 0.45
    progress_power: float = 1.2
    min_rating: float = 900.0
    max_rating: float = 40000.0


class RatingEngine:
    def __init__(self, params: ModelParams, seed: int) -> None:
        self.params = params
        self.random = random.Random(seed)

    def _expected(self, user_rating: float, tag_rating: float) -> float:
        exponent = (tag_rating - user_rating) / self.params.expected_scale
        return 1.0 / (1.0 + math.pow(10.0, exponent))

    def update(
        self,
        user_rating: float,
        tag_rating: float,
        is_correct: bool,
        recent_window: Sequence[int],
        solved_count: int,
    ) -> tuple[float, float, float]:
        expected = self._expected(user_rating, tag_rating)
        actual = 1.0 if is_correct else 0.0

        user_delta = self.params.k_user * (actual - expected)
        if is_correct:
            user_delta += self.params.correct_bonus
        else:
            user_delta *= self.params.wrong_penalty_multiplier

        if recent_window:
            recent_acc = sum(recent_window) / len(recent_window)
            if recent_acc >= 0.8 and is_correct:
                user_delta += self.params.hot_bonus
            elif recent_acc <= 0.45 and not is_correct:
                user_delta -= self.params.cold_penalty

        # Diminishing return against very large volume, tuned to keep 7k@90% near top tier.
        progress = solved_count / max(1.0, self.params.progress_pivot)
        damping = 1.0 / (1.0 + self.params.progress_damping * math.pow(progress, self.params.progress_power))
        user_delta *= damping

        tag_delta = self.params.k_tag * (expected - actual)

        new_user = min(max(user_rating + user_delta, self.params.min_rating), self.params.max_rating)
        new_tag = min(max(tag_rating + tag_delta, self.params.min_rating), self.params.max_rating)
        return new_user, new_tag, user_delta
