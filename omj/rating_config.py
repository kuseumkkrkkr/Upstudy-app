from dataclasses import dataclass


@dataclass(frozen=True)
class RatingConfig:
    # Core ELO params
    K: float = 24.0
    K_MIN: float = 16.0
    DELTA_MAX: float = 36.0

    # Confidence params
    U_MAX: float = 2400.0
    C_MAX: float = 24.0
    TAU_DAYS: float = 21.0
    M_LOSE: float = 0.08

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
