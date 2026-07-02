"""
대규모 CSAT 학생 레이팅 시뮬레이션 시스템 v4

변경사항:
- 비동기 배치 처리: 학생별 독립 실행
- 진행률 출력: 3명마다 진행 상황 로깅
- 등급 역전 버그 수정: rating 계산 로직 개선
- 파일 로깅: 실시간 진행 확인
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
# 태그 데이터 임포트
# ───────────────────────────────────────────────
try:
    from csat_codebase.tag_data import SUBJECT_TAG_RULES
except ImportError:
    SUBJECT_TAG_RULES = [
        {'code': 1, 'grade': 10, 'name': 'common-math-1', 'tags': []},
        {'code': 2, 'grade': 11, 'name': 'common-math-2', 'tags': []},
        {'code': 3, 'grade': 12, 'name': 'algebra', 'tags': []},
        {'code': 4, 'grade': 13, 'name': 'calculus-1', 'tags': []},
    ]

# ───────────────────────────────────────────────
# 상수 및 설정
# ───────────────────────────────────────────────

TIER_DISTRIBUTION = {
    1: 0.04,   # 상위 4%
    2: 0.07,   # 다음 7%
    3: 0.12,   # 다음 12%
    4: 0.17,   # 다음 17%
    5: 0.20,   # 다음 20%
    6: 0.17,   # 다음 17%
}

TIER_BASE_SKILL = {
    1: 0.88,
    2: 0.75,
    3: 0.62,
    4: 0.50,
    5: 0.38,
    6: 0.25,
}

TIER_SKILL_STD = {
    1: 0.06,
    2: 0.08,
    3: 0.10,
    4: 0.11,
    5: 0.11,
    6: 0.10,
}

MONTHLY_INTENSITY = {
    3: 0.8, 4: 0.9, 5: 1.0, 6: 1.1, 7: 1.3, 8: 1.4, 9: 1.2, 10: 1.3, 11: 1.5,
}

WEEKDAY_FACTOR = [1.0, 1.0, 1.0, 1.0, 0.9, 0.6, 0.5]

SUBJECT_TIME_RATIO = {
    'calculus-1': 0.40, 'algebra': 0.30, 'common-math-2': 0.15,
    'probability-statistics': 0.10, 'common-math-1': 0.05,
}

# ───────────────────────────────────────────────
# 로깅 유틸리티
# ───────────────────────────────────────────────

class ProgressLogger:
    """진행 상황 로거 - 파일 및 콘솔 동시 출력"""
    
    def __init__(self, log_file: str = "simulation_progress.log"):
        self.log_file = log_file
        self.start_time = time.time()
        self._file = open(log_file, 'w', encoding='utf-8', buffering=1)
    
    def log(self, msg: str):
        elapsed = time.time() - self.start_time
        line = f"[{elapsed:.1f}s] {msg}"
        print(line, flush=True)
        self._file.write(line + '\n')
        self._file.flush()
    
    def close(self):
        self._file.close()
    
    def __enter__(self):
        return self
    
    def __exit__(self, *args):
        self.close()

# ───────────────────────────────────────────────
# 데이터 모델
# ───────────────────────────────────────────────

@dataclass
class TagSkill:
    tag: str
    true_skill: float
    learning_rate: float
    forgetting_rate: float
    last_study_day: float = 0.0
    solve_count: int = 0
    correct_count: int = 0

@dataclass
class StudentProfile:
    student_id: int
    tier: int
    tag_skills: Dict[str, TagSkill]
    total_problems: int = 0
    total_correct: int = 0
    study_days: set = field(default_factory=set)
    
    def get_skill(self, tag: str, day: float) -> float:
        ts = self.tag_skills.get(tag)
        if not ts:
            return 0.5
        days_since = max(0, day - ts.last_study_day)
        decay = math.exp(-ts.forgetting_rate * days_since)
        return max(0.02, min(0.98, ts.true_skill * decay))
    
    def update_after_solve(self, tag: str, is_correct: bool, day: float, difficulty: float):
        ts = self.tag_skills.get(tag)
        if not ts:
            return
        ts.last_study_day = day
        ts.solve_count += 1
        if is_correct:
            ts.correct_count += 1

@dataclass
class Problem:
    problem_id: int
    tags: List[str]
    difficulty: float
    subject: str

@dataclass
class SolveRecord:
    student_id: int
    problem_id: int
    day: float
    is_correct: bool
    answer_time: float
    tags: List[str]
    difficulty: float
    rating_before: float = 0.0
    rating_after: float = 0.0

# ───────────────────────────────────────────────
# 학생 생성기
# ───────────────────────────────────────────────

class StudentGenerator:
    def __init__(self, n_students: int, seed: int = 42):
        self.n_students = n_students
        random.seed(seed)
        
        # 태그 목록 생성
        self.all_tags = []
        for subject in SUBJECT_TAG_RULES:
            subject_name = subject['name']
            for i in range(15):
                self.all_tags.append(f"{subject_name}-tag-{i}")
    
    def generate_students(self) -> List[StudentProfile]:
        students = []
        student_id = 0
        
        for tier, ratio in TIER_DISTRIBUTION.items():
            n_tier = max(1, int(self.n_students * ratio))
            if tier == 6:
                n_tier = self.n_students - len(students)
            
            for _ in range(n_tier):
                base_skill = TIER_BASE_SKILL[tier]
                skill_std = TIER_SKILL_STD[tier]
                
                tag_skills = {}
                for tag in self.all_tags:
                    true_skill = random.gauss(base_skill, skill_std)
                    true_skill = max(0.02, min(0.98, true_skill))
                    
                    learning_rate = random.uniform(0.01, 0.05)
                    forgetting_rate = random.uniform(0.001, 0.01)
                    
                    tag_skills[tag] = TagSkill(
                        tag=tag, true_skill=true_skill,
                        learning_rate=learning_rate, forgetting_rate=forgetting_rate
                    )
                
                students.append(StudentProfile(
                    student_id=student_id, tier=tier, tag_skills=tag_skills
                ))
                student_id += 1
        
        return students

# ───────────────────────────────────────────────
# 문제 생성기
# ───────────────────────────────────────────────

class ProblemGenerator:
    _problem_counter = 0
    
    def __init__(self, seed: int = 43):
        random.seed(seed)
        self.subjects = [s['name'] for s in SUBJECT_TAG_RULES]
    
    def generate_problem(self, subject: str, tags: List[str], difficulty: float) -> Problem:
        ProblemGenerator._problem_counter += 1
        return Problem(
            problem_id=ProblemGenerator._problem_counter,
            tags=tags,
            difficulty=difficulty,
            subject=subject
        )

# ───────────────────────────────────────────────
# 공부 패턴 시뮬레이터
# ───────────────────────────────────────────────

class StudyPatternSimulator:
    def __init__(self):
        self.start_day = 0
        self.end_day = 270
        self.base_problems_per_day = 25
    
    def get_month(self, day: int) -> int:
        if day < 30: return 3
        elif day < 60: return 4
        elif day < 90: return 5
        elif day < 120: return 6
        elif day < 150: return 7
        elif day < 180: return 8
        elif day < 210: return 9
        elif day < 240: return 10
        else: return 11
    
    def simulate_day(self, student: StudentProfile, day: float, 
                     problem_gen: ProblemGenerator) -> Tuple[List[Problem], int]:
        month = self.get_month(int(day))
        intensity = MONTHLY_INTENSITY.get(month, 1.0)
        weekday = int(day) % 7
        weekday_factor = WEEKDAY_FACTOR[weekday]
        
        n_problems = max(1, int(self.base_problems_per_day * intensity * weekday_factor))
        n_problems = random.randint(max(1, n_problems - 5), n_problems + 5)
        
        problems = []
        for _ in range(n_problems):
            subject = random.choices(
                list(SUBJECT_TIME_RATIO.keys()),
                weights=list(SUBJECT_TIME_RATIO.values())
            )[0]
            
            # 학생의 취약 태그 선호
            student_tags = list(student.tag_skills.keys())
            tag = random.choice(student_tags[:10] if random.random() < 0.3 else student_tags)
            
            # 난이도: 학생 실력 기반
            avg_skill = sum(ts.true_skill for ts in student.tag_skills.values()) / len(student.tag_skills)
            target_diff = avg_skill * 20
            difficulty = max(1.0, min(20.0, random.gauss(target_diff, 3.0)))
            
            problems.append(problem_gen.generate_problem(subject, [tag], difficulty))
        
        return problems, n_problems

# ───────────────────────────────────────────────
# 풀이 시뮬레이터
# ───────────────────────────────────────────────

class SolveSimulator:
    def __init__(self, seed: int = 44):
        random.seed(seed)
    
    def solve_fast(self, student: StudentProfile, problem: Problem, day: float) -> bool:
        tag_skills = [student.get_skill(tag, day) for tag in problem.tags]
        avg_skill = sum(tag_skills) / len(tag_skills) if tag_skills else 0.5
        
        difficulty_penalty = math.sqrt(10.0 / max(problem.difficulty, 1.0))
        noise = random.gauss(0, 0.08)
        effective_skill = max(0.02, min(0.98, avg_skill + noise))
        correct_prob = max(0.02, min(0.98, effective_skill * difficulty_penalty))
        
        is_correct = random.random() < correct_prob
        
        for tag in problem.tags:
            student.update_after_solve(tag, is_correct, day, problem.difficulty)
        
        student.total_problems += 1
        if is_correct:
            student.total_correct += 1
        
        return is_correct

# ───────────────────────────────────────────────
# 개선된 레이팅 엔진 v4
# ───────────────────────────────────────────────

@dataclass
class RatingState:
    rating: float = 1500.0
    rd: float = 350.0
    volatility: float = 0.06
    tag_ratings: Dict[str, 'TagRatingState'] = field(default_factory=dict)
    last_update_day: float = 0.0
    total_games: int = 0
    win_count: int = 0
    # 누적 성과 (EMA용)
    _cumulative_perf: float = 0.0
    _total_attempts: int = 0

@dataclass
class TagRatingState:
    rating: float = 1500.0
    rd: float = 350.0
    attempts: int = 0
    correct_count: int = 0
    _cumulative_perf: float = 0.0
    _total_attempts: int = 0

class ImprovedRatingEngine:
    DEFAULT_RATING = 1500.0
    MIN_RATING = 400.0
    MAX_RATING = 3000.0
    DECAY_ALPHA = 0.02
    TAG_WEIGHT = 0.3
    
    def __init__(self):
        self.student_ratings: Dict[int, RatingState] = {}
    
    def _compute_performance_score(self, is_correct: bool, difficulty: float) -> float:
        if is_correct:
            return difficulty
        else:
            return -(20.0 - difficulty) * 1.5
    
    def _performance_to_rating(self, avg_performance: float) -> float:
        """성과 점수를 레이팅으로 변환 (등급 역방지 버전)"""
        # 정규화: 이론적 범위 -30 ~ +20
        # 정답률과 난이도를 동시에 반영
        
        if avg_performance <= -15:
            # 매우 낮은 실력
            rating = self.DEFAULT_RATING + 40.0 * avg_performance
        elif avg_performance <= 0:
            # 중간 이하
            rating = self.DEFAULT_RATING + 60.0 * avg_performance
        elif avg_performance <= 10:
            # 중간 이상
            rating = self.DEFAULT_RATING + 80.0 * avg_performance
        else:
            # 고실력: 지수적 보정으로 상위 등급 분리
            base = self.DEFAULT_RATING + 800.0  # performance=10 기준
            bonus = 50.0 * (avg_performance - 10) ** 1.3
            rating = base + bonus
        
        return max(self.MIN_RATING, min(self.MAX_RATING, rating))
    
    def update_rating(self, student_id: int, problem: Problem,
                      is_correct: bool, day: float) -> Tuple[float, float]:
        if student_id not in self.student_ratings:
            self.student_ratings[student_id] = RatingState()
        
        state = self.student_ratings[student_id]
        rating_before = state.rating
        
        perf_score = self._compute_performance_score(is_correct, problem.difficulty)
        
        # EMA 업데이트
        alpha = self.DECAY_ALPHA
        if state._total_attempts == 0:
            state._cumulative_perf = perf_score
        else:
            state._cumulative_perf = (1 - alpha) * state._cumulative_perf + alpha * perf_score
        
        state._total_attempts += 1
        
        overall_rating = self._performance_to_rating(state._cumulative_perf)
        
        # 태그별 업데이트
        tag_ratings = []
        for tag in problem.tags:
            if tag not in state.tag_ratings:
                state.tag_ratings[tag] = TagRatingState()
            
            tag_state = state.tag_ratings[tag]
            
            tag_alpha = min(0.1, alpha * 5)
            if tag_state._total_attempts == 0:
                tag_state._cumulative_perf = perf_score
            else:
                tag_state._cumulative_perf = (1 - tag_alpha) * tag_state._cumulative_perf + tag_alpha * perf_score
            
            tag_state._total_attempts += 1
            tag_state.attempts += 1
            if is_correct:
                tag_state.correct_count += 1
            
            tag_rating = self._performance_to_rating(tag_state._cumulative_perf)
            tag_state.rating = tag_rating
            tag_ratings.append(tag_rating)
        
        # 최종 레이팅: 전체 기반 + 태그 보정 (역방지)
        if tag_ratings:
            avg_tag_rating = sum(tag_ratings) / len(tag_ratings)
            # 태그 평균이 전체와 크게 벗어나면 클램핑
            max_diff = 300.0  # 최대 300점 차이 허용
            diff = avg_tag_rating - overall_rating
            if abs(diff) > max_diff:
                diff = max_diff if diff > 0 else -max_diff
            clamped_tag = overall_rating + diff
            
            state.rating = overall_rating * (1 - self.TAG_WEIGHT) + clamped_tag * self.TAG_WEIGHT
        else:
            state.rating = overall_rating
        
        state.total_games += 1
        if is_correct:
            state.win_count += 1
        
        state.rating = max(self.MIN_RATING, min(self.MAX_RATING, state.rating))
        
        return rating_before, state.rating
    
    def get_student_rating(self, student_id: int) -> Tuple[float, float]:
        state = self.student_ratings.get(student_id, RatingState())
        return state.rating, state.rd
    
    def get_tag_rating(self, student_id: int, tag: str) -> Tuple[float, float]:
        state = self.student_ratings.get(student_id, RatingState())
        tag_state = state.tag_ratings.get(tag, TagRatingState())
        return tag_state.rating, tag_state.rd

# ───────────────────────────────────────────────
# 배치 시뮬레이션 (비동기 처리)
# ───────────────────────────────────────────────

def simulate_student_batch(batch_data: dict) -> dict:
    """학생 배치를 독립적으로 시뮬레이션"""
    students = batch_data['students']
    seed = batch_data['seed']
    batch_id = batch_data['batch_id']
    
    random.seed(seed)
    
    study_sim = StudyPatternSimulator()
    solve_sim = SolveSimulator(seed + 1000)
    rating_engine = ImprovedRatingEngine()
    problem_gen = ProblemGenerator(seed + 2000)
    
    total_problems = 0
    
    for student in students:
        for day in range(study_sim.start_day, study_sim.end_day + 1):
            problems, n = study_sim.simulate_day(student, float(day), problem_gen)
            
            for problem in problems:
                is_correct = solve_sim.solve_fast(student, problem, float(day))
                rating_engine.update_rating(
                    student.student_id, problem, is_correct, float(day)
                )
                total_problems += 1
    
    return {
        'batch_id': batch_id,
        'students': students,
        'total_problems': total_problems,
        'rating_engine': rating_engine,
    }

# ───────────────────────────────────────────────
# 메인 시뮬레이터 v4
# ───────────────────────────────────────────────

class MassiveSimulator:
    def __init__(self, n_students: int = 500, seed: int = 42,
                 save_records: bool = False, fast_mode: bool = True,
                 batch_size: int = 3, n_workers: int = None,
                 logger: ProgressLogger = None):
        self.n_students = n_students
        self.seed = seed
        self.save_records = save_records
        self.fast_mode = fast_mode
        self.batch_size = batch_size
        self.n_workers = n_workers or max(1, multiprocessing.cpu_count() - 1)
        self.logger = logger
        
        random.seed(seed)
        
        self.student_gen = StudentGenerator(n_students, seed)
        self.problem_gen = ProblemGenerator(seed + 1)
        self.study_sim = StudyPatternSimulator()
        self.solve_sim = SolveSimulator(seed + 2)
        self.rating_engine = ImprovedRatingEngine()
        
        self.students: List[StudentProfile] = []
        self.all_records: List[SolveRecord] = []
    
    def _log(self, msg: str):
        if self.logger:
            self.logger.log(msg)
        else:
            print(msg, flush=True)
    
    def run(self, verbose: bool = True) -> dict:
        if verbose:
            self._log("=" * 60)
            self._log(f"CSAT Rating Simulation v4 - {self.n_students} students")
            self._log(f"Workers: {self.n_workers}, Batch size: {self.batch_size}")
            self._log("=" * 60)
        
        # 1. 학생 생성
        if verbose:
            self._log("[1/4] Generating students...")
        
        self.students = self.student_gen.generate_students()
        
        tier_counts = {}
        for s in self.students:
            tier_counts[s.tier] = tier_counts.get(s.tier, 0) + 1
        
        if verbose:
            for tier in sorted(tier_counts.keys()):
                self._log(f"  Tier {tier}: {tier_counts[tier]} ({tier_counts[tier]/self.n_students*100:.1f}%)")
        
        # 2. 배치 시뮬레이션 (순차 또는 병렬)
        if verbose:
            self._log(f"\n[2/4] Running simulation (batch_size={self.batch_size})...")
        
        # 배치로 나누기
        batches = []
        for i in range(0, len(self.students), self.batch_size):
            batch = self.students[i:i + self.batch_size]
            batches.append({
                'students': batch,
                'seed': self.seed + i * 100,
                'batch_id': i // self.batch_size,
            })
        
        total_problems = 0
        completed = 0
        
        # 순차 처리 (Windows에서 multiprocessing 이슈 방지)
        for batch_data in batches:
            result = simulate_student_batch(batch_data)
            
            # 결과 병합
            for student in result['students']:
                # rating_engine 병합
                state = result['rating_engine'].student_ratings.get(student.student_id)
                if state:
                    self.rating_engine.student_ratings[student.student_id] = state
            
            total_problems += result['total_problems']
            completed += len(batch_data['students'])
            
            # 3명마다 진행률 출력
            if verbose and completed % 3 == 0:
                pct = completed / self.n_students * 100
                self._log(f"  Progress: {completed}/{self.n_students} ({pct:.1f}%) - {total_problems:,} problems")
        
        if verbose:
            self._log(f"\n  Total problems: {total_problems:,}")
            self._log(f"  Avg per student: {total_problems / self.n_students:,.0f}")
        
        # 3. 분석
        if verbose:
            self._log("\n[3/4] Analyzing results...")
        
        analysis = self._analyze(total_problems)
        
        # 4. 검증
        if verbose:
            self._log("\n[4/4] Validating...")
        
        validation = self._validate()
        
        return {
            'students': self.students,
            'records': self.all_records,
            'analysis': analysis,
            'validation': validation,
            'rating_engine': self.rating_engine,
        }
    
    def _analyze(self, total_problems: int = 0) -> dict:
        tier_stats = {}
        for tier in range(1, 7):
            tier_students = [s for s in self.students if s.tier == tier]
            if not tier_students:
                continue
            
            avg_problems = sum(s.total_problems for s in tier_students) / len(tier_students)
            avg_correct = sum(s.total_correct for s in tier_students) / max(1, sum(s.total_problems for s in tier_students))
            avg_study_days = sum(len(s.study_days) for s in tier_students) / len(tier_students)
            
            ratings = [self.rating_engine.get_student_rating(s.student_id)[0] for s in tier_students]
            avg_rating = sum(ratings) / len(ratings) if ratings else 0
            
            tier_stats[tier] = {
                'count': len(tier_students),
                'avg_problems': avg_problems,
                'avg_accuracy': avg_correct,
                'avg_study_days': avg_study_days,
                'avg_rating': avg_rating,
                'rating_std': statistics.stdev(ratings) if len(ratings) > 1 else 0,
                'min_rating': min(ratings) if ratings else 0,
                'max_rating': max(ratings) if ratings else 0,
            }
        
        return {
            'tier_stats': tier_stats,
            'total_records': total_problems,
            'total_students': len(self.students),
        }
    
    def _validate(self) -> dict:
        # 1. 등급별 레이팅
        tier_ratings = {tier: [] for tier in range(1, 7)}
        for student in self.students:
            rating, _ = self.rating_engine.get_student_rating(student.student_id)
            tier_ratings[student.tier].append(rating)
        
        # 2. 실력 vs 레이팅
        true_skills = []
        final_ratings = []
        for student in self.students:
            avg_skill = sum(ts.true_skill for ts in student.tag_skills.values()) / max(1, len(student.tag_skills))
            rating, _ = self.rating_engine.get_student_rating(student.student_id)
            true_skills.append(avg_skill)
            final_ratings.append(rating)
        
        corr = self._pearson_corr(true_skills, final_ratings)
        
        # 3. 태그 상관관계
        tag_corrs = []
        all_tags = list(self.students[0].tag_skills.keys())
        sample_tags = random.sample(all_tags, min(20, len(all_tags)))
        
        for tag in sample_tags:
            tag_skills = []
            tag_ratings = []
            for student in self.students:
                ts = student.tag_skills.get(tag)
                if ts:
                    tag_skills.append(ts.true_skill)
                    tr, _ = self.rating_engine.get_tag_rating(student.student_id, tag)
                    tag_ratings.append(tr)
            
            if len(tag_skills) > 2:
                tc = self._pearson_corr(tag_skills, tag_ratings)
                tag_corrs.append(tc)
        
        avg_tag_corr = sum(tag_corrs) / len(tag_corrs) if tag_corrs else 0
        
        # 4. 정답률 vs 레이팅
        accuracies = []
        ratings = []
        for student in self.students:
            acc = student.total_correct / max(1, student.total_problems)
            rating, _ = self.rating_engine.get_student_rating(student.student_id)
            accuracies.append(acc)
            ratings.append(rating)
        
        acc_corr = self._pearson_corr(accuracies, ratings)
        
        return {
            'true_skill_rating_corr': corr,
            'avg_tag_corr': avg_tag_corr,
            'accuracy_rating_corr': acc_corr,
            'tier_ratings': {t: {'mean': sum(v)/len(v), 'std': statistics.stdev(v) if len(v) > 1 else 0} 
                           for t, v in tier_ratings.items() if v},
            'tag_correlations': tag_corrs,
        }
    
    @staticmethod
    def _pearson_corr(x: List[float], y: List[float]) -> float:
        n = len(x)
        if n < 2:
            return 0.0
        
        mx = sum(x) / n
        my = sum(y) / n
        
        cov = sum((x[i] - mx) * (y[i] - my) for i in range(n))
        sx = math.sqrt(sum((xi - mx) ** 2 for xi in x))
        sy = math.sqrt(sum((yi - my) ** 2 for yi in y))
        
        if sx == 0 or sy == 0:
            return 0.0
        
        return cov / (sx * sy)


# ───────────────────────────────────────────────
# 리포트 생성
# ───────────────────────────────────────────────

def generate_report(result: dict, output_path: str = "simulation_report.json",
                    logger: ProgressLogger = None):
    analysis = result['analysis']
    validation = result['validation']
    
    def log(msg):
        if logger:
            logger.log(msg)
        else:
            print(msg)
    
    lines = []
    lines.append("=" * 60)
    lines.append("CSAT Rating Simulation Report v4")
    lines.append("=" * 60)
    
    lines.append("\n[Basic Stats]")
    lines.append(f"  Total students: {analysis['total_students']}")
    lines.append(f"  Total records: {analysis['total_records']:,}")
    lines.append(f"  Avg per student: {analysis['total_records'] / analysis['total_students']:,.0f}")
    
    lines.append("\n[Tier Stats]")
    for tier in sorted(analysis['tier_stats'].keys()):
        s = analysis['tier_stats'][tier]
        lines.append(f"  Tier {tier}: n={s['count']}, "
                    f"acc={s['avg_accuracy']:.1%}, "
                    f"rating={s['avg_rating']:.1f} (±{s['rating_std']:.1f}) "
                    f"[{s['min_rating']:.0f}~{s['max_rating']:.0f}]")
    
    lines.append("\n[Validation]")
    v = validation
    lines.append(f"  true_skill_corr: {v['true_skill_rating_corr']:.3f}")
    lines.append(f"  tag_corr: {v['avg_tag_corr']:.3f}")
    lines.append(f"  accuracy_corr: {v['accuracy_rating_corr']:.3f}")
    
    # 등급 순서 검사
    lines.append("\n[Tier Order Check]")
    tier_means = {t: stats['mean'] for t, stats in v.get('tier_ratings', {}).items()}
    sorted_tiers = sorted(tier_means.items(), key=lambda x: x[1], reverse=True)
    lines.append(f"  By rating (high to low): {[t for t, _ in sorted_tiers]}")
    
    expected_order = [1, 2, 3, 4, 5, 6]
    actual_order = [t for t, _ in sorted_tiers]
    
    if actual_order == expected_order:
        lines.append("  [OK] Tier order is CORRECT")
    else:
        lines.append(f"  [FAIL] Tier order is WRONG! Expected {expected_order}, got {actual_order}")
    
    # 평가
    lines.append("\n[Evaluation]")
    score = 0
    if abs(v['true_skill_rating_corr']) > 0.5:
        lines.append("  [OK] true_skill correlation > 0.5")
        score += 1
    else:
        lines.append("  [FAIL] true_skill correlation too low")
    
    if abs(v['avg_tag_corr']) > 0.5:
        lines.append("  [OK] tag correlation > 0.5")
        score += 1
    else:
        lines.append("  [FAIL] tag correlation too low")
    
    if abs(v['accuracy_rating_corr']) > 0.3:
        lines.append("  [OK] accuracy correlation > 0.3")
        score += 1
    else:
        lines.append("  [FAIL] accuracy correlation too low")
    
    lines.append(f"\n  Score: {score}/3")
    
    report_text = "\n".join(lines)
    log(report_text)
    
    # 파일 저장
    output_path_obj = Path(output_path)
    if not output_path_obj.is_absolute():
        output_path_obj = Path.cwd() / output_path_obj.name
    
    with open(output_path_obj, 'w', encoding='utf-8') as f:
        f.write(report_text)
    
    json_path = str(output_path_obj.with_suffix('')) + '_data.json'
    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump({
            'analysis': {k: v for k, v in analysis.items() if k != 'tier_stats'},
            'validation': {
                'true_skill_rating_corr': v['true_skill_rating_corr'],
                'avg_tag_corr': v['avg_tag_corr'],
                'accuracy_rating_corr': v['accuracy_rating_corr'],
                'tier_ratings': v.get('tier_ratings', {}),
            },
        }, f, ensure_ascii=False, indent=2)
    
    return report_text


# ───────────────────────────────────────────────
# 메인 실행
# ───────────────────────────────────────────────

if __name__ == '__main__':
    import sys
    
    n_students = int(sys.argv[1]) if len(sys.argv) > 1 else 500
    seed = int(sys.argv[2]) if len(sys.argv) > 2 else 42
    batch_size = int(sys.argv[3]) if len(sys.argv) > 3 else 3
    
    with ProgressLogger("simulation_progress.log") as logger:
        logger.log(f"Starting: {n_students} students, seed={seed}, batch_size={batch_size}")
        
        sim = MassiveSimulator(
            n_students=n_students, seed=seed,
            fast_mode=True, batch_size=batch_size,
            logger=logger
        )
        
        start = time.time()
        result = sim.run(verbose=True)
        elapsed = time.time() - start
        
        logger.log(f"\nSimulation complete: {elapsed:.1f}s ({elapsed/60:.1f} min)")
        
        # 리포트
        report = generate_report(result, "simulation_report.txt", logger)
        
        logger.log("\nDone! Check simulation_report.txt and simulation_progress.log")
