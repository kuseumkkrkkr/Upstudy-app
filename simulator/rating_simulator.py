import math
import random
import tkinter as tk
from dataclasses import dataclass, field, asdict
from tkinter import ttk


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


def normalize_tag(tag: str) -> str:
    return tag.strip().lstrip('#').strip().lower()


def format_bool_ko(value: bool | None) -> str:
    if value is True:
        return '정답'
    if value is False:
        return '오답'
    return '미입력'


def format_float(value: float | None, digits: int = 4) -> str:
    if value is None:
        return '없음'
    return f'{value:.{digits}f}'


def format_float_list(values: list[float], digits: int = 1) -> str:
    if not values:
        return '[]'
    return '[' + ', '.join(f'{v:.{digits}f}' for v in values) + ']'


def format_event_log(event: dict) -> str:
    index = event.get('index', '?')
    mode = event.get('mode', 'manual')
    mode_ko = '수동' if mode == 'manual' else '랜덤'
    sim_before = event.get('sim_day_before', 0.0)
    sim_after = event.get('sim_day_after', 0.0)
    lines = [f'[이벤트 {index} | {mode_ko} | 시뮬레이션 Day {sim_before:.2f} -> {sim_after:.2f}]']

    cfg = event.get('config', {})
    lines.append(
        '알고리즘 설정(스냅샷): '
        f"K={cfg.get('K')}, K_MIN={cfg.get('K_MIN')}, DELTA_MAX={cfg.get('DELTA_MAX')}, "
        f"U_MAX={cfg.get('U_MAX')}, C_MAX={cfg.get('C_MAX')}, TAU_DAYS={cfg.get('TAU_DAYS')}"
    )
    lines.append(
        '가중치/기본값: '
        f"ALPHA={cfg.get('ALPHA')}, BETA={cfg.get('BETA')}, GAMMA={cfg.get('GAMMA')}, "
        f"DELTA={cfg.get('DELTA')}, LAMBDA={cfg.get('LAMBDA')}, MU={cfg.get('MU')}, NU={cfg.get('NU')}, "
        f"DEFAULT_RATING={cfg.get('DEFAULT_RATING')}"
    )

    inp = event.get('input', {})
    tags_raw = inp.get('tags_raw') or []
    tags_norm = inp.get('tags_norm') or []
    steps = inp.get('steps') or []
    lines.append(
        '입력: '
        f"난이도={format_float(inp.get('difficulty'), 2)}, 메인허들={format_float(inp.get('main_huddle'), 2)}, "
        f"플로우레이트={format_float(inp.get('flow_rate'), 2)}, 답시간={format_float(inp.get('answer_time'), 2)}, "
        f"경과일={format_float(inp.get('advance_days'), 2)}, 전체정답={format_bool_ko(inp.get('is_correct'))}"
    )
    lines.append(f"태그(원본): {', '.join(tags_raw) if tags_raw else '없음'}")
    lines.append(f"태그(정규화): {', '.join(tags_norm) if tags_norm else '없음'}")
    lines.append('스텝:')
    if steps:
        for step in steps:
            lines.append(
                f"enter={format_float(step.get('enter_huddle'), 2)}, "
                f"tags={','.join(step.get('tags') or []) if step.get('tags') else '없음'}, "
                f"정오={format_bool_ko(step.get('correct'))}"
            )
    else:
        lines.append('스텝 없음')

    comp = event.get('computed', {})
    lines.append(
        '공통 계산: '
        f"r_t={format_float(comp.get('r_t'))}, r_u={format_float(comp.get('r_u'))}, "
        f"r_r={format_float(comp.get('r_r'))}, 시간팩터={format_float(comp.get('base_time_factor'))}, "
        f"k_eff={format_float(comp.get('k_eff'))}, 스텝수={comp.get('total_flow_count')}"
    )

    tag_deltas = event.get('tag_deltas', [])
    lines.append('태그별 계산:')
    if not tag_deltas:
        lines.append('태그 변화 없음')
    for tag_info in tag_deltas:
        tag = tag_info.get('tag', '')
        if tag_info.get('skipped'):
            lines.append(
                f"{tag}: 플로우 없음, 시도 {tag_info.get('attempts_before')} -> {tag_info.get('attempts_after')}, "
                f"레이팅 {format_float(tag_info.get('rating_before'), 2)} -> {format_float(tag_info.get('rating_after'), 2)}"
            )
            continue
        lines.append(
            f"{tag}: 시도 {tag_info.get('attempts_before')} -> {tag_info.get('attempts_after')}, "
            f"레이팅 {format_float(tag_info.get('rating_before'), 2)} -> {format_float(tag_info.get('rating_after'), 2)}, "
            f"플로우={format_float_list(tag_info.get('flows', []))}"
        )
        lines.append(
            f"바리어={format_float(tag_info.get('barrier'))}, 가중치={format_float(tag_info.get('weight'))}, "
            f"문제레이팅={format_float(tag_info.get('problem_rating'))}, 기대값={format_float(tag_info.get('expected'))}, "
            f"태그정오={format_bool_ko(tag_info.get('tag_correct'))}, r_tag={tag_info.get('r_tag')}, "
            f"r_c_t={format_float(tag_info.get('r_c_t'))}, r_time_t={format_float(tag_info.get('r_time_t'))}, "
            f"신뢰도={format_float(tag_info.get('confidence'))}, 변화량={format_float(tag_info.get('delta'))}, "
            f"사용자가중치={format_float(tag_info.get('user_weight'))}, 사용자반영={format_float(tag_info.get('user_contrib'))}"
        )

    user_before = event.get('user_before', {})
    user_after = event.get('user_after', {})
    lines.append(
        '사용자 변화: '
        f"rating {format_float(user_before.get('rating'), 2)} -> {format_float(user_after.get('rating'), 2)}, "
        f"ovr {format_float(user_before.get('ovr'), 2)} -> {format_float(user_after.get('ovr'), 2)}, "
        f"ovr_delta {format_float(user_after.get('ovr', 0.0) - user_before.get('ovr', 0.0), 2)}"
    )
    lines.append(
        '최근 정답률: '
        f"{user_before.get('recent_accuracy', 0.0):.2%} -> {user_after.get('recent_accuracy', 0.0):.2%}, "
        f"연속 오답 {user_before.get('lose_streak')} -> {user_after.get('lose_streak')}"
    )
    return '\n'.join(lines)


def clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


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


def build_tag_flow_map(steps: list[Step]) -> dict[str, list[float]]:
    tag_map: dict[str, list[float]] = {}
    for step in steps:
        for raw in step.tags:
            tag = normalize_tag(raw)
            if not tag:
                continue
            tag_map.setdefault(tag, []).append(step.enter_huddle)
    return tag_map


def build_tag_correct_map(steps: list[Step]) -> dict[str, bool | None]:
    tag_counts: dict[str, dict[str, int]] = {}
    for step in steps:
        if step.correct is None:
            continue
        for raw in step.tags:
            tag = normalize_tag(raw)
            if not tag:
                continue
            counts = tag_counts.setdefault(tag, {'correct': 0, 'incorrect': 0})
            if step.correct:
                counts['correct'] += 1
            else:
                counts['incorrect'] += 1
    result: dict[str, bool | None] = {}
    for tag, counts in tag_counts.items():
        if counts['incorrect'] > 0:
            result[tag] = False
        elif counts['correct'] > 0:
            result[tag] = True
        else:
            result[tag] = None
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
    debug: bool = False,
    mode: str = 'manual',
) -> dict | None:
    tags_norm = [normalize_tag(t) for t in tags if normalize_tag(t)]
    tags_norm = list(dict.fromkeys(tags_norm))

    sim_day_before = user.last_attempt_day if user.last_attempt_day is not None else 0.0
    sim_day = sim_day_before
    sim_day += max(0.0, advance_days)

    if user.last_attempt_day is None:
        r_t = 1.0
    else:
        d_days = max(0.0, sim_day - user.last_attempt_day)
        r_t = math.exp(-d_days / CONFIG.TAU_DAYS)

    tag_flow_map = build_tag_flow_map(steps)
    tag_correct_map = build_tag_correct_map(steps)
    total_flow_count = len(steps)

    user_before = {
        'rating': user.rating,
        'ovr': user.ovr,
        'ovr_prev': user.ovr_prev,
        'lose_streak': user.lose_streak,
        'recent_accuracy': user.recent_sum / user.recent_count if user.recent_count > 0 else 0.0,
    }

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
            tag_deltas.append(
                {
                    'tag': tag,
                    'attempts_before': attempts_before,
                    'attempts_after': state.attempts,
                    'rating_before': rating_before,
                    'rating_after': state.rating,
                    'flows': flows_t,
                    'skipped': True,
                }
            )
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
        tag_deltas.append(
            {
                'tag': tag,
                'attempts_before': attempts_before,
                'attempts_after': state.attempts,
                'rating_before': rating_before,
                'rating_after': state.rating,
                'flows': flows_t,
                'barrier': barrier_t,
                'weight': weight_t,
                'problem_rating': problem_rating_t,
                'expected': expected,
                'tag_correct': tag_correct,
                'r_tag': r_tag,
                'r_c_t': r_c_t,
                'r_time_t': r_time_t,
                'confidence': confidence_t,
                'delta': delta_t,
                'user_weight': w_t,
                'user_contrib': delta_t * w_t,
                'skipped': False,
            }
        )

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

    if not debug:
        return None

    user_after = {
        'rating': user.rating,
        'ovr': user.ovr,
        'ovr_prev': user.ovr_prev,
        'lose_streak': user.lose_streak,
        'recent_accuracy': user.recent_sum / user.recent_count if user.recent_count > 0 else 0.0,
    }
    event = {
        'mode': mode,
        'config': asdict(CONFIG),
        'sim_day_before': sim_day_before,
        'sim_day_after': sim_day,
        'input': {
            'difficulty': difficulty,
            'main_huddle': main_huddle,
            'flow_rate': flow_rate,
            'tags_raw': list(tags),
            'tags_norm': tags_norm,
            'is_correct': is_correct,
            'answer_time': answer_time,
            'advance_days': advance_days,
            'steps': [
                {
                    'enter_huddle': step.enter_huddle,
                    'tags': list(step.tags),
                    'correct': step.correct,
                }
                for step in steps
            ],
        },
        'computed': {
            'r_t': r_t,
            'r_u': r_u,
            'r_r': r_r,
            'base_time_factor': base_time_factor,
            'k_eff': k_eff,
            'total_flow_count': total_flow_count,
        },
        'tag_deltas': tag_deltas,
        'user_before': user_before,
        'user_after': user_after,
    }
    return event


class RatingSimulatorApp(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title('레이팅 시뮬레이터')
        self.geometry('1100x700')

        self.user = UserState()
        self.history: list[tuple[float, float]] = []
        self.sim_day = 0.0
        self.event_history: list[dict] = []

        self._build_ui()
        self._refresh_ui()

    def _build_ui(self) -> None:
        container = ttk.Frame(self)
        container.pack(fill='both', expand=True, padx=10, pady=10)

        left = ttk.Frame(container)
        right = ttk.Frame(container)
        left.pack(side='left', fill='y')
        right.pack(side='right', fill='both', expand=True)

        # Inputs
        self.difficulty_var = tk.StringVar(value='10')
        self.main_huddle_var = tk.StringVar(value='2')
        self.flow_rate_var = tk.StringVar(value='')
        self.tags_var = tk.StringVar(value='diff,exp')
        self.is_correct_var = tk.BooleanVar(value=True)
        self.answer_time_var = tk.StringVar(value='120')
        self.advance_days_var = tk.StringVar(value='0')

        ttk.Label(left, text='난이도 (D)').pack(anchor='w')
        ttk.Entry(left, textvariable=self.difficulty_var, width=16).pack(anchor='w')
        ttk.Label(left, text='메인 허들 (1-3)').pack(anchor='w', pady=(6, 0))
        ttk.Entry(left, textvariable=self.main_huddle_var, width=16).pack(anchor='w')
        ttk.Label(left, text='플로우 레이트 (선택)').pack(anchor='w', pady=(6, 0))
        ttk.Entry(left, textvariable=self.flow_rate_var, width=16).pack(anchor='w')
        ttk.Label(left, text='태그 (콤마)').pack(anchor='w', pady=(6, 0))
        ttk.Entry(left, textvariable=self.tags_var, width=22).pack(anchor='w')

        ttk.Checkbutton(left, text='정답 여부 (전체)', variable=self.is_correct_var).pack(anchor='w', pady=(6, 0))
        ttk.Label(left, text='응답 시간 (초)').pack(anchor='w', pady=(6, 0))
        ttk.Entry(left, textvariable=self.answer_time_var, width=16).pack(anchor='w')
        ttk.Label(left, text='경과 일수').pack(anchor='w', pady=(6, 0))
        ttk.Entry(left, textvariable=self.advance_days_var, width=16).pack(anchor='w')

        ttk.Label(left, text='스텝 (enter | tags | correct)').pack(anchor='w', pady=(8, 0))
        self.steps_text = tk.Text(left, width=34, height=12)
        self.steps_text.pack(anchor='w')
        self.steps_text.insert('1.0', '3 | diff | 1\n6 | diff,exp | 0\n4 | exp | 1\n')

        ttk.Button(left, text='제출 적용', command=self._apply_submission).pack(fill='x', pady=(8, 0))

        ttk.Separator(left, orient='horizontal').pack(fill='x', pady=8)

        self.random_count_var = tk.StringVar(value='20')
        self.random_tags_var = tk.StringVar(value='diff,exp,log')
        ttk.Label(left, text='랜덤 시뮬 횟수').pack(anchor='w')
        ttk.Entry(left, textvariable=self.random_count_var, width=16).pack(anchor='w')
        ttk.Label(left, text='랜덤 태그 (콤마)').pack(anchor='w', pady=(6, 0))
        ttk.Entry(left, textvariable=self.random_tags_var, width=22).pack(anchor='w')
        ttk.Button(left, text='랜덤 시뮬 실행', command=self._run_random).pack(fill='x', pady=(6, 0))
        ttk.Button(left, text='초기화', command=self._reset).pack(fill='x', pady=(6, 0))

        # Right side: stats + chart
        self.stats_label = ttk.Label(right, text='', justify='left')
        self.stats_label.pack(anchor='nw')

        self.canvas = tk.Canvas(right, height=260, bg='white', highlightthickness=1, highlightbackground='#cccccc')
        self.canvas.pack(fill='x', padx=4, pady=8)

        ttk.Label(right, text='태그 통계').pack(anchor='w')
        self.tag_list = tk.Text(right, height=12)
        self.tag_list.pack(fill='both', expand=True)

        ttk.Label(right, text='이벤트 로그').pack(anchor='w', pady=(6, 0))
        self.log_text = tk.Text(right, height=10)
        self.log_text.pack(fill='both', expand=True)

    def _parse_steps(self) -> list[Step]:
        raw = self.steps_text.get('1.0', 'end').strip()
        steps: list[Step] = []
        if not raw:
            return steps
        for line in raw.splitlines():
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            parts = [p.strip() for p in line.split('|')]
            if not parts:
                continue
            try:
                enter = float(parts[0])
            except ValueError:
                continue
            tags = []
            if len(parts) >= 2 and parts[1]:
                tags = [normalize_tag(t) for t in parts[1].replace(',', ' ').split()]
                tags = [t for t in tags if t]
            correct = None
            if len(parts) >= 3 and parts[2] != '':
                correct = parts[2].strip().lower() in ('1', 'true', 't', 'y', 'yes')
            steps.append(Step(enter_huddle=enter, tags=tags, correct=correct))
        return steps

    def _apply_submission(self) -> None:
        try:
            difficulty = float(self.difficulty_var.get().strip())
        except ValueError:
            difficulty = 0.0
        try:
            main_huddle = float(self.main_huddle_var.get().strip())
        except ValueError:
            main_huddle = 0.0
        flow_rate_raw = self.flow_rate_var.get().strip()
        flow_rate = float(flow_rate_raw) if flow_rate_raw else 0.0
        tags = [t.strip() for t in self.tags_var.get().split(',') if t.strip()]
        is_correct = bool(self.is_correct_var.get())
        answer_time_raw = self.answer_time_var.get().strip()
        answer_time = float(answer_time_raw) if answer_time_raw else None
        advance_raw = self.advance_days_var.get().strip()
        advance_days = float(advance_raw) if advance_raw else 0.0

        steps = self._parse_steps()
        if flow_rate <= 0:
            flow_rate = float(len(steps)) if steps else 1.0
        if not tags:
            tags = sorted({tag for step in steps for tag in step.tags})

        event = apply_rating_update(
            self.user,
            difficulty=difficulty,
            main_huddle=main_huddle,
            flow_rate=flow_rate,
            steps=steps,
            tags=tags,
            is_correct=is_correct,
            answer_time=answer_time,
            advance_days=advance_days,
            debug=True,
            mode='manual',
        )
        self.history.append((self.user.rating, self.user.ovr))
        if event:
            self._append_event_logs([event])
        self._refresh_ui()

    def _run_random(self) -> None:
        try:
            count = int(self.random_count_var.get().strip())
        except ValueError:
            count = 10
        tags_pool = [t.strip() for t in self.random_tags_var.get().split(',') if t.strip()]
        if not tags_pool:
            tags_pool = ['diff', 'exp']
        new_events: list[dict] = []
        for _ in range(max(1, count)):
            difficulty = random.uniform(5, 20)
            main_huddle = random.choice([1, 2, 3])
            steps = []
            step_count = random.randint(2, 6)
            for _ in range(step_count):
                enter = random.randint(1, 10)
                step_tags = random.sample(tags_pool, k=random.randint(1, min(2, len(tags_pool))))
                correct = random.random() < 0.65
                steps.append(Step(enter_huddle=enter, tags=step_tags, correct=correct))
            tags = sorted({t for step in steps for t in step.tags})
            event = apply_rating_update(
                self.user,
                difficulty=difficulty,
                main_huddle=main_huddle,
                flow_rate=float(step_count),
                steps=steps,
                tags=tags,
                is_correct=random.random() < 0.7,
                answer_time=random.uniform(40, 200),
                advance_days=random.uniform(0.0, 2.0),
                debug=True,
                mode='random',
            )
            self.history.append((self.user.rating, self.user.ovr))
            if event:
                new_events.append(event)
        if new_events:
            self._append_event_logs(new_events)
        self._refresh_ui()

    def _reset(self) -> None:
        self.user = UserState()
        self.history.clear()
        self.event_history.clear()
        self.log_text.delete('1.0', 'end')
        self._refresh_ui()

    def _refresh_ui(self) -> None:
        recent_accuracy = self.user.recent_sum / self.user.recent_count if self.user.recent_count > 0 else 0.0
        delta = self.user.ovr - self.user.ovr_prev
        stats = (
            f'레이팅: {self.user.rating:.2f}\n'
            f'OVR: {self.user.ovr:.2f}\n'
            f'OVR 변화: {delta:+.2f}\n'
            f'최근 정답률: {recent_accuracy:.2%}\n'
            f'연속 오답: {self.user.lose_streak}\n'
            f'태그 수: {len(self.user.tags)}\n'
        )
        self.stats_label.config(text=stats)
        self._draw_chart()
        self._refresh_tag_list()

    def _draw_chart(self) -> None:
        self.canvas.delete('all')
        if len(self.history) < 2:
            self.canvas.create_text(10, 10, anchor='nw', text='히스토리 없음', fill='#777777')
            return
        width = self.canvas.winfo_width()
        height = self.canvas.winfo_height()
        pad = 20
        ratings = [r for r, _ in self.history]
        ovrs = [o for _, o in self.history]
        min_val = min(ratings + ovrs)
        max_val = max(ratings + ovrs)
        if max_val - min_val < 1e-3:
            max_val += 1
            min_val -= 1
        def to_xy(index: int, value: float) -> tuple[float, float]:
            x = pad + index * (width - 2 * pad) / (len(self.history) - 1)
            y = height - pad - (value - min_val) / (max_val - min_val) * (height - 2 * pad)
            return x, y
        # axes
        self.canvas.create_line(pad, pad, pad, height - pad, fill='#cccccc')
        self.canvas.create_line(pad, height - pad, width - pad, height - pad, fill='#cccccc')
        # rating line
        points = []
        for i, value in enumerate(ratings):
            points.extend(to_xy(i, value))
        self.canvas.create_line(*points, fill='#1b402b', width=2)
        # ovr line
        points = []
        for i, value in enumerate(ovrs):
            points.extend(to_xy(i, value))
        self.canvas.create_line(*points, fill='#2b6cb0', width=2)
        self.canvas.create_text(width - pad, pad, anchor='ne', text=f'{max_val:.1f}', fill='#666666')
        self.canvas.create_text(width - pad, height - pad, anchor='se', text=f'{min_val:.1f}', fill='#666666')

    def _refresh_tag_list(self) -> None:
        self.tag_list.delete('1.0', 'end')
        if not self.user.tags:
            self.tag_list.insert('end', '태그 통계 없음.\n')
            return
        rows = []
        for tag, state in sorted(self.user.tags.items()):
            rows.append(f'{tag:12}  레이팅={state.rating:7.2f}  시도={state.attempts}')
        self.tag_list.insert('end', '\n'.join(rows))

    def _append_event_logs(self, events: list[dict]) -> None:
        if not events:
            return
        for event in events:
            event['index'] = len(self.event_history) + 1
            self.event_history.append(event)
        logs = '\n\n'.join(format_event_log(event) for event in events)
        if logs:
            self.log_text.insert('end', logs + '\n\n')
            self.log_text.see('end')


if __name__ == '__main__':
    app = RatingSimulatorApp()
    app.mainloop()
