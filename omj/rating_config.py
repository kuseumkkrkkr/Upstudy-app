from dataclasses import dataclass


@dataclass(frozen=True)
class RatingConfig:
    # 핵심 ELO 변수: K는 모든 정답·오답에 동일하고 DELTA_MAX는 단일 태그 급변을 제한한다.
    K: float = 24.0
    DELTA_MAX: float = 36.0

    # 신뢰도 변수: 태그 시도 신뢰는 C_MAX에서 포화하고 최근성은 TAU_DAYS로 완만하게 감소한다.
    C_MAX: float = 24.0
    TAU_DAYS: float = 21.0

    # Confidence weights
    ALPHA: float = 0.45  # R_u
    BETA: float = 0.30   # R_c
    GAMMA: float = 0.15  # R_r
    DELTA: float = 0.10  # R_t

    # Difficulty normalization anchors
    DIFFICULTY_LOG_CENTER: float = 3.70
    DIFFICULTY_LOG_SCALE: float = 1.20

    # Defaults
    DEFAULT_RATING: float = 1200.0


CONFIG = RatingConfig()
