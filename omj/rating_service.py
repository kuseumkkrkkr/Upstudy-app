import math
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

from rating_config import CONFIG
from storage.postgres_rating_store import postgres_rating_store


def _now_utc() -> datetime:
    return datetime.now(timezone.utc)


def _parse_iso(value: Any) -> Optional[datetime]:
    """필요 변수: PostgreSQL 일시 또는 ISO 문자열. 작동 원리: 모든 값을 UTC aware datetime으로 통일한다."""
    if not value:
        return None
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
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
    """필요 변수: 호환용 연패 수. 작동 원리: 제출 순서에 따른 변화량 편향을 없애기 위해 고정 K를 반환한다."""
    del lose_streak
    return CONFIG.K


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


@dataclass
class PlacementRatingResult(RatingResult):
    confidence: float
    strong_tags: List[Dict[str, Any]]
    weak_tags: List[Dict[str, Any]]


def apply_rating_update(
    *,
    user_id: str,
    quest: Dict[str, Any],
    is_correct: bool,
    step_outcomes: List[Dict[str, Any]],
    response_time_seconds: Optional[float] = None,
    submission_ref: str,
) -> RatingResult:
    """필요 변수: 서버 문제 원본·채점 결과·필수 제출 키. 작동 원리: PostgreSQL 행 잠금 안에서 정규화된 태그 기여도와 재전송 결과를 원자적으로 반영한다."""
    submission_id = submission_ref.strip()
    if not submission_id:
        raise ValueError("submission_ref is required")
    with postgres_rating_store.transaction() as cur:
        return _apply_rating_update_in_transaction(
            cur=cur,
            user_id=user_id,
            quest=quest,
            is_correct=is_correct,
            step_outcomes=step_outcomes,
            response_time_seconds=response_time_seconds,
            submission_ref=submission_id,
        )


def apply_rating_batch(*, user_id: str, submissions: List[Dict[str, Any]]) -> List[RatingResult]:
    """필요 변수: 동일 사용자의 최대 100개 채점 제출. 작동 원리: 한 연결·한 트랜잭션에서 문제 순서대로 반영해 HTTP·DB 커밋 비용과 순서 경합을 줄인다."""
    if not submissions or len(submissions) > 100:
        raise ValueError("rating batch size must be between 1 and 100")
    results: List[RatingResult] = []
    with postgres_rating_store.transaction() as cur:
        for item in submissions:
            submission_ref = str(item.get("submission_ref") or "").strip()
            if not submission_ref:
                raise ValueError("submission_ref is required")
            results.append(_apply_rating_update_in_transaction(
                cur=cur,
                user_id=user_id,
                quest=item["quest"],
                is_correct=bool(item["is_correct"]),
                step_outcomes=list(item.get("step_outcomes") or []),
                response_time_seconds=item.get("response_time_seconds"),
                submission_ref=submission_ref,
            ))
    return results


def _apply_rating_update_in_transaction(
    *,
    cur: Any,
    user_id: str,
    quest: Dict[str, Any],
    is_correct: bool,
    step_outcomes: List[Dict[str, Any]],
    response_time_seconds: Optional[float],
    submission_ref: str,
) -> RatingResult:
    """필요 변수: 열린 PostgreSQL 커서와 단일 제출 자료. 작동 원리: 서버 원본 태그만 신뢰하고 태그 흐름 합을 1로 정규화해 사용자·태그 레이팅을 갱신한다."""
    quest_info = quest.get("info", {}) or {}
    quest_header = quest.get("header", {}) or {}
    quest_id = str(quest_header.get("quest_id") or quest.get("quest_id") or "").strip()
    if not quest_id:
        raise ValueError("quest_id is missing from canonical quest")

    # 사용자 행을 항상 첫 잠금으로 잡아 겹치는 배치의 잠금 순서를 단일화한다.
    user = postgres_rating_store.get_or_create_user(cur, user_id, for_update=True)
    replay = postgres_rating_store.claim_submission(
        cur,
        user_id=user_id,
        submission_id=submission_ref,
        quest_id=quest_id,
    )
    if replay is not None:
        return RatingResult(**replay)

    raw_tags = quest_info.get("hash_tag") or []
    unique_tags = list(dict.fromkeys(
        normalized
        for raw in raw_tags if (normalized := _normalize_tag(str(raw)))
        and normalized not in _EXCLUDED_TAGS
    ))
    quest_difficulty = float(quest_info.get("difficulty_score") or quest_info.get("difficulty") or 0)
    main_huddle = float(quest_info.get("main_huddle") or 0)
    quest_flow_rate = float(quest_info.get("flow_rate") or 0)
    flattened_steps = _flatten_solve_steps(quest.get("solves") or [])
    tag_flow_by_tag = _build_tag_flow_map(flattened_steps)
    tag_correct_by_tag = _build_tag_correct_map(flattened_steps, step_outcomes)
    rated_flow_count = sum(len(tag_flow_by_tag.get(tag, [])) for tag in unique_tags)

    now = _now_utc()
    current_rating = float(user["rating"])
    lose_streak = int(user["lose_streak"])
    recent_results = list(user.get("recent_results") or [])
    recent_index = int(user.get("recent_index") or 0)
    recent_count = int(user.get("recent_count") or 0)
    recent_sum = int(user.get("recent_sum") or 0)
    recent_accuracy_signal = recent_sum / recent_count if recent_count > 0 else 0.5
    last_attempt_at = _parse_iso(user.get("last_attempt_at"))
    if last_attempt_at:
        days = max(0.0, (now - last_attempt_at).total_seconds() / 86400.0)
        recency_signal = math.exp(-days / CONFIG.TAU_DAYS)
    else:
        recency_signal = 1.0

    user_tag_stats = postgres_rating_store.get_tag_stats(cur, user_id, unique_tags)
    time_signal = compute_time_factor(response_time_seconds, quest_flow_rate, main_huddle)
    rating_delta_total = 0.0
    tag_updates: List[Dict[str, Any]] = []

    for tag in unique_tags:
        tag_flow_entries = tag_flow_by_tag.get(tag, [])
        stats = user_tag_stats.get(tag)
        attempts = int(stats["attempts"]) + 1 if stats else 1
        tag_current_rating = float(stats["rating"]) if stats else current_rating
        tag_new_rating = tag_current_rating

        if tag_flow_entries:
            barrier = compute_barrier(tag_flow_entries, main_huddle)
            problem_weight = compute_problem_weight(quest_difficulty, barrier)
            problem_rating = compute_problem_rating(quest_difficulty, barrier)
            tag_outcome = tag_correct_by_tag.get(tag)
            tag_result = int(is_correct if tag_outcome is None else tag_outcome)
            attempt_confidence = _clamp(attempts / CONFIG.C_MAX, 0.0, 1.0)
            confidence_weight = (
                CONFIG.ALPHA
                + CONFIG.BETA * attempt_confidence
                + CONFIG.GAMMA * recent_accuracy_signal
                + CONFIG.DELTA * recency_signal
            ) * time_signal
            # 태그 실력과 전체 실력은 각각 자기 현재값으로 기대정답률을 계산한다.
            tag_expected = compute_expected_score(tag_current_rating, problem_rating)
            global_expected = compute_expected_score(current_rating, problem_rating)
            tag_delta = compute_k_factor(lose_streak) * (tag_result - tag_expected) * confidence_weight * problem_weight
            tag_delta = _clamp(tag_delta, -CONFIG.DELTA_MAX, CONFIG.DELTA_MAX)
            global_delta = compute_k_factor(lose_streak) * (tag_result - global_expected) * confidence_weight * problem_weight
            global_delta = _clamp(global_delta, -CONFIG.DELTA_MAX, CONFIG.DELTA_MAX)
            tag_new_rating += tag_delta
            rating_delta_total += global_delta * len(tag_flow_entries) / max(1, rated_flow_count)

        tag_updates.append({
            "user_id": user_id,
            "tag": tag,
            "attempts": attempts,
            "rating": tag_new_rating,
            "rating_prev": tag_current_rating,
            "updated_at": now,
        })

    user_new_rating = current_rating + rating_delta_total
    recent_results, recent_index, recent_count, recent_sum = _update_recent_results(
        recent_results, recent_index, recent_count, recent_sum, int(is_correct)
    )
    postgres_rating_store.upsert_tag_stats(cur, tag_updates)
    ovr_prev = float(user.get("ovr") or current_rating)
    ovr = postgres_rating_store.compute_ovr(cur, user_id, user_new_rating)
    new_lose_streak = 0 if is_correct else lose_streak + 1
    postgres_rating_store.update_user(cur, {
        "user_id": user_id,
        "rating": user_new_rating,
        "ovr": ovr,
        "ovr_prev": ovr_prev,
        "lose_streak": new_lose_streak,
        "last_attempt_at": now,
        "recent_results": recent_results,
        "recent_index": recent_index,
        "recent_count": recent_count,
        "recent_sum": recent_sum,
        "updated_at": now,
    })
    result = RatingResult(
        rating=user_new_rating,
        ovr=ovr,
        ovr_delta=ovr - ovr_prev,
        recent_accuracy=recent_sum / recent_count if recent_count else 0.0,
        lose_streak=new_lose_streak,
    )
    postgres_rating_store.save_submission_response(
        cur,
        user_id=user_id,
        submission_id=submission_ref,
        response=result.__dict__,
    )
    return result


def apply_level_test_placement(
    *,
    user_id: str,
    session_id: str,
    answers: List[Dict[str, Any]],
) -> PlacementRatingResult:
    """Apply a completed level-test placement as an initial rating estimate."""
    if len(answers) < 50:
        raise ValueError("level test requires 50 answers before rating placement")

    samples = _build_placement_samples(answers)
    if not samples:
        raise ValueError("level test answers contain no usable quest samples")

    estimated_rating = _estimate_rating_from_samples(samples)
    tag_ratings = _estimate_tag_ratings(samples, estimated_rating)
    correct_count = sum(1 for sample in samples if sample["is_correct"])
    recent_results = [1 if sample["is_correct"] else 0 for sample in samples[-50:]]
    confidence = _clamp(len(samples) / 50.0, 0.0, 1.0)
    now = _now_utc()
    submission_ref = f"level-test:{session_id}"
    with postgres_rating_store.transaction() as cur:
        # 단일 제출과 같은 잠금 순서(사용자→이벤트→태그)를 유지한다.
        user = postgres_rating_store.get_or_create_user(cur, user_id, for_update=True)
        replay = postgres_rating_store.claim_submission(
            cur,
            user_id=user_id,
            submission_id=submission_ref,
            quest_id=submission_ref,
        )
        if replay is not None:
            return PlacementRatingResult(**replay)
        ovr_prev = float(user.get("ovr") or CONFIG.DEFAULT_RATING)
        old_tag_stats = postgres_rating_store.get_tag_stats(cur, user_id, tag_ratings.keys())
        tag_updates = []
        for tag, rating in tag_ratings.items():
            previous = (
                float(old_tag_stats[tag]["rating"])
                if tag in old_tag_stats
                else estimated_rating
            )
            attempts = _tag_attempt_count(samples, tag)
            tag_updates.append(
                {
                    "user_id": user_id,
                    "tag": tag,
                    "attempts": max(1, attempts),
                    "rating": rating,
                    "rating_prev": previous,
                    "updated_at": now,
                }
            )
        postgres_rating_store.upsert_tag_stats(cur, tag_updates)
        estimated_ovr = postgres_rating_store.compute_ovr(cur, user_id, estimated_rating)
        lose_streak = 0 if samples[-1]["is_correct"] else 1
        postgres_rating_store.update_user(cur, {
            "user_id": user_id,
            "rating": estimated_rating,
            "ovr": estimated_ovr,
            "ovr_prev": ovr_prev,
            "lose_streak": lose_streak,
            "last_attempt_at": now,
            "recent_results": recent_results,
            "recent_index": len(recent_results) % 50,
            "recent_count": len(recent_results),
            "recent_sum": correct_count,
            "updated_at": now,
        })
        result = PlacementRatingResult(
            rating=estimated_rating,
            ovr=estimated_ovr,
            ovr_delta=estimated_ovr - ovr_prev,
            recent_accuracy=correct_count / len(recent_results),
            lose_streak=lose_streak,
            confidence=confidence,
            strong_tags=_rank_tag_results(tag_ratings, reverse=True),
            weak_tags=_rank_tag_results(tag_ratings, reverse=False),
        )
        postgres_rating_store.save_submission_response(
            cur,
            user_id=user_id,
            submission_id=submission_ref,
            response=result.__dict__,
        )
        return result


def _build_placement_samples(answers: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """필요 변수: 저장된 레벨테스트 답안. 작동 원리: PostgreSQL 문제 payload의 검수 태그·보정 레이팅으로 표본을 만든다."""
    from storage.postgres_level_test_store import postgres_level_test_store

    samples: List[Dict[str, Any]] = []
    quests = postgres_level_test_store.get_problem_payloads(
        str(answer.get("quest_id") or "") for answer in answers
    )
    for answer in answers:
        quest = quests.get(str(answer.get("quest_id") or ""))
        if not quest:
            continue
        info = quest.get("info", {}) or {}
        # 레벨테스트 교과 레이팅은 클라이언트 입력이 아닌 정적 문제의 검수 태그만 신뢰한다.
        raw_tags = info.get("hash_tag") or []
        tags = list(dict.fromkeys(_normalize_tag(str(tag)) for tag in raw_tags if _normalize_tag(str(tag))))
        if not tags:
            continue
        problem_rating = _placement_problem_rating(quest, tags)
        samples.append(
            {
                "quest_id": answer.get("quest_id"),
                "is_correct": bool(answer.get("is_correct")),
                "tags": tags,
                "problem_rating": problem_rating,
            }
        )
    return samples


def _placement_problem_rating(quest: Dict[str, Any], tags: List[str]) -> float:
    """필요 변수: 정적 문제와 태그. 작동 원리: 직접 보정한 고정 레이팅을 우선하고 구형 payload만 기존 휴리스틱으로 계산한다."""
    info = quest.get("info", {}) or {}
    try:
        calibrated = float(info.get("placement_rating"))
    except (TypeError, ValueError):
        calibrated = 0.0
    if calibrated > 0:
        return _clamp(calibrated, 900.0, 1700.0)
    try:
        difficulty = float(info.get("difficulty") or 0)
    except (TypeError, ValueError):
        difficulty = 0.0
    try:
        main_huddle = float(info.get("main_huddle") or 0)
    except (TypeError, ValueError):
        main_huddle = 0.0
    flattened_steps = _flatten_solve_steps(quest.get("solves") or [])
    tag_flow_by_tag = _build_tag_flow_map(flattened_steps)
    ratings = []
    for tag in tags:
        barrier = compute_barrier(tag_flow_by_tag.get(tag, []), main_huddle)
        ratings.append(compute_problem_rating(difficulty, barrier))
    if not ratings:
        return compute_problem_rating(difficulty, compute_barrier([], main_huddle))
    return sum(ratings) / len(ratings)


def _estimate_rating_from_samples(samples: List[Dict[str, Any]]) -> float:
    best_rating = CONFIG.DEFAULT_RATING
    best_score = float("-inf")
    for rating in [800 + i * 5 for i in range(281)]:
        score = -0.5 * ((rating - 1229.08) / 224.57) ** 2
        for sample in samples:
            expected = compute_expected_score(float(rating), float(sample["problem_rating"]))
            expected = _clamp(expected, 0.001, 0.999)
            score += math.log(expected if sample["is_correct"] else 1.0 - expected)
        if score > best_score:
            best_score = score
            best_rating = float(rating)
    return best_rating


def _estimate_tag_ratings(
    samples: List[Dict[str, Any]],
    global_rating: float,
) -> Dict[str, float]:
    by_tag: Dict[str, List[Dict[str, Any]]] = {}
    for sample in samples:
        for tag in sample["tags"]:
            by_tag.setdefault(tag, []).append(sample)

    result: Dict[str, float] = {}
    for tag, tag_samples in by_tag.items():
        local_rating = _estimate_rating_from_samples(tag_samples)
        shrink = len(tag_samples) / (len(tag_samples) + 5.0)
        result[tag] = shrink * local_rating + (1.0 - shrink) * global_rating
    return result


def _tag_attempt_count(samples: List[Dict[str, Any]], tag: str) -> int:
    return sum(1 for sample in samples if tag in sample["tags"])


def _rank_tag_results(
    tag_ratings: Dict[str, float],
    *,
    reverse: bool,
) -> List[Dict[str, Any]]:
    ordered = sorted(tag_ratings.items(), key=lambda item: item[1], reverse=reverse)
    return [
        {"tag": tag, "rating": round(rating, 2)}
        for tag, rating in ordered[:5]
    ]


def fetch_user_rating(user_id: str) -> RatingResult:
    """필요 변수: 사용자 ID. 작동 원리: PostgreSQL의 현재 레이팅과 최근 50문항 정답률을 읽는다."""
    user = postgres_rating_store.fetch_user(user_id)
    recent_count = int(user["recent_count"])
    return RatingResult(
        rating=float(user["rating"]),
        ovr=float(user["ovr"]),
        ovr_delta=float(user["ovr"]) - float(user["ovr_prev"]),
        recent_accuracy=int(user["recent_sum"]) / recent_count if recent_count else 0.0,
        lose_streak=int(user["lose_streak"]),
    )


def fetch_tag_ratings(user_id: str) -> List[Dict[str, Any]]:
    """필요 변수: 사용자 ID. 작동 원리: PostgreSQL 태그 레이팅을 순위순으로 변환한다."""
    return [
        {
            "tag": row["tag"],
            "attempts": int(row["attempts"]),
            "rating": float(row["rating"]),
            "delta": float(row["rating"]) - float(row["rating_prev"]),
        }
        for row in postgres_rating_store.list_tag_stats(user_id)
    ]
