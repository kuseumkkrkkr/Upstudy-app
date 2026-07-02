"""FastAPI router for durable job state machine."""
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query

try:
    from app.schemas.common import ApiResponse, JobStatus
    from services.jobs.state_machine import (
        JobStateMachine,
        JobState,
        InvalidTransitionError,
        JobNotFoundError,
    )
except ImportError:
    from app.schemas.common import ApiResponse, JobStatus
    from services.jobs.state_machine import (
        JobStateMachine,
        JobState,
        InvalidTransitionError,
        JobNotFoundError,
    )

router = APIRouter(prefix="/jobs", tags=["jobs"])


def _wrap(data, message: Optional[str] = None) -> ApiResponse:
    return ApiResponse(status=JobStatus.done, data=data, message=message)


def _get_sm() -> JobStateMachine:
    return JobStateMachine()


# ── endpoints ────────────────────────────────────────────────

@router.get("/{job_id}")
def get_job(job_id: str, sm: JobStateMachine = Depends(_get_sm)) -> ApiResponse:
    try:
        state = sm.get_status(job_id)
    except JobNotFoundError:
        raise HTTPException(status_code=404, detail="Job not found")
    return _wrap(state)


@router.get("/")
def list_jobs(
    user_id: Optional[str] = Query(None),
    status: Optional[JobStatus] = Query(None),
    limit: int = Query(200, ge=1, le=1000),
    sm: JobStateMachine = Depends(_get_sm),
) -> ApiResponse:
    js = JobState(status.value) if status else None
    rows = sm.list_jobs(user_id=user_id, status=js, limit=limit)
    return _wrap(rows)


@router.post("/{job_id}/cancel")
def cancel_job(
    job_id: str,
    user_id: str = Query(..., description="User requesting cancellation"),
    sm: JobStateMachine = Depends(_get_sm),
) -> ApiResponse:
    try:
        state = sm.cancel_job(job_id, user_id)
    except JobNotFoundError:
        raise HTTPException(status_code=404, detail="Job not found")
    except PermissionError:
        raise HTTPException(status_code=403, detail="Not authorised to cancel this job")
    except InvalidTransitionError as exc:
        raise HTTPException(status_code=409, detail=str(exc))
    return _wrap(state, message="Job cancelled")
