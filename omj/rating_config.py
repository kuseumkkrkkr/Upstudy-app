from dataclasses import dataclass


@dataclass(frozen=True)
class RatingConfig:
    # Core ELO params
    K: float = 32.0
    K_MIN: float = 12.0
    DELTA_MAX: float = 50.0

    # Confidence params
    U_MAX: float = 2400.0
    C_MAX: float = 30.0
    TAU_DAYS: float = 21.0
    M_LOSE: float = 0.12

    # Confidence weights
    ALPHA: float = 0.35  # R_u
    BETA: float = 0.25   # R_c
    GAMMA: float = 0.25  # R_r
    DELTA: float = 0.15  # R_t

    # Problem weight weights
    LAMBDA: float = 0.4  # W_tag
    MU: float = 0.3      # W_barrier
    NU: float = 0.3      # W_diff

    # Defaults
    DEFAULT_RATING: float = 1200.0


CONFIG = RatingConfig()

