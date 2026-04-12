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
    w_tag = 1.0
    w_barrier = barrier / 10.0
    w_diff = difficulty / 10.0
    return CONFIG.LAMBDA * w_tag + CONFIG.MU * w_barrier + CONFIG.NU * w_diff


def compute_problem_rating(difficulty: float, barrier: float) -> float:
    return _clamp(1000.0 + 40.0 * difficulty + 30.0 * barrier, 800.0, 2200.0)


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
    tags: Iterable[str],
    step_correctness: List[Dict[str, Any]],
    answer_time: Optional[float] = None,
    submission_id: Optional[str] = None,
) -> RatingResult:
    normalized_tags = [_normalize_tag(tag) for tag in tags if _normalize_tag(tag)]
    normalized_tags = list(dict.fromkeys(normalized_tags))

    info = quest.get("info", {}) or {}
    difficulty = float(info.get("difficulty") or 0)
    main_huddle = float(info.get("main_huddle") or 0)
    flow_rate = float(info.get("flow_rate") or 0)

    solves = quest.get("solves") or []
    flat_steps = _flatten_solve_steps(solves)
    tag_flow_map = _build_tag_flow_map(flat_steps)
    total_flow_count = len(flat_steps)
    tag_correct_map = _build_tag_correct_map(flat_steps, step_correctness)

    now = _now_utc()

    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.isolation_level = None
    try:
        conn.execute("BEGIN IMMEDIATE")

        if submission_id:
            if not mark_submission(conn, user_id=user_id, submission_id=submission_id):
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

        user_rating = float(user["rating"])
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

        tag_stats = get_tag_stats(conn, user_id, normalized_tags)

        r_u = _clamp(user_rating / CONFIG.U_MAX, 0.0, 1.0)
        r_r = recent_sum / recent_count if recent_count > 0 else 0.5
        if last_attempt_at:
            days = max(0.0, (now - last_attempt_at).total_seconds() / 86400.0)
            r_t = math.exp(-days / CONFIG.TAU_DAYS)
        else:
            r_t = 1.0

        base_time_factor = compute_time_factor(answer_time, flow_rate, main_huddle)

        k_eff = compute_k_factor(lose_streak)
        delta_user = 0.0

        tag_updates: List[Dict[str, Any]] = []
        tag_rating_sum = float(user.get("tag_rating_sum") or 0.0)
        tag_rating_count = int(user.get("tag_rating_count") or 0)

        # compute weights denominator
        valid_flow_count = total_flow_count if total_flow_count > 0 else 0

        for tag in normalized_tags:
            flows_t = tag_flow_map.get(tag, [])
            if not flows_t:
                # still track attempts, but skip rating update
                stats = tag_stats.get(tag)
                attempts = int(stats["attempts"]) + 1 if stats else 1
                rating_value = float(stats["rating"]) if stats else user_rating
                rating_prev = rating_value
                if not stats:
                    tag_rating_sum += rating_value
                    tag_rating_count += 1
                tag_updates.append(
                    {
                        "user_id": user_id,
                        "tag": tag,
                        "attempts": attempts,
                        "rating": rating_value,
                        "rating_prev": rating_prev,
                        "updated_at": now.isoformat(timespec="seconds") + "Z",
                    }
                )
                continue

            barrier_t = compute_barrier(flows_t, main_huddle)
            problem_weight_t = compute_problem_weight(difficulty, barrier_t)
            problem_rating_t = compute_problem_rating(difficulty, barrier_t)
            expected = compute_expected_score(user_rating, problem_rating_t)

            tag_correct = tag_correct_map.get(tag)
            if tag_correct is None:
                r_tag = 1 if is_correct else 0
            else:
                r_tag = 1 if tag_correct else 0

            stats = tag_stats.get(tag)
            attempts = int(stats["attempts"]) + 1 if stats else 1
            r_c_t = _clamp(attempts / CONFIG.C_MAX, 0.0, 1.0)

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

            delta_t = k_eff * (r_tag - expected) * confidence_t * problem_weight_t
            delta_t = _clamp(delta_t, -CONFIG.DELTA_MAX, CONFIG.DELTA_MAX)

            rating_value = float(stats["rating"]) if stats else user_rating
            rating_prev = rating_value
            new_rating = rating_value + delta_t

            if stats:
                tag_rating_sum += new_rating - rating_value
            else:
                tag_rating_sum += new_rating
                tag_rating_count += 1

            w_t = len(flows_t) / valid_flow_count if valid_flow_count > 0 else 0.0
            delta_user += delta_t * w_t

            tag_updates.append(
                {
                    "user_id": user_id,
                    "tag": tag,
                    "attempts": attempts,
                    "rating": new_rating,
                    "rating_prev": rating_prev,
                    "updated_at": now.isoformat(timespec="seconds") + "Z",
                }
            )

        if normalized_tags and valid_flow_count == 0:
            # fallback: equal weights if no flow info
            per = 1.0 / max(1, len(normalized_tags))
            delta_user = sum(
                (item["rating"] - (tag_stats.get(item["tag"], {}).get("rating") or user_rating))
                * per
                for item in tag_updates
            )

        new_rating = user_rating + delta_user

        # update recent results (ring buffer)
        recent_results, recent_index, recent_count, recent_sum = _update_recent_results(
            recent_results, recent_index, recent_count, recent_sum, 1 if is_correct else 0
        )

        ovr_prev = float(user.get("ovr") or user_rating)
        if tag_rating_count > 0:
            ovr = tag_rating_sum / tag_rating_count
        else:
            ovr = new_rating

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
                new_rating,
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
            rating=new_rating,
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
