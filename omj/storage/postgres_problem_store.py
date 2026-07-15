"""PostgreSQL 문제 payload·풀이 이력 이중 기록 저장소."""
from __future__ import annotations

import json
import os
import time
from math import ceil
from concurrent.futures import ThreadPoolExecutor
from threading import BoundedSemaphore, Lock
from typing import Any, Optional

from difficulty_contract import DIFFICULTY_CONTRACTS, resolve_difficulty_score, resolve_difficulty_tier
from student_problem_content_review import review_student_problem_contract


def _env_int(name: str, default: int, minimum: int = 1) -> int:
    """필요 변수: 환경 변수명·기본값·최솟값. 작동 원리: 잘못된 운영 숫자 설정을 안전한 기본값과 하한으로 보정한다."""
    try:
        return max(minimum, int(os.getenv(name, str(default))))
    except (TypeError, ValueError):
        return max(minimum, default)


class PostgresProblemStore:
    """DATABASE_URL이 설정된 환경에서만 PostgreSQL 영속 저장소를 사용한다."""

    def __init__(self) -> None:
        self._pool: Any = None
        self._lock = Lock()
        self._pool_failed_at = 0.0
        self._write_executor = ThreadPoolExecutor(
            max_workers=_env_int("POSTGRES_DUAL_WRITE_WORKERS", 4),
            thread_name_prefix="postgres-dual-write",
        )
        self._write_slots = BoundedSemaphore(
            _env_int("POSTGRES_DUAL_WRITE_QUEUE_SIZE", 2000, minimum=100)
        )
        self._verification_checked_at = 0.0
        self._verification_ok = False

    def _get_pool(self) -> Optional[Any]:
        """필요 변수: DATABASE_URL. 작동 원리: 연결 풀을 지연 생성하고 설정·연결 오류는 기존 경로에 영향을 주지 않게 None으로 처리한다."""
        if self._pool is not None:
            return self._pool
        database_url = os.getenv("DATABASE_URL", "").strip()
        if not database_url:
            return None
        try:
            retry_seconds = max(1.0, float(os.getenv("POSTGRES_CONNECT_RETRY_SEC", "5")))
        except ValueError:
            retry_seconds = 5.0
        if self._pool_failed_at and time.monotonic() - self._pool_failed_at < retry_seconds:
            return None
        with self._lock:
            if self._pool is not None:
                return self._pool
            if self._pool_failed_at and time.monotonic() - self._pool_failed_at < retry_seconds:
                return None
            try:
                from psycopg_pool import ConnectionPool

                self._pool = ConnectionPool(
                    conninfo=database_url,
                    min_size=1,
                    max_size=_env_int("POSTGRES_POOL_MAX_SIZE", 20, minimum=4),
                    timeout=1,
                    open=True,
                )
                self._pool_failed_at = 0.0
            except Exception:
                self._pool = None
                self._pool_failed_at = time.monotonic()
        return self._pool

    def get_pool(self) -> Any:
        """필요 변수: DATABASE_URL과 적용된 PostgreSQL 마이그레이션. 작동 원리: 문제·레이팅 저장소가 같은 프로세스 연결 풀을 공유하며, 연결 불가 시 즉시 실패시킨다."""
        pool = self._get_pool()
        if pool is None:
            raise RuntimeError("PostgreSQL connection pool is unavailable")
        return pool

    def is_cache_backend_enabled(self) -> bool:
        """필요 변수: PROBLEM_CACHE_BACKEND·DATABASE_URL. 작동 원리: 이관 전 서버가 빈 PostgreSQL을 읽지 않도록 명시적 전환 플래그를 요구한다."""
        return (
            os.getenv("PROBLEM_CACHE_BACKEND", "").strip().lower() == "postgres"
            and bool(os.getenv("DATABASE_URL", "").strip())
            and os.getenv("PROBLEM_CACHE_VERIFIED", "").strip().lower() in {"1", "true", "yes"}
            and self.has_verified_migration()
        )

    def ping(self) -> bool:
        """필요 변수: PostgreSQL 연결 풀. 작동 원리: 준비 상태 점검에서 짧은 SELECT 1로 실제 연결 가능 여부를 확인한다."""
        pool = self._get_pool()
        if pool is None:
            return False
        try:
            with pool.connection() as conn, conn.cursor() as cur:
                cur.execute("SELECT 1")
                row = cur.fetchone()
            return bool(row and int(row[0]) == 1)
        except Exception:
            return False

    def has_verified_migration(self, *, force: bool = False) -> bool:
        """필요 변수: 검증 캐시 강제 갱신 여부. 작동 원리: PostgreSQL 내부의 원본·대상 동일 해시 감사 레코드를 30초 TTL로 확인한다."""
        now = time.monotonic()
        if not force and now - self._verification_checked_at < 30:
            return self._verification_ok
        pool = self._get_pool()
        verified = False
        if pool is not None:
            try:
                with pool.connection() as conn, conn.cursor() as cur:
                    cur.execute(
                        """
                        SELECT source_count = target_count AND source_digest = target_digest
                        FROM problem_cache_migration_audit
                        ORDER BY id DESC LIMIT 1
                        """
                    )
                    row = cur.fetchone()
                verified = bool(row and row[0] is True)
            except Exception:
                verified = False
        self._verification_ok = verified
        self._verification_checked_at = now
        return verified

    def record_migration_audit(self, report: dict[str, Any]) -> None:
        """필요 변수: 전 행 이관 검증 보고서. 작동 원리: 동일 개수·해시만 DB 제약을 통과하도록 배포 승인 증거를 영속 저장한다."""
        pool = self._get_pool()
        if pool is None:
            raise RuntimeError("PostgreSQL connection pool is unavailable")
        with pool.connection() as conn, conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO problem_cache_migration_audit
                (source_count, target_count, source_digest, target_digest, tier_counts, report)
                VALUES (%s, %s, %s, %s, %s::jsonb, %s::jsonb)
                """,
                (
                    int(report["source_approved"]),
                    int(report["target_approved"]),
                    str(report["source_digest"]),
                    str(report["target_digest"]),
                    json.dumps(report["tier_counts"], ensure_ascii=False),
                    json.dumps(report, ensure_ascii=False),
                ),
            )
            conn.commit()
        self._verification_checked_at = 0.0

    def upsert_problem(self, quest: dict[str, Any], *, strict: bool = False) -> bool:
        """필요 변수: 정규화된 문제 payload·엄격 모드. 작동 원리: PostgreSQL에 원자 저장하고 이관 중에는 연결·SQL 오류를 호출자에게 전달한다."""
        pool = self._get_pool()
        if pool is None:
            if strict:
                raise RuntimeError("PostgreSQL connection pool is unavailable")
            return False
        header = quest.get("header") if isinstance(quest, dict) else {}
        info = quest.get("info") if isinstance(quest, dict) else {}
        data = quest.get("data") if isinstance(quest, dict) else {}
        quest_id = str((header or {}).get("quest_id") or "").strip()
        if not quest_id:
            if strict:
                raise ValueError("quest_id is required")
            return False
        raw_tags = (info or {}).get("hash_tag") or []
        tags = sorted({str(tag).strip().lstrip("#") for tag in raw_tags if str(tag).strip()})
        difficulty_tier, _ = resolve_difficulty_tier(info or {})
        difficulty_score = resolve_difficulty_score(info or {})
        review = review_student_problem_contract(
            quest,
            expected_solve_count=DIFFICULTY_CONTRACTS[difficulty_tier].solves_count,
            expected_tags=(info or {}).get("hash_tag") or [],
        )
        quality_reasons = [str(reason) for reason in review["reasons"]]
        quality_status = str((info or {}).get("quality_status") or "").strip()
        if quality_reasons:
            quality_status = "rejected"
        elif quality_status not in {"approved", "quarantined", "rejected"}:
            quality_status = "approved"
        try:
            with pool.connection() as conn, conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO problem_payload
                    (quest_id, codebase_id, seed, difficulty_tier, difficulty_score,
                     quality_status, quality_reasons, tags, payload, updated_at)
                    VALUES (%s, %s, %s, %s, %s, %s, %s::jsonb, %s::jsonb, %s::jsonb, NOW())
                    ON CONFLICT (quest_id) DO UPDATE SET
                        codebase_id = EXCLUDED.codebase_id,
                        seed = EXCLUDED.seed,
                        difficulty_tier = EXCLUDED.difficulty_tier,
                        difficulty_score = EXCLUDED.difficulty_score,
                        quality_status = EXCLUDED.quality_status,
                        quality_reasons = EXCLUDED.quality_reasons,
                        tags = EXCLUDED.tags,
                        payload = EXCLUDED.payload,
                        updated_at = NOW()
                    """,
                    (
                        quest_id,
                        (data or {}).get("codebase_id"),
                        (data or {}).get("seed"),
                        difficulty_tier,
                        difficulty_score,
                        quality_status,
                        json.dumps(quality_reasons, ensure_ascii=False),
                        json.dumps(tags, ensure_ascii=False),
                        json.dumps(quest, ensure_ascii=False),
                    ),
                )
                conn.commit()
            return True
        except Exception:
            if strict:
                raise
            return False

    def record_problem_solve(
        self,
        *,
        user_id: str,
        codebase_id: int,
        seed: str,
        tags: list[str],
        strict: bool = False,
    ) -> bool:
        """필요 변수: 사용자·문제 variant·태그·엄격 모드. 작동 원리: 최근 풀이를 UPSERT하며 이관 중에는 실패를 숨기지 않는다."""
        pool = self._get_pool()
        if pool is None:
            if strict:
                raise RuntimeError("PostgreSQL connection pool is unavailable")
            return False
        normalized_tags = sorted({str(tag).strip().lstrip("#") for tag in tags if str(tag).strip()})
        try:
            with pool.connection() as conn, conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO user_problem_history
                    (user_id, codebase_id, seed, tags, solved_at, solve_count)
                    VALUES (%s, %s, %s, %s::jsonb, NOW(), 1)
                    ON CONFLICT (user_id, codebase_id, seed) DO UPDATE SET
                        tags = EXCLUDED.tags,
                        solved_at = NOW(),
                        solve_count = user_problem_history.solve_count + 1
                    """,
                    (user_id, codebase_id, int(seed), json.dumps(normalized_tags, ensure_ascii=False)),
                )
                conn.commit()
            return True
        except (TypeError, ValueError):
            if strict:
                raise
            return False
        except Exception:
            if strict:
                raise
            return False

    def _submit_bounded(self, function: Any, /, **kwargs: Any) -> bool:
        """필요 변수: DB 기록 함수와 인자. 작동 원리: 대기열 상한을 넘으면 즉시 SQLite 경로만 유지해 메모리 무한 증가를 막는다."""
        if not self._write_slots.acquire(blocking=False):
            return False
        try:
            future = self._write_executor.submit(function, **kwargs)
            future.add_done_callback(lambda _future: self._write_slots.release())
            return True
        except RuntimeError:
            self._write_slots.release()
            return False

    def enqueue_problem_upsert(self, quest: dict[str, Any]) -> bool:
        """필요 변수: SQLite 저장이 끝난 문제. 작동 원리: 요청 지연 없이 제한된 큐로 PostgreSQL 이중 기록을 수행한다."""
        if not os.getenv("DATABASE_URL", "").strip():
            return False
        return self._submit_bounded(self.upsert_problem, quest=quest)

    def enqueue_problem_solve(self, *, user_id: str, codebase_id: int, seed: str, tags: list[str]) -> None:
        """필요 변수: 풀이 이력 값. 작동 원리: 사용자 응답 경로를 막지 않도록 PostgreSQL 이중 기록을 제한된 전용 워커에 제출한다."""
        if not os.getenv("DATABASE_URL", "").strip():
            return
        self._submit_bounded(
            self.record_problem_solve,
            user_id=user_id,
            codebase_id=codebase_id,
            seed=seed,
            tags=tags,
        )

    def approved_problem_snapshot(self) -> dict[str, tuple[int, int, dict[str, Any]]]:
        """필요 변수: PostgreSQL 연결. 작동 원리: 전환 검증용 승인 문제 ID·티어·점수·payload를 전부 읽어 원본과 대조한다."""
        pool = self._get_pool()
        if pool is None:
            raise RuntimeError("PostgreSQL connection pool is unavailable")
        snapshot: dict[str, tuple[int, int, dict[str, Any]]] = {}
        with pool.connection() as conn, conn.cursor() as cur:
            cur.execute(
                """
                SELECT quest_id, difficulty_tier, difficulty_score, payload
                FROM problem_payload
                WHERE quality_status='approved'
                ORDER BY quest_id
                """
            )
            for quest_id, tier, score, payload in cur.fetchall():
                if isinstance(payload, str):
                    payload = json.loads(payload)
                snapshot[str(quest_id)] = (
                    int(tier),
                    int(score),
                    payload if isinstance(payload, dict) else {},
                )
        return snapshot

    def problem_history_keys(self) -> set[tuple[str, int, int]]:
        """필요 변수: PostgreSQL 풀이 이력. 작동 원리: SQLite 과거 variant가 모두 이관됐는지 검증할 복합 키 집합을 읽는다."""
        pool = self._get_pool()
        if pool is None:
            raise RuntimeError("PostgreSQL connection pool is unavailable")
        with pool.connection() as conn, conn.cursor() as cur:
            cur.execute("SELECT user_id, codebase_id, seed FROM user_problem_history")
            return {
                (str(user_id), int(codebase_id), int(seed))
                for user_id, codebase_id, seed in cur.fetchall()
            }

    def claim_cached_quests(
        self,
        *,
        user_id: str,
        hash_tags: list[str],
        min_difficulty_tier: int,
        max_difficulty_tier: int,
        question_count: int,
        prefetch_count: int,
    ) -> Optional[tuple[list[dict[str, Any]], dict[str, int]]]:
        """필요 변수: 사용자·태그·난이도·문항 수. 작동 원리: Redis 예약 큐를 먼저 소비한 뒤 PostgreSQL에서 100%→50%→1개 태그 후보를 채운다."""
        if not self.is_cache_backend_enabled():
            return None
        pool = self._get_pool()
        tags = sorted({str(tag).strip().lstrip("#") for tag in hash_tags if str(tag).strip()})
        if pool is None or not tags or question_count < 1:
            return None
        from services.problem_runtime_cache import problem_runtime_cache

        request_key = f"{','.join(tags)}|{min_difficulty_tier}|{max_difficulty_tier}"
        claimed_variants = sorted(problem_runtime_cache.list_claimed_variants(user_id=user_id))
        queued_ids = problem_runtime_cache.take_prefetched(
            user_id=user_id,
            request_key=request_key,
            count=question_count,
        )
        queued_payloads = problem_runtime_cache.load_payloads(queued_ids)
        missing_queued_ids = [quest_id for quest_id in queued_ids if quest_id not in queued_payloads]
        quests = [queued_payloads[quest_id] for quest_id in queued_ids if quest_id in queued_payloads]
        target_count = question_count + max(0, prefetch_count)
        needed = max(0, target_count - len(queued_ids))
        match_stage = 0
        selected_candidate_ids: list[str] = []
        selected_for_prefetch: list[dict[str, Any]] = []
        selected_ids = set(queued_ids)
        try:
            with pool.connection() as conn, conn.cursor() as cur:
                if missing_queued_ids:
                    cur.execute(
                        """
                        SELECT quest_id, payload FROM problem_payload
                        WHERE quest_id = ANY(%s) AND quality_status='approved'
                        """,
                        (missing_queued_ids,),
                    )
                    recovered = {}
                    for quest_id, payload in cur.fetchall():
                        if isinstance(payload, str):
                            payload = json.loads(payload)
                        if isinstance(payload, dict):
                            recovered[str(quest_id)] = payload
                    quests.extend(recovered[quest_id] for quest_id in missing_queued_ids if quest_id in recovered)
                    problem_runtime_cache.cache_payloads(list(recovered.values()))
                match_stages = dict.fromkeys((len(tags), max(1, ceil(len(tags) * 0.5)), 1))
                for required_matches in match_stages:
                    if needed <= 0:
                        break
                    cur.execute(
                        """
                        SELECT p.quest_id, p.codebase_id, p.seed,
                               COUNT(DISTINCT tag.value) AS matched_count
                        FROM problem_payload p
                        CROSS JOIN LATERAL jsonb_array_elements_text(p.tags) AS tag(value)
                        WHERE p.difficulty_tier BETWEEN %s AND %s
                          AND p.quality_status = 'approved'
                          AND p.tags ?| %s::text[]
                          AND tag.value = ANY(%s)
                          AND NOT EXISTS (
                            SELECT 1 FROM user_problem_history h
                            WHERE h.user_id = %s
                              AND h.codebase_id = p.codebase_id
                              AND h.seed = p.seed
                          )
                          AND NOT (
                            (p.codebase_id::text || ':' || p.seed::text) = ANY(%s::text[])
                          )
                        GROUP BY p.quest_id, p.codebase_id, p.seed, p.updated_at
                        HAVING COUNT(DISTINCT tag.value) >= %s
                        ORDER BY matched_count DESC, p.updated_at DESC
                        LIMIT %s
                        """,
                        (
                            min_difficulty_tier,
                            max_difficulty_tier,
                            tags,
                            tags,
                            user_id,
                            claimed_variants,
                            required_matches,
                            max(target_count * 3, 30),
                        ),
                    )
                    rows = cur.fetchall()
                    if not rows:
                        continue
                    if match_stage == 0:
                        match_stage = required_matches
                    for quest_id, codebase_id, seed, _matched in rows:
                        quest_id = str(quest_id)
                        if quest_id in selected_ids:
                            continue
                        if codebase_id is None or seed is None:
                            continue
                        if not problem_runtime_cache.claim_unserved_variant(
                            user_id=user_id,
                            codebase_id=int(codebase_id),
                            seed=seed,
                        ):
                            continue
                        selected_candidate_ids.append(quest_id)
                        selected_ids.add(quest_id)
                        if len(selected_candidate_ids) >= needed:
                            break
                    needed = max(0, target_count - len(queued_ids) - len(selected_candidate_ids))
                if selected_candidate_ids:
                    cur.execute(
                        """
                        SELECT quest_id, payload FROM problem_payload
                        WHERE quest_id = ANY(%s) AND quality_status='approved'
                        """,
                        (selected_candidate_ids,),
                    )
                    payloads: dict[str, dict[str, Any]] = {}
                    for quest_id, payload in cur.fetchall():
                        if isinstance(payload, str):
                            payload = json.loads(payload)
                        if isinstance(payload, dict):
                            payloads[str(quest_id)] = payload
                    selected_for_prefetch = [
                        payloads[quest_id]
                        for quest_id in selected_candidate_ids
                        if quest_id in payloads
                    ]
        except Exception:
            return None

        problem_runtime_cache.cache_payloads(selected_for_prefetch)
        serve_now = max(0, question_count - len(quests))
        quests.extend(selected_for_prefetch[:serve_now])
        prefetch_ids = [
            str(((quest.get("header") or {}).get("quest_id") or "")).strip()
            for quest in selected_for_prefetch[serve_now:]
        ]
        problem_runtime_cache.reserve_prefetch(
            user_id=user_id,
            request_key=request_key,
            quest_ids=[quest_id for quest_id in prefetch_ids if quest_id],
        )
        return quests, {
            "queued": max(0, target_count - len(queued_ids) - len(selected_for_prefetch)),
            "cached": len(quests),
            "match_stage": match_stage,
        }


postgres_problem_store = PostgresProblemStore()
