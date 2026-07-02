"""State-machine facade over JobStore with transition validation."""
from typing import Optional

try:
    from services.jobs.store import JobStore, JobState
except ImportError:
    from services.jobs.store import JobStore, JobState


VALID_TRANSITIONS: dict[JobState, list[JobState]] = {
    JobState.queued: [JobState.generating, JobState.rejected, JobState.failed],
    JobState.generating: [JobState.done, JobState.failed, JobState.rejected],
}

TERMINAL_STATES = {JobState.done, JobState.failed, JobState.rejected}


class InvalidTransitionError(Exception):
    """Raised when a job status transition is not allowed."""

    pass


class JobNotFoundError(Exception):
    """Raised when a job does not exist."""

    pass


class JobStateMachine:
    """High-level durable job orchestrator."""

    def __init__(self, db_path: Optional[str] = None):
        self._store = JobStore(db_path)

    # ── lifecycle ──────────────────────────────────────────────

    def start_job(
        self,
        user_id: str,
        job_type: str,
        payload: Optional[dict] = None,
        job_id: Optional[str] = None,
    ) -> dict:
        """Create a new job and return its initial state."""
        job_id = self._store.create(
            operation=job_type,
            payload=payload,
            user_id=user_id,
            job_id=job_id,
        )
        return self.get_status(job_id)

    def transition(
        self,
        job_id: str,
        to_status: JobState,
        *,
        reason: Optional[str] = None,
        result: Optional[dict] = None,
        error: Optional[str] = None,
        rejection_reason: Optional[str] = None,
    ) -> dict:
        """Move a job to a new status with validation."""
        current = self._store.get(job_id)
        if current is None:
            raise JobNotFoundError(f"Job {job_id} not found")

        from_status = JobState(current["status"])

        if to_status == from_status:
            return self.get_status(job_id)

        if from_status in TERMINAL_STATES:
            raise InvalidTransitionError(
                f"Cannot transition from terminal state {from_status.value}"
            )

        allowed = VALID_TRANSITIONS.get(from_status, [])
        if to_status not in allowed:
            raise InvalidTransitionError(
                f"Transition {from_status.value} -> {to_status.value} not allowed"
            )

        self._store.transition(
            job_id,
            to_status,
            detail=reason,
            result=result,
            error=error,
            rejection_reason=rejection_reason,
        )
        return self.get_status(job_id)

    def cancel_job(self, job_id: str, user_id: str) -> dict:
        """Cancel a job if it is queued or generating."""
        current = self._store.get(job_id)
        if current is None:
            raise JobNotFoundError(f"Job {job_id} not found")

        if current.get("user_id") != user_id:
            raise PermissionError("Not authorised to cancel this job")

        status = JobState(current["status"])
        if status not in (JobState.queued, JobState.generating):
            raise InvalidTransitionError(
                f"Cannot cancel a job in status {status.value}"
            )

        self._store.transition(
            job_id,
            JobState.rejected,
            detail=f"Cancelled by user {user_id}",
            rejection_reason="user_cancelled",
        )
        return self.get_status(job_id)

    # ── queries ────────────────────────────────────────────────

    def get_status(self, job_id: str) -> dict:
        """Full job info including event history."""
        state = self._store.get(job_id)
        if state is None:
            raise JobNotFoundError(f"Job {job_id} not found")
        events = self._store.get_events(job_id)
        return {
            "job_id": state["job_id"],
            "status": state["status"],
            "operation": state["operation"],
            "payload": state.get("payload_json"),
            "result": state.get("result_json"),
            "error": state.get("error"),
            "rejection_reason": state.get("rejection_reason"),
            "user_id": state.get("user_id"),
            "created_at": state["created_at"],
            "updated_at": state["updated_at"],
            "events": events,
        }

    def poll(self, job_id: str) -> dict:
        """Lightweight poll for clients (no event history)."""
        return self._store.poll(job_id)

    def list_jobs(
        self,
        user_id: Optional[str] = None,
        status: Optional[JobState] = None,
        limit: int = 200,
    ) -> list[dict]:
        """Filterable job listing."""
        rows = self._store.list_jobs(user_id=user_id, status=status, limit=limit)
        for r in rows:
            r["payload"] = r.pop("payload_json", None)
            r["result"] = r.pop("result_json", None)
        return rows

    def list_active(self, operation: Optional[str] = None, limit: int = 50) -> list[dict]:
        """Queued or generating jobs."""
        return self._store.list_active(operation=operation, limit=limit)
