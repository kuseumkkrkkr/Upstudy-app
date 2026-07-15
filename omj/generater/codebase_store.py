from __future__ import annotations

import hashlib
import json
import os
import sqlite3
from pathlib import Path
from typing import Any, Dict, List, Optional


def _resolve_db_path() -> Path:
    override = os.environ.get("CODEBASE_DB_PATH")
    if override:
        return Path(override)
    return Path(__file__).resolve().parents[1] / "codebases.db"


import atexit
import threading

_db_local = threading.local()
_init_db_lock = threading.Lock()
_init_db_done: bool = False


def _get_db_connection() -> sqlite3.Connection:
    conn = getattr(_db_local, "conn", None)
    if conn is None:
        conn = sqlite3.connect(_resolve_db_path())
        conn.row_factory = sqlite3.Row
        _db_local.conn = conn
    return conn


def _close_all_db_connections() -> None:
    """Close all thread-local DB connections on shutdown."""
    conn = getattr(_db_local, "conn", None)
    if conn is not None:
        try:
            conn.close()
        except Exception:
            pass
        _db_local.conn = None


atexit.register(_close_all_db_connections)


def init_db() -> None:
    global _init_db_done
    if _init_db_done:
        return
    with _init_db_lock:
        if _init_db_done:
            return
        conn = sqlite3.connect(_resolve_db_path())
        conn.row_factory = sqlite3.Row
        try:
            _init_db_impl(conn)
            conn.commit()
        finally:
            conn.close()
        _init_db_done = True


def _init_db_impl(conn: sqlite3.Connection) -> None:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS codebases (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              prompt TEXT NOT NULL,
              code TEXT NOT NULL,
              mode TEXT,
              tags TEXT,
              difficulty INTEGER,
              tier INTEGER,
              solves_count INTEGER,
              strategy_level INTEGER,
              branch_conditions INTEGER,
              validated_seeds TEXT,
              created_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS codebase_seed_cache (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              codebase_id INTEGER NOT NULL,
              code_hash TEXT NOT NULL,
              seed INTEGER NOT NULL,
              created_at TEXT DEFAULT CURRENT_TIMESTAMP,
              UNIQUE(codebase_id, code_hash, seed)
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS codebase_seed_stats (
              codebase_id INTEGER NOT NULL,
              code_hash TEXT NOT NULL,
              attempts INTEGER NOT NULL DEFAULT 0,
              successes INTEGER NOT NULL DEFAULT 0,
              updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
              UNIQUE(codebase_id, code_hash)
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS codebase_seed_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              codebase_id INTEGER NOT NULL,
              code_hash TEXT NOT NULL,
              seed INTEGER,
              status TEXT NOT NULL,
              error_type TEXT,
              error_message TEXT,
              stage TEXT,
              elapsed_ms INTEGER,
              source TEXT,
              created_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
            """
        )
        conn.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_seed_cache_lookup
            ON codebase_seed_cache(codebase_id, code_hash)
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS codebase_agent_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              codebase_id INTEGER,
              action TEXT NOT NULL,
              status TEXT NOT NULL,
              attempt INTEGER,
              error_message TEXT,
              detail TEXT,
              created_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS formula_seed_cache (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              signature TEXT NOT NULL,
              seed INTEGER NOT NULL,
              params_json TEXT,
              answers_json TEXT,
              created_at TEXT DEFAULT CURRENT_TIMESTAMP,
              UNIQUE(signature, seed)
            )
            """
        )
        _ensure_column(conn, "codebases", "validated_seeds", "TEXT")
        _ensure_column(conn, "codebases", "tier_source", "TEXT")
        _ensure_column(conn, "codebases", "quality_status", "TEXT NOT NULL DEFAULT 'pending_validation'")
        _ensure_column(conn, "codebases", "quality_reasons", "TEXT NOT NULL DEFAULT '[]'")
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_codebases_tier_quality ON codebases(tier, quality_status, id)"
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS codebase_quality_validation (
                codebase_id INTEGER NOT NULL,
                code_hash TEXT NOT NULL,
                seed INTEGER NOT NULL,
                status TEXT NOT NULL CHECK(status IN ('approved','rejected')),
                reasons_json TEXT NOT NULL,
                checked_at INTEGER NOT NULL,
                PRIMARY KEY(codebase_id, code_hash, seed)
            )
            """
        )
        conn.commit()


def _ensure_column(conn: sqlite3.Connection, table: str, column: str, definition: str) -> None:
    existing = {row["name"] for row in conn.execute(f"PRAGMA table_info({table})").fetchall()}
    if column not in existing:
        conn.execute(f"ALTER TABLE {table} ADD COLUMN {column} {definition}")


def _close_connection() -> None:
    """Close thread-local connection if open. Call at thread exit."""
    conn = getattr(_db_local, "conn", None)
    if conn is not None:
        conn.close()
        _db_local.conn = None


def load_codebases(*, student_ready_only: bool = False) -> List[Dict[str, Any]]:
    """필요 변수: 학생용 승인 필터. 작동 원리: 관리·수리 경로는 전부 읽고 학생 재사용 경로는 검증 완료 코드베이스만 읽는다."""
    init_db()
    with _get_db_connection() as conn:
        where = "WHERE quality_status = 'approved'" if student_ready_only else ""
        rows = conn.execute(
            f"""
            SELECT id, name, prompt, code, mode, tags, difficulty, tier,
                   solves_count, strategy_level, branch_conditions, validated_seeds, created_at,
                   tier_source, quality_status, quality_reasons
            FROM codebases
            {where}
            ORDER BY id ASC
            """
        ).fetchall()
    results: List[Dict[str, Any]] = []
    for row in rows:
        tags_raw = row["tags"] or ""
        try:
            tags = json.loads(tags_raw) if tags_raw else []
        except Exception:
            tags = []
        seeds_raw = row["validated_seeds"] or ""
        try:
            validated_seeds = json.loads(seeds_raw) if seeds_raw else []
        except Exception:
            validated_seeds = []
        results.append(
            {
                "id": row["id"],
                "name": row["name"],
                "prompt": row["prompt"],
                "code": row["code"],
                "mode": row["mode"],
                "tags": tags,
                "difficulty": row["difficulty"],
                "tier": row["tier"],
                "solves_count": row["solves_count"],
                "strategy_level": row["strategy_level"],
                "branch_conditions": row["branch_conditions"],
                "validated_seeds": validated_seeds,
                "created_at": row["created_at"],
                "tier_source": row["tier_source"],
                "quality_status": row["quality_status"],
                "quality_reasons": _safe_json_list(row["quality_reasons"]),
            }
        )
    return results


def save_codebase(entry: Dict[str, Any]) -> Dict[str, Any]:
    init_db()
    with _get_db_connection() as conn:
        cursor = conn.execute(
            """
            INSERT INTO codebases (
              name, prompt, code, mode, tags, difficulty, tier,
              solves_count, strategy_level, branch_conditions, validated_seeds,
              tier_source, quality_status, quality_reasons
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                entry.get("name") or "",
                entry.get("prompt") or "",
                entry.get("code") or "",
                entry.get("mode"),
                json.dumps(entry.get("tags") or [], ensure_ascii=False),
                entry.get("difficulty"),
                entry.get("tier"),
                entry.get("solves_count"),
                entry.get("strategy_level"),
                entry.get("branch_conditions"),
                json.dumps(entry.get("validated_seeds") or [], ensure_ascii=False),
                entry.get("tier_source") or "explicit",
                entry.get("quality_status") or "pending_validation",
                json.dumps(entry.get("quality_reasons") or [], ensure_ascii=False),
            ),
        )
        new_id = cursor.lastrowid
        name = entry.get("name") or f"CB-{new_id:03d}"
        conn.execute("UPDATE codebases SET name = ? WHERE id = ?", (name, new_id))
        conn.commit()
    entry["id"] = new_id
    entry["name"] = name
    return entry


def _safe_json_list(value: Any) -> List[Any]:
    """필요 변수: JSON 목록 문자열. 작동 원리: 손상된 품질 사유를 빈 목록으로 안전하게 읽는다."""
    try:
        parsed = json.loads(value) if isinstance(value, str) else value
    except json.JSONDecodeError:
        return []
    return parsed if isinstance(parsed, list) else []


def update_codebase_quality(entry_id: int, status: str, reasons: List[str]) -> None:
    """필요 변수: 코드베이스 ID·품질 상태·사유. 작동 원리: 학생 재사용 승인 또는 격리를 한 행 갱신으로 기록한다."""
    if status not in {"pending_validation", "approved", "quarantined", "rejected"}:
        raise ValueError(f"invalid codebase quality status: {status}")
    init_db()
    with _get_db_connection() as conn:
        conn.execute(
            "UPDATE codebases SET quality_status=?, quality_reasons=? WHERE id=?",
            (status, json.dumps(list(dict.fromkeys(reasons)), ensure_ascii=False), int(entry_id)),
        )
        conn.commit()


def update_codebase(entry_id: int, code: str, prompt: Optional[str] = None) -> None:
    init_db()
    with _get_db_connection() as conn:
        if prompt is None:
            conn.execute("UPDATE codebases SET code = ? WHERE id = ?", (code, entry_id))
        else:
            conn.execute(
                "UPDATE codebases SET code = ?, prompt = ? WHERE id = ?",
                (code, prompt, entry_id),
            )
        conn.commit()


def compute_code_hash(code: str) -> str:
    return hashlib.sha256(code.encode("utf-8")).hexdigest()


def fetch_cached_seed(codebase_id: int, code_hash: str) -> Optional[int]:
    init_db()
    with _get_db_connection() as conn:
        row = conn.execute(
            """
            SELECT seed
            FROM codebase_seed_cache
            WHERE codebase_id = ? AND code_hash = ?
              AND (
                NOT EXISTS (
                  SELECT 1 FROM codebase_quality_validation q
                  WHERE q.codebase_id = codebase_seed_cache.codebase_id
                    AND q.code_hash = codebase_seed_cache.code_hash
                )
                OR EXISTS (
                  SELECT 1 FROM codebase_quality_validation q
                  WHERE q.codebase_id = codebase_seed_cache.codebase_id
                    AND q.code_hash = codebase_seed_cache.code_hash
                    AND q.seed = codebase_seed_cache.seed
                    AND q.status = 'approved'
                )
              )
            ORDER BY RANDOM()
            LIMIT 1
            """,
            (codebase_id, code_hash),
        ).fetchone()
    return int(row["seed"]) if row else None


def list_cached_seeds(codebase_id: int, code_hash: str, limit: int = 100) -> List[int]:
    """
    Return up to `limit` cached seeds for the given codebase/hash in random order.
    """
    init_db()
    safe_limit = max(1, min(int(limit), 500))
    with _get_db_connection() as conn:
        rows = conn.execute(
            """
            SELECT seed
            FROM codebase_seed_cache
            WHERE codebase_id = ? AND code_hash = ?
              AND (
                NOT EXISTS (
                  SELECT 1 FROM codebase_quality_validation q
                  WHERE q.codebase_id = codebase_seed_cache.codebase_id
                    AND q.code_hash = codebase_seed_cache.code_hash
                )
                OR EXISTS (
                  SELECT 1 FROM codebase_quality_validation q
                  WHERE q.codebase_id = codebase_seed_cache.codebase_id
                    AND q.code_hash = codebase_seed_cache.code_hash
                    AND q.seed = codebase_seed_cache.seed
                    AND q.status = 'approved'
                )
              )
            ORDER BY RANDOM()
            LIMIT ?
            """,
            (codebase_id, code_hash, safe_limit),
        ).fetchall()
    return [int(row["seed"]) for row in rows]


def save_cached_seed(codebase_id: int, code_hash: str, seed: int) -> None:
    init_db()
    with _get_db_connection() as conn:
        conn.execute(
            """
            INSERT OR IGNORE INTO codebase_seed_cache (codebase_id, code_hash, seed)
            VALUES (?, ?, ?)
            """,
            (codebase_id, code_hash, int(seed)),
        )
        conn.commit()
    record_validated_seed(codebase_id, code_hash, int(seed))


def record_seed_quality(
    codebase_id: int,
    code_hash: str,
    seed: int,
    status: str,
    reasons: List[str],
) -> None:
    """필요 변수: 코드베이스·해시·시드·최종 품질 결과. 작동 원리: 원시 실행 성공과 학생 노출 승인을 분리해 시드 단위로 UPSERT한다."""
    if status not in {"approved", "rejected"}:
        raise ValueError(f"invalid seed quality status: {status}")
    init_db()
    with _get_db_connection() as conn:
        conn.execute(
            """
            INSERT INTO codebase_quality_validation
            (codebase_id, code_hash, seed, status, reasons_json, checked_at)
            VALUES (?, ?, ?, ?, ?, strftime('%s','now'))
            ON CONFLICT(codebase_id, code_hash, seed) DO UPDATE SET
                status=excluded.status,
                reasons_json=excluded.reasons_json,
                checked_at=excluded.checked_at
            """,
            (
                int(codebase_id),
                code_hash,
                int(seed),
                status,
                json.dumps(list(dict.fromkeys(reasons)), ensure_ascii=False),
            ),
        )
        conn.commit()


def record_validated_seed(codebase_id: int, code_hash: str, seed: int) -> None:
    """Persist validated seeds alongside the codebase so they can be replayed later."""
    init_db()
    with _get_db_connection() as conn:
        row = conn.execute(
            "SELECT validated_seeds FROM codebases WHERE id = ?",
            (codebase_id,),
        ).fetchone()
        if row is None:
            return
        try:
            existing = json.loads(row["validated_seeds"] or "[]")
        except Exception:
            existing = []
        if not isinstance(existing, list):
            existing = []
        entry = {"code_hash": code_hash, "seed": int(seed)}
        if entry in existing:
            return
        existing.append(entry)
        conn.execute(
            "UPDATE codebases SET validated_seeds = ? WHERE id = ?",
            (json.dumps(existing, ensure_ascii=False), codebase_id),
        )
        conn.commit()


def save_formula_seed(
    signature: str,
    seed: int,
    *,
    params: Optional[Dict[str, Any]] = None,
    answers: Optional[Dict[str, Any]] = None,
) -> None:
    init_db()
    params_json = json.dumps(params, ensure_ascii=False) if params else None
    answers_json = json.dumps(answers, ensure_ascii=False) if answers else None
    with _get_db_connection() as conn:
        conn.execute(
            """
            INSERT OR IGNORE INTO formula_seed_cache (signature, seed, params_json, answers_json)
            VALUES (?, ?, ?, ?)
            """,
            (signature, int(seed), params_json, answers_json),
        )
        conn.commit()


def record_seed_attempt(codebase_id: int, code_hash: str, success: bool) -> None:
    init_db()
    with _get_db_connection() as conn:
        conn.execute(
            """
            INSERT INTO codebase_seed_stats (codebase_id, code_hash, attempts, successes)
            VALUES (?, ?, 1, ?)
            ON CONFLICT(codebase_id, code_hash) DO UPDATE SET
                attempts = attempts + 1,
                successes = successes + ?,
                updated_at = CURRENT_TIMESTAMP
            """,
            (codebase_id, code_hash, 1 if success else 0, 1 if success else 0),
        )
        conn.commit()


def get_seed_stats(codebase_id: int, code_hash: str) -> tuple[int, int]:
    init_db()
    with _get_db_connection() as conn:
        row = conn.execute(
            """
            SELECT attempts, successes
            FROM codebase_seed_stats
            WHERE codebase_id = ? AND code_hash = ?
            """,
            (codebase_id, code_hash),
        ).fetchone()
    if not row:
        return 0, 0
    return int(row["attempts"]), int(row["successes"])


def count_cached_seeds(codebase_id: int, code_hash: str) -> int:
    init_db()
    with _get_db_connection() as conn:
        row = conn.execute(
            """
            SELECT COUNT(*) AS total
            FROM codebase_seed_cache
            WHERE codebase_id = ? AND code_hash = ?
            """,
            (codebase_id, code_hash),
        ).fetchone()
    return int(row["total"]) if row else 0


def list_codebase_stats(*, auto_delete_disabled: bool = False) -> List[Dict[str, Any]]:
    init_db()
    conn = _get_db_connection()
    rows = conn.execute(
        """
        SELECT id, name, prompt, code, mode, tags, difficulty, tier,
               solves_count, strategy_level, branch_conditions, validated_seeds, created_at
        FROM codebases
        ORDER BY id ASC
        """
    ).fetchall()

    # Bulk-fetch stats and cache counts in single queries
    codebase_ids = [row["id"] for row in rows]
    stats_map: Dict[int, tuple] = {}
    cache_map: Dict[int, int] = {}
    if codebase_ids:
        placeholders = ",".join("?" * len(codebase_ids))
        for row in conn.execute(
            f"""
            SELECT codebase_id, code_hash, attempts, successes
            FROM codebase_seed_stats
            WHERE codebase_id IN ({placeholders})
            """,
            codebase_ids,
        ).fetchall():
            stats_map[row["codebase_id"]] = (row["attempts"], row["successes"])
        for row in conn.execute(
            f"""
            SELECT codebase_id, COUNT(*) AS total
            FROM codebase_seed_cache
            WHERE codebase_id IN ({placeholders})
            GROUP BY codebase_id
            """,
            codebase_ids,
        ).fetchall():
            cache_map[row["codebase_id"]] = int(row["total"])

    results: List[Dict[str, Any]] = []
    for row in rows:
        entry_id = row["id"]
        code = row["code"] or ""
        code_hash = compute_code_hash(code)
        attempts, successes = stats_map.get(entry_id, (0, 0))
        cached_count = cache_map.get(entry_id, 0)
        success_rate = (successes / attempts * 100.0) if attempts else None
        if attempts >= 10 and successes == 0:
            status = "disabled"
        elif attempts and success_rate is not None and success_rate < 60.0:
            status = "warning"
        else:
            status = "ok"
        if status == "disabled" and auto_delete_disabled and entry_id is not None:
            delete_codebase(entry_id)
            continue
        tags_raw = row["tags"] or ""
        try:
            tags = json.loads(tags_raw) if tags_raw else []
        except Exception:
            tags = []
        results.append(
            {
                "id": entry_id,
                "name": row["name"] or "",
                "tags": tags,
                "difficulty": row["difficulty"],
                "solves_count": row["solves_count"],
                "strategy_level": row["strategy_level"],
                "branch_conditions": row["branch_conditions"],
                "created_at": row["created_at"],
                "code_hash": code_hash,
                "attempts": attempts,
                "successes": successes,
                "success_rate": success_rate,
                "cached_seeds": cached_count,
                "status": status,
            }
        )
    return results


def save_seed_log(
    *,
    codebase_id: int,
    code_hash: str,
    seed: Optional[int],
    status: str,
    error_type: Optional[str] = None,
    error_message: Optional[str] = None,
    stage: Optional[str] = None,
    elapsed_ms: Optional[int] = None,
    source: str = "runtime",
) -> None:
    init_db()
    with _get_db_connection() as conn:
        conn.execute(
            """
            INSERT INTO codebase_seed_logs (
              codebase_id, code_hash, seed, status, error_type, error_message,
              stage, elapsed_ms, source
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                codebase_id,
                code_hash,
                seed,
                status,
                error_type,
                error_message,
                stage,
                elapsed_ms,
                source,
            ),
        )
        conn.commit()


def save_seed_logs_batch(
    logs: List[Dict[str, Any]],
) -> None:
    """Batch insert seed logs for better performance."""
    if not logs:
        return
    init_db()
    with _get_db_connection() as conn:
        conn.executemany(
            """
            INSERT INTO codebase_seed_logs (
              codebase_id, code_hash, seed, status, error_type, error_message,
              stage, elapsed_ms, source
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    log["codebase_id"],
                    log["code_hash"],
                    log.get("seed"),
                    log["status"],
                    log.get("error_type"),
                    log.get("error_message"),
                    log.get("stage"),
                    log.get("elapsed_ms"),
                    log.get("source", "runtime"),
                )
                for log in logs
            ],
        )
        conn.commit()


def list_seed_logs(
    *,
    codebase_id: Optional[int] = None,
    limit: int = 200,
) -> List[Dict[str, Any]]:
    init_db()
    params: List[Any] = []
    where = ""
    if codebase_id is not None:
        where = "WHERE codebase_id = ?"
        params.append(int(codebase_id))
    params.append(int(limit))
    with _get_db_connection() as conn:
        rows = conn.execute(
            f"""
            SELECT id, codebase_id, code_hash, seed, status, error_type, error_message,
                   stage, elapsed_ms, source, created_at
            FROM codebase_seed_logs
            {where}
            ORDER BY id DESC
            LIMIT ?
            """,
            params,
        ).fetchall()
    return [
        {
            "id": row["id"],
            "codebase_id": row["codebase_id"],
            "code_hash": row["code_hash"],
            "seed": row["seed"],
            "status": row["status"],
            "error_type": row["error_type"],
            "error_message": row["error_message"],
            "stage": row["stage"],
            "elapsed_ms": row["elapsed_ms"],
            "source": row["source"],
            "created_at": row["created_at"],
        }
        for row in rows
    ]


def save_agent_log(
    *,
    codebase_id: Optional[int],
    action: str,
    status: str,
    attempt: Optional[int] = None,
    error_message: Optional[str] = None,
    detail: Optional[Dict[str, Any]] = None,
) -> None:
    init_db()
    detail_json = json.dumps(detail or {}, ensure_ascii=False)
    with _get_db_connection() as conn:
        conn.execute(
            """
            INSERT INTO codebase_agent_logs (
              codebase_id, action, status, attempt, error_message, detail
            ) VALUES (?, ?, ?, ?, ?, ?)
            """,
            (
                codebase_id,
                action,
                status,
                attempt,
                error_message,
                detail_json,
            ),
        )
        conn.commit()


def list_agent_logs(
    *,
    codebase_id: Optional[int] = None,
    limit: int = 200,
) -> List[Dict[str, Any]]:
    init_db()
    params: List[Any] = []
    where = ""
    if codebase_id is not None:
        where = "WHERE codebase_id = ?"
        params.append(int(codebase_id))
    params.append(int(limit))
    with _get_db_connection() as conn:
        rows = conn.execute(
            f"""
            SELECT id, codebase_id, action, status, attempt, error_message, detail, created_at
            FROM codebase_agent_logs
            {where}
            ORDER BY id DESC
            LIMIT ?
            """,
            params,
        ).fetchall()
    results: List[Dict[str, Any]] = []
    for row in rows:
        detail_raw = row["detail"] or ""
        try:
            detail = json.loads(detail_raw) if detail_raw else {}
        except Exception:
            detail = {"raw": detail_raw}
        results.append(
            {
                "id": row["id"],
                "codebase_id": row["codebase_id"],
                "action": row["action"],
                "status": row["status"],
                "attempt": row["attempt"],
                "error_message": row["error_message"],
                "detail": detail,
                "created_at": row["created_at"],
            }
        )
    return results


def delete_codebase(entry_id: int) -> None:
    init_db()
    with _get_db_connection() as conn:
        conn.execute("DELETE FROM codebase_seed_cache WHERE codebase_id = ?", (entry_id,))
        conn.execute("DELETE FROM codebase_seed_stats WHERE codebase_id = ?", (entry_id,))
        conn.execute("DELETE FROM codebase_seed_logs WHERE codebase_id = ?", (entry_id,))
        conn.execute("DELETE FROM codebases WHERE id = ?", (entry_id,))
        conn.commit()
