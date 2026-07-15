import json
import math
import random
import statistics
import sys
from collections import defaultdict, deque
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

ROOT_DIR = Path(__file__).resolve().parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

import rating_service


DEFAULT_STUDENT_COUNT = 2000
DEFAULT_ATTEMPTS_PER_STUDENT = 120
DEFAULT_SEEDS = (7, 21, 42)


@dataclass(frozen=True)
class QuestProfile:
    difficulty: float
    main_huddle: float
    flow_rate: float
    tags: tuple[str, ...]


@dataclass
class StudentState:
    rating: float = 1200.0
    lose_streak: int = 0
    recent_results: deque[int] = None
    tag_attempts: dict[str, int] = None
    tag_ratings: dict[str, float] = None

    def __post_init__(self) -> None:
        if self.recent_results is None:
            self.recent_results = deque(maxlen=50)
        if self.tag_attempts is None:
            self.tag_attempts = defaultdict(int)
        if self.tag_ratings is None:
            self.tag_ratings = {}


@dataclass(frozen=True)
class DifficultyProfile:
    center: float
    scale: float


@dataclass(frozen=True)
class SimulationSummary:
    name: str
    mean_rating: float
    rating_stddev: float
    min_rating: float
    max_rating: float
    correlation_with_true_skill: float


def clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def pearson(xs: Iterable[float], ys: Iterable[float]) -> float:
    xs = list(xs)
    ys = list(ys)
    x_mean = statistics.mean(xs)
    y_mean = statistics.mean(ys)
    x_std = statistics.pstdev(xs)
    y_std = statistics.pstdev(ys)
    if x_std <= 0 or y_std <= 0:
        return 0.0
    cov = sum((x - x_mean) * (y - y_mean) for x, y in zip(xs, ys)) / len(xs)
    return cov / (x_std * y_std)


def generate_synthetic_quest_profiles(seed: int = 20260702, count: int = 600) -> list[QuestProfile]:
    rng = random.Random(seed)
    tag_pool = (
        "함수",
        "수열",
        "로그",
        "지수",
        "미분",
        "적분",
        "확률",
        "통계",
        "기하",
        "삼각함수",
        "방정식",
        "부등식",
    )

    profiles: list[QuestProfile] = []
    for _ in range(count):
        bucket = rng.random()
        if bucket < 0.25:
            difficulty = rng.uniform(6.0, 18.0)
            main_huddle = 1.0
            flow_rate = rng.uniform(2.0, 4.0)
        elif bucket < 0.70:
            difficulty = rng.uniform(18.0, 55.0)
            main_huddle = rng.choice((1.0, 2.0))
            flow_rate = rng.uniform(3.0, 6.0)
        elif bucket < 0.93:
            difficulty = rng.uniform(55.0, 95.0)
            main_huddle = rng.choice((2.0, 3.0))
            flow_rate = rng.uniform(5.0, 9.0)
        else:
            difficulty = rng.uniform(95.0, 140.0)
            main_huddle = 3.0
            flow_rate = rng.uniform(8.0, 14.0)

        tag_count = rng.choices((1, 2, 3, 4), weights=(30, 38, 22, 10), k=1)[0]
        tags = tuple(rng.sample(tag_pool, k=tag_count))
        profiles.append(
            QuestProfile(
                difficulty=difficulty,
                main_huddle=main_huddle,
                flow_rate=flow_rate,
                tags=tags,
            )
        )
    return profiles


def build_difficulty_profile(quests: list[QuestProfile]) -> DifficultyProfile:
    logged = sorted(math.log1p(quest.difficulty) for quest in quests)
    center = statistics.median(logged)
    q1 = logged[len(logged) // 4]
    q3 = logged[(len(logged) * 3) // 4]
    scale = max(0.15, q3 - q1)
    return DifficultyProfile(center=center, scale=scale)


def difficulty_signal(difficulty: float, profile: DifficultyProfile) -> float:
    return (math.log1p(max(0.0, difficulty)) - profile.center) / profile.scale


def baseline_problem_rating(difficulty: float, barrier: float, _: DifficultyProfile) -> float:
    return clamp(1000.0 + 40.0 * difficulty + 30.0 * barrier, 800.0, 2200.0)


def baseline_problem_weight(difficulty: float, barrier: float, _: DifficultyProfile) -> float:
    return 0.4 + 0.3 * (barrier / 10.0) + 0.3 * (difficulty / 10.0)


def tuned_problem_rating(difficulty: float, barrier: float, profile: DifficultyProfile) -> float:
    signal = difficulty_signal(difficulty, profile)
    return clamp(1080.0 + 180.0 * signal + 24.0 * barrier, 900.0, 1700.0)


def tuned_problem_weight(difficulty: float, barrier: float, profile: DifficultyProfile) -> float:
    signal = difficulty_signal(difficulty, profile)
    return clamp(0.82 + 0.12 * signal + 0.03 * barrier, 0.75, 1.25)


def expected_score(user_rating: float, problem_rating: float) -> float:
    return 1.0 / (1.0 + 10 ** ((problem_rating - user_rating) / 400.0))


def true_problem_rating(quest: QuestProfile, profile: DifficultyProfile) -> float:
    signal = difficulty_signal(quest.difficulty, profile)
    return 1200.0 + 140.0 * signal + 55.0 * (quest.main_huddle - 2.0) + 10.0 * (quest.flow_rate - 5.0)


def true_correct_probability(student_skill: float, problem_skill: float) -> float:
    return 1.0 / (1.0 + 10 ** ((problem_skill - student_skill) / 180.0))


def run_algorithm(
    *,
    name: str,
    quests: list[QuestProfile],
    profile: DifficultyProfile,
    true_skills: list[float],
    seed: int,
) -> SimulationSummary:
    rng = random.Random(seed)
    states = [StudentState() for _ in true_skills]

    for _ in range(DEFAULT_ATTEMPTS_PER_STUDENT):
        for index, student_skill in enumerate(true_skills):
            quest = rng.choice(quests)
            probability = true_correct_probability(student_skill, true_problem_rating(quest, profile))
            is_correct = 1 if rng.random() < probability else 0
            state = states[index]

            barrier = rating_service.compute_barrier([], quest.main_huddle)

            if name == "baseline":
                k_factor = max(12.0, 32.0 * math.exp(-0.12 * max(0, state.lose_streak)))
                problem_rating = baseline_problem_rating(quest.difficulty, barrier, profile)
                problem_weight = baseline_problem_weight(quest.difficulty, barrier, profile)
                user_signal = clamp(state.rating / 2400.0, 0.0, 1.0)
                attempt_scale = 30.0
                confidence = (
                    0.35 * user_signal
                    + 0.25 * (sum(state.recent_results) / len(state.recent_results) if state.recent_results else 0.5)
                    + 0.15 * 1.0
                )
                beta_weight = 0.25
                delta_cap = 50.0
            else:
                k_factor = rating_service.compute_k_factor(state.lose_streak)
                problem_rating = tuned_problem_rating(quest.difficulty, barrier, profile)
                problem_weight = tuned_problem_weight(quest.difficulty, barrier, profile)
                user_signal = 1.0
                attempt_scale = 24.0
                confidence = (
                    0.45 * user_signal
                    + 0.15 * (sum(state.recent_results) / len(state.recent_results) if state.recent_results else 0.5)
                    + 0.10 * 1.0
                )
                beta_weight = 0.30
                delta_cap = 36.0

            delta_total = 0.0
            unique_tags = tuple(dict.fromkeys(quest.tags))
            per_tag_weight = 1.0 / max(1, len(unique_tags))

            for tag in unique_tags:
                attempts = state.tag_attempts[tag] + 1
                attempt_signal = clamp(attempts / attempt_scale, 0.0, 1.0)
                effective_confidence = (confidence + beta_weight * attempt_signal)
                delta = k_factor * (is_correct - expected_score(state.rating, problem_rating)) * effective_confidence * problem_weight
                delta = clamp(delta, -delta_cap, delta_cap)
                previous_tag_rating = state.tag_ratings.get(tag, state.rating)
                state.tag_ratings[tag] = previous_tag_rating + delta
                state.tag_attempts[tag] = attempts
                delta_total += delta * per_tag_weight

            state.rating += delta_total
            state.recent_results.append(is_correct)
            state.lose_streak = 0 if is_correct else state.lose_streak + 1

    ratings = [state.rating for state in states]
    return SimulationSummary(
        name=name,
        mean_rating=statistics.mean(ratings),
        rating_stddev=statistics.pstdev(ratings),
        min_rating=min(ratings),
        max_rating=max(ratings),
        correlation_with_true_skill=pearson(ratings, true_skills),
    )


class _SmokeRatingStore:
    """PostgreSQL I/O 없이 운영 계산 함수만 재현하는 보정 스크립트용 메모리 저장소."""

    def __init__(self) -> None:
        self.user = {
            "rating": 1200.0, "ovr": 1200.0, "ovr_prev": 1200.0,
            "lose_streak": 0, "last_attempt_at": None, "recent_results": [],
            "recent_index": 0, "recent_count": 0, "recent_sum": 0,
        }
        self.tags: dict[str, dict] = {}

    @contextmanager
    def transaction(self):
        """필요 변수: 없음. 작동 원리: 운영 서비스와 같은 트랜잭션 문맥 형태를 제공한다."""
        yield object()

    def get_or_create_user(self, cur, user_id, *, for_update):
        """필요 변수: 사용자 키. 작동 원리: 단일 스모크 사용자 상태를 반환한다."""
        del cur, user_id, for_update
        return dict(self.user)

    def claim_submission(self, cur, **kwargs):
        """필요 변수: 최초 스모크 제출. 작동 원리: 단 한 번 실행하므로 신규 제출로 처리한다."""
        del cur, kwargs
        return None

    def get_tag_stats(self, cur, user_id, tags):
        """필요 변수: 태그 목록. 작동 원리: 존재하는 메모리 태그만 반환한다."""
        del cur, user_id
        return {tag: self.tags[tag] for tag in tags if tag in self.tags}

    def upsert_tag_stats(self, cur, rows):
        """필요 변수: 태그 갱신값. 작동 원리: 태그별 최신 상태를 메모리에 기록한다."""
        del cur
        for row in rows:
            self.tags[row["tag"]] = dict(row)

    def compute_ovr(self, cur, user_id, fallback):
        """필요 변수: 태그 레이팅. 작동 원리: 운영식과 같은 시도 수 상한 가중평균을 계산한다."""
        del cur, user_id
        weights = [min(int(row["attempts"]), 24) for row in self.tags.values()]
        if not weights:
            return fallback
        return sum(row["rating"] * weight for row, weight in zip(self.tags.values(), weights)) / sum(weights)

    def update_user(self, cur, values):
        """필요 변수: 사용자 계산 결과. 작동 원리: 최신 상태를 메모리에 반영한다."""
        del cur
        self.user.update(values)

    def save_submission_response(self, cur, **kwargs):
        """필요 변수: 스모크 응답. 작동 원리: 단일 실행에서는 재생이 필요 없어 저장을 생략한다."""
        del cur, kwargs


def run_real_code_smoke_test(quests: list[QuestProfile]) -> dict[str, float]:
    """필요 변수: 합성 문제. 작동 원리: 운영 apply_rating_update를 메모리 저장소에 연결해 I/O와 무관한 계산 계약을 검증한다."""
    sample_quest = quests[len(quests) // 2]
    quest_payload = {
        "header": {"quest_id": "calibration-smoke"},
        "info": {
            "difficulty": sample_quest.difficulty,
            "main_huddle": sample_quest.main_huddle,
            "flow_rate": sample_quest.flow_rate,
            "hash_tag": list(sample_quest.tags),
        },
        "solves": [{
            "enter_huddle": sample_quest.main_huddle,
            "hash_tag": list(sample_quest.tags),
            "branches": [],
        }],
    }
    store = _SmokeRatingStore()
    original_store = rating_service.postgres_rating_store
    rating_service.postgres_rating_store = store
    try:
        result = rating_service.apply_rating_update(
            user_id="smoke-student",
            quest=quest_payload,
            is_correct=True,
            step_outcomes=[{"step_id": 1, "correct": True}],
            response_time_seconds=42.0,
            submission_ref="smoke-1",
        )
    finally:
        rating_service.postgres_rating_store = original_store
    return {
        "rating": result.rating,
        "ovr": result.ovr,
        "recent_accuracy": result.recent_accuracy,
    }


def main() -> None:
    quests = generate_synthetic_quest_profiles()
    profile = build_difficulty_profile(quests)
    summaries: dict[str, list[SimulationSummary]] = {"baseline": [], "tuned": []}

    for seed in DEFAULT_SEEDS:
        rng = random.Random(seed)
        true_skills = [1200.0 + rng.gauss(0.0, 170.0) for _ in range(DEFAULT_STUDENT_COUNT)]
        summaries["baseline"].append(
            run_algorithm(
                name="baseline",
                quests=quests,
                profile=profile,
                true_skills=true_skills,
                seed=seed,
            )
        )
        summaries["tuned"].append(
            run_algorithm(
                name="tuned",
                quests=quests,
                profile=profile,
                true_skills=true_skills,
                seed=seed,
            )
        )

    def aggregate(items: list[SimulationSummary]) -> dict[str, float]:
        return {
            "mean_rating": statistics.mean(item.mean_rating for item in items),
            "rating_stddev": statistics.mean(item.rating_stddev for item in items),
            "min_rating": statistics.mean(item.min_rating for item in items),
            "max_rating": statistics.mean(item.max_rating for item in items),
            "correlation_with_true_skill": statistics.mean(item.correlation_with_true_skill for item in items),
        }

    report = {
        "quest_count": len(quests),
        "difficulty_profile": {
            "log_center": round(profile.center, 4),
            "log_scale": round(profile.scale, 4),
        },
        "baseline": aggregate(summaries["baseline"]),
        "tuned": aggregate(summaries["tuned"]),
        "smoke_test": run_real_code_smoke_test(quests),
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
