"""FastAPI router for durable job state machine."""
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from app.api.deps import get_current_user

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

from generater.codebase_runner import hard_cancel_process_pool
from services.jobs.cancellation import cancel_token, release_token

router = APIRouter(prefix="/jobs", tags=["jobs"])


def _wrap(data, message: Optional[str] = None) -> ApiResponse:
    return ApiResponse(status=JobStatus.done, data=data, message=message)


def _get_sm() -> JobStateMachine:
    return JobStateMachine()


def _can_manage_all_jobs(user: dict) -> bool:
    return user.get("role") in {"admin", "academy_admin"}


# ── endpoints ────────────────────────────────────────────────

@router.get("/{job_id}")
def get_job(
    job_id: str,
    user: dict = Depends(get_current_user),
    sm: JobStateMachine = Depends(_get_sm),
) -> ApiResponse:
    try:
        state = sm.get_status(job_id)
    except JobNotFoundError:
        raise HTTPException(status_code=404, detail="Job not found")
    if not _can_manage_all_jobs(user) and state.get("user_id") != user.get("user_id"):
        raise HTTPException(status_code=403, detail="Not authorised to view this job")
    return _wrap(state)


@router.get("/")
def list_jobs(
    user_id: Optional[str] = Query(None),
    status: Optional[JobStatus] = Query(None),
    limit: int = Query(200, ge=1, le=1000),
    user: dict = Depends(get_current_user),
    sm: JobStateMachine = Depends(_get_sm),
) -> ApiResponse:
    js = JobState(status.value) if status else None
    if not _can_manage_all_jobs(user):
        user_id = user.get("user_id")
    rows = sm.list_jobs(user_id=user_id, status=js, limit=limit)
    return _wrap(rows)


@router.post("/{job_id}/cancel")
def cancel_job(
    job_id: str,
    user_id: Optional[str] = Query(None, description="User requesting cancellation"),
    user: dict = Depends(get_current_user),
    sm: JobStateMachine = Depends(_get_sm),
) -> ApiResponse:
    try:
        before = sm.get_status(job_id)
        if not _can_manage_all_jobs(user) and before.get("user_id") != user.get("user_id"):
            raise PermissionError("Not authorised to cancel this job")
        requester_id = before.get("user_id") if _can_manage_all_jobs(user) else user.get("user_id")
        if user_id and user_id != requester_id and not _can_manage_all_jobs(user):
            raise PermissionError("Not authorised to cancel this job")
        cancel_token(job_id)
        hard_cancel_process_pool()
        state = sm.cancel_job(job_id, requester_id)
        if before.get("status") == JobState.queued.value:
            release_token(job_id)
    except JobNotFoundError:
        raise HTTPException(status_code=404, detail="Job not found")
    except PermissionError:
        raise HTTPException(status_code=403, detail="Not authorised to cancel this job")
    except InvalidTransitionError as exc:
        raise HTTPException(status_code=409, detail=str(exc))
    return _wrap(state, message="Job cancelled")
