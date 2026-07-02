"""Durable job-state machine backed by SQLite.

Replaces the in-memory `_GEN_STATUS` dict in server.py with a persistent
`job_state` table + append-only event log.
"""
import json
import sqlite3
import uuid
from datetime import datetime, timezone
from enum import Enum
from typing import Optional

try:
    from storage.storage import DB_PATH, _ensure_column
except ImportError:
    from storage.storage import DB_PATH, _ensure_column


class JobState(str, Enum):
    queued = "queued"
    generating = "generating"
    done = "done"
    failed = "failed"
    rejected = "rejected"


# L1 in-memory cache synced to DB
_GEN_STATUS: dict[str, dict] = {}


class JobStore:
    """SQLite-backed durable job state store."""

    def __init__(self, db_path: Optional[str] = None):
        self._db_path = db_path or DB_PATH
        self._ensure_tables()

    def _ensure_tables(self) -> None:
        with sqlite3.connect(self._db_path) as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS job_state (
                    job_id TEXT PRIMARY KEY,
                    status TEXT NOT NULL,
                    operation TEXT NOT NULL,
                    payload_json TEXT,
                    result_json TEXT,
                    error TEXT,
                    rejection_reason TEXT,
                    user_id TEXT,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                )
                """
            )
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS job_event_log (
                    event_id INTEGER PRIMARY KEY AUTOINCREMENT,
                    job_id TEXT NOT NULL,
                    old_status TEXT,
                    new_status TEXT NOT NULL,
                    detail TEXT,
                    created_at TEXT NOT NULL
                )
                """
            )
            _ensure_column(conn.cursor(), "job_state", "user_id", "user_id TEXT")
            conn.execute(
                "CREATE INDEX IF NOT EXISTS idx_job_state_status ON job_state(status)"
            )
            conn.execute(
                "CREATE INDEX IF NOT EXISTS idx_job_state_user_id ON job_state(user_id)"
            )
            conn.execute(
                "CREATE INDEX IF NOT EXISTS idx_job_event_job_id ON job_event_log(job_id)"
            )
            conn.commit()

    def create(
        self,
        operation: str,
        payload: Optional[dict] = None,
        user_id: Optional[str] = None,
        job_id: Optional[str] = None,
    ) -> str:
        job_id = job_id or str(uuid.uuid4())
        now = datetime.now(timezone.utc).isoformat()
        payload_json = json.dumps(payload) if payload else None
        with sqlite3.connect(self._db_path) as conn:
            conn.execute(
                """
                INSERT INTO job_state (job_id, status, operation, payload_json, user_id, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (job_id, JobState.queued.value, operation, payload_json, user_id, now, now),
            )
            conn.execute(
                """
                INSERT INTO job_event_log (job_id, old_status, new_status, detail, created_at)
                VALUES (?, ?, ?, ?, ?)
                """,
                (job_id, None, JobState.queued.value, "Job created", now),
            )
            conn.commit()

        # Sync L1 cache
        _GEN_STATUS[job_id] = {
            "job_id": job_id,
            "status": JobState.queued.value,
            "operation": operation,
            "payload": payload,
            "result": None,
            "error": None,
            "rejection_reason": None,
            "user_id": user_id,
            "created_at": now,
            "updated_at": now,
        }
        return job_id

    def transition(
        self,
        job_id: str,
        new_status: JobState,
        *,
        detail: Optional[str] = None,
        result: Optional[dict] = None,
        error: Optional[str] = None,
        rejection_reason: Optional[str] = None,
    ) -> None:
        now = datetime.now(timezone.utc).isoformat()
        with sqlite3.connect(self._db_path) as conn:
            cur = conn.execute("SELECT status FROM job_state WHERE job_id = ?", (job_id,))
            row = cur.fetchone()
            old_status = row[0] if row else None
            conn.execute(
                """UPDATE job_state
                   SET status = ?, result_json = ?, error = ?, rejection_reason = ?, updated_at = ?
                   WHERE job_id = ?""",
                (
                    new_status.value,
                    json.dumps(result) if result else None,
                    error,
                    rejection_reason,
                    now,
                    job_id,
                ),
            )
            conn.execute(
                """
                INSERT INTO job_event_log (job_id, old_status, new_status, detail, created_at)
                VALUES (?, ?, ?, ?, ?)
                """,
                (
                    job_id,
                    old_status,
                    new_status.value,
                    detail or f"Transition to {new_status.value}",
                    now,
                ),
            )
            conn.commit()

        # Sync L1 cache
        cached = _GEN_STATUS.get(job_id, {})
        cached["status"] = new_status.value
        cached["updated_at"] = now
        if result is not None:
            cached["result"] = result
        if error is not None:
            cached["error"] = error
        if rejection_reason is not None:
            cached["rejection_reason"] = rejection_reason
        _GEN_STATUS[job_id] = cached

    def get(self, job_id: str) -> Optional[dict]:
        # L1 cache hit
        if job_id in _GEN_STATUS:
            cached = _GEN_STATUS[job_id]
            return {
                "job_id": cached["job_id"],
                "status": cached["status"],
                "operation": cached["operation"],
                "payload_json": json.dumps(cached["payload"]) if cached.get("payload") is not None else None,
                "result_json": json.dumps(cached["result"]) if cached.get("result") is not None else None,
                "error": cached.get("error"),
                "rejection_reason": cached.get("rejection_reason"),
                "user_id": cached.get("user_id"),
                "created_at": cached["created_at"],
                "updated_at": cached["updated_at"],
            }

        with sqlite3.connect(self._db_path) as conn:
            conn.row_factory = sqlite3.Row
            row = conn.execute(
                "SELECT * FROM job_state WHERE job_id = ?", (job_id,)
            ).fetchone()
            if row is None:
                return None
            return dict(row)

    def poll(self, job_id: str) -> dict:
        """Return current state; callers poll until terminal."""
        state = self.get(job_id)
        if state is None:
            return {"status": "not_found", "job_id": job_id}
        return {
            "status": state["status"],
            "job_id": job_id,
            "operation": state["operation"],
            "result": json.loads(state["result_json"]) if state.get("result_json") else None,
            "error": state.get("error"),
            "rejection_reason": state.get("rejection_reason"),
            "created_at": state["created_at"],
            "updated_at": state["updated_at"],
        }

    def list_active(self, operation: Optional[str] = None, limit: int = 50) -> list[dict]:
        with sqlite3.connect(self._db_path) as conn:
            conn.row_factory = sqlite3.Row
            sql = "SELECT * FROM job_state WHERE status IN (?, ?)"
            params = [JobState.queued.value, JobState.generating.value]
            if operation:
                sql += " AND operation = ?"
                params.append(operation)
            sql += " ORDER BY created_at DESC LIMIT ?"
            params.append(limit)
            rows = conn.execute(sql, params).fetchall()
            return [dict(r) for r in rows]

    def list_jobs(
        self,
        user_id: Optional[str] = None,
        status: Optional[JobState] = None,
        limit: int = 200,
    ) -> list[dict]:
        with sqlite3.connect(self._db_path) as conn:
            conn.row_factory = sqlite3.Row
            conditions: list[str] = []
            params: list = []
            if user_id is not None:
                conditions.append("user_id = ?")
                params.append(user_id)
            if status is not None:
                conditions.append("status = ?")
                params.append(status.value)
            sql = "SELECT * FROM job_state"
            if conditions:
                sql += " WHERE " + " AND ".join(conditions)
            sql += " ORDER BY created_at DESC LIMIT ?"
            params.append(limit)
            rows = conn.execute(sql, params).fetchall()
            return [dict(r) for r in rows]

    def get_events(self, job_id: str) -> list[dict]:
        with sqlite3.connect(self._db_path) as conn:
            conn.row_factory = sqlite3.Row
            rows = conn.execute(
                "SELECT * FROM job_event_log WHERE job_id = ? ORDER BY created_at ASC",
                (job_id,),
            ).fetchall()
            return [dict(r) for r in rows]
