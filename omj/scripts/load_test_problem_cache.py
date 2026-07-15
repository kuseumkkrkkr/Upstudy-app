"""문제 생성 없이 사용자별 캐시 선택 SQL 경로를 부하 테스트한다."""
from __future__ import annotations

import argparse
import json
import statistics
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from storage import storage as quest_storage
import user_habit


def _insert_cached_quests(count: int) -> None:
    """필요 변수: 캐시 문제 수. 작동 원리: 생성기를 호출하지 않고 SQL 캐시 선택에 필요한 문제·태그 행만 일괄 삽입한다."""
    tags = ["#비례", "#기울기", "#함수"]
    tags_json = json.dumps(tags, ensure_ascii=False)
    conn = quest_storage._connect()
    try:
        for index in range(count):
            quest_id = f"cache-{index:04d}"
            conn.execute(
                "INSERT INTO quest_header (quest_id, quest_model) VALUES (?, '[]')",
                (quest_id,),
            )
            conn.execute(
                """INSERT INTO quest_info
                (quest_id, main, sub, hash_tag, flow_rate, difficulty, main_huddle,
                 difficulty_tier, difficulty_score, tier_source, quality_status,
                 quality_reasons, quality_checked_at)
                VALUES (?, 0, '[]', ?, 4, 26, 2, 3, 26, 'load-test', 'approved', '[]', 0)""",
                (quest_id, tags_json),
            )
            conn.execute(
                """INSERT INTO quest_data
                (quest_id, quest_title, codebase_id, seed, hash_tag)
                VALUES (?, '{}', ?, ?, ?)""",
                (quest_id, index + 1, 100_000 + index, tags_json),
            )
            conn.executemany(
                "INSERT INTO quest_tag_index (quest_id, tag) VALUES (?, ?)",
                [(quest_id, tag.lstrip("#").lower()) for tag in tags],
            )
        conn.commit()
    finally:
        conn.close()


def _insert_dummy_history(user_count: int) -> None:
    """필요 변수: 사용자 수. 작동 원리: 각 사용자에게 캐시와 겹치지 않는 최근 풀이 이력을 넣어 중복 제외 SQL 조인을 실제로 수행한다."""
    now = "2026-07-14T00:00:00Z"
    rows = [
        (f"load-user-{index:06d}", "problem", 9_000_000 + index, str(index), "[]", "dummy", 1, now)
        for index in range(user_count)
    ]
    conn = quest_storage._connect()
    try:
        conn.executemany(
            """INSERT INTO user_habit
            (user_id, kind, codebase_id, seed, tags, quest_title, retry_count, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
            rows,
        )
        conn.commit()
    finally:
        conn.close()


def _request_cached_quest(
    user_index: int,
    *,
    user_prefix: str = "load-user",
    hash_tags: list[str] | None = None,
    difficulty_tier: int = 3,
) -> dict[str, Any]:
    """필요 변수: 더미 사용자·접두사·태그·티어. 작동 원리: 선택한 실제 저장소에서 문제 생성 없이 캐시 조회 지연을 반환한다."""
    started = time.perf_counter()
    tags = hash_tags or ["#비례", "#기울기", "#함수"]
    quests, state = quest_storage.claim_cached_quests(
        user_id=f"{user_prefix}-{user_index:06d}",
        hash_tags=tags,
        min_difficulty_tier=difficulty_tier,
        max_difficulty_tier=difficulty_tier,
        question_count=1,
        prefetch_count=0,
    )
    return {
        "elapsed_ms": (time.perf_counter() - started) * 1000,
        "cached": len(quests),
        "state": state,
    }


def _percentile(values: list[float], percentile: float) -> float:
    """필요 변수: 지연시간 목록과 백분위. 작동 원리: 정렬 인덱스로 외부 라이브러리 없이 p95·p99를 계산한다."""
    if not values:
        return 0.0
    ordered = sorted(values)
    index = min(len(ordered) - 1, int((len(ordered) - 1) * percentile))
    return ordered[index]


def _execute_requests(
    *, users: int, concurrency: int, user_prefix: str, hash_tags: list[str], difficulty_tier: int
) -> tuple[list[dict[str, Any]], list[str], float]:
    """필요 변수: 부하 크기와 실제 조회 조건. 작동 원리: 공통 병렬 실행기로 결과·예외·총 시간을 수집한다."""
    started = time.perf_counter()
    results: list[dict[str, Any]] = []
    failures: list[str] = []
    with ThreadPoolExecutor(max_workers=concurrency) as executor:
        futures = [
            executor.submit(
                _request_cached_quest,
                index,
                user_prefix=user_prefix,
                hash_tags=hash_tags,
                difficulty_tier=difficulty_tier,
            )
            for index in range(users)
        ]
        for future in as_completed(futures):
            try:
                results.append(future.result())
            except Exception as exc:  # 부하 결과에는 예외 건수도 포함한다.
                failures.append(repr(exc))
    return results, failures, time.perf_counter() - started


def run_load_test(*, users: int, concurrency: int, cached_quests: int) -> dict[str, Any]:
    """필요 변수: 사용자·동시성·캐시 수. 작동 원리: 임시 DB에서 2천 사용자 SQL 캐시 요청을 병렬 실행하고 성공률과 지연시간을 집계한다."""
    with tempfile.TemporaryDirectory(prefix="omj-cache-load-") as temp_dir:
        db_path = str(Path(temp_dir) / "quests.db")
        original_quest_db = quest_storage.DB_PATH
        original_habit_db = user_habit.DB_PATH
        try:
            quest_storage.DB_PATH = db_path
            user_habit.DB_PATH = db_path
            quest_storage.init_db()
            user_habit.init_habit_db()
            _insert_cached_quests(cached_quests)
            _insert_dummy_history(users)

            results, failures, duration_sec = _execute_requests(
                users=users,
                concurrency=concurrency,
                user_prefix="load-user",
                hash_tags=["#비례", "#기울기", "#함수"],
                difficulty_tier=3,
            )
        finally:
            quest_storage.DB_PATH = original_quest_db
            user_habit.DB_PATH = original_habit_db

    latencies = [float(result["elapsed_ms"]) for result in results]
    cached_hits = sum(1 for result in results if result["cached"] == 1)
    return {
        "users": users,
        "concurrency": concurrency,
        "cached_quests": cached_quests,
        "duration_sec": round(duration_sec, 3),
        "requests_per_sec": round(users / duration_sec, 2) if duration_sec else 0.0,
        "cached_hits": cached_hits,
        "empty_results": len(results) - cached_hits,
        "exceptions": len(failures),
        "p50_ms": round(_percentile(latencies, 0.50), 2),
        "p95_ms": round(_percentile(latencies, 0.95), 2),
        "p99_ms": round(_percentile(latencies, 0.99), 2),
        "max_ms": round(max(latencies), 2) if latencies else 0.0,
    }


def run_postgres_load_test(
    *, users: int, concurrency: int, hash_tags: list[str], difficulty_tier: int
) -> dict[str, Any]:
    """필요 변수: 실제 PostgreSQL·Redis 환경과 조회 조건. 작동 원리: readiness 통과 후 고유 사용자를 병렬 조회해 상용 경로 지연을 측정한다."""
    from services.runtime_readiness import runtime_readiness

    readiness = runtime_readiness()
    if readiness["ready"] is not True or readiness["problem_cache_backend"] != "postgres":
        raise RuntimeError(f"PostgreSQL runtime is not ready: {readiness}")
    prefix = f"pg-load-{int(time.time() * 1000)}"
    results, failures, duration_sec = _execute_requests(
        users=users,
        concurrency=concurrency,
        user_prefix=prefix,
        hash_tags=hash_tags,
        difficulty_tier=difficulty_tier,
    )
    latencies = [float(result["elapsed_ms"]) for result in results]
    cached_hits = sum(1 for result in results if result["cached"] == 1)
    return {
        "backend": "postgres",
        "users": users,
        "concurrency": concurrency,
        "hash_tags": hash_tags,
        "difficulty_tier": difficulty_tier,
        "duration_sec": round(duration_sec, 3),
        "requests_per_sec": round(users / duration_sec, 2) if duration_sec else 0.0,
        "cached_hits": cached_hits,
        "empty_results": len(results) - cached_hits,
        "exceptions": len(failures),
        "p50_ms": round(_percentile(latencies, 0.50), 2),
        "p95_ms": round(_percentile(latencies, 0.95), 2),
        "p99_ms": round(_percentile(latencies, 0.99), 2),
        "max_ms": round(max(latencies), 2) if latencies else 0.0,
        "readiness": readiness,
    }


def main() -> None:
    """필요 변수: CLI 인자. 작동 원리: 기본값 2,000명의 더미 사용자를 실행하고 JSON 결과만 표준 출력한다."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--users", type=int, default=2000)
    parser.add_argument("--concurrency", type=int, default=200)
    parser.add_argument("--cached-quests", type=int, default=100)
    parser.add_argument("--backend", choices=("sqlite", "postgres"), default="sqlite")
    parser.add_argument("--tags", default="#비례,#기울기,#함수")
    parser.add_argument("--tier", type=int, default=3)
    args = parser.parse_args()
    if args.backend == "postgres":
        tags = [tag.strip() for tag in args.tags.split(",") if tag.strip()]
        result = run_postgres_load_test(
            users=max(1, args.users),
            concurrency=max(1, args.concurrency),
            hash_tags=tags,
            difficulty_tier=max(1, min(5, args.tier)),
        )
    else:
        result = run_load_test(
            users=max(1, args.users),
            concurrency=max(1, args.concurrency),
            cached_quests=max(1, args.cached_quests),
        )
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
