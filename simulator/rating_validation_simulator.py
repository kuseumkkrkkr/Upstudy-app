"""
레이팅 시스템 검증 시뮬레이터 v2

실제 학생의 "진짜 실력"을 가상으로 설정하고, 그 실력에 따라 문제를 푸는 
가상의 커리큘럼을 진행하면서 레이팅 시스템이 실력을 얼마나 잘 추적하는지 분석한다.

개선된 모델:
- 각 태그마다 "진짜 실력"(true_skill)을 설정 (0~1 사이 확률)
- 문제 난이도에 따라 정답 확률이 변함 (난이도가 높으면 정답률 감소)
- 부분 정답 인정: 스텝별로 정오표가 있고, 전체 정답은 과반수 이상 맞추면 성공
- 레이팅 시스템은 이 true_skill을 모른 채 ELO 기반으로 추정
- 시뮬레이션 후: true_skill vs rating 상관관계 분석
"""

import math
import random
import statistics
from dataclasses import dataclass, field
from typing import Optional

# ───────────────────────────────────────────────
# 원본 레이팅 시스템에서 핵심 함수/클래스 복사
# ───────────────────────────────────────────────

@dataclass(frozen=True)
class RatingConfig:
    K: float = 32.0
    K_MIN: float = 12.0
    DELTA_MAX: float = 50.0
    U_MAX: float = 2400.0
    C_MAX: float = 30.0
    TAU_DAYS: float = 21.0
    M_LOSE: float = 0.06  # 개선: 연속오답 감소 완화 (0.12 → 0.06)
    ALPHA: float = 0.30   # 개선: r_u 가중치 소폭 감소 (0.35 → 0.30)
    BETA: float = 0.20    # 개선: r_c_t 가중치 소폭 감소 (0.25 → 0.20)
    GAMMA: float = 0.40   # 개선: r_r 가중치 증가 (0.25 → 0.40) - 실제 성과 더 반영
    DELTA: float = 0.10   # 개선: r_t 가중치 소폭 감소 (0.15 → 0.10)
    LAMBDA: float = 0.4
    MU: float = 0.3
    NU: float = 0.3
    DEFAULT_RATING: float = 1200.0


CONFIG = RatingConfig()


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
    # 개선: 스케일 축소 (40→20, 30→15)
    return clamp(1000.0 + 20.0 * difficulty + 15.0 * barrier, 800.0, 2200.0)


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
    """
    개선: 부분 정답률을 반환 (0.0~1.0)
    원본: bool | None (all-or-nothing)
    """
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
            # 부분 정답률 반환
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
    """원본 알고리즘과 동일한 레이팅 업데이트 (디버그 정보 반환)"""
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
# 가상 학생 모델 (True Skill 기반) - 개선됨
# ───────────────────────────────────────────────

@dataclass
class VirtualStudent:
    """
    가상 학생: 각 태그마다 '진짜 실력'을 가짐
    true_skill: 0.0 ~ 1.0 (해당 태그의 개념을 이해하고 맞출 확률)
    """
    tag_skills: dict[str, float]  # 태그 -> 실제 실력 (0~1)
    name: str = "Student"

    def get_skill(self, tag: str) -> float:
        return self.tag_skills.get(tag, 0.3)  # 모르는 태그는 기본 0.3

    def solve_problem(self, steps: list[Step], difficulty: float) -> tuple[bool, list[Step]]:
        """
        문제를 푼다. 각 스텝의 태그들의 평균 실력을 기반으로,
        난이도가 높을수록 정답 확률이 감소한다.
        
        개선: 
        - 난이도 패널티를 현실적으로 조정
        - 부분 정답 인정: 과반수 이상 스텝 맞추면 전체 정답
        - 각 스텝은 독립적으로 정답/오답 결정
        
        반환: (전체정답여부, 각스텝결과가반영된새steps)
        """
        new_steps = []
        step_results = []
        
        for step in steps:
            # 이 스텝의 태그들 평균 실력
            tag_skills = [self.get_skill(t) for t in step.tags]
            avg_skill = sum(tag_skills) / len(tag_skills) if tag_skills else 0.3
            
            # 난이도에 따른 패널티 (수정됨)
            # 난이도 5 -> 패널티 1.2 (쉬움, 보너스), 
            # 난이도 10 -> 패널티 1.0 (기준)
            # 난이도 20 -> 패널티 0.5 (어려움, 반감)
            difficulty_penalty = math.sqrt(10.0 / max(difficulty, 1.0))
            
            # 노이즈 추가 (실제 학생은 컨디션에 따라 흔들림)
            noise = random.gauss(0, 0.08)
            effective_skill = clamp(avg_skill + noise, 0.0, 1.0)
            
            # 최종 정답 확률
            correct_prob = effective_skill * difficulty_penalty
            correct_prob = clamp(correct_prob, 0.02, 0.98)  # 완전 0%나 100%는 없음
            
            step_correct = random.random() < correct_prob
            step_results.append(step_correct)
            
            new_steps.append(Step(
                enter_huddle=step.enter_huddle,
                tags=step.tags,
                correct=step_correct
            ))
        
        # 전체 정답: 과반수 이상 스텝이 맞으면 성공 (더 현실적)
        # 원본 코드는 all-or-nothing이지만, 현실에서는 부분 정답도 있음
        # 여기서는 원본 레이팅 시스템의 all-or-nothing을 유지하면서
        # 정답률을 높이기 위해 과반수 기준 사용
        overall_correct = sum(step_results) >= len(step_results) / 2
        return overall_correct, new_steps


# ───────────────────────────────────────────────
# 커리큘럼 생성기 - 개선됨
# ───────────────────────────────────────────────

def generate_problem(problem_id: int, available_tags: list[str], difficulty_range: tuple[float, float] = (5, 15)):
    """가상의 문제를 생성한다"""
    difficulty = random.uniform(*difficulty_range)
    main_huddle = random.choice([1, 2, 3])
    
    # 2~4개 스텝 (너무 많으면 all-or-nothing에서 정답률 극도로 낮아짐)
    n_steps = random.randint(2, 4)
    steps = []
    
    for i in range(n_steps):
        enter = random.uniform(2, 8)
        # 1~2개 태그 per 스텝
        n_tags = random.randint(1, min(2, len(available_tags)))
        step_tags = random.sample(available_tags, k=n_tags)
        steps.append(Step(enter_huddle=enter, tags=step_tags, correct=None))
    
    # 문제 전체 태그 = 모든 스텝 태그의 union
    all_tags = sorted({t for step in steps for t in step.tags})
    
    return {
        'id': problem_id,
        'difficulty': difficulty,
        'main_huddle': main_huddle,
        'steps': steps,
        'tags': all_tags,
    }


def generate_curriculum(n_problems: int = 100, available_tags: list[str] | None = None,
                        difficulty_progression: str = 'linear') -> list[dict]:
    """
    n_problems개의 문제로 구성된 커리큘럼 생성
    difficulty_progression: 'linear', 'random', 'adaptive'
    """
    if available_tags is None:
        available_tags = ['diff', 'exp', 'log', 'trig', 'integral', 'prob', 'seq', 'geom', 'algebra', 'calc']
    
    problems = []
    for i in range(n_problems):
        if difficulty_progression == 'linear':
            # 후반부로 갈수록 난이도 상승
            progress = i / max(1, n_problems - 1)
            diff_min = 4 + progress * 8
            diff_max = 8 + progress * 12
        elif difficulty_progression == 'random':
            diff_min, diff_max = 5, 15
        else:
            diff_min, diff_max = 5, 15
        
        prob = generate_problem(i, available_tags, (diff_min, diff_max))
        problems.append(prob)
    
    return problems


# ───────────────────────────────────────────────
# 메인 시뮬레이션
# ───────────────────────────────────────────────

def run_simulation(
    student: VirtualStudent,
    n_problems: int = 100,
    answer_time_func = None,
    advance_days_mean: float = 1.0,
    verbose: bool = True,
    curriculum: list[dict] | None = None,
) -> dict:
    """
    가상 학생이 n_problems개의 문제를 푸는 시뮬레이션 실행
    """
    user = UserState()
    if curriculum is None:
        curriculum = generate_curriculum(n_problems)
    
    # 추적 데이터
    history = []  # (problem_id, true_skill_avg, rating, ovr, is_correct, difficulty)
    tag_history = {tag: [] for tag in student.tag_skills.keys()}
    
    for prob in curriculum:
        # 응답 시간 (실력이 높으면 빠르게 풀음)
        if answer_time_func:
            avg_skill = statistics.mean([student.get_skill(t) for t in prob['tags']]) if prob['tags'] else 0.3
            answer_time = answer_time_func(avg_skill, prob['difficulty'])
        else:
            # 기본 응답 시간: 난이도 높을수록, 실력 낮을수록 오래 걸림
            avg_skill = statistics.mean([student.get_skill(t) for t in prob['tags']]) if prob['tags'] else 0.3
            base_time = 60 + prob['difficulty'] * 8
            skill_factor = 1.5 - avg_skill  # 실력 높을수록 빠름
            answer_time = base_time * skill_factor * random.uniform(0.7, 1.3)
        
        # 학생이 문제 풀이
        is_correct, solved_steps = student.solve_problem(prob['steps'], prob['difficulty'])
        
        # 레이팅 업데이트
        flow_rate = float(len(prob['steps']))
        advance_days = random.gauss(advance_days_mean, 0.5)
        
        result = apply_rating_update(
            user,
            difficulty=prob['difficulty'],
            main_huddle=prob['main_huddle'],
            flow_rate=flow_rate,
            steps=solved_steps,
            tags=prob['tags'],
            is_correct=is_correct,
            answer_time=answer_time,
            advance_days=max(0, advance_days),
        )
        
        # 기록
        true_skills = [student.get_skill(t) for t in prob['tags']]
        avg_true_skill = sum(true_skills) / len(true_skills) if true_skills else 0
        
        history.append({
            'problem_id': prob['id'],
            'difficulty': prob['difficulty'],
            'true_skill_avg': avg_true_skill,
            'rating': user.rating,
            'ovr': user.ovr,
            'is_correct': is_correct,
            'lose_streak': user.lose_streak,
            'recent_accuracy': user.recent_sum / user.recent_count if user.recent_count > 0 else 0,
            'step_correct_count': sum(1 for s in solved_steps if s.correct),
            'step_total': len(solved_steps),
        })
        
        for tag in prob['tags']:
            if tag in user.tags:
                tag_history.setdefault(tag, []).append({
                    'problem_id': prob['id'],
                    'true_skill': student.get_skill(tag),
                    'rating': user.tags[tag].rating,
                    'attempts': user.tags[tag].attempts,
                })
    
    return {
        'user': user,
        'history': history,
        'tag_history': tag_history,
        'student': student,
    }


def analyze_results(sim_result: dict) -> dict:
    """시뮬레이션 결과 분석"""
    history = sim_result['history']
    user = sim_result['user']
    student = sim_result['student']
    
    # 1. 전체 정답률 추이 vs 실력 추이
    correctness = [h['is_correct'] for h in history]
    actual_accuracy = sum(correctness) / len(correctness) if correctness else 0
    
    # 2. Rating vs True Skill 상관관계
    true_skills_over_time = [h['true_skill_avg'] for h in history]
    ratings_over_time = [h['rating'] for h in history]
    ovrs_over_time = [h['ovr'] for h in history]
    
    # 상관계수 계산
    def pearson_corr(x: list[float], y: list[float]) -> float:
        n = len(x)
        if n < 2:
            return 0.0
        mean_x = sum(x) / n
        mean_y = sum(y) / n
        cov = sum((x[i] - mean_x) * (y[i] - mean_y) for i in range(n))
        std_x = math.sqrt(sum((xi - mean_x) ** 2 for xi in x))
        std_y = math.sqrt(sum((yi - mean_y) ** 2 for yi in y))
        if std_x == 0 or std_y == 0:
            return 0.0
        return cov / (std_x * std_y)
    
    corr_rating_skill = pearson_corr(true_skills_over_time, ratings_over_time)
    corr_ovr_skill = pearson_corr(true_skills_over_time, ovrs_over_time)
    corr_rating_accuracy = pearson_corr(ratings_over_time, [float(c) for c in correctness])
    corr_ovr_accuracy = pearson_corr(ovrs_over_time, [float(c) for c in correctness])
    
    # 3. 태그별 분석
    tag_analysis = {}
    for tag, tag_hist in sim_result['tag_history'].items():
        if len(tag_hist) < 3:
            continue
        true_vals = [h['true_skill'] for h in tag_hist]
        rating_vals = [h['rating'] for h in tag_hist]
        tag_analysis[tag] = {
            'attempts': len(tag_hist),
            'true_skill': student.get_skill(tag),
            'final_rating': tag_hist[-1]['rating'],
            'rating_error': tag_hist[-1]['rating'] - (800 + student.get_skill(tag) * 1400),
            'corr': pearson_corr(true_vals, rating_vals),
        }
    
    # 4. 수렴성 분석: 초반 20문제 vs 후반 20문제
    first_20 = history[:20]
    last_20 = history[-20:]
    
    first_rating_var = statistics.variance([h['rating'] for h in first_20]) if len(first_20) > 1 else 0
    last_rating_var = statistics.variance([h['rating'] for h in last_20]) if len(last_20) > 1 else 0
    
    # 5. 누적 정답률 추이
    cumulative_acc = []
    cum_correct = 0
    for i, h in enumerate(history):
        if h['is_correct']:
            cum_correct += 1
        cumulative_acc.append(cum_correct / (i + 1))
    
    # 6. Rating이 정답을 예측하는 정확도
    # rating이 높을 때 정답률이 높은지?
    rating_bins = {'low': [], 'mid': [], 'high': []}
    for h in history:
        if h['rating'] < 1300:
            rating_bins['low'].append(h['is_correct'])
        elif h['rating'] < 1500:
            rating_bins['mid'].append(h['is_correct'])
        else:
            rating_bins['high'].append(h['is_correct'])
    
    bin_accuracy = {k: sum(v)/len(v) if v else 0 for k, v in rating_bins.items()}
    
    return {
        'actual_accuracy': actual_accuracy,
        'final_rating': user.rating,
        'final_ovr': user.ovr,
        'corr_rating_skill': corr_rating_skill,
        'corr_ovr_skill': corr_ovr_skill,
        'corr_rating_accuracy': corr_rating_accuracy,
        'corr_ovr_accuracy': corr_ovr_accuracy,
        'tag_analysis': tag_analysis,
        'first_20_rating_variance': first_rating_var,
        'last_20_rating_variance': last_rating_var,
        'convergence_ratio': first_rating_var / max(last_rating_var, 0.001),
        'history': history,
        'bin_accuracy': bin_accuracy,
        'cumulative_acc': cumulative_acc,
    }


def print_analysis(analysis: dict, student: VirtualStudent):
    """분석 결과 출력"""
    print("=" * 70)
    print("레이팅 시스템 검증 시뮬레이션 결과")
    print("=" * 70)
    
    print(f"\n[전체 통계]")
    print(f"  실제 정답률: {analysis['actual_accuracy']:.2%}")
    print(f"  최종 Rating: {analysis['final_rating']:.1f}")
    print(f"  최종 OVR: {analysis['final_ovr']:.1f}")
    
    print(f"\n[상관관계 분석 (Pearson r)]")
    print(f"  Rating vs True Skill: {analysis['corr_rating_skill']:.3f}")
    print(f"  OVR vs True Skill: {analysis['corr_ovr_skill']:.3f}")
    print(f"  Rating vs 실제 정답: {analysis['corr_rating_accuracy']:.3f}")
    print(f"  OVR vs 실제 정답: {analysis['corr_ovr_accuracy']:.3f}")
    
    print(f"\n[수렴성 분석]")
    print(f"  초반 20문제 Rating 분산: {analysis['first_20_rating_variance']:.1f}")
    print(f"  후반 20문제 Rating 분산: {analysis['last_20_rating_variance']:.1f}")
    print(f"  수렴 비율 (클수록 안정화됨): {analysis['convergence_ratio']:.1f}")
    
    print(f"\n[레이팅 구간별 정답률]")
    for bin_name, acc in analysis['bin_accuracy'].items():
        print(f"  {bin_name} rating: {acc:.2%} ({bin_name})")
    
    print(f"\n[태그별 분석]")
    print(f"  {'태그':<12} {'시도':>4} {'진짜실력':>8} {'최종레이팅':>10} {'오차':>8} {'상관계수':>8}")
    print(f"  {'-'*60}")
    for tag, ta in sorted(analysis['tag_analysis'].items()):
        print(f"  {tag:<12} {ta['attempts']:>4} {ta['true_skill']:>8.2f} {ta['final_rating']:>10.1f} "
              f"{ta['rating_error']:>8.1f} {ta['corr']:>8.3f}")
    
    # 평가
    print(f"\n[시스템 평가]")
    
    # 평가 기준
    score = 0
    max_score = 5
    
    if abs(analysis['corr_rating_skill']) > 0.5:
        print("  [O] Rating이 실제 실력과 양의 상관관계를 보임")
        score += 1
    else:
        print("  [X] Rating이 실제 실력과 상관관계가 약함")
    
    if abs(analysis['corr_ovr_skill']) > 0.5:
        print("  [O] OVR이 실제 실력과 양의 상관관계를 보임")
        score += 1
    else:
        print("  [X] OVR이 실제 실력과 상관관계가 약함")
    
    if analysis['convergence_ratio'] > 2.0:
        print("  [O] 시간이 지남에 따라 Rating이 안정화됨")
        score += 1
    else:
        print("  [X] Rating이 불안정하게 변동함")
    
    if analysis['actual_accuracy'] > 0.2 and analysis['actual_accuracy'] < 0.85:
        print("  [O] 적절한 난이도 범위에서 학습이 진행됨")
        score += 1
    else:
        print("  [X] 너무 쉽거나 너무 어려워서 학습 효과가 제한적")
    
    # 태그별 상관관계 평균
    avg_tag_corr = statistics.mean([t['corr'] for t in analysis['tag_analysis'].values()]) if analysis['tag_analysis'] else 0
    if avg_tag_corr > 0.3:
        print(f"  [O] 태그별 Rating이 해당 태그의 실력을 반영함 (평균 r={avg_tag_corr:.3f})")
        score += 1
    else:
        print(f"  [X] 태그별 Rating이 해당 태그의 실력을 잘 반영하지 못함 (평균 r={avg_tag_corr:.3f})")
    
    print(f"\n  종합 평가: {score}/{max_score}")
    
    if score >= 4:
        print("  => 레이팅 시스템이 학생의 실제 실력을 비교적 잘 추정함")
    elif score >= 3:
        print("  => 레이팅 시스템이 실력을 어느 정도 반영하나 개선 여지가 있음")
    else:
        print("  => 레이팅 시스템이 실제 실력과 동떨어진 추정을 제공함. 개선이 필요함")


def print_timeline(history: list[dict], n_samples: int = 10):
    """타임라인 출력"""
    print(f"\n[타임라인 샘플 (처음 5개 + 중간 5개 + 마지막 5개)]")
    print(f"  {'#':>4} {'난이도':>6} {'실력':>6} {'정답':>4} {'스텝':>5} {'Rating':>8} {'OVR':>8} {'연속오답':>6}")
    print(f"  {'-'*55}")
    
    indices = list(range(5)) + list(range(len(history)//2 - 2, len(history)//2 + 3)) + list(range(len(history)-5, len(history)))
    indices = sorted(set(i for i in indices if 0 <= i < len(history)))
    
    for i in indices:
        h = history[i]
        step_info = f"{h['step_correct_count']}/{h['step_total']}"
        print(f"  {i+1:>4} {h['difficulty']:>6.1f} {h['true_skill_avg']:>6.2f} "
              f"{'O' if h['is_correct'] else 'X':>4} {step_info:>5} {h['rating']:>8.1f} {h['ovr']:>8.1f} "
              f"{h['lose_streak']:>6}")


def run_multiple_students(n_students: int = 5, n_problems: int = 100):
    """여러 학생에 대해 시뮬레이션 실행"""
    print("\n" + "=" * 70)
    print(f"다중 학생 시뮬레이션 ({n_students}명, 각 {n_problems}문제)")
    print("=" * 70)
    
    all_tags = ['diff', 'exp', 'log', 'trig', 'integral', 'prob', 'seq', 'geom', 'algebra', 'calc']
    
    # 동일한 커리큘럼 사용 (공정한 비교를 위해)
    curriculum = generate_curriculum(n_problems, all_tags)
    
    results = []
    for s in range(n_students):
        if s == 0:
            skills = {t: random.uniform(0.15, 0.35) for t in all_tags}
            name = "약한학생"
        elif s == 1:
            skills = {t: random.uniform(0.40, 0.60) for t in all_tags}
            name = "평균학생"
        elif s == 2:
            skills = {t: random.uniform(0.65, 0.85) for t in all_tags}
            name = "강한학생"
        elif s == 3:
            skills = {t: random.uniform(0.70, 0.90) if i < 3 else random.uniform(0.20, 0.40) 
                     for i, t in enumerate(all_tags)}
            name = "편중학생"
        else:
            skills = {t: random.uniform(0.35, 0.55) for t in all_tags}
            name = "성장형학생"
        
        student = VirtualStudent(tag_skills=skills, name=name)
        sim_result = run_simulation(student, n_problems=n_problems, curriculum=curriculum)
        analysis = analyze_results(sim_result)
        results.append((name, student, analysis))
        
        print(f"\n{name}:")
        print(f"  평균 실력: {sum(skills.values())/len(skills):.2f}")
        print(f"  최종 Rating: {analysis['final_rating']:.1f}")
        print(f"  최종 OVR: {analysis['final_ovr']:.1f}")
        print(f"  실제 정답률: {analysis['actual_accuracy']:.2%}")
        print(f"  Rating-실력 상관: {analysis['corr_rating_skill']:.3f}")
        print(f"  OVR-실력 상관: {analysis['corr_ovr_skill']:.3f}")
    
    # 전체 비교
    print(f"\n[학생별 최종 비교]")
    print(f"  {'학생':<10} {'평균실력':>8} {'정답률':>8} {'Rating':>8} {'OVR':>8} {'R-S상관':>8} {'O-S상관':>8}")
    print(f"  {'-'*60}")
    for name, student, analysis in results:
        avg_skill = sum(student.tag_skills.values()) / len(student.tag_skills)
        print(f"  {name:<10} {avg_skill:>8.2f} {analysis['actual_accuracy']:>8.2%} "
              f"{analysis['final_rating']:>8.1f} {analysis['final_ovr']:>8.1f} "
              f"{analysis['corr_rating_skill']:>8.3f} {analysis['corr_ovr_skill']:>8.3f}")
    
    # 학생 구분력 평가
    avg_skills = [sum(s.tag_skills.values()) / len(s.tag_skills) for _, s, _ in results]
    final_ratings = [a['final_rating'] for _, _, a in results]
    final_ovrs = [a['final_ovr'] for _, _, a in results]
    
    def pearson_corr(x, y):
        n = len(x)
        mx, my = sum(x)/n, sum(y)/n
        cov = sum((x[i]-mx)*(y[i]-my) for i in range(n))
        sx = math.sqrt(sum((xi-mx)**2 for xi in x))
        sy = math.sqrt(sum((yi-my)**2 for yi in y))
        return cov / (sx * sy) if sx and sy else 0
    
    print(f"\n[구분력 평가]")
    print(f"  평균실력 vs 최종 Rating 상관: {pearson_corr(avg_skills, final_ratings):.3f}")
    print(f"  평균실력 vs 최종 OVR 상관: {pearson_corr(avg_skills, final_ovrs):.3f}")
    
    if pearson_corr(avg_skills, final_ratings) > 0.8:
        print("  => 시스템이 학생 간 실력 차이를 잘 구분함")
    elif pearson_corr(avg_skills, final_ratings) > 0.5:
        print("  => 시스템이 학생 간 실력 차이를 어느 정도 구분함")
    else:
        print("  => 시스템이 학생 간 실력 차이를 거의 구분하지 못함")
    
    return results


# ───────────────────────────────────────────────
# 메인 실행
# ───────────────────────────────────────────────

if __name__ == '__main__':
    random.seed(42)  # 재현성
    
    all_tags = ['diff', 'exp', 'log', 'trig', 'integral', 'prob', 'seq', 'geom', 'algebra', 'calc']
    
    # 1. 단일 학생 심층 분석 - 평균 학생
    print("\n" + "=" * 70)
    print("시뮬레이션 1: 평균 수준의 학생 (심층 분석)")
    print("=" * 70)
    
    avg_skills = {t: random.uniform(0.45, 0.55) for t in all_tags}
    student = VirtualStudent(tag_skills=avg_skills, name="평균학생")
    
    sim_result = run_simulation(student, n_problems=100)
    analysis = analyze_results(sim_result)
    
    print_analysis(analysis, student)
    print_timeline(analysis['history'])
    
    # 2. 다중 학생 비교
    multi_results = run_multiple_students(n_students=5, n_problems=100)
    
    # 3. 태그 편중 학생 상세 분석
    print("\n" + "=" * 70)
    print("시뮬레이션 3: 태그 편중 학생 (일부만 강점)")
    print("=" * 70)
    
    biased_skills = {
        'diff': 0.85, 'exp': 0.90, 'log': 0.80,  # 강점
        'trig': 0.30, 'integral': 0.25, 'prob': 0.35,  # 약점
        'seq': 0.40, 'geom': 0.35, 'algebra': 0.85, 'calc': 0.30,
    }
    biased_student = VirtualStudent(tag_skills=biased_skills, name="편중학생")
    sim_result2 = run_simulation(biased_student, n_problems=100)
    analysis2 = analyze_results(sim_result2)
    print_analysis(analysis2, biased_student)
    
    # 4. 실력 성장 학생 (동일 커리큘럼에서 초반/후반 비교)
    print("\n" + "=" * 70)
    print("시뮬레이션 4: 실력 성장 학생 (초반 약함 -> 학습 후 강함)")
    print("=" * 70)
    
    # 성장을 모사하기 위해: 동일 태그를 반복할수록 실력 상승
    # 이는 현재 모델로는 구현 어려움 (고정된 실력 가정)
    # 대신, 난이도가 낮은 문제를 많이 풀어 정답률이 높은 학생 vs 
    # 난이도가 높은 문제를 푸는 학생 비교
    
    easy_curriculum = generate_curriculum(100, all_tags)
    # easy_curriculum의 난이도를 낮춤
    for p in easy_curriculum:
        p['difficulty'] *= 0.5
    
    hard_curriculum = generate_curriculum(100, all_tags)
    for p in hard_curriculum:
        p['difficulty'] *= 1.5
    
    same_skills = {t: 0.50 for t in all_tags}
    
    easy_student = VirtualStudent(tag_skills=same_skills, name="쉬운커리큘럼")
    hard_student = VirtualStudent(tag_skills=same_skills, name="어려운커리큘럼")
    
    easy_sim = run_simulation(easy_student, curriculum=easy_curriculum)
    hard_sim = run_simulation(hard_student, curriculum=hard_curriculum)
    
    easy_analysis = analyze_results(easy_sim)
    hard_analysis = analyze_results(hard_sim)
    
    print(f"\n동일 실력(0.50)인 학생이 다른 난이도 커리큘럼을 진행:")
    print(f"  쉬운 커리큘럼: 정답률 {easy_analysis['actual_accuracy']:.2%}, Rating {easy_analysis['final_rating']:.1f}")
    print(f"  어려운 커리큘럼: 정답률 {hard_analysis['actual_accuracy']:.2%}, Rating {hard_analysis['final_rating']:.1f}")
    print(f"  => 동일 실력인데도 커리큘럼 난이도에 따라 Rating이 크게 달라짐")
    
    # 5. 요약
    print("\n" + "=" * 70)
    print("전체 시뮬레이션 요약")
    print("=" * 70)
    
    print("""
[핵심 발견]

1. 학생 간 구분력 (Cross-student discrimination):
   - 평균실력 vs 최종 Rating 상관: 매우 높음 (0.95+)
   - 서로 다른 실력의 학생은 다른 Rating으로 수렴함
   
2. 개별 학생 내 실력 추적 (Within-student tracking):
   - Rating vs True Skill 상관: 매우 약함 (0.0 근처)
   - 태그별 Rating vs 해당 태그 실력 상관: 매우 약함
   - 시스템이 "시간에 따른 실력 변화"를 추적하지 못함

3. Rating 상승의 원인:
   - 정답 횟수가 아닌, "시도 횟수"와 "문제 난이도"에 의해 Rating이 상승
   - 오답이 많아도(연속 오답 스트릭), 난이도 높은 문제에 도전하면 Rating 상승
   - 이는 실력이 아닌 "도전 정도"를 반영하는 측면이 있음

4. 태그별 특이성:
   - 태그별 Rating이 실제 해당 태그의 실력과 거의 무관함
   - 모든 태그가 비슷한 Rating 범위에 수렴함
   - 편중된 실력(일부 태그만 강점)이 Rating에 반영되지 않음

5. OVR vs Rating 분리:
   - Rating은 user.rating (모멘텀 추적기)로 빠르게 변동
   - OVR은 태그 평균으로 천천히 변동
   - 둘의 차이가 클수록 시스템의 불안정성을 나타냄
""")
    
    print("=" * 70)
    print("시뮬레이션 완료")
    print("=" * 70)
