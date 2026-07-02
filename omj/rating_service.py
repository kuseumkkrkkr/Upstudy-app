import json
import math
import sqlite3
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Dict, Iterable, List, Optional, Tuple

from rating_config import CONFIG
from storage.rating_storage import (
    create_user,
    get_tag_stats,
    get_user,
    list_tag_stats,
    mark_submission,
    upsert_tag_stats,
)
from storage.storage import DB_PATH


def _now_utc() -> datetime:
    return datetime.now(timezone.utc)


def _parse_iso(value: Optional[str]) -> Optional[datetime]:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def _normalize_tag(tag: str) -> str:
    return (tag or "").strip().lstrip("#").strip().lower()


_EXCLUDED_TAGS = {_normalize_tag("사칙연산")}


def _clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def _difficulty_signal(difficulty: float) -> float:
    logged = math.log1p(max(0.0, difficulty))
    return (logged - CONFIG.DIFFICULTY_LOG_CENTER) / CONFIG.DIFFICULTY_LOG_SCALE


def compute_expected_score(user_rating: float, problem_rating: float) -> float:
    return 1.0 / (1.0 + 10 ** ((problem_rating - user_rating) / 400.0))


def compute_k_factor(lose_streak: int) -> float:
    return max(CONFIG.K_MIN, CONFIG.K * math.exp(-CONFIG.M_LOSE * max(0, lose_streak)))


def _percentile(values: List[float], pct: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    if len(ordered) == 1:
        return float(ordered[0])
    idx = int(round((len(ordered) - 1) * pct))
    idx = max(0, min(idx, len(ordered) - 1))
    return float(ordered[idx])


def compute_barrier(enter_huddles: List[float], main_huddle: float) -> float:
    if not enter_huddles:
        main_scaled = main_huddle * 3.3
        return _clamp(main_scaled, 0.0, 10.0)
    avg_enter = sum(enter_huddles) / max(1, len(enter_huddles))
    p80_enter = _percentile(enter_huddles, 0.8)
    main_scaled = main_huddle * 3.3
    barrier = 0.6 * avg_enter + 0.2 * p80_enter + 0.2 * main_scaled
    return _clamp(barrier, 0.0, 10.0)


def compute_problem_weight(difficulty: float, barrier: float) -> float:
    signal = _difficulty_signal(difficulty)
    return _clamp(0.82 + 0.12 * signal + 0.03 * barrier, 0.75, 1.25)


def compute_problem_rating(difficulty: float, barrier: float) -> float:
    signal = _difficulty_signal(difficulty)
    return _clamp(1080.0 + 180.0 * signal + 24.0 * barrier, 900.0, 1700.0)


def compute_time_factor(answer_time: Optional[float], flow_rate: float, main_huddle: float) -> float:
    if answer_time is None or answer_time <= 0:
        return 1.0
    t_ref = 30.0 + 20.0 * flow_rate + 30.0 * main_huddle
    raw = math.exp(-max(0.0, answer_time - t_ref) / max(1.0, t_ref))
    raw = _clamp(raw, 0.4, 1.0)
    return 0.9 + 0.1 * raw


def _flatten_solve_steps(solves: Any) -> List[Dict[str, Any]]:
    steps: List[Dict[str, Any]] = []

    def visit(step: Dict[str, Any]) -> None:
        steps.append(step)
        branches = step.get("branches") or []
        if isinstance(branches, list):
            for branch in branches:
                if isinstance(branch, dict):
                    visit(branch)

    if isinstance(solves, list):
        for step in solves:
            if isinstance(step, dict):
                visit(step)
    return steps


def _build_tag_flow_map(steps: List[Dict[str, Any]]) -> Dict[str, List[float]]:
    tag_map: Dict[str, List[float]] = {}
    for step in steps:
        enter = step.get("enter_huddle", 0)
        try:
            enter_value = float(enter)
        except (TypeError, ValueError):
            enter_value = 0.0
        tags = step.get("hash_tag") or []
        if not isinstance(tags, list):
            continue
        for raw in tags:
            norm = _normalize_tag(str(raw))
            if not norm or norm in _EXCLUDED_TAGS:
                continue
            tag_map.setdefault(norm, []).append(enter_value)
    return tag_map


def _build_tag_correct_map(
    steps: List[Dict[str, Any]],
    step_correctness: List[Dict[str, Any]],
) -> Dict[str, Optional[bool]]:
    if not steps or not step_correctness:
        return {}
    step_map: Dict[int, Optional[bool]] = {}
    for entry in step_correctness:
        try:
            step_id = int(entry.get("step_id") or 0)
        except (TypeError, ValueError):
            step_id = 0
        if step_id <= 0:
            continue
        correct_value = entry.get("correct")
        if correct_value is None:
            step_map[step_id] = None
        else:
            step_map[step_id] = bool(correct_value)

    tag_counts: Dict[str, Dict[str, int]] = {}
    for idx, step in enumerate(steps, start=1):
        correctness = step_map.get(idx)
        if correctness is None:
            continue
        tags = step.get("hash_tag") or []
        if not isinstance(tags, list):
            continue
        for raw in tags:
            norm = _normalize_tag(str(raw))
            if not norm or norm in _EXCLUDED_TAGS:
                continue
            counts = tag_counts.setdefault(norm, {"correct": 0, "incorrect": 0})
            if correctness:
                counts["correct"] += 1
            else:
                counts["incorrect"] += 1

    result: Dict[str, Optional[bool]] = {}
    for tag, counts in tag_counts.items():
        if counts["incorrect"] > 0:
            result[tag] = False
        elif counts["correct"] > 0:
            result[tag] = True
        else:
            result[tag] = None
    return result


def _update_recent_results(
    recent_results: List[int],
    recent_index: int,
    recent_count: int,
    recent_sum: int,
    value: int,
) -> Tuple[List[int], int, int, int]:
    if recent_count < 50:
        recent_results.append(value)
        recent_count += 1
        recent_sum += value
        recent_index = recent_count % 50
        return recent_results, recent_index, recent_count, recent_sum
    # ring buffer overwrite
    if not recent_results:
        recent_results = [0] * 50
    if len(recent_results) < 50:
        recent_results.extend([0] * (50 - len(recent_results)))
    old = recent_results[recent_index]
    recent_results[recent_index] = value
    recent_sum += value - int(old)
    recent_index = (recent_index + 1) % 50
    return recent_results, recent_index, recent_count, recent_sum


@dataclass
class RatingResult:
    rating: float
    ovr: float
    ovr_delta: float
    recent_accuracy: float
    lose_streak: int


def apply_rating_update(
    *,
    user_id: str,
    quest: Dict[str, Any],
    is_correct: bool,
    submitted_tags: Iterable[str],
    step_outcomes: List[Dict[str, Any]],
    response_time_seconds: Optional[float] = None,
    submission_ref: Optional[str] = None,
) -> RatingResult:
    unique_tags = [_normalize_tag(tag) for tag in submitted_tags if _normalize_tag(tag)]
    unique_tags = list(dict.fromkeys(unique_tags))

    quest_info = quest.get("info", {}) or {}
    quest_difficulty = float(quest_info.get("difficulty") or 0)
    main_huddle = float(quest_info.get("main_huddle") or 0)
    quest_flow_rate = float(quest_info.get("flow_rate") or 0)

    solve_steps = quest.get("solves") or []
    flattened_steps = _flatten_solve_steps(solve_steps)
    tag_flow_by_tag = _build_tag_flow_map(flattened_steps)
    total_step_count = len(flattened_steps)
    tag_correct_by_tag = _build_tag_correct_map(flattened_steps, step_outcomes)

    now = _now_utc()

    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.isolation_level = None
    try:
        conn.execute("BEGIN IMMEDIATE")

        if submission_ref:
            if not mark_submission(conn, user_id=user_id, submission_id=submission_ref):
                # already processed
                user = get_user(conn, user_id)
                if not user:
                    user = create_user(conn, user_id=user_id, rating=CONFIG.DEFAULT_RATING)
                recent_accuracy = (
                    user["recent_sum"] / user["recent_count"]
                    if user["recent_count"] > 0
                    else 0.0
                )
                conn.execute("COMMIT")
                return RatingResult(
                    rating=user["rating"],
                    ovr=user["ovr"],
                    ovr_delta=user["ovr"] - user["ovr_prev"],
                    recent_accuracy=recent_accuracy,
                    lose_streak=user["lose_streak"],
                )

        user = get_user(conn, user_id)
        if not user:
            user = create_user(conn, user_id=user_id, rating=CONFIG.DEFAULT_RATING)

        current_rating = float(user["rating"])
        lose_streak = int(user["lose_streak"])
        last_attempt_at = _parse_iso(user.get("last_attempt_at"))
        recent_results_raw = user.get("recent_results") or "[]"
        try:
            recent_results = json.loads(recent_results_raw)
            if not isinstance(recent_results, list):
                recent_results = []
        except json.JSONDecodeError:
            recent_results = []
        recent_index = int(user.get("recent_index") or 0)
        recent_count = int(user.get("recent_count") or 0)
        recent_sum = int(user.get("recent_sum") or 0)

        user_tag_stats = get_tag_stats(conn, user_id, unique_tags)

        # User rating 자체는 expected_score에 이미 반영되므로,
        # confidence는 과도한 상향 편향을 막기 위해 기준값 1.0으로 둔다.
        user_confidence = 1.0
        recent_accuracy_signal = recent_sum / recent_count if recent_count > 0 else 0.5
        if last_attempt_at:
            days = max(0.0, (now - last_attempt_at).total_seconds() / 86400.0)
            recency_signal = math.exp(-days / CONFIG.TAU_DAYS)
        else:
            recency_signal = 1.0

        time_signal = compute_time_factor(response_time_seconds, quest_flow_rate, main_huddle)

        effective_k_factor = compute_k_factor(lose_streak)
        rating_delta_total = 0.0

        tag_updates: List[Dict[str, Any]] = []
        tag_rating_sum = float(user.get("tag_rating_sum") or 0.0)
        tag_rating_count = int(user.get("tag_rating_count") or 0)

        # compute weights denominator
        flow_step_count = total_step_count if total_step_count > 0 else 0

        for tag in unique_tags:
            tag_flow_entries = tag_flow_by_tag.get(tag, [])
            if not tag_flow_entries:
                # still track attempts, but skip rating update
                stats = user_tag_stats.get(tag)
                attempts = int(stats["attempts"]) + 1 if stats else 1
                tag_current_rating = float(stats["rating"]) if stats else current_rating
                tag_previous_rating = tag_current_rating
                if not stats:
                    tag_rating_sum += tag_current_rating
                    tag_rating_count += 1
                tag_updates.append(
                    {
                        "user_id": user_id,
                        "tag": tag,
                        "attempts": attempts,
                        "rating": tag_current_rating,
                        "rating_prev": tag_previous_rating,
                        "updated_at": now.isoformat(timespec="seconds") + "Z",
                    }
                )
                continue

            tag_barrier = compute_barrier(tag_flow_entries, main_huddle)
            tag_weight = compute_problem_weight(quest_difficulty, tag_barrier)
            tag_rating = compute_problem_rating(quest_difficulty, tag_barrier)
            expected_score = compute_expected_score(current_rating, tag_rating)

            tag_outcome = tag_correct_by_tag.get(tag)
            if tag_outcome is None:
                tag_result = 1 if is_correct else 0
            else:
                tag_result = 1 if tag_outcome else 0

            stats = user_tag_stats.get(tag)
            attempts = int(stats["attempts"]) + 1 if stats else 1
            attempt_confidence = _clamp(attempts / CONFIG.C_MAX, 0.0, 1.0)

            if tag_outcome is True:
                time_confidence = 1.0
            elif tag_outcome is False:
                time_confidence = time_signal
            else:
                time_confidence = 1.0 if is_correct else time_signal

            confidence_weight = (
                CONFIG.ALPHA * user_confidence
                + CONFIG.BETA * attempt_confidence
                + CONFIG.GAMMA * recent_accuracy_signal
                + CONFIG.DELTA * recency_signal
            ) * time_confidence

            tag_rating_delta = effective_k_factor * (tag_result - expected_score) * confidence_weight * tag_weight
            tag_rating_delta = _clamp(tag_rating_delta, -CONFIG.DELTA_MAX, CONFIG.DELTA_MAX)

            tag_current_rating = float(stats["rating"]) if stats else current_rating
            tag_previous_rating = tag_current_rating
            tag_new_rating = tag_current_rating + tag_rating_delta

            if stats:
                tag_rating_sum += tag_new_rating - tag_current_rating
            else:
                tag_rating_sum += tag_new_rating
                tag_rating_count += 1

            tag_flow_weight = len(tag_flow_entries) / flow_step_count if flow_step_count > 0 else 0.0
            rating_delta_total += tag_rating_delta * tag_flow_weight

            tag_updates.append(
                {
                    "user_id": user_id,
                    "tag": tag,
                    "attempts": attempts,
                    "rating": tag_new_rating,
                    "rating_prev": tag_previous_rating,
                    "updated_at": now.isoformat(timespec="seconds") + "Z",
                }
            )

        if unique_tags and flow_step_count == 0:
            # fallback: equal weights if no flow info
            per_tag_weight = 1.0 / max(1, len(unique_tags))
            rating_delta_total = sum(
                (item["rating"] - (user_tag_stats.get(item["tag"], {}).get("rating") or current_rating))
                * per_tag_weight
                for item in tag_updates
            )

        user_new_rating = current_rating + rating_delta_total

        # update recent results (ring buffer)
        recent_results, recent_index, recent_count, recent_sum = _update_recent_results(
            recent_results, recent_index, recent_count, recent_sum, 1 if is_correct else 0
        )

        ovr_prev = float(user.get("ovr") or current_rating)
        if tag_rating_count > 0:
            ovr = tag_rating_sum / tag_rating_count
        else:
            ovr = user_new_rating

        now_iso = now.isoformat(timespec="seconds") + "Z"
        conn.execute(
            """
            UPDATE user_rating
            SET
                rating = ?,
                ovr = ?,
                ovr_prev = ?,
                lose_streak = ?,
                last_attempt_at = ?,
                recent_results = ?,
                recent_index = ?,
                recent_count = ?,
                recent_sum = ?,
                tag_rating_sum = ?,
                tag_rating_count = ?,
                updated_at = ?
            WHERE user_id = ?
            """,
            (
                user_new_rating,
                ovr,
                ovr_prev,
                0 if is_correct else lose_streak + 1,
                now_iso,
                json.dumps(recent_results),
                recent_index,
                recent_count,
                recent_sum,
                tag_rating_sum,
                tag_rating_count,
                now_iso,
                user_id,
            ),
        )

        upsert_tag_stats(conn, tag_updates)

        conn.execute("COMMIT")

        recent_accuracy = recent_sum / recent_count if recent_count > 0 else 0.0
        return RatingResult(
            rating=user_new_rating,
            ovr=ovr,
            ovr_delta=ovr - ovr_prev,
            recent_accuracy=recent_accuracy,
            lose_streak=0 if is_correct else lose_streak + 1,
        )
    except Exception:
        conn.execute("ROLLBACK")
        raise
    finally:
        conn.close()


def fetch_user_rating(user_id: str) -> RatingResult:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        user = get_user(conn, user_id)
        if not user:
            user = create_user(conn, user_id=user_id, rating=CONFIG.DEFAULT_RATING)
            conn.commit()
        recent_accuracy = (
            user["recent_sum"] / user["recent_count"]
            if user["recent_count"] > 0
            else 0.0
        )
        return RatingResult(
            rating=user["rating"],
            ovr=user["ovr"],
            ovr_delta=user["ovr"] - user["ovr_prev"],
            recent_accuracy=recent_accuracy,
            lose_streak=user["lose_streak"],
        )
    finally:
        conn.close()


def fetch_tag_ratings(user_id: str) -> List[Dict[str, Any]]:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        rows = list_tag_stats(conn, user_id)
        return [
            {
                "tag": row["tag"],
                "attempts": row["attempts"],
                "rating": row["rating"],
                "delta": row["rating"] - row["rating_prev"],
            }
            for row in rows
        ]
    finally:
        conn.close()
