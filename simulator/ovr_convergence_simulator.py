"""
OVR 수렴성 검증 시뮬레이터 v1

목표: 500명의 랜덤 가상 학생을 생성하여 5000~10000문제를 풀게 한 후,
      OVR(Overall Rating = tag_rating_sum / tag_rating_count)이 
      실력 수준에 따라 적절히 수렴하는지 검증.

특히 7000문제/90% 정답률 수준에서 높은 OVR 도달 여부 확인.

구조:
  1. StudentProfile: true_skill(0~1), 학습 패턴, 태그별 실력
  2. ProblemGenerator: 난이도 1~20, 태그 할당
  3. RatingEngine: 실제 omj/rating_service.py 의 핵심 로직을 그대로 복제
  4. Simulator: 배치 실행, 진행률 로깅, 결과 집계
  5. Analyzer: OVR 수렴성, 정답률-OVR 상관관계, 구간별 분포
"""

from __future__ import annotations

import math
import random
import statistics
import json
import time
import os
from dataclasses import dataclass, field
from typing import Dict, List, Tuple, Optional
from pathlib import Path
from concurrent.futures import ProcessPoolExecutor, as_completed
import multiprocessing

# ───────────────────────────────────────────────
# 1. RatingConfig (omj/rating_config.py 동기화)
# ───────────────────────────────────────────────

@dataclass(frozen=True)
class RatingConfig:
    K: float = 32.0
    K_MIN: float = 12.0
    DELTA_MAX: float = 50.0
    U_MAX: float = 2400.0
    C_MAX: float = 30.0
    TAU_DAYS: float = 21.0
    M_LOSE: float = 0.12
    ALPHA: float = 0.35
    BETA: float = 0.25
    GAMMA: float = 0.25
    DELTA: float = 0.15
    LAMBDA: float = 0.4
    MU: float = 0.3
    NU: float = 0.3
    DEFAULT_RATING: float = 1200.0


CONFIG = RatingConfig()


# ───────────────────────────────────────────────
# 2. Rating Engine (omj/rating_service.py 핵심 복제)
# ───────────────────────────────────────────────

@dataclass
class TagState:
    attempts: int = 0
    rating: float = CONFIG.DEFAULT_RATING


@dataclass
class UserState:
    rating: float = CONFIG.DEFAULT_RATING
    ovr: float = CONFIG.DEFAULT_RATING
    ovr_prev: float = CONFIG.DEFAULT_RATING
    lose_streak: int = 0
    last_attempt_day: float | None = None
    recent_results: list[int] = field(default_factory=list)
    recent_index: int = 0
    recent_count: int = 0
    recent_sum: int = 0
    tags: dict[str, TagState] = field(default_factory=dict)


@dataclass
class Step:
    enter_huddle: float
    tags: list[str]
    correct: bool | None = None


def clamp(value: float, low: float, high: float) -> float:
    return max(low, min(value, high))


def compute_expected_score(user_rating: float, problem_rating: float) -> float:
    return 1.0 / (1.0 + 10 ** ((problem_rating - user_rating) / 400.0))


def compute_k_factor(lose_streak: int) -> float:
    return max(CONFIG.K_MIN, CONFIG.K * math.exp(-CONFIG.M_LOSE * max(0, lose_streak)))


def percentile(values: list[float], pct: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    if len(ordered) == 1:
        return float(ordered[0])
    idx = int(round((len(ordered) - 1) * pct))
    idx = max(0, min(idx, len(ordered) - 1))
    return float(ordered[idx])


def compute_barrier(enter_huddles: list[float], main_huddle: float) -> float:
    if not enter_huddles:
        return clamp(main_huddle * 3.3, 0.0, 10.0)
    avg_enter = sum(enter_huddles) / max(1, len(enter_huddles))
    p80_enter = percentile(enter_huddles, 0.8)
    main_scaled = main_huddle * 3.3
    barrier = 0.6 * avg_enter + 0.2 * p80_enter + 0.2 * main_scaled
    return clamp(barrier, 0.0, 10.0)


def compute_problem_weight(difficulty: float, barrier: float) -> float:
    w_tag = 1.0
    w_barrier = barrier / 10.0
    w_diff = difficulty / 10.0
    return CONFIG.LAMBDA * w_tag + CONFIG.MU * w_barrier + CONFIG.NU * w_diff


def compute_problem_rating(difficulty: float, barrier: float) -> float:
    return clamp(1000.0 + 40.0 * difficulty + 30.0 * barrier, 800.0, 2200.0)


def compute_time_factor(answer_time: float | None, flow_rate: float, main_huddle: float) -> float:
    if answer_time is None or answer_time <= 0:
        return 1.0
    t_ref = 30.0 + 20.0 * flow_rate + 30.0 * main_huddle
    raw = math.exp(-max(0.0, answer_time - t_ref) / max(1.0, t_ref))
    raw = clamp(raw, 0.4, 1.0)
    return 0.9 + 0.1 * raw


def normalize_tag(tag: str) -> str:
    return tag.strip().lstrip('#').strip().lower()


def build_tag_flow_map(steps: list[Step]) -> dict[str, list[float]]:
    tag_map: dict[str, list[float]] = {}
    for step in steps:
        for raw in step.tags:
            tag = normalize_tag(raw)
            if not tag:
                continue
            tag_map.setdefault(tag, []).append(step.enter_huddle)
    return tag_map


def build_tag_correct_map(steps: list[Step]) -> dict[str, float | None]:
    tag_counts: dict[str, dict[str, int]] = {}
    for step in steps:
        if step.correct is None:
            continue
        for raw in step.tags:
            tag = normalize_tag(raw)
            if not tag:
                continue
            counts = tag_counts.setdefault(tag, {'correct': 0, 'incorrect': 0, 'total': 0})
            counts['total'] += 1
            if step.correct:
                counts['correct'] += 1
            else:
                counts['incorrect'] += 1
    result: dict[str, float | None] = {}
    for tag, counts in tag_counts.items():
        if counts['total'] == 0:
            result[tag] = None
        else:
            result[tag] = counts['correct'] / counts['total']
    return result


def update_recent_results(
    recent_results: list[int],
    recent_index: int,
    recent_count: int,
    recent_sum: int,
    value: int,
) -> tuple[list[int], int, int, int]:
    if recent_count < 50:
        recent_results.append(value)
        recent_count += 1
        recent_sum += value
        recent_index = recent_count % 50
        return recent_results, recent_index, recent_count, recent_sum
    if not recent_results:
        recent_results = [0] * 50
    if len(recent_results) < 50:
        recent_results.extend([0] * (50 - len(recent_results)))
    old = recent_results[recent_index]
    recent_results[recent_index] = value
    recent_sum += value - int(old)
    recent_index = (recent_index + 1) % 50
    return recent_results, recent_index, recent_count, recent_sum


def apply_rating_update(
    user: UserState,
    *,
    difficulty: float,
    main_huddle: float,
    flow_rate: float,
    steps: list[Step],
    tags: list[str],
    is_correct: bool,
    answer_time: float | None,
    advance_days: float,
) -> dict:
    """원본 rating_service.py 의 apply_rating_update 와 동일한 로직"""
    tags_norm = [normalize_tag(t) for t in tags if normalize_tag(t)]
    tags_norm = list(dict.fromkeys(tags_norm))

    sim_day_before = user.last_attempt_day if user.last_attempt_day is not None else 0.0
    sim_day = sim_day_before + max(0.0, advance_days)

    if user.last_attempt_day is None:
        r_t = 1.0
    else:
        d_days = max(0.0, sim_day - user.last_attempt_day)
        r_t = math.exp(-d_days / CONFIG.TAU_DAYS)

    tag_flow_map = build_tag_flow_map(steps)
    tag_correct_map = build_tag_correct_map(steps)
    total_flow_count = len(steps)

    r_u = clamp(user.rating / CONFIG.U_MAX, 0.0, 1.0)
    r_r = user.recent_sum / user.recent_count if user.recent_count > 0 else 0.5
    base_time_factor = compute_time_factor(answer_time, flow_rate, main_huddle)
    k_eff = compute_k_factor(user.lose_streak)

    delta_user = 0.0
    tag_deltas: list[dict] = []

    for tag in tags_norm:
        flows_t = tag_flow_map.get(tag, [])
        state = user.tags.get(tag)
        if state is None:
            state = TagState(attempts=0, rating=user.rating)
            user.tags[tag] = state

        attempts_before = state.attempts
        rating_before = state.rating
        state.attempts += 1

        if not flows_t:
            tag_deltas.append({
                'tag': tag,
                'attempts_before': attempts_before,
                'attempts_after': state.attempts,
                'rating_before': rating_before,
                'rating_after': state.rating,
                'flows': flows_t,
                'skipped': True,
            })
            continue

        barrier_t = compute_barrier(flows_t, main_huddle)
        weight_t = compute_problem_weight(difficulty, barrier_t)
        problem_rating_t = compute_problem_rating(difficulty, barrier_t)
        expected = compute_expected_score(user.rating, problem_rating_t)

        tag_correct = tag_correct_map.get(tag)
        if tag_correct is None:
            r_tag = 1 if is_correct else 0
        else:
            r_tag = 1 if tag_correct else 0

        r_c_t = clamp(state.attempts / CONFIG.C_MAX, 0.0, 1.0)

        if tag_correct is True:
            r_time_t = 1.0
        elif tag_correct is False:
            r_time_t = base_time_factor
        else:
            r_time_t = 1.0 if is_correct else base_time_factor

        confidence_t = (
            CONFIG.ALPHA * r_u
            + CONFIG.BETA * r_c_t
            + CONFIG.GAMMA * r_r
            + CONFIG.DELTA * r_t
        ) * r_time_t

        delta_t = k_eff * (r_tag - expected) * confidence_t * weight_t
        delta_t = clamp(delta_t, -CONFIG.DELTA_MAX, CONFIG.DELTA_MAX)

        state.rating += delta_t

        w_t = len(flows_t) / total_flow_count if total_flow_count > 0 else 0.0
        delta_user += delta_t * w_t
        tag_deltas.append({
            'tag': tag,
            'delta': delta_t,
            'expected': expected,
            'problem_rating': problem_rating_t,
            'confidence': confidence_t,
            'rating_after': state.rating,
        })

    user.rating += delta_user
    user.ovr_prev = user.ovr
    if user.tags:
        user.ovr = sum(tag.rating for tag in user.tags.values()) / len(user.tags)
    else:
        user.ovr = user.rating

    user.recent_results, user.recent_index, user.recent_count, user.recent_sum = update_recent_results(
        user.recent_results,
        user.recent_index,
        user.recent_count,
        user.recent_sum,
        1 if is_correct else 0,
    )

    user.lose_streak = 0 if is_correct else user.lose_streak + 1
    user.last_attempt_day = sim_day

    return {
        'tags_norm': tags_norm,
        'r_u': r_u,
        'r_r': r_r,
        'r_t': r_t,
        'k_eff': k_eff,
        'base_time_factor': base_time_factor,
        'delta_user': delta_user,
        'tag_deltas': tag_deltas,
        'is_correct': is_correct,
    }


# ───────────────────────────────────────────────
# 3. 데이터 모델: 학생, 문제, 풀이 기록
# ───────────────────────────────────────────────

@dataclass
class StudentProfile:
    student_id: int
    # 전체 평균 실력 (0~1)
    base_skill: float
    # 태그별 실력 (태그 -> 0~1)
    tag_skills: Dict[str, float]
    # 학습 패턴
    target_problems: int          # 목표 풀이 문제 수 (5000~10000)
    target_accuracy: float        # 목표 정답률 (0.3~0.95)
    # 결과
    total_problems: int = 0
    total_correct: int = 0
    final_rating: float = CONFIG.DEFAULT_RATING
    final_ovr: float = CONFIG.DEFAULT_RATING
    history: list = field(default_factory=list)


@dataclass
class Problem:
    problem_id: int
    tags: List[str]
    difficulty: float      # 1~20
    main_huddle: float     # 1~3
    steps: List[Step]


# ───────────────────────────────────────────────
# 4. 생성기
# ───────────────────────────────────────────────

ALL_TAGS = [
    'algebra', 'geometry', 'calculus', 'probability', 'statistics',
    'number_theory', 'combinatorics', 'trigonometry', 'logarithm', 'exponential',
    'sequence', 'series', 'limit', 'derivative', 'integral',
    'matrix', 'vector', 'complex_number', 'polynomial', 'equation',
]


def generate_student(student_id: int, rng: random.Random) -> StudentProfile:
    """랜덤 학생 프로필 생성"""
    # 5개 티어로 분포
    tier = rng.choices(
        [1, 2, 3, 4, 5],
        weights=[0.05, 0.15, 0.30, 0.35, 0.15]
    )[0]

    tier_base_skill = {1: 0.88, 2: 0.72, 3: 0.55, 4: 0.38, 5: 0.22}[tier]
    tier_skill_std = {1: 0.05, 2: 0.08, 3: 0.10, 4: 0.10, 5: 0.08}[tier]

    tag_skills = {}
    for tag in ALL_TAGS:
        skill = rng.gauss(tier_base_skill, tier_skill_std)
        tag_skills[tag] = clamp(skill, 0.02, 0.98)

    # 목표 문제 수: 5000~10000
    target_problems = rng.randint(5000, 10000)
    # 목표 정답률: 티어와 관련되되 변동성 있음
    target_accuracy = clamp(rng.gauss(tier_base_skill, 0.08), 0.30, 0.95)

    return StudentProfile(
        student_id=student_id,
        base_skill=tier_base_skill,
        tag_skills=tag_skills,
        target_problems=target_problems,
        target_accuracy=target_accuracy,
    )


def generate_problem(problem_id: int, rng: random.Random) -> Problem:
    """랜덤 문제 생성"""
    difficulty = rng.uniform(3.0, 18.0)
    main_huddle = float(rng.randint(1, 3))

    # 2~4개 스텝
    n_steps = rng.randint(2, 4)
    steps = []
    all_step_tags = set()

    for _ in range(n_steps):
        enter = rng.uniform(2.0, 8.0)
        n_tags = rng.randint(1, 2)
        step_tags = rng.sample(ALL_TAGS, k=n_tags)
        all_step_tags.update(step_tags)
        steps.append(Step(enter_huddle=enter, tags=step_tags))

    return Problem(
        problem_id=problem_id,
        tags=sorted(all_step_tags),
        difficulty=difficulty,
        main_huddle=main_huddle,
        steps=steps,
    )


def student_solves_problem(student: StudentProfile, problem: Problem, rng: random.Random) -> Tuple[bool, List[Step]]:
    """
    학생이 문제를 푼다.
    각 스텝의 태그 평균 실력을 기반으로 정답 확률 계산.
    난이도가 높을수록 정답률 감소.
    """
    step_results = []
    new_steps = []

    for step in problem.steps:
        tag_skills = [student.tag_skills.get(t, 0.3) for t in step.tags]
        avg_skill = sum(tag_skills) / len(tag_skills) if tag_skills else 0.3

        # 난이도 패널티
        difficulty_penalty = math.sqrt(10.0 / max(problem.difficulty, 1.0))
        noise = rng.gauss(0, 0.08)
        effective_skill = clamp(avg_skill + noise, 0.0, 1.0)
        correct_prob = clamp(effective_skill * difficulty_penalty, 0.02, 0.98)

        step_correct = rng.random() < correct_prob
        step_results.append(step_correct)
        new_steps.append(Step(
            enter_huddle=step.enter_huddle,
            tags=step.tags,
            correct=step_correct,
        ))

    # 전체 정답: 과반수 이상 스텝 정답
    overall_correct = sum(step_results) >= len(step_results) / 2
    return overall_correct, new_steps


# ───────────────────────────────────────────────
# 5. 단일 학생 시뮬레이션
# ───────────────────────────────────────────────

def simulate_one_student(student: StudentProfile, seed: int) -> StudentProfile:
    """한 학생의 전체 학습 과정 시뮬레이션"""
    rng = random.Random(seed + student.student_id)
    user = UserState()

    n_problems = student.target_problems
    history = []

    for i in range(n_problems):
        problem = generate_problem(i, rng)
        is_correct, solved_steps = student_solves_problem(student, problem, rng)

        # 응답 시간: 실력 높을수록 빠름
        avg_skill = statistics.mean([student.tag_skills.get(t, 0.3) for t in problem.tags]) if problem.tags else 0.3
        base_time = 60 + problem.difficulty * 8
        skill_factor = 1.5 - avg_skill
        answer_time = base_time * skill_factor * rng.uniform(0.7, 1.3)

        # 하루 평균 25문제 가정
        advance_days = rng.gauss(0.04, 0.02)

        result = apply_rating_update(
            user,
            difficulty=problem.difficulty,
            main_huddle=problem.main_huddle,
            flow_rate=float(len(problem.steps)),
            steps=solved_steps,
            tags=problem.tags,
            is_correct=is_correct,
            answer_time=answer_time,
            advance_days=max(0, advance_days),
        )

        student.total_problems += 1
        if is_correct:
            student.total_correct += 1

        # 100문제마다 스냅샷
        if (i + 1) % 100 == 0 or i == n_problems - 1:
            history.append({
                'problem_idx': i + 1,
                'rating': user.rating,
                'ovr': user.ovr,
                'accuracy_so_far': student.total_correct / student.total_problems,
                'lose_streak': user.lose_streak,
            })

    student.final_rating = user.rating
    student.final_ovr = user.ovr
    student.history = history
    return student


# ───────────────────────────────────────────────
# 6. 배치 실행 (멀티프로세싱)
# ───────────────────────────────────────────────

def simulate_batch(batch_students: List[StudentProfile], batch_seed: int) -> List[StudentProfile]:
    """배치 내 학생들을 순차 시뮬레이션"""
    results = []
    for student in batch_students:
        result = simulate_one_student(student, batch_seed)
        results.append(result)
    return results


# ───────────────────────────────────────────────
# 7. 메인 시뮬레이터 + 분석기
# ───────────────────────────────────────────────

class ConvergenceSimulator:
    def __init__(self, n_students: int = 500, seed: int = 42,
                 batch_size: int = 50, n_workers: int = None):
        self.n_students = n_students
        self.seed = seed
        self.batch_size = batch_size
        self.n_workers = n_workers or max(1, multiprocessing.cpu_count() - 1)
        self.rng = random.Random(seed)
        self.students: List[StudentProfile] = []
        self.results: List[StudentProfile] = []

    def generate_students(self):
        print(f"[1/4] {self.n_students}명 학생 프로필 생성 중...")
        self.students = [
            generate_student(i, self.rng)
            for i in range(self.n_students)
        ]
        print(f"      완료. 평균 목표 문제수={statistics.mean([s.target_problems for s in self.students]):.0f}, "
              f"평균 목표 정답률={statistics.mean([s.target_accuracy for s in self.students]):.2%}")

    def run_simulation(self):
        print(f"[2/4] 시뮬레이션 실행 중... (workers={self.n_workers}, batch_size={self.batch_size})")
        start = time.time()

        # 배치 분할
        batches = []
        for i in range(0, len(self.students), self.batch_size):
            batch = self.students[i:i + self.batch_size]
            batches.append((batch, self.seed + i))

        total = len(self.students)
        completed = 0

        with ProcessPoolExecutor(max_workers=self.n_workers) as executor:
            futures = {executor.submit(simulate_batch, batch, seed): batch for batch, seed in batches}
            for future in as_completed(futures):
                batch_results = future.result()
                self.results.extend(batch_results)
                completed += len(batch_results)
                elapsed = time.time() - start
                rate = completed / elapsed if elapsed > 0 else 0
                eta = (total - completed) / rate if rate > 0 else 0
                print(f"      진행: {completed}/{total} ({completed/total*100:.1f}%) | "
                      f"속도: {rate:.1f}명/초 | ETA: {eta:.0f}초")

        elapsed = time.time() - start
        print(f"      완료. 총 소요: {elapsed:.1f}초")

    def analyze(self):
        print(f"[3/4] 결과 분석 중...")
        analysis = {}

        # 기본 통계
        actual_accuracies = [s.total_correct / s.total_problems for s in self.results]
        final_ovrs = [s.final_ovr for s in self.results]
        final_ratings = [s.final_rating for s in self.results]
        target_probs = [s.target_problems for s in self.results]

        analysis['n_students'] = len(self.results)
        analysis['avg_actual_accuracy'] = statistics.mean(actual_accuracies)
        analysis['std_actual_accuracy'] = statistics.stdev(actual_accuracies) if len(actual_accuracies) > 1 else 0
        analysis['avg_final_ovr'] = statistics.mean(final_ovrs)
        analysis['std_final_ovr'] = statistics.stdev(final_ovrs) if len(final_ovrs) > 1 else 0
        analysis['avg_final_rating'] = statistics.mean(final_ratings)
        analysis['std_final_rating'] = statistics.stdev(final_ratings) if len(final_ratings) > 1 else 0
        analysis['avg_target_problems'] = statistics.mean(target_probs)

        # 상관관계
        def pearson(x: list[float], y: list[float]) -> float:
            n = len(x)
            if n < 2:
                return 0.0
            mx, my = sum(x)/n, sum(y)/n
            cov = sum((x[i]-mx)*(y[i]-my) for i in range(n))
            sx = math.sqrt(sum((xi-mx)**2 for xi in x))
            sy = math.sqrt(sum((yi-my)**2 for yi in y))
            return cov / (sx * sy) if sx and sy else 0.0

        analysis['corr_accuracy_ovr'] = pearson(actual_accuracies, final_ovrs)
        analysis['corr_accuracy_rating'] = pearson(actual_accuracies, final_ratings)
        analysis['corr_targetproblems_ovr'] = pearson(target_probs, final_ovrs)

        # 구간별 분석: 정답률 구간별 평균 OVR
        bins = [
            (0.0, 0.4, 'low'),
            (0.4, 0.6, 'mid-low'),
            (0.6, 0.75, 'mid'),
            (0.75, 0.85, 'mid-high'),
            (0.85, 0.95, 'high'),
            (0.95, 1.0, 'very-high'),
        ]
        bin_stats = {}
        for lo, hi, name in bins:
            subset = [s for s in self.results if lo <= s.total_correct/s.total_problems < hi]
            if subset:
                bin_stats[name] = {
                    'count': len(subset),
                    'avg_accuracy': statistics.mean([s.total_correct/s.total_problems for s in subset]),
                    'avg_ovr': statistics.mean([s.final_ovr for s in subset]),
                    'avg_rating': statistics.mean([s.final_rating for s in subset]),
                    'avg_problems': statistics.mean([s.total_problems for s in subset]),
                }
        analysis['bin_stats'] = bin_stats

        # 핵심 검증: 7000문제 이상 & 90% 정답률 이상 학생들의 OVR
        high_performers = [
            s for s in self.results
            if s.total_problems >= 7000 and s.total_correct / s.total_problems >= 0.90
        ]
        analysis['high_performers_count'] = len(high_performers)
        if high_performers:
            analysis['high_performers_avg_ovr'] = statistics.mean([s.final_ovr for s in high_performers])
            analysis['high_performers_avg_rating'] = statistics.mean([s.final_rating for s in high_performers])
            analysis['high_performers_min_ovr'] = min([s.final_ovr for s in high_performers])
            analysis['high_performers_max_ovr'] = max([s.final_ovr for s in high_performers])
        else:
            analysis['high_performers_avg_ovr'] = 0
            analysis['high_performers_avg_rating'] = 0
            analysis['high_performers_min_ovr'] = 0
            analysis['high_performers_max_ovr'] = 0

        # 수렴성: 초반 vs 후반 OVR 변동
        convergence_samples = []
        for s in self.results:
            if len(s.history) >= 20:
                early_ovrs = [h['ovr'] for h in s.history[:10]]
                late_ovrs = [h['ovr'] for h in s.history[-10:]]
                early_var = statistics.variance(early_ovrs) if len(early_ovrs) > 1 else 0
                late_var = statistics.variance(late_ovrs) if len(late_ovrs) > 1 else 0
                convergence_samples.append({
                    'student_id': s.student_id,
                    'early_var': early_var,
                    'late_var': late_var,
                    'ratio': early_var / max(late_var, 0.001),
                    'final_ovr': s.final_ovr,
                })
        if convergence_samples:
            analysis['avg_convergence_ratio'] = statistics.mean([c['ratio'] for c in convergence_samples])
        else:
            analysis['avg_convergence_ratio'] = 0

        self.analysis = analysis
        return analysis

    def print_report(self):
        print(f"[4/4] 분석 결과")
        print("=" * 70)
        a = self.analysis

        print(f"\n[전체 통계]")
        print(f"  학생 수: {a['n_students']}")
        print(f"  평균 실제 정답률: {a['avg_actual_accuracy']:.2%} (±{a['std_actual_accuracy']:.2%})")
        print(f"  평균 최종 OVR: {a['avg_final_ovr']:.1f} (±{a['std_final_ovr']:.1f})")
        print(f"  평균 최종 Rating: {a['avg_final_rating']:.1f} (±{a['std_final_rating']:.1f})")
        print(f"  평균 풀이 문제수: {a['avg_target_problems']:.0f}")

        print(f"\n[상관관계]")
        print(f"  정답률 vs OVR: {a['corr_accuracy_ovr']:.3f}")
        print(f"  정답률 vs Rating: {a['corr_accuracy_rating']:.3f}")
        print(f"  문제수 vs OVR: {a['corr_targetproblems_ovr']:.3f}")

        print(f"\n[정답률 구간별 OVR]")
        print(f"  {'구간':<12} {'인원':>6} {'평균정답률':>10} {'평균OVR':>10} {'평균Rating':>10} {'평균문제수':>10}")
        print(f"  {'-'*60}")
        for name, stats in a['bin_stats'].items():
            print(f"  {name:<12} {stats['count']:>6} {stats['avg_accuracy']:>9.2%} {stats['avg_ovr']:>10.1f} "
                  f"{stats['avg_rating']:>10.1f} {stats['avg_problems']:>10.0f}")

        print(f"\n[핵심 검증: 7000문제+ & 90%+ 정답률 학생]")
        print(f"  인원: {a['high_performers_count']}")
        if a['high_performers_count'] > 0:
            print(f"  평균 OVR: {a['high_performers_avg_ovr']:.1f}")
            print(f"  평균 Rating: {a['high_performers_avg_rating']:.1f}")
            print(f"  OVR 범위: {a['high_performers_min_ovr']:.1f} ~ {a['high_performers_max_ovr']:.1f}")
        else:
            print(f"  ⚠️  해당 조건 학생이 없습니다!")

        print(f"\n[수렴성]")
        print(f"  평균 수렴 비율 (클수록 안정): {a['avg_convergence_ratio']:.1f}")

        print(f"\n[평가]")
        score = 0
        max_score = 5

        # 1. 정답률-OVR 상관
        if abs(a['corr_accuracy_ovr']) > 0.5:
            print(f"  [O] 정답률과 OVR이 양의 상관관계 (r={a['corr_accuracy_ovr']:.3f})")
            score += 1
        else:
            print(f"  [X] 정답률과 OVR 상관관계 약함 (r={a['corr_accuracy_ovr']:.3f})")

        # 2. high performer OVR
        if a['high_performers_count'] > 0 and a['high_performers_avg_ovr'] > 1600:
            print(f"  [O] 고성과 학생 OVR 높음 (avg={a['high_performers_avg_ovr']:.1f})")
            score += 1
        elif a['high_performers_count'] > 0:
            print(f"  [△] 고성과 학생 OVR 중간 (avg={a['high_performers_avg_ovr']:.1f}, 기대 1600+)")
        else:
            print(f"  [X] 고성과 학생 없음")

        # 3. 수렴성
        if a['avg_convergence_ratio'] > 2.0:
            print(f"  [O] OVR 수렴 안정적 (ratio={a['avg_convergence_ratio']:.1f})")
            score += 1
        else:
            print(f"  [X] OVR 수렴 불안정 (ratio={a['avg_convergence_ratio']:.1f})")

        # 4. 구간별 분리
        bin_ovrs = [s['avg_ovr'] for s in a['bin_stats'].values() if 'avg_ovr' in s]
        if len(bin_ovrs) >= 2 and max(bin_ovrs) - min(bin_ovrs) > 200:
            print(f"  [O] 정답률 구간별 OVR 분리됨 (range={max(bin_ovrs)-min(bin_ovrs):.1f})")
            score += 1
        else:
            print(f"  [△] 정답률 구간별 OVR 분리 약함")

        # 5. 전체 평균 OVR 적정
        if 1300 <= a['avg_final_ovr'] <= 1800:
            print(f"  [O] 전체 평균 OVR 적정 ({a['avg_final_ovr']:.1f})")
            score += 1
        else:
            print(f"  [△] 전체 평균 OVR 편중 ({a['avg_final_ovr']:.1f})")

        print(f"\n  종합 평가: {score}/{max_score}")
        if score >= 4:
            print("  => OVR 시스템이 실력을 비교적 잘 반영하고 수렴함")
        elif score >= 3:
            print("  => OVR 시스템이 어느 정도 작동하나 개선 여지 있음")
        else:
            print("  => OVR 시스템에 문제 있음. 알고리즘 조정 필요")

        print("=" * 70)

    def save_results(self, path: str = "simulator/sim_data/ovr_convergence_results.json"):
        """결과를 JSON으로 저장"""
        data = {
            'analysis': self.analysis,
            'students_summary': [
                {
                    'student_id': s.student_id,
                    'base_skill': s.base_skill,
                    'target_problems': s.target_problems,
                    'target_accuracy': s.target_accuracy,
                    'total_problems': s.total_problems,
                    'total_correct': s.total_correct,
                    'actual_accuracy': s.total_correct / s.total_problems,
                    'final_rating': s.final_rating,
                    'final_ovr': s.final_ovr,
                }
                for s in self.results
            ]
        }
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        print(f"\n[저장] 결과 저장 완료: {path}")


def main():
    sim = ConvergenceSimulator(
        n_students=500,
        seed=42,
        batch_size=25,      # 배치 크기
        n_workers=4,        # 프로세스 수
    )
    sim.generate_students()
    sim.run_simulation()
    sim.analyze()
    sim.print_report()
    sim.save_results()


if __name__ == '__main__':
    main()
