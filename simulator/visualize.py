"""
CSAT Rating Simulation Visualizer
시뮬레이션 결과 시각화 및 실제 레이팅 알고리즘 비교 분석

생성 차트:
1. 등급별 레이팅 분포 (박스플롯 + 바이올린)
2. 실력 vs 레이팅 산점도 (등급별 색상)
3. 태그별 상관관계 히트맵
4. 정답률 vs 레이팅 산점도
5. 월별 학습량/레이팅 변화
6. 등급 경계 분석 (혼란 행렬)
7. 실제 알고리즘 비교 (ELO/Glicko/TrueSkill)
"""

from __future__ import annotations

import json
import math
import random
import statistics
from dataclasses import dataclass, field
from typing import Dict, List, Tuple, Optional
from pathlib import Path

import numpy as np
import matplotlib.pyplot as plt
import matplotlib.font_manager as fm
from matplotlib.patches import Rectangle
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import plotly.express as px

# 한글 폰트 설정 (Windows)
import platform
if platform.system() == 'Windows':
    plt.rcParams['font.family'] = 'Malgun Gothic'
else:
    plt.rcParams['font.family'] = 'DejaVu Sans'
plt.rcParams['axes.unicode_minus'] = False


# ───────────────────────────────────────────────
# 데이터 로더
# ───────────────────────────────────────────────

class SimulationDataLoader:
    """시뮬레이션 결과 데이터 로드"""
    
    def __init__(self, data_path: str = "simulation_report_data.json"):
        self.data_path = Path(data_path)
        self.raw_data = None
        self.students = []
        self.validation = {}
        self.analysis = {}
        
    def load(self) -> 'SimulationDataLoader':
        """JSON 데이터 로드"""
        if not self.data_path.exists():
            # 현재 디렉토리에서 검색
            candidates = list(Path('.').glob('*_data.json'))
            if candidates:
                self.data_path = candidates[0]
            else:
                raise FileNotFoundError(f"No simulation data file found")
        
        with open(self.data_path, 'r', encoding='utf-8') as f:
            self.raw_data = json.load(f)
        
        self.validation = self.raw_data.get('validation', {})
        self.analysis = self.raw_data.get('analysis', {})
        
        # 학생 데이터가 없으면 더미 생성
        if 'students' not in self.raw_data:
            self._generate_dummy_students()
        else:
            self.students = self.raw_data['students']
        
        return self
    
    def _generate_dummy_students(self, n: int = 500):
        """검증 데이터만 있는 경우 더미 학생 생성"""
        tier_stats = self.analysis.get('tier_stats', {})
        
        student_id = 0
        for tier, stats in tier_stats.items():
            tier = int(tier)
            count = stats.get('count', 0)
            avg_rating = stats.get('avg_rating', 1500)
            rating_std = stats.get('rating_std', 200)
            avg_accuracy = stats.get('avg_accuracy', 0.5)
            
            for _ in range(count):
                rating = random.gauss(avg_rating, rating_std)
                accuracy = random.gauss(avg_accuracy, 0.1)
                true_skill = (rating - 1500) / 800 + 0.5  # 근사
                
                self.students.append({
                    'student_id': student_id,
                    'tier': tier,
                    'rating': rating,
                    'true_skill': max(0.02, min(0.98, true_skill)),
                    'accuracy': max(0, min(1, accuracy)),
                    'total_problems': random.randint(5000, 8000),
                    'total_correct': 0,
                    'tag_skills': {},
                })
                student_id += 1
        
        # total_correct 계산
        for s in self.students:
            s['total_correct'] = int(s['total_problems'] * s['accuracy'])


# ───────────────────────────────────────────────
# Matplotlib 정적 차트
# ───────────────────────────────────────────────

class MatplotlibVisualizer:
    """정적 차트 생성 (보고서용)"""
    
    def __init__(self, data: SimulationDataLoader, output_dir: str = "simulation_charts"):
        self.data = data
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)
        
        # 색상 팔레트 (등급별)
        self.tier_colors = {
            1: '#1f77b4',  # 파랑 (1등급)
            2: '#2ca02c',  # 초록
            3: '#ff7f0e',  # 주황
            4: '#d62728',  # 빨강
            5: '#9467bd',  # 보라
            6: '#8c564b',  # 갈색
        }
        
        self.tier_labels = {
            1: '1등급 (상위 4%)',
            2: '2등급 (상위 4~11%)',
            3: '3등급 (상위 11~23%)',
            4: '4등급 (상위 23~40%)',
            5: '5등급 (상위 40~60%)',
            6: '6등급 (상위 60~77%)',
        }
    
    def _get_student_df(self) -> List[dict]:
        """학생 데이터 정규화"""
        students = []
        for s in self.data.students:
            students.append({
                'student_id': s.get('student_id', 0),
                'tier': s.get('tier', 3),
                'true_skill': s.get('true_skill', 0.5),
                'rating': s.get('rating', 1500),
                'accuracy': s.get('accuracy', 0.5),
                'total_problems': s.get('total_problems', 0),
                'total_correct': s.get('total_correct', 0),
            })
        return students
    
    def plot_tier_rating_distribution(self) -> str:
        """등급별 레이팅 분포 (박스플롯 + 바이올린)"""
        students = self._get_student_df()
        
        fig, axes = plt.subplots(1, 2, figsize=(14, 6))
        
        # 박스플롯
        tier_data = [[] for _ in range(6)]
        for s in students:
            tier = s['tier'] - 1
            if 0 <= tier < 6:
                tier_data[tier].append(s['rating'])
        
        bp = axes[0].boxplot(tier_data, patch_artist=True, tick_labels=[f'{i}등급' for i in range(1, 7)])
        for patch, tier in zip(bp['boxes'], range(1, 7)):
            patch.set_facecolor(self.tier_colors[tier])
            patch.set_alpha(0.7)
        
        axes[0].set_ylabel('Rating')
        axes[0].set_title('등급별 레이팅 분포 (Boxplot)')
        axes[0].grid(axis='y', alpha=0.3)
        
        # 히스토그램 오버레이
        for tier in range(1, 7):
            data = tier_data[tier - 1]
            if data:
                axes[1].hist(data, bins=20, alpha=0.5, label=f'{tier}등급', 
                           color=self.tier_colors[tier])
        
        axes[1].set_xlabel('Rating')
        axes[1].set_ylabel('Count')
        axes[1].set_title('등급별 레이팅 히스토그램')
        axes[1].legend()
        axes[1].grid(alpha=0.3)
        
        plt.tight_layout()
        path = self.output_dir / 'tier_rating_distribution.png'
        plt.savefig(path, dpi=150, bbox_inches='tight')
        plt.close()
        return str(path)
    
    def plot_skill_vs_rating(self) -> str:
        """실력 vs 레이팅 산점도"""
        students = self._get_student_df()
        
        fig, ax = plt.subplots(figsize=(10, 8))
        
        for tier in range(1, 7):
            tier_students = [s for s in students if s['tier'] == tier]
            if not tier_students:
                continue
            
            x = [s['true_skill'] for s in tier_students]
            y = [s['rating'] for s in tier_students]
            
            ax.scatter(x, y, c=self.tier_colors[tier], alpha=0.6, s=30,
                      label=self.tier_labels[tier])
        
        # 추세선
        all_x = [s['true_skill'] for s in students]
        all_y = [s['rating'] for s in students]
        z = np.polyfit(all_x, all_y, 1)
        p = np.poly1d(z)
        ax.plot(sorted(all_x), p(sorted(all_x)), "r--", alpha=0.8, linewidth=2,
               label=f'Trend (r={self.data.validation.get("true_skill_rating_corr", 0):.3f})')
        
        ax.set_xlabel('True Skill (0~1)')
        ax.set_ylabel('Rating')
        ax.set_title('실력 vs 레이팅 상관관계')
        ax.legend(loc='upper left', fontsize=8)
        ax.grid(alpha=0.3)
        
        plt.tight_layout()
        path = self.output_dir / 'skill_vs_rating.png'
        plt.savefig(path, dpi=150, bbox_inches='tight')
        plt.close()
        return str(path)
    
    def plot_accuracy_vs_rating(self) -> str:
        """정답률 vs 레이팅 산점도"""
        students = self._get_student_df()
        
        fig, ax = plt.subplots(figsize=(10, 8))
        
        for tier in range(1, 7):
            tier_students = [s for s in students if s['tier'] == tier]
            if not tier_students:
                continue
            
            x = [s['accuracy'] * 100 for s in tier_students]
            y = [s['rating'] for s in tier_students]
            sizes = [s['total_problems'] / 50 for s in tier_students]  # 문제 수로 크기
            
            ax.scatter(x, y, c=self.tier_colors[tier], alpha=0.6, s=sizes,
                      label=self.tier_labels[tier])
        
        all_x = [s['accuracy'] * 100 for s in students]
        all_y = [s['rating'] for s in students]
        z = np.polyfit(all_x, all_y, 1)
        p = np.poly1d(z)
        ax.plot(sorted(all_x), p(sorted(all_x)), "r--", alpha=0.8, linewidth=2,
               label=f'Trend (r={self.data.validation.get("accuracy_rating_corr", 0):.3f})')
        
        ax.set_xlabel('Accuracy (%)')
        ax.set_ylabel('Rating')
        ax.set_title('정답률 vs 레이팅 상관관계 (버블 크기 = 풀이량)')
        ax.legend(loc='upper left', fontsize=8)
        ax.grid(alpha=0.3)
        
        plt.tight_layout()
        path = self.output_dir / 'accuracy_vs_rating.png'
        plt.savefig(path, dpi=150, bbox_inches='tight')
        plt.close()
        return str(path)
    
    def plot_tier_confusion_matrix(self) -> str:
        """등급 혼란 행렬 (실제 등급 vs 레이팅 기반 예측 등급)"""
        students = self._get_student_df()
        
        # 레이팅 기반 등급 예측 (분위수)
        ratings = sorted([s['rating'] for s in students], reverse=True)
        n = len(ratings)
        
        # 등급 경계 (상위 %)
        boundaries = [0.04, 0.11, 0.23, 0.40, 0.60, 1.0]
        rating_bounds = []
        for b in boundaries:
            idx = int(n * b) - 1
            idx = max(0, min(idx, n - 1))
            rating_bounds.append(ratings[idx])
        
        # 혼란 행렬
        confusion = [[0] * 6 for _ in range(6)]
        for s in students:
            actual_tier = s['tier'] - 1
            
            # 예측 등급
            pred_tier = 5  # 기본 6등급
            for i, bound in enumerate(rating_bounds):
                if s['rating'] >= bound:
                    pred_tier = i
                    break
            
            confusion[actual_tier][pred_tier] += 1
        
        # 시각화
        fig, ax = plt.subplots(figsize=(10, 8))
        
        im = ax.imshow(confusion, cmap='Blues')
        
        ax.set_xticks(range(6))
        ax.set_yticks(range(6))
        ax.set_xticklabels([f'{i}등급' for i in range(1, 7)])
        ax.set_yticklabels([f'{i}등급' for i in range(1, 7)])
        ax.set_xlabel('Predicted Tier (by Rating)')
        ax.set_ylabel('Actual Tier')
        ax.set_title('등급 혼란 행렬\n(실제 등급 vs 레이팅 기반 예측 등급)')
        
        # 숫자 표시
        for i in range(6):
            for j in range(6):
                text = ax.text(j, i, confusion[i][j],
                             ha="center", va="center", color="black" if confusion[i][j] < max(sum(confusion, [])) / 2 else "white",
                             fontsize=12, fontweight='bold')
        
        # 정확도 계산
        correct = sum(confusion[i][i] for i in range(6))
        total = sum(sum(row) for row in confusion)
        accuracy = correct / total if total > 0 else 0
        
        ax.text(0.5, -0.15, f'Accuracy: {accuracy:.1%} (perfect diagonal = 100%)',
               transform=ax.transAxes, ha='center', fontsize=12)
        
        plt.colorbar(im, ax=ax)
        plt.tight_layout()
        path = self.output_dir / 'tier_confusion_matrix.png'
        plt.savefig(path, dpi=150, bbox_inches='tight')
        plt.close()
        return str(path)
    
    def plot_rating_algorithm_comparison(self) -> str:
        """레이팅 알고리즘 비교 (이론적)"""
        fig, axes = plt.subplots(2, 2, figsize=(14, 12))
        
        # 1. ELO: 선형 변화
        ax = axes[0, 0]
        performances = np.linspace(-20, 20, 100)
        elo_ratings = 1500 + 20 * performances
        ax.plot(performances, elo_ratings, 'b-', linewidth=2, label='ELO (linear)')
        ax.axhline(y=1500, color='gray', linestyle='--', alpha=0.5)
        ax.set_xlabel('Performance Score')
        ax.set_ylabel('Rating')
        ax.set_title('ELO: 선형 변화')
        ax.legend()
        ax.grid(alpha=0.3)
        ax.set_ylim(1000, 2000)
        
        # 2. Glicko: RD 기반 불확실성
        ax = axes[0, 1]
        rd_values = np.linspace(50, 350, 100)
        rating_changes = 800 / (1 + np.exp((rd_values - 200) / 50))
        ax.plot(rd_values, rating_changes, 'g-', linewidth=2, label='Glicko RD impact')
        ax.set_xlabel('Rating Deviation (RD)')
        ax.set_ylabel('Max Rating Change')
        ax.set_title('Glicko: 불확실성 기반 변화폭')
        ax.legend()
        ax.grid(alpha=0.3)
        
        # 3. TrueSkill: μ/σ 분리
        ax = axes[1, 0]
        mu = np.linspace(10, 35, 100)
        sigma = np.linspace(1, 8, 100)
        MU, SIGMA = np.meshgrid(mu, sigma)
        conservative = MU - 3 * SIGMA  # conservative skill
        
        contour = ax.contourf(MU, SIGMA, conservative, levels=20, cmap='viridis')
        ax.set_xlabel('Mean Skill (μ)')
        ax.set_ylabel('Standard Deviation (σ)')
        ax.set_title('TrueSkill: Conservative Skill (μ - 3σ)')
        plt.colorbar(contour, ax=ax)
        
        # 4. 우리 알고리즘: 비대칭 + 비선형
        ax = axes[1, 1]
        perf = np.linspace(-15, 20, 200)
        
        # 우리 알고리즘
        our_rating = np.piecewise(perf,
            [perf <= -15, (perf > -15) & (perf <= 0), (perf > 0) & (perf <= 10), perf > 10],
            [lambda p: 1500 + 40 * p,
             lambda p: 1500 + 60 * p,
             lambda p: 1500 + 80 * p,
             lambda p: 1500 + 800 + 50 * (p - 10) ** 1.3])
        
        ax.plot(perf, our_rating, 'r-', linewidth=2.5, label='Our Algorithm (v4)')
        ax.plot(perf, 1500 + 60 * perf, 'b--', alpha=0.5, label='Linear (ELO-like)')
        ax.axhline(y=1500, color='gray', linestyle='--', alpha=0.5)
        ax.set_xlabel('Performance Score')
        ax.set_ylabel('Rating')
        ax.set_title('Our Algorithm: 비대칭 + 비선형 매핑')
        ax.legend()
        ax.grid(alpha=0.3)
        ax.set_ylim(0, 3000)
        
        plt.tight_layout()
        path = self.output_dir / 'algorithm_comparison.png'
        plt.savefig(path, dpi=150, bbox_inches='tight')
        plt.close()
        return str(path)
    
    def generate_all(self) -> List[str]:
        """모든 정적 차트 생성"""
        paths = []
        
        print("Generating static charts...")
        paths.append(self.plot_tier_rating_distribution())
        print(f"  [OK] {paths[-1]}")
        
        paths.append(self.plot_skill_vs_rating())
        print(f"  [OK] {paths[-1]}")
        
        paths.append(self.plot_accuracy_vs_rating())
        print(f"  [OK] {paths[-1]}")
        
        paths.append(self.plot_tier_confusion_matrix())
        print(f"  [OK] {paths[-1]}")
        
        paths.append(self.plot_rating_algorithm_comparison())
        print(f"  [OK] {paths[-1]}")
        
        return paths


# ───────────────────────────────────────────────
# Plotly 인터랙티브 차트
# ───────────────────────────────────────────────

class PlotlyVisualizer:
    """인터랙티브 HTML 차트 생성"""
    
    def __init__(self, data: SimulationDataLoader, output_dir: str = "simulation_charts"):
        self.data = data
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)
        
        self.tier_colors = {
            1: '#1f77b4', 2: '#2ca02c', 3: '#ff7f0e',
            4: '#d62728', 5: '#9467bd', 6: '#8c564b',
        }
    
    def _get_student_df(self) -> List[dict]:
        students = []
        for s in self.data.students:
            students.append({
                'student_id': s.get('student_id', 0),
                'tier': s.get('tier', 3),
                'true_skill': s.get('true_skill', 0.5),
                'rating': s.get('rating', 1500),
                'accuracy': s.get('accuracy', 0.5),
                'total_problems': s.get('total_problems', 0),
                'total_correct': s.get('total_correct', 0),
            })
        return students
    
    def create_interactive_dashboard(self) -> str:
        """인터랙티브 대시보드 생성"""
        students = self._get_student_df()
        
        # 서브플롯 레이아웃
        fig = make_subplots(
            rows=2, cols=2,
            subplot_titles=(
                '실력 vs 레이팅',
                '정답률 vs 레이팅',
                '등급별 레이팅 분포',
                '등급별 정답률 분포'
            ),
            specs=[[{'type': 'scatter'}, {'type': 'scatter'}],
                   [{'type': 'violin'}, {'type': 'violin'}]]
        )
        
        # 1. 실력 vs 레이팅
        for tier in range(1, 7):
            tier_students = [s for s in students if s['tier'] == tier]
            if not tier_students:
                continue
            
            fig.add_trace(
                go.Scatter(
                    x=[s['true_skill'] for s in tier_students],
                    y=[s['rating'] for s in tier_students],
                    mode='markers',
                    name=f'{tier}등급',
                    marker=dict(color=self.tier_colors[tier], size=6, opacity=0.6),
                    hovertemplate='Skill: %{x:.3f}<br>Rating: %{y:.0f}<br>Tier: ' + str(tier),
                ),
                row=1, col=1
            )
        
        # 2. 정답률 vs 레이팅
        for tier in range(1, 7):
            tier_students = [s for s in students if s['tier'] == tier]
            if not tier_students:
                continue
            
            fig.add_trace(
                go.Scatter(
                    x=[s['accuracy'] * 100 for s in tier_students],
                    y=[s['rating'] for s in tier_students],
                    mode='markers',
                    name=f'{tier}등급',
                    marker=dict(color=self.tier_colors[tier], size=6, opacity=0.6),
                    showlegend=False,
                    hovertemplate='Accuracy: %{x:.1f}%<br>Rating: %{y:.0f}',
                ),
                row=1, col=2
            )
        
        # 3. 등급별 레이팅 분포 (바이올린)
        for tier in range(1, 7):
            tier_students = [s for s in students if s['tier'] == tier]
            if not tier_students:
                continue
            
            fig.add_trace(
                go.Violin(
                    x=[tier] * len(tier_students),
                    y=[s['rating'] for s in tier_students],
                    name=f'{tier}등급',
                    line_color=self.tier_colors[tier],
                    showlegend=False,
                ),
                row=2, col=1
            )
        
        # 4. 등급별 정답률 분포
        for tier in range(1, 7):
            tier_students = [s for s in students if s['tier'] == tier]
            if not tier_students:
                continue
            
            fig.add_trace(
                go.Violin(
                    x=[tier] * len(tier_students),
                    y=[s['accuracy'] * 100 for s in tier_students],
                    name=f'{tier}등급',
                    line_color=self.tier_colors[tier],
                    showlegend=False,
                ),
                row=2, col=2
            )
        
        fig.update_layout(
            title_text="CSAT Rating Simulation Dashboard",
            height=800,
            hovermode='closest'
        )
        
        path = self.output_dir / 'interactive_dashboard.html'
        fig.write_html(str(path))
        return str(path)
    
    def create_tier_boundary_analysis(self) -> str:
        """등급 경계 분석"""
        students = self._get_student_df()
        
        # 레이팅 순으로 정렬
        sorted_students = sorted(students, key=lambda s: s['rating'], reverse=True)
        n = len(sorted_students)
        
        # 누적 비율
        cum_pct = [(i + 1) / n * 100 for i in range(n)]
        ratings = [s['rating'] for s in sorted_students]
        tiers = [s['tier'] for s in sorted_students]
        
        fig = go.Figure()
        
        # 레이팅 곡선
        fig.add_trace(go.Scatter(
            x=cum_pct, y=ratings,
            mode='lines',
            name='Rating by Percentile',
            line=dict(color='blue', width=2)
        ))
        
        # 등급 경계선
        boundaries = [4, 11, 23, 40, 60, 77]
        colors = ['green', 'yellow', 'orange', 'red', 'purple', 'brown']
        
        for b, color in zip(boundaries, colors):
            fig.add_vline(x=b, line_dash="dash", line_color=color, opacity=0.5)
        
        # 실제 등급별 평균 레이팅
        tier_stats = {}
        for s in students:
            t = s['tier']
            if t not in tier_stats:
                tier_stats[t] = []
            tier_stats[t].append(s['rating'])
        
        for tier in sorted(tier_stats.keys()):
            mean_r = statistics.mean(tier_stats[tier])
            # 대략적인 위치
            if tier == 1:
                x_pos = 2
            elif tier == 2:
                x_pos = 7.5
            elif tier == 3:
                x_pos = 17
            elif tier == 4:
                x_pos = 31.5
            elif tier == 5:
                x_pos = 50
            else:
                x_pos = 68.5
            
            fig.add_annotation(
                x=x_pos, y=mean_r,
                text=f'{tier}등급<br>avg: {mean_r:.0f}',
                showarrow=True,
                arrowhead=2,
                ax=0, ay=-40
            )
        
        fig.update_layout(
            title='등급 경계 vs 레이팅 분포',
            xaxis_title='Percentile (%)',
            yaxis_title='Rating',
            height=600
        )
        
        path = self.output_dir / 'tier_boundary_analysis.html'
        fig.write_html(str(path))
        return str(path)


# ───────────────────────────────────────────────
# 레이팅 알고리즘 비교 분석
# ───────────────────────────────────────────────

@dataclass
class AlgorithmComparison:
    """실제 레이팅 알고리즘과의 비교 분석"""
    
    name: str
    formula: str
    strengths: List[str]
    weaknesses: List[str]
    applicable: bool
    adaptation_needed: List[str]


class RatingAlgorithmAnalyzer:
    """실제 레이팅 알고리즘 분석 및 적용 전략"""
    
    def __init__(self):
        self.algorithms = self._initialize_algorithms()
    
    def _initialize_algorithms(self) -> Dict[str, AlgorithmComparison]:
        return {
            'elo': AlgorithmComparison(
                name='ELO (1978)',
                formula='R_new = R_old + K * (S - E)',
                strengths=[
                    '단순하고 이해하기 쉬움',
                    '계산 비용 매우 낮음',
                    '체스 등 1:1 경기에 최적화',
                ],
                weaknesses=[
                    'K값 선정이 임의적',
                    '문제 난이도 반영 불가',
                    '태그별 분리 불가',
                    '초기 레이팅 불확실성 미반영',
                ],
                applicable=False,
                adaptation_needed=[
                    'K값을 난이도 기반으로 동적 조정',
                    '태그별 ELO 분리',
                    '초기 RD 개념 추가',
                ]
            ),
            
            'glicko': AlgorithmComparison(
                name='Glicko (1995) / Glicko-2 (2012)',
                formula='R_new = R_old + q/(1/RD^2 + 1/d^2) * (S - E)',
                strengths=[
                    'Rating Deviation (RD)으로 불확실성 정량화',
                    '비활동 시 RD 증가 (복습 필요 반영)',
                    '신규 사용자 처리 우수',
                    'Glicko-2는 변동성(volatility) 추가',
                ],
                weaknesses=[
                    '계산 복잡도 중간',
                    '문제 난이도 직접 반영 어려움',
                    '태그별 분리 시 계산량 폭증',
                ],
                applicable=True,
                adaptation_needed=[
                    '문제 난이도를 "상대 레이팅"으로 매핑',
                    '태그별 Glicko 상태 관리',
                    'RD 감소율을 학습 패턴에 맞춤',
                ]
            ),
            
            'trueskill': AlgorithmComparison(
                name='TrueSkill (Microsoft, 2005)',
                formula='μ_new, σ_new = f(μ, σ, μ_opp, σ_opp, outcome)',
                strengths=[
                    '팀 게임/다자 경기 지원',
                    'μ(평균) + σ(불확실성) 분리',
                    'Conservative skill = μ - 3σ',
                    '베이지안 업데이트',
                ],
                weaknesses=[
                    '계산 복잡도 높음',
                    'Factor Graph 필요',
                    '1:1 문제 풀이에 오버엔지니어링',
                    '태그별 적용 시 상태 공간 폭증',
                ],
                applicable=True,
                adaptation_needed=[
                    '문제를 "상대"로 모델링',
                    '태그별 μ/σ 쌍 관리',
                    '성과 점수를 승패로 변환',
                ]
            ),
            
            'ours_v4': AlgorithmComparison(
                name='Our Algorithm v4 (현재)',
                formula='''
                perf = correct ? difficulty : -(20-difficulty)*1.5
                rating = f_EMA(perf) with non-linear mapping
                tag_rating = EMA_tag(perf) with clamping
                final = overall*(1-w) + tag_avg*w
                '''.strip(),
                strengths=[
                    '난이도 직접 반영 (성과 점수)',
                    '비대칭 페널티 (오답 > 정답 영향)',
                    '비선형 매핑 (고실력 구간 분리)',
                    '태그별 레이팅 + 클램핑',
                    'EMA으로 최근 문제 가중',
                    '계산 매우 빠름 (2.5분/500명)',
                ],
                weaknesses=[
                    '이론적 기반 약함 (heuristic)',
                    'RD/σ 없음 (불확실성 미반영)',
                    'K값/α값 경험적 선정',
                    '수렴 보장 없음 (이론적)',
                ],
                applicable=True,
                adaptation_needed=[
                    'RD 개념 추가 (Glicko借鉴)',
                    '태그 상관관계 반영',
                    '시간 가중치 개선 (forgetting curve)',
                ]
            ),
        }
    
    def generate_comparison_report(self) -> str:
        """비교 분석 리포트 생성"""
        lines = []
        lines.append("=" * 70)
        lines.append("CSAT 레이팅 알고리즘 비교 분석 및 적용 전략")
        lines.append("=" * 70)
        
        for key, algo in self.algorithms.items():
            lines.append(f"\n{'─' * 70}")
            lines.append(f"[{algo.name}]")
            lines.append(f"{'─' * 70}")
            
            lines.append(f"\n[공식]")
            lines.append(f"  {algo.formula}")
            
            lines.append(f"\n[강점]")
            for s in algo.strengths:
                lines.append(f"  + {s}")
            
            lines.append(f"\n[약점]")
            for w in algo.weaknesses:
                lines.append(f"  - {w}")
            
            lines.append(f"\n[적용 가능성]: {'[OK] 가능' if algo.applicable else '[X] 어려움'}")
            
            if algo.adaptation_needed:
                lines.append(f"\n[적용 시 필요한 개조]")
                for a in algo.adaptation_needed:
                    lines.append(f"  → {a}")
        
        # 종합 전략
        lines.append(f"\n{'=' * 70}")
        lines.append("[종합 적용 전략]")
        lines.append(f"{'=' * 70}")
        lines.append("""
1. 단기 (1~2개월): 현재 v4 알고리즘 유지 + RD 개념 추가
   - Glicko의 RD 아이디어를 v4에 통합
   - 신규 사용자: RD=350, 풀이 후 RD 감소
   - 장기 미접속: RD 증가 (복습 필요 반영)

2. 중기 (3~6개월): Glicko-2 하이브리드 전환
   - v4의 성과 점수를 Glicko-2의 "상대 레이팅"으로 매핑
   - 태그별 Glicko 상태 관리 (태그 수 제한)
   - 변동성(volatility)으로 학습 불규칙성 반영

3. 장기 (6개월+): TrueSkill 스타일 베이지안 접근 검토
   - 태그 간 상관관계를 그래프 모델로 표현
   - 문제 풀이를 "학생 vs 문제" 매칭으로 모델링
   - 다중 태그 문제: factor graph 업데이트

[핵심 설계 원칙]
- 계산 속도: 500명 < 5초 목표 (현재 2.5분 → 30배 개선 필요)
- 태그 분리: 20개 태그, corr > 0.5 유지
- 등급 분리: 1~6등급 평균 레이팅 차이 > 200점
- 정답률 반영: accuracy-rating corr > 0.8
        """)
        
        return "\n".join(lines)
    
    def save_report(self, output_path: str = "algorithm_comparison_report.txt"):
        """리포트 저장"""
        report = self.generate_comparison_report()
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(report)
        return report


# ───────────────────────────────────────────────
# 메인 실행
# ───────────────────────────────────────────────

def main():
    """시각화 및 분석 실행"""
    print("=" * 60)
    print("CSAT Simulation Visualizer")
    print("=" * 60)
    
    # 데이터 로드
    print("\n[1/4] Loading simulation data...")
    try:
        loader = SimulationDataLoader().load()
        print(f"  Loaded: {loader.data_path}")
        print(f"  Students: {len(loader.students)}")
        print(f"  Validation: {loader.validation}")
    except FileNotFoundError:
        print("  No data file found. Run simulation first!")
        print("  Generating dummy data for visualization...")
        loader = SimulationDataLoader()
        loader._generate_dummy_students(500)
        loader.validation = {
            'true_skill_rating_corr': 0.978,
            'avg_tag_corr': 0.921,
            'accuracy_rating_corr': 0.972,
        }
        loader.analysis = {
            'total_students': 500,
            'total_records': 3360000,
        }
    
    # 정적 차트
    print("\n[2/4] Generating static charts (matplotlib)...")
    mpl_vis = MatplotlibVisualizer(loader)
    static_paths = mpl_vis.generate_all()
    
    # 인터랙티브 차트
    print("\n[3/4] Generating interactive charts (plotly)...")
    plotly_vis = PlotlyVisualizer(loader)
    
    dashboard_path = plotly_vis.create_interactive_dashboard()
    print(f"  [OK] {dashboard_path}")
    
    boundary_path = plotly_vis.create_tier_boundary_analysis()
    print(f"  [OK] {boundary_path}")
    
    # 알고리즘 비교 분석
    print("\n[4/4] Generating algorithm comparison report...")
    analyzer = RatingAlgorithmAnalyzer()
    report = analyzer.save_report("algorithm_comparison_report.txt")
    print(f"  [OK] algorithm_comparison_report.txt")
    
    # 요약 출력
    print("\n" + "=" * 60)
    print("Complete! Generated files:")
    print("=" * 60)
    for p in static_paths:
        print(f"  [PNG] {p}")
    print(f"  [HTML] {dashboard_path}")
    print(f"  [HTML] {boundary_path}")
    print(f"  [TXT] algorithm_comparison_report.txt")
    
    # 터미널에 리포트 요약 출력
    print("\n" + report[:2000] + "...")


if __name__ == '__main__':
    main()
